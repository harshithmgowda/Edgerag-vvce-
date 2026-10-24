import time
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import AiProviderModel
from app.schemas.schemas import (
    AiProviderResponse,
    AiProviderConfig,
    AiProviderTestResult,
    ChatRequest,
    ChatResponse,
)
from app.security.auth import get_current_user
from app.ai.agent import execute_langgraph_chat

router = APIRouter()

@router.get("/ai/providers", response_model=List[AiProviderResponse])
def list_ai_providers(db: Session = Depends(get_db)):
    providers = db.query(AiProviderModel).all()
    if not providers:
        # Default providers
        defaults = [
            ("nvidia", "NVIDIA NIM", "nvidia/nemotron-3-ultra-550b-a55b"),
            ("gemini", "Google Gemini", "gemini-flash-latest"),
            ("openai", "OpenAI GPT-4o", "gpt-4o-mini"),
            ("anthropic", "Anthropic Claude", "claude-3-5-sonnet"),
            ("groq", "Groq LPUs", "llama-3.1-70b-versatile"),
        ]
        for pid, name, model in defaults:
            p = AiProviderModel(
                provider_id=pid,
                display_name=name,
                default_model=model,
                api_key_encrypted=settings.NVIDIA_NIM_API_KEY if pid == "nvidia" else "",
                is_active=(pid in ("nvidia", "gemini")),
            )
            db.add(p)
        db.commit()
        providers = db.query(AiProviderModel).all()

    result = []
    for p in providers:
        if p.provider_id == "nvidia" and not p.api_key_encrypted and settings.NVIDIA_NIM_API_KEY:
            p.api_key_encrypted = settings.NVIDIA_NIM_API_KEY
            if p.default_model == "meta/llama-3.2-11b-vision-instruct":
                p.default_model = "nvidia/nemotron-3-ultra-550b-a55b"
            p.is_active = True
            db.commit()
        has_key = bool(p.api_key_encrypted)
        masked = f"{p.api_key_encrypted[:4]}...{p.api_key_encrypted[-4:]}" if has_key and len(p.api_key_encrypted) > 8 else None
        result.append(
            AiProviderResponse(
                provider_id=p.provider_id,
                display_name=p.display_name,
                is_configured=has_key,
                default_model=p.default_model,
                is_active=p.is_active,
                masked_key=masked,
            )
        )
    return result

@router.post("/ai/providers", response_model=AiProviderResponse)
def update_ai_provider(
    config: AiProviderConfig,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    provider = db.query(AiProviderModel).filter(AiProviderModel.provider_id == config.provider_id).first()
    if not provider:
        provider = AiProviderModel(
            provider_id=config.provider_id,
            display_name=config.provider_id.title(),
            default_model=config.model_name,
            is_active=config.is_active,
        )
        db.add(provider)

    if config.api_key and "..." not in config.api_key:
        provider.api_key_encrypted = config.api_key
    provider.default_model = config.model_name
    provider.is_active = config.is_active
    db.commit()
    db.refresh(provider)

    masked = f"{provider.api_key_encrypted[:4]}...{provider.api_key_encrypted[-4:]}" if provider.api_key_encrypted and len(provider.api_key_encrypted) > 8 else None
    return AiProviderResponse(
        provider_id=provider.provider_id,
        display_name=provider.display_name,
        is_configured=bool(provider.api_key_encrypted),
        default_model=provider.default_model,
        is_active=provider.is_active,
        masked_key=masked,
    )

@router.post("/ai/providers/{provider_id}/test", response_model=AiProviderTestResult)
def test_ai_provider(provider_id: str, db: Session = Depends(get_db)):
    start_time = time.time()
    provider = db.query(AiProviderModel).filter(AiProviderModel.provider_id == provider_id).first()
    if not provider or not provider.api_key_encrypted:
        return AiProviderTestResult(
            provider_id=provider_id,
            success=False,
            message="No API key configured for this provider",
            latency_ms=0,
        )

    from app.ai.provider_gateway import generate
    try:
        answer = generate(provider_id, provider.api_key_encrypted, provider.default_model,
            "What word is recorded in the test document? Respond with that word only.",
            [{"chunk_id": "connection-test", "manual_title": "Connection test", "page_number": 1, "chunk_text": "The recorded word is OK."}])
        return AiProviderTestResult(provider_id=provider_id, success=True,
            message=f"{provider_id}: model returned a valid answer", latency_ms=int((time.time()-start_time)*1000))
    except Exception as exc:
        return AiProviderTestResult(provider_id=provider_id, success=False,
            message=f"Connection failed: {exc}", latency_ms=int((time.time()-start_time)*1000))

@router.post("/ai/chat", response_model=ChatResponse)
def execute_chat(request: ChatRequest, db: Session = Depends(get_db)):
    result = execute_langgraph_chat(
        question=request.question,
        equipment_id=request.equipment_id,
        ai_mode=request.ai_mode,
        db=db,
        history=[turn.model_dump() for turn in request.history],
    )
    return result

@router.post("/ai/chat/stream")
def stream_chat(request: ChatRequest):
    import json
    import queue
    import threading
    from app.db.database import SessionLocal
    events = queue.Queue()
    def send(kind, data):
        events.put((kind, data))
    def run():
        try:
            with SessionLocal() as db:
                result = execute_langgraph_chat(request.question, request.equipment_id,
                    request.ai_mode, db, on_event=send,
                    history=[turn.model_dump() for turn in request.history])
                send("result", result.model_dump())
        except Exception:
            send("error", {"message": "The answer could not be completed. Check the backend and provider settings."})
        finally:
            send("done", {})
    def stream():
        threading.Thread(target=run, daemon=True).start()
        while True:
            try:
                kind, data = events.get(timeout=10)
            except queue.Empty:
                yield ": keep-alive\n\n"
                continue
            yield f"event: {kind}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"
            if kind == "done":
                break
    return StreamingResponse(stream(), media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})
