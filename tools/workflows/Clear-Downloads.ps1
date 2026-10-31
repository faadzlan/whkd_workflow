#Requires -Version 5.1
<#
.SYNOPSIS
    Smart cleanup of Downloads folder to prevent File Explorer hangs.
.DESCRIPTION
    Moves files older than N days to dated archive folders.
    Like a cron job + logrotate, but for your Downloads.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [int]$DaysOld = 30,           # Move files older than this
    [switch]$AutoArchive = $false, # Skip confirmation
    [int]$RetentionDays = 0       # Also delete _Archive\<date>\ folders older than this (0 = disabled)
)

$Downloads = "$env:USERPROFILE\Downloads"
$ArchiveRoot = "$env:USERPROFILE\Downloads\_Archive"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Downloads Cleanup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if Downloads exists
if (-not (Test-Path $Downloads)) {
    Write-Error "Downloads folder not found: $Downloads"
    exit 1
}

# Get current stats
$allFiles = Get-ChildItem -Path $Downloads -File -Recurse -ErrorAction SilentlyContinue
$totalFiles = $allFiles.Count
$totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "`nCurrent Downloads folder:" -ForegroundColor Yellow
Write-Host "  Files: $totalFiles" -ForegroundColor Gray
Write-Host "  Size: $totalSizeMB MB" -ForegroundColor Gray

# Find old files
$cutoffDate = (Get-Date).AddDays(-$DaysOld)
$oldFiles = $allFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }

if (-not $oldFiles) {
    Write-Host "`n✓ No files older than $DaysOld days found. Nothing to archive." -ForegroundColor Green
} else {
    $oldSize = ($oldFiles | Measure-Object -Property Length -Sum).Sum
    $oldSizeMB = [math]::Round($oldSize / 1MB, 2)

    Write-Host "`nFiles to archive (older than $DaysOld days):" -ForegroundColor Yellow
    Write-Host "  Count: $($oldFiles.Count)" -ForegroundColor Gray
    Write-Host "  Size: $oldSizeMB MB" -ForegroundColor Gray

    # Show sample of files
    Write-Host "`nSample files to be moved:" -ForegroundColor Gray
    $oldFiles | Select-Object -First 10 | ForEach-Object {
        Write-Host "  - $($_.Name) ($([math]::Round($_.Length/1KB, 1)) KB)" -ForegroundColor DarkGray
    }
    if ($oldFiles.Count -gt 10) {
        Write-Host "  ... and $($oldFiles.Count - 10) more" -ForegroundColor DarkGray
    }

    # Create archive folder with date
    $archiveDate = Get-Date -Format "yyyy-MM-dd"
    $ArchivePath = "$ArchiveRoot\$archiveDate"

    if ($WhatIfPreference) {
        Write-Host "`n[WHATIF] Would move files to: $ArchivePath" -ForegroundColor Magenta
    } else {
        # Confirm unless -AutoArchive
        $proceed = $true
        if (-not $AutoArchive) {
            $confirm = Read-Host "`nMove these files to archive? (y/n)"
            if ($confirm -ne "y") {
                Write-Host "Cancelled." -ForegroundColor Yellow
                $proceed = $false
            }
        }

        if ($proceed) {
            # Create archive directory
            New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null

            # Move files, preserving folder structure
            $movedCount = 0
            $failedCount = 0

            foreach ($file in $oldFiles) {
                try {
                    # Calculate relative path to preserve subfolder structure
                    $relativePath = $file.FullName.Substring($Downloads.Length + 1)
                    $destPath = Join-Path $ArchivePath $relativePath

                    # Create subdirectories if needed
                    $destDir = Split-Path $destPath -Parent
                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }

                    if ($PSCmdlet.ShouldProcess($file.Name, "Move to archive")) {
                        Move-Item -Path $file.FullName -Destination $destPath -Force
                        $movedCount++
                    }
                } catch {
                    Write-Host "✗ Failed to move: $($file.Name)" -ForegroundColor Red
                    $failedCount++
                }
            }

            # Clean up empty directories in Downloads
            # Sort deepest-first so nested empty dirs are removed before their parents,
            # avoiding "Cannot find path" errors when a parent's -Recurse removal already
            # took its (also-empty) children with it.
            $emptyDirs = Get-ChildItem -Path $Downloads -Directory -Recurse | Where-Object {
                (Get-ChildItem -Path $_.FullName -Recurse -File).Count -eq 0
            } | Sort-Object { $_.FullName.Length } -Descending

            foreach ($dir in $emptyDirs) {
                if (Test-Path $dir.FullName) {
                    Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # Final report
            $remainingFiles = (Get-ChildItem -Path $Downloads -File -Recurse -ErrorAction SilentlyContinue).Count

            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "Archive Complete!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Moved: $movedCount files" -ForegroundColor Green
            if ($failedCount -gt 0) {
                Write-Host "Failed: $failedCount files" -ForegroundColor Red
            }
            Write-Host "Archive location: $ArchivePath" -ForegroundColor Gray
            Write-Host "Downloads folder now has $remainingFiles files" -ForegroundColor Gray
        }
    }
}

#------------------------------------------------------------------------------
# RETENTION PASS (FINDING 9, documentation/workflow-audit-2026-07.org)
# _Archive grows without bound otherwise - files only ever move one
# directory down, never leave. Opt-in via -RetentionDays so an
# unattended/scheduled run never starts deleting archived material
# without it being explicitly requested.
#------------------------------------------------------------------------------
if ($RetentionDays -gt 0 -and (Test-Path $ArchiveRoot)) {
    $retentionCutoff = (Get-Date).AddDays(-$RetentionDays)
    $archiveDirs = Get-ChildItem -Path $ArchiveRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
        $dirDate = [datetime]::MinValue
        [datetime]::TryParseExact($_.Name, "yyyy-MM-dd", $null, [System.Globalization.DateTimeStyles]::None, [ref]$dirDate) -and
            $dirDate -lt $retentionCutoff
    }

    if (-not $archiveDirs) {
        Write-Host "`nNo archived folders older than $RetentionDays days to prune." -ForegroundColor Gray
    } else {
        Write-Host "`nPruning archived folders older than $RetentionDays days:" -ForegroundColor Yellow
        foreach ($dir in $archiveDirs) {
            $dirSizeMB = [math]::Round(((Get-ChildItem $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) / 1MB, 2)
            if ($WhatIfPreference) {
                Write-Host "  [WHATIF] Would delete: $($dir.FullName) ($dirSizeMB MB)" -ForegroundColor Magenta
            } elseif ($PSCmdlet.ShouldProcess($dir.FullName, "Delete archived folder ($dirSizeMB MB)")) {
                Remove-Item -Path $dir.FullName -Recurse -Force
                Write-Host "  Deleted: $($dir.FullName) ($dirSizeMB MB)" -ForegroundColor Red
            }
        }
    }
}

# Schedule reminder
Write-Host "`nTip: Schedule this to run weekly:" -ForegroundColor Yellow
Write-Host "  schtasks /create /tn 'Weekly Downloads Cleanup' /tr 'powershell.exe -File `"$PSCommandPath`" -AutoArchive -RetentionDays 180' /sc weekly /d SUN /st 18:00" -ForegroundColor Cyan
