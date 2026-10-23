from datetime import datetime
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import DeviceModel
from app.schemas.schemas import (
    DeviceResponse,
    DeviceRegisterRequest,
    DeviceRegisterResponse,
    DeviceHeartbeatRequest,
    DeviceHeartbeatResponse,
)
from app.security.auth import get_current_user

router = APIRouter()

@router.get("/devices", response_model=List[DeviceResponse])
def list_devices(db: Session = Depends(get_db)):
    return db.query(DeviceModel).order_by(DeviceModel.last_heartbeat.desc()).all()

@router.post("/devices/register", response_model=DeviceRegisterResponse, status_code=status.HTTP_201_CREATED)
def register_device(req: DeviceRegisterRequest, db: Session = Depends(get_db)):
    device = db.query(DeviceModel).filter(DeviceModel.device_identifier == req.device_identifier).first()
    if not device:
        device = DeviceModel(
            device_identifier=req.device_identifier,
            device_name=req.device_name,
            model=req.model,
            os_version=req.os_version,
            status="ACTIVE",
            last_heartbeat=datetime.utcnow(),
        )
        db.add(device)
    else:
        device.device_name = req.device_name
        device.model = req.model
        device.os_version = req.os_version
        device.last_heartbeat = datetime.utcnow()

    db.commit()
    db.refresh(device)

    # Return persistent device pairing token
    return DeviceRegisterResponse(
        device_id=device.id,
        token=f"edgerag_dev_token_{device.id}",
    )

@router.post("/devices/heartbeat", response_model=DeviceHeartbeatResponse)
def device_heartbeat(req: DeviceHeartbeatRequest, db: Session = Depends(get_db)):
    device = db.query(DeviceModel).filter(DeviceModel.id == req.device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    if device.status == "REVOKED":
        raise HTTPException(status_code=403, detail="Device access has been revoked by administrator")

    device.last_heartbeat = datetime.utcnow()
    db.commit()

    return DeviceHeartbeatResponse(
        acknowledged=True,
        server_time=datetime.utcnow(),
    )

@router.post("/devices/{device_id}/revoke")
def revoke_device(device_id: str, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    device = db.query(DeviceModel).filter(DeviceModel.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    device.status = "REVOKED"
    db.commit()
    return {"status": "REVOKED", "device_id": device_id}
