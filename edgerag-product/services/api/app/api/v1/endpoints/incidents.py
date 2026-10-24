from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import IncidentModel
from app.schemas.schemas import IncidentResponse, IncidentReviewUpdate
from app.security.auth import get_current_user

router = APIRouter()

@router.get("/incidents", response_model=List[IncidentResponse])
def list_incidents(
    status: Optional[str] = None,
    equipment_id: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(IncidentModel)
    if status:
        query = query.filter(IncidentModel.status == status)
    if equipment_id:
        query = query.filter(IncidentModel.equipment_id == equipment_id)
    return query.order_by(IncidentModel.recorded_offline_at.desc()).all()

@router.get("/incidents/{incident_id}", response_model=IncidentResponse)
def get_incident(incident_id: str, db: Session = Depends(get_db)):
    inc = db.query(IncidentModel).filter(IncidentModel.id == incident_id).first()
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found")
    return inc

@router.patch("/incidents/{incident_id}/review", response_model=IncidentResponse)
def review_incident(
    incident_id: str,
    review_data: IncidentReviewUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    inc = db.query(IncidentModel).filter(IncidentModel.id == incident_id).first()
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found")

    inc.status = review_data.status
    inc.review_notes = review_data.review_notes
    inc.reviewer_id = current_user.id
    inc.reviewed_at = datetime.utcnow()

    db.commit()
    db.refresh(inc)
    return inc
