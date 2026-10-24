from pathlib import Path
r=Path.cwd()
for name in ['services/api/app/ai/retrieval.py','apps/mobile/lib/services/knowledge_retrieval.dart']:
 p=r/name;s=p.read_text().replace('coverage < .25','coverage < .5');p.write_text(s)
p=r/'apps/mobile/lib/services/agent_controller.dart';s=p.read_text().replace('>= 0.20','>= 0.50').replace(' < .25',' < .5').replace('const maxAttempts = 2','const maxAttempts = 1');p.write_text(s)
p=r/'services/api/app/ai/agent.py';s=p.read_text().replace('>= 0.20','>= 0.50').replace('max_retries = 2','max_retries = 1');p.write_text(s)
p=r/'tests/unit/test_rag_quality.py';s=p.read_text()+'''\n\ndef test_generic_word_match_is_not_sufficient_evidence():
    assert rank_chunks([chunk("a", "This problem concerns oil pressure")], "water jug problem") == []
''';p.write_text(s)
