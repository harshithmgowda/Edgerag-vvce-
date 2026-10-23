import os
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import ManualModel, ProcessingJobModel, EquipmentModel
from app.schemas.schemas import ManualResponse, ManualUploadResponse
from app.services.storage import storage_service
from app.workers.tasks import process_manual_task, execute_processing_pipeline
from app.security.auth import get_current_user
from app.config import settings

router = APIRouter()

@router.get("/manuals", response_model=List[ManualResponse])
def list_manuals(equipment_id: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(ManualModel)
    if equipment_id:
        query = query.filter(ManualModel.equipment_id == equipment_id)
    return query.order_by(ManualModel.created_at.desc()).all()

@router.post("/manuals", response_model=ManualUploadResponse, status_code=status.HTTP_202_ACCEPTED)
async def upload_manual(
    file: UploadFile = File(...),
    equipment_id: str = Form(...),
    title: str = Form(...),
    revision: str = Form("v1.0.0"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    # Verify equipment exists
    eq = db.query(EquipmentModel).filter(EquipmentModel.id == equipment_id).first()
    if not eq:
        raise HTTPException(status_code=404, detail="Associated equipment not found")

    # Validate file extension
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF manuals are supported")

    # Read content & validate file size limit (50 MB)
    contents = await file.read()
    file_size = len(contents)
    if file_size > 50 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File size exceeds maximum allowable 50MB limit")

    # Upload to storage
    import io
    storage_path = storage_service.upload_file(
        bucket=settings.MINIO_BUCKET_MANUALS,
        object_name=f"{equipment_id}_{__import__('uuid').uuid4()}.pdf",
        file_data=io.BytesIO(contents),
        length=file_size,
        content_type="application/pdf"
    )

    # Create Manual record
    manual = ManualModel(
        equipment_id=equipment_id,
        title=title,
        revision=revision,
        file_name=file.filename,
        file_size_bytes=file_size,
        page_count=0,
        storage_path=storage_path,
        status="PROCESSING",
    )
    db.add(manual)
    db.commit()
    db.refresh(manual)

    # Create Processing Job record
    job = ProcessingJobModel(
        manual_id=manual.id,
        equipment_id=equipment_id,
        status="QUEUED",
        stage="INIT",
        progress_percentage=5,
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    # Schedule background processing: Try Celery first; if Redis not running, run synchronously
    try:
        process_manual_task.delay(job.id)
    except Exception:
        # Fallback to direct synchronous execution for local no-docker simplicity
        import threading
        thread = threading.Thread(target=execute_processing_pipeline, args=(job.id,))
        thread.daemon = True
        thread.start()

    return ManualUploadResponse(
        manual_id=manual.id,
        job_id=job.id,
        status="QUEUED"
    )

@router.get("/manuals/{manual_id}", response_model=ManualResponse)
def get_manual(manual_id: str, db: Session = Depends(get_db)):
    manual = db.query(ManualModel).filter(ManualModel.id == manual_id).first()
    if not manual:
        raise HTTPException(status_code=404, detail="Manual not found")
    return manual

from app.security.auth import require_authenticated_admin
from app.services.deletion import ensure_idle, delete_records, equipment_packages

@router.get("/manuals/{manual_id}/pages/{page_number}")
def preview_page(manual_id: str, page_number: int, excerpt: str = "",
                 db: Session = Depends(get_db), user=Depends(require_authenticated_admin)):
    from fastapi.responses import Response
    import fitz
    manual = db.query(ManualModel).filter(ManualModel.id == manual_id).first()
    if not manual:
        raise HTTPException(404, "Manual not found")
    path = storage_service.get_file_path_or_bytes(manual.storage_path)
    if not os.path.isfile(path):
        raise HTTPException(404, "Original PDF unavailable")
    with fitz.open(path) as pdf:
        if page_number < 1 or page_number > len(pdf):
            raise HTTPException(422, "Page number is outside this manual")
        page = pdf[page_number - 1]
        for rect in page.search_for(excerpt[:180])[:20] if excerpt else []:
            page.add_highlight_annot(rect)
        data = page.get_pixmap(matrix=fitz.Matrix(1.3, 1.3), alpha=False).tobytes("png")
    return Response(data, media_type="image/png", headers={"Cache-Control": "private, no-store"})

@router.delete("/manuals/{manual_id}")
def delete_manual(manual_id: str, db: Session = Depends(get_db),
                  current_user=Depends(require_authenticated_admin)):
    entity = db.query(ManualModel).filter(ManualModel.id == manual_id).first()
    if entity is None:
        raise HTTPException(404, "Manual not found")
    ensure_idle(db, entity.equipment_id)
    # Invalidate every older package; none may resurrect the deleted manual.
    return delete_records(db, [*equipment_packages(db, entity.equipment_id), entity])
