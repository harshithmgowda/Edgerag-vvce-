# Member 3 Handoff: FastAPI Backend & Infrastructure

## 1. Executive Summary & Architecture

Member 3 has built the complete asynchronous **FastAPI Backend** inside `services/api` supporting strict **No-Docker** execution on Windows and WSL2.

| Responsibility | Technology & Architecture | Resilience Strategy |
|---|---|---|
| **API Server** | FastAPI + Uvicorn | Binds to `0.0.0.0:8000`, exposes `/api/v1` routes with CORS for web & mobile. |
| **Relational Database** | SQLAlchemy ORM + MySQL | Dynamic dialect: defaults to SQLite (`edgerag_dev.db`) for immediate zero-dependency testing, automatically switches to MySQL via `DATABASE_URL`. |
| **Task Queue & Worker** | Redis + Celery | Async task execution with automatic in-process fallback thread if Redis is offline. |
| **Object Storage** | MinIO Client | S3 bucket management with automatic fallback to local directory (`./storage/manuals`, `./storage/packages`). |
| **Security & RBAC** | JWT (HS256) + Bcrypt | Passwords securely salted; default admin bootstrapped (`admin` / `IndustrialAdmin2026!`). |

---

## 2. API Endpoints Verified

- `GET /api/v1/health`
- `POST /api/v1/auth/login`, `POST /api/v1/auth/register-admin`, `GET /api/v1/auth/me`
- `GET /api/v1/equipment`, `POST /api/v1/equipment`, `GET /api/v1/equipment/{id}`, `PATCH /api/v1/equipment/{id}`
- `GET /api/v1/manuals`, `POST /api/v1/manuals`, `GET /api/v1/manuals/{id}`
- `GET /api/v1/jobs`, `GET /api/v1/jobs/{id}`
- `GET /api/v1/packages`, `GET /api/v1/packages/{id}/download`
- `GET /api/v1/devices`, `POST /api/v1/devices/register`, `POST /api/v1/devices/heartbeat`, `POST /api/v1/devices/{id}/revoke`
- `POST /api/v1/sync/check`, `POST /api/v1/sync/incidents`
- `GET /api/v1/incidents`, `GET /api/v1/incidents/{id}`, `PATCH /api/v1/incidents/{id}/review`
- `GET /api/v1/ai/providers`, `POST /api/v1/ai/providers`, `POST /api/v1/ai/providers/{id}/test`, `POST /api/v1/ai/chat`, `POST /api/v1/ai/chat/stream`

---

## 3. How to Run the Backend (No Docker)

```bash
cd edgerag-product/services/api
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Swagger UI available at [http://localhost:8000/docs](http://localhost:8000/docs).

---

## 4. Integration Requirements for Member 4 (AI Lead)

1. Member 4 must implement the LangGraph state machine inside `services/api/app/ai/agent.py` and the reusable RAG core in `packages/rag-core`.
2. The `execute_langgraph_chat` function is already connected to `/api/v1/ai/chat` and `/api/v1/ai/chat/stream`.
3. When embedding queries, verify that normalized vectors strictly match the 384-dimensional space of `all-MiniLM-L6-v2`.
