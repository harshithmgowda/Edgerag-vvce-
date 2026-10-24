# 🌐 Track 1: Headquarters Web Portal (`apps/hq-web`)

**Assigned Team Member**: Member 1 (Frontend & Admin UI Lead)  
**Tech Stack**: Next.js 14 (App Router), React 18, TypeScript, Tailwind CSS, Recharts, Lucide Icons  
**Git Scope**: `feat(web): <description>` or `fix(web): <description>`  
**Dedicated Branch**: `track/web-portal` (or feature branches `feat/web/<feature-name>`)

---

## 🎯 Domain & Responsibilities

You own the **Headquarters Administration Portal** used by maintenance supervisors, plant directors, and engineers at headquarters to:
1. Manage equipment registry (`/equipment`).
2. Upload, parse, and verify technical PDF manuals (`/manuals`, `/manuals/upload`).
3. Monitor real-time Celery ingestion worker jobs (`/jobs`).
4. Generate, inspect, and publish offline SQLite knowledge packages (`/packages`).
5. Track paired field Android devices and heartbeat statuses (`/devices`).
6. Triage, review, and resolve field incident reports synced from mobile devices (`/incidents`).
7. Configure online AI providers (Google Gemini, OpenAI, Claude) and API keys (`/settings/ai`).
8. Monitor system health and Hotspot network settings (`/settings`).

---

## 📁 Folder Structure

```
apps/hq-web/
├── app/                      # Next.js 14 App Router
│   ├── (auth)/               # Login and authentication views
│   ├── devices/              # Device management & heartbeat monitoring
│   ├── equipment/            # Equipment registry & serial tracking
│   ├── incidents/            # Field incident triage board
│   ├── jobs/                 # Ingestion job progress & logs
│   ├── manuals/              # Manual inventory & PDF uploader
│   ├── packages/             # Knowledge package distribution & hashes
│   ├── settings/             # System health & AI provider keys
│   ├── layout.tsx            # Global sidebar, navigation & shell
│   └── page.tsx              # Analytics dashboard & overview metrics
├── components/               # Modular, reusable UI components
│   ├── DashboardStats.tsx    # Metric cards & Recharts graphs
│   ├── JobActions.tsx        # Ingestion retry & extraction reports
│   ├── Navbar.tsx            # Header status bar
│   └── Sidebar.tsx           # Navigation drawer
├── lib/                      # Core helpers & networking
│   ├── api-client.ts         # Type-safe API client (dynamic Hotspot support)
│   ├── types.ts              # TypeScript domain interfaces
│   └── utils.ts              # Formatters, date parsers, styling helpers
├── public/                   # Static icons, logos, illustrations
├── package.json              # Next.js dependencies & scripts
└── tailwind.config.js        # Design tokens & color system
```

---

## 🚀 Development Workflow

```bash
# 1. Navigate to your track folder
cd apps/hq-web

# 2. Install dependencies (first time)
npm install

# 3. Start development server (bound to 0.0.0.0 for LAN/Hotspot)
npm run dev

# 4. Open in browser
# Local PC:        http://localhost:3000
# Windows Hotspot: http://192.168.137.1:3000
# Phone Hotspot:   http://192.168.43.1:3000
```

---

## 💡 How to Add a New Screen & Feature

1. Create a new folder under `app/<feature-name>/page.tsx`.
2. Use `api` from `lib/api-client.ts` to call backend endpoints.
3. Add a sidebar link in `components/Sidebar.tsx`.
4. Validate TypeScript before committing:
   ```bash
   npx tsc --noEmit
   ```

---

## 📤 Git Commit & Contribution Guide

When making changes to Track 1, always use the `web` scope:

```bash
git checkout -b feat/web/incident-drawer
# Make your edits in apps/hq-web/
git add apps/hq-web/
git commit -m "feat(web): add real-time incident resolution drawer and severity filter"
git push origin feat/web/incident-drawer
```
*(Your commits will cleanly highlight your contributions on the team's GitHub commit graph without any file conflicts with other members!)*
