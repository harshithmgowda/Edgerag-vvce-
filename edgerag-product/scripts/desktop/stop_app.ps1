# Stop all EdgeRAG processes cleanly
$ports = 3000, 8000
foreach ($port in $ports) {
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
        Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}

Get-Process python -ErrorAction SilentlyContinue | Where-Object {
    try { $_.CommandLine -match "uvicorn" -or $_.CommandLine -match "celery" } catch { $false }
} | Stop-Process -Force -ErrorAction SilentlyContinue
