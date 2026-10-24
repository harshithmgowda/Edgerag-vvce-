# Stop all EdgeRAG local services
Write-Host "Stopping EdgeRAG development processes..." -ForegroundColor Yellow

# Stop Uvicorn
Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "uvicorn" -or $_.CommandLine -match "celery" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Stop Node
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "All EdgeRAG development processes terminated." -ForegroundColor Green
