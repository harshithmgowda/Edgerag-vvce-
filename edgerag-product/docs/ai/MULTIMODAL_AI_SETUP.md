# 🚀 EdgeRAG Multimodal AI Architecture & Setup Guide

EdgeRAG has been upgraded from a text-only RAG assistant into a complete **on-device and hybrid Multimodal AI Platform** built natively for industrial field engineers and technicians working in air-gapped, hazardous, or offline environments.

---

## 🏛️ System Architecture Overview

EdgeRAG combines a **Dual-Database Architecture** with a **Multi-Model Orchestration Engine**:

```
                                  +------------------------------------+
                                  |   Explore AI: Model Hub Screen     |
                                  |  (8 Apple-Inspired Category Cards) |
                                  +-----------------+------------------+
                                                    |
         +-------------------+----------------------+--------------------+--------------------+
         |                   |                      |                    |                    |
   [ AI Chat ]        [ Ask Image ]         [ Audio Scribe ]     [ Video Insights ]   [ Doc Scanner ]
  Text + Media        Camera/Gallery         Mic Record/WAV        Frame Extraction     Label OCR + RAG
         |                   |                      |                    |                    |
         +-------------------+----------------------+--------------------+--------------------+
                                                    |
                                                    v
                             +-----------------------------------------------+
                             |         Agent Skills & Execution Router       |
                             |  (7 Bounded Skills, Strict Allowlist, Security)|
                             +----------------------+------------------------+
                                                    |
                    +-------------------------------+-------------------------------+
                    |                                                               |
                    v                                                               v
      +-----------------------------+                                 +-----------------------------+
      |    On-Device AI Engine      |                                 |    Cloud Fallback Engine    |
      | - Gemma 4 E2B IT (LiteRT-LM)|                                 | - NVIDIA NIM Llama 3.2 11B  |
      | - Qwen 2.5 0.5B (GGUF)      |                                 | - Google Gemini 2.0 Flash   |
      | - Whisper ASR / System TTS  |                                 | (BYOK Secure Key Storage)   |
      +--------------+--------------+                                 +--------------+--------------+
                     |                                                               |
                     +------------------------------+--------------------------------+
                                                    |
                                                    v
                                  +------------------------------------+
                                  |    Grounding & Verification Layer  |
                                  |  Database A: app_data.db (Incidents|
                                  |  Database B: knowledge_{id}.db     |
                                  |   - 384-d Cosine Vector Chunks     |
                                  |   - Exact Page Numbers & Manuals   |
                                  +------------------------------------+
```

---

## 📱 The 8 Multimodal Capabilities & Model Power Matrix

| # | Capability | Primary Model (Offline) | Cloud Fallback | Features & RAG Grounding |
|---|---|---|---|---|
| **1** | **AI Chat** | **Gemma 4 E2B IT** / **Qwen 2.5 0.5B** | NVIDIA NIM / Gemini 2.0 | Multimodal composer, live streaming, manual attachment, TTS speech readout, page citations. |
| **2** | **Agent Skills** | **Gemma 4 E2B IT** / Native Dart Engine | NIM Function Calling | 7 authorized industrial operations, parameter validation, JSON trace, error recovery. |
| **3** | **Ask Image** | **Gemma 4 E2B IT** (Vision) | NVIDIA Llama 3.2 11B Vision | Camera capture, gallery picker, gauge readings, fault light detection, manual cross-referencing. |
| **4** | **Audio Scribe** | **Whisper Base** / **Gemma 4 Audio** | Gemini 2.0 Flash Audio | Microphone recording, voice note transcription, translation, summary, direct RAG questioning. |
| **5** | **Video Insights** | **Gemma 4 E2B IT** (Multi-Frame) | NVIDIA NIM Vision | Short video ingestion, timestamped frame extraction (0.5s, 2.5s, 5.0s), motion and component analysis. |
| **6** | **Document Scanner** | **Gemma 4 E2B IT** / Mobile OCR | NVIDIA NIM / Gemini Vision | Industrial nameplate scanning, serial number extraction, error code lookup against SQLite manuals. |
| **7** | **Voice Assistant** | **SpeechToText + Qwen/Gemma + TTS** | NIM Voice Pipe | Push-to-talk voice pipeline: Mic -> Speech-to-Text -> Vector RAG -> LLM -> Text-to-Speech answer. |
| **8** | **Model Manager** | **Typed Multi-Model Registry** | System Health Monitor | Storage auditor, checksum verification, model profile catalog, task routing, safe model deletion. |

