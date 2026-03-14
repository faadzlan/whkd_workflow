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
    
    [switch]$Explorer,     # Open in File Explorer
    [switch]$Terminal,     # Open in Windows Terminal
    [switch]$WSL,          # Open in WSL terminal
    [switch]$Emacs,        # Open Emacs at project root
    [switch]$List          # Show all available projects
)

# Load projects from JSON config (single source of truth)
$scriptDir = $PSScriptRoot
$projectsConfigPath = Join-Path $scriptDir "projects.json"

function Resolve-ProjectPath {
    param([string]$Path)
    # Resolve ~ to USERPROFILE for Windows paths only
    # WSL paths (~/...) are kept as-is for WSL to resolve
    if ($Path -match '^~\\') {
        $Path = $Path -replace '^~\\', "$env:USERPROFILE\"
    } elseif ($Path -match '^~$') {
        $Path = $env:USERPROFILE
    }
    return $Path
}

$projects = @{}
if (Test-Path $projectsConfigPath) {
    $json = Get-Content $projectsConfigPath -Raw | ConvertFrom-Json
    $json.projects.PSObject.Properties | ForEach-Object {
        # Resolve ~ to actual path at load time
        $projects[$_.Name] = Resolve-ProjectPath -Path $_.Value.path
    }
} else {
    Write-Warning "Projects config not found at $projectsConfigPath"
    # Fallback to empty hashtable - user will see "not found" for any project
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
    } -AutoSize
    
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host '  Go-ToProject whkd           # Change to whkd_setup directory' -ForegroundColor DarkGray
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

if (-not (Test-Path $path)) {
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
    Start-Process explorer -ArgumentList $path
}
elseif ($Terminal) {
    Write-Host "Opening in Windows Terminal..." -ForegroundColor Yellow
    Start-Process wt -ArgumentList "-d `"$path`""
}
elseif ($WSL) {
    Write-Host "Opening in WSL..." -ForegroundColor Yellow
    # Convert Windows path to WSL path
    $wslPath = $path -replace '^([A-Za-z]):', { '/mnt/' + $args[0].Groups[1].Value.ToLower() } -replace '\\', '/'
    Start-Process wsl -ArgumentList "cd `"$wslPath`" && bash"
}
elseif ($Emacs) {
    Write-Host "Opening Emacs (WSL)..." -ForegroundColor Yellow
    $wslPath = $path -replace '^([A-Za-z]):', { '/mnt/' + $args[0].Groups[1].Value.ToLower() } -replace '\\', '/'
    Start-Process wsl -ArgumentList "cd `"$wslPath`" && emacs ."
}
else {
    # Default: just change directory in current shell
    Write-Host "Changing directory..." -ForegroundColor Yellow
    Set-Location -Path $path
    Get-ChildItemColor  # Show colorized directory contents (like `ls --color`)
}

# Create convenient aliases
function global:proj { & $PSScriptRoot\Go-ToProject.ps1 @args }
function global:cdp { & $PSScriptRoot\Go-ToProject.ps1 @args }
