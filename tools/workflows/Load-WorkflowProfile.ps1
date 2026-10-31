#Requires -Version 5.1
<#
.SYNOPSIS
    Loads all workflow functions into your PowerShell session.
.DESCRIPTION
    Source this file to make all workflow functions available.
    Like `source ~/.bashrc` in bash.

    Add this to your PowerShell profile to auto-load:
    . C:\Users\faadz\Projects\whkd_workflow\tools\workflows\Load-WorkflowProfile.ps1
#>

$workflowDir = $PSScriptRoot

# Shared helpers: Resolve-ProjectPath, Test-IsWSLPath, ConvertTo-WSLPath,
# ConvertTo-WindowsPath, Convert-WSLPathToUNC, Get-WSLHomeDir
. (Join-Path $workflowDir "Common.ps1")

Write-Host "Loading PowerShell Workflows..." -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

#------------------------------------------------------------------------------
# 1. NAVIGATION & PROJECTS
#------------------------------------------------------------------------------

# Single implementation lives in Go-ToProject.ps1 (see FINDING 7 in
# documentation/workflow-audit-2026-07.org) - delegate rather than keep a
# second, divergent copy here. Parameters are declared (not just @args)
# so tab-completion below has a named ProjectName parameter to attach to;
# there is no logic here to drift, only forwarding.
function proj {
    param(
        [Parameter(Position = 0)]
        [string]$ProjectName,
        [Alias("e")][switch]$Explorer,
        [Alias("t")][switch]$Terminal,
        [Alias("w")][switch]$WSL,
        [Alias("m")][switch]$Emacs,
        [switch]$List
    )
    & "$workflowDir\Go-ToProject.ps1" @PSBoundParameters
}

# Tab-completion for project aliases, reading the same projects.json
# Go-ToProject.ps1 uses - so `proj <Tab>` never drifts from the real list.
$script:ProjNameCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $projectsConfigPath = Join-Path $workflowDir "projects.json"
    if (-not (Test-Path $projectsConfigPath)) { return }
    (Get-Content $projectsConfigPath -Raw | ConvertFrom-Json).projects.PSObject.Properties.Name |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
Register-ArgumentCompleter -CommandName proj -ParameterName ProjectName -ScriptBlock $script:ProjNameCompleter
Register-ArgumentCompleter -CommandName "Go-ToProject.ps1" -ParameterName ProjectName -ScriptBlock $script:ProjNameCompleter

# Quick directory shortcuts
function home { Set-Location $env:USERPROFILE }
function docs { Set-Location "$env:USERPROFILE\Projects" }
function dl { Set-Location "$env:USERPROFILE\Downloads" }

# Open Explorer at current or specified directory
function exp {
    param([string]$Path = ".")
    
    # Expand ~ to home directory
    if ($Path -eq "~") {
        $Path = $env:USERPROFILE
    }
    
    # Resolve the path (handles ., .., relative paths)
    try {
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop | Select-Object -ExpandProperty Path
    } catch {
        Write-Error "Path not found: $Path"
        return
    }
    
    # Open Explorer
    Start-Process explorer $resolvedPath
    Write-Host "Opened: $resolvedPath" -ForegroundColor Green
}

#------------------------------------------------------------------------------
# 2. SETTINGS SHORTCUTS
#------------------------------------------------------------------------------

# URIs live in one place - Open-QuickSettings.ps1's $settingsMap (FINDING 8)
function bt { & "$workflowDir\Open-QuickSettings.ps1" -Setting Bluetooth }
function vol { & "$workflowDir\Open-QuickSettings.ps1" -Setting Audio }
function wifi { & "$workflowDir\Open-QuickSettings.ps1" -Setting Network }
function disp { & "$workflowDir\Open-QuickSettings.ps1" -Setting Display }
function startup-apps { & "$workflowDir\Open-QuickSettings.ps1" -Setting Startup }
function power { & "$workflowDir\Open-QuickSettings.ps1" -Setting Power }

#------------------------------------------------------------------------------
# 3. SYSTEM HEALTH
#------------------------------------------------------------------------------

function syshealth { & "$workflowDir\Show-SystemHealth.ps1" }
function mem { Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | Format-Table Name, @{Name="Memory(MB)"; Expression={[math]::Round($_.WorkingSet/1MB)}} -AutoSize }
function cpu { Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | Format-Table Name, CPU -AutoSize }
function doctor { & "$workflowDir\Test-WorkflowSetup.ps1" }

#------------------------------------------------------------------------------
# 4. WORKFLOW COMMANDS
#------------------------------------------------------------------------------

function work { 
    param([string]$ProjectPath)
    if ($ProjectPath) {
        & "$workflowDir\Start-WorkEnvironment.ps1" -ProjectPath $ProjectPath
    } else {
        & "$workflowDir\Start-WorkEnvironment.ps1"
    }
}
function bye { & "$workflowDir\Close-AllWindows.ps1" }
function clean-dl { & "$workflowDir\Clear-Downloads.ps1" @args }

#------------------------------------------------------------------------------
# 5. WSL BRIDGE
#------------------------------------------------------------------------------
# Path conversion comes from Common.ps1 (ConvertTo-WSLPath / ConvertTo-WindowsPath)

