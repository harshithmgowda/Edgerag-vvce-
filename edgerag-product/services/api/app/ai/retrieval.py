"""Portable lexical retrieval; never compare incompatible embedding spaces."""
import math
import re
from collections import Counter

STOP = set("a an the is are was were be been to of for in on and or with what which how do does can i me my please explain tell about this that it from by give simple example examples describe detail detailed briefly briefly show using used would could should need want understand step steps please document documents manual explain explanation main key concept".split())

def terms(text):
    return [t for t in re.findall(r"[^\W_]+(?:[-.][^\W_]+)*", text.lower()) if t not in STOP]

def rank_chunks(chunks, query, limit=6):
    if re.search(r"\b(summarize|summary|overview|main topics|topics covered)\b", query.lower()):
        # A representative overview, sampled across manuals/pages rather than fabricated search relevance.
        groups = {}
        for chunk in sorted(chunks, key=lambda c: (c["manual_id"], c["page_number"], c["chunk_id"])):
            groups.setdefault(chunk["manual_id"], []).append(chunk)
        selected = []
        for group in groups.values():
            slots = max(1, limit // max(1, len(groups)))
            for index in range(slots):
                selected.append(dict(group[min(len(group)-1, index*len(group)//slots)], similarity_score=1.0, retrieval_score=1.0))
        return selected[:limit]
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
        if coverage < .5:
            continue
        ranked.append(dict(chunk, similarity_score=coverage, lexical_coverage=coverage, retrieval_score=score * coverage))
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


def rank_hybrid(chunks, query, vectors, query_vector, limit=6):
    lexical = rank_chunks(chunks, query, limit=len(chunks))
    lex = {c["chunk_id"]: c for c in lexical}
    scale = max((c["retrieval_score"] for c in lexical), default=1) or 1
    ranked = []
    for chunk, vector in zip(chunks, vectors):
        cosine = sum(a*b for a,b in zip(vector, query_vector))
        hit = lex.get(chunk["chunk_id"])
        if hit is None and cosine < .40:
            continue
        score = .6 * max(0, cosine) + .4 * (hit["retrieval_score"]/scale if hit else 0)
        ranked.append(dict(chunk, similarity_score=cosine, semantic_score=cosine,
                           lexical_coverage=hit.get("lexical_coverage", 0) if hit else 0, retrieval_score=score))
    ranked.sort(key=lambda c: (-c["retrieval_score"], c["chunk_id"]))
    result = []
    for candidate in ranked:
        words = set(terms(candidate["chunk_text"]))
        if any(len(words & set(terms(c["chunk_text"]))) / max(1,len(words | set(terms(c["chunk_text"])))) > .85 for c in result):
            continue
        result.append(candidate)
        if len(result) == limit:
            break
    return result
