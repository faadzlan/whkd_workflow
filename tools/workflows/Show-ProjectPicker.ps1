#Requires -Version 5.1
<#
.SYNOPSIS
    Fuzzy-searchable project picker for hotkey use.
.DESCRIPTION
    Lists projects from projects.json in a filterable grid view and opens
    the selected one in Windows Terminal.

    Uses Out-GridView rather than a console prompt (Read-Host, menus)
    because it is meant to be bound to a whkd hotkey: whkd's
    ".shell powershell" commands run without an attached console window,
    so a console-based prompt would have nothing visible to type into.
    Out-GridView opens its own window regardless.
#>

[CmdletBinding()]
param()

$scriptDir = $PSScriptRoot

# Shared helper: Resolve-ProjectPath
. (Join-Path $scriptDir "Common.ps1")

$projectsConfigPath = Join-Path $scriptDir "projects.json"
if (-not (Test-Path $projectsConfigPath)) {
    Write-Warning "Projects config not found at $projectsConfigPath"
    exit 1
}

$json = Get-Content $projectsConfigPath -Raw | ConvertFrom-Json
$rows = $json.projects.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        Alias = $_.Name
        Path  = Resolve-ProjectPath -Path $_.Value.path
    }
} | Sort-Object Alias

$selected = $rows | Out-GridView -Title "Jump to project" -OutputMode Single
if (-not $selected) { exit 0 }

& (Join-Path $scriptDir "Go-ToProject.ps1") -ProjectName $selected.Alias -Terminal
