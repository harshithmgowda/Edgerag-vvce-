from pathlib import Path
r=Path.cwd();p=r/'services/api/app/workers/tasks.py';s=p.read_text();a=s.index('        # Locate PDF file');b=s.index('        job.total_chunks = len(all_chunks)',a)
s=s[:a]+'''        from src.extractor import PdfExtractor
        from src.chunker import TokenAwareChunker
        # Each new version contains every processed manual for this equipment.
        # A newly uploaded manual must not hide older documents from retrieval.
        manuals = db.query(ManualModel).filter(ManualModel.equipment_id == equipment.id).all()
        manuals = [m for m in manuals if m.id == manual.id or m.status == "PROCESSED"]
        all_chunks = []
        manifest_manuals = []
        chunker = TokenAwareChunker(settings.MAX_CHUNK_TOKENS, settings.CHUNK_OVERLAP_TOKENS)
        for source in manuals:
            pdf_path = storage_service.get_file_path_or_bytes(source.storage_path)
            pages, metadata = PdfExtractor.extract_pages(pdf_path)
            if metadata["scanned_pages_count"]:
                raise ValueError(f"{source.title}: image-only pages require OCR before indexing")
            chunks = chunker.chunk_pages(pages, source.id, equipment.id)
            if not chunks:
                raise ValueError(f"{source.title}: PDF has no extractable text; OCR is required")
            source.page_count = metadata["total_pages"]
            all_chunks.extend(chunks)
            manifest_manuals.append({"manual_id": source.id, "title": source.title,
                "revision": source.revision, "page_count": source.page_count, "chunk_count": len(chunks)})
        job.total_pages = sum(m["page_count"] for m in manifest_manuals)
        job.stage = "CHUNKING"
        job.progress_percentage = 40
        db.commit()

''' + s[b:]
s=s.replace('        cur.execute("INSERT INTO manuals VALUES (?, ?, ?, ?, ?)", (\n            manual.id, equipment.id, manual.title, manual.revision, manual.page_count\n        ))', '        for source in manuals:\n            cur.execute("INSERT INTO manuals VALUES (?, ?, ?, ?, ?)", (\n                source.id, equipment.id, source.title, source.revision, source.page_count\n            ))')
a=s.index('            "manuals": [');b=s.index('            "sqlite_checksum_sha256"',a);s=s[:a]+'            "manuals": manifest_manuals,\n'+s[b:]
s=s.replace('version="v1",','version=f"v-{job.id}",').replace('"version": f"v1",','"version": f"v-{job.id}",');p.write_text(s)
# Make extraction fail explicitly for scanned vector-only pages too.
p=r/'packages/rag-core/src/extractor.py';s=p.read_text().replace('ocr_needed = is_empty and len(page.get_images()) > 0','ocr_needed = is_empty and (len(page.get_images()) > 0 or bool(page.get_drawings()))');p.write_text(s)
