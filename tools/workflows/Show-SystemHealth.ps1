#Requires -Version 5.1
<#
.SYNOPSIS
    Quick system health dashboard - answers "Why is my PC slow?"
.DESCRIPTION
    Shows memory hogs, CPU usage, disk space, and startup impact.
    Like `top`, `df -h`, and `free -m` combined for Windows.
#>

[CmdletBinding()]
param(
    [switch]$ShowAllProcesses
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "System Health Dashboard" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

#------------------------------------------------------------------------------
# MEMORY - Like `free -m` in Linux
#------------------------------------------------------------------------------
Write-Host "MEMORY USAGE" -ForegroundColor Yellow
Write-Host "------------" -ForegroundColor Yellow

$totalRAM = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$availRAM = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1MB
$usedRAM = $totalRAM - $availRAM
$ramPercent = [math]::Round(($usedRAM / $totalRAM) * 100, 1)

# Color-code the memory status
if ($ramPercent -gt 90) { $ramColor = "Red" }
elseif ($ramPercent -gt 75) { $ramColor = "Yellow" }
else { $ramColor = "Green" }

Write-Host "Total: $([math]::Round($totalRAM, 1)) GB" -ForegroundColor Gray
Write-Host "Used:  $([math]::Round($usedRAM, 1)) GB ($ramPercent%)" -ForegroundColor $ramColor
Write-Host "Free:  $([math]::Round($availRAM, 1)) GB" -ForegroundColor Gray

# Top memory consumers (like `ps aux --sort=-%mem | head`)
Write-Host "`nTop Memory Consumers:" -ForegroundColor Yellow
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 | 
    Format-Table -Property @{
        Name = "Process"
        Expression = { $_.ProcessName }
        Width = 20
    }, @{
        Name = "Memory (MB)"
        Expression = { [math]::Round($_.WorkingSet / 1MB, 1) }
        Align = "Right"
    }, @{
        Name = "PID"
        Expression = { $_.Id }
        Width = 8
    } -AutoSize

#------------------------------------------------------------------------------
# CPU - Like `top` CPU column
#------------------------------------------------------------------------------
Write-Host "`nCPU USAGE" -ForegroundColor Yellow
Write-Host "----------" -ForegroundColor Yellow

$cpuLoad = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

if ($cpuLoad -gt 80) { $cpuColor = "Red" }
elseif ($cpuLoad -gt 50) { $cpuColor = "Yellow" }
else { $cpuColor = "Green" }

Write-Host "Current Load: $([math]::Round($cpuLoad, 1))%" -ForegroundColor $cpuColor

# Top CPU consumers
Write-Host "`nTop CPU Consumers:" -ForegroundColor Yellow
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 |
    Format-Table -Property @{
        Name = "Process"
        Expression = { $_.ProcessName }
        Width = 20
    }, @{
        Name = "CPU Time"
        Expression = { [math]::Round($_.CPU, 1) }
        Align = "Right"
    }, @{
        Name = "PID"
        Expression = { $_.Id }
        Width = 8
    } -AutoSize

#------------------------------------------------------------------------------
# DISK SPACE - Like `df -h` in Linux
#------------------------------------------------------------------------------
Write-Host "`nDISK SPACE" -ForegroundColor Yellow
Write-Host "----------" -ForegroundColor Yellow

Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freeGB = [math]::Round($_.FreeSpace / 1GB, 2)
    $totalGB = [math]::Round($_.Size / 1GB, 2)
    $usedGB = $totalGB - $freeGB
    $percentFree = [math]::Round(($freeGB / $totalGB) * 100, 1)
    
    if ($percentFree -lt 10) { $diskColor = "Red" }
    elseif ($percentFree -lt 20) { $diskColor = "Yellow" }
    else { $diskColor = "Green" }
    
    Write-Host "$($_.DeviceID) " -NoNewline
    Write-Host "$usedGB GB / $totalGB GB" -NoNewline -ForegroundColor Gray
    Write-Host " ($percentFree% free)" -ForegroundColor $diskColor
}

#------------------------------------------------------------------------------
# STARTUP IMPACT - Windows-specific
#------------------------------------------------------------------------------
Write-Host "`nSTARTUP PROGRAMS (High Impact)" -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow

# Get startup tasks from Task Manager's Startup tab
Get-CimInstance -ClassName Win32_StartupCommand | 
    Select-Object -First 10 |
    Format-Table -Property @{
        Name = "Program"
        Expression = { $_.Name }
        Width = 30
    }, @{
        Name = "Command"
        Expression = { 
            if ($_.Command.Length -gt 50) { $_.Command.Substring(0, 47) + "..." }
            else { $_.Command }
        }
        Width = 50
    } -AutoSize

#------------------------------------------------------------------------------
# NETWORK - Like `ip addr` or `ifconfig`
#------------------------------------------------------------------------------
Write-Host "`nNETWORK" -ForegroundColor Yellow
Write-Host "-------" -ForegroundColor Yellow

$ipConfig = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" 
} | Select-Object -First 1

if ($ipConfig) {
    Write-Host "IPv4 Address: $($ipConfig.IPAddress)" -ForegroundColor Green
    Write-Host "Interface:    $($ipConfig.InterfaceAlias)" -ForegroundColor Gray
} else {
    Write-Host "No active network connection found" -ForegroundColor Red
}

# Quick ping to Google
Write-Host "`nInternet Connectivity:" -ForegroundColor Yellow -NoNewline
$ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet
if ($ping) {
    Write-Host " ✓ Online" -ForegroundColor Green
} else {
    Write-Host " ✗ Offline" -ForegroundColor Red
}

#------------------------------------------------------------------------------
# RECOMMENDATIONS
#------------------------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "QUICK ACTIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($ramPercent -gt 85) {
    Write-Host "⚠ High memory usage detected!" -ForegroundColor Red
    Write-Host "  Run: Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10" -ForegroundColor Yellow
    Write-Host "  Or:  Stop-Process -Name chrome -Force (if Chrome is the culprit)" -ForegroundColor Yellow
}

if ($ShowAllProcesses) {
    Write-Host "`nAll Running Processes:" -ForegroundColor Yellow
    Get-Process | Sort-Object WorkingSet -Descending | 
        Select-Object -First 20 |
        Format-Table Name, Id, @{Name="Memory(MB)"; Expression={[math]::Round($_.WorkingSet/1MB)}}, CPU -AutoSize
}

Write-Host "`nUseful commands:" -ForegroundColor Gray
Write-Host "  Show-SystemHealth -ShowAllProcesses  # See all top processes" -ForegroundColor DarkGray
Write-Host "  taskkill /f /im chrome.exe           # Kill Chrome if unresponsive" -ForegroundColor DarkGray
Write-Host "  Get-NetAdapter | Format-Table        # Network adapter details" -ForegroundColor DarkGray
