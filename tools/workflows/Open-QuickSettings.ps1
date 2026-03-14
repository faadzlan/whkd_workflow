#Requires -Version 5.1
<#
.SYNOPSIS
    Quick shortcuts to Windows Settings pages.
.DESCRIPTION
    Opens common Settings pages without clicking through UI.
    Like xdg-open for Windows Settings URIs.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Bluetooth", "Audio", "Display", "Network", "Power", "Storage", 
                 "Startup", "Notifications", "DefaultApps", "Privacy", "Update", "All")]
    [string]$Setting = "All"
)

# Settings URI mappings
$settingsMap = @{
    Bluetooth      = "ms-settings:bluetooth"
    Audio          = "ms-settings:sound"
    Display        = "ms-settings:display"
    Network        = "ms-settings:network"
    Power          = "ms-settings:powersleep"
    Storage        = "ms-settings:storagesense"
    Startup        = "ms-settings:startupapps"
    Notifications  = "ms-settings:notifications"
    DefaultApps    = "ms-settings:defaultapps"
    Privacy        = "ms-settings:privacy"
    Update         = "ms-settings:windowsupdate"
}

if ($Setting -eq "All") {
    Write-Host "Available Quick Settings:" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""
    
    $i = 1
    foreach ($key in ($settingsMap.Keys | Sort-Object)) {
        Write-Host "  $i. $key" -ForegroundColor Yellow
        $i++
    }
    
    Write-Host "`nUsage examples:" -ForegroundColor Gray
    Write-Host '  Open-QuickSettings -Setting Bluetooth' -ForegroundColor DarkGray
    Write-Host '  Open-QuickSettings -Setting Audio' -ForegroundColor DarkGray
    Write-Host "`nOr use these functions:" -ForegroundColor Gray
    Write-Host '  bt   # Opens Bluetooth' -ForegroundColor DarkGray
    Write-Host '  vol  # Opens Audio/Sound' -ForegroundColor DarkGray
} else {
    $uri = $settingsMap[$Setting]
    Write-Host "Opening $Setting settings..." -ForegroundColor Green
    Start-Process $uri
}

# Create convenient aliases
function global:bt { & $PSScriptRoot\Open-QuickSettings.ps1 -Setting Bluetooth }
function global:vol { & $PSScriptRoot\Open-QuickSettings.ps1 -Setting Audio }
function global:wifi { & $PSScriptRoot\Open-QuickSettings.ps1 -Setting Network }
function global:disp { & $PSScriptRoot\Open-QuickSettings.ps1 -Setting Display }
