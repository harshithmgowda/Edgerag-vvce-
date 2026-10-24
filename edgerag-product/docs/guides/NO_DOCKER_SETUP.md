# 🚫 NO DOCKER SETUP: Complete Windows & WSL2 Guide

This document explains how EdgeRAG runs its full production stack—**FastAPI, MySQL, Redis, Celery, and MinIO**—natively on Windows without ever requiring Docker or Docker Desktop.

---

## 🏛️ Native Architecture Mapping

```
+---------------------------------------------------------------------------------------+
| WINDOWS 11 HOST                                                                       |
|                                                                                       |
|   1. Next.js Headquarters Web Portal (Port 3000)                                      |
|      - Run with: npm run dev                                                          |
|                                                                                       |
|   2. FastAPI Backend Service (Port 8000, 0.0.0.0)                                     |
|      - Run with: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload             |
|                                                                                       |
|   3. MySQL Community Server (Port 3306)                                               |
|      - Installed as a standard Windows Service ("MySQL80")                            |
|      - Or instant SQLite fallback (edgerag_dev.db)                                    |
|                                                                                       |
|   4. MinIO Object Storage (Port 9000)                                                 |
|      - Run native minio.exe OR automatic local filesystem fallback (./storage/)       |
|                                                                                       |
+-------------------------------------------+-------------------------------------------+
                                            |
                              (Mirrored Localhost Networking)
                                            |
+-------------------------------------------v-------------------------------------------+
| WSL2 LINUX (UBUNTU)                                                                   |
|                                                                                       |
|   5. Redis In-Memory Broker (Port 6379)                                               |
|      - Run with: sudo service redis-server start                                      |
|                                                                                       |
|   6. Celery Asynchronous Task Worker                                                  |
|      - Run with: celery -A app.workers.celery_app.celery_app worker --loglevel=info   |
|      - Or run on Windows with: --pool=solo                                            |
+---------------------------------------------------------------------------------------+
```

---

## 🚀 Setting Up the Components

### 1. MySQL (Native Windows)
1. Download **MySQL Community Server (Windows MSI)**:
   [https://dev.mysql.com/downloads/installer/](https://dev.mysql.com/downloads/installer/)
2. Install with Server Port `3306`.
3. Set your root password (e.g., `edgerag_password`).
4. In MySQL Workbench or CLI, run:
   ```sql
   CREATE DATABASE edgerag_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
5. Update your `.env` file:
   ```env
   DATABASE_URL=mysql+pymysql://root:edgerag_password@127.0.0.1:3306/edgerag_db
   ```

*(If you don't want to install MySQL right now, simply leave `DATABASE_URL=sqlite:///./edgerag_dev.db` in `.env`. It works automatically!)*

---

### 2. Redis on Windows / WSL2
Redis runs best on Linux. With Windows Subsystem for Linux (WSL2), it takes 30 seconds:
1. Open PowerShell and install Ubuntu:
   ```powershell
   wsl --install -d Ubuntu
   ```
2. Open Ubuntu terminal and install Redis:
   ```bash
   sudo apt update
   sudo apt install -y redis-server
   sudo service redis-server start
   ```
3. Test Redis:
   ```bash
   redis-cli ping
   ```
   *Output*: `PONG`
4. Because WSL2 shares localhost networking with Windows, your Windows FastAPI app can connect directly to `redis://127.0.0.1:6379/0`!

---

### 3. MinIO on Windows (Native Executable)
1. Download `minio.exe` for Windows:
   [https://dl.min.io/server/minio/release/windows-amd64/minio.exe](https://dl.min.io/server/minio/release/windows-amd64/minio.exe)
2. Place `minio.exe` in `C:\minio\`
3. Start MinIO in PowerShell:
   ```powershell
   C:\minio\minio.exe server C:\minio\data --address :9000 --console-address :9001
   ```
4. Access MinIO web console at `http://localhost:9001` (Credentials: `minioadmin` / `minioadmin`).

*(If MinIO is not running, EdgeRAG's built-in `StorageService` automatically saves files locally into `./storage/manuals` and `./storage/packages` without any errors!)*

---

### 4. Celery Worker (Native Windows)
On Windows, Celery cannot use the default fork pool. Use the solo execution pool:
```powershell
cd services\api
celery -A app.workers.celery_app.celery_app worker --loglevel=info --pool=solo
```
The worker will listen for PDF extraction and chunking tasks dispatched from FastAPI.
