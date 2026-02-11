<#
.SYNOPSIS
    Comprehensive Network Configuration Logger for Windows 11 (v2)
    Target: Windows 11
    Update: Now captures disconnected adapters and RSC status.
    
.DESCRIPTION
    This script gathers detailed information about:
    1. System & OS Version
    2. ALL Physical Network Adapters (regardless of connection status)
    3. Advanced Adapter Properties (MIMO, Power Saving, Offloading settings)
    4. RSC (Receive Segment Coalescing) Status - Key throttling suspect
    5. TCP/IP Global Parameters
    
    Output is saved to the current user's Desktop.
#>

$ErrorActionPreference = "SilentlyContinue"
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$LogFile = "$DesktopPath\Network_Diagnostic_Log_v2.txt"

Start-Transcript -Path $LogFile -Force

Function Write-Section {
    Param([string]$Title)
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Cyan
}

# 1. System Information
Write-Section "SYSTEM INFORMATION"
$sysInfo = Get-ComputerInfo
Write-Output "Model:        $($sysInfo.CsModel)"
Write-Output "OS Version:   $($sysInfo.OsVersion) ($($sysInfo.OsBuildNumber))"

# 2. Network Adapters (UPDATED: Now includes disconnected physical adapters)
Write-Section "PHYSICAL NETWORK ADAPTERS"
# Filter for physical hardware only (removes virtual switches/VPN taps) to reduce noise
$adapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -ne $null -and $_.PhysicalMediaType -ne "Unspecified" }

if ($adapters) {
    foreach ($adapter in $adapters) {
        Write-Host "`n[Adapter: $($adapter.Name)]" -ForegroundColor Green
        Write-Output "Description: $($adapter.InterfaceDescription)"
        Write-Output "Status:      $($adapter.Status)"
        Write-Output "Driver Ver:  $($adapter.DriverVersion)"
        Write-Output "Driver Date: $($adapter.DriverDate)"
        
        # 3. RSC Check (CRITICAL for Throttling)
        Write-Host "--- RSC (Receive Segment Coalescing) Status ---"
        try {
            $rsc = Get-NetAdapterRsc -Name $adapter.Name
            if ($rsc) {
                Write-Output "IPv4 RSC: $($rsc.IPv4Enabled)"
                Write-Output "IPv6 RSC: $($rsc.IPv6Enabled)"
            }
            else {
                Write-Output "RSC not supported or disabled at hardware level."
            }
        }
        catch {
            Write-Output "Could not query RSC status."
        }

        # 4. Advanced Properties
        Write-Host "--- Advanced Properties ---"
        $advProps = Get-NetAdapterAdvancedProperty -Name $adapter.Name 
        # Expanded list of properties to check for power saving and offloading
        $interestingProps = "MIMO Power Save Mode", "Roaming Aggressiveness", "Throughput Booster", "Packet Coalescing", "Ultra High Band", "Preferred Band", "Energy Efficient Ethernet", "Jumbo Packet", "Receive Side Scaling", "Large Send Offload V2 (IPv4)", "Large Send Offload V2 (IPv6)", "Global BG Scan blocking"
        
        $advProps | Where-Object { $_.DisplayName -in $interestingProps -or $_.RegistryKeyword -like "*PowerSave*" } | Select-Object DisplayName, DisplayValue | Format-Table -AutoSize
    }
}
else {
    Write-Warning "No physical network adapters found."
}

# 5. TCP/IP Global Parameters
Write-Section "TCP/IP GLOBAL PARAMETERS"
Write-Host "--- Netsh Global TCP Dump ---"
netsh int tcp show global

# 6. Power Configuration
Write-Section "POWER CONFIGURATION"
Write-Host "Active Power Plan:"
powercfg /getactivescheme

Write-Section "END OF DIAGNOSTIC"
Stop-Transcript

Write-Host "`nScript Complete. Log saved to: $LogFile" -ForegroundColor Green
Start-Sleep -Seconds 3