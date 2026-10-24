# Member 4 Handoff: AI, LangGraph & Knowledge Engineering

## 1. Executive Summary & Capabilities Delivered

Member 4 has developed the complete offline and online AI infrastructure across `packages/rag-core` and `services/api/app/ai`.

| Subsystem | Architecture & Tech | Invariants Enforced |
|---|---|---|
| **PDF Extraction** | PyMuPDF (`fitz`) | Retains page numbers, detects empty pages, flags OCR requirements for scanned diagrams. |
| **Chunking Engine** | `TokenAwareChunker` | Target ~224 tokens, 32 overlap tokens, tracks manual and equipment UUIDs. |
| **Embeddings** | `sentence-transformers` (`all-MiniLM-L6-v2`) | Strictly 384 dimensions, L2-normalized unit vectors, binary float32 storage. |
| **Package Builder** | `KnowledgePackageBuilder` | Compiles `knowledge.sqlite`, generates `manifest.json`, archives into ZIP, validates SHA-256. |
| **LangGraph Agent** | LangGraph `StateGraph` | 7-node state machine: Planner -> Retriever -> Evidence Check -> Query Rewriter (max 2 retries) -> Tool Controller -> Reasoner -> Verifier. |
| **Observable Trace** | Trace logging | Emits real events: `[PLANNER]`, `[RETRIEVER]`, `[EVIDENCE]`, `[TOOL]`, `[REASONER]`, `[VERIFIER]`. |
| **Online Gemini** | `GeminiAdapter` | Grounded system instructions requiring source citation tags `[Page X]`. |

---

## 2. Server vs. Mobile Agentic Parity

- **Server-Side Agent**: Runs full Python LangGraph compiled graph with dynamic tooling and multi-turn query rewriting.
- **Mobile On-Device Agent**: Replicates the exact state machine in pure Dart (`services/agent_controller.dart`), computing 384-dimensional cosine similarity against the downloaded SQLite database and generating grounded responses with zero cloud connectivity.
