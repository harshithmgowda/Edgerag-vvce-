# 🚀 EdgeRAG — An Offline-First, Agentic Knowledge Platform for Industrial Operations

**Bringing intelligent equipment troubleshooting to field engineers, even when internet connectivity is unavailable.**

EdgeRAG combines retrieval-augmented generation (RAG), on-device AI inference, and a centralized knowledge management system to make industrial documentation accessible directly from Android devices.

Designed for industrial environments where connectivity can be unreliable or completely restricted, the platform enables technicians to search equipment manuals, retrieve relevant technical information, and generate evidence-backed answers without depending on cloud services.

The solution supports two operating modes:

- **Offline mode:** Processes questions locally using downloaded knowledge packages and an on-device language model.
- **Online mode:** Enables optional cloud-assisted AI functionality, centralized administration, and knowledge synchronization.

---

## 🌟 The Problem We're Solving

Industrial maintenance teams often work with large collections of technical manuals, equipment specifications, and troubleshooting documents.

Finding the correct procedure within hundreds of PDF pages can be slow, particularly when technicians are working at remote facilities with limited network connectivity.

Traditional cloud-dependent AI assistants introduce an additional limitation: they may become unavailable precisely when field engineers need them most.

**EdgeRAG addresses these challenges by placing searchable technical knowledge and AI-assisted troubleshooting directly on the technician's device.**

### Key capabilities

- 📚 **Document intelligence:** Convert industrial PDFs into searchable technical knowledge.
- 📱 **Offline access:** Retrieve information and generate responses without internet connectivity.
- 🧠 **Agentic retrieval:** Evaluate retrieved evidence and refine searches when the available information is insufficient.
- 🔎 **Hybrid search:** Combine semantic similarity with keyword-based retrieval for technical terminology and error codes.
- 📄 **Traceable answers:** Associate responses with supporting source documents and page references.
- 📶 **Local synchronization:** Transfer approved knowledge packages to mobile devices through supported local network connections.
- ⚙️ **Asynchronous processing:** Process larger documents through backend task workers.
- ☁️ **Optional cloud AI:** Support additional capabilities through user-configured Gemini API access.

---

## 🏗️ Technology Architecture

EdgeRAG is organized into independently developed components that share common data contracts.

| Component | Technologies | Responsibility |
|---|---|---|
| Headquarters Portal | Next.js 14, Tailwind CSS, Recharts | Document administration, knowledge management, monitoring |
| Backend Services | FastAPI, Celery | API operations, document processing jobs, synchronization |
| Knowledge Engine | Python, RapidOCR, MiniLM | Text extraction, chunking, embeddings, retrieval |
| Android Application | Flutter, SQLite | Local knowledge storage, technician interface, offline access |
| On-Device AI | LiteRT-LM, fllama bridge | Local language model inference |
| Optional Cloud AI | Gemini API (BYOK) | Online AI-assisted functionality |
| Evaluation Suite | Python test runners | Retrieval, answer quality, citation, and offline testing |

### Knowledge processing workflow

1. An administrator uploads an industrial document through the headquarters portal.
2. The backend receives the file and initiates its processing workflow.
3. The knowledge engine extracts text and applies OCR when required.
4. Extracted content is divided into smaller, retrievable sections.
5. An embedding model converts those sections into numerical representations.
6. The processed content and associated metadata are assembled into a portable knowledge package.
7. The Android application downloads the approved package when a supported connection is available.
8. The technician can subsequently retrieve information and use supported AI capabilities without contacting the headquarters server.

The offline inference path is designed to function independently of the optional cloud AI integration.

---

## 👥 Repository Organization and Team Responsibilities

EdgeRAG follows a monorepo architecture. Instead of maintaining separate repositories for every application and service, related components are organized within one shared codebase.

This structure allows contributors to work on different parts of the system while maintaining consistent interfaces, documentation, and testing practices.

### Repository structure

