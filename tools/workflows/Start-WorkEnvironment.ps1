#Requires -Version 5.1
<#
.SYNOPSIS
    Starts your daily work environment with apps and window layouts.
.DESCRIPTION
    Opens and positions windows exactly as you described:
    - Desktop 2: Terminal (right 1/2), two File Explorers stacked (left)
    - Desktop 3: Emacs (WSL) at project root
    
    Uses VirtualDesktop module to automatically switch virtual desktops.
    
    FOR BASH USERS:
    - This uses Windows APIs to move windows (no direct bash equivalent)
    - Think of it as a sophisticated i3wm or tmux layout script

.PARAMETER ProjectPath
    The project directory to open. Defaults to value from projects.json.
    CHANGE THIS DAILY: Just pass your today's working directory:
        Start-WorkEnvironment -ProjectPath "G:\My Drive\Projects\Today"
    Or use the alias:
        work "G:\My Drive\Projects\Today"

.EXAMPLE
    # Default project path (from projects.json)
    Start-WorkEnvironment
    
    # Today's specific project
    Start-WorkEnvironment -ProjectPath "G:\My Drive\Projects\OpenFOAM\Case1"
    
    # Skip some apps
    Start-WorkEnvironment -SkipEmacs
#>

[CmdletBinding()]
param(
    [string]$ProjectPath,  # If not specified, uses default from projects.json
    [switch]$SkipTerminal,
    [switch]$SkipExplorer,
    [switch]$SkipEmacs
)

#==============================================================================
# PART 0: LOAD PROJECT CONFIG (DRY Principle)
#==============================================================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
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

function Get-DefaultProjectPath {
    if (Test-Path $projectsConfigPath) {
        $json = Get-Content $projectsConfigPath -Raw | ConvertFrom-Json
        # Use "projects" as the default project, fallback to first available
        $rawPath = $null
        if ($json.projects.projects) {
            $rawPath = $json.projects.projects.path
        } elseif ($json.projects.PSObject.Properties.Count -gt 0) {
            $firstKey = $json.projects.PSObject.Properties.Name | Select-Object -First 1
            $rawPath = $json.projects.$firstKey.path
        }
        if ($rawPath) {
            return Resolve-ProjectPath -Path $rawPath
        }
    }
    # Ultimate fallback
    return "$env:USERPROFILE\Documents"
}

# Set default if not provided
if (-not $ProjectPath) {
    $ProjectPath = Get-DefaultProjectPath
}

#==============================================================================
# PART 1: VIRTUAL DESKTOP FUNCTIONS
# Uses the VirtualDesktop module you already have installed!
#==============================================================================

function Switch-ToDesktop {
    param([int]$DesktopNumber)
    
    # VirtualDesktop module uses 0-based indexing (Desktop 1 = index 0)
    $targetIndex = $DesktopNumber - 1
    
    try {
        # Get total desktop count
        $desktopCount = Get-DesktopCount
        if ($desktopCount -gt $targetIndex) {
            # Get the specific desktop by index and switch to it
            $targetDesktop = Get-Desktop -Index $targetIndex
            $targetDesktop | Switch-Desktop
            Write-Host "Switched to Desktop $DesktopNumber" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Desktop $DesktopNumber not found. You have $desktopCount desktops." -ForegroundColor Red
            Write-Host "Please create Desktop $DesktopNumber manually first." -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "Could not switch desktops automatically. Please use whkd hotkeys." -ForegroundColor Yellow
        return $false
    }
}

function Get-CurrentDesktopNumber {
    try {
        # Get-CurrentDesktop returns the current desktop object directly
        $currentDesktop = Get-CurrentDesktop
        # Get all desktops to find the index of the current one
        $desktopList = Get-DesktopList
        for ($i = 0; $i -lt $desktopList.Count; $i++) {
            if ($desktopList[$i].Visible) {
                return $i + 1  # Convert to 1-based
            }
        }
        return 1
    } catch {
        return 1
    }
}

#==============================================================================
# PART 2: SCREEN LAYOUT CALCULATIONS
#==============================================================================

function Get-ScreenDimensions {
    # Get primary screen size
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    return @{
        Width = $screen.Width
        Height = $screen.Height
        Left = $screen.Left
        Top = $screen.Top
    }
}

function Calculate-Layout {
    param($Screen)
    
    # Desktop 2 layout: Terminal right 1/2, two Explorers stacked on left
    return @{
        Terminal = @{
            X = $screen.Left + ($screen.Width / 2)
            Y = $screen.Top
            Width = $screen.Width / 2
            Height = $screen.Height
        }
        ExplorerTop = @{
            X = $screen.Left
            Y = $screen.Top
            Width = $screen.Width / 2
            Height = $screen.Height / 2
        }
        ExplorerBottom = @{
            X = $screen.Left
            Y = $screen.Top + ($screen.Height / 2)
            Width = $screen.Width / 2
            Height = $screen.Height / 2
        }
    }
}

#==============================================================================
# PART 3: WINDOW MANAGEMENT
# Uses .NET to position windows (similar to xdotool on Linux)
#==============================================================================

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
}
"@

