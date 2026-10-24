# 🔰 START HERE: Welcome to EdgeRAG!

Hello and welcome to **EdgeRAG**! 👋

If you are an engineering student or beginner developer, this guide was written specifically for you. You don't need to be an expert in complex cloud architectures or Docker containers. This document explains what we built, how the pieces fit together, and exactly what to do next.

---

## 🌟 What is EdgeRAG?

Imagine an engineer working deep inside an underground power substation or on an offshore oil rig. 
- There is **no internet** and **no mobile cellular signal**.
- But the engineer needs to fix a multi-million-dollar machine whose manual is 800 pages of dense schematics.

**EdgeRAG solves this:**
1. At Headquarters, an administrator uploads the equipment PDF manual into a web dashboard.
2. The computer automatically reads the PDF, slices it into readable pieces (chunks), generates mathematical vectors (embeddings), and packs them into a lightweight `.zip` package.
3. The field engineer connects their Android phone to the laptop's Wi-Fi hotspot.
4. With one tap, the phone downloads the manual knowledge package over the local network (no internet required!).
5. The engineer walks deep underground in Airplane Mode and asks: *"What does error code ERR-4029 mean?"*
6. The phone's local offline AI searches its local database, finds the exact manual page, and answers with clickable page citations!
7. If the engineer discovers a broken part, they log an incident on their phone. When they return to the office, the phone automatically synchronizes the incident back to the headquarters dashboard!

---

## 📂 What Did We Build in This Folder?

Here is your tour of the `edgerag-product` folder:

```text
edgerag-product/
│
├── apps/
│   ├── hq-web/       💻 The Headquarters Web Portal (Next.js + React + Tailwind CSS)
│   │                 Where admins upload PDFs, view machines, and review incidents.
│   │
│   └── mobile/       📱 The Android Field Application (Flutter + Dart)
│                     The app running on the engineer's phone with dual SQLite databases.
│
├── services/
│   └── api/          ⚙️ The FastAPI Backend (Python)
│                     Runs on port 8000. Handles authentication, database, and LangGraph AI.
│
├── packages/
│   ├── rag-core/     🧠 Python RAG Engine (PyMuPDF + Chunking + 384-d Embeddings)
│   │                 Extracts text from PDFs and builds the `.zip` knowledge packages.
│   │
│   └── mobile-ai/    📱 Mobile On-Device AI Package (Dart)
│                     Does fast cosine vector similarity directly inside the phone.
│
├── contracts/        📜 The API & Data Rules (OpenAPI 3.0 specification & JSON schemas)
│
├── scripts/          ⚡ Helper Scripts
│   ├── start/        Double-click or run scripts to start everything easily.
│   ├── stop/         Cleanly terminates all running services.
│   └── verify/       Tests if your computer has all required software installed.
│
└── docs/             📚 Technical Documentation & Team Handoffs
```

---

## 🔄 How Do the Components Talk to Each Other?

There are two main connections:

1. **Web Dashboard $\leftrightarrow$ Backend**:
   - The Next.js website (running on `http://localhost:3000`) talks to FastAPI (running on `http://localhost:8000/api/v1`).
2. **Android Phone $\leftrightarrow$ Backend (Over Hotspot)**:
   - When you turn on Windows Mobile Hotspot on your laptop, your laptop becomes `192.168.137.1`.
   - The phone connects to that Wi-Fi and talks to `http://192.168.137.1:8000/api/v1`.
   - Public internet is NOT required for this to work!

---

## 🎯 Which Guide Should You Read Next?

Please open:

👉 **[`RUN_EVERYTHING_STEP_BY_STEP.md`](./RUN_EVERYTHING_STEP_BY_STEP.md)**

It provides numbered, click-by-click instructions showing you how to install missing software, start the backend, open the website, and run the mobile app!
