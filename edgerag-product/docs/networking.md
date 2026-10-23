# EdgeRAG Networking & Air-Gap Topology

## 1. Network Topologies in Industrial Environments

EdgeRAG explicitly models four mutually exclusive network states on the mobile device:

| State ID | Network Condition | HQ Server Reachable? | Public Internet Available? | Enabled Operations |
|---|---|---|---|---|
| **STATE-1** | `OFFLINE_AIRGAP` | ❌ No | ❌ No | On-device RAG, local incidents, viewing cached manuals |
| **STATE-2** | `HQ_LAN_HOTSPOT` | ✅ Yes | ❌ No (Air-gapped HQ) | Package sync, incident sync, device heartbeat |
| **STATE-3** | `PUBLIC_INTERNET_ONLY` | ❌ No | ✅ Yes | Online AI (Gemini BYOK), cloud incident backup |
| **STATE-4** | `FULLY_CONNECTED` | ✅ Yes | ✅ Yes | All operations active |

---

## 2. Windows Mobile Hotspot Architecture

When field engineers bring their Android devices to the maintenance depot or HQ facility:
1. The Windows PC hosting the EdgeRAG backend enables **Windows Mobile Hotspot** (`Settings -> Network & Internet -> Mobile Hotspot`).
2. Windows assigns the virtual Wi-Fi adapter the static IP address `192.168.137.1`.
3. The Android phone connects to the Wi-Fi SSID broadcast by the laptop.
4. Android receives a dynamic IP in the `192.168.137.0/24` subnet (e.g., `192.168.137.45`).
5. The FastAPI backend binds to `0.0.0.0:8000`, making it accessible to the phone at `http://192.168.137.1:8000/api/v1`.

### Critical Warning: Android Localhost vs Laptop Localhost
On an Android device, `localhost` and `127.0.0.1` refer **exclusively to the phone itself**. Entering `http://localhost:8000` on Flutter will fail with `ECONNREFUSED`. The app must use the laptop's LAN IP address (`http://192.168.137.1:8000` or corporate Wi-Fi IP `http://192.168.1.X:8000`).

---

## 3. LAN Active Discovery & Connection Handshake

When Flutter attempts to establish communication with Headquarters:
```
Mobile (Flutter)                                      Headquarters (FastAPI)
       |                                                         |
       |  1. TCP Ping / GET /api/v1/health                       |
       |-------------------------------------------------------->|
       |     (Timeout: 3.5s)                                     |
       |                                                         |
       |  2. HealthResponse (200 OK + "HEALTHY")                 |
       |<--------------------------------------------------------|
       |                                                         |
       |  3. Device Heartbeat & Token Verification               |
       |     POST /api/v1/devices/heartbeat                      |
       |-------------------------------------------------------->|
       |                                                         |
       |  4. HeartbeatResponse (200 OK + server_time)            |
       |<--------------------------------------------------------|
```

If the health check fails, the mobile application does not crash or spam network requests; it flags the HQ state as `UNREACHABLE` and falls back gracefully to `OFFLINE_AIRGAP`.

---

## 4. Connecting Mobile Browser & App to Headquarters Web Portal

EdgeRAG supports accessing the Headquarters Web Portal (`apps/hq-web`) directly from mobile devices over the local Hotspot without requiring an internet connection:

### Web Portal Access Architecture
1. **Binding to `0.0.0.0`**: Next.js development server is launched with `-H 0.0.0.0 -p 3000` so it accepts incoming connections from any device on the hotspot subnet.
2. **Dynamic API Host Resolution**: `ApiClient` (`apps/hq-web/lib/api-client.ts`) dynamically resolves `window.location.hostname`. When viewed on the mobile phone via `http://192.168.137.1:3000`, API requests automatically target `http://192.168.137.1:8000/api/v1` instead of failing against the phone's `localhost`.
3. **Dual Hotspot Configurations**:
   - **Mode A: Laptop as Hotspot (Windows Mobile Hotspot)**
     - Laptop Hotspot IP: `192.168.137.1`
     - Web Portal URL: `http://192.168.137.1:3000`
     - Mobile API URL: `http://192.168.137.1:8000/api/v1`
   - **Mode B: Phone as Hotspot (Android Wi-Fi Hotspot)**
     - Phone Hotspot Gateway: `192.168.43.1`
     - Web Portal URL: `http://192.168.43.1:3000`
     - Mobile API URL: `http://192.168.43.1:8000/api/v1`
4. **Mobile App Integration**:
   - **In-App Auto-Discovery**: The Flutter app's `NetworkService` probes active network interfaces and known hotspot subnets to automatically detect the gateway.
   - **Web Portal Reachability Checker**: The mobile app's Network Setup screen provides a one-tap reachability check against port 3000 and a "Copy Web Link" button to easily launch Chrome or Safari on the phone.

