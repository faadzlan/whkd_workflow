#Requires -Version 5.1
<#
.SYNOPSIS
    Test script to verify sanitization didn't break functionality.
.DESCRIPTION
    Run this after sanitizing paths to ensure everything still works:
    - Path resolution with ~
    - projects.json loading
    - WSL path conversion
    - Virtual desktop switching
    - Window positioning
    
.EXAMPLE
    .\tools\test-sanitization.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$testsPassed = 0
$testsFailed = 0

function Test-Condition {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$SuccessMessage = "PASS",
        [string]$FailureMessage = "FAIL"
    )
    
    Write-Host "Testing: $Name... " -NoNewline
    try {
        $result = & $Test
        if ($result) {
            Write-Host $SuccessMessage -ForegroundColor Green
            $script:testsPassed++
            return $true
        } else {
            Write-Host $FailureMessage -ForegroundColor Red
            $script:testsFailed++
            return $false
        }
    } catch {
        Write-Host "$FailureMessage ($_ )" -ForegroundColor Red
        $script:testsFailed++
        return $false
    }
}

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

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sanitization Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

#==============================================================================
# TEST 1: Basic Path Resolution
#==============================================================================

Write-Host "--- Path Resolution Tests ---" -ForegroundColor Yellow

$testPath = "~\Documents\whkd_workflow"
$resolvedPath = Resolve-ProjectPath -Path $testPath

Test-Condition "~ expands to USERPROFILE" {
    $resolvedPath -eq "C:\Users\$env:USERNAME\Documents\whkd_workflow"
}

Test-Condition "Resolved path exists" {
    Test-Path $resolvedPath
}

Test-Condition "Windows paths without ~ pass through" {
    $result = Resolve-ProjectPath -Path "G:\My Drive"
    $result -eq "G:\My Drive"
}

Test-Condition "WSL paths pass through unchanged" {
    $result = Resolve-ProjectPath -Path "~/Documents/project"
    # ~/ should remain unchanged for WSL
    $result -eq "~/Documents/project"
}

#==============================================================================
# TEST 2: projects.json Loading
#==============================================================================

Write-Host ""
Write-Host "--- projects.json Tests ---" -ForegroundColor Yellow

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectsConfigPath = Join-Path $scriptDir "workflows\projects.json"

Test-Condition "projects.json exists" {
    Test-Path $projectsConfigPath
}

$json = $null
if (Test-Path $projectsConfigPath) {
    $json = Get-Content $projectsConfigPath -Raw | ConvertFrom-Json
    
    Test-Condition "projects.json is valid JSON" {
        $json -ne $null -and $json.projects -ne $null
    }
    
    Test-Condition "whkd project uses ~" {
        $json.projects.whkd.path -match '^~'
    }
    
    Test-Condition "ssm project uses ~ (WSL)" {
        $json.projects.ssm.path -match '^~'
    }
    
    # Test actual resolution
    $whkdResolved = Resolve-ProjectPath -Path $json.projects.whkd.path
    Test-Condition "whkd path resolves correctly" {
        Test-Path $whkdResolved
    }
} else {
    Write-Host "SKIPPED: Cannot test project loading (file not found)" -ForegroundColor Yellow
}

#==============================================================================
# TEST 3: WSL Path Conversion
#==============================================================================

Write-Host ""
Write-Host "--- WSL Path Conversion Tests ---" -ForegroundColor Yellow

function Convert-ToWslPath {
    param([string]$Path)
    $wslPath = $Path -replace '^~', $env:USERPROFILE
    $wslPath = $wslPath -replace '\\', '/'
    if ($wslPath -match '^([A-Za-z]):(/.*)?$') {
        $drive = $matches[1].ToLower()
        $rest = $matches[2]
        $wslPath = "/mnt/$drive$rest"
    }
    return $wslPath
}

Test-Condition "Windows path converts to WSL" {
    $result = Convert-ToWslPath "C:\Users\Test\Documents"
    $result -eq "/mnt/c/Users/Test/Documents"
}

Test-Condition "~ path converts to WSL" {
    $result = Convert-ToWslPath "~\Documents"
    $expected = "/mnt/c/Users/$env:USERNAME/Documents" -replace '\\', '/'
    $result -eq $expected
}

