# 📱 Track 2: Mobile Application (`apps/mobile`)

**Assigned Team Member**: Member 2 (Mobile & Edge UI Lead)  
**Tech Stack**: Flutter 3.2.0+, Dart, SQLite (`sqflite`), `flutter_edge_ai`, LiteRT-LM, Fllama (GGUF), Speech-to-Text  
**Git Scope**: `feat(mobile): <description>` or `fix(mobile): <description>`  
**Dedicated Branch**: `track/mobile-app` (or feature branches `feat/mobile/<feature-name>`)

---

## 🎯 Domain & Responsibilities

You own the **Android Field Technician Application** running 100% offline in air-gapped industrial environments:
1. **Interactive AI Assistant**: Bounded adaptive RAG chat with 3-tier evidence status (`MANUAL_SUPPORTED`, `GENERAL_GUIDANCE`, `INSUFFICIENT`).
2. **Hybrid Retrieval**: On-device keyword matching (for exact error codes/parts) + MiniLM cosine embeddings (for symptoms).
3. **Inspectable Sources**: Expandable citation cards with manual revision, package version, page number, and PDF jump.
4. **Resilient Synchronization**: Atomic SQLite database replacement over Windows/Phone Wi-Fi Hotspot with download rollback.
5. **Multimodal AI**: Camera diagnostics, audio voice transcription, and offline incident reporting.
6. **Air-Gap Incident Outbox**: Local SQLite incident queue with automatic upload when connecting to HQ Hotspot.

---

## 📁 Folder Structure

```
apps/mobile/
├── android/                  # Native Android configuration & permissions
├── assets/                   # Offline fonts (Roboto, Metropolis), icons, mock packages
├── lib/
│   ├── models/               # Data contracts (Chat, Incident, Package, Device)
│   │   └── models.dart
│   ├── screens/              # Flutter UI views & screen controllers
│   │   ├── ai_chat_screen.dart           # RAG Chat & Source Verification Cards
│   │   ├── ask_image_screen.dart         # Multimodal Camera Vision Diagnostics
│   │   ├── audio_scribe_screen.dart      # Hands-free Technician Audio Notes
│   │   ├── home_dashboard_screen.dart    # Telemetry, Status & Navigation Hub
│   │   ├── hotspot_sync_screen.dart      # Atomic Package Sync & Outbox Manager
│   │   ├── hq_connection_screen.dart     # Hotspot Subnet Radar & Web Portal Link
│   │   ├── incident_logging_screen.dart  # Offline Incident Recorder
│   │   ├── manual_viewer_screen.dart     # Offline PDF Page Viewer
│   │   └── settings_screen.dart          # Device Settings & BYOK Providers
│   ├── services/             # Core mobile logic & edge services
│   │   ├── agent_controller.dart         # Bounded 3-attempt retrieval loop
│   │   ├── database_service.dart         # SQLite Dual-DB manager (App DB + Knowledge DB)
│   │   ├── knowledge_retrieval.dart      # Hybrid lexical + semantic search
│   │   ├── local_ai_service.dart         # On-device Gemma / LiteRT-LM inference
│   │   ├── network_service.dart          # Hotspot radar & gateway discovery
│   │   ├── semantic_encoder.dart         # On-device embedding similarity
│   │   └── sync_service.dart             # Atomic package replacement & rollback
│   └── main.dart             # App bootstrap & theme initialization
├── pubspec.yaml              # Flutter dependencies & assets
└── README.md                 # This track guide
```

---

## 🚀 Development Workflow

```bash
# 1. Navigate to your track folder
cd apps/mobile

# 2. Get dependencies
flutter pub get

# 3. Analyze code quality
flutter analyze

# 4. Run on connected Android device or emulator
flutter run
```

---

## 💡 How to Add a New Feature

1. Add your UI widget/screen in `lib/screens/<feature>_screen.dart`.
2. Add necessary database queries in `lib/services/database_service.dart`.
3. Wire the navigation into `lib/screens/home_dashboard_screen.dart`.
4. Validate with `flutter analyze` before committing.

---

## 📤 Git Commit & Contribution Guide

When making changes to Track 2, always use the `mobile` scope:

```bash
git checkout -b feat/mobile/voice-waveform
# Make your edits in apps/mobile/
git add apps/mobile/
git commit -m "feat(mobile): add animated audio waveform during speech-to-text recording"
git push origin feat/mobile/voice-waveform
```
*(Your commits will cleanly highlight your contributions on the team's GitHub commit graph without any file conflicts with other members!)*
