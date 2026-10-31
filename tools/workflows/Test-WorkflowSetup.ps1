#Requires -Version 5.1
<#
.SYNOPSIS
    "workflow-doctor" - reports drift between this repo and live machine
    state, so it doesn't have to be rediscovered by hand.
.DESCRIPTION
    documentation/workflow-audit-2026-07.org (the "OPPORTUNITIES" section)
    found that most of its findings were only visible by inspecting
    running machine state: duplicate whkd processes, whkdrc diverging
    from the repo, missing PowerShell modules. This script checks those
    directly instead of requiring a manual audit each time.

    It deliberately reports FACTS with their provenance, not a bare
    inventory with a verdict attached. The same audit found two findings
    (FINDING 4 and FINDING 5) where a bare inventory - "second hotkey
    daemon running", "komorebi installed" - was read as a probable
    problem and was wrong both times; what resolved them was checking
    whose file it was and when it was written, not just that it existed.
    Anything this script can't attribute with confidence, it reports
    neutrally rather than flags.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "SilentlyContinue"
$workflowDir = $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $workflowDir)

function Write-Check {
    param([string]$Status, [string]$Message)
    $color = switch ($Status) {
        "OK"   { "Green" }
        "INFO" { "Gray" }
        "WARN" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$Status] " -ForegroundColor $color -NoNewline
    Write-Host $Message
}

Write-Host "workflow-doctor" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan

#------------------------------------------------------------------------------
# whkd process count
#------------------------------------------------------------------------------
# whkd is installed via scoop, which wraps every app in a shim executable
# (scoop\shims\whkd.exe) that launches and then waits on the real binary
# (scoop\apps\whkd\current\whkd.exe) - so ONE logical instance normally
# shows up as TWO whkd.exe processes in a simple `Get-Process -Name whkd`,
# related as parent/child. Counting raw processes without checking that
# relationship reproduces the exact mistake FINDINGS 4/5 in the workflow
# audit warned about (inventory mistaken for a problem without checking
# provenance) - confirmed 2026-07-29 by checking Win32_Process parentage;
# what first looked like a duplicate daemon was this shim pair, both times.
# A real duplicate would show more than one "root" instance (a whkd.exe
# whose parent is not itself a whkd.exe process).
$whkdCim = Get-CimInstance Win32_Process -Filter "Name = 'whkd.exe'" -ErrorAction SilentlyContinue
if (-not $whkdCim) {
    Write-Check "WARN" "whkd is not running."
} else {
    $whkdPids = @($whkdCim.ProcessId)
    $rootInstances = @($whkdCim | Where-Object { $_.ParentProcessId -notin $whkdPids })
    if (@($rootInstances).Count -gt 1) {
        Write-Check "WARN" "$(@($rootInstances).Count) independent whkd instances running (root PIDs: $($rootInstances.ProcessId -join ', ')). This is a real duplicate - FINDING 3 in the workflow audit: a bound key can fire its command twice, fine for idempotent bindings (desktop switches), not fine if bye/clean-dl are ever bound."
    } else {
        Write-Check "OK" "whkd running as a single instance ($(@($whkdCim).Count) process(es): shim + binary is normal for a scoop install)."
    }
}

#------------------------------------------------------------------------------
# whkdrc / start_whkd.vbs drift from the repo's versioned copies
#------------------------------------------------------------------------------
$whkdrcLive = "$env:USERPROFILE\.config\whkdrc"
$whkdrcRepo = Join-Path $repoRoot "config\whkdrc"
if ((Test-Path $whkdrcLive) -and (Test-Path $whkdrcRepo)) {
    $liveContent = Get-Content $whkdrcLive -Raw
    $repoContent = Get-Content $whkdrcRepo -Raw
    if ($liveContent -eq $repoContent) {
        Write-Check "OK" "Live whkdrc matches config/whkdrc."
    } else {
        Write-Check "WARN" "Live whkdrc ($whkdrcLive) differs from config/whkdrc. Run tools/Install-WhkdConfig.ps1 to sync, or update config/whkdrc if the live edit is the one you want to keep."
    }
} elseif (Test-Path $whkdrcLive) {
    Write-Check "INFO" "Live whkdrc exists at $whkdrcLive but config/whkdrc does not - nothing to compare against yet."
} else {
    Write-Check "WARN" "No whkdrc found at $whkdrcLive. whkd has nothing to read."
}

$vbsLive = "$env:USERPROFILE\.config\whkd\start_whkd.vbs"
$vbsRepo = Join-Path $repoRoot "config\start_whkd.vbs"
if ((Test-Path $vbsLive) -and (Test-Path $vbsRepo)) {
    if ((Get-Content $vbsLive -Raw) -eq (Get-Content $vbsRepo -Raw)) {
        Write-Check "OK" "Live start_whkd.vbs matches config/start_whkd.vbs."
    } else {
        Write-Check "WARN" "Live start_whkd.vbs differs from config/start_whkd.vbs. Run tools/Install-WhkdConfig.ps1 to sync."
    }
}

#------------------------------------------------------------------------------
# Required PowerShell modules
#------------------------------------------------------------------------------
$requiredModules = @("Get-ChildItemColor", "VirtualDesktop")
foreach ($mod in $requiredModules) {
    if (Get-Module -ListAvailable -Name $mod) {
        Write-Check "OK" "Module '$mod' is installed."
    } else {
        Write-Check "WARN" "Module '$mod' is not installed (Install-Module -Name $mod -Scope CurrentUser). proj/Go-ToProject.ps1's colorized listing or Start-WorkEnvironment.ps1's desktop switching will error without it."
    }
}

#------------------------------------------------------------------------------
# Scheduled Task that restarts whkd
#------------------------------------------------------------------------------
$task = Get-ScheduledTask -TaskName "Restart WHKD" -ErrorAction SilentlyContinue
if ($task) {
    Write-Check "INFO" "Scheduled Task 'Restart WHKD' exists (state: $($task.State)). FINDING 3 in the workflow audit found this is one of three-to-four separate mechanisms that can restart whkd - see documentation/workflow-audit-2026-07.org before adding another."
} else {
    Write-Check "INFO" "No Scheduled Task named 'Restart WHKD' found."
}

#------------------------------------------------------------------------------
# Other processes sharing hotkey territory - reported as fact, not a flag.
# FINDING 4/FINDING 5 lesson: an unexplained running process is not itself
# evidence of a problem; whose it is and why matters more than that it
# exists. This is informational only.
#------------------------------------------------------------------------------
$ahk = Get-Process -Name AutoHotkey* -ErrorAction SilentlyContinue
if ($ahk) {
    Write-Check "INFO" "AutoHotkey running (PID $($ahk[0].Id)) - a separate project (keyboardRemapping.ahk, text expansion/app automation). See 'Why whkd, and the Boundary with AutoHotkey' in AGENTS.md; no action implied."
}

Write-Host "`nDone." -ForegroundColor Cyan
