#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Updates the "Restart WHKD" scheduled task to run without the PowerShell flash window.
.DESCRIPTION
    Modifies the existing scheduled task to use a VBS wrapper that completely hides the window.
#>

$taskName = "Restart WHKD"
$vbsPath = "$env:USERPROFILE\.config\whkd\start_whkd.vbs"

# Ensure the VBS launcher exists
if (-not (Test-Path $vbsPath)) {
    Write-Error "VBS launcher not found at: $vbsPath"
    Write-Host "Run the setup command first to create the VBS file." -ForegroundColor Yellow
    exit 1
}

# Unregister the old task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Removed old task: $taskName" -ForegroundColor Yellow

# Create the new action using wscript to hide the window completely
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""

# Trigger: At log on
$trigger = New-ScheduledTaskTrigger -AtLogOn

# Principal: Current user with highest privileges
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

# Settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden

# Register the task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "`n✓ Updated task: $taskName" -ForegroundColor Green
Write-Host "  - Program: wscript.exe" -ForegroundColor Cyan
Write-Host "  - Arguments: `"$vbsPath`"" -ForegroundColor Cyan
Write-Host "  - Trigger: At log on" -ForegroundColor Cyan
Write-Host "`nThe blue PowerShell flash should now be eliminated on next restart." -ForegroundColor Green
