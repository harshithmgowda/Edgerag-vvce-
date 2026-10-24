from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import KnowledgePackageModel, IncidentModel, DeviceModel
from app.schemas.schemas import (
    SyncCheckRequest,
    SyncCheckResponse,
    KnowledgePackageResponse,
    IncidentSyncPayload,
    IncidentSyncResult,
)

router = APIRouter()

@router.post("/sync/check", response_model=SyncCheckResponse)
def check_sync_updates(req: SyncCheckRequest, db: Session = Depends(get_db)):
    # Verify device is not revoked
    device = db.query(DeviceModel).filter(DeviceModel.id == req.device_id).first()
    if device and device.status == "REVOKED":
        raise HTTPException(status_code=403, detail="Device has been revoked from synchronizing knowledge")

    all_packages = db.query(KnowledgePackageModel).order_by(KnowledgePackageModel.created_at.desc()).all()
    updates = []

    # Map of latest package per equipment
    latest_by_equip = {}
    for pkg in all_packages:
        if pkg.equipment_id not in latest_by_equip:
            latest_by_equip[pkg.equipment_id] = pkg

    for equip_id, pkg in latest_by_equip.items():
        installed_version = req.installed_packages.get(equip_id)
        if installed_version != pkg.version:
            updates.append(KnowledgePackageResponse.model_validate(pkg))

    if device:
        device.last_sync = datetime.utcnow()
        db.commit()

    return SyncCheckResponse(available_updates=updates)

@router.post("/sync/incidents", response_model=IncidentSyncResult)
def sync_incidents(payload: IncidentSyncPayload, db: Session = Depends(get_db)):
    # Verify device
    device = db.query(DeviceModel).filter(DeviceModel.id == payload.device_id).first()
    if device and device.status == "REVOKED":
        raise HTTPException(status_code=403, detail="Device revoked from submitting incidents")

    accepted_count = 0
    duplicate_count = 0
    synced_ids = []

    for inc_in in payload.incidents:
        existing = db.query(IncidentModel).filter(IncidentModel.id == inc_in.id).first()
        if existing:
            duplicate_count += 1
            synced_ids.append(inc_in.id)
            continue

        new_incident = IncidentModel(
            id=inc_in.id,
            equipment_id=inc_in.equipment_id,
            title=inc_in.title,
            description=inc_in.description,
            severity=inc_in.severity,
            status="OPEN",
            device_id=payload.device_id,
            recorded_offline_at=inc_in.recorded_offline_at,
            linked_manual_page=inc_in.linked_manual_page,
            citation_chunk_id=inc_in.citation_chunk_id,
            created_at=datetime.utcnow(),
        )
        db.add(new_incident)
        accepted_count += 1
        synced_ids.append(inc_in.id)

    db.commit()

    if device:
        device.last_sync = datetime.utcnow()
        db.commit()

    return IncidentSyncResult(
        total_received=len(payload.incidents),
        accepted_count=accepted_count,
        duplicate_count=duplicate_count,
        rejected_count=0,
        synced_ids=synced_ids,
    )
