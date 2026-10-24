# MEMBER 3 — BACKEND, RAG AND INTEGRATION
Copy this entire file into your coding assistant.

You are the Backend/RAG Engineer and integration owner for EdgeRAG. Build the shared API, PDF-processing pipeline and portable knowledge packages.

## Shared project and team contract — read this first

Build EdgeRAG: an offline-first industrial equipment knowledge assistant. Headquarters registers equipment and uploads PDF manuals. A Python backend extracts text, attempts OCR, chunks passages, creates embeddings, and publishes portable SQLite knowledge packages. A Flutter Android app downloads packages over LAN, retrieves relevant passages offline, runs an installed local model when available, and records incidents for later synchronization. A Next.js website provides administration and browser chat.

This is a three-person hackathon rebuild:
- Member 1 owns apps/hq-web.
- Member 2 owns apps/mobile.
- Member 3 owns services/api, packages/rag-core, contracts, and root setup scripts.
Work only in your assigned directories. Do not overwrite other members' work. Do not create fake production records or pretend incomplete features work. Tests may use explicitly isolated fixtures.
Assume teammates are beginners: implement the work, explain commands and prerequisites, and leave a short handoff. Do not stop after producing a plan.
If this workspace contains an existing EdgeRAG implementation, inspect and reuse suitable code without deleting it. A fresh rebuild must use a separate directory; do not overwrite the original project.
Build one working vertical slice before optional features. No Docker requirement. Never commit secrets or model weights.

Member 3 publishes contracts/openapi.yaml, contracts/knowledge-package.md, and a small test package first. This contract is shared; do not independently invent endpoint names, field names, or package filenames. If a mismatch arises, report it in your handoff and coordinate with Member 3. Until the server is ready, build typed interfaces and clearly labeled test fixtures; production screens must show connection errors, not demo records.

### API agreement

Base URL: http://<HQ_HOST>:8000/api/v1. Web runs on port 3000.
Use NEXT_PUBLIC_API_BASE_URL for web and an editable HQ URL on Android. A physical phone uses the laptop's LAN IP, never localhost.
IDs are UUID strings; timestamps are ISO-8601 UTC strings. JSON properties use snake_case.
ADMIN and FIELD_ENGINEER are the user roles.
Errors: {"detail":"Useful explanation"}, with appropriate HTTP status.
Use Authorization: Bearer <token> for authenticated requests. Admin-only: create/delete equipment, upload/delete manuals, provider configuration, incident review. Device sync/download uses a registered device token. No anonymous admin fallback.

Entities (Member 3 must formalize these in OpenAPI):
- Equipment: id, name, model_number, manufacturer, serial_number, description (nullable), created_at.
- Manual: id, equipment_id, title, revision, file_name, file_size_bytes, page_count, status, created_at.
- Job: id, manual_id, equipment_id, status, stage, progress_percentage, total_pages (nullable), total_chunks (nullable), error_message (nullable), created_at, completed_at (nullable).
- Package: id, equipment_id, version, package_file_name, file_size_bytes, sha256_hash, chunk_count, encoder_model, vector_dimension, created_at.
- Citation: chunk_id, manual_id, manual_title, page_number, similarity_score, snippet.
- Incident: id, equipment_id, title, description, severity, recorded_offline_at; server adds status, device_id, created_at and review fields.
Manual status: UPLOADED | PROCESSING | PROCESSED | FAILED.
Job status: QUEUED | RUNNING | SUCCEEDED | FAILED.
Job stages: INIT | EXTRACTING_PAGES | CHUNKING | EMBEDDING | GENERATING_SQLITE | PACKAGING | COMPLETED.
Incident severity: LOW | MEDIUM | HIGH | CRITICAL.
Incident status: OPEN | IN_REVIEW | RESOLVED | DISMISSED.

