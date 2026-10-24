import os
import uuid
import sqlite3
from typing import Dict, Any, List, Optional, TypedDict
from sqlalchemy.orm import Session
from app.db.models import EquipmentModel, KnowledgePackageModel, AiProviderModel
from app.schemas.schemas import ChatResponse, CitationResponse
from app.services.storage import storage_service
from app.ai.tools import AuthorizedTools
from app.ai.gemini_adapter import GeminiAdapter
from app.ai.nvidia_adapter import NvidiaNimAdapter
from app.config import settings

# ===========================================================================
# LangGraph Typed State Specification
# ===========================================================================
class EdgeRagAgentState(TypedDict):
    request_id: str
    equipment_id: str
    equipment_name: str
    user_query: str
    current_search_query: str
    query_attempt: int
    retrieved_chunks: List[Dict[str, Any]]
    evidence_status: str             # SUFFICIENT | INSUFFICIENT
    selected_tools: List[str]
    provider: str
    generated_answer: str
    verified_citations: List[Dict[str, Any]]
    final_status: str                # SUCCESS | INSUFFICIENT_EVIDENCE | ERROR
    observable_events: List[str]
    error: Optional[str]

# ===========================================================================
# Helper: Cosine vector similarity & query embedding
# ===========================================================================
def _search_equipment_sqlite(storage_path: str, query: str, limit: int = 6, equipment_id=None) -> List[Dict[str, Any]]:
    import tempfile
    import zipfile
    from app.ai.retrieval import rank_chunks, rank_hybrid
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
        vectors = None
        try:
            columns = {r[1] for r in conn.execute("PRAGMA table_info(manuals)")}
            revision = "m.revision" if "revision" in columns else "NULL"
            rows = conn.execute(f"""
                SELECT c.id, c.manual_id, m.title, c.page_number, c.chunk_text, {revision}
                FROM chunks c JOIN manuals m ON c.manual_id = m.id
                WHERE (? IS NULL OR c.equipment_id = ?)
            """, (equipment_id, equipment_id)).fetchall()
            tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if "metadata" in tables:
                backend = conn.execute("SELECT value FROM metadata WHERE key='embedding_backend'").fetchone()
                if backend and backend[0] == "minilm-onnx-meanpool-v1":
                    import struct
                    blobs = dict(conn.execute("SELECT chunk_id, embedding_bytes FROM embeddings"))
                    if all(row[0] in blobs and len(blobs[row[0]]) == 1536 for row in rows):
                        vectors = [struct.unpack("<384f", blobs[row[0]]) for row in rows]
        finally:
            conn.close()
    chunks = [dict(zip(("chunk_id", "manual_id", "manual_title", "page_number", "chunk_text", "manual_revision"), row)) for row in rows]
    if vectors is not None:
        try:
            from src.embedder import get_embedder
            return rank_hybrid(chunks, query, vectors, get_embedder().embed_text(query), limit)
        except (ImportError, RuntimeError):
            pass  # Explicit lexical fallback for hosts without the encoder assets.
    return rank_chunks(chunks, query, limit)

# ===========================================================================
# The 7 LangGraph Nodes
# ===========================================================================
def planner_node(state: EdgeRagAgentState, db: Session) -> EdgeRagAgentState:
    events = list(state.get("observable_events", []))
    events.append(f"[PLANNER] Identified equipment: {state['equipment_name']} (UUID: {state['equipment_id'][:8]}...)")
    events.append(f"[PLANNER] Initializing retrieval target for prompt: \"{state['user_query']}\"")

    state["observable_events"] = events
    state["current_search_query"] = state["user_query"]
    import re
    if re.match(r"^(explain (it|that)|why|how so|give (me )?an? example|continue|what about)", state["user_query"], re.I):
        previous = [m["content"] for m in state.get("history", []) if m.get("role") == "user"]
        if previous:
            state["current_search_query"] = previous[-1]
    state["query_attempt"] = 1
    return state

def retriever_node(state: EdgeRagAgentState, db: Session) -> EdgeRagAgentState:
    events = list(state["observable_events"])
    attempt = state.get("query_attempt", 1)
    events.append(f"[RETRIEVER] Ranking manual passages with hybrid retrieval: \"{state['current_search_query']}\"")



    # Locate active package for equipment
    pkg = db.query(KnowledgePackageModel).filter(
        KnowledgePackageModel.equipment_id == state["equipment_id"]
    ).order_by(KnowledgePackageModel.created_at.desc()).first()

    chunks = []
    if pkg:
        chunks = _search_equipment_sqlite(pkg.storage_path, state["current_search_query"], limit=6, equipment_id=state["equipment_id"])
        for chunk in chunks:
            chunk["package_version"] = pkg.version
        events.append(f"[RETRIEVER] Retrieved {len(chunks)} chunks from package {pkg.package_file_name}")
    else:
        events.append("[RETRIEVER] No published knowledge package found for this equipment")

    state["retrieved_chunks"] = chunks
    state["observable_events"] = events
    return state

