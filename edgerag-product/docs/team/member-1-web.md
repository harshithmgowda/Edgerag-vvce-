# Member 1 Handoff: Headquarters Administration Website

## 1. Executive Summary & Implemented Screens

Member 1 has built the complete Apple-inspired **Headquarters Administration Website** inside `apps/hq-web` using Next.js 14, React 18, TypeScript, Tailwind CSS, and Recharts.

| Screen Name | Path | Purpose & Capabilities | Real Data Contract |
|---|---|---|---|
| **Login** | `/login` | Secure JWT authentication with admin bootstrap detection. | `POST /api/v1/auth/login` |
| **Dashboard** | `/` | Real-time counts (equipment, manuals, packages, devices, incidents), Recharts severity breakdown, and empty states. | Real aggregations from `/api/v1` |
| **Equipment** | `/equipment` | Equipment search, asset grid, model/serial metadata, modal creation form. | `GET`, `POST /api/v1/equipment` |
| **Manuals** | `/manuals` | Manuals inventory, equipment filter, revision tags, page counts, file size. | `GET /api/v1/manuals` |
| **Upload Manual** | `/manuals/upload` | Drag & drop PDF uploader with 50MB limit, revision input, upload progress bar. | `POST /api/v1/manuals` (Multipart) |
| **Processing Jobs** | `/jobs` | Real-time Celery worker monitoring with stages (EXTRACTING, CHUNKING, EMBEDDING, PACKAGING). | `GET /api/v1/jobs` |
| **Knowledge Packages** | `/packages` | Published package versions (`v1`), SHA-256 integrity hashes, chunk counts, download ZIP link. | `GET /api/v1/packages`, `GET /packages/{id}/download` |
| **Devices** | `/devices` | Paired Android field phones, OS version, last heartbeat, revocation button. | `GET /api/v1/devices`, `POST /devices/{id}/revoke` |
| **Incidents** | `/incidents` | Field incident triage board, status filtering (OPEN, IN_REVIEW, RESOLVED), review drawer. | `GET /api/v1/incidents`, `PATCH /incidents/{id}/review` |
| **AI Providers** | `/settings/ai` | Configure Google Gemini, OpenAI, Claude, Groq keys; live "Test Connection" button. | `GET`, `POST /api/v1/ai/providers`, `POST /test` |
| **Settings** | `/settings` | Hotspot LAN binding (192.168.137.1:8000), service health checks (MySQL, Redis, MinIO). | `GET /api/v1/health` |

---

## 2. Shared Contracts & Files Created

- Architecture Root: [`apps/hq-web`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/hq-web)
- Core API Client: [`apps/hq-web/lib/api-client.ts`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/hq-web/lib/api-client.ts)
- TypeScript Contracts: [`apps/hq-web/lib/types.ts`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/hq-web/lib/types.ts)
- Design Tokens & Global CSS: [`apps/hq-web/app/globals.css`](file:///c:/Users/Harshith/OneDrive/Desktop/edgerag/edgerag-product/apps/hq-web/app/globals.css)

---

## 3. How to Run & Build

```bash
cd edgerag-product/apps/hq-web
npm install
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

---

## 4. Exact Integration Instructions for Member 2 (Mobile)

1. **Package Verification**: The packages listed on `/packages` are distributed as ZIP archives containing `manifest.json` and `knowledge.sqlite`. Member 2 must verify the `sha256_hash` property received from `/api/v1/sync/check` before extracting.
2. **Hotspot IP Address**: The web dashboard binds to port 3000; the FastAPI backend binds to port 8000 on `0.0.0.0`. Member 2 should connect the Android phone to the laptop hotspot and configure the base URL as `http://192.168.137.1:8000/api/v1`.
3. **Incident Outbox Contract**: When an offline incident is created on mobile, use the schema defined in `contracts/incident.schema.json`. Once synchronized, the incident will appear immediately on the Headquarters `/incidents` screen.
