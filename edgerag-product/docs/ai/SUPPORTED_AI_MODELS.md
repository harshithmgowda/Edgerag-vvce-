# 📋 EdgeRAG Supported AI Models Catalog

This document lists all **verified compatible models** in the EdgeRAG typed model registry, including on-device LLMs, vision-language backends, speech-to-text models, and cloud fallback providers.

---

## 🤖 Model Comparison Matrix

| Model Identifier | Display Name | Family | Format | Runtime / Engine | Input Modalities | Output Modalities | RAM Estimate | File Size | Verified Status |
|---|---|---|---|---|---|---|---|---|---|
| `gemma-4-e2b-it` | Google Gemma 4 E2B IT | Gemma 4 | LiteRT-LM (`.bin`/`.tflite`) | `flutter_edge_ai` (Vulkan/NPU) | Text, Image, Audio, JSON | Text | 1,800 MB | ~2.1 GB | **Preferred Primary Multimodal** |
| `qwen2.5-0.5b-instruct` | Qwen 2.5 0.5B Instruct | Qwen 2.5 | GGUF (`q4_k_m`) | `llama.cpp` / `fllama` | Text, Structured JSON | Text | 650 MB | 468.6 MB | **Verified Installed on Pixel 9a** |
| `phi-3-mini-4k` | Microsoft Phi-3 Mini 4K | Phi-3 | GGUF (`q4_k_m`) | `llama.cpp` / `fllama` | Text, Structured JSON | Text | 2,400 MB | 2.18 GB | **Verified Supported** |
| `whisper-base-asr` | OpenAI Whisper Base | Whisper | ONNX / LiteRT | Speech Engine | Audio (Microphone / WAV) | Text | 350 MB | 148 MB | **Verified Supported** |
| `android-system-tts` | Android Speech Synthesis | Native OS | Native IPC | Google TTS Engine | Text | Speech Audio | ~40 MB | System Built-in | **Verified Active on Android** |
| `minilm-l6-v2-dense` | sentence-transformers/all-MiniLM-L6-v2 | MiniLM | SQLite Matrix | Dot-product Cosine | Text (384-d vector) | Similarity Score | 120 MB | 80 MB (Embedded) | **Verified Active (knowledge.sqlite)** |
| `nvidia-nemotron-3-ultra` | NVIDIA Nemotron 3 Ultra 550B | Nemotron | Cloud REST API (NVIDIA NIM) | NVIDIA NIM Engine | Text, Complex Reasoning | Pristine Structured Markdown | Cloud Hosted | Cloud Service | **Verified Live (Recommended Online AI)** |
| `nvidia-nim-llama32-vision` | NVIDIA NIM Llama 3.2 11B Vision | Llama 3.2 | Cloud REST API | NVIDIA NIM API | Text, High-Res Image | Text | Cloud Hosted | Cloud Service | **Verified Live (Vision Fallback)** |
| `gemini-2.0-flash` | Google Gemini 2.0 Flash | Gemini | Cloud REST API | Google AI Studio | Text, Image, Audio | Text | Cloud Hosted | Cloud Service | **Verified Live (BYOK Fallback)** |

---

## 🔍 Model Profiles in Detail

### 0. NVIDIA Nemotron 3 Ultra 550B (`nvidia/nemotron-3-ultra-550b-a55b`)
- **Target Role**: Primary Online Cloud Reasoning & Diagnostic Engine (BYOK).
- **Architecture**: 550B parameter Ultra-scale reasoning model hosted on NVIDIA NIM high-performance GPU cluster.
- **Key Features**: Direct Executive Summary generation, step-by-step procedures, technical tables, and exact citation grounding with `[Source CHUNK_ID]`.
- **Streaming**: Native Server-Sent Events (SSE) token streaming with zero loading stall.
- **API Endpoint**: `https://integrate.api.nvidia.com/v1/chat/completions`

### 1. Google Gemma 4 E2B IT
- **Target Role**: Primary Multimodal On-Device Model.
- **Capabilities**: Directly understands natural text, technical equipment photographs, and audio recordings. Generates structured citations grounded in manual context.
- **Download Source**: [https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm)
- **Installation Path**: `/sdcard/Android/data/com.edgerag.mobile/files/models/gemma-4-e2b-it.bin`

### 2. Qwen 2.5 0.5B Instruct (GGUF)
- **Target Role**: Ultra-Lightweight Offline Text & Agent Reasoner.
- **Capabilities**: Excels at speed and low memory usage. Streams 18+ tokens/sec on mobile CPUs without overheating.
- **Current Status**: Pre-installed and verified on the connected Pixel 9a test device (`/sdcard/Android/data/com.edgerag.mobile/files/models/qwen2.5-0.5b-instruct-q4_k_m.gguf`).
- **Download Source**: [https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF)

### 3. Microsoft Phi-3 Mini 4K (GGUF)
- **Target Role**: High-Accuracy Offline Technical Reasoning.
- **Capabilities**: Formatted for complex industrial logic and multi-step diagnostic reasoning.
- **Download Source**: [https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf](https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf)

### 4. OpenAI Whisper Base / Moonshine ASR
- **Target Role**: Speech-to-Text Transcription for Audio Scribe.
- **Capabilities**: Real-time microphone audio chunk transcription. Converts spoken technical observations into text for vector search.

### 5. Android System TTS Engine
- **Target Role**: Hands-Free Voice Assistant Output.
- **Capabilities**: Zero additional memory footprint; synthesizes clear spoken English directly from generated answers.

### 6. sentence-transformers/all-MiniLM-L6-v2
- **Target Role**: Dense Vector Retrieval for Equipment Manuals.
- **Capabilities**: Produces 384-dimensional dense vectors used in `knowledge_{id}.db`. Retains 100% backward compatibility with HQ-generated packages.

### 7. NVIDIA NIM Llama 3.2 11B Vision Instruct
- **Target Role**: Cloud Multimodal Fallback.
- **Capabilities**: High-resolution image understanding with zero detail loss. Verified live on NVIDIA infrastructure with BYOK key management.

### 8. Google Gemini 2.0 Flash
- **Target Role**: Secondary Cloud Multimodal Fallback.
- **Capabilities**: High-speed multimodal API for image and voice processing when internet is active and permitted by the technician.