def evidence_checker_node(state: EdgeRagAgentState) -> EdgeRagAgentState:
    from app.ai.evidence import sufficient
    events = list(state["observable_events"])
    chunks = state.get("retrieved_chunks", [])

    if sufficient(chunks, state.get("search_base", state["user_query"])):
        events.append(f"[EVIDENCE] Relevant evidence retrieved (Top score: {chunks[0]['similarity_score']:.2f})")
        state["evidence_status"] = "SUFFICIENT"
    else:
        score_disp = f"{chunks[0]['similarity_score']:.2f}" if chunks else "0.00"
        events.append(f"[EVIDENCE] Insufficient score ({score_disp}). Evaluating query rewrite eligibility.")
        state["evidence_status"] = "INSUFFICIENT"

    state["observable_events"] = events
    return state

def query_rewriter_node(state: EdgeRagAgentState) -> EdgeRagAgentState:
    events = list(state["observable_events"])
    current_attempt = state.get("query_attempt", 1)
    next_attempt = current_attempt + 1

    # Formulate augmented query with technical terminology
    base = state["user_query"]
    from app.ai.evidence import rewrite_query
    rewritten = rewrite_query(state.get("search_base", base), next_attempt, equipment_name=state.get("equipment_name"))
    events.append(f"[QUERY_REWRITE] Attempt #{next_attempt}: Augmented query to \"{rewritten}\"")

    state["current_search_query"] = rewritten
    state["query_attempt"] = next_attempt
    state["observable_events"] = events
    return state

def tool_controller_node(state: EdgeRagAgentState, tools: AuthorizedTools) -> EdgeRagAgentState:
    events = list(state["observable_events"])
    spec = tools.get_equipment_spec(state["equipment_id"])
    events.append(f"[TOOL] Verified machine specification: {spec.get('name')} ({spec.get('model_number')})")
    state["observable_events"] = events
    return state

def reasoner_node(state: EdgeRagAgentState, db: Session, ai_mode: str) -> EdgeRagAgentState:
    events = list(state["observable_events"])
    chunks = state.get("retrieved_chunks", [])

    if not chunks or state.get("evidence_status") != "SUFFICIENT":
        state["retrieved_chunks"] = []
        events.append("[REASONER] Insufficient relevant manual evidence; generation skipped")
        state["observable_events"] = events
        state["generated_answer"] = "I could not find enough supporting manual evidence after searching. Please provide the exact error code, symptom, or model number, or upload the relevant manual. I won't guess a procedure."
        state["provider"] = "Deterministic Evidence Guard"
        return state

    from app.ai.provider_gateway import generate
    cloud_invoked = False
    if ai_mode in ["ONLINE_AI", "SMART_AUTO"]:
        providers = db.query(AiProviderModel).filter(AiProviderModel.is_active == True).all()
        configured = []
        for p in providers:
            if p.api_key_encrypted:
                model = settings.NVIDIA_NIM_MODEL if (p.provider_id == "nvidia" and p.default_model == "meta/llama-3.2-11b-vision-instruct") else p.default_model
                configured.append((p.provider_id, p.api_key_encrypted, model))
        known = {p.provider_id for p in providers}
        if "gemini" not in known and settings.GEMINI_API_KEY:
            configured.append(("gemini", settings.GEMINI_API_KEY, "gemini-flash-latest"))
        if "nvidia" not in known and settings.NVIDIA_NIM_API_KEY:
            configured.append(("nvidia", settings.NVIDIA_NIM_API_KEY, settings.NVIDIA_NIM_MODEL))
        configured.sort(key=lambda p: {"nvidia": 0, "gemini": 1}.get(p[0], 2))
        for provider, key, model in configured:
            try:
                if state.get("_on_event"):
                    state["_on_event"]("status", {"message": f"Writing an answer with {provider} ({model})..."})
                    state["_on_event"]("reset", {})
                answer = generate(provider, key, model, state["user_query"], chunks,
                    on_token=(lambda token: state["_on_event"]("delta", {"text": token})) if state.get("_on_event") else None,
                    history=state.get("history", []))
                state["generated_answer"] = answer
                state["provider"] = f"{provider} · {model}"
                cloud_invoked = True
                break
            except Exception as exc:
                events.append(f"[REASONER] {provider}: {type(exc).__name__}; provider unavailable")

    if not cloud_invoked and ai_mode == "ONLINE_AI":
        state["generated_answer"] = "Online AI is unavailable. Check your provider key, selected model, quota, and connection."
        state["provider"] = "Online provider unavailable"
        state["retrieved_chunks"] = []
        state["final_status"] = "ERROR"
        state["observable_events"] = events
        return state

    if not cloud_invoked:
        events.append("[REASONER] Executing grounded offline synthesis from top verified manual chunks")
        state["generated_answer"] = _synthesize_grounded_text(state["user_query"], chunks)
        state["provider"] = "Deterministic RAG Synthesizer"

    state["observable_events"] = events
    return state

