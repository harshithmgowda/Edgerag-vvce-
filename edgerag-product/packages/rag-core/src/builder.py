import os
import json
import sqlite3
import zipfile
import hashlib
from datetime import datetime
from typing import List, Dict, Any

class KnowledgePackageBuilder:
    """Builds and verifies portable SQLite knowledge packages for Android sync."""

    @staticmethod
    def compute_sha256(filepath: str) -> str:
        sha = hashlib.sha256()
        with open(filepath, "rb") as f:
            while chunk := f.read(65536):
                sha.update(chunk)
        return sha.hexdigest()

    @classmethod
    def build_package(
        cls,
        output_dir: str,
        package_id: str,
        equipment_id: str,
        equipment_name: str,
        version: str,
        manual_id: str,
        manual_title: str,
        manual_revision: str,
        page_count: int,
        chunks: List[Dict[str, Any]],
        embeddings: List[bytes],
    ) -> Dict[str, Any]:
        os.makedirs(output_dir, exist_ok=True)
        sqlite_path = os.path.join(output_dir, "knowledge.sqlite")

        # 1. Compile SQLite Database
        if os.path.exists(sqlite_path):
            os.remove(sqlite_path)

        conn = sqlite3.connect(sqlite_path)
        cur = conn.cursor()

        cur.execute("""
            CREATE TABLE manuals (
                id TEXT PRIMARY KEY,
                equipment_id TEXT NOT NULL,
                title TEXT NOT NULL,
                revision TEXT NOT NULL,
                page_count INTEGER NOT NULL
            )
        """)
        cur.execute("INSERT INTO manuals VALUES (?, ?, ?, ?, ?)", (
            manual_id, equipment_id, manual_title, manual_revision, page_count
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

        for ch, emb_bytes in zip(chunks, embeddings):
            cur.execute("INSERT INTO chunks VALUES (?, ?, ?, ?, ?)", (
                ch["id"], ch["manual_id"], ch["equipment_id"], ch["page_number"], ch["chunk_text"]
            ))
            cur.execute("INSERT INTO embeddings VALUES (?, ?)", (
                ch["id"], emb_bytes
            ))

        conn.commit()
        conn.close()

        # 2. Compute SQLite Checksum
        sqlite_sha = cls.compute_sha256(sqlite_path)

        # 3. Create Manifest
        manifest_data = {
            "schema_version": "1.0.0",
            "package_id": package_id,
            "equipment_id": equipment_id,
            "equipment_name": equipment_name,
            "version": version,
            "generated_at": datetime.utcnow().isoformat() + "Z",
            "chunk_count": len(chunks),
            "embedding_spec": {
                "model_name": "all-MiniLM-L6-v2",
                "dimension": 384,
                "normalized": True,
                "similarity_metric": "cosine"
            },
            "manuals": [
                {
                    "manual_id": manual_id,
                    "title": manual_title,
                    "revision": manual_revision,
                    "page_count": page_count,
                    "chunk_count": len(chunks)
                }
            ],
            "sqlite_checksum_sha256": sqlite_sha
        }

        manifest_path = os.path.join(output_dir, "manifest.json")
        with open(manifest_path, "w") as f:
            json.dump(manifest_data, f, indent=2)

        # 4. Create ZIP Bundle
        zip_filename = f"equipment-knowledge-{equipment_id[:8]}-{version}.zip"
        zip_path = os.path.join(output_dir, zip_filename)

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
            zipf.write(manifest_path, arcname="manifest.json")
            zipf.write(sqlite_path, arcname="knowledge.sqlite")

        zip_sha = cls.compute_sha256(zip_path)
        zip_size = os.path.getsize(zip_path)

        return {
            "zip_path": zip_path,
            "zip_filename": zip_filename,
            "file_size_bytes": zip_size,
            "sha256_hash": zip_sha,
            "manifest": manifest_data,
        }
