# SEQUENTIAL MEMBER 1 — BUILD BACKEND, RAG AND HANDOFF
Copy this entire file into your coding assistant in the NEW rebuild repository.

You are the FIRST developer in a sequential three-person hackathon team.
No website or mobile app has been built yet. Build the backend and reusable RAG/package foundation FIRST, test it, commit it and push it to our configured GitHub repository. Member 2 will pull your code to build the website. Member 3 will later pull both to build Android.

The product is EdgeRAG: headquarters uploads equipment manuals, converts them into portable SQLite knowledge packages, and distributes them to technicians over local Wi-Fi. Technicians ask questions online or using an installed local model offline and synchronize field incidents later.

Work in services/api, packages/rag-core, contracts, scripts and documentation. Do not spend your time building web/mobile screens. Do not overwrite any original EdgeRAG reference project; use this separate rebuild repository.
Assume the human is a beginner. Implement working code, explain setup commands, and leave an explicit handoff rather than only a plan. Use native Windows-compatible startup without requiring Docker.

Start by inspecting any existing files and AGENTS.md. Establish the API and package contract below, then implement it. Produce contracts/openapi.yaml from the actual application and contracts/knowledge-package.md describing the exact SQLite/ZIP schema.
Future members must be able to work from your repository without access to this conversation. Write all decisions into files.
### API agreement

Base URL: http://<HQ_HOST>:8000/api/v1. Web runs on port 3000.
Use NEXT_PUBLIC_API_BASE_URL for web and an editable HQ URL on Android. A physical phone uses the laptop's LAN IP, never localhost.
IDs are UUID strings; timestamps are ISO-8601 UTC strings. JSON properties use snake_case.
ADMIN and FIELD_ENGINEER are the user roles.
Errors: {"detail":"Useful explanation"}, with appropriate HTTP status.
Use Authorization: Bearer <token> for authenticated requests. Admin-only: create/delete equipment, upload/delete manuals, provider configuration, incident review. Device sync/download uses a registered device token. No anonymous admin fallback.

Entities (Member 1 must formalize these in OpenAPI):
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
Before deeper implementation, publish the agreed OpenAPI schemas, example requests/responses, knowledge-package schema, .env.example and a tiny clearly labeled fixture package. Record the server base URL and contract decisions in the handoff for the next member.

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
Provide a genuine small fixture package for the mobile developer and verify its schema for the future mobile app. The other members have not started yet.
Leave README with exact Windows startup commands, dependency/model setup, admin provisioning and troubleshooting. Include a 5-minute end-to-end demo checklist and docs/handoffs/backend.md with implemented features, test evidence and limitations.
Deliver running code and verified artifacts, not only architecture notes.


## Mandatory repository handoff files

Create:
- README.md: product overview, repo map, prerequisites and exact backend startup commands.
- .env.example: every required variable, safe placeholders, no secrets.
- docs/handoffs/01-backend.md: what works, API authentication, job lifecycle, model setup, test outcomes, known limitations and Member 2's entry points.
- contracts/openapi.yaml and contracts/knowledge-package.md.
- A tiny generated fixture package with no private data, plus its generator script and instructions for the mobile member.
- scripts/verify_backend: a reproducible smoke-test command for an isolated development database.

Your handoff must identify the exact installed/runtime model requirements, download/setup procedure and what happens if assets or provider credentials are unavailable.
Do not claim browser or mobile integration has passed before those apps exist.
## Required GitHub handoff — perform at the end

This team works sequentially on ONE agreed integration branch. Inspect git status, remotes, current branch and upstream first.
- Never initialize a new repository inside the pulled repository.
- Preserve unrelated changes; never reset, clean, force-push, or rewrite history.
- Run relevant checks. Clearly distinguish passed, failed and unrun checks.
- Inspect the diff and stage only your intended source, tests, contracts and documentation.
- Exclude .env secrets, API tokens, databases containing user data, uploaded PDFs, local caches, node_modules, build output and model weights. Commit .env.example with placeholders and a lockfile where appropriate.
- Commit your completed changes with a clear message.
- If the agreed remote and branch are already configured, push to that branch normally. If they are missing, ask only for the GitHub URL/branch you need; do not invent a repository.
- If the branch is protected, open a PR if tooling is available and tell the human to merge it before handing off. Do not claim the next member can pull the work until it is on the agreed branch.
- On a non-fast-forward push, fetch and inspect the divergence. Preserve others' work and resolve conflicts carefully; do not force-push.
- End with repository URL, branch, final commit SHA, setup/run commands, test results, known limitations, and the exact next-member steps. If pushing is unavailable, explicitly say "committed locally, not pushed."

The next teammate should use git clone for their first checkout or git pull --ff-only on a clean checkout of the agreed branch. They must not start from an older ZIP or different branch.
