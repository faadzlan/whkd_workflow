#Requires -Version 5.1
<#
.SYNOPSIS
    Loads all workflow functions into your PowerShell session.
.DESCRIPTION
    Source this file to make all workflow functions available.
    Like `source ~/.bashrc` in bash.

    Add this to your PowerShell profile to auto-load:
    . C:\Users\faadz\Documents\whkd_workflow\tools\workflows\Load-WorkflowProfile.ps1
#>

$workflowDir = $PSScriptRoot

Write-Host "Loading PowerShell Workflows..." -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

#------------------------------------------------------------------------------
# 1. NAVIGATION & PROJECTS
#------------------------------------------------------------------------------

# Load projects from JSON config
$projectsConfigPath = Join-Path $workflowDir "projects.json"
$script:ProjectsConfig = $null
$script:ProjectsMeta = $null

function Resolve-ProjectPath {
    param([string]$Path)
    # Resolve ~ to USERPROFILE for Windows paths only
    # WSL paths (~/...) are kept as-is for WSL to resolve
    # Windows paths use ~\, WSL paths use ~/
    if ($Path -match '^~\\') {
        # Windows path: ~\Documents\...
        $Path = $Path -replace '^~\\', "$env:USERPROFILE\"
    } elseif ($Path -match '^~/') {
        # WSL path: ~/Documents/... - keep as-is
        # Do not convert, let WSL resolve it
    } elseif ($Path -match '^~$') {
        # Just ~ by itself - treat as Windows
        $Path = $env:USERPROFILE
    }
    return $Path
}

function Load-ProjectsConfig {
    if ($script:ProjectsConfig -eq $null) {
        if (Test-Path $projectsConfigPath) {
            $json = Get-Content $projectsConfigPath -Raw | ConvertFrom-Json
            $script:ProjectsConfig = @{}
            $script:ProjectsMeta = @{}
            $json.projects.PSObject.Properties | ForEach-Object {
                # Resolve ~ to actual path at load time
                $script:ProjectsConfig[$_.Name] = Resolve-ProjectPath -Path $_.Value.path
                $script:ProjectsMeta[$_.Name] = @{
                    Type = $_.Value.type
                    Distro = $_.Value.distro
                }
            }
        } else {
            Write-Warning "Projects config not found at $projectsConfigPath"
            $script:ProjectsConfig = @{}
            $script:ProjectsMeta = @{}
        }
    }
    return $script:ProjectsConfig
}

# Test if a path is a WSL path (starts with / or ~)
function Test-IsWSLPath {
    param([string]$Path)
    return $Path -match '^(/|~)'
}

# Convert WSL path to Windows UNC path (for Explorer access)
function Convert-WSLPathToUNC {
    param(
        [string]$WSLPath,
        [string]$Distro = "Ubuntu"
    )
    # Remove trailing slash if present
    $WSLPath = $WSLPath.TrimEnd('/')
    # Expand ~ to /home/user if needed
    if ($WSLPath -match '^~') {
        $WSLPath = $WSLPath -replace '^~', '/home/adzlan'
    }
    # Convert /path to \path for UNC format
    $windowsPath = $WSLPath -replace '/', '\'
    return "\\wsl.localhost\$Distro$windowsPath"
}

