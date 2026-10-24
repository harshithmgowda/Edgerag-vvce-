# 🔑 GEMINI & EXTERNAL API KEYS GUIDE

EdgeRAG features a dual-layer AI strategy:
1. **Offline Mode**: Uses local vector retrieval and on-device models (`llama.cpp`) with zero cloud data transfer.
2. **Online Mode**: When internet is available, engineers can leverage **Google Gemini** for complex diagnostic reasoning grounded in retrieved manual citations.

---

## 🆓 1. How to Get a Free Google Gemini API Key

1. Navigate to Google AI Studio:
   👉 **[https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)**
2. Sign in with your standard Google account.
3. Click **Create API Key**.
4. Select a project (or click Create project).
5. Copy your new API key (starts with `AIzaSy...`).

---

## 🔒 2. Security Architecture: Where Are Keys Stored?

### Tier 1: Headquarters Organization Key
- Configured by the system administrator at `http://localhost:3000/settings/ai`.
- Stored on the server inside the encrypted database vault or in `.env` as `GEMINI_API_KEY`.
- The web frontend masks the key (e.g. `AIza...9xQz`). Raw keys are never sent across the network.

### Tier 2: Field Engineer Mobile BYOK (Bring Your Own Key)
- Designed for field engineers operating away from headquarters who want to use their personal AI quotas over cellular internet.
- Entered directly on the phone in **Settings $\to$ External AI Providers (BYOK)**.
- Stored exclusively in the hardware-backed **Android Keystore** (`flutter_secure_storage`).
- Keys are never logged to console or Android logcat.

---

## 🤖 3. Model Recommendations

| Model Name | Latency | Reasoning | Recommended Usage |
|---|---|---|---|
| **`gemini-1.5-flash`** | ~800ms | High | **Default / Recommended**: Ideal for fast question answering and fault code resolution. |
| **`gemini-1.5-pro`** | ~2200ms | Maximum | Complex multi-page wiring schematics and comparative analysis. |
| **`gemini-2.0-flash`** | ~600ms | Next-Gen | Experimental next-generation speed and multimodal ingestion. |

---

## 🧪 4. Live Connection Verification

Both the Headquarters Web Portal and Mobile App include a live **Test Connection** button:
1. Enter your key.
2. Click **Test Connection**.
3. The system executes a minimal 1-token test prompt (`Ping test`).
4. If verified, the system displays a green badge with measured roundtrip latency in milliseconds.
5. If invalid, the exact Google API error message is displayed for troubleshooting.
