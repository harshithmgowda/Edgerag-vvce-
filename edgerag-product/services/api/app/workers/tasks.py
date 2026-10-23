import os
import io
import json
import uuid
import hashlib
import sqlite3
import zipfile
import struct
from datetime import datetime
from sqlalchemy.orm import Session
from app.workers.celery_app import celery_app
from app.db.database import SessionLocal
from app.db.models import ProcessingJobModel, ManualModel, KnowledgePackageModel, EquipmentModel
from app.services.storage import storage_service
from app.config import settings

def _compute_sha256(filepath: str) -> str:
    sha = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            sha.update(chunk)
    return sha.hexdigest()

def _simple_chunk_text(text: str, chunk_size: int = 224, overlap: int = 32):
    from src.chunker import TokenAwareChunker
    return [c["chunk_text"] for c in TokenAwareChunker(chunk_size, overlap).chunk_pages(
        [{"page_number": 1, "text": text}], "", "")]


def _generate_384d_embedding(text: str) -> bytes:
    from src.embedder import get_embedder
    return get_embedder().embed_to_bytes(text)


def execute_processing_pipeline(job_id: str):
    """Core deterministic PDF processing, chunking, embedding, SQLite compilation, and packaging pipeline."""
    db: Session = SessionLocal()
    try:
        job = db.query(ProcessingJobModel).filter(ProcessingJobModel.id == job_id).first()
        if not job:
            return

        manual = db.query(ManualModel).filter(ManualModel.id == job.manual_id).first()
        equipment = db.query(EquipmentModel).filter(EquipmentModel.id == job.equipment_id).first()
        if not manual or not equipment:
            job.status = "FAILED"
            job.error_message = "Associated manual or equipment record missing"
            db.commit()
            return

        # STAGE 1: INIT
        job.status = "RUNNING"
        job.stage = "EXTRACTING_PAGES"
        job.progress_percentage = 15
        job.error_message = None
        job.completed_at = None
        manual.status = "PROCESSING"
        db.commit()

        from src.extractor import PdfExtractor
        from src.chunker import TokenAwareChunker
        # Each new version contains every processed manual for this equipment.
        # A newly uploaded manual must not hide older documents from retrieval.
        manuals = db.query(ManualModel).filter(ManualModel.equipment_id == equipment.id).all()
        manuals = [m for m in manuals if m.id == manual.id or m.status == "PROCESSED"]
        all_chunks = []
        manifest_manuals = []
        extraction_reports = []
        from src.embedder import get_embedder
        encoder = get_embedder()
        chunker = TokenAwareChunker(settings.MAX_CHUNK_TOKENS, settings.CHUNK_OVERLAP_TOKENS, tokenizer=encoder.chunk_tokenizer())
        for source in manuals:
            pdf_path = storage_service.get_file_path_or_bytes(source.storage_path)
            pages, metadata = PdfExtractor.extract_pages(pdf_path)
            extraction_reports.append({"manual_id": source.id, "title": source.title, **metadata})
            report_dir = os.path.join(settings.LOCAL_STORAGE_DIR, "reports")
            os.makedirs(report_dir, exist_ok=True)
            with open(os.path.join(report_dir, f"{job.id}.json"), "w", encoding="utf-8") as report:
                json.dump(extraction_reports, report)
            chunks = chunker.chunk_pages(pages, source.id, equipment.id)
            if not chunks:
                raise ValueError(f"{source.title}: PDF has no extractable text; OCR is required")
            source.page_count = metadata["total_pages"]
            all_chunks.extend(chunks)
            manifest_manuals.append({"manual_id": source.id, "title": source.title,
                "revision": source.revision, "page_count": source.page_count, "chunk_count": len(chunks),
                "indexed_pages": metadata.get("indexed_pages", []), "skipped_pages": metadata.get("skipped_pages", [])})
        job.total_pages = sum(m["page_count"] for m in manifest_manuals)
        job.stage = "CHUNKING"
        job.progress_percentage = 40
        db.commit()

        job.total_chunks = len(all_chunks)
        job.stage = "EMBEDDING"
        job.progress_percentage = 60
        db.commit()

        # STAGE 3: EMBEDDINGS & SQLITE GENERATION
        job.stage = "GENERATING_SQLITE"
        job.progress_percentage = 75
        db.commit()

        temp_dir = os.path.join(settings.LOCAL_STORAGE_DIR, "temp", job.id)
        os.makedirs(temp_dir, exist_ok=True)
        sqlite_file = os.path.join(temp_dir, "knowledge.sqlite")

        if os.path.exists(sqlite_file):
            os.remove(sqlite_file)
        # Create Knowledge SQLite database
        conn = sqlite3.connect(sqlite_file)
        cur = conn.cursor()
        cur.execute("CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        cur.execute("INSERT INTO metadata VALUES (?, ?)", ("embedding_backend", "minilm-onnx-meanpool-v1"))
        cur.execute("INSERT INTO metadata VALUES (?, ?)", ("encoder_fingerprint", encoder.fingerprint()))

        cur.execute("""
            CREATE TABLE manuals (
                id TEXT PRIMARY KEY,
                equipment_id TEXT NOT NULL,
                title TEXT NOT NULL,
                revision TEXT NOT NULL,
                page_count INTEGER NOT NULL
            )
        """)
        for source in manuals:
            cur.execute("INSERT INTO manuals VALUES (?, ?, ?, ?, ?)", (
                source.id, equipment.id, source.title, source.revision, source.page_count
            ))

        cur.execute("""
            CREATE TABLE chunks (
                id TEXT PRIMARY KEY,
                manual_id TEXT NOT NULL,
                equipment_id TEXT NOT NULL,
                page_number INTEGER NOT NULL,
                chunk_text TEXT NOT NULL
            )
        """)

        cur.execute("""
            CREATE TABLE embeddings (
                chunk_id TEXT PRIMARY KEY,
                embedding_bytes BLOB NOT NULL
            )
        """)

        for ch in all_chunks:
            cur.execute("INSERT INTO chunks VALUES (?, ?, ?, ?, ?)", (
                ch["id"], ch["manual_id"], ch["equipment_id"], ch["page_number"], ch["chunk_text"]
            ))
            emb_bytes = _generate_384d_embedding(ch["chunk_text"])
            cur.execute("INSERT INTO embeddings VALUES (?, ?)", (
                ch["id"], emb_bytes
            ))

        conn.commit()
        conn.close()

        # STAGE 4: PACKAGING & ZIP BUNDLE CREATION
        job.stage = "PACKAGING"
        job.progress_percentage = 90
        db.commit()

        sqlite_sha = _compute_sha256(sqlite_file)
        manifest_data = {
            "schema_version": "1.0.0",
            "package_id": str(uuid.uuid4()),
            "equipment_id": equipment.id,
            "equipment_name": equipment.name,
            "version": f"v-{job.id.replace('-', '')[:24]}",
            "generated_at": datetime.utcnow().isoformat() + "Z",
            "chunk_count": len(all_chunks),
            "embedding_spec": {
                "model_name": "all-MiniLM-L6-v2",
                "dimension": settings.EMBEDDING_DIMENSION,
                "normalized": True,
                "similarity_metric": "cosine"
            },
            "manuals": manifest_manuals,
            "extraction_reports": extraction_reports,
            "sqlite_checksum_sha256": sqlite_sha
        }

        manifest_file = os.path.join(temp_dir, "manifest.json")
        with open(manifest_file, "w") as f:
            json.dump(manifest_data, f, indent=2)

        # Build ZIP archive
        package_file_name = f"equipment-knowledge-{equipment.id[:8]}-{job.id}.zip"
        zip_path = os.path.join(temp_dir, package_file_name)

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
            zipf.write(manifest_file, arcname="manifest.json")
            zipf.write(sqlite_file, arcname="knowledge.sqlite")

        # Move ZIP to persistent storage
        zip_sha256 = _compute_sha256(zip_path)
        zip_size = os.path.getsize(zip_path)

        with open(zip_path, "rb") as f:
            final_storage_path = storage_service.upload_file(
                bucket=settings.MINIO_BUCKET_PACKAGES,
                object_name=package_file_name,
                file_data=f,
                length=zip_size,
                content_type="application/zip",
            )

        # STAGE 5: PUBLISH PACKAGE RECORD
        pkg_record = KnowledgePackageModel(
            id=manifest_data["package_id"],
            equipment_id=equipment.id,
            version=f"v-{job.id.replace('-', '')[:24]}",
            package_file_name=package_file_name,
            storage_path=final_storage_path,
            file_size_bytes=zip_size,
            sha256_hash=zip_sha256,
            chunk_count=len(all_chunks),
            encoder_model="all-MiniLM-L6-v2",
            vector_dimension=settings.EMBEDDING_DIMENSION,
        )
        db.add(pkg_record)

        # Update Job & Manual status
        manual.status = "PROCESSED"
        job.status = "SUCCEEDED"
        job.stage = "COMPLETED"
        job.progress_percentage = 100
        job.completed_at = datetime.utcnow()
        db.commit()

    except Exception as e:
        db.rollback()
        job = db.query(ProcessingJobModel).filter(ProcessingJobModel.id == job_id).first()
        if job:
            job.status = "FAILED"
            job.error_message = str(e)
            job.completed_at = datetime.utcnow()
            failed_manual = db.query(ManualModel).filter(ManualModel.id == job.manual_id).first()
            if failed_manual:
                failed_manual.status = "FAILED"
            db.commit()
    finally:
        db.close()

@celery_app.task(name="app.workers.tasks.process_manual_task")
def process_manual_task(job_id: str):
    execute_processing_pipeline(job_id)
