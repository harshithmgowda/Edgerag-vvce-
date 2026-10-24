# SEQUENTIAL MEMBER 2 — READ PULLED BACKEND, BUILD WEBSITE, PUSH
Copy this entire file into your coding assistant AFTER cloning/pulling Member 1's completed GitHub work.

You are the SECOND developer in a sequential three-person hackathon team.
Member 1 has built and pushed the EdgeRAG backend/RAG foundation. Your task is to READ and understand that existing repository, then build the Next.js HQ website against its real APIs. Member 3 will pull your complete repository and add Flutter Android.

EdgeRAG lets HQ register equipment, upload manuals, build portable knowledge packages, answer equipment-specific questions and review synchronized field incidents.
Do not start again from scratch. Do not ask the user to manually describe details already present in the repository.
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

Own apps/hq-web, its tests, and docs/handoffs/02-web.md. Preserve the backend.
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

Do not implement backend logic or invent records to make pages look populated. Use the actual checked-in contract. If integration exposes a backend defect, make a minimal compatible fix with a regression test; document it instead of replacing the backend.

## Build order

First: login -> equipment -> upload -> job -> chat.
Second: packages -> delete flows -> incidents/devices -> provider settings.
Third: responsive polish, dark theme and optional streaming.
Do not spend the first half of the hackathon only styling the dashboard.

## Verification and handoff

Run type checking and production build.
Add meaningful tests for authenticated DELETE, cancellation, expired-session recovery, failed requests and clean answer rendering.
Verify desktop and narrow layouts with the running backend; never delete a teammate's real data during tests.
Deliver apps/hq-web/.env.example, README setup commands, and docs/handoffs/02-web.md with pages implemented, exact API dependencies, test commands/results, known gaps, and the browser demo sequence.
Finish by listing what works against the real backend versus what remains unverified.


## Mandatory sequential handoff

Update root README.md to explain how to run backend + website together.
Write docs/handoffs/02-web.md including:
- The Member 1 commit you started from and any compatible backend fixes.
- Completed routes, API client location, authentication/session behavior and exact .env configuration.
- Verified end-to-end flows and what still needs credentials or setup.
- Known gaps the mobile member must know, including package schema and enrollment requirements.
- Instructions for Member 3 to pull, run both existing apps and add apps/mobile without rebuilding them.

Verify at least equipment creation -> manual upload -> completed/failed job feedback -> package list -> grounded chat, using a known readable test PDF and available provider credentials. If credentials are absent, report that generation remains unverified instead of faking an answer.
Member 3 must receive a functioning website AND the preserved backend.
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
