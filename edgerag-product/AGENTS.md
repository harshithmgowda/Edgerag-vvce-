# EdgeRAG Engineering Team Protocols & Agent Directives

This document defines the roles, contracts, and collaboration boundaries for the EdgeRAG development team.

---

## 👥 Engineering Team Roles

### 1. Member 1: Web & Design Lead (`apps/hq-web`)
- **Focus**: Headquarters Administration Portal built with Next.js 14, React, TypeScript, Tailwind CSS, and Recharts.
- **Aesthetic**: Premium Apple-inspired SaaS style (neutral slate/zinc palettes, subtle borders, soft drop shadows, SF Pro / Inter typography, responsive tables, real loading and empty states).
- **Core Principle**: Zero fake data. Empty states must render with guidance ("No equipment registered yet"). All chart data, equipment lists, manuals, packages, and incidents originate from real `/api/v1` backend endpoints.
- **Artifact**: `docs/handoffs/member-1-web.md`.

### 2. Member 2: Mobile & Edge Lead (`apps/mobile`, `packages/mobile-ai`)
- **Focus**: Android-first Flutter application designed for field technicians.
- **Architecture**: Dual-SQLite design:
  - Database A (`app_data.db`): Writable application records (conversations, messages, incidents, outbox queue, device settings).
  - Database B (`knowledge.db`): Immutable knowledge store (manual chunks, 384-dimensional float embeddings, page references).
- **Core Principle**: Extreme edge resilience. Must seamlessly operate in 4 distinct network states (No network, LAN only, Internet only, Full connectivity). Hotspot sync downloads versioned ZIP packages and verifies SHA-256 before atomic activation.
- **Artifact**: `docs/handoffs/member-2-mobile.md`.

### 3. Member 3: Backend & Infrastructure Lead (`services/api`)
- **Focus**: FastAPI asynchronous API server, MySQL persistence, Redis task queues, Celery worker orchestration, and MinIO S3-compatible storage.
- **Strategy**: Absolute NO-DOCKER architecture. Services run natively on Windows host or inside WSL2 Linux environment.
- **Security**: JWT role-based access control (`admin`, `field_engineer`), bcrypt password hashing, device token authentication, idempotent incident synchronization keyed on UUID.
- **Artifact**: `docs/handoffs/member-3-backend.md`.

### 4. Member 4: AI & Machine Learning Lead (`packages/rag-core`, `services/api/app/ai`)
- **Focus**: 
  - Server RAG: PyMuPDF PDF parsing, tokenizer-aware chunking (224 tokens, 32 overlap), `sentence-transformers` (`all-MiniLM-L6-v2`) embeddings, and `.zip` bundle creation.
  - Server Agent: LangChain and LangGraph `StateGraph` workflow featuring Planner, Retriever, Query Rewriter, Tool Controller, Reasoner, and Citation Verifier.
  - Mobile Agent: Standalone Dart/native agent controller replicating the LangGraph state machine on-device without calling Python.
- **Provider Adapters**: Google Gemini (primary online provider), Anthropic Claude, OpenAI, and Groq with BYOK (Bring Your Own Key) capabilities.
- **Artifact**: `docs/handoffs/member-4-ai.md`.

---

## 🔒 Shared Contracts & Boundaries

1. **API Prefix**: All server routes use `/api/v1`.
2. **Entity Identifiers**: Strictly RFC-4122 Version 4 UUIDs (lowercase string format).
3. **Timestamps**: ISO 8601 UTC with trailing `Z` (e.g., `2026-10-19T14:30:00Z`).
4. **Schema Enforcement**: All API communication must validate against `contracts/openapi.yaml`.
5. **No Model Weight Commits**: Never commit large GGUF or PyTorch weights to version control.
6. **No Fake Dashboards**: Empty states are celebrated; never insert mock statistics into production databases.
