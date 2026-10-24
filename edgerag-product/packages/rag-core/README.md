# 🧠 Track 4: Agentic RAG Engine (`packages/rag-core`)

**Assigned Team Member**: Member 4 (AI, Embeddings & RAG Lead)  
**Tech Stack**: Python 3.11+, PyMuPDF (fitz), RapidOCR, NumPy, Sentence-Transformers (MiniLM-L6-v2), SQLite  
**Git Scope**: `feat(rag): <description>` or `fix(rag): <description>`  
**Dedicated Branch**: `track/ai-engine` (or feature branches `feat/ai/<feature-name>`)

---

## 🎯 Domain & Responsibilities

You own the **Core Ingestion, Extraction, Chunking & Packaging Pipeline**:
1. **Resilient PDF/OCR Ingestion**: Per-page exception isolation, skipping blank or lined notebook pages while preserving exact physical page numbers.
2. **Context-Aware Semantic Chunking**: Chunking text by headers, error code identifiers, and procedure sections with overlap.
3. **Local Embedding Generation**: Creating normalized dense vector representations using all-MiniLM-L6-v2.
4. **Knowledge Packaging**: Compiling SQLite databases containing chunks, embeddings, and full-text indexes, bundled with SHA-256 integrity manifests for mobile distribution.
5. **Adaptive Bounded Retrieval Logic**: Developing domain-aware query rewriting algorithms and evidence threshold gating.

---

## 📁 Folder Structure

```
packages/rag-core/
├── src/
│   ├── __init__.py           # Package exports
│   ├── extractor.py          # PDF text extraction, RapidOCR & blank page skipping
│   ├── chunker.py            # Section-aware & error-code preserving chunker
│   ├── embedder.py           # Dense vector embedding generator
│   └── packager.py           # Offline SQLite & manifest compiler
├── setup.py                  # Package installation metadata
└── README.md                 # This track guide
```

---

## 🚀 Key Modules & Functions

### `extractor.py`
- `extract_text_and_ocr(pdf_path: str) -> List[PageContent]`
  - Renders visual drawings and scanned text using RapidOCR.
  - Automatically isolates errors per page: if page 28 is a lined notes page, it logs a warning and proceeds without failing the document.
  - Records `indexed_pages` and `skipped_pages` in extraction metadata.

### `chunker.py`
- `chunk_document(pages: List[PageContent], max_tokens=384, overlap=40) -> List[Chunk]`
  - Preserves error code labels (`E-104`, `ERR-4029`, `F02`) inside chunk bodies for high-precision exact matching.

### `packager.py`
- `build_knowledge_package(equipment_id, version, chunks) -> (zip_path, sha256_hash)`
  - Creates an isolated `knowledge.sqlite` database with `chunks` and `manuals` tables.
  - Computes SHA-256 cryptographic digest for client verification.

---

## 💡 How to Test Changes

Run unit tests directly:
```bash
pytest tests/unit/test_rag_quality.py
```

Run the 25-question evaluation benchmark:
```bash
python tests/eval/eval_benchmark.py
```

---

## 📤 Git Commit & Contribution Guide

When making changes to Track 4, always use the `rag` or `ai` scope:

```bash
git checkout -b feat/ai/multimodal-chunking
# Make your edits in packages/rag-core/
git add packages/rag-core/
git commit -m "feat(rag): add diagram bounding box preservation in chunk metadata"
git push origin feat/ai/multimodal-chunking
```
*(Your commits will cleanly highlight your contributions on the team's GitHub commit graph without any file conflicts with other members!)*
