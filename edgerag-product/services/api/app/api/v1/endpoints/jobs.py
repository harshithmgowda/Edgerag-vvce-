from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import ProcessingJobModel
from app.schemas.schemas import ProcessingJobResponse

router = APIRouter()

from uuid import UUID
from pathlib import Path
import json
from app.security.auth import require_authenticated_admin
from app.config import settings


@router.get("/jobs/{job_id}/extraction")
def extraction_report(job_id: UUID, db: Session = Depends(get_db),
                      user=Depends(require_authenticated_admin)):
    job = db.query(ProcessingJobModel).filter(ProcessingJobModel.id == str(job_id)).first()
    if not job:
        raise HTTPException(404, "Processing job not found")
    path = Path(settings.LOCAL_STORAGE_DIR) / "reports" / f"{job.id}.json"
    return {"manuals": json.loads(path.read_text(encoding="utf-8")) if path.is_file() else []}


@router.post("/jobs/{job_id}/retry", response_model=ProcessingJobResponse, status_code=202)
def retry_job(job_id: UUID, db: Session = Depends(get_db),
              user=Depends(require_authenticated_admin)):
    from app.workers.tasks import process_manual_task, execute_processing_pipeline
    import threading
    job = db.query(ProcessingJobModel).filter(ProcessingJobModel.id == str(job_id)).with_for_update().first()
    if not job:
        raise HTTPException(404, "Processing job not found")
    if job.status != "FAILED":
        raise HTTPException(409, "Only failed jobs can be retried")
    running = db.query(ProcessingJobModel).filter(ProcessingJobModel.equipment_id == job.equipment_id,
        ProcessingJobModel.status.in_(["QUEUED", "RUNNING"])).first()
    if running:
        raise HTTPException(409, "This equipment already has an active job")
    job.status, job.stage, job.progress_percentage = "QUEUED", "INIT", 0
    job.error_message, job.completed_at = None, None
    db.commit()
    db.refresh(job)
    try:
        process_manual_task.delay(job.id)
    except Exception:
        threading.Thread(target=execute_processing_pipeline, args=(job.id,), daemon=True).start()
    return job

@router.get("/jobs", response_model=List[ProcessingJobResponse])
def list_jobs(db: Session = Depends(get_db)):
    return db.query(ProcessingJobModel).order_by(ProcessingJobModel.created_at.desc()).all()

@router.get("/jobs/{job_id}", response_model=ProcessingJobResponse)
def get_job(job_id: str, db: Session = Depends(get_db)):
    job = db.query(ProcessingJobModel).filter(ProcessingJobModel.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Processing job not found")
    return job
