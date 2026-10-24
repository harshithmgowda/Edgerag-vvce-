# 🏆 EdgeRAG Hackathon Team Contribution Guide

Welcome to the team! This repository is organized as a **modular monorepo** so that all 4 team members can develop, test, and push code simultaneously **without stomping on each other's files or running into merge conflicts**.

---

## 👥 Team Folder Ownership & Git Scope Matrix

Each team member owns a specific folder domain. When you create commits in your assigned directory, GitHub automatically attributes your lines of code, commit frequency, and PRs to your profile on the repository Insights & Contributors graph!

| Member | Track Name | Primary Folder | Tech Stack | Branch Prefix | Commit Scope |
|---|---|---|---|---|---|
| **Member 1** | **Web Portal & Admin UI** | [`apps/hq-web/`](./apps/hq-web/) | Next.js 14, React, Tailwind, Recharts | `feat/web/*` | `feat(web): ...` |
| **Member 2** | **Mobile Edge App** | [`apps/mobile/`](./apps/mobile/) | Flutter, Dart, SQLite, LiteRT-LM | `feat/mobile/*` | `feat(mobile): ...` |
| **Member 3** | **Backend API & Sync Engine** | [`services/api/`](./services/api/) | FastAPI, Uvicorn, SQLAlchemy, MinIO | `feat/backend/*` | `feat(backend): ...` |
| **Member 4** | **Agentic RAG & Ingestion** | [`packages/rag-core/`](./packages/rag-core/) | PyMuPDF, RapidOCR, MiniLM, NumPy | `feat/ai/*` | `feat(rag): ...` |
| **Shared** | **QA & Benchmarks** | [`tests/`](./tests/) | Pytest, 25-Query Benchmark Suite | `test/*` | `test(eval): ...` |
| **Shared** | **Docs & Demo Playbook** | [`docs/`](./docs/) | Markdown, Architecture Specs | `docs/*` | `docs(guide): ...` |

---

## 🌿 Git Branching Strategy

Never commit directly to `main` during active development. Follow this branch naming convention:

```bash
# Member 1 (Web):
git checkout -b feat/web/incident-triage-drawer

# Member 2 (Mobile):
git checkout -b feat/mobile/offline-waveform-recorder

# Member 3 (Backend):
git checkout -b feat/backend/checksum-sync-endpoint

# Member 4 (AI/RAG):
git checkout -b feat/ai/ocr-blank-page-filter

# Testing / QA:
git checkout -b test/benchmark-v2-expansion

# Documentation:
git checkout -b docs/hackathon-demo-script
```

---

## ✍️ Conventional Commit Message Guidelines

To make the repository history look professional and easy to navigate for hackathon evaluators, format commit messages as:

```
<type>(<scope>): <short imperative description>
```

### Examples:
- `feat(web): add real-time incident review drawer and status toggles`
- `fix(web): dynamically resolve backend API host from window location for hotspot`
- `feat(mobile): implement 3-tier evidence status badge in AI chat`
- `fix(mobile): enforce rollback to previous working SQLite DB on cancelled download`
- `feat(backend): bind uvicorn and next.js to 0.0.0.0 for LAN hotspot reachability`
- `fix(backend): add per-page error handling to storage fallback`
- `feat(rag): skip genuinely blank notebook pages while preserving manual numbering`
- `test(eval): add 25-question ground truth benchmark suite and measured report`
- `docs(team): add folder-wise ownership and commit contribution guidelines`

---

## 🚀 How to Make Your First Contribution

```bash
# 1. Pull the latest main branch
git checkout main
git pull origin main

# 2. Create your feature branch based on your track
git checkout -b feat/web/my-new-feature

# 3. Work inside your track directory (e.g., apps/hq-web/)
# ... write code and tests ...

# 4. Stage ONLY files in your track directory
git add apps/hq-web/

# 5. Commit with your track scope
git commit -m "feat(web): add equipment search filter by serial number"

# 6. Push your branch to GitHub
git push -u origin feat/web/my-new-feature

# 7. Open a Pull Request on GitHub with a clear summary
```

---

## 🛡️ Golden Rules for Zero-Conflict Teamwork

1. **Stay in your lane**: Avoid editing files in another track's folder without talking to that team member first.
2. **Contracts are shared**: If you need to change anything in `contracts/`, discuss it with the team first so neither backend nor mobile breaks.
3. **Run local checks before pushing**:
   - Web: `cd apps/hq-web && npx tsc --noEmit`
   - Mobile: `cd apps/mobile && flutter analyze`
   - Backend: `pytest tests/unit`
   - Benchmark: `python tests/eval/eval_benchmark.py`
4. **Small, frequent commits**: Push small, working commits rather than one massive commit at the end of the day. This keeps your GitHub contributor graph active and makes rollbacks easy if something breaks!
