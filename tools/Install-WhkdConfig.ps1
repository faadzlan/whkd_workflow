#Requires -Version 5.1
<#
.SYNOPSIS
    Deploy this repo's versioned whkd config to the live machine locations.
.DESCRIPTION
    FINDING 2 of documentation/workflow-audit-2026-07.org: the live whkdrc
    and start_whkd.vbs existed only on the machine, unversioned - a single
    reinstall from gone. This copies the repo's config/ copies into place:

        config/whkdrc         -> ~/.config/whkdrc
        config/start_whkd.vbs -> ~/.config/whkd/start_whkd.vbs

    Existing files are backed up alongside themselves with a .bak-<date>
    suffix before being overwritten, never silently clobbered.

    This does NOT restart whkd or touch the Scheduled Task - re-run
    `alt + o` (or restart the daemon yourself) to pick up whkdrc changes,
    and see FINDING 3 in the audit before changing how whkd is restarted.
.PARAMETER WhatIf
    Preview what would be copied without changing anything.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

$repoRoot = Split-Path -Parent $PSScriptRoot
$configDir = Join-Path $repoRoot "config"

$targets = @(
    @{ Source = Join-Path $configDir "whkdrc"; Dest = "$env:USERPROFILE\.config\whkdrc" }
    @{ Source = Join-Path $configDir "start_whkd.vbs"; Dest = "$env:USERPROFILE\.config\whkd\start_whkd.vbs" }
)

foreach ($t in $targets) {
    if (-not (Test-Path $t.Source)) {
        Write-Warning "Source not found, skipping: $($t.Source)"
        continue
    }

    $destDir = Split-Path -Parent $t.Dest
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    if (Test-Path $t.Dest) {
        $existing = Get-Content $t.Dest -Raw -ErrorAction SilentlyContinue
        $incoming = Get-Content $t.Source -Raw
        if ($existing -eq $incoming) {
            Write-Host "Already up to date: $($t.Dest)" -ForegroundColor Gray
            continue
        }
        $backup = "$($t.Dest).bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if ($PSCmdlet.ShouldProcess($t.Dest, "Back up to $backup, then overwrite")) {
            Copy-Item $t.Dest $backup
            Write-Host "Backed up existing file to: $backup" -ForegroundColor Yellow
        }
    }

    if ($PSCmdlet.ShouldProcess($t.Dest, "Copy $($t.Source)")) {
        Copy-Item $t.Source $t.Dest -Force
        Write-Host "Deployed: $($t.Dest)" -ForegroundColor Green
    }
}

Write-Host "`nDone. whkd will not pick up whkdrc changes until it is restarted (alt + o)." -ForegroundColor Cyan
