# Start Celery Worker (No Docker)
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Starting EdgeRAG Celery Background Worker" -ForegroundColor Cyan
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

$celeryExe = if (Test-Path "$ApiDir\venv\Scripts\celery.exe") { "$ApiDir\venv\Scripts\celery.exe" } else { "celery" }

# Launch Celery worker using pool=solo on Windows
Write-Host "[*] Launching Celery worker (pool=solo for Windows compatibility)..." -ForegroundColor Green
& $celeryExe -A app.workers.celery_app.celery_app worker --loglevel=info --pool=solo