Test-Condition "G: drive converts to /mnt/g" {
    $result = Convert-ToWslPath "G:\My Drive\Research"
    $result -eq "/mnt/g/My Drive/Research"
}

Test-Condition "Spaces preserved in WSL path" {
    $result = Convert-ToWslPath "C:\My Documents\My Folder"
    $result -eq "/mnt/c/My Documents/My Folder"
}

#==============================================================================
# TEST 4: Virtual Desktop Module
#==============================================================================

Write-Host ""
Write-Host "--- Virtual Desktop Tests ---" -ForegroundColor Yellow

Test-Condition "VirtualDesktop module is installed" {
    Get-Module -ListAvailable -Name VirtualDesktop | Where-Object { $_.Name -eq "VirtualDesktop" }
}

Test-Condition "Can get desktop count" {
    try {
        $count = Get-DesktopCount
        $count -gt 0
    } catch {
        $false
    }
}

Test-Condition "Can get desktop list" {
    try {
        $desktops = Get-DesktopList
        $desktops.Count -gt 0
    } catch {
        $false
    }
}

#==============================================================================
# TEST 5: Workflow Scripts
#==============================================================================

Write-Host ""
Write-Host "--- Workflow Script Tests ---" -ForegroundColor Yellow

$workflowDir = Join-Path $scriptDir "workflows"

$requiredScripts = @(
    "Load-WorkflowProfile.ps1",
    "Start-WorkEnvironment.ps1",
    "Go-ToProject.ps1",
    "projects.json"
)

foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $workflowDir $script
    Test-Condition "$script exists" {
        Test-Path $scriptPath
    }
}

# Check for Resolve-ProjectPath function in key files
$loadProfilePath = Join-Path $workflowDir "Load-WorkflowProfile.ps1"
if (Test-Path $loadProfilePath) {
    $content = Get-Content $loadProfilePath -Raw
    Test-Condition "Load-WorkflowProfile has Resolve-ProjectPath" {
        $content -match "function Resolve-ProjectPath"
    }
}

$startWorkPath = Join-Path $workflowDir "Start-WorkEnvironment.ps1"
if (Test-Path $startWorkPath) {
    $content = Get-Content $startWorkPath -Raw
    Test-Condition "Start-WorkEnvironment has Resolve-ProjectPath" {
        $content -match "function Resolve-ProjectPath"
    }
}

#==============================================================================
# TEST 6: Live Function Test (Optional - may open windows)
#==============================================================================

Write-Host ""
Write-Host "--- Live Function Tests (Optional) ---" -ForegroundColor Yellow

# Auto-skip live tests when running in non-interactive mode
if ($Host.Name -eq "ServerRemoteHost" -or -not $Host.UI.RawUI) {
    $runLiveTests = "n"
    Write-Host "Non-interactive mode detected - skipping live tests" -ForegroundColor Yellow
} else {
    $runLiveTests = Read-Host "Run live tests? (opens windows/emacs) [y/N]"
}

if ($runLiveTests -eq "y" -or $runLiveTests -eq "Y") {
    
    # Test proj function if available
    if (Get-Command proj -ErrorAction SilentlyContinue) {
        Test-Condition "proj command available" { $true }
        
        Write-Host "Testing 'proj whkd'..." -ForegroundColor Gray
        proj whkd
        $current = Get-Location
        Test-Condition "proj changed directory" {
            $current.Path -eq (Resolve-ProjectPath "~\Documents\whkd_workflow")
        }
    } else {
        Write-Host "proj command not loaded - skipping" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "SKIPPED: Live tests skipped by user" -ForegroundColor Yellow
}

#==============================================================================
# SUMMARY
#==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
if ($testsFailed -gt 0) {
    Write-Host "Failed: $testsFailed" -ForegroundColor Red
} else {
    Write-Host "Failed: $testsFailed" -ForegroundColor Green
}

if ($testsFailed -eq 0) {
    Write-Host ""
    Write-Host "`u{2713} All tests passed! Sanitization successful." -ForegroundColor Green
    Write-Host "You can safely push to GitHub." -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "`u{2717} Some tests failed. Please review before pushing." -ForegroundColor Red
    exit 1
}
