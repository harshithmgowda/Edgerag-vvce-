# 🤖 OFFLINE AI & LOCAL MODEL INSTALLATION GUIDE

EdgeRAG is engineered to perform high-accuracy RAG question answering with **zero internet connection** and **zero headquarters server calls** when in Offline Mode.

---

## 📐 The On-Device AI Stack

EdgeRAG's on-device AI architecture provides both multimodal reasoning and dense vector retrieval:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          ON-DEVICE AI STACK (ANDROID)                           │
├───────────────────────────────┬───────────────────────────────┬─────────────────┤
│ 1. Vector Retrieval Engine    │ 2. Primary Multimodal LLM     │ 3. Fast Reasoner│
├───────────────────────────────┼───────────────────────────────┼─────────────────┤
│ Model: all-MiniLM-L6-v2       │ Model: Google Gemma 4 E2B IT  │ Model: Qwen 2.5 │
│ Dimension: 384 floats         │ Format: LiteRT-LM (.bin)      │ Format: GGUF    │
│ Function: Embeds query &      │ Function: Multimodal Text,    │ Function: Fast  │
│ performs SQLite dot-product   │ Image, Audio, & Agent Tools   │ text reasoning  │
│ RAM Footprint: ~120 MB        │ RAM Footprint: ~1.8 GB        │ RAM: ~650 MB    │
└───────────────────────────────┴───────────────────────────────┴─────────────────┘
```

---

## 📥 Verified On-Device Models

### 1. Preferred Primary Model: Google Gemma 4 E2B IT
- **Official Repository**: [HuggingFace: litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm)
- **File Size**: ~2.1 GB
- **Capabilities**: Multimodal text input, image inspection, audio transcription, and agent function calling.
- **Detailed Instructions**: See [INSTALL_GEMMA4_E2B.md](./INSTALL_GEMMA4_E2B.md).

### 2. Fast On-Device Reasoner: Qwen 2.5 0.5B Instruct
- **Installed Status**: Pre-installed and verified on the connected Pixel 9a test device!
- **Path**: `/sdcard/Android/data/com.edgerag.mobile/files/models/qwen2.5-0.5b-instruct-q4_k_m.gguf`
- **File Size**: 468.6 MB
- **Speed**: 18+ tokens/second with minimal battery drain.

### 3. High-Accuracy Reasoner: Microsoft Phi-3 Mini 4K
- **Repository**: [https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf](https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf)
- **File Size**: 2.39 GB (4-bit quantization).

---

## 📂 Installation on Android Phone

1. Connect your phone to your computer using a USB cable.
2. Open Windows File Explorer $\to$ Select your phone.
3. Navigate to the app documents directory:
   `Internal Storage/Android/data/com.edgerag.mobile/files/models/`
   *(Create the `models` folder if it does not already exist).*
4. Copy `Phi-3-mini-4k-instruct-q4.gguf` into this directory.
5. Launch the **EdgeRAG** mobile app $\to$ The Home Dashboard will switch the status badge to:
   `Local LLM: Ready`.

---

## ⚡ How the Phone Retrieves Without Cloud

1. You ask: *"What is the emergency shutdown procedure for the main drive motor?"*
2. The phone embeds the question into a 384-dimensional vector.
3. The phone performs a fast dot-product similarity query against the pre-compiled `knowledge_{id}.db` SQLite database.
4. The top 4 matching manual chunks are retrieved in less than 35 milliseconds.
5. The local `llama.cpp` runtime streams tokens onto the screen, attaching verified citations such as `[Page 42]`.
6. You have full manual diagnostic intelligence in the palm of your hand deep in an air-gapped facility!
