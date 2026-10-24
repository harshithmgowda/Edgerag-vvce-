# EdgeRAG Complete End-to-End Demonstration Script

Follow this step-by-step scenario to demonstrate the full offline + online agentic capability of EdgeRAG.

---

## 🎭 The Demonstration Scenario

- **Role**: Field Service Engineer on an offshore oil production platform.
- **Problem**: Gas compressor alarm `ERR-4029` (High vibration & pressure drop).
- **Network Environment**: Air-gapped pump room 3 levels below sea deck; zero cellular signal.

---

## 📋 The 7 Demonstration Phases

### Phase 1: Headquarters Manual Ingestion
1. Administrator logs into `http://localhost:3000` (`admin` / `IndustrialAdmin2026!`).
2. Navigates to **Equipment** and selects or creates `Solar Taurus 60 Gas Turbine`.
3. Navigates to **Upload Manual**, selects `Taurus60_Maintenance_Manual.pdf`.
4. Observes real Celery processing job moving through stages:
   - `EXTRACTING_PAGES`
   - `CHUNKING` (224 tokens, 32 overlap)
   - `EMBEDDING` (`all-MiniLM-L6-v2`, 384 dimensions)
   - `GENERATING_SQLITE`
   - `PACKAGING` (`equipment-knowledge-v1.zip`)
5. Job finishes with status `SUCCEEDED`.
6. Checks **Knowledge Packages**: package `v1` is published with SHA-256 hash.

### Phase 2: Hotspot Pairing & Knowledge Sync
1. Turn on Windows Mobile Hotspot on laptop (SSID: `EdgeRAG-HQ`, IP: `192.168.137.1`).
2. Field engineer connects Android phone to `EdgeRAG-HQ`.
3. Opens Flutter app. App displays LAN banner: `HQ Network Detected: 192.168.137.1`.
4. Engineer navigates to **Sync** screen and taps **Check for Updates**.
5. App displays: `Update Available: Taurus 60 Knowledge v1 (12.4 MB)`.
6. Taps **Sync Now**:
   - Downloads package ZIP.
   - Verifies SHA-256 hash against server manifest.
   - Unpacks `knowledge.sqlite` safely.
   - Activates package atomically.
7. Displays: `Synchronized successfully at 14:32 UTC`.

### Phase 3: Airplane Mode Air-Gap Query (Offline Only)
1. Turn on **Airplane Mode** on the Android phone (Wi-Fi OFF, Cellular OFF, Bluetooth OFF).
2. App indicator switches to `MODE: OFFLINE ONLY` (Grey cloud with strike-through).
3. Select equipment: `Solar Taurus 60 Gas Turbine`.
4. Ask question: *"What does error code ERR-4029 mean and what is the emergency check?"*
5. Mobile Dart Agent executes:
   - Matches question against local 384-d vector embeddings in `knowledge.db`.
   - Retrieves Page 88: *"ERR-4029: Turbine 2nd Stage Inlet Pressure Drop"*.
   - llama.cpp generates local answer with zero cloud calls.
6. Displays grounded response and clickable citation chip: `[Page 88: Section 4.3.2]`.
7. Tapping the chip opens the exact manual page snippet.

### Phase 4: Offline Incident Creation
1. Inside the chat, tap **Create Incident from Answer**.
2. Form auto-populates title: *"ERR-4029 Pressure Drop on Turbine 2"*, equipment ID, and linked manual page (88).
3. Engineer adds technician notes: *"Inspected fuel filter assembly; discovered metal shavings. Ordered replacement cartridge."*
4. Sets Severity: `CRITICAL`.
5. Taps **Save Incident**.
6. Incident is saved to local `app_data.db` with permanent UUID `f47ac10b-...` and sync status `PENDING`.

### Phase 5: Reconnection & Outbox Synchronization
1. Re-enable Wi-Fi and connect back to `EdgeRAG-HQ` hotspot.
2. Flutter background sync sentinel detects HQ reachability.
3. Automatically posts pending outbox record to `/api/v1/sync/incidents`.
4. HQ returns `HTTP 200: { accepted_count: 1, synced_ids: ["f47ac10b-..."] }`.
5. Phone updates incident badge to `SYNCED (Green checkmark)`.

### Phase 6: Headquarters Admin Review
1. Administrator opens HQ Web Portal and clicks **Incidents**.
2. New incident immediately appears in the list:
   - Severity: `CRITICAL` (Red pill)
   - Title: `ERR-4029 Pressure Drop on Turbine 2`
   - Device: `SM-G998B (Field Device #4)`
   - Citation: `Page 88`
3. Administrator reviews technician notes, enters resolution order: *"Approved emergency replacement from warehouse stock B"*, and updates status to `IN_REVIEW`.

### Phase 7: Online Cloud Agentic RAG (Gemini BYOK)
1. Connect laptop and phone to regular internet Wi-Fi.
2. In Flutter app, switch AI Mode to `ONLINE AI` or `SMART AUTO`.
3. Ask a complex multi-stage engineering question:
   *"Compare the lubrication intervals of the main bearing under continuous 90% load vs intermittent duty cycle."*
4. LangGraph server agent (or phone online agent with Gemini key):
   - Retrieves multiple chunks across Chapter 3 and Chapter 7.
   - Evaluates evidence sufficiency; performs 1 query rewrite to pull viscosity tables.
   - Reasoner passes grounded context to Google Gemini 1.5 Flash.
   - Verifier checks assertions against retrieved pages.
5. Emits detailed synthesized response citing `[Page 34: Table 3-1]` and `[Page 71: Chart 7-4]`.
