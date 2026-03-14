#Requires -Version 5.1
<#
.SYNOPSIS
    WSL-Windows bridge utilities.
.DESCRIPTION
    Helper functions for working between Windows and WSL environments.
    Makes WSL paths, clipboard sharing, and file operations seamless.
#>

#==============================================================================
# PATH CONVERSION
#==============================================================================

<#
.SYNOPSIS
    Convert Windows path to WSL path.
.EXAMPLE
    ConvertTo-WSLPath "G:\My Drive\Projects"
    # Returns: /mnt/g/My Drive/Projects
#>
function ConvertTo-WSLPath {
    param([string]$WindowsPath)
    
    if ($WindowsPath -match '^([A-Za-z]):') {
        $drive = $matches[1].ToLower()
        $path = $WindowsPath.Substring(2) -replace '\\', '/'
        return "/mnt/$drive$path"
    }
    return $WindowsPath -replace '\\', '/'
}

<#
.SYNOPSIS
    Convert WSL path to Windows path.
.EXAMPLE
    ConvertTo-WindowsPath "/mnt/g/My Drive/Projects"
    # Returns: G:\My Drive\Projects
#>
function ConvertTo-WindowsPath {
    param([string]$WSLPath)
    
    if ($WSLPath -match '^/mnt/([a-z])(/.*)?$') {
        $drive = $matches[1].ToUpper()
        $path = $matches[2] -replace '/', '\'
        return "$drive`:$path"
    }
    return $WSLPath -replace '/', '\'
}

# Short aliases
Set-Alias -Name wsl-path -Value ConvertTo-WSLPath
Set-Alias -Name win-path -Value ConvertTo-WindowsPath

#==============================================================================
# CLIPBOARD BRIDGE
#==============================================================================

<#
.SYNOPSIS
    Copy Windows path to WSL clipboard format.
.DESCRIPTION
    Copies current directory or given path in WSL format to clipboard.
    Useful for pasting into WSL terminals.
#>
function Copy-WSLPath {
    param([string]$Path = (Get-Location).Path)
    
    $wslPath = ConvertTo-WSLPath $Path
    $wslPath | Set-Clipboard
    Write-Host "Copied to clipboard: $wslPath" -ForegroundColor Green
}

<#
.SYNOPSIS
    Copy current Windows path (Windows format) to clipboard.
    Like `pwd | clip` but actually useful.
#>
function Copy-WindowsPath {
    param([string]$Path = (Get-Location).Path)
    
    $Path | Set-Clipboard
    Write-Host "Copied to clipboard: $Path" -ForegroundColor Green
}

#==============================================================================
# FILE OPERATIONS
#==============================================================================

<#
.SYNOPSIS
    Open current directory in WSL file manager (if available).
.DESCRIPTION
    Opens Windows Explorer at the WSL-equivalent Windows path.
#>
function Open-WSLInExplorer {
    $current = (Get-Location).Path
    Start-Process explorer -ArgumentList $current
}

<#
.SYNOPSIS
    Run a command in WSL with current Windows directory.
.EXAMPLE
    wsl-here ls -la
    wsl-here emacs .
#>
function Invoke-InWSL {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Command
    )
    
    $wslPath = ConvertTo-WSLPath (Get-Location).Path
    $cmdString = $Command -join ' '
    
    Write-Host "Running in WSL ($wslPath): $cmdString" -ForegroundColor Gray
    wsl cd "$wslPath" && $cmdString
}

Set-Alias -Name wsl-here -Value Invoke-InWSL

#==============================================================================
# WSL STATUS
#==============================================================================

<#
.SYNOPSIS
    Show WSL distribution status.
#>
function Get-WSLStatus {
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

#==============================================================================
# EXPORTS FOR POWERSHELL PROFILE
#==============================================================================

$exports = @"
# WSL Bridge Functions
function wsl-path { ConvertTo-WSLPath `$args[0] }
function win-path { ConvertTo-WindowsPath `$args[0] }
function cp-wsl { Copy-WSLPath `$args[0] }
function cp-win { Copy-WindowsPath `$args[0] }
function wsl-here { Invoke-InWSL `$args }
function wsl-status { Get-WSLStatus }
"@

Write-Host "WSL Bridge loaded!" -ForegroundColor Green
Write-Host "Available functions:" -ForegroundColor Yellow
Write-Host "  ConvertTo-WSLPath / wsl-path   - Convert G:\path to /mnt/g/path" -ForegroundColor Gray
Write-Host "  ConvertTo-WindowsPath / win-path - Convert /mnt/g/path to G:\path" -ForegroundColor Gray
Write-Host "  Copy-WSLPath / cp-wsl          - Copy WSL path to clipboard" -ForegroundColor Gray
Write-Host "  Copy-WindowsPath / cp-win      - Copy Windows path to clipboard" -ForegroundColor Gray
Write-Host "  Invoke-InWSL / wsl-here        - Run command in WSL at current dir" -ForegroundColor Gray
Write-Host "  Get-WSLStatus / wsl-status     - Show WSL distro status" -ForegroundColor Gray
