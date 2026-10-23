from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from app.db.models import EquipmentModel, ManualModel, KnowledgePackageModel

class AuthorizedTools:
    """Safe, bounded tool controller for industrial diagnostic agent."""

    def __init__(self, db: Session):
        self.db = db

    def get_equipment_spec(self, equipment_id: str) -> Dict[str, Any]:
        """Tool: Fetch official manufacturer and model specifications."""
        eq = self.db.query(EquipmentModel).filter(EquipmentModel.id == equipment_id).first()
        if not eq:
            return {"error": "Equipment not found"}
        return {
            "name": eq.name,
            "model_number": eq.model_number,
            "manufacturer": eq.manufacturer,
            "serial_number": eq.serial_number,
            "description": eq.description,
        }

    def get_knowledge_package_status(self, equipment_id: str) -> Dict[str, Any]:
        """Tool: Check published knowledge versions and chunk counts."""
        pkg = self.db.query(KnowledgePackageModel).filter(
            KnowledgePackageModel.equipment_id == equipment_id
        ).order_by(KnowledgePackageModel.created_at.desc()).first()

        if not pkg:
            return {"status": "NO_PACKAGE_PUBLISHED"}
        return {
            "package_id": pkg.id,
            "version": pkg.version,
            "chunk_count": pkg.chunk_count,
            "encoder": pkg.encoder_model,
            "sha256": pkg.sha256_hash,
        }

    def verify_fault_code(self, code: str) -> Dict[str, Any]:
        """Tool: Checks if fault code format matches standard industrial prefixes (e.g. ERR, ALM, WRN)."""
        clean = code.upper().strip()
        is_standard = any(clean.startswith(prefix) for prefix in ["ERR", "ALM", "WRN", "FLT", "E-"])
        return {
            "code": clean,
            "is_standard_industrial_code": is_standard,
            "category": "CRITICAL_ALARM" if "ERR" in clean or "FLT" in clean else "DIAGNOSTIC_WARNING",
        }
