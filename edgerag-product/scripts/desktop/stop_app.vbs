Set WshShell = CreateObject("WScript.Shell")
ScriptPath = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
psScript = ScriptPath & "stop_app.ps1"
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """", 0, True
WshShell.Popup "All EdgeRAG services have been stopped.", 2, "EdgeRAG Stopped", 64
