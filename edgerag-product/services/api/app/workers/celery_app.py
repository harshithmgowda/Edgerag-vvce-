from celery import Celery
from app.config import settings

celery_app = Celery(
    "edgerag_workers",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=1800,  # 30 min hard limit for large industrial manuals
)

# Auto-discover tasks
celery_app.autodiscover_tasks(["app.workers"])
