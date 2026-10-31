#Requires -Version 5.1
<#
.SYNOPSIS
    Quick navigation to deep project folders.
.DESCRIPTION
    Jump to frequently used project directories without typing long paths.
    Like `cd` with bookmarks.

.FAQ
  Q: Why not just use `cd`?
  A: This handles deep paths, opens File Explorer, AND can launch WSL in that directory.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectName,

    [Alias("e")][switch]$Explorer,     # Open in File Explorer
    [Alias("t")][switch]$Terminal,     # Open in Windows Terminal
    [Alias("w")][switch]$WSL,          # Open in WSL terminal
    [Alias("m")][switch]$Emacs,        # Open Emacs at project root
    [switch]$List          # Show all available projects
)

# Load projects from JSON config (single source of truth)
$scriptDir = $PSScriptRoot
$projectsConfigPath = Join-Path $scriptDir "projects.json"

# Shared helpers: Resolve-ProjectPath, Test-IsWSLPath, ConvertTo-WSLPath,
# ConvertTo-WindowsPath, Convert-WSLPathToUNC, Get-WSLHomeDir
. (Join-Path $scriptDir "Common.ps1")

$projects = @{}
$projectsMeta = @{}
if (Test-Path $projectsConfigPath) {
    $json = Get-Content $projectsConfigPath -Raw | ConvertFrom-Json
    $json.projects.PSObject.Properties | ForEach-Object {
        # Resolve ~ to actual path at load time
        $projects[$_.Name] = Resolve-ProjectPath -Path $_.Value.path
        $projectsMeta[$_.Name] = @{
            Type   = $_.Value.type
            Distro = $_.Value.distro
        }
    }
} else {
    Write-Warning "Projects config not found at $projectsConfigPath"
    # Fallback to empty hashtable - user will see "not found" for any project
}

# "list" as a bare project name is a documented alias for -List (proj list)
if ($ProjectName -eq "list") {
    $List = $true
    $ProjectName = $null
}

# Show all projects if -List or no project specified
if ($List -or (-not $ProjectName)) {
    Write-Host "Available Projects:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    
    $projects.GetEnumerator() | Sort-Object Key | Format-Table -Property @{
        Name = "Alias"
        Expression = { $_.Key }
        Width = 15
    }, @{
        Name = "Path"
        Expression = { $_.Value }
    }, @{
        Name = "Type"
        Expression = { if (Test-IsWSLPath $_.Value) { "[WSL]" } else { "" } }
    } -AutoSize
    
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host '  Go-ToProject whkd           # Change to whkd_workflow directory' -ForegroundColor DarkGray
    Write-Host '  Go-ToProject of -Explorer   # Open OpenFOAM folder in File Explorer' -ForegroundColor DarkGray
    Write-Host '  Go-ToProject drive -WSL     # Open Drive in WSL terminal' -ForegroundColor DarkGray
    Write-Host '  Go-ToProject projects -Emacs # Open Emacs at Projects root' -ForegroundColor DarkGray
    return
}

# Find the project
$path = $projects[$ProjectName.ToLower()]

if (-not $path) {
    Write-Error "Project '$ProjectName' not found. Use -List to see available projects."
    exit 1
}

$isWSL = Test-IsWSLPath $path
$distro = $projectsMeta[$ProjectName.ToLower()].Distro
if (-not $distro) { $distro = "Ubuntu" }

# Test-Path can't resolve a bare WSL-form path (e.g. /home/adzlan/...) from
# Windows - check via its UNC equivalent instead.
if ($isWSL) {
    if (-not (Test-Path (Convert-WSLPathToUNC -WSLPath $path -Distro $distro))) {
        Write-Error "Project path not found: $path"
        exit 1
    }
} elseif (-not (Test-Path $path)) {
    Write-Error "Project path not found: $path"
    exit 1
}

Write-Host "Project: $ProjectName" -ForegroundColor Green
Write-Host "Path: $path" -ForegroundColor Gray

#------------------------------------------------------------------------------
# ACTIONS
#------------------------------------------------------------------------------

if ($Explorer) {
    Write-Host "Opening in File Explorer..." -ForegroundColor Yellow
    if ($isWSL) {
        Start-Process explorer (Convert-WSLPathToUNC -WSLPath $path -Distro $distro)
    } else {
        Start-Process explorer -ArgumentList $path
    }
}
elseif ($Terminal) {
    Write-Host "Opening in Windows Terminal..." -ForegroundColor Yellow
    if ($isWSL) {
        Start-Process wt -ArgumentList "-d `"$(Convert-WSLPathToUNC -WSLPath $path -Distro $distro)`""
    } else {
        Start-Process wt -ArgumentList "-d `"$path`""
    }
}
elseif ($WSL) {
    Write-Host "Opening in WSL..." -ForegroundColor Yellow
    $wslPath = if ($isWSL) { $path } else { ConvertTo-WSLPath $path }
    Start-Process wsl -ArgumentList "cd `"$wslPath`" && bash"
}
elseif ($Emacs) {
    Write-Host "Opening Emacs (WSL)..." -ForegroundColor Yellow
    $wslPath = if ($isWSL) { $path } else { ConvertTo-WSLPath $path }
    Start-Process wsl -ArgumentList "emacs `"$wslPath`"" -WindowStyle Hidden
}
else {
    # Default: just change directory in current shell
    if ($isWSL) {
        Write-Host "Opening in WSL..." -ForegroundColor Yellow
        Start-Process wsl -ArgumentList "cd `"$path`" && bash"
    } else {
        Write-Host "Changing directory..." -ForegroundColor Yellow
        Set-Location -Path $path
        Get-ChildItemColor  # Show colorized directory contents (like `ls --color`)
    }
}

# Create convenient aliases
function global:proj { & $PSScriptRoot\Go-ToProject.ps1 @args }
function global:cdp { & $PSScriptRoot\Go-ToProject.ps1 @args }
