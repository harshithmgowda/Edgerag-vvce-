import sys
from pathlib import Path
import pytest
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "services/api"))
sys.path.insert(0, str(ROOT / "packages/rag-core"))
from app.ai.retrieval import rank_chunks
from src.chunker import TokenAwareChunker
from src.extractor import PdfExtractor


def chunk(id, text):
    return dict(chunk_id=id, manual_id="manual", manual_title="Manual", page_number=1, chunk_text=text)

def test_retrieval_rejects_unrelated_evidence():
    assert rank_chunks([chunk("a", "Oil pressure maintenance inspection")], "Dijkstra shortest path") == []

def test_retrieval_ranks_topic_and_exact_error_codes():
    docs = [chunk("a", "Water jug capacity and search states"), chunk("b", "Dijkstra shortest path algorithm uses distances"), chunk("c", "E-104 means coolant failure")]
    assert rank_chunks(docs, "explain Dijkstra shortest path")[0]["chunk_id"] == "b"
    assert rank_chunks(docs, "what does E-104 mean")[0]["chunk_id"] == "c"

def test_short_questions_and_duplicate_context():
    docs = [chunk("a", "Dijkstra shortest paths"), chunk("b", "Dijkstra shortest paths")]
    assert len(rank_chunks(docs, "Dijkstra")) == 1
    assert rank_chunks(docs, "what is the") == []

def test_chunker_preserves_layout_and_all_content():
    text = "Procedure:\n1. Open valve.\n2. Check pressure.\n\n" + "\n".join(f"value_{i} = input + {i};" for i in range(80))
    chunks = TokenAwareChunker(64, 12).chunk_pages([dict(page_number=7, text=text)], "manual", "equipment")
    assert len(chunks) > 1
    assert "\n" in chunks[0]["chunk_text"]
    assert all(c["token_count"] <= 64 and c["page_number"] == 7 for c in chunks)
    for i in range(80):
        assert any(f"value_{i}" in c["chunk_text"] for c in chunks)

def test_invalid_chunk_parameters():
    with pytest.raises(ValueError): TokenAwareChunker(32, 32)
    with pytest.raises(ValueError): TokenAwareChunker(0, 0)

def test_corrupt_pdf_never_becomes_fake_evidence(tmp_path):
    path = tmp_path / "broken.pdf"
    path.write_bytes(b"not a PDF")
    with pytest.raises(ValueError): PdfExtractor.extract_pages(str(path))


def test_generic_word_match_is_not_sufficient_evidence():
    assert rank_chunks([chunk("a", "This problem concerns oil pressure")], "water jug problem") == []

def test_extractor_skips_blank_notes_pages_and_preserves_page_numbers(tmp_path):
    import fitz
    pdf_path = tmp_path / "mixed_document.pdf"
    doc = fitz.open()
    # Page 1: Normal manual page
    p1 = doc.new_page()
    p1.insert_text((50, 50), "Error code E-104 indicates coolant loop pressure loss below 1.2 bar.")
    # Page 2: Ruled blank notes page (with line drawings, no alphanumeric text)
    p2 = doc.new_page()
    p2.draw_line((50, 100), (400, 100))
    p2.draw_line((50, 150), (400, 150))
    p2.draw_line((50, 200), (400, 200))
    # Page 3: Technical procedure page
    p3 = doc.new_page()
    p3.insert_text((50, 50), "Procedure: Replace coolant manifold O-rings and verify recirculation pump P-200 line pressure.")
    doc.save(str(pdf_path))
    doc.close()

    pages, meta = PdfExtractor.extract_pages(str(pdf_path))
    assert meta["total_pages"] == 3
    assert 2 in meta["skipped_pages"]
    assert 1 in meta["indexed_pages"]
    assert 3 in meta["indexed_pages"]
    assert pages[0]["page_number"] == 1
    assert pages[1]["page_number"] == 2
    assert pages[1]["is_empty"] is True
    assert pages[2]["page_number"] == 3
    assert pages[2]["is_empty"] is False
    assert "E-104" in pages[0]["text"]
    assert "P-200" in pages[2]["text"]

