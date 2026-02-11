<#
.SYNOPSIS
    Gathers comprehensive hardware and driver information and exports it to a JSON file
    optimized for LLM analysis.

.DESCRIPTION
    This script utilizes CIM/WMI instances to fetch details about:
    - Computer System & OS
    - Processor (CPU)
    - Memory (RAM)
    - Storage (Disks & Partitions)
    - Video Controller (GPU)
    - Network Adapters
    - Signed Drivers
    
    The output is saved as a structured JSON file.

.NOTES
    File Name  : Gather-SystemInfo.ps1

#>

$ErrorActionPreference = "SilentlyContinue"

Write-Host "Starting System Information Scan..." -ForegroundColor Cyan

# --- Helper Function to get readable size ---
function Format-Size {
    param ([long]$bytes)
    if ($bytes -gt 1TB) { return "$([math]::Round($bytes / 1TB, 2)) TB" }
    if ($bytes -gt 1GB) { return "$([math]::Round($bytes / 1GB, 2)) GB" }
    if ($bytes -gt 1MB) { return "$([math]::Round($bytes / 1MB, 2)) MB" }
    return "$bytes Bytes"
}

# --- 1. System & OS ---
Write-Host "Gathering OS and System info..." -ForegroundColor Yellow
$computerSystem = Get-CimInstance Win32_ComputerSystem
$osSystem = Get-CimInstance Win32_OperatingSystem

$sysInfo = [PSCustomObject]@{
    Manufacturer = $computerSystem.Manufacturer
    Model        = $computerSystem.Model
    SystemType   = $computerSystem.SystemType
    TotalMemory  = Format-Size $computerSystem.TotalPhysicalMemory
}

$osInfo = [PSCustomObject]@{
    Name         = $osSystem.Caption
    Version      = $osSystem.Version
    Build        = $osSystem.BuildNumber
    Architecture = $osSystem.OSArchitecture
    LastBoot     = $osSystem.LastBootUpTime
}

# --- 2. CPU ---
Write-Host "Gathering CPU info..." -ForegroundColor Yellow
$cpuList = Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, SocketDesignation

# --- 3. RAM ---
Write-Host "Gathering Memory info..." -ForegroundColor Yellow
$ramList = Get-CimInstance Win32_PhysicalMemory | Select-Object Manufacturer, PartNumber, Speed, @{N = 'Capacity'; E = { Format-Size $_.Capacity } }, ConfiguredVoltage

# --- 4. GPU ---
Write-Host "Gathering GPU info..." -ForegroundColor Yellow
$gpuList = Get-CimInstance Win32_VideoController | Select-Object Name, VideoProcessor, DriverVersion, DriverDate, @{N = 'VRAM'; E = { Format-Size $_.AdapterRAM } }, CurrentHorizontalResolution, CurrentVerticalResolution

# --- 5. Storage ---
Write-Host "Gathering Storage info..." -ForegroundColor Yellow
$diskList = Get-CimInstance Win32_DiskDrive | Select-Object Model, InterfaceType, MediaType, @{N = 'Size'; E = { Format-Size $_.Size } }, Partitions, Status

# --- 6. Network ---
Write-Host "Gathering Network info..." -ForegroundColor Yellow
$netList = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true } | Select-Object Name, Manufacturer, Speed, MACAddress, NetConnectionStatus, DriverName, DriverVersion

# --- 7. Drivers (Detailed) ---
# Fetching signed drivers. This can be a long list, so we select relevant properties for analysis.
Write-Host "Gathering Driver info (this may take a moment)..." -ForegroundColor Yellow
$driverList = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceName -ne $null } | Select-Object DeviceName, Manufacturer, DriverVersion, DriverDate, DriverProviderName, HardWareID

# --- Assemble Report ---
$report = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    System    = $sysInfo
    OS        = $osInfo
    CPU       = $cpuList
    Memory    = $ramList
    GPU       = $gpuList
    Storage   = $diskList
    Network   = $netList
    Drivers   = $driverList
}

# --- Export to JSON ---
$desktopPath = [Environment]::GetFolderPath("Desktop")
$outputFile = Join-Path -Path $desktopPath -ChildPath "System_Hardware_Drivers_Log.json"

# If writing to Desktop fails (permissions), write to current script location
if (-not (Test-Path $desktopPath)) {
    $outputFile = ".\System_Hardware_Drivers_Log.json"
}

Write-Host "Exporting data to JSON..." -ForegroundColor Yellow
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputFile -Encoding utf8

Write-Host "Done!" -ForegroundColor Green
Write-Host "Log saved to: $outputFile" -ForegroundColor White
Write-Host "You can now upload this file to an LLM for analysis." -ForegroundColor Cyan