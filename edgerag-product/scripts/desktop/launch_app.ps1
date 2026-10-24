# EdgeRAG Desktop App Launcher
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path "$ScriptDir\..\..").Path

# 1. Check & start Backend (Port 8000) in minimized window if not already active
$backendConn = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if (-not $backendConn) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$ProjectRoot\scripts\start\start_backend.ps1`"" -WorkingDirectory $ProjectRoot -WindowStyle Minimized
}

# 2. Check & start Celery Worker in minimized window if not already active
$workerRunning = Get-Process python -ErrorAction SilentlyContinue | Where-Object { 
    try { $_.CommandLine -match "celery" } catch { $false }
}
if (-not $workerRunning) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$ProjectRoot\scripts\start\start_worker.ps1`"" -WorkingDirectory $ProjectRoot -WindowStyle Minimized
}

# 3. Check & start Web App (Port 3000) in minimized window if not already active
$webConn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if (-not $webConn) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$ProjectRoot\scripts\start\start_web.ps1`"" -WorkingDirectory $ProjectRoot -WindowStyle Minimized
}

# 4. Wait for Web Portal to be accessible (up to 30 seconds)
$url = "http://localhost:3000"
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Milliseconds 500
    }
}

# 5. Launch in dedicated Desktop App Window Mode (Frameless, clean desktop app experience)
$edgePaths = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$chromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$browserLaunched = $false

foreach ($p in $edgePaths) {
    if (Test-Path $p) {
        Start-Process -FilePath $p -ArgumentList "--app=$url --window-size=1440,900"
        $browserLaunched = $true
        break
    }
}

if (-not $browserLaunched) {
    foreach ($p in $chromePaths) {
        if (Test-Path $p) {
            Start-Process -FilePath $p -ArgumentList "--app=$url --window-size=1440,900"
            $browserLaunched = $true
            break
        }
    }
}

if (-not $browserLaunched) {
    Start-Process $url
}
