from pathlib import Path
r=Path.cwd();d=r/'tests/unit';d.mkdir(exist_ok=True)
(d/'test_rag_quality.py').write_text('''import sys
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
    text = "Procedure:\\n1. Open valve.\\n2. Check pressure.\\n\\n" + "\\n".join(f"value_{i} = input + {i};" for i in range(80))
    chunks = TokenAwareChunker(64, 12).chunk_pages([dict(page_number=7, text=text)], "manual", "equipment")
    assert len(chunks) > 1
    assert "\\n" in chunks[0]["chunk_text"]
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
''')
p=r/'apps/mobile/test/retrieval_test.dart';p.write_text('''import 'package:flutter_test/flutter_test.dart';
import 'package:edgerag_mobile/models/models.dart';
import 'package:edgerag_mobile/services/knowledge_retrieval.dart';

ChunkModel chunk(String id, String text) => ChunkModel(id:id, manualId:'manual',
  manualTitle:'Manual', pageNumber:1, chunkText:text, embedding:[], similarityScore:0);
void main() {
  test('Ranks relevant topic, rejects unrelated and empty questions', () {
    final docs = [chunk('a','Oil maintenance and safety inspection'),
      chunk('b','Dijkstra shortest path uses tentative distances'),
      chunk('c','E-104 means coolant failure')];
    expect(rankKnowledgeChunks(docs, 'Explain Dijkstra shortest path').first.id, 'b');
    expect(rankKnowledgeChunks(docs, 'What does E-104 mean').first.id, 'c');
    expect(rankKnowledgeChunks(docs, 'photosynthesis chlorophyll'), isEmpty);
    expect(rankKnowledgeChunks(docs, 'what is the'), isEmpty);
  });
  test('Duplicate excerpts do not consume context budget', () {
    expect(rankKnowledgeChunks([chunk('a','Dijkstra paths'),chunk('b','Dijkstra paths')], 'Dijkstra'), hasLength(1));
  });
}
''')