# Track existing windows before opening new ones
$script:WindowHandlesBefore = @()

function Get-WindowHandles {
    param([string]$ProcessName)
    Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | 
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -ExpandProperty MainWindowHandle
}

function Register-ExistingWindows {
    $script:WindowHandlesBefore = @{
        explorer = Get-WindowHandles -ProcessName "explorer"
        WindowsTerminal = Get-WindowHandles -ProcessName "WindowsTerminal"
    }
}

function Set-WindowPosition {
    param(
        [Parameter(Mandatory=$false)]$Process,
        [string]$ProcessName,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [switch]$NoRegister  # Don't re-register after positioning (for last window)
    )
    
    # Wait for window to be ready
    Start-Sleep -Milliseconds 1200
    
    $hwnd = [IntPtr]::Zero
    
    # Try to get window handle using before/after comparison
    if ($ProcessName -and $script:WindowHandlesBefore[$ProcessName]) {
        $beforeHandles = $script:WindowHandlesBefore[$ProcessName]
        $after = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | 
            Where-Object { $_.MainWindowHandle -ne 0 -and ($beforeHandles -notcontains $_.MainWindowHandle) }
        
        if ($after) {
            $hwnd = $after[-1].MainWindowHandle  # Use the last (most recent) new window
        }
    }
    
    # Fallback to Process.MainWindowHandle if comparison didn't work
    if ($hwnd -eq [IntPtr]::Zero -and $Process) {
        # Retry a few times as window handle might not be ready immediately
        for ($i = 0; $i -lt 5 -and $hwnd -eq [IntPtr]::Zero; $i++) {
            Start-Sleep -Milliseconds 500
            $Process.Refresh()
            $hwnd = $Process.MainWindowHandle
        }
    }
    
    if ($hwnd -ne [IntPtr]::Zero) {
        # SW_RESTORE = 9
        [WinAPI]::ShowWindow($hwnd, 9) | Out-Null
        Start-Sleep -Milliseconds 200
        [WinAPI]::MoveWindow($hwnd, $X, $Y, $Width, $Height, $true) | Out-Null
    } else {
        Write-Warning "Could not find window handle for positioning"
    }
    
    # Re-register windows so next call knows about this one
    if (-not $NoRegister -and $ProcessName) {
        Start-Sleep -Milliseconds 500
        $script:WindowHandlesBefore[$ProcessName] = Get-WindowHandles -ProcessName $ProcessName
    }
}

#==============================================================================
# PART 4: EMACS LAUNCHER (Background/Detached)
# This "lets go" of the terminal - Emacs runs independently
#==============================================================================

function Start-EmacsWSL {
    param(
        [string]$ProjectPath
    )
    
    # Convert Windows path to WSL path
    # G:\folder\file -> /mnt/g/folder/file (lowercase drive letter for WSL)
    # Step 1: Replace backslashes with forward slashes
    $wslPath = $ProjectPath -replace '\\', '/'
    # Step 2: Replace drive letter (e.g., G:) with /mnt/g (lowercase)
    if ($wslPath -match '^([A-Za-z]):(/.*)?$') {
        $drive = $matches[1].ToLower()
        $rest = $matches[2]
        $wslPath = "/mnt/$drive$rest"
    }
    
    Write-Host "Opening Emacs (WSL) at: $wslPath" -ForegroundColor Gray
    
    # KEY POINT: Using -WindowStyle Hidden "lets go" of the terminal
    # Emacs runs as a completely separate process, not tethered to PowerShell
    # Use single quotes inside to handle spaces in path properly
    $wslCommand = "emacs '$wslPath'"
    Start-Process wsl -ArgumentList $wslCommand -WindowStyle Hidden
    
    Write-Host "Emacs launched (detached from terminal)" -ForegroundColor Green
}

