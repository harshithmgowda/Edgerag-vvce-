# ==============================================================================
# EdgeRAG Hackathon Git Initialization & Branch Setup Script
# Run this once in edgerag-product to bootstrap the repository for the team!
# ==============================================================================

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " EdgeRAG Hackathon Git Repository & Team Tracks Setup" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
Set-Location $ProjectRoot

# 1. Initialize Git if not already done
if (!(Test-Path ".git")) {
    Write-Host "[*] Initializing local Git repository..." -ForegroundColor Yellow
    git init -b main
} else {
    Write-Host "[*] Git repository already initialized." -ForegroundColor Green
}

# 2. Add files respecting .gitignore
Write-Host "[*] Staging files for initial team commit..." -ForegroundColor Yellow
git add .

# 3. Create initial commit if no commits exist
$commitCount = git rev-list --count HEAD 2>$null
if (-not $commitCount -or $commitCount -eq 0) {
    Write-Host "[*] Creating initial bootstrap commit on main..." -ForegroundColor Yellow
    git commit -m "feat(repo): bootstrap clean modular hackathon monorepo architecture with team tracks"
} else {
    Write-Host "[*] Repository already has commits. Creating clean commit if dirty..." -ForegroundColor Green
    git commit -m "chore(repo): organize folder structure, track READMEs and contribution guide" 2>$null
}

# 4. Create track branches for all 4 team members
$branches = @(
    @{ Name = "track/web-portal";  Desc = "Track 1: Member 1 (apps/hq-web)" },
    @{ Name = "track/mobile-app";  Desc = "Track 2: Member 2 (apps/mobile)" },
    @{ Name = "track/backend-api"; Desc = "Track 3: Member 3 (services/api)" },
    @{ Name = "track/ai-engine";   Desc = "Track 4: Member 4 (packages/rag-core)" }
)

Write-Host "`n[*] Configuring team track branches..." -ForegroundColor Cyan
foreach ($b in $branches) {
    git branch $b.Name 2>$null
    Write-Host "    [+] Created branch '$($b.Name)' -> $($b.Desc)" -ForegroundColor Green
}

git checkout main 2>$null

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " [SUCCESS] Repository Ready for Hackathon Team Collaboration!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "To link this repository to your team's GitHub repository, run:" -ForegroundColor Yellow
Write-Host "  git remote add origin https://github.com/<your-org-or-user>/edgerag.git" -ForegroundColor White
Write-Host "  git push -u origin main --all" -ForegroundColor White
Write-Host "`nEach member can checkout their track branch:" -ForegroundColor Yellow
Write-Host "  Member 1: git checkout track/web-portal" -ForegroundColor White
Write-Host "  Member 2: git checkout track/mobile-app" -ForegroundColor White
Write-Host "  Member 3: git checkout track/backend-api" -ForegroundColor White
Write-Host "  Member 4: git checkout track/ai-engine" -ForegroundColor White
Write-Host "=================================================================`n" -ForegroundColor Cyan