```text
edgerag-product/
│
├── apps/
│   ├── hq-web/
│   │   └── README.md
│   └── mobile/
│       └── README.md
│
├── services/
│   └── api/
│       └── README.md
│
├── packages/
│   ├── rag-core/
│   │   └── README.md
│   └── fllama/
│
├── tests/
│   ├── eval/
│   ├── unit/
│   └── README.md
│
├── contracts/
│   ├── incident.schema.json
│   ├── package-manifest.json
│   └── README.md
│
├── docs/
│   ├── ai/
│   ├── architecture/
│   ├── guides/
│   ├── team/
│   └── EVALUATION_REPORT.md
│
├── scripts/
│   ├── start/
│   ├── stop/
│   ├── setup/
│   └── archive/
│
├── CONTRIBUTING.md
├── START_HERE.md
└── README.md
```

### Development responsibilities

| Track | Responsibility | Primary Directory |
|---|---|---|
| Member 1 | Headquarters dashboard and web interface | `apps/hq-web/` |
| Member 2 | Flutter application and on-device features | `apps/mobile/` |
| Member 3 | Backend services and synchronization | `services/api/` |
| Member 4 | Document intelligence and agentic retrieval | `packages/rag-core/` |
| Shared | Automated evaluation and quality assurance | `tests/` |
| Shared | Data schemas and integration contracts | `contracts/` |

Each development track includes its own README containing implementation details and setup guidance.

### Git collaboration conventions

| Development Area | Branch Naming | Commit Example |
|---|---|---|
| Web | `feat/web/*` | `feat(web): implement upload dashboard` |
| Mobile | `feat/mobile/*` | `feat(mobile): add local document search` |
| Backend | `feat/backend/*` | `feat(backend): add package download endpoint` |
| AI Engine | `feat/ai/*` | `feat(rag): implement retrieval evaluation` |
| Testing | `test/*` | `test(eval): add citation validation` |
| Contracts | `chore/contract/*` | `chore(contract): revise manifest schema` |

Separating development responsibilities reduces unnecessary file overlap. Contributors still use pull requests, integration testing, and code reviews to identify conflicts before merging changes.

