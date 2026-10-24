export interface User {
  id: string;
  username: string;
  email: string;
  role: 'ADMIN' | 'FIELD_ENGINEER';
  created_at: string;
}

export interface Equipment {
  id: string;
  name: string;
  model_number: string;
  manufacturer: string;
  serial_number: string;
  description?: string;
  created_at: string;
}

export interface Manual {
  id: string;
  equipment_id: string;
  title: string;
  revision: string;
  file_name: string;
  file_size_bytes: number;
  page_count: number;
  status: 'UPLOADED' | 'PROCESSING' | 'PROCESSED' | 'FAILED';
  created_at: string;
}

export interface ProcessingJob {
  id: string;
  manual_id: string;
  equipment_id: string;
  status: 'QUEUED' | 'RUNNING' | 'SUCCEEDED' | 'FAILED';
  stage: 'INIT' | 'EXTRACTING_PAGES' | 'CHUNKING' | 'EMBEDDING' | 'GENERATING_SQLITE' | 'PACKAGING' | 'VERIFYING' | 'COMPLETED';
  progress_percentage: number;
  total_pages?: number;
  total_chunks?: number;
  error_message?: string;
  created_at: string;
  completed_at?: string;
}

export interface KnowledgePackage {
  id: string;
  equipment_id: string;
  version: string;
  package_file_name: string;
  file_size_bytes: number;
  sha256_hash: string;
  chunk_count: number;
  encoder_model: string;
  vector_dimension: number;
  created_at: string;
}

export interface Device {
  id: string;
  device_identifier: string;
  device_name: string;
  model: string;
  os_version: string;
  status: 'ACTIVE' | 'REVOKED';
  installed_package_versions?: Record<string, string>;
  last_heartbeat: string;
  last_sync?: string;
}

export interface Incident {
  id: string;
  equipment_id: string;
  title: string;
  description: string;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  status: 'OPEN' | 'IN_REVIEW' | 'RESOLVED' | 'DISMISSED';
  device_id?: string;
  recorded_offline_at: string;
  review_notes?: string;
  reviewer_id?: string;
  reviewed_at?: string;
  created_at: string;
}

export interface AiProvider {
  provider_id: string;
  display_name: string;
  is_configured: boolean;
  default_model: string;
  is_active: boolean;
  masked_key?: string;
}

export interface HealthStatus {
  status: string;
  database: string;
  redis: string;
  storage: string;
  version: string;
}
