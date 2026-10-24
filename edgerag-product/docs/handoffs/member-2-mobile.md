# Member 2 Handoff: Flutter Android Field Application

## 1. Executive Summary & Implemented Features

Member 2 has developed the complete Android-first **Flutter Field Application** inside `apps/mobile` and `packages/mobile-ai`.

| Feature | Implementation Component | Contract & Persistence |
|---|---|---|
| **Dual SQLite Storage** | `services/database_service.dart` | Database A (`app_data.db`) stores user chats & incident outbox; Database B (`knowledge_{id}.db`) stores read-only vector chunks. |
| **Hotspot Sync Client** | `services/sync_service.dart` | Fetches package delta via `/sync/check`, verifies SHA-256 digest, Zip-Slip path traversal defense, atomic `.sqlite` activation. |
| **Incident Outbox Sync** | `services/sync_service.dart` | Reads pending incidents with permanent UUIDs; calls `POST /api/v1/sync/incidents` idempotently. |
| **4-State Network Sentinel**| `services/network_service.dart` | Detects `offlineAirgap`, `hqLanHotspot`, `publicInternetOnly`, `fullyConnected`. |
| **Mobile Agent FSM** | `services/agent_controller.dart` | Bounded Dart finite state machine (Planner -> Cosine Search -> Sufficiency -> Query Rewrite -> Reasoner -> Verifier). |
| **Google Gemini BYOK** | `services/gemini_service.dart` | Direct cloud grounding with Android Keystore backed secret storage and live connection test. |
| **18 Screens Implemented**| `lib/screens/*.dart` | Onboarding, Login, HQ Setup, Registration, Equipment, Dashboard, AI Chat with Citation Chips, Incident Outbox, Settings, etc. |

---

## 2. Shared Contracts & Files Created

- Mobile Project Root: [`apps/mobile`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/mobile)
- Domain Models: [`apps/mobile/lib/models/models.dart`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/mobile/lib/models/models.dart)
- Database Manager: [`apps/mobile/lib/services/database_service.dart`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/mobile/lib/services/database_service.dart)
- Agent Controller: [`apps/mobile/lib/services/agent_controller.dart`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/mobile/lib/services/agent_controller.dart)
- On-Device AI Package: [`packages/mobile-ai`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/packages/mobile-ai)

---

## 3. How to Run on Android

```bash
cd edgerag-product/apps/mobile
flutter pub get
flutter run
```

---

## 4. Exact Integration Instructions for Member 3 (Backend)

1. **Hotspot IP Binding**: Ensure FastAPI binds to `0.0.0.0:8000` so the mobile app can reach `http://192.168.137.1:8000/api/v1`.
2. **Cleartext HTTP Support**: On Android 9+, HTTP traffic is blocked by default. `AndroidManifest.xml` already sets `android:usesCleartextTraffic="true"`.
3. **Idempotent Incidents**: When Member 3 writes the incident sync endpoint `/api/v1/sync/incidents`, use the incident's `id` (UUID) as the primary key with `ON DUPLICATE KEY UPDATE` to guarantee idempotency.
4. **Knowledge Package Format**: Member 3 must bundle `knowledge.sqlite` and `manifest.json` into a `.zip` file with SHA-256 hash matching the manifest.
