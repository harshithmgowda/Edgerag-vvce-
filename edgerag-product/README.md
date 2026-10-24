# 🚀 EdgeRAG — Hybrid Offline + Online Agentic RAG Platform

> **Industrial Equipment Knowledge at the Extreme Edge — 100% Air-Gapped Operation with Adaptive Evidence Checking.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688.svg?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Next.js 14](https://img.shields.io/badge/Next.js-14.2-black.svg?logo=next.js&logoColor=white)](https://nextjs.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.2.0+-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Evaluation Benchmark](https://img.shields.io/badge/Evaluation_Hit_Rate-100%25-brightgreen.svg)](./docs/EVALUATION_REPORT.md)
[![Offline Complete](https://img.shields.io/badge/Offline_Operation-100%25_Verified-success.svg)](./docs/EVALUATION_REPORT.md)

---

## 🏆 Hackathon Monorepo Structure & Team Tracks

This repository is organized as a **modular monorepo**. Each team member owns an isolated folder domain with dedicated track guides, branch conventions, and commit scopes. This allows everyone to push code simultaneously **with zero merge conflicts and clear attribution on GitHub!**

```text
edgerag-product/
├── 🌐 apps/
│   ├── hq-web/               # Track 1: Headquarters Web Portal (Next.js 14, Tailwind, Recharts)
│   │   └── README.md         # 👉 Member 1 Guide
│   └── mobile/               # Track 2: Android Field Application (Flutter, SQLite, LiteRT-LM)
│       └── README.md         # 👉 Member 2 Guide
│
├── ⚙️ services/
│   └── api/                  # Track 3: Backend API & Sync Microservices (FastAPI, Celery, Storage)
│       └── README.md         # 👉 Member 3 Guide
│
├── 🧠 packages/
│   ├── rag-core/             # Track 4: Agentic RAG & Ingestion Engine (RapidOCR, MiniLM, Chunker)
│   │   └── README.md         # 👉 Member 4 Guide
│   └── fllama/               # On-device native inference runtime bridge
│
├── 🧪 tests/                 # Track 5: QA & Rigorous Benchmarks (25-Query Ground-Truth Benchmark)
│   ├── eval/                 # Rigorous evaluation test runner
│   ├── unit/                 # Fast unit tests
│   └── README.md             # 👉 QA Guide
│
├── 📋 contracts/             # Track 6: Shared Data Contracts & Schemas (JSON Schemas, Manifests)
│   ├── incident.schema.json  # Air-gap incident sync schema
│   ├── package-manifest.json # Package integrity schema
│   └── README.md             # 👉 Contract Specifications
│
├── 📚 docs/                  # Documentation & Demo Playbook
│   ├── ai/                   # Offline AI, Gemini BYOK & Multimodal setup guides
│   ├── architecture/         # System topology, Agentic RAG, Networking & Security
│   ├── guides/               # Step-by-step setup, Hotspot sync, and Troubleshooting
│   ├── team/                 # Team handoffs & Git workflow
│   └── EVALUATION_REPORT.md  # 📊 Empirical benchmark results (25 queries measured)
│
├── 🛠️ scripts/               # Automation, Windows/Linux start & stop scripts
│   ├── start/                # start_all.ps1, start_backend.ps1, start_web.ps1
│   ├── stop/                 # stop_all.ps1
│   ├── setup/                # Environment initialization scripts
│   └── archive/              # Patches & migration scripts
│
├── CONTRIBUTING.md           # 👥 Team branch & commit workflow cheat sheet
├── START_HERE.md             # 🔰 Quickstart guide for new developers
└── README.md                 # 📖 Main project overview (You are here)
```

---

## 👥 Team Ownership & Git Scope Matrix

| Member | Track | Folder Path | Branch Prefix | Commit Scope | Dedicated Guide |
|---|---|---|---|---|---|
| **Member 1** | **Web Portal & Admin UI** | [`apps/hq-web/`](./apps/hq-web/) | `feat/web/*` | `feat(web): ...` | [Track 1 README](./apps/hq-web/README.md) |
| **Member 2** | **Mobile Edge App** | [`apps/mobile/`](./apps/mobile/) | `feat/mobile/*` | `feat(mobile): ...` | [Track 2 README](./apps/mobile/README.md) |
| **Member 3** | **Backend API & Sync** | [`services/api/`](./services/api/) | `feat/backend/*` | `feat(backend): ...` | [Track 3 README](./services/api/README.md) |
| **Member 4** | **Agentic RAG Engine** | [`packages/rag-core/`](./packages/rag-core/) | `feat/ai/*` | `feat(rag): ...` | [Track 4 README](./packages/rag-core/README.md) |
| **Shared** | **QA & Benchmarks** | [`tests/`](./tests/) | `test/*` | `test(eval): ...` | [Track 5 README](./tests/README.md) |
| **Shared** | **Schemas & Contracts** | [`contracts/`](./contracts/) | `chore/contract/*` | `chore(contract): ...` | [Track 6 README](./contracts/README.md) |

*(See [CONTRIBUTING.md](./CONTRIBUTING.md) for full branch and PR conventions).*

---

## 📊 Measured Evaluation Benchmark (25 Ground-Truth Queries)

To give hackathon judges empirical evidence of reliability rather than unverified claims, EdgeRAG was rigorously tested against 25 ground-truth technical scenarios from industrial manuals across 4 categories:

| Metric | Score | Hackathon Benchmark Definition |
|---|---|---|
| **Retrieval Hit Rate (Top-1)** | **100.0%** (19/19) | Target manual section ranked #1 in retrieved passages |
| **Retrieval Hit Rate (Top-3)** | **100.0%** (19/19) | Target manual section present in top-3 candidates |
| **Answer Correctness** | **96.0%** (24/25) | Factual alignment with equipment engineering manuals |
| **Source Support Accuracy** | **94.7%** (18/19) | Cited page numbers directly substantiate the technical steps |
| **Appropriate Refusal Rate** | **100.0%** (6/6) | Safely refuses out-of-scope / unverified procedures |
| **Offline Completion Rate** | **100.0%** (25/25) | 100% of workflows complete air-gapped with zero network calls |

👉 **Full Report**: [`docs/EVALUATION_REPORT.md`](./docs/EVALUATION_REPORT.md)

---

## ⚡ 3-Step Quickstart

### 1. Launch All Services (Backend, Worker, Web)
```powershell
.\scripts\start\start_all.ps1
```
- **Local Web Portal**: http://localhost:3000
- **Hotspot Web Portal**: `http://192.168.137.1:3000` (Windows Hotspot) / `http://192.168.43.1:3000` (Phone Hotspot)
- **FastAPI Backend**: `http://localhost:8000/docs`

### 2. Run the Mobile App
```bash
cd apps/mobile
flutter run
```

### 3. Run Benchmark Verification
```bash
python tests/eval/eval_benchmark.py
```

---

## 📖 Essential Documentation Links

- 🔰 **[Beginner Quickstart (Start Here)](./START_HERE.md)**
- 📘 **[Step-by-Step Runbook](./docs/guides/RUN_EVERYTHING_STEP_BY_STEP.md)**
- ⚙️ **[No-Docker Architecture Guide](./docs/guides/NO_DOCKER_SETUP.md)**
- 📶 **[Hotspot Synchronization Guide](./docs/guides/HOTSPOT_SYNC_GUIDE.md)**
- 🤖 **[Multimodal AI Setup Guide](./docs/ai/MULTIMODAL_AI_SETUP.md)**
- 💎 **[Google Gemma 4 E2B Setup Guide](./docs/ai/INSTALL_GEMMA4_E2B.md)**
- 🔑 **[Google Gemini BYOK & API Keys](./docs/ai/GEMINI_AND_API_KEYS.md)**
- 🛠️ **[Troubleshooting Runbook](./docs/guides/TROUBLESHOOTING.md)**
- 🤝 **[Team Handoffs & Workflow](./docs/team/TEAM_WORKFLOW.md)**
