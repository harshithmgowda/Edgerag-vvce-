# 🛠️ TROUBLESHOOTING & REPAIR MATRIX

This document provides immediate, exact solutions for common configuration and runtime errors across Web, Mobile, Backend, and Hotspot networking.

---

## 💻 1. Web Portal & Next.js Errors

### Issue: `npm: command not found` or `node: command not found`
- **Cause**: Node.js is not installed or its directory is missing from your Windows PATH environment variable.
- **Fix**: Download and run the Node.js LTS installer from [https://nodejs.org](https://nodejs.org). Restart VS Code after installation.

### Issue: `FetchError: Connection Refused (port 8000)`
- **Cause**: The FastAPI backend is not running.
- **Fix**: Open a PowerShell terminal, navigate to `services\api`, and run:
  ```powershell
  uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
  ```

---

## ⚙️ 2. Backend & Database Errors

### Issue: `Can't connect to MySQL server on '127.0.0.1:3306'`
- **Cause**: MySQL Community Server is not started or `DATABASE_URL` is pointing to an unconfigured instance.
- **Fix**: 
  - To use MySQL: Open Windows Services (`services.msc`), find `MySQL80`, and click **Start**.
  - To bypass MySQL with zero configuration: Open `.env` and set `DATABASE_URL=sqlite:///./edgerag_dev.db`. The backend will automatically create and use a local SQLite database!

### Issue: `Redis connection error / Connection refused on port 6379`
- **Cause**: Redis server is not running on localhost.
- **Fix**: 
  - EdgeRAG has a built-in synchronous fallback: If Redis is offline, PDF manual processing runs inside an in-process daemon thread automatically!
  - If you want Celery async execution: In WSL2, run `sudo service redis-server start`.

---

## 📶 3. Hotspot LAN & Android Connection Errors

### Issue: Phone reports `SocketException: Connection refused (OS Error: Connection refused, errno = 111)`
- **Cause**: The app is configured with `localhost:8000`. On Android, `localhost` means the phone itself, not your laptop!
- **Fix**: In the app's LAN setup screen, change the URL to:
  👉 `http://192.168.137.1:8000/api/v1`

### Issue: Phone reports `SocketException: Connection timed out`
- **Cause**: Windows Defender Firewall is blocking incoming traffic on port 8000 from the hotspot network adapter.
- **Fix**: Open PowerShell as Administrator and run:
  ```powershell
  New-NetFirewallRule -DisplayName "EdgeRAG Port 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
  ```

---

## 📄 4. PDF Ingestion & Celery Errors

### Issue: `File exceeds maximum allowable size of 50 Megabytes`
- **Cause**: Industrial safety manuals can occasionally be several hundred megabytes.
- **Fix**: In `services/api/app/api/v1/endpoints/manuals.py`, you can increase `50 * 1024 * 1024` if your hardware has sufficient RAM.

### Issue: `Security Checksum Failed! Expected hash does not match`
- **Cause**: A download was interrupted or corrupt bytes were transferred over Wi-Fi.
- **Fix**: The app automatically deletes the corrupted temporary `.zip` file. Tap **Retry Download** in the Hotspot Sync screen.

---

## 🤖 5. Google Gemini & AI Provider Errors

### Issue: `Gemini Error: API_KEY_INVALID`
- **Cause**: The entered key contains a typo, leading/trailing whitespace, or was revoked.
- **Fix**: Log into [https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey), copy the exact key string, paste into Settings, and tap **Test Connection**.

### Issue: `Quota exceeded for quota metric 'Queries' and limit 'QUOTA_PER_MINUTE'`
- **Cause**: Free tier Google Gemini allows up to 15 requests per minute.
- **Fix**: Wait 60 seconds before making the next request, or switch AI Mode to `OFFLINE ONLY` to use local on-device retrieval!