Endpoints:
- GET /health -> {status,database,redis,storage,version}.
- POST /auth/login {username,password} -> {access_token,token_type:"bearer",user:{id,username,email,role,created_at}}.
- GET /auth/me -> user.
- GET /equipment -> Equipment[].
- POST /equipment {name,model_number,manufacturer,serial_number,description?} -> Equipment.
- DELETE /equipment/{id} -> {deleted:true,cleanup_pending:number}.
- GET /manuals?equipment_id=<optional UUID> -> Manual[].
- POST /manuals multipart fields file,equipment_id,title,revision -> 202 {manual_id,job_id,status:"QUEUED"}.
- DELETE /manuals/{id} -> {deleted:true,cleanup_pending:number}.
- GET /jobs and GET /jobs/{id} -> Job[] and Job respectively.
- POST /jobs/{id}/retry -> 202 {manual_id,job_id,status:"QUEUED"}; failed jobs only, admin-only, reject concurrent processing.
- GET /packages?equipment_id=<optional UUID> -> Package[].
- GET /packages/{id}/download -> ZIP bytes.
- POST /chat {question,equipment_id,ai_mode,history:[{role,content}]} -> {answer,citations: Citation[],provider_used,status,execution_trace:string[]}.
- ai_mode: SMART_AUTO | ONLINE_AI | OFFLINE_ONLY. Chat status: SUCCESS | INSUFFICIENT_EVIDENCE | ERROR.
- Optional later: POST /chat/stream, same request, SSE events status {message}, reset {}, delta {text}, result <full chat response>. Start with non-streaming chat.
- POST /devices/register {device_identifier,device_name,model,os_version} -> {device_id,token}. Require admin authorization for enrollment; use returned device token for sync.
- GET /devices -> device list for administrators.
- POST /sync/check {device_id,installed_packages:{equipmentId:version}} -> {available_updates:Package[]}.
- POST /sync/incidents {device_id,sync_timestamp,incidents:Incident[]} -> {total_received,accepted_count,duplicate_count,rejected_count,synced_ids:string[]}.
- GET /incidents -> server incidents; PATCH /incidents/{id} {status,review_notes} -> updated incident.
- GET /ai/providers -> [{provider_id,display_name,is_configured,default_model,is_active,masked_key}].
- POST /ai/providers {provider_id,api_key,model_name,is_active} -> provider status without raw key.
- POST /ai/providers/{id}/test -> {provider_id,success,message,latency_ms}.

### Offline package agreement

ZIP root must contain manifest.json and knowledge.sqlite.
SQLite schema:
- metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)
- manuals(id TEXT PRIMARY KEY, equipment_id TEXT, title TEXT, revision TEXT, page_count INTEGER)
- chunks(id TEXT PRIMARY KEY, manual_id TEXT, equipment_id TEXT, page_number INTEGER, chunk_text TEXT)
- embeddings(chunk_id TEXT PRIMARY KEY, embedding_bytes BLOB)

Store metadata embedding_backend=minilm-onnx-meanpool-v1.
Backend embeddings: all-MiniLM-L6-v2, 384 dimensions, normalized, float32 little-endian: exactly 1536 bytes per vector.
Manifest: schema_version:"1.0.0", package_id, equipment_id, equipment_name, version, generated_at, chunk_count, embedding_spec:{model_name:"all-MiniLM-L6-v2",dimension:384,normalized:true,similarity_metric:"cosine"}, manuals:[{manual_id,title,revision,page_count,chunk_count}], sqlite_checksum_sha256.
Package API provides the ZIP checksum; manifest provides the SQLite checksum.
Original PDF page numbers must survive chunking. Do not renumber after skipping empty pages.

### Product rules

Use Roboto for controls, Metropolis for branding, Open Sans for reading text. Bundle permitted fonts and licenses locally. Use a restrained Google-inspired design: blue actions, light neutral surfaces, clear hierarchy, rounded controls, accessible contrast, useful empty states. Avoid excessive gradients, glass effects, fake statistics, and decorative clutter.
AI answers use readable Markdown. Do not show raw chunk IDs or inline source tags in displayed, copied, or spoken answers. Keep citations separately in expandable source cards. Preserve technical values, tables, code and ordinary links when cleaning citation markers.
Show missing credentials, unavailable models, missing knowledge, and network failures honestly. Source-ID matching is provenance checking, not proof of factual accuracy.

## Your implementation

Own services/api, packages/rag-core, contracts, and root setup scripts. Do not change apps/hq-web or apps/mobile.
Before deeper implementation, publish the agreed OpenAPI schemas, example requests/responses, knowledge-package schema, .env.example and a tiny clearly labeled fixture package. Tell teammates the server base URL and any contract corrections.

Use Python, FastAPI, Pydantic, SQLAlchemy, PyMuPDF, RapidOCR, ONNX Runtime and a matching tokenizer. Use MySQL for application records; allow SQLite as an explicitly documented local-development option. Use local filesystem storage for the initial demo, with MinIO optional. Run natively without Docker.
Use a simple background-job runner for the first vertical slice; add Redis/Celery only after the pipeline works. Persist job status and handle failures/restarts honestly.

