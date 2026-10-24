"""Bounded search reformulation and conservative evidence gating, not confidence."""
import re
from app.ai.retrieval import terms

EXPANSIONS = {
    "not draining": "drainage troubleshooting blockage drain pump waste water filter hose",
    "water stays": "drainage troubleshooting blockage drain pump waste water",
    "does not start": "power supply door switch start circuit breaker",
    "won't start": "power supply door switch start circuit breaker",
    "overheating": "overheating temperature cooling thermal fan heat sink",
    "vibration": "vibration unbalance balance alignment mounting transit bolts",
    "rpm": "rpm rotational speed motor velocity",
    "psi": "psi pressure bar regulator gauge valve",
    "leak": "leak seal gasket o-ring hose fitting",
    "shut off": "shutdown overload trip thermal cut-off safety limit",
}

def rewrite_query(query, attempt, equipment_name=None):
    normalized = query.lower().replace("’", "'")
    expanded = normalized
    for phrase, replacement in EXPANSIONS.items():
        expanded = expanded.replace(phrase, replacement)
    if attempt == 2 and expanded != normalized:
        return expanded
    prefix = f"{equipment_name} " if equipment_name else ""
    return (prefix + " ".join(dict.fromkeys(terms(expanded)))).strip() or query

def sufficient(chunks, question):
    if not chunks:
        return False
    if re.search(r"\b(summary|summarize|overview|topics covered)\b", question, re.I):
        return True
    # Technical codes must appear exactly; semantic similarity alone is unsafe for codes.
    codes = [t for t in terms(question) if any(c.isdigit() for c in t)]
    for chunk in chunks:
        text = chunk.get("chunk_text", "").lower()
        if codes and not all(code in terms(text) for code in codes):
            continue
        similarity = float(chunk.get("similarity_score", chunk.get("retrieval_score", 0)))
        lexical = float(chunk.get("lexical_coverage", similarity))
        semantic = float(chunk.get("semantic_score", similarity))
        if similarity >= 0.40 or lexical >= 0.40 or semantic >= 0.40:
            return True
    return False
