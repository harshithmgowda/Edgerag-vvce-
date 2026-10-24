# 📶 HOTSPOT & LAN SYNCHRONIZATION GUIDE

This guide explains how to connect your Android phone to your Windows laptop's local Wi-Fi hotspot to synchronize equipment knowledge packages and offline incidents **without public internet**.

---

## 🌐 The Industrial Air-Gap Challenge

In remote substations or factory basements, there is no internet. 
However, technicians still need:
1. To download new equipment manuals onto their phones.
2. To upload recorded safety incidents back to headquarters.

We achieve this by turning your laptop into a **local headquarters hotspot**.

---

## 🛠️ Step 1: Turn On Windows Mobile Hotspot

1. On your Windows laptop, click the **Network Icon** in the bottom-right taskbar $\to$ Click the **Mobile Hotspot** toggle.
2. Or go to **Windows Settings $\to$ Network & internet $\to$ Mobile hotspot**.
3. Set **Share over**: `Wi-Fi`.
4. Click **Properties** to see:
   - **Network name (SSID)** (e.g. `EdgeRAG-HQ`)
   - **Network password**
5. By default in Windows, the hotspot gateway IP is statically assigned to:
   👉 `192.168.137.1`

---

## 🛡️ Step 2: Allow Port 8000 Through Windows Firewall

By default, Windows Defender Firewall blocks incoming connections from other devices on the hotspot network.

Run this one-line command in **PowerShell (Run as Administrator)**:
```powershell
New-NetFirewallRule -DisplayName "EdgeRAG FastAPI Port 8000" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```
This permits your Android phone to reach the FastAPI backend service.

---

## 📱 Step 3: Connect Your Android Phone

1. On your phone, go to **Settings $\to$ Wi-Fi**.
2. Select your laptop's hotspot network (e.g. `EdgeRAG-HQ`).
3. Enter the hotspot password.
4. Your phone will receive an IP address like `192.168.137.45`.
5. Note: Your phone may say *"Connected without internet"*. This is completely normal and expected! EdgeRAG does not need public internet.

---

## 🔄 Step 4: Synchronize Knowledge to Phone

1. Open the **EdgeRAG** mobile app.
2. Go to **Settings $\to$ HQ Connection Endpoint**:
   - Ensure the URL is set to: `http://192.168.137.1:8000/api/v1`
   - Tap **Test Connection**.
   - You should see: `Connected to Headquarters Backend`.
3. Return to the Home Dashboard $\to$ Tap **Hotspot Synchronization**.
4. Tap **Check Updates**:
   - The phone calls `POST /api/v1/sync/check`.
   - The server responds with available packages for your assigned equipment.
5. Tap **Install**:
   - The phone downloads the `.zip` bundle.
   - Computes the SHA-256 hash.
   - Unpacks `knowledge.sqlite`.
   - Atomically replaces the local database.
6. The app now displays: `Knowledge Active`.

---

## 📤 Step 5: Synchronize Offline Incidents Outbox

1. When working offline, tap **Record Field Incident** and submit any report.
2. The incident receives a permanent RFC-4122 V4 UUID and is saved into the local SQLite outbox.
3. When you reconnect to the laptop hotspot, tap **Hotspot Synchronization $\to$ Sync Outbox**.
4. The backend receives the batch, records it in the MySQL database, and confirms acceptance.
5. Open the Headquarters Web Portal at `http://localhost:3000/incidents` to review the ticket!
