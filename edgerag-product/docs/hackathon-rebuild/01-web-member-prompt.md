# MEMBER 1 — WEB APPLICATION
Copy this entire file into your coding assistant.

You are the Web and UX Engineer for EdgeRAG. Implement a working HQ web application, not screenshots or a proposal.

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

Own apps/hq-web only, including tests and docs/handoff.md inside that folder.
Use Next.js App Router, React, TypeScript, Tailwind CSS, and lucide-react. Choose compatible maintained versions, pin dependencies, and keep the setup reproducible.

Build these screens:
1. Login: admin authentication, helpful failures, session expiry recovery, logout.
2. Dashboard: real equipment/manual/package/device/incident counts; no fabricated analytics.
3. Equipment: search, register, and delete equipment. Validate required fields and unique-serial errors.
4. Manuals: filter by equipment, multipart PDF upload, upload progress, job tracking, delete.
5. Jobs: status/stage/progress, readable error, retry failed jobs, clean polling teardown. Avoid duplicate logs from React Strict Mode.
6. Packages: version, equipment, size, chunk count, checksum, download.
7. Chat: equipment selection, AI mode, message history, Markdown, copy, source cards. Start with POST /chat; add streaming only after the non-streaming flow works.
8. Devices and incidents: display real registered devices and received incidents; allow incident review.
9. Provider settings: configure and test one provider first. Never put provider secrets in NEXT_PUBLIC variables, browser logs, or client bundles.

Create a typed API client and shared TypeScript types. API errors must preserve status codes. Handle loading, empty, unauthorized, forbidden, processing conflict, network failure and retry states.

Deletion must use an in-page accessible dialog, NOT window.confirm. Explain cascade effects:
- Equipment deletion removes its HQ manuals, packages, and incidents.
- Manual deletion invalidates all packages for that equipment.
- Existing offline copies are not remotely erased.
If unauthenticated or expired, offer admin sign-in inside the flow. Signing in must NOT itself delete anything; require a separate final confirmation. Disable duplicate submissions. Keep the record on API failure; remove it only after confirmed success. Surface cleanup_pending warnings. Honor 409 for active processing.

Do not implement backend logic or invent records to make pages look populated. Use the contract and coordinate discrepancies.

## Build order

First: login -> equipment -> upload -> job -> chat.
Second: packages -> delete flows -> incidents/devices -> provider settings.
Third: responsive polish, dark theme and optional streaming.
Do not spend the first half of the hackathon only styling the dashboard.

## Verification and handoff

Run type checking and production build.
Add meaningful tests for authenticated DELETE, cancellation, expired-session recovery, failed requests and clean answer rendering.
Verify desktop and narrow layouts with the running backend; never delete a teammate's real data during tests.
Deliver apps/hq-web/.env.example, README setup commands, and docs/handoff.md with pages implemented, exact API dependencies, test commands/results, known gaps, and the browser demo sequence.
Finish by listing what works against the real backend versus what remains unverified.