def verifier_node(state: EdgeRagAgentState) -> EdgeRagAgentState:
    events = list(state["observable_events"])
    answer = state.get("generated_answer", "")
    chunks = state.get("retrieved_chunks", [])

    verified = []
    for c in chunks:
        tag = f"[Source {c['chunk_id']}]"
        if tag in answer:
            verified.append(c)


    events.append(f"[VERIFIER] Verified {len(verified)} source page citations against active manual chunks")
    state["verified_citations"] = verified
    state["observable_events"] = events
    return state

def final_responder_node(state: EdgeRagAgentState) -> ChatResponse:
    events = list(state["observable_events"])
    events.append("[RESULT] Emitting verified answer with verifiable manual page citations")

    citations_resp = [
        CitationResponse(
            chunk_id=c["chunk_id"],
            manual_id=c["manual_id"],
            manual_title=c.get("manual_title", "Technical Manual"),
            page_number=c["page_number"],
            similarity_score=float(c.get("similarity_score", 0.0)),
            snippet=c["chunk_text"],
            manual_revision=c.get("manual_revision"),
            package_version=c.get("package_version"),
        )
        for c in state.get("verified_citations", [])
    ]

    return ChatResponse(
        answer=state["generated_answer"],
        citations=citations_resp,
        provider_used=state.get("provider", "LangGraph Workflow"),
        status="ERROR" if state.get("final_status") == "ERROR" else ("SUCCESS" if state.get("verified_citations") else "INSUFFICIENT_EVIDENCE"),
        execution_trace=events,
        evidence_status=("MANUAL_SUPPORTED" if state.get("verified_citations") else
                         "GENERAL_GUIDANCE" if state.get("evidence_status") == "SUFFICIENT" else "INSUFFICIENT"),
    )

def _synthesize_grounded_text(question: str, chunks: List[Dict[str, Any]]) -> str:
    top = chunks[0]
    result = f"According to technical manual specifications ({top.get('manual_title', 'Manual')}, [Source {top['chunk_id']}]):\n\n"
    result += f"{top['chunk_text']}\n\n"
    if len(chunks) > 1:
        second = chunks[1]
        result += f"Additional relevant excerpt is documented in [Source {second['chunk_id']}]:\n"
        result += f"{second['chunk_text'][:250]}..."
    return result

# ===========================================================================
# LangGraph Workflow Orchestrator
# ===========================================================================
def execute_langgraph_chat(
    question: str,
    equipment_id: str,
    ai_mode: str,
    db: Session,
    on_event=None,
    history=None,
) -> ChatResponse:
    """Executes the bounded planner/retriever/reasoner state machine."""
    eq = db.query(EquipmentModel).filter(EquipmentModel.id == equipment_id).first()
    equipment_name = eq.name if eq else "Industrial Machine"

    # 1. Initialize State
    state: EdgeRagAgentState = {
        "request_id": str(uuid.uuid4()),
        "equipment_id": equipment_id,
        "equipment_name": equipment_name,
        "user_query": question,
        "current_search_query": question,
        "query_attempt": 1,
        "retrieved_chunks": [],
        "evidence_status": "INSUFFICIENT",
        "selected_tools": ["get_equipment_spec"],
        "provider": "",
        "generated_answer": "",
        "verified_citations": [],
        "final_status": "PENDING",
        "observable_events": [],
        "error": None,
    }

    state["_on_event"] = on_event
    state["history"] = history or []
    if on_event:
        on_event("status", {"message": "Searching your documentsÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦"})
    tools = AuthorizedTools(db)

    # 2. State Machine Transitions
    # Step A: Planner
    state = planner_node(state, db)

    # Step B: Retrieval Loop (Bounded by max 2 attempts)
    state["search_base"] = state["current_search_query"]
    max_retries = 3
    while state["query_attempt"] <= max_retries:
        state = retriever_node(state, db)
        state = evidence_checker_node(state)
        if state["evidence_status"] == "SUFFICIENT" or state["query_attempt"] >= max_retries:
            break
        # Query rewrite conditional edge
        state = query_rewriter_node(state)

    # Step C: Tool Controller
    state = tool_controller_node(state, tools)

    # Step D: Reasoner
    if on_event:
        on_event("status", {"message": f"Found {len(state['retrieved_chunks'])} relevant passages"})
    state = reasoner_node(state, db, ai_mode)

    # Step E: Verifier
    if on_event:
        on_event("status", {"message": "Checking source referencesÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦"})
    state = verifier_node(state)

    # Step F: Final Response
    return final_responder_node(state)
