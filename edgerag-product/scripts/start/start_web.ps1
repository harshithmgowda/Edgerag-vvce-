# Start Next.js Headquarters Web Portal
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Starting EdgeRAG Headquarters Web Portal (Port 3000)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$WebDir = "$ProjectRoot\apps\hq-web"

Set-Location $WebDir

if (!(Test-Path "node_modules")) {
    Write-Host "[*] Installing Node.js dependencies..." -ForegroundColor Yellow
    npm.cmd install
}

Write-Host "[*] Launching Next.js server bound to 0.0.0.0:3000..." -ForegroundColor Green
Write-Host "    - Local PC Web:      http://localhost:3000" -ForegroundColor Cyan
Write-Host "    - Windows Hotspot:   http://192.168.137.1:3000" -ForegroundColor Cyan
Write-Host "    - Phone Hotspot:     http://192.168.43.1:3000" -ForegroundColor Cyan
npm.cmd run dev