#==============================================================================
# PART 5: MAIN WORKFLOW
#==============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Work Environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Project: $ProjectPath" -ForegroundColor Green

# Verify project path exists
if (-not (Test-Path $ProjectPath)) {
    Write-Warning "Project path does not exist: $ProjectPath"
    $create = Read-Host "Create it? (y/n)"
    if ($create -eq "y") {
        New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
    } else {
        exit 1
    }
}

# Get screen dimensions
$screen = Get-ScreenDimensions
Write-Host "Screen: $($screen.Width)x$($screen.Height)" -ForegroundColor Gray

# Calculate positions
$layout = Calculate-Layout -Screen $screen

#------------------------------------------------------------------------------
# DESKTOP 2: Terminal + File Explorers
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "--- Desktop 2 Setup ---" -ForegroundColor Yellow
Switch-ToDesktop -DesktopNumber 2 | Out-Null

if (-not $SkipExplorer) {
    # Open two File Explorer windows stacked on the left
    Write-Host "Opening File Explorers..." -ForegroundColor Gray
    
    # Register existing explorer windows before opening new ones
    Register-ExistingWindows
    Start-Sleep -Milliseconds 500
    
    # Top-left explorer
    $exp1 = Start-Process explorer -ArgumentList $ProjectPath -PassThru
    Set-WindowPosition -Process $exp1 -ProcessName "explorer" `
                       -X $layout.ExplorerTop.X -Y $layout.ExplorerTop.Y `
                       -Width $layout.ExplorerTop.Width -Height $layout.ExplorerTop.Height
    
    # Bottom-left explorer
    $exp2 = Start-Process explorer -ArgumentList $ProjectPath -PassThru
    Set-WindowPosition -Process $exp2 -ProcessName "explorer" `
                       -X $layout.ExplorerBottom.X -Y $layout.ExplorerBottom.Y `
                       -Width $layout.ExplorerBottom.Width -Height $layout.ExplorerBottom.Height
    
    Write-Host "File Explorers positioned (stacked left)" -ForegroundColor Green
}

if (-not $SkipTerminal) {
    # Open Windows Terminal on the right
    Write-Host "Opening Windows Terminal..." -ForegroundColor Gray
    
    if (-not $SkipExplorer) {
        # Re-register to capture the explorer windows we just opened
        Start-Sleep -Seconds 1
    }
    Register-ExistingWindows
    Start-Sleep -Milliseconds 500
    
    $term = Start-Process wt -ArgumentList "-d `"$ProjectPath`"" -PassThru
    Set-WindowPosition -Process $term -ProcessName "WindowsTerminal" `
                       -X $layout.Terminal.X -Y $layout.Terminal.Y `
                       -Width $layout.Terminal.Width -Height $layout.Terminal.Height
    
    Write-Host "Terminal positioned (right 1/2)" -ForegroundColor Green
}

#------------------------------------------------------------------------------
# DESKTOP 3: Emacs (WSL)
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "--- Desktop 3 Setup ---" -ForegroundColor Yellow
Switch-ToDesktop -DesktopNumber 3 | Out-Null

if (-not $SkipEmacs) {
    # Open Emacs in WSL at project root (detached/background)
    Start-EmacsWSL -ProjectPath $ProjectPath
}

#------------------------------------------------------------------------------
# DONE - Return to Desktop 2
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Work environment started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Switch back to Desktop 2 (main working desktop)
Start-Sleep -Seconds 1
Switch-ToDesktop -DesktopNumber 2 | Out-Null

Write-Host ""
Write-Host "Tips:" -ForegroundColor Yellow
Write-Host "  - ProjectPath can be changed daily: work 'G:\My Drive\Projects\Today'"
Write-Host "  - Use your whkd hotkeys to switch desktops"
Write-Host "  - Emacs runs independently (not tethered to PowerShell)"
