import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Boolean, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.db.database import Base

def generate_uuid() -> str:
    return str(uuid.uuid4())

class UserModel(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    username = Column(String(64), unique=True, nullable=False, index=True)
    email = Column(String(128), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(32), default="FIELD_ENGINEER", nullable=False)  # ADMIN, FIELD_ENGINEER
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class EquipmentModel(Base):
    __tablename__ = "equipment"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(128), nullable=False, index=True)
    model_number = Column(String(64), nullable=False)
    manufacturer = Column(String(64), nullable=False)
    serial_number = Column(String(64), unique=True, nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    manuals = relationship("ManualModel", back_populates="equipment", cascade="all, delete-orphan")
    packages = relationship("KnowledgePackageModel", back_populates="equipment", cascade="all, delete-orphan")
    incidents = relationship("IncidentModel", back_populates="equipment", cascade="all, delete-orphan")

class ManualModel(Base):
    __tablename__ = "manuals"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    equipment_id = Column(String(36), ForeignKey("equipment.id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    revision = Column(String(32), default="v1.0.0", nullable=False)
    file_name = Column(String(255), nullable=False)
    file_size_bytes = Column(Integer, nullable=False)
    page_count = Column(Integer, default=0, nullable=False)
    storage_path = Column(String(512), nullable=False)
    status = Column(String(32), default="UPLOADED", nullable=False)  # UPLOADED, PROCESSING, PROCESSED, FAILED
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    equipment = relationship("EquipmentModel", back_populates="manuals")
    jobs = relationship("ProcessingJobModel", back_populates="manual", cascade="all, delete-orphan")

class ProcessingJobModel(Base):
    __tablename__ = "processing_jobs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    manual_id = Column(String(36), ForeignKey("manuals.id"), nullable=False, index=True)
    equipment_id = Column(String(36), ForeignKey("equipment.id"), nullable=False, index=True)
    status = Column(String(32), default="QUEUED", nullable=False)  # QUEUED, RUNNING, SUCCEEDED, FAILED
    stage = Column(String(64), default="INIT", nullable=False)
    progress_percentage = Column(Integer, default=0, nullable=False)
    total_pages = Column(Integer, nullable=True)
    total_chunks = Column(Integer, nullable=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    completed_at = Column(DateTime, nullable=True)

    manual = relationship("ManualModel", back_populates="jobs")

class KnowledgePackageModel(Base):
    __tablename__ = "knowledge_packages"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    equipment_id = Column(String(36), ForeignKey("equipment.id"), nullable=False, index=True)
    version = Column(String(32), default="v1", nullable=False)
    package_file_name = Column(String(255), nullable=False)
    storage_path = Column(String(512), nullable=False)
    file_size_bytes = Column(Integer, nullable=False)
    sha256_hash = Column(String(64), nullable=False)
    chunk_count = Column(Integer, default=0, nullable=False)
    encoder_model = Column(String(64), default="all-MiniLM-L6-v2", nullable=False)
    vector_dimension = Column(Integer, default=384, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    equipment = relationship("EquipmentModel", back_populates="packages")

class DeviceModel(Base):
    __tablename__ = "devices"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    device_identifier = Column(String(128), unique=True, nullable=False, index=True)
    device_name = Column(String(128), nullable=False)
    model = Column(String(64), nullable=False)
    os_version = Column(String(64), nullable=False)
    status = Column(String(32), default="ACTIVE", nullable=False)  # ACTIVE, REVOKED
    last_heartbeat = Column(DateTime, default=datetime.utcnow, nullable=False)
    last_sync = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

class IncidentModel(Base):
    __tablename__ = "incidents"

    # Important: Mobile device generates permanent RFC-4122 V4 UUID
    id = Column(String(36), primary_key=True)
    equipment_id = Column(String(36), ForeignKey("equipment.id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    severity = Column(String(32), default="MEDIUM", nullable=False)  # LOW, MEDIUM, HIGH, CRITICAL
    status = Column(String(32), default="OPEN", nullable=False)  # OPEN, IN_REVIEW, RESOLVED, DISMISSED
    device_id = Column(String(36), nullable=True)
    recorded_offline_at = Column(DateTime, nullable=False)
    linked_manual_page = Column(Integer, nullable=True)
    citation_chunk_id = Column(String(64), nullable=True)
    review_notes = Column(Text, nullable=True)
    reviewer_id = Column(String(36), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    equipment = relationship("EquipmentModel", back_populates="incidents")

class AiProviderModel(Base):
    __tablename__ = "ai_providers"

    provider_id = Column(String(64), primary_key=True)
    display_name = Column(String(128), nullable=False)
    api_key_encrypted = Column(String(512), nullable=True)
    default_model = Column(String(128), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
