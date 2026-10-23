from pathlib import Path
r=Path.cwd()
p=r/'services/api/app/ai/agent.py';s=p.read_text();a=s.index('def _embed_query_384d');b=s.index('def _search_equipment_sqlite',a);s=s[:a]+s[b:];s=s.replace('import struct\n','');s=s.replace('    if not cloud_invoked:\n        events.append', '''    if not cloud_invoked and ai_mode == "ONLINE_AI":
        state["generated_answer"] = "Online AI is unavailable. Check your provider key, selected model, quota, and connection."
        state["provider"] = "Online provider unavailable"
        state["retrieved_chunks"] = []
        state["final_status"] = "ERROR"
        state["observable_events"] = events
        return state

    if not cloud_invoked:
        events.append''');s=s.replace('status="SUCCESS" if state.get("verified_citations") else "INSUFFICIENT_EVIDENCE",','status="ERROR" if state.get("final_status") == "ERROR" else ("SUCCESS" if state.get("verified_citations") else "INSUFFICIENT_EVIDENCE"),');p.write_text(s)
for filename in ['nvidia_adapter.py','gemini_adapter.py']:
 p=r/'services/api/app/ai'/filename;s=p.read_text();import re
 s=re.sub(r'candidate_models = \[model_name, [^\n]+', 'candidate_models = [model_name]',s)
 if filename=='nvidia_adapter.py':
  s=s.replace('return choices[0]["message"].get("content", "").strip()', 'text = (choices[0]["message"].get("content") or "").strip()\n                        if text:\n                            return text\n                        raise ValueError("NVIDIA returned an empty answer")')
 else:
  s=s.replace('return candidates[0]["content"]["parts"][0].get("text", "").strip()', 'text = "".join(part.get("text", "") for part in candidates[0]["content"]["parts"] if not part.get("thought")).strip()\n                        if text:\n                            return text\n                        raise ValueError("Gemini returned an empty answer")')
 p.write_text(s)
p=r/'apps/mobile/lib/services/agent_controller.dart';s=p.read_text().replace('      if (!cloudSuccess) {\n        providerUsed', '''      if (!cloudSuccess && aiMode == AiMode.onlineAi) {
        return AgentResult(answer: 'Online AI is unavailable. Check your provider key, selected model, quota, and connection.',
          citations: [], providerUsed: 'Online provider unavailable', executionTrace: trace.events, isSuccess: false);
      }
      if (!cloudSuccess) {
        providerUsed''');p.write_text(s)
