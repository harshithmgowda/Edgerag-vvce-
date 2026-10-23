from pathlib import Path
p=Path('tests/unit/test_rag_pipeline.py');p.write_text('''import os
import sys
import sqlite3
import zipfile
from pathlib import Path
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "services/api"))
from app.ai import agent


def test_insufficient_evidence_does_not_invoke_provider():
    state = {"observable_events": [], "retrieved_chunks": [{"chunk_id": "x"}], "evidence_status": "INSUFFICIENT"}
    result = agent.reasoner_node(state, None, "ONLINE_AI")
    assert not result["retrieved_chunks"]
    assert result["provider"] == "Deterministic Evidence Guard"


def test_citations_are_exact_and_never_invented():
    chunks = [{"chunk_id": "a", "page_number": 1}, {"chunk_id": "b", "page_number": 1}]
    state = {"observable_events": [], "retrieved_chunks": chunks, "generated_answer": "Answer [Source b]"}
    assert agent.verifier_node(state)["verified_citations"] == [chunks[1]]
    state["generated_answer"] = "Answer [Page 1]"
    assert agent.verifier_node(state)["verified_citations"] == []


def test_search_legacy_package_and_equipment_scope(tmp_path, monkeypatch):
    database = tmp_path / "knowledge.db"
    conn = sqlite3.connect(database)
    conn.executescript("""CREATE TABLE manuals (id TEXT, title TEXT);
        CREATE TABLE chunks (id TEXT, manual_id TEXT, equipment_id TEXT, page_number INTEGER, chunk_text TEXT);
        INSERT INTO manuals VALUES ('m', 'Manual');
        INSERT INTO chunks VALUES ('a', 'm', 'eq', 2, 'Dijkstra shortest path algorithm');
        INSERT INTO chunks VALUES ('b', 'm', 'other', 3, 'Dijkstra shortest path algorithm');""")
    conn.close()
    archive = tmp_path / "package.zip"
    with zipfile.ZipFile(archive, 'w') as z:
        z.write(database, 'knowledge.db')
    monkeypatch.setattr(agent.storage_service, "get_file_path_or_bytes", lambda path: path)
    # Keep TemporaryDirectory in the writable test directory on sandboxed Windows.
    monkeypatch.setattr(__import__('tempfile'), 'tempdir', str(tmp_path))
    result = agent._search_equipment_sqlite(str(archive), 'Dijkstra shortest path', equipment_id='eq')
    assert [c['chunk_id'] for c in result] == ['a']
    assert agent._search_equipment_sqlite(str(archive), 'oil pressure', equipment_id='eq') == []
''')
