' Fixed 2026-07-29 (FINDING 3, documentation/workflow-audit-2026-07.org):
' the original ran taskkill and Start-Process as one fire-and-forget
' `powershell.exe -Command "taskkill ... && Start-Process ..."` string.
' `taskkill /f` returns as soon as the terminate request is queued, not
' once the process has actually exited, so the new whkd could start while
' the old one was still shutting down and both would survive. This
' version waits for taskkill's own process to return, then adds an
' explicit delay before starting the replacement - matching the delay
' used by the AHK project's restart-whkd.ps1 (500ms).
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "taskkill.exe /f /im whkd.exe", 0, True
WScript.Sleep 500
WshShell.Run "powershell.exe -WindowStyle Hidden -Command ""Start-Process whkd -WindowStyle Hidden""", 0, False
Set WshShell = Nothing
