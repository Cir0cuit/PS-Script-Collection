<#
.SYNOPSIS
    Network Performance Optimizer for Windows 11
    Target: Intel Wi-Fi 6E AX211 & Windows 11 TCP Stack

.DESCRIPTION
    This script applies the following fixes to optimize network reliability and performance:
    1. Disables MIMO Power Save Mode (Forces full antenna usage).
    2. Disables Packet Coalescing (Reduces latency).
    3. Disables Global RSC (Fixes Windows 11 throughput bug).
    4. Sets "Throughput Booster" to Enabled (Optional performance gain).
    
    It attempts to auto-detect Wi-Fi and Ethernet adapters but allows overriding via parameters.

    REQUIRES ADMINISTRATOR PRIVILEGES.

.PARAMETER WifiAdapterName
    Name of the Wi-Fi adapter to optimize. Default is auto-detected.

.PARAMETER EthernetAdapterName
    Name of the Ethernet adapter to optimize. Default is auto-detected.
#>

[CmdletBinding()]
param (
    [string]$WifiAdapterName,
    [string]$EthernetAdapterName
)

# Check for Administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges to change driver settings."
    Write-Warning "Please right-click the file and select 'Run with PowerShell' -> then accept the UAC prompt."
    Start-Sleep -Seconds 5
    Exit
}

$ErrorActionPreference = "SilentlyContinue"
Write-Host "Applying Network Optimizations..." -ForegroundColor Cyan

# Auto-detect adapters if not provided
if (-not $WifiAdapterName) {
    $wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*Wireless*" } | Select-Object -First 1
    if ($wifiAdapter) {
        $WifiAdapterName = $wifiAdapter.Name
        Write-Host "Auto-detected Wi-Fi Adapter: $WifiAdapterName" -ForegroundColor Gray
    } else {
        $WifiAdapterName = "Wi-Fi" # Fallback default
        Write-Host "Could not auto-detect Wi-Fi. Using default: $WifiAdapterName" -ForegroundColor Gray
    }
}

if (-not $EthernetAdapterName) {
    $ethAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Ethernet*" -or $_.InterfaceDescription -like "*Gigabit*" -or $_.InterfaceDescription -like "*Controller*" } | Where-Object { $_.Name -notlike "*vEthernet*" } | Select-Object -First 1
    if ($ethAdapter) {
        $EthernetAdapterName = $ethAdapter.Name
        Write-Host "Auto-detected Ethernet Adapter: $EthernetAdapterName" -ForegroundColor Gray
    } else {
        $EthernetAdapterName = "Ethernet" # Fallback default
        Write-Host "Could not auto-detect Ethernet. Using default: $EthernetAdapterName" -ForegroundColor Gray
    }
}

# 1. Optimize Wi-Fi Adapter
Write-Host "`n[1/3] Optimizing Adapter: $WifiAdapterName" -ForegroundColor Yellow

# Fix 1: Disable MIMO Power Save (The biggest culprit)
Write-Host "   - Setting MIMO Power Save Mode to 'No SMPS'..."
Set-NetAdapterAdvancedProperty -Name $WifiAdapterName -DisplayName "MIMO Power Save Mode" -DisplayValue "No SMPS" 

# Fix 2: Disable Packet Coalescing (Latency fix)
Write-Host "   - Disabling Packet Coalescing..."
Set-NetAdapterAdvancedProperty -Name $WifiAdapterName -DisplayName "Packet Coalescing" -DisplayValue "Disabled"

# Fix 3: Enable Throughput Booster (Increases burst speeds)
Write-Host "   - Enabling Throughput Booster..."
Set-NetAdapterAdvancedProperty -Name $WifiAdapterName -DisplayName "Throughput Booster" -DisplayValue "Enabled"

# 2. Fix Global TCP Stack (RSC Bug)
Write-Host "`n[2/3] Optimizing Global TCP Stack" -ForegroundColor Yellow
Write-Host "   - Disabling Receive Segment Coalescing (RSC)..."
netsh int tcp set global rsc=disabled
if ($LASTEXITCODE -eq 0) { Write-Host "     Success." -ForegroundColor Green }

# 3. Optimize Ethernet Adapter
Write-Host "`n[3/3] Optimizing Adapter: $EthernetAdapterName" -ForegroundColor Yellow
Write-Host "   - Ensuring Flow Control is Disabled..."
Set-NetAdapterAdvancedProperty -Name $EthernetAdapterName -DisplayName "Flow Control" -DisplayValue "Disabled"

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " OPTIMIZATION COMPLETE" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Please RESTART your computer for these changes to take effect."
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")