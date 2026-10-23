from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import EquipmentModel
from app.schemas.schemas import EquipmentCreate, EquipmentUpdate, EquipmentResponse
from app.security.auth import get_current_user

router = APIRouter()

@router.get("/equipment", response_model=List[EquipmentResponse])
def list_equipment(db: Session = Depends(get_db)):
    return db.query(EquipmentModel).order_by(EquipmentModel.created_at.desc()).all()

@router.post("/equipment", response_model=EquipmentResponse, status_code=status.HTTP_201_CREATED)
def create_equipment(
    eq_in: EquipmentCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    existing = db.query(EquipmentModel).filter(EquipmentModel.serial_number == eq_in.serial_number).first()
    if existing:
        raise HTTPException(status_code=400, detail="Equipment with this serial number already registered")

    eq = EquipmentModel(
        name=eq_in.name,
        model_number=eq_in.model_number,
        manufacturer=eq_in.manufacturer,
        serial_number=eq_in.serial_number,
        description=eq_in.description,
    )
    db.add(eq)
    db.commit()
    db.refresh(eq)
    return eq

@router.get("/equipment/{equipment_id}", response_model=EquipmentResponse)
def get_equipment_by_id(equipment_id: str, db: Session = Depends(get_db)):
    eq = db.query(EquipmentModel).filter(EquipmentModel.id == equipment_id).first()
    if not eq:
        raise HTTPException(status_code=404, detail="Equipment not found")
    return eq

@router.patch("/equipment/{equipment_id}", response_model=EquipmentResponse)
def update_equipment(
    equipment_id: str,
    eq_update: EquipmentUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    eq = db.query(EquipmentModel).filter(EquipmentModel.id == equipment_id).first()
    if not eq:
        raise HTTPException(status_code=404, detail="Equipment not found")

    update_data = eq_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(eq, field, value)

    db.commit()
    db.refresh(eq)
    return eq

from app.security.auth import require_authenticated_admin
from app.services.deletion import ensure_idle, delete_records, equipment_packages

@router.delete("/equipment/{equipment_id}")
def delete_equipment(equipment_id: str, db: Session = Depends(get_db),
                  current_user=Depends(require_authenticated_admin)):
    entity = db.query(EquipmentModel).filter(EquipmentModel.id == equipment_id).first()
    if entity is None:
        raise HTTPException(404, "Equipment not found")
    ensure_idle(db, entity.id)
    # Delete children explicitly so their stored PDFs and ZIPs are removed too.
    return delete_records(db, [*entity.packages, *entity.manuals, entity])
