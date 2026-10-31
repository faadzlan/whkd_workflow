#Requires -Version 5.1
<#
.SYNOPSIS
    Loads the everyday workflow shortcuts into your PowerShell session.
.DESCRIPTION
    Dot-sourced from $PROFILE:
    . C:\Users\faadz\Projects\whkd_workflow\tools\workflows\Load-WorkflowProfile.ps1

    Slimmed on 2026-10-31 after a usage audit of PSReadLine history (see
    documentation/load-workflow-profile.org): only the four shortcuts still
    in regular use are defined here, and the banner is one line. The other
    scripts in this folder are still runnable by path and from whkd
    hotkeys; `wf` lists them.
#>

$workflowDir = $PSScriptRoot

# Open Explorer at the current or a specified directory
function exp {
    param([string]$Path = ".")
    try {
        $resolvedPath = (Resolve-Path $Path -ErrorAction Stop).Path
    } catch {
        Write-Error "Path not found: $Path"
        return
    }
    Start-Process explorer $resolvedPath
}

# Bluetooth settings page (URI lives in Open-QuickSettings.ps1's $settingsMap)
function bt { & "$workflowDir\Open-QuickSettings.ps1" -Setting Bluetooth }

# Top 10 processes by memory
function mem {
    Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 |
        Format-Table Name, @{Name = "Memory(MB)"; Expression = { [math]::Round($_.WorkingSet / 1MB) } } -AutoSize
}

# Close all windows
function bye { & "$workflowDir\Close-AllWindows.ps1" }

# Print what's available: the shortcuts above, plus the scripts and hotkeys
# that are no longer loaded into every shell.
function wf {
    Write-Host "Shortcuts" -ForegroundColor Yellow
    Write-Host "  bt          Bluetooth settings page" -ForegroundColor Gray
    Write-Host "  exp [path]  Open Explorer here or at path" -ForegroundColor Gray
    Write-Host "  mem         Top 10 processes by memory" -ForegroundColor Gray
    Write-Host "  bye         Close all windows" -ForegroundColor Gray
    Write-Host "`nScripts (run by path, in $workflowDir)" -ForegroundColor Yellow
    Write-Host "  Show-SystemHealth.ps1      System health dashboard" -ForegroundColor Gray
    Write-Host "  Start-WorkEnvironment.ps1  Daily work environment" -ForegroundColor Gray
    Write-Host "  Clear-Downloads.ps1        Archive old Downloads (-WhatIf to preview)" -ForegroundColor Gray
    Write-Host "  Go-ToProject.ps1 <name>    Jump to a projects.json project" -ForegroundColor Gray
    Write-Host "  Open-QuickSettings.ps1     Other Settings pages (-Setting Audio|Network|Display|Startup|Power)" -ForegroundColor Gray
    Write-Host "  Test-WorkflowSetup.ps1     Check for whkd/config drift" -ForegroundColor Gray
    Write-Host "`nwhkd hotkeys" -ForegroundColor Yellow
    Write-Host "  alt+1..0 switch desktop | alt+shift+1..0 move window | alt+o restart whkd" -ForegroundColor Gray
    Write-Host "  alt+shift+w work env | alt+shift+s system health | alt+shift+p project picker" -ForegroundColor Gray
}

Write-Host "bt, exp, mem, bye  (wf for more)" -ForegroundColor DarkGray
