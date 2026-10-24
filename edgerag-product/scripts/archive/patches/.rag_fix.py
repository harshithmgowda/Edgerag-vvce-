from pathlib import Path
root = Path.cwd()
p = root/'services/api/app/ai/retrieval.py'
p.write_text('''"""Portable lexical retrieval; never compare incompatible embedding spaces."""
import math
import re
from collections import Counter

STOP = set("a an the is are was were be been to of for in on and or with what which how do does can i me my please explain tell about this that it from by".split())

def terms(text):
    return [t for t in re.findall(r"[^\\W_]+(?:[-.][^\\W_]+)*", text.lower()) if t not in STOP]

def rank_chunks(chunks, query, limit=6):
    query_terms = set(terms(query))
    if not query_terms or not chunks:
        return []
    docs = [Counter(terms(c["chunk_text"])) for c in chunks]
    lengths = [sum(d.values()) for d in docs]
    avg = sum(lengths) / len(docs) or 1
    df = Counter(t for d in docs for t in d)
    ranked = []
    for chunk, doc, length in zip(chunks, docs, lengths):
        matched = query_terms.intersection(doc)
        if not matched:
            continue
        score = 0.0
        for term in matched:
            freq = doc[term]
            idf = math.log(1 + (len(docs) - df[term] + .5) / (df[term] + .5))
            score += idf * freq * 2.2 / (freq + 1.2 * (.25 + .75 * length / avg))
        coverage = len(matched) / len(query_terms)
        # Coverage is interpretable; BM25 is used only for ordering.
        if coverage < .25:
            continue
        ranked.append(dict(chunk, similarity_score=coverage, retrieval_score=score * coverage))
    ranked.sort(key=lambda c: (-c["retrieval_score"], c["chunk_id"]))
    seen = set()
    result = []
    for chunk in ranked:
        key = (chunk["manual_id"], chunk["chunk_text"])
        if key not in seen:
            seen.add(key)
            result.append(chunk)
        if len(result) >= limit:
            break
    return result
''', encoding='utf-8')
p=root/'services/api/app/ai/agent.py'
s=p.read_text()
a=s.index('def _search_equipment_sqlite('); b=s.index('# ===========================================================================',a)
s=s[:a]+'''def _search_equipment_sqlite(storage_path: str, query: str, limit: int = 6, equipment_id=None) -> List[Dict[str, Any]]:
    import tempfile
    import zipfile
    from app.ai.retrieval import rank_chunks
    local_path = storage_service.get_file_path_or_bytes(storage_path)
    if not os.path.exists(local_path):
        return []
    with tempfile.TemporaryDirectory() as temp_dir:
        db_file = local_path
        if local_path.lower().endswith(".zip"):
            with zipfile.ZipFile(local_path) as archive:
                name = next((n for n in ("knowledge.sqlite", "knowledge.db") if n in archive.namelist()), None)
                if name is None:
                    raise ValueError("Knowledge package is missing its SQLite database")
                db_file = os.path.join(temp_dir, name)
                with open(db_file, "wb") as target:
                    target.write(archive.read(name))
        conn = sqlite3.connect(db_file)
        try:
            rows = conn.execute("""
                SELECT c.id, c.manual_id, m.title, c.page_number, c.chunk_text
                FROM chunks c JOIN manuals m ON c.manual_id = m.id
                WHERE (? IS NULL OR c.equipment_id = ?)
            """, (equipment_id, equipment_id)).fetchall()
        finally:
            conn.close()
    chunks = [dict(zip(("chunk_id", "manual_id", "manual_title", "page_number", "chunk_text"), row)) for row in rows]
    return rank_chunks(chunks, query, limit)

''' + s[b:]
s=s.replace('    query_vec = _embed_query_384d(state["current_search_query"])','')
s=s.replace('_search_equipment_sqlite(pkg.storage_path, query_vec, limit=4)','_search_equipment_sqlite(pkg.storage_path, state["current_search_query"], limit=6, equipment_id=state["equipment_id"])')
s=s.replace('Generating 384-d vector for search query:', 'Ranking manual passages by BM25 and query coverage:')
s=s.replace('rewritten = f"{base} technical maintenance troubleshooting procedure safety diagram"','rewritten = base  # Preserve user intent; unrelated maintenance terms pollute retrieval.')
s=s.replace('    if not chunks:\n        state["generated_answer"]', '    if not chunks or state.get("evidence_status") != "SUFFICIENT":\n        state["retrieved_chunks"] = []\n        events.append("[REASONER] Insufficient relevant manual evidence; generation skipped")\n        state["observable_events"] = events\n        state["generated_answer"]',1)
s=s.replace('    if not verified and chunks:\n        verified = chunks[:2]\n','')
s=s.replace('        alt_tag = f"Page {c[\'page_number\']}"\n        if tag in answer or alt_tag in answer:', '        if tag in answer:')
s=s.replace('Additional safety and diagnostic guidance is documented in', 'Additional relevant excerpt is documented in')
p.write_text(s,encoding='utf-8')
