# 📘 RUN EVERYTHING STEP-BY-STEP (Complete Beginner Runbook)

Welcome! This is the master guide for running **EdgeRAG** on your Windows laptop. Every step is written in simple, numbered instructions. Follow them one by one.

---

## 📑 Table of Contents

- [Chapter A: Required Software Installation](#chapter-a-required-software-installation)
- [Chapter B: Open the Project in VS Code](#chapter-b-open-the-project-in-vs-code)
- [Chapter C: Configure the Backend](#chapter-c-configure-the-backend)
- [Chapter D: Start Every Service](#chapter-d-start-every-service)
- [Chapter E: Start and Use the Website](#chapter-e-start-and-use-the-website)
- [Chapter F: Run the Flutter Android App](#chapter-f-run-the-flutter-android-app)
- [Chapter G: Synchronize Using Hotspot](#chapter-g-synchronize-using-hotspot)
- [Chapter H: Install Offline AI Models](#chapter-h-install-offline-ai-models)
- [Chapter I: Configure Google Gemini API](#chapter-i-configure-google-gemini-api)
- [Chapter J: Test LangGraph Agentic RAG](#chapter-j-test-langgraph-agentic-rag)
- [Chapter K: Test Offline Incident Sync](#chapter-k-test-offline-incident-sync)
- [Chapter L: Build the Android APK](#chapter-l-build-the-android-apk)
- [Chapter M: Stop & Restart Everything](#chapter-m-stop--restart-everything)
- [Chapter N: Common Errors & Exact Fixes](#chapter-n-common-errors--exact-fixes)

---

## Chapter A: Required Software Installation

> 💡 **Notice**: We do **NOT** use Docker. Everything runs natively on your Windows laptop!

Before we start, verify that the following tools are installed. If any are missing, download them from their official websites:

1. **Git for Windows**:
   - Download from: [https://git-scm.com/download/win](https://git-scm.com/download/win)
   - Keep default settings during installation.
2. **Visual Studio Code (VS Code)**:
   - Download from: [https://code.visualstudio.com/Download](https://code.visualstudio.com/Download)
3. **Python (Version 3.10, 3.11, or 3.12)**:
   - Download from: [https://www.python.org/downloads/](https://www.python.org/downloads/)
   - ⚠️ **VERY IMPORTANT**: During installation, check the box: **"Add python.exe to PATH"**!
4. **Node.js (LTS version 20 or 22)**:
   - Download from: [https://nodejs.org/en/download/](https://nodejs.org/en/download/)
   - Includes `npm` automatically.
5. **Flutter SDK**:
   - Download from: [https://docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
   - Extract to `C:\src\flutter` and add `C:\src\flutter\bin` to your System PATH environment variables.
6. **Android Studio**:
   - Download from: [https://developer.android.com/studio](https://developer.android.com/studio)
   - Install the **Android SDK Platform-Tools** and **Android SDK Command-line Tools**.

---

## Chapter B: Open the Project in VS Code

1. Launch **VS Code**.
2. Click **File** in the top menu $\to$ **Open Folder...**
3. Navigate to:
   `c:\Users\Harshith\OneDrive\Desktop\edgerag\edgerag-product`
4. Click **Select Folder**.
5. Open a new terminal:
   Click **Terminal** in the top menu $\to$ **New Terminal** (or press `` Ctrl + ` ``).
6. Verify your terminal is in the project root by running:
   ```powershell
   Get-Location
   ```
   *Expected output*: `...\edgerag-product`

---

## Chapter C: Configure the Backend

The backend comes pre-configured with safe development defaults.

1. In your VS Code terminal, copy the example environment file:
   ```powershell
   Copy-Item .env.example .env
   ```
2. By default, EdgeRAG uses SQLite (`edgerag_dev.db`) for immediate zero-dependency operation. You do not need to install MySQL or Redis just to test the application!
3. If you have MySQL installed, open `.env` and set:
   ```env
   DATABASE_URL=mysql+pymysql://root:yourpassword@127.0.0.1:3306/edgerag_db
   ```

---

## Chapter D: Start Every Service

We have created an automated launcher script that starts all services in separate PowerShell windows!

1. In your VS Code terminal, run:
   ```powershell
   .\scripts\start\start_all.ps1
   ```
2. Three separate PowerShell windows will open:
   - **Window 1 (Backend)**: Runs FastAPI at `http://0.0.0.0:8000`.
   - **Window 2 (Worker)**: Runs the background PDF processing worker.
   - **Window 3 (Website)**: Runs the Next.js web application at `http://localhost:3000`.
3. Keep these terminal windows open while working!

---

## Chapter E: Start and Use the Website

1. Open your browser (Google Chrome or Edge) and go to:
   👉 **[http://localhost:3000](http://localhost:3000)**
2. You will see the **EdgeRAG Login Screen**:
   - **Username**: `admin`
   - **Password**: `IndustrialAdmin2026!`
   - Click **Sign In**.
3. You are now on the **Headquarters Command Center**:
   - Notice that all metrics start at `0` (Zero fake data!).
4. **Register Equipment**:
   - Click **Equipment** in the left sidebar $\to$ Click **Register Equipment**.
   - Asset Name: `Siemens S7-1500 Modular PLC`
   - Model Number: `6ES7516-3AN02`
   - Manufacturer: `Siemens AG`
   - Serial Number: `SN-2026-X9920`
   - Click **Save Equipment**.
5. **Upload a Manual**:
   - Click **Upload Manual** in the sidebar.
   - Select the Siemens PLC equipment.
   - Title: `S7-1500 System Diagnostic Manual`
   - Revision: `v1.0.0`
   - Drag and drop any technical PDF file (or a test PDF).
   - Click **Start RAG Ingestion**.
6. **Watch the Processing Job**:
   - Click **Processing Jobs** in the sidebar.
   - You will see the progress bar move:
     `EXTRACTING_PAGES` $\to$ `CHUNKING` $\to$ `EMBEDDING` $\to$ `PACKAGING` $\to$ `SUCCEEDED`.
7. **View Knowledge Package**:
   - Click **Knowledge Packages** in the sidebar.
   - You will see package `v1` with its 384-dimensional specification and SHA-256 hash!

---

## Chapter F: Run the Flutter Android App

1. Connect your Android phone to your laptop using a USB cable.
2. On your phone, enable Developer Options:
   - Go to **Settings $\to$ About Phone $\to$ Tap "Build Number" 7 times**.
   - Go to **Settings $\to$ System $\to$ Developer Options $\to$ Turn ON "USB Debugging"**.
3. In VS Code, open a new terminal tab and check if your device is detected:
   ```powershell
   flutter devices
   ```
   *Expected output*: Shows your phone model (e.g., `SM-G998B (mobile)`).
4. Navigate to the mobile app folder and run:
   ```powershell
   cd apps\mobile
   flutter pub get
   flutter run
   ```
5. The app will compile and launch on your phone!

---

## Chapter G: Synchronize Using Hotspot

> ⚠️ **CRITICAL FOR BEGINNERS**: Your phone cannot reach `http://localhost:8000` because `localhost` on the phone means the phone itself!

1. On your Windows laptop:
   - Click Windows Start $\to$ Settings $\to$ **Network & internet** $\to$ **Mobile hotspot**.
   - Turn **Mobile hotspot** to **ON**.
   - Note the Network name (SSID) and Password.
2. On your Android phone:
   - Connect to your laptop's Wi-Fi hotspot.
3. Open the **EdgeRAG** app on your phone:
   - The app will show: `HQ Network Detected: 192.168.137.1`.
   - Tap **Hotspot Synchronization**.
   - Tap **Check Updates**.
   - The app finds the manual package you uploaded on your laptop!
   - Tap **Install**.
   - The phone downloads the `.zip`, validates the SHA-256 hash, and unpacks `knowledge.sqlite`.
   - Your phone now holds the manual locally!

---

## Chapter H: Install Offline AI Models (Gemma 4 & Qwen 2.5)

To answer questions and understand images/audio without internet, EdgeRAG supports on-device multimodal models:
1. **Primary Multimodal Model (Preferred)**:
   - **Google Gemma 4 E2B IT** (~2.1 GB LiteRT-LM format)
   - Supports: Text, Image Understanding, Audio Transcription, and Structured Agent Tools.
   - 👉 Detailed Guide: **[INSTALL_GEMMA4_E2B.md](./INSTALL_GEMMA4_E2B.md)**
2. **Fast On-Device Reasoner (Pre-Installed on Test Device)**:
   - **Qwen 2.5 0.5B Instruct** (468.6 MB GGUF)
   - Runs at 18+ tokens/second on mobile CPUs with minimal battery consumption.
   - Installed at: `/sdcard/Android/data/com.edgerag.mobile/files/models/qwen2.5-0.5b-instruct-q4_k_m.gguf`.
3. **High-Accuracy Technical Reasoner**:
   - **Phi-3-mini-4k-instruct-q4.gguf** (~2.18 GB).
4. **How to Install Models**:
   - Push via ADB:
     ```powershell
     adb push your_model.bin /sdcard/Android/data/com.edgerag.mobile/files/models/
     ```
   - Or tap **Explore AI** $\to$ **Model Manager** $\to$ **Import File** in the EdgeRAG app.
5. In EdgeRAG on your phone, open **Explore AI** $\to$ **Model Manager** $\to$ Verify your model is marked `Installed`.

---

## Chapter I: Configure Google Gemini API

When you have internet and want online cloud AI reasoning:
1. Get a free Google Gemini API key:
   - Open: [https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)
   - Click **Create API Key**.
2. **On Headquarters Web Portal**:
   - Go to **AI Providers** $\to$ Paste your key $\to$ Click **Test Connection** $\to$ Click **Save Configuration**.
3. **On Android Phone (BYOK)**:
   - Go to **Settings $\to$ External AI Providers (BYOK)** $\to$ Paste your key $\to$ Tap **Test & Save**.
   - The key is securely stored in the hardware **Android Keystore**.

---

## Chapter J: Test LangGraph Agentic RAG

1. On the Headquarters Web Portal:
   - Open the interactive Swagger API docs: [http://localhost:8000/docs](http://localhost:8000/docs)
2. Scroll to `POST /api/v1/ai/chat` $\to$ Click **Try it out**.
3. Enter JSON:
   ```json
   {
     "question": "What is the emergency shutdown procedure for the PLC?",
     "equipment_id": "PASTE_YOUR_EQUIPMENT_UUID_HERE",
     "ai_mode": "SMART_AUTO"
   }
   ```
4. Click **Execute**.
5. Observe the response:
   - `answer`: Grounded explanation citing exact manual pages.
   - `execution_trace`: Real observable events:
     `[PLANNER]`, `[RETRIEVER]`, `[EVIDENCE]`, `[TOOL]`, `[REASONER]`, `[VERIFIER]`.

---

## Chapter K: Test Offline Incident Sync

1. On your phone, turn ON **Airplane Mode** (Wi-Fi OFF, Cellular OFF).
2. The EdgeRAG app switches to: `OFFLINE AIR-GAP`.
3. Tap **Record Field Incident**:
   - Title: `Water Leakage Near Main Pump`
   - Severity: `CRITICAL`
   - Description: `Observed cooling water leaking onto busbar tray.`
   - Tap **Save to Offline Outbox**.
4. Restart the phone or app $\to$ The incident is still safely stored in local SQLite!
5. Turn OFF Airplane Mode $\to$ Reconnect to laptop hotspot.
6. Tap **Hotspot Synchronization** $\to$ Tap **Sync Outbox**.
7. Go to your laptop website $\to$ Click **Incidents**:
   - The incident appears immediately for administrative review!

---

## Chapter L: Build the Android APK

To generate a standalone `.apk` file you can install on any Android phone:
1. In VS Code terminal:
   ```powershell
   cd apps\mobile
   flutter build apk --debug
   ```
2. The generated installer file is saved at:
   `apps\mobile\build\app\outputs\flutter-apk\app-debug.apk`
3. Copy this file to your phone and tap it to install!

---

## Chapter M: Stop & Restart Everything

To cleanly shut down all running background processes:
1. In your VS Code terminal, run:
   ```powershell
   .\scripts\stop\stop_all.ps1
   ```
2. All running Python, Celery, and Node.js processes will stop.
3. To start them again later, simply run `.\scripts\start\start_all.ps1`!

---

## Chapter N: Common Errors & Exact Fixes

| Problem | Cause | Exact Fix |
|---|---|---|
| `'python' is not recognized` | Python was installed without checking "Add to PATH". | Reinstall Python and check the box **"Add python.exe to PATH"** on the first screen. |
| Phone says `Connection refused` | Using `localhost:8000` on the phone. | In the app's LAN setup screen, change the URL to `http://192.168.137.1:8000/api/v1`. |
| Windows Firewall blocks hotspot | Windows Defender Firewall blocking port 8000. | Run in PowerShell as Administrator: `New-NetFirewallRule -DisplayName "EdgeRAG Backend" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow` |
| `Redis connection error` | Redis is not running locally. | EdgeRAG automatically falls back to synchronous processing! You do not need to do anything. |
| PDF upload says `File too large` | PDF exceeds 50 Megabytes. | Upload a manual smaller than 50MB. |
