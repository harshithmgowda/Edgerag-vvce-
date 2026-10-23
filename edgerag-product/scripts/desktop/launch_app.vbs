Set WshShell = CreateObject("WScript.Shell")
ScriptPath = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
psScript = ScriptPath & "launch_app.ps1"
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """", 0, False
