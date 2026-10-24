# EdgeRAG System Architecture Specification

## 1. High-Level System Overview

EdgeRAG is designed to decouple heavy knowledge processing (performed at headquarters on server hardware) from field inference (performed on commodity Android devices in air-gapped industrial environments).

```
+-----------------------------------------------------------------------------------------+
|                               HEADQUARTERS HOST (WINDOWS / WSL2)                        |
|                                                                                         |
|  +-------------------------+     HTTP / REST     +-----------------------------------+  |
|  |  Next.js 14 Web Portal  | <=================> |        FastAPI Backend API        |  |
|  |   (Apple-Style SaaS)    |                     |  - Endpoints (/api/v1)            |  |
|  +-------------------------+                     |  - JWT RBAC & Device Auth         |  |
|                                                  |  - LangGraph Agentic Orchestrator |  |
|                                                  +-----------------+-----------------+  |
|                                                                    |                    |
|                                   +--------------------------------+-----------------+  |
|                                   |                                |                 |  |
|                                   v                                v                 v  |
|                          +-----------------+             +-----------------+   +-----+-----+
|                          | MySQL Database  |             | Redis Task Q    |   | MinIO / S3|
|                          | - Equipment     |             | & Celery Worker |   | - PDFs    |
|                          | - Manuals & Jobs|             | - PyMuPDF       |   | - ZIP pkgs|
|                          | - Incidents     |             | - MiniLM Embed  |   +-----------+
|                          +-----------------+             | - SQLite Build  |            |
|                                                          +--------+--------+            |
|                                                                   |                     |
|                                                                   v                     |
|                                                       +-----------------------+         |
|                                                       | Knowledge Package ZIP | <-------+
|                                                       | (manifest + sqlite)   |         |
|                                                       +-----------+-----------+         |
+-------------------------------------------------------------------|---------------------+
                                                                    |
                       LOCAL HOTSPOT / WI-FI LAN (192.168.137.x)     | (Zero Public Internet)
                                                                    v
+-----------------------------------------------------------------------------------------+
|                                 FIELD ENGINEER ANDROID DEVICE                           |
|                                                                                         |
|   +---------------------------------------------------------------------------------+   |
|   | Flutter Application (Dart)                                                      |   |
|   |  - Hotspot Sync Client (SHA-256 Check & Atomic Activation)                      |   |
|   |  - Native Dart Agent Controller (Plan -> Retrieve -> Sufficiency -> Verify)     |   |
|   |  - Network State Sentinel (Offline / LAN Only / Cloud Only / Dual)               |   |
|   +-----------------------+---------------------------------+-----------------------+   |
|                           |                                 |                           |
|                           v                                 v                           |
|            +------------------------------+  +-------------------------------+          |
|            | Database A (Writable SQLite) |  | Database B (Knowledge SQLite) |          |
|            | - Conversations & Messages   |  | - Manual Text Chunks          |          |
|            | - Offline Incident Outbox    |  | - 384-d Pre-computed Embeddings|         |
|            | - Device Registration State  |  | - Page Number Citation Map    |          |
|            +------------------------------+  +---------------+---------------+          |
|                                                              |                          |
|                                                              v                          |
|                                                +----------------------------+           |
|                                                | Local Inference Engine     |           |
|                                                | - Cosine Vector Matcher    |           |
|                                                | - llama.cpp / On-device LLM|           |
|                                                +----------------------------+           |
+-----------------------------------------------------------------------------------------+
```

## 2. Key Architectural Invariants

1. **Dual SQLite Isolation on Android**:
   - The field device maintains strictly separated databases. 
   - `app_data.db` contains technician conversations, recorded incidents, and pending sync outbox records. It is never overwritten during knowledge updates.
   - `knowledge.db` is an immutable, read-only snapshot generated at headquarters. When an updated package is synced, the new database is staged in a temporary directory, validated against its manifest hash, and atomically swapped into active status.
2. **Deterministic Vector Compatibility**:
   - Headquarters generates embeddings using `sentence-transformers` (`all-MiniLM-L6-v2`) with L2 normalization producing 384-dimensional unit vectors.
   - The mobile retrieval engine utilizes the exact same dimensionality and cosine similarity metric:
     $$\text{similarity}(u, v) = \frac{u \cdot v}{\|u\| \|v\|}$$
     Since vectors are pre-normalized, this collapses to the fast dot product $u \cdot v$.
3. **No Docker Requirement**:
   - Built for native Windows 11 execution.
   - Python 3.10+ runs FastAPI natively on Windows.
   - MySQL runs as a Windows native service.
   - Redis and Celery can run natively on Windows via Redis-for-Windows or directly inside lightweight WSL2 with mirrored networking.
   - MinIO provides a single native Windows executable `minio.exe`.
   - A built-in local filesystem fallback adapter enables zero-dependency development even if MinIO or Redis is temporarily stopped.

## 3. Multimodal On-Device & Hybrid AI Platform

1. **Model Hub & Multi-Model Registry**:
   - Mobile app features a unified typed model registry managing on-device LiteRT-LM models (Google Gemma 4 E2B IT), GGUF models (Qwen 2.5 0.5B, Phi-3-mini), system TTS, and cloud vision backends (NVIDIA NIM Llama 3.2 11B Vision, Gemini 2.0 Flash).
2. **Eight Industrial AI Capabilities**:
   - **AI Chat**: Multimodal composer with image/audio/manual attachments and speech synthesis.
   - **Agent Skills**: 7 bounded operations with strict allowlist and parameter verification.
   - **Ask Image**: Equipment identification, visual troubleshooting, and gauge readings.
   - **Audio Scribe**: Noise-resilient voice note recording, speech-to-text, translation, and incident filing.
   - **Video Insights**: Resource-conscious frame sampling across video timelines without OOM errors.
   - **Document Scanner**: Technical nameplate and wiring diagram OCR with direct manual correlation.
   - **Voice Assistant**: Hands-free push-to-talk voice pipeline for technicians with safety gloves.
   - **Model Manager**: Real storage auditor, checksum verification, and safe model removal.
3. **Preservation of Document RAG Invariants**:
   - All visual observations and audio transcripts are correlated against SQLite manual embeddings (`knowledge_{id}.db`).
   - Factual instructions must come with verified `[Source CHUNK_ID]` citations. Visual AI estimates are never presented as verified equipment specifications.
