from pathlib import Path
p=Path('services/api/app/api/v1/endpoints/ai.py');s=p.read_text();a=s.index('    # Execute actual request to verify API key');b=s.index('@router.post("/ai/chat"',a);s=s[:a]+'''    from app.ai.provider_gateway import generate
    try:
        answer = generate(provider_id, provider.api_key_encrypted, provider.default_model,
            "What word is recorded in the test document? Respond with that word only.",
            [{"chunk_id": "connection-test", "manual_title": "Connection test", "page_number": 1, "chunk_text": "The recorded word is OK."}])
        return AiProviderTestResult(provider_id=provider_id, success=True,
            message=f"{provider_id}: model returned a valid answer", latency_ms=int((time.time()-start_time)*1000))
    except Exception as exc:
        return AiProviderTestResult(provider_id=provider_id, success=False,
            message=f"Connection failed: {exc}", latency_ms=int((time.time()-start_time)*1000))

''' +s[b:];s=s.replace('("gemini", "Google Gemini", "gemini-1.5-flash"),','("gemini", "Google Gemini", "gemini-flash-latest"),\n            ("nvidia", "NVIDIA NIM", "meta/llama-3.2-11b-vision-instruct"),');p.write_text(s,encoding='utf-8')
# Broader natural-language phrasing should not drown out the actual topic.
for filename in ['services/api/app/ai/retrieval.py','apps/mobile/lib/services/knowledge_retrieval.dart']:
 p=Path(filename);s=p.read_text();s=s.replace('this that it from by','this that it from by give simple example examples describe detail detailed briefly briefly show using used would could should need want understand step steps please document documents manual explain explanation main key concept');p.write_text(s,encoding='utf-8')
p=Path('services/api/app/ai/retrieval.py');s=p.read_text();s=s.replace('    query_terms = set(terms(query))','''    if re.search(r"\\b(summarize|summary|overview|main topics|topics covered)\\b", query.lower()):
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
    query_terms = set(terms(query))''');p.write_text(s)
p=Path('services/api/app/ai/agent.py');s=p.read_text();s=s.replace('    state["current_search_query"] = state["user_query"]','''    state["current_search_query"] = state["user_query"]
    import re
    if re.match(r"^(explain (it|that)|why|how so|give (me )?an? example|continue|what about)", state["user_query"], re.I):
        previous = [m["content"] for m in state.get("history", []) if m.get("role") == "user"]
        if previous:
            state["current_search_query"] = previous[-1]''');p.write_text(s,encoding='utf-8')
