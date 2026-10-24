# MEMBER 2 — ANDROID FIELD APPLICATION
Copy this entire file into your coding assistant.

You are the Mobile and Offline Engineer for EdgeRAG. Implement a working Flutter Android application connected to the shared backend.

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

Own apps/mobile only, including tests and docs/handoff.md.
Use Flutter/Dart, sqflite, http, path_provider, crypto, archive, and secure credential storage. Choose compatible versions. Keep Android build setup documented.

Build these flows:
1. HQ connection: editable base URL, connection test, understandable LAN instructions.
2. Authorized device enrollment and secure persistence of the returned device token.
3. Equipment selection with a cached list for offline use.
4. Field dashboard: selected equipment, actual network state, installed knowledge version, model readiness, pending incident count.
5. Knowledge sync: compare versions, download ZIP, verify SHA-256, validate manifest and schema, verify SQLite checksum, install safely.
6. AI chat: equipment-scoped retrieval, readable Markdown, separate source cards, copy, cancellation, history.
7. Incident creation/history: save locally immediately, assign a stable UUID, queue pending upload, mark synced only after HQ acknowledgment.
8. Settings: model installation/status, HQ connection, offline storage management, and admin equipment/manual deletion.

Use two storage responsibilities:
- app_data.db: conversations, messages, incidents, outbox state and installed-package records.
- knowledge_<equipmentId>.db: downloaded equipment knowledge.
Use the exact schema and filenames in the shared package contract.

For package installation, stage on the same filesystem as the active database. Reject bad checksums, unsupported schemas and unsafe ZIP paths. Validate everything before closing and replacing the active database. Keep the previous package recoverable if activation fails. A failed download must not destroy working knowledge.

Use BM25-style lexical retrieval over local chunks for the first working version, matching the existing prototype's mobile approach. Preserve equipment scope and original page numbers. Do not claim vector retrieval unless you actually implement and test a compatible query embedder and vector comparison.

Local generation:
- First integrate ONE installed, Android-compatible small GGUF model through a supported llama.cpp/Fllama runtime.
- Document the exact model file, license, install path, device requirements and setup.
- Do not invent or assume model compatibility from a display name.
- Missing model must show an actionable installation message. Retrieved excerpts can still be displayed, explicitly labeled as excerpts rather than AI-generated answers.
- Local generation must not call a cloud endpoint in OFFLINE_ONLY mode.
- Add LiteRT-LM as an optional second runtime only if the core demo is working.

Mode behavior:
- OFFLINE_ONLY: local retrieval plus installed local inference, no external AI.
- ONLINE_AI: use HQ chat when reachable; show a clear connectivity error otherwise.
- SMART_AUTO: prefer reachable HQ, then fall back to downloaded knowledge and local inference.
Internet-only direct provider calls are optional later; do not ship secret API keys in source.
Distinguish HQ reachability from internet reachability.
When evidence is absent, state that the manual does not contain enough information. Do not silently present general model knowledge as manual-grounded advice.

Deletion:
Provide obvious management actions on equipment/settings screens. Distinguish Delete from HQ (admin login required, permanent server operation) from Remove local download (device-only). Show consequences and confirmation. Clear deleted equipment from the local picker cache after HQ success. Never delete local incident drafts as a side effect of removing knowledge.

## Build order

First: connect -> equipment -> package sync -> local retrieval -> offline incident.
Second: installed local model -> grounded chat -> incident synchronization.
Third: source cards, deletion/settings, and presentation polish.
Image analysis, scanning, voice, audio/video tools and multiple local runtimes are stretch features; implement only with real supported models/providers and honest availability labels.

## Verification and handoff

Run flutter analyze and focused widget/unit tests.
Test corrupt ZIP rejection, failed activation retaining old knowledge, equipment-scoped retrieval, duplicate incident retries, delete cancellation/failure, and missing-model states.
Test the Android app on a real device in airplane mode, after downloading knowledge AND installing a model. Record which actions actually work offline.
Deliver a debug APK if the Android toolchain is available, README with exact build/install commands, and docs/handoff.md with phone requirements, network setup, model setup, API dependencies, test outcomes and verified limitations.
Never label the whole app offline-ready based only on emulator UI tests.

