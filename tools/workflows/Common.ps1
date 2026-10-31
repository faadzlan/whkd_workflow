#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for the workflow scripts.
.DESCRIPTION
    Dot-sourced by Load-WorkflowProfile.ps1, Go-ToProject.ps1, and
    Start-WorkEnvironment.ps1 so project-path resolution and WSL path
    conversion have one implementation instead of three drifting copies.
#>

# Resolve ~ in a projects.json path entry.
# Windows paths (~\...) resolve against USERPROFILE; WSL paths (~/...) are
# left untouched for WSL itself to resolve.
function Resolve-ProjectPath {
    param([string]$Path)
    if ($Path -match '^~\\') {
        $Path = $Path -replace '^~\\', "$env:USERPROFILE\"
    } elseif ($Path -match '^~/') {
        # WSL path - leave as-is, WSL resolves its own ~
    } elseif ($Path -match '^~$') {
        $Path = $env:USERPROFILE
    }
    return $Path
}

# Does this path look like a WSL/Linux path rather than a Windows one?
function Test-IsWSLPath {
    param([string]$Path)
    return $Path -match '^(/|~)'
}

# Windows path -> WSL path: G:\folder\file -> /mnt/g/folder/file
function ConvertTo-WSLPath {
    param([string]$WindowsPath)
    if ($WindowsPath -match '^([A-Za-z]):') {
        $drive = $matches[1].ToLower()
        $path = $WindowsPath.Substring(2) -replace '\\', '/'
        return "/mnt/$drive$path"
    }
    return $WindowsPath -replace '\\', '/'
}

# WSL path -> Windows path: /mnt/g/folder/file -> G:\folder\file
function ConvertTo-WindowsPath {
    param([string]$WSLPath)
    if ($WSLPath -match '^/mnt/([a-z])(/.*)?$') {
        $drive = $matches[1].ToUpper()
        $path = $matches[2] -replace '/', '\'
        return "$drive`:$path"
    }
    return $WSLPath -replace '/', '\'
}

# The WSL user's home directory, queried once per session and cached -
# avoids hardcoding a specific username.
function Get-WSLHomeDir {
    param([string]$Distro = "Ubuntu")
    if (-not $script:WSLHomeDir) {
        $script:WSLHomeDir = (wsl.exe -d $Distro -e sh -c 'echo $HOME').Trim()
    }
    return $script:WSLHomeDir
}

# WSL/Linux path -> UNC path that Explorer/Windows Terminal can open directly.
function Convert-WSLPathToUNC {
    param(
        [string]$WSLPath,
        [string]$Distro = "Ubuntu"
    )
    $WSLPath = $WSLPath.TrimEnd('/')
    if ($WSLPath -match '^~') {
        $WSLPath = $WSLPath -replace '^~', (Get-WSLHomeDir -Distro $Distro)
    }
    $windowsPath = $WSLPath -replace '/', '\'
    return "\\wsl.localhost\$Distro$windowsPath"
}
