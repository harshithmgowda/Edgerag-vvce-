# SEQUENTIAL MEMBER 3 — READ BACKEND + WEBSITE, BUILD MOBILE, INTEGRATE
Copy this entire file into your coding assistant AFTER cloning/pulling Member 2's completed GitHub work.

You are the THIRD and final developer in a sequential three-person hackathon team.
The repository already contains Member 1's backend/RAG and Member 2's HQ website. READ them first, then implement Flutter Android to use their real APIs and knowledge packages. Finish by verifying the complete laptop-to-phone workflow.

EdgeRAG is an offline-first equipment knowledge assistant: upload manuals at HQ, distribute packages over LAN, retrieve relevant text on Android, generate locally using a compatible installed model, record incidents offline and sync them when reconnected.

Your task is to add the mobile app and perform final integration, not replace the two earlier applications.
## Mandatory first steps after pulling

1. Inspect git status, branch and latest commit. Preserve local changes.
2. Read AGENTS.md, root README.md, .env.example, contracts/openapi.yaml, contracts/knowledge-package.md, and every preceding docs/handoffs file.
3. Inspect the ACTUAL backend route implementations, request/response models, authentication, job statuses, package generator and tests. The repository is the source of truth, not guessed APIs or stale prose.
4. Run the preceding member's documented setup and smoke tests where dependencies are available. Report blockers precisely.
5. Summarize what already exists, what your phase adds, and the existing API/package contracts in your own words; then implement without waiting for routine approval.
6. Reuse the existing project. Do not scaffold a second backend, replace shared contracts, change database filenames casually, or fabricate a new API.
7. If a required capability is missing, add the smallest backward-compatible change, regression-test it, update OpenAPI and handoff docs, and verify earlier functionality still works.

Use the existing contract exactly for endpoint names, snake_case fields, UUID IDs, UTC timestamps, auth roles/tokens, chat responses, incident acknowledgments and ZIP/SQLite schema.
If examples in your instructions differ from the working repository, preserve compatible behavior and document the discrepancy.
Do not silently use mock responses in production. Fixtures belong only in tests or an explicit demo mode.
Never commit credentials or model weights.

## Shared visual and answer behavior

Use Roboto for interface controls, Metropolis for branding, and Open Sans for readable body text. Bundle licensed fonts locally. Aim for a clean Google-inspired interface with blue actions, neutral surfaces, useful spacing and accessible focus/contrast.
Use Markdown for AI answers. Remove raw inline chunk/source tags from display, copy and speech, while keeping sources in a separate expandable section. Do not strip ordinary technical values, links, tables or code.
Show actual loading, empty, error and offline states. Never imply a model ran when it did not.## Your implementation

Own apps/mobile, its tests, and docs/handoffs/03-mobile.md. Preserve the existing web and backend applications.
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
Deliver a debug APK if the Android toolchain is available, README with exact build/install commands, and docs/handoffs/03-mobile.md with phone requirements, network setup, model setup, API dependencies, test outcomes and verified limitations.
Never label the whole app offline-ready based only on emulator UI tests.


## Mandatory final integration and handoff

Read docs/handoffs/01-backend.md AND docs/handoffs/02-web.md. Use the actual generated sample package to test imports before wiring downloads.
Run this end-to-end flow with isolated demo data:
1. Website registers equipment and uploads a readable PDF.
2. Backend completes extraction, chunking, embeddings and packaging.
3. Phone registers with HQ and downloads the package over LAN.
4. Verify checksum rejection with a corrupt test package.
5. Ask an equipment-specific question with source details.
6. Select OFFLINE_ONLY and disconnect the phone. Verify local inference using a genuinely installed model. If unavailable, clearly label retrieved excerpts and record that local generation is not verified.
7. Create an incident offline.
8. Reconnect; sync it; confirm it appears on the HQ website.
9. Repeat sync and confirm no duplicate incident is created.
10. Verify web functionality still works after any integration fixes.

Write docs/handoffs/03-mobile.md, docs/DEMO.md and update root README.md with exact commands, device setup, model installation, full demo script, test evidence, known limitations and backup-demo instructions.
Build an APK if the SDK is available; keep binaries out of ordinary source commits and explain where the build output is.
Do not claim production readiness, safety certification, guaranteed accuracy or guaranteed offline support for untested tools.
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
