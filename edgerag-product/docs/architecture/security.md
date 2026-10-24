# EdgeRAG Security Architecture & Threat Model

## 1. Authentication & Authorization

EdgeRAG implements strict Role-Based Access Control (RBAC):

| Role | Permissions |
|---|---|
| **Administrator** | Register equipment, upload PDF manuals, trigger RAG rebuilds, configure cloud AI provider keys, review field incidents, revoke device credentials. |
| **Field Engineer** | Download authorized equipment knowledge packages, send device heartbeats, execute on-device and online RAG queries, submit field incidents. |

### JWT Specification
- Algorithm: HMAC-SHA256 (`HS256`).
- Secret: Configurable 64-character entropy key via `EDGERAG_SECRET_KEY`.
- Expiration: Default 24 hours (`1440` minutes).
- Payload: `{"sub": user_uuid, "role": "ADMIN" | "FIELD_ENGINEER", "exp": timestamp}`.

---

## 2. Secure Mobile Device Pairing & Revocation

1. Field devices register via `/api/v1/devices/register` with unique hardware UUID and OS profile.
2. Server issues a dedicated persistent device token.
3. Every hotspot synchronization request carries the device token.
4. If an administrator flags a device as `REVOKED` in the HQ Web Portal:
   - Next heartbeat or sync attempt immediately returns HTTP 403 Forbidden.
   - Flutter revokes local cached sync credentials and halts knowledge transfer.

---

## 3. Secret Management & BYOK (Bring Your Own Key)

### Server-Side Cloud Keys
- External provider keys (e.g. `GEMINI_API_KEY`) are stored in server environment variables or encrypted configuration tables.
- The web API `/api/v1/ai/providers` **never returns raw API keys**; it masks them (e.g., `AIza...9xQz`).

### Mobile On-Device BYOK
- Field engineers can input personal API keys on their mobile device for direct cloud queries.
- Stored using **Android Keystore-backed Secure Storage** (`flutter_secure_storage`).
- Keys are never logged to `adb logcat` or console output.
- Keys are wiped on user logout or device unpairing.

---

## 4. PDF Ingestion Security & Memory DoS Prevention

1. **File Type Verification**: Validates magic bytes (`%PDF-1.`) in addition to MIME type and extension.
2. **File Size Limit**: Hard ceiling at 50 Megabytes per manual upload.
3. **Decompression Bomb Guard**: PyMuPDF stream limits prevent memory exhaustion from nested object streams.
4. **Temporary Sandboxing**: Uploaded PDFs are parsed in isolated worker memory before persisting to MinIO.
