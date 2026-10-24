# Setup EdgeRAG Desktop Shortcut and App Launcher
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$IcoSource = "$ProjectRoot\apps\mobile\windows\runner\resources\app_icon.ico"
$IcoDest = "$ScriptDir\edgerag.ico"

# Copy Icon
if (Test-Path $IcoSource) {
    Copy-Item -Path $IcoSource -Destination $IcoDest -Force
}

$DesktopPath = [Environment]::GetFolderPath('Desktop')
$WshShell = New-Object -ComObject WScript.Shell

# 1. Main App Shortcut: "EdgeRAG HQ.lnk"
$ShortcutPath = Join-Path $DesktopPath "EdgeRAG HQ.lnk"
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "wscript.exe"
$Shortcut.Arguments = "`"$ScriptDir\launch_app.vbs`""
$Shortcut.WorkingDirectory = "$ProjectRoot"
$Shortcut.Description = "EdgeRAG Headquarters Command Center"
if (Test-Path $IcoDest) {
    $Shortcut.IconLocation = "$IcoDest,0"
}
$Shortcut.Save()
Write-Host "[+] Created Desktop Shortcut: $ShortcutPath" -ForegroundColor Green

# 2. Stop App Shortcut: "Stop EdgeRAG.lnk"
$StopShortcutPath = Join-Path $DesktopPath "Stop EdgeRAG.lnk"
$StopShortcut = $WshShell.CreateShortcut($StopShortcutPath)
$StopShortcut.TargetPath = "wscript.exe"
$StopShortcut.Arguments = "`"$ScriptDir\stop_app.vbs`""
$StopShortcut.WorkingDirectory = "$ProjectRoot"
$StopShortcut.Description = "Stop EdgeRAG Background Services"
if (Test-Path $IcoDest) {
    $StopShortcut.IconLocation = "$IcoDest,0"
}
$StopShortcut.Save()
Write-Host "[+] Created Stop Shortcut: $StopShortcutPath" -ForegroundColor Green

# 3. Create a fallback double-clickable .bat file on Desktop: "EdgeRAG Launcher.bat"
$BatContent = @"
@echo off
title EdgeRAG Launcher
cd /d "$ScriptDir"
wscript.exe "$ScriptDir\launch_app.vbs"
exit
"@
$BatPath = Join-Path $DesktopPath "EdgeRAG Launcher.bat"
Set-Content -Path $BatPath -Value $BatContent
Write-Host "[+] Created Batch Launcher: $BatPath" -ForegroundColor Green

Write-Host "`nAll desktop shortcuts installed successfully!" -ForegroundColor Cyan