# Quick project navigation
function proj {
    param(
        [string]$Name,
        [switch]$e,  # Explorer
        [switch]$t,  # Terminal
        [switch]$w,  # WSL
        [switch]$m   # Emacs
    )
    
    $projects = Load-ProjectsConfig
    
    if (-not $Name -or $Name -eq "list") {
        Write-Host "Available projects:" -ForegroundColor Yellow
        $projects.GetEnumerator() | Sort-Object Key | ForEach-Object {
            $type = if (Test-IsWSLPath $_.Value) { "[WSL]" } else { "" }
            Write-Host "  - $($_.Key) $type" -ForegroundColor Gray
        }
        return
    }
    
    $path = $projects[$Name.ToLower()]
    if (-not $path) {
        Write-Error "Unknown project: $Name"
        return
    }
    
    # Check if this is a WSL path
    $isWSL = Test-IsWSLPath $path
    $distro = $script:ProjectsMeta[$Name.ToLower()].Distro
    if (-not $distro) { $distro = "Ubuntu" }
    
    if ($e) {
        # Open in Explorer
        if ($isWSL) {
            $uncPath = Convert-WSLPathToUNC -WSLPath $path -Distro $distro
            Start-Process explorer $uncPath
        } else {
            Start-Process explorer $path
        }
    }
    elseif ($t) {
        # Open in Terminal
        if ($isWSL) {
            $uncPath = Convert-WSLPathToUNC -WSLPath $path -Distro $distro
            Start-Process wt -ArgumentList "-d `"$uncPath`""
        } else {
            Start-Process wt -ArgumentList "-d `"$path`""
        }
    }
    elseif ($w) {
        # Open in WSL
        if ($isWSL) {
            Start-Process wsl -ArgumentList "cd `"$path`" && bash"
        } else {
            $wslPath = $path -replace '^([A-Za-z]):', { '/mnt/' + $args[0].Groups[1].Value.ToLower() } -replace '\\', '/'
            Start-Process wsl -ArgumentList "cd `"$wslPath`" && bash"
        }
    }
    elseif ($m) {
        # Open in Emacs (WSL) - pass path directly, no shell needed
        if ($isWSL) {
            Start-Process wsl -ArgumentList "emacs `"$path`"" -WindowStyle Hidden
        } else {
            $wslPath = $path -replace '^([A-Za-z]):', { '/mnt/' + $args[0].Groups[1].Value.ToLower() } -replace '\\', '/'
            Start-Process wsl -ArgumentList "emacs `"$wslPath`"" -WindowStyle Hidden
        }
    }
    else {
        # Default: cd into directory
        if ($isWSL) {
            # For WSL paths, open WSL instead of trying Set-Location
            Start-Process wsl -ArgumentList "cd `"$path`" && bash"
        } else {
            Set-Location $path
            Get-ChildItemColor
        }
    }
}

# Quick directory shortcuts
function home { Set-Location $env:USERPROFILE }
function docs { Set-Location "$env:USERPROFILE\Documents" }
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

function bt { Start-Process "ms-settings:bluetooth" }
function vol { Start-Process "ms-settings:sound" }
function wifi { Start-Process "ms-settings:network" }
function disp { Start-Process "ms-settings:display" }
function startup-apps { Start-Process "ms-settings:startupapps" }
function power { Start-Process "ms-settings:powersleep" }

#------------------------------------------------------------------------------
# 3. SYSTEM HEALTH
#------------------------------------------------------------------------------

function syshealth { & "$workflowDir\Show-SystemHealth.ps1" }
function mem { Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | Format-Table Name, @{Name="Memory(MB)"; Expression={[math]::Round($_.WorkingSet/1MB)}} -AutoSize }
function cpu { Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | Format-Table Name, CPU -AutoSize }

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
function clean-dl { & "$workflowDir\Clear-Downloads.ps1" }

#------------------------------------------------------------------------------
# 5. WSL BRIDGE
#------------------------------------------------------------------------------

function wsl-path {
    param([string]$Path = (Get-Location).Path)
    $Path -replace '^([A-Za-z]):', { '/mnt/' + $args[0].Groups[1].Value.ToLower() } -replace '\\', '/'
}

function win-path {
    param([string]$WSLPath)
    if ($WSLPath -match '^/mnt/([a-z])(/.*)?$') {
        "$($matches[1].ToUpper()):$($matches[2] -replace '/', '\')"
    } else { $WSLPath -replace '/', '\' }
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

Write-Host "`nWorkflows:" -ForegroundColor Yellow
Write-Host "  work                       - Start daily work environment" -ForegroundColor Gray
Write-Host "  bye                        - Close all windows" -ForegroundColor Gray
Write-Host "  clean-dl                   - Archive old Downloads" -ForegroundColor Gray

Write-Host "`nWSL:" -ForegroundColor Yellow
Write-Host "  wsl-path [path]            - Show WSL path for current/specified dir" -ForegroundColor Gray
Write-Host "  cp-wsl, cp-win             - Copy path to clipboard (WSL or Windows format)" -ForegroundColor Gray
Write-Host "  wsl-here [cmd]             - Run command in WSL at current directory" -ForegroundColor Gray

Write-Host "`nUtilities:" -ForegroundColor Yellow
Write-Host "  touch <file>               - Create or update file timestamp" -ForegroundColor Gray
Write-Host "  which <cmd>                - Find command location" -ForegroundColor Gray
Write-Host "  findf <name> [path]        - Find files by name" -ForegroundColor Gray

Write-Host "`nAdd to your profile for auto-load:" -ForegroundColor Cyan
Write-Host "  notepad `$PROFILE" -ForegroundColor DarkGray
Write-Host "  # Add this line:" -ForegroundColor DarkGray
Write-Host "  . C:\Users\faadz\Documents\whkd_workflow\tools\workflows\Load-WorkflowProfile.ps1" -ForegroundColor DarkGray
