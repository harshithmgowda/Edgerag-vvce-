from pathlib import Path
p=Path('services/api/app/workers/tasks.py');s=p.read_text().replace('f"v-{job.id}"','f"v-{job.id.replace(chr(45), chr(0))[:24]}"')
# Keep a short unique version within the database column's 32-character limit.
s=s.replace('job.id.replace(chr(45), chr(0))[:24]', "job.id.replace('-', '')[:24]")
p.write_text(s)
p=Path('scripts/rebuild_knowledge.py');p.write_text('''"""Rebuild equipment packages without replacing existing package files.
Run from services/api: venv/Scripts/python ../../scripts/rebuild_knowledge.py
"""
import os
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT / "services/api")
sys.path.insert(0, str(ROOT / "services/api"))
from app.db.database import SessionLocal
from app.db.models import EquipmentModel, ManualModel, ProcessingJobModel
from app.workers.tasks import execute_processing_pipeline


def main():
    jobs = []
    with SessionLocal() as db:
        for equipment in db.query(EquipmentModel).all():
            manual = db.query(ManualModel).filter(ManualModel.equipment_id == equipment.id,
                ManualModel.status == "PROCESSED").first()
            if manual is None:
                continue
            job = ProcessingJobModel(equipment_id=equipment.id, manual_id=manual.id, status="QUEUED")
            db.add(job)
            db.commit()
            jobs.append((job.id, equipment.id))
    failures = 0
    for job_id, equipment_id in jobs:
        execute_processing_pipeline(job_id)
        with SessionLocal() as db:
            job = db.get(ProcessingJobModel, job_id)
            print(equipment_id, job.status, "chunks:", job.total_chunks, job.error_message or "")
            failures += job.status != "SUCCEEDED"
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
''')
