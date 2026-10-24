import os
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import KnowledgePackageModel
from app.schemas.schemas import KnowledgePackageResponse
from app.services.storage import storage_service

router = APIRouter()

@router.get("/packages", response_model=List[KnowledgePackageResponse])
def list_packages(equipment_id: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(KnowledgePackageModel)
    if equipment_id:
        query = query.filter(KnowledgePackageModel.equipment_id == equipment_id)
    return query.order_by(KnowledgePackageModel.created_at.desc()).all()

@router.get("/packages/{package_id}/download")
def download_package(package_id: str, db: Session = Depends(get_db)):
    pkg = db.query(KnowledgePackageModel).filter(KnowledgePackageModel.id == package_id).first()
    if not pkg:
        raise HTTPException(status_code=404, detail="Knowledge package not found")

    file_path = storage_service.get_file_path_or_bytes(pkg.storage_path)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Package file missing from storage")

    return FileResponse(
        path=file_path,
        media_type="application/zip",
        filename=pkg.package_file_name,
    )

from app.security.auth import require_authenticated_admin
from app.services.deletion import ensure_idle, delete_records, equipment_packages

@router.delete("/packages/{package_id}")
def delete_package(package_id: str, db: Session = Depends(get_db),
                  current_user=Depends(require_authenticated_admin)):
    entity = db.query(KnowledgePackageModel).filter(KnowledgePackageModel.id == package_id).first()
    if entity is None:
        raise HTTPException(404, "Package not found")
    ensure_idle(db, entity.equipment_id)
    return delete_records(db, [entity])