Implement all agreed endpoints. Provision the initial admin through a documented setup command reading credentials from environment/input, not a hardcoded source password. Hash passwords, issue expiring JWTs, enforce admin roles, validate device tokens, and reject unknown/revoked devices. Configure CORS for the intended web origin. Keep secrets out of responses and logs.

### PDF and RAG pipeline

- Accept PDFs up to a documented limit; validate input and equipment membership.
- Store uploads using unique manual IDs so a duplicate filename cannot overwrite another record.
- Preserve each original page number.
- Extract text with PyMuPDF; attempt local OCR on likely scanned pages.
- Do NOT reject an entire readable manual because a blank notes page or illustration has no OCR text. The old BOSCH manual failed on a lined notes page, page 39 of 40.
- Record which pages were skipped and why. Distinguish blank/diagram pages from unreadable scans; warn about incomplete extraction instead of claiming completeness.
- Reject a document with no useful recoverable text. Keep actionable page-level diagnostics for OCR dependency or recognition failures.
- Chunk around 224 model tokens with 32 overlap, preserving sentence/paragraph boundaries when possible.
- Generate actual all-MiniLM-L6-v2 embeddings using local ONNX weights and the matching tokenizer. Mean-pool with the attention mask, normalize, verify 384 dimensions, serialize little-endian float32.
- Missing embedding assets must produce setup instructions, never random/hash-based fake vectors.
- Build packages containing all successfully processed manuals for the selected equipment plus the current successfully extracted manual.
- Write the exact SQLite schema and manifest in the shared contract; compute SQLite and ZIP checksums.
- Publish only a fully valid package. Preserve existing good packages if processing fails.
- Keep job and manual statuses consistent, set terminal timestamps and meaningful errors, and support retry without duplicate concurrent jobs.

### Retrieval and chat

Equipment-scoped hybrid search: lexical/BM25 plus cosine similarity over compatible MiniLM vectors. Start with exact vector scans for small equipment collections and document the scaling limit. No Chroma is required for parity with the prototype.
Configure and test ONE cloud provider first, with model ID provided through settings/environment; support additional adapters later. Do not assume a model exists merely because an old README names it.
Build a bounded workflow: identify equipment -> retrieve -> evidence check -> optional controlled equipment lookup -> generate -> verify source IDs -> response.
If using LangGraph, actually compile/use StateGraph; otherwise honestly describe a Python state workflow.
Use a meaningful evidence policy; do not assign every weak match a high confidence score.
If evidence is insufficient, return INSUFFICIENT_EVIDENCE. Citation matching validates provenance, not factual truth.
Keep source markers for internal provenance if needed but return clean answer prose and separate citations. Never remove ordinary technical values or Markdown links.
OFFLINE_ONLY on the server can return clearly labeled retrieved excerpts if there is no configured server-local generator; do not impersonate an LLM.
Start with POST /chat; implement the exact shared SSE protocol later.

### Sync, deletion and reliability

Version-check equipment packages. Verify device identity and ownership of submitted device_id.
Incident sync must be idempotent by UUID and acknowledge only successfully persisted records. Include duplicate IDs in synced_ids; avoid duplicate records under retries.
Admin-only equipment deletion must handle dependent manuals/jobs/packages/incidents and stored files transactionally.
Manual deletion invalidates every package containing it. Do not leave a downloadable stale package that reintroduces deleted knowledge.
Reject deletion during an active job with 409 and a useful message. Preserve records if database deletion fails; report post-commit file cleanup problems through cleanup_pending.
Existing offline copies cannot be instantly revoked without connectivity; document this limitation.

### Verification and handoff

Use isolated test databases and temporary storage. Never use real manuals/equipment as destructive test fixtures.
Tests must cover: text PDF extraction, successful OCR, blank notes page among readable pages, unreadable-only document, original page provenance, 384-dimensional embeddings, package schema/checksums, equipment isolation, insufficient evidence, job failure/status updates, retry concurrency, duplicate incident sync, authorization and deletion rollback.
Provide a genuine small fixture package for the mobile developer and test the API with the web/mobile members' request shapes.
Leave README with exact Windows startup commands, dependency/model setup, admin provisioning and troubleshooting. Include a 5-minute end-to-end demo checklist and docs/handoffs/backend.md with implemented features, test evidence and limitations.
Deliver running code and verified artifacts, not only architecture notes.

