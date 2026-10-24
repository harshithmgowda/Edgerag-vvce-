# Launch all EdgeRAG development services in separate terminals
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Starting EdgeRAG Full-Stack Environment (No Docker)  " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Start FastAPI Backend in new window
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$ScriptDir\start_backend.ps1`""
Write-Host "[+] Dispatched FastAPI Backend (Port 8000)" -ForegroundColor Green

# 2. Start Celery Worker in new window
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$ScriptDir\start_worker.ps1`""
Write-Host "[+] Dispatched Celery Worker" -ForegroundColor Green

# 3. Start Next.js Frontend in new window
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$ScriptDir\start_web.ps1`""
Write-Host "[+] Dispatched Next.js Web App (Port 3000)" -ForegroundColor Green

Write-Host "`nAll EdgeRAG services started." -ForegroundColor Cyan
Write-Host "  • Local Web Portal:     http://localhost:3000" -ForegroundColor Yellow
Write-Host "  • Hotspot Web Portal:   http://192.168.137.1:3000 (Windows) / http://192.168.43.1:3000 (Phone)" -ForegroundColor Yellow
Write-Host "  • Hotspot API Backend:  http://192.168.137.1:8000/api/v1" -ForegroundColor Yellow
