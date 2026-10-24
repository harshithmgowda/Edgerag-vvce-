"""Administrative deletion, including all packages containing removed manuals."""
from pathlib import Path
from fastapi import HTTPException
from app.config import settings
from app.db.models import ProcessingJobModel, KnowledgePackageModel
from app.services.storage import storage_service


def ensure_idle(db, equipment_id):
    if db.query(ProcessingJobModel).filter(
        ProcessingJobModel.equipment_id == equipment_id,
        ProcessingJobModel.status.in_(["QUEUED", "RUNNING"]),
    ).first():
        raise HTTPException(409, "Wait for active processing jobs to finish before deleting.")


def delete_records(db, records):
    """Quarantine local files before commit; restore them if the transaction fails."""
    import uuid
    moved = []
    remote = []
    root = Path(settings.LOCAL_STORAGE_DIR).resolve()
    try:
        for record in records:
            storage_path = getattr(record, "storage_path", None)
            if storage_path:
                candidate = Path(storage_service.get_file_path_or_bytes(storage_path)).resolve()
                if candidate.is_file():
                    if not candidate.is_relative_to(root):
                        raise HTTPException(400, "Stored file is outside the managed storage directory.")
                    quarantine = candidate.with_name(candidate.name + "." + uuid.uuid4().hex + ".deleted")
                    candidate.rename(quarantine)
                    moved.append((candidate, quarantine))
                elif not storage_service._use_local_fallback:
                    remote.append(storage_path)
            db.delete(record)
        db.commit()
    except Exception:
        db.rollback()
        for original, quarantine in reversed(moved):
            quarantine.rename(original)
        raise
    pending = 0
    for _, quarantine in moved:
        try:
            quarantine.unlink()
        except OSError:
            pending += 1
    for path in remote:
        try:
            bucket, key = path.split("/", 1)
            storage_service._minio_client.remove_object(bucket, key)
        except Exception:
            pending += 1
    return {"deleted": True, "cleanup_pending": pending}


def equipment_packages(db, equipment_id):
    return db.query(KnowledgePackageModel).filter(
        KnowledgePackageModel.equipment_id == equipment_id).all()