---

## 🛠️ Detailed Feature Breakdown

### 1. AI Chat (`AiChatScreen`)
- **Attachment Bottom Sheet**: Technicians can tap the paperclip icon to attach:
  - Live Camera Snapshot
  - Gallery Image
  - Recorded Audio Note
  - Attached Equipment Technical Manual
- **Dual Text & Visual Grounding**: Visual observations are blended with SQLite manual embeddings before query dispatch.
- **Audio Readout**: Any response can be read aloud using Android Text-to-Speech with markdown stripping.

### 2. Agent Skills (`AgentSkillsScreen`)
All skills are subject to a **strict allowlist** preventing arbitrary shell execution, unauthorized file deletion, or unapproved network transmissions:
1. `search_equipment_manual`: Performs keyword and vector ranking over SQLite chunks.
2. `read_manual_page`: Retrieves full markdown and schematics for an exact manual page.
3. `explain_equipment_error`: Correlates machine fault codes (e.g. `F07800`, `E-04`) with troubleshooting steps.
4. `analyze_image`: Executes multimodal vision inspection and extracts component observations.
5. `transcribe_audio`: Transcribes field voice notes into verified maintenance logs.
6. `create_incident_draft`: Assembles symptoms into an incident ticket with mandatory technician confirmation.
7. `check_knowledge_readiness`: Audits SQLite tables, chunk counts, and 384-dimensional vector indices.

### 3. Ask Image (`AskImageScreen`)
- High-resolution camera capture with auto-compression (88% JPEG quality) to prevent Out-Of-Memory (OOM) errors.
- Visual inspection extracts physical attributes: digital gauge levels, warning indicators, and component wear.
- Visual evidence is correlated with downloaded manual chunks to output an authorized repair procedure.

### 4. Audio Scribe (`AudioScribeScreen`)
- Live audio recording with real-time waveform animation and duration timer.
- Converts voice notes into technical English transcripts.
- One-tap actions:
  - **Ask EdgeRAG**: Routes transcript directly into the RAG diagnostics engine.
  - **Log as Incident**: Pre-fills an official maintenance ticket.
  - **Copy / Share**: Exports the verified text.

### 5. Video Insights (`VideoInsightsScreen`)
- Resource-conscious frame extraction: avoids decoding entire videos in memory.
- Samples 3 representative frames across the timeline (0.5s, 2.5s, 5.0s).
- Correlates observed operational movement with maintenance manual sections.

### 6. Document Scanner (`DocumentScannerScreen`)
- Designed for technical nameplates, warning decals, and wiring diagrams.
- OCR extracts alphanumeric serials, model IDs, and voltage ratings.
- Automatically searches SQLite `chunks` table for matching specifications.

### 7. Voice Assistant (`VoiceAssistantScreen`)
- Hands-free field interaction designed for technicians wearing industrial gloves.
- Push-to-talk microphone listening with speech-to-text.
- Vector retrieval searches manual chunks for spoken technical terms.
- Speaks the verified instruction aloud via Android TTS.

### 8. Model Manager (`ModelManagerScreen`)
- Audits device storage at `/sdcard/Android/data/com.edgerag.mobile/files/models`.
- Displays genuine installed status, memory estimates, and verified download links.
- Allows deleting individual models without touching user incidents, chat history, or downloaded PDF knowledge.
