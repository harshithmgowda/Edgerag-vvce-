# Start FastAPI Backend Service (No Docker)
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Starting EdgeRAG FastAPI Backend (0.0.0.0:8000)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$ApiDir = "$ProjectRoot\services\api"

Set-Location $ApiDir

# Activate virtual environment if present
if (Test-Path "$ApiDir\venv\Scripts\Activate.ps1") {
    Write-Host "[*] Activating virtual environment in $ApiDir\venv..." -ForegroundColor Yellow
    . "$ApiDir\venv\Scripts\Activate.ps1"
}

$pythonExe = if (Test-Path "$ApiDir\venv\Scripts\python.exe") { "$ApiDir\venv\Scripts\python.exe" } else { "python" }

# Initialize Database tables if needed
& $pythonExe "$ProjectRoot\scripts\setup\init_db.py"

# Start Uvicorn bound to 0.0.0.0 for LAN/Hotspot accessibility
Write-Host "[*] Launching Uvicorn server on http://0.0.0.0:8000..." -ForegroundColor Green
& $pythonExe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
