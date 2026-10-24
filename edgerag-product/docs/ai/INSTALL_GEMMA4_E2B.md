# 💎 Google Gemma 4 E2B IT Installation & Verification Guide

This guide covers obtaining, importing, verifying, and running **Google Gemma 4 E2B IT** on Android with EdgeRAG.

---

## 📋 Model Specifications

| Attribute | Specification |
|---|---|
| **Model Name** | Google Gemma 4 E2B IT (Instruction-Tuned) |
| **Model Family** | Gemma 4 |
| **Official Repository** | [HuggingFace: litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm) |
| **Target Runtime** | Google LiteRT-LM / Flutter Edge AI (`flutter_edge_ai`) |
| **File Format** | `.tflite` / `.bin` (LiteRT-LM format) or quantized `.gguf` fallback |
| **File Size** | ~2.1 GB to 2.4 GB (4-bit quantized) |
| **Supported Inputs** | Text, Image, Audio, Structured Function Calling |
| **Supported Output** | Text (Streaming) |
| **Minimum Hardware** | Android 8.0+ (API Level 26+), arm64-v8a architecture |
| **Recommended RAM** | Minimum 4 GB RAM (8 GB+ recommended for large context) |
| **License** | Google Gemma Terms of Use (Permissive open model license for research and commercial applications) |

---

## 📥 How to Obtain the Model File

### Option A: Direct Download via Hugging Face CLI / Python
```bash
# Install Hugging Face CLI
pip install huggingface_hub

# Download Gemma 4 E2B IT LiteRT-LM model package
huggingface-cli download litert-community/gemma-4-E2B-it-litert-lm --local-dir ./gemma-4-e2b
```

### Option B: Web Browser Download
1. Visit the repository: [https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/tree/main](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/tree/main)
2. Locate the model binary: `gemma-4-e2b-it.bin` (or `model.tflite`).
3. Download the file directly to your computer or Android Downloads folder.

---

## 📲 How to Install onto Android Device (Pixel 9a or similar)

### Method 1: Push via ADB (Fastest & Direct)
Connect your device with USB Debugging enabled:
```powershell
# 1. Verify device is connected
adb devices

# 2. Create the models directory inside EdgeRAG's app storage
adb shell mkdir -p /sdcard/Android/data/com.edgerag.mobile/files/models

# 3. Push the model file onto the device
adb push ./gemma-4-e2b-it.bin /sdcard/Android/data/com.edgerag.mobile/files/models/
```

### Method 2: Import from In-App Model Manager
1. In the EdgeRAG app, open **Explore AI** -> **Model Manager** (top-right tuning icon).
2. Locate the **Google Gemma 4 E2B IT** card.
3. Tap **Import File**.
4. Use the Android file picker to select the downloaded model file from your `Downloads` directory.
5. EdgeRAG will copy the file into the protected application folder and verify its integrity.

---

## ✅ Verifying Successful Installation

1. Open EdgeRAG and navigate to **Explore AI** -> **Model Manager**.
2. Under **Google Gemma 4 E2B IT**, you should see:
   - Green pill: `Installed`
   - Active path: `/sdcard/Android/data/com.edgerag.mobile/files/models/gemma-4-e2b-it.bin`
   - Model count on Model Hub cards (AI Chat, Ask Image, Audio Scribe) will increment to reflect the available on-device model.

---

## 🧪 Testing Features with Gemma 4 E2B IT

### 1. Testing Text Generation (Offline)
1. In Home Dashboard, toggle AI Mode to **Offline Only**.
2. Open **AI Chat**.
3. Type: `What are the step-by-step procedures to bleed air from the pump casing?`
4. Verify response:
   - Status will show `Thinking (Gemma 4 E2B IT)…`
   - The response will stream in Markdown format with verified `[Source CHUNK_ID]` page citations.

### 2. Testing Image Understanding (Ask Image)
1. Open **Ask Image**.
2. Tap **Take Photo** and photograph an equipment nameplate or pressure gauge.
3. Ask: `What is the current pressure reading on this dial?`
4. Tap **Run Visual Diagnostics**.
5. Verify response:
   - Visual observation list will highlight visible dial markers.
   - Grounded recommendation will pull authorized safe PSI ranges from the downloaded manual.

### 3. Testing Audio Processing (Audio Scribe)
1. Open **Audio Scribe**.
2. Tap the blue microphone button and speak for 5 seconds: `Excessive bearing noise observed during stage 2 startup.`
3. Tap **Stop & Transcribe**.
4. Tap **Ask EdgeRAG about this Problem** to route the spoken anomaly directly into the RAG engine.

---

## 🔧 Troubleshooting & Failure Recovery

| Issue | Root Cause | Solution |
|---|---|---|
| **Model shows "Missing" after pushing file** | File placed in wrong path or permission issue. | Confirm path via `adb shell ls -l /sdcard/Android/data/com.edgerag.mobile/files/models/`. Refresh Model Manager screen. |
| **Out-Of-Memory (OOM) error on startup** | Device has insufficient free RAM (< 1.5 GB). | Close background apps or select the lightweight **Qwen 2.5 0.5B** profile (requires only 650 MB RAM). |
| **Inference fails with GPU backend error** | Device Vulkan driver incompatibility. | In Model Manager, toggle hardware acceleration to **CPU Only (4 Threads)**. |
| **Permissions Denied on Android 13+** | Storage permissions not granted. | Go to Android Settings -> Apps -> EdgeRAG -> Permissions -> Allow Camera, Microphone, and Photos. |