For detailed instructions, refer to [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## 📊 Experimental Evaluation

EdgeRAG's repository includes a benchmark report covering 25 technical test scenarios.

The evaluation considers whether the retrieval engine finds the appropriate document sections, whether generated answers align with the available evidence, and whether the offline execution path completes successfully.

### Reported benchmark results

| Evaluation Metric | Reported Result | Measurement |
|---|---|---|
| Top-1 Retrieval Hit Rate | 100% (19/19) | Relevant section appears first |
| Top-3 Retrieval Hit Rate | 100% (19/19) | Relevant section appears among the first three results |
| Answer Correctness | 96% (24/25) | Responses match expected technical facts |
| Source Support Accuracy | 94.7% (18/19) | Referenced pages support the associated answer |
| Appropriate Refusal Rate | 100% (6/6) | Unsupported queries are handled through refusal |
| Offline Completion Rate | 100% (25/25) | Test workflows finish without external network requests |

These figures are taken from the project's supplied benchmark summary and should be interpreted within the scope of its 25 test scenarios. They do not establish equivalent performance across all industrial equipment or operating environments.

**Evaluation documentation:** [View the benchmark report](./docs/EVALUATION_REPORT.md)

### Why the evaluation matters

Industrial troubleshooting requires more than a convincing AI response.

A technically useful assistant should identify relevant instructions, preserve their original context, and avoid inventing maintenance procedures when trustworthy evidence is unavailable.

EdgeRAG therefore evaluates both retrieval performance and answer reliability, including the ability to decline questions that cannot be supported by the available knowledge.

---

## ⚡ Getting Started

The repository includes startup scripts for launching the local development environment.

### Step 1 — Launch the platform services

From the repository root, execute:

```powershell
.\scripts\start\start_all.ps1
```

This script is intended to start the configured backend services, task worker, and headquarters web interface.

**Local development endpoints**

| Service | Address |
|---|---|
| Headquarters Portal | http://localhost:3000 |
| FastAPI Documentation | http://localhost:8000/docs |

For local network access, use the development computer's reachable IP address.

Common hotspot gateway examples include:

- Windows hotspot: `http://192.168.137.1:3000`
- Some mobile hotspot configurations: `http://192.168.43.1:3000`

These addresses are examples. Actual network addresses depend on the hotspot and device configuration.

### Step 2 — Launch the Android application

Navigate to the Flutter project:

```bash
cd apps/mobile
```

Start the application on a compatible Android device or emulator:

```bash
flutter run
```

The application is responsible for storing downloaded knowledge locally and supporting the configured offline retrieval and inference workflow.

### Step 3 — Execute the evaluation suite

Return to the repository root and run:

```bash
python tests/eval/eval_benchmark.py
```

This command executes the project's configured evaluation runner.

Review the output and compare the measured results against the documented benchmark before presenting performance claims.

---

## 📚 Documentation and Developer Resources

The repository includes focused guides for installation, AI configuration, network synchronization, troubleshooting, and team collaboration.

### Setup and operations

- [Beginner Setup Guide](./START_HERE.md) — Recommended first steps for new contributors.
- [Complete Execution Guide](./docs/guides/RUN_EVERYTHING_STEP_BY_STEP.md) — Instructions for launching and operating the platform.
- [No-Docker Setup](./docs/guides/NO_DOCKER_SETUP.md) — Local environment configuration without Docker.
- [Troubleshooting](./docs/guides/TROUBLESHOOTING.md) — Common setup and runtime problems.

### Knowledge synchronization and AI

- [Hotspot Synchronization](./docs/guides/HOTSPOT_SYNC_GUIDE.md) — Local transfer of knowledge packages.
- [Multimodal AI Configuration](./docs/ai/MULTIMODAL_AI_SETUP.md) — Setup guidance for supported multimodal features.
- [Gemma 4 E2B Installation](./docs/ai/INSTALL_GEMMA4_E2B.md) — Repository-specific model installation guidance.
- [Gemini API Configuration](./docs/ai/GEMINI_AND_API_KEYS.md) — Optional cloud integration and API key setup.

### Collaboration and evaluation

- [Team Development Workflow](./docs/team/TEAM_WORKFLOW.md) — Responsibilities, development branches, and integration procedures.
- [Benchmark Evaluation Report](./docs/EVALUATION_REPORT.md) — Test methodology and recorded results.

---

## 🔐 Offline Operation and Data Handling

EdgeRAG separates knowledge preparation from field-level knowledge consumption.

At headquarters, documents can be ingested, processed, validated, and packaged for distribution.

On the Android device, downloaded knowledge and compatible inference resources support local operation.

This separation is particularly useful for industrial environments where internet connectivity is unreliable, restricted, or intentionally disabled.

The offline workflow does not require an external AI API for supported local queries. Cloud-assisted features remain optional and require connectivity when enabled.

Package integrity, authorized distribution, and secure handling of sensitive operational documents should be considered during deployment.

---

## 🔮 Future Development Opportunities

Potential enhancements include:

- Expanded support for industrial equipment manuals and documentation formats.
- Improved retrieval evaluation across larger and more diverse datasets.
- More efficient on-device semantic search.
- Additional synchronization and conflict-resolution capabilities.
- Enhanced citation verification and evidence-quality scoring.
- Scalable document-processing workers for larger deployments.
- Further benchmarking on real-world maintenance questions.

---

## 🤝 Contributing

Contributors should follow the repository's development conventions and keep changes focused on their assigned modules.

Before creating a pull request:

1. Review the documentation for the relevant component.
2. Create a branch using the project's naming convention.
3. Implement and test the proposed change.
4. Verify compatibility with shared schemas and dependent services.
5. Submit a pull request with a clear description of the modification.

Additional guidelines are available in [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## 📄 License

The project is presented as MIT-licensed. Refer to the repository's license file for the applicable terms.

Third-party models, datasets, dependencies, and documentation may carry their own licenses and attribution requirements.

---

**EdgeRAG — Making industrial knowledge accessible where connectivity cannot be guaranteed.**
