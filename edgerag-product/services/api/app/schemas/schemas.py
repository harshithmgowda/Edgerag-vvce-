from datetime import datetime
from typing import List, Optional, Dict
from pydantic import BaseModel, Field

# Health
class HealthStatus(BaseModel):
    status: str
    database: str
    redis: str
    storage: str
    version: str

# Auth
class LoginRequest(BaseModel):
    username: str
    password: str

class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    role: str = "ADMIN"

class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    role: str
    created_at: datetime

    class Config:
        from_attributes = True

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse

# Equipment
class EquipmentCreate(BaseModel):
    name: str
    model_number: str
    manufacturer: str
    serial_number: str
    description: Optional[str] = None

class EquipmentUpdate(BaseModel):
    name: Optional[str] = None
    model_number: Optional[str] = None
    manufacturer: Optional[str] = None
    serial_number: Optional[str] = None
    description: Optional[str] = None

class EquipmentResponse(BaseModel):
    id: str
    name: str
    model_number: str
    manufacturer: str
    serial_number: str
    description: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

# Manuals
class ManualResponse(BaseModel):
    id: str
    equipment_id: str
    title: str
    revision: str
    file_name: str
    file_size_bytes: int
    page_count: int
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class ManualUploadResponse(BaseModel):
    manual_id: str
    job_id: str
    status: str

# Processing Jobs
class ProcessingJobResponse(BaseModel):
    id: str
    manual_id: str
    equipment_id: str
    status: str
    stage: str
    progress_percentage: int
    total_pages: Optional[int] = None
    total_chunks: Optional[int] = None
    error_message: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# Knowledge Packages
class KnowledgePackageResponse(BaseModel):
    id: str
    equipment_id: str
    version: str
    package_file_name: str
    file_size_bytes: int
    sha256_hash: str
    chunk_count: int
    encoder_model: str
    vector_dimension: int
    created_at: datetime

    class Config:
        from_attributes = True

# Devices
class DeviceRegisterRequest(BaseModel):
    device_identifier: str
    device_name: str
    model: str
    os_version: str

class DeviceRegisterResponse(BaseModel):
    device_id: str
    token: str

class DeviceHeartbeatRequest(BaseModel):
    device_id: str
    installed_packages: Optional[Dict[str, str]] = None

class DeviceHeartbeatResponse(BaseModel):
    acknowledged: bool
    server_time: datetime

class DeviceResponse(BaseModel):
    id: str
    device_identifier: str
    device_name: str
    model: str
    os_version: str
    status: str
    last_heartbeat: datetime
    last_sync: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

# Sync
class SyncCheckRequest(BaseModel):
    device_id: str
    installed_packages: Dict[str, str]

class SyncCheckResponse(BaseModel):
    available_updates: List[KnowledgePackageResponse]

class IncidentSubmission(BaseModel):
    id: str
    equipment_id: str
    title: str
    description: str
    severity: str
    recorded_offline_at: datetime
    linked_manual_page: Optional[int] = None
    citation_chunk_id: Optional[str] = None

class IncidentSyncPayload(BaseModel):
    device_id: str
    sync_timestamp: datetime
    incidents: List[IncidentSubmission]

class IncidentSyncResult(BaseModel):
    total_received: int
    accepted_count: int
    duplicate_count: int
    rejected_count: int
    synced_ids: List[str]

# Incidents
class IncidentResponse(BaseModel):
    id: str
    equipment_id: str
    title: str
    description: str
    severity: str
    status: str
    device_id: Optional[str] = None
    recorded_offline_at: datetime
    review_notes: Optional[str] = None
    reviewer_id: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

class IncidentReviewUpdate(BaseModel):
    status: str
    review_notes: str

# AI Providers
class AiProviderResponse(BaseModel):
    provider_id: str
    display_name: str
    is_configured: bool
    default_model: str
    is_active: bool
    masked_key: Optional[str] = None

class AiProviderConfig(BaseModel):
    provider_id: str
    api_key: str
    model_name: str
    is_active: bool = True

class AiProviderTestResult(BaseModel):
    provider_id: str
    success: bool
    message: str
    latency_ms: int

# Chat & Citations
class CitationResponse(BaseModel):
    chunk_id: str
    manual_id: str
    manual_title: Optional[str] = None
    page_number: int
    similarity_score: float
    snippet: str
    manual_revision: Optional[str] = None
    package_version: Optional[str] = None

class ChatTurn(BaseModel):
    role: str
    content: str = Field(max_length=4000)


class ChatRequest(BaseModel):
    question: str
    equipment_id: str
    ai_mode: str = "SMART_AUTO"
    history: List[ChatTurn] = Field(default_factory=list, max_length=6)
    provider_id: Optional[str] = "gemini"

class ChatResponse(BaseModel):
    answer: str
    citations: List[CitationResponse]
    provider_used: str
    status: str
    execution_trace: List[str]
    evidence_status: str = "NEEDS_REVIEW"
