#Requires -Version 5.1
<#
.SYNOPSIS
    Closes all open windows gracefully (your shutdown cleanup).
.DESCRIPTION
    Closes all application windows, optionally excluding specific apps.
    Similar to `killall` in bash but for Windows GUI apps.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string[]]$Exclude = @("explorer", "whkd"),  # Don't close these
    [switch]$Force  # Kill without asking
)

Write-Host "Closing all windows..." -ForegroundColor Yellow

# Get all processes with visible windows (MainWindowHandle != 0)
$processes = Get-Process | Where-Object { 
    $_.MainWindowHandle -ne 0 -and 
    $_.ProcessName -notin $Exclude -and
    $_.ProcessName -ne "powershell" -and
    $_.ProcessName -ne "WindowsTerminal"
}

Write-Host "Found $($processes.Count) windows to close" -ForegroundColor Gray

foreach ($proc in $processes) {
    $name = $proc.ProcessName
    $title = $proc.MainWindowTitle
    
    if ($title) {
        $display = "$name ($title)"
    } else {
        $display = $name
    }
    
    if ($PSCmdlet.ShouldProcess($display, "Close window")) {
        try {
            if ($Force) {
                Stop-Process -Id $proc.Id -Force
            } else {
                # Graceful close (sends WM_CLOSE like clicking X)
                $proc.CloseMainWindow() | Out-Null
            }
            Write-Host "✓ Closed: $display" -ForegroundColor Green
        } catch {
            Write-Host "✗ Failed to close: $display" -ForegroundColor Red
        }
    }
}

Write-Host "`nDone! Excluded: $($Exclude -join ', ')" -ForegroundColor Yellow
