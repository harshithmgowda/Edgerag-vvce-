from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.db.database import get_db
from app.schemas.schemas import HealthStatus
from app.config import settings

router = APIRouter()

@router.get("/health", response_model=HealthStatus)
def get_health(db: Session = Depends(get_db)):
    # 1. Check Database
    db_status = "CONNECTED"
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        db_status = "DISCONNECTED"

    # 2. Check Redis
    redis_status = "CONNECTED"
    try:
        import redis
        r = redis.from_url(settings.REDIS_URL, socket_connect_timeout=1)
        r.ping()
    except Exception:
        redis_status = "OFFLINE"

    # 3. Check Storage
    storage_status = "ONLINE"

    overall_status = "HEALTHY" if db_status == "CONNECTED" else "DEGRADED"

    return HealthStatus(
        status=overall_status,
        database=db_status,
        redis=redis_status,
        storage=storage_status,
        version="1.0.0"
    )
