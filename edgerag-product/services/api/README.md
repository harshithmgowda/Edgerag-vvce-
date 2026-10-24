# ⚙️ Track 3: Backend API & Services (`services/api`)

**Assigned Team Member**: Member 3 (Backend & Storage Lead)  
**Tech Stack**: Python 3.11+, FastAPI, Uvicorn, SQLAlchemy, SQLite/PostgreSQL, MinIO / Local FS, Celery, Redis  
**Git Scope**: `feat(backend): <description>` or `fix(backend): <description>`  
**Dedicated Branch**: `track/backend-api` (or feature branches `feat/backend/<feature-name>`)

---

## 🎯 Domain & Responsibilities

You own the **Headquarters Backend & Microservices Engine** running on port 8000:
1. **RESTful APIs**: Complete `/api/v1` routes for equipment, manuals, jobs, packages, devices, and incidents.
2. **Hotspot Synchronization**: Endpoints `/sync/check`, `/packages/{id}/download`, and `/sync/incidents` handling atomic package delivery.
3. **Storage Engine**: Dual-mode storage (MinIO S3 with automatic local filesystem fallback).
4. **Asynchronous Worker Queue**: Celery tasks (`workers/tasks.py`) orchestrating PDF extraction, chunking, and package compilation.
5. **Security & Authentication**: JWT token generation, role-based access control, and device token authentication.
6. **Agentic Coordinator**: LangGraph-inspired backend reasoner and evidence guard (`app/ai/agent.py`).

---

## 📁 Folder Structure

```
services/api/
├── app/
│   ├── ai/                   # Backend AI reasoner & coordinator
│   │   ├── agent.py          # Reasoner, verifier & coordinator nodes
│   │   └── evidence.py       # Evidence validation & 3-tier status evaluator
│   ├── api/v1/               # REST API endpoints
│   │   ├── auth.py           # JWT login, refresh & password hashing
│   │   ├── devices.py        # Android phone registration & heartbeats
│   │   ├── equipment.py      # Equipment CRUD operations
│   │   ├── incidents.py      # Field incident triage & status updates
│   │   ├── jobs.py           # Background job telemetry & retry triggers
│   │   ├── manuals.py        # PDF upload & page-level excerpt rendering
│   │   ├── packages.py       # Knowledge package metadata & download streams
│   │   ├── sync.py           # Delta check & mobile outbox ingest
│   │   └── router.py         # Consolidated API v1 router
│   ├── db/                   # Database models & connection pooling
│   │   ├── database.py       # SQLAlchemy engine & session factory
│   │   └── models.py         # Table definitions (Equipment, Manual, Job, Package, Incident)
│   ├── schemas/              # Pydantic request/response validation schemas
│   │   └── schemas.py
│   ├── security/             # Password hashing, JWT encode/decode, auth guards
│   │   └── auth.py
│   ├── services/             # Core business logic & storage clients
│   │   └── storage.py        # MinIO client with zero-config local fallback
│   ├── workers/              # Celery background tasks
│   │   ├── celery_app.py     # Celery instance configuration
│   │   └── tasks.py          # Asynchronous manual ingestion pipeline
│   ├── config.py             # App settings from environment variables (.env)
│   └── main.py               # FastAPI application factory & CORS configuration
├── requirements.txt          # Python dependencies
└── README.md                 # This track guide
```

---

## 🚀 Development Workflow

```bash
# 1. Navigate to your track folder
cd services/api

# 2. Start the API server (bound to 0.0.0.0 for LAN/Hotspot)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Or use the root PowerShell script:
# .\scripts\start\start_backend.ps1

# 3. Interactive API documentation:
# Swagger UI:  http://localhost:8000/docs
# OpenAPI JSON: http://localhost:8000/openapi.json
```

---

## 💡 How to Add a New API Endpoint

1. Define request and response schemas in `app/schemas/schemas.py`.
2. Add database models in `app/db/models.py` if adding tables/columns.
3. Create route handlers in `app/api/v1/<resource>.py`.
4. Register the router in `app/api/v1/router.py`.
5. Run unit tests to verify:
   ```bash
   pytest tests/unit
   ```

---

## 📤 Git Commit & Contribution Guide

When making changes to Track 3, always use the `backend` scope:

```bash
git checkout -b feat/backend/checksum-endpoint
# Make your edits in services/api/
git add services/api/
git commit -m "feat(backend): add cryptographic package verification endpoint for sync checks"
git push origin feat/backend/checksum-endpoint
```
*(Your commits will cleanly highlight your contributions on the team's GitHub commit graph without any file conflicts with other members!)*