function wsl-path {
    param([string]$Path = (Get-Location).Path)
    ConvertTo-WSLPath $Path
}

function win-path {
    param([string]$WSLPath)
    ConvertTo-WindowsPath $WSLPath
}

function cp-wsl {
    param([string]$Path = (Get-Location).Path)
    $wslPath = wsl-path $Path
    $wslPath | Set-Clipboard
    Write-Host "Copied WSL path: $wslPath" -ForegroundColor Green
}

function cp-win {
    param([string]$Path = (Get-Location).Path)
    $Path | Set-Clipboard
    Write-Host "Copied Windows path: $Path" -ForegroundColor Green
}

function wsl-here {
    param([string]$Command = "bash")
    $wslPath = wsl-path
    wsl sh -c "cd '$wslPath' && $Command"
}

# Show WSL distribution status
function wsl-status {
    Write-Host "WSL Distributions:" -ForegroundColor Cyan
    wsl -l -v

    Write-Host "`nWSL Configuration:" -ForegroundColor Cyan
    $wslConfig = "$env:USERPROFILE\.wslconfig"
    if (Test-Path $wslConfig) {
        Get-Content $wslConfig | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "  No .wslconfig found" -ForegroundColor DarkGray
    }

    Write-Host "`nWSL Integration:" -ForegroundColor Cyan
    Write-Host "  Windows PATH in WSL: $env:WSLENV" -ForegroundColor Gray
}

# Open current directory in Explorer (useful from inside a WSL-launched shell)
function wsl-explorer {
    Start-Process explorer (Get-Location).Path
}

#------------------------------------------------------------------------------
# 6. FILE UTILITIES
#------------------------------------------------------------------------------

# Touch (like Linux touch)
function touch {
    param([string]$Path)
    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path | Out-Null
    }
}

# Which (like Linux which)
function which {
    param([string]$Name)
    Get-Command $Name | Select-Object -ExpandProperty Source
}

# Quick file search (like find + grep)
function findf {
    param(
        [string]$Name,
        [string]$Path = "."
    )
    Get-ChildItem -Path $Path -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue
}

#------------------------------------------------------------------------------
# SUMMARY
#------------------------------------------------------------------------------

Write-Host "`nLoaded shortcuts:" -ForegroundColor Green

Write-Host "`nNavigation:" -ForegroundColor Yellow
Write-Host "  proj <name> [-e|-t|-w|-m]  - Jump to project (Explorer/Terminal/WSL/Emacs)" -ForegroundColor Gray
Write-Host "  home, docs, dl             - Quick directory shortcuts" -ForegroundColor Gray
Write-Host "  exp [path]                 - Open Explorer at current or specified path" -ForegroundColor Gray

Write-Host "`nSettings:" -ForegroundColor Yellow
Write-Host "  bt, vol, wifi, disp        - Bluetooth, Sound, Network, Display" -ForegroundColor Gray
Write-Host "  startup-apps, power        - Startup apps, Power settings" -ForegroundColor Gray

Write-Host "`nSystem:" -ForegroundColor Yellow
Write-Host "  syshealth                  - System health dashboard" -ForegroundColor Gray
Write-Host "  mem, cpu                   - Top memory/CPU consumers" -ForegroundColor Gray
Write-Host "  doctor                     - Check for drift: whkd processes, whkdrc, modules" -ForegroundColor Gray

Write-Host "`nWorkflows:" -ForegroundColor Yellow
Write-Host "  work                       - Start daily work environment" -ForegroundColor Gray
Write-Host "  bye                        - Close all windows" -ForegroundColor Gray
Write-Host "  clean-dl                   - Archive old Downloads" -ForegroundColor Gray

Write-Host "`nWSL:" -ForegroundColor Yellow
Write-Host "  wsl-path [path]            - Show WSL path for current/specified dir" -ForegroundColor Gray
Write-Host "  cp-wsl, cp-win             - Copy path to clipboard (WSL or Windows format)" -ForegroundColor Gray
Write-Host "  wsl-here [cmd]             - Run command in WSL at current directory" -ForegroundColor Gray
Write-Host "  wsl-status                 - Show WSL distro status" -ForegroundColor Gray
Write-Host "  wsl-explorer               - Open current directory in Explorer" -ForegroundColor Gray

Write-Host "`nUtilities:" -ForegroundColor Yellow
Write-Host "  touch <file>               - Create or update file timestamp" -ForegroundColor Gray
Write-Host "  which <cmd>                - Find command location" -ForegroundColor Gray
Write-Host "  findf <name> [path]        - Find files by name" -ForegroundColor Gray

Write-Host "`nAdd to your profile for auto-load:" -ForegroundColor Cyan
Write-Host "  notepad `$PROFILE" -ForegroundColor DarkGray
Write-Host "  # Add this line:" -ForegroundColor DarkGray
Write-Host "  . C:\Users\faadz\Projects\whkd_workflow\tools\workflows\Load-WorkflowProfile.ps1" -ForegroundColor DarkGray
