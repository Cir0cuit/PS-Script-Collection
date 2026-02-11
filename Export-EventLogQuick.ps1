# ============================================================
# Windows 11 Event Log Exporter for LLM Analysis
# Created for: Efficiency & Performance Analysis
# Lookback: 7 Days
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$desktopPath = [Environment]::GetFolderPath("Desktop")
$outputFile = "$desktopPath\Win11_Log_Analysis.json"
$daysBack = 7
$startDate = (Get-Date).AddDays(-$daysBack)

Write-Host "Starting Log Export... (This may take a moment)" -ForegroundColor Cyan

# 1. Gather System Context (Crucial for LLM to judge performance)
Write-Host "[-] Gathering System Hardware Info..."
$sysInfo = Get-ComputerInfo | Select-Object CsName, WindowsProductName, CsProcessors, @{N='RamGB';E={[math]::Round($_.CsTotalPhysicalMemory/1GB, 0)}}, OsLastBootUpTime

# 2. Define Log Queries
# We use Get-WinEvent with FilterHashtable for speed.

# Query A: General System & Application Health (Errors & Warnings Only)
# Level 1=Critical, 2=Error, 3=Warning
$filterGeneral = @{
    LogName = 'System','Application'
    Level = 1, 2, 3
    StartTime = $startDate
}

# Query B: Specialized Performance Diagnostics (Boot/Shutdown Degradation)
# We want ALL events from this log as they are rare and high-value.
$filterPerf = @{
    LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
    StartTime = $startDate
}

# 3. Fetch Events
Write-Host "[-] Fetching Error and Warning events from the last $daysBack days..."
$eventsGeneral = Get-WinEvent -FilterHashtable $filterGeneral

Write-Host "[-] Fetching Boot/Shutdown Performance metrics..."
$eventsPerf = Get-WinEvent -FilterHashtable $filterPerf

# 4. Combine and Process
# We select only properties relevant to the LLM to save token space.
$allEvents = $eventsGeneral + $eventsPerf | Sort-Object TimeCreated

$cleanEvents = $allEvents | Select-Object @{N='Time';E={$_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')}},
                                          @{N='Level';E={$_.LevelDisplayName}},
                                          @{N='Log';E={$_.LogName}},
                                          @{N='Source';E={$_.ProviderName}},
                                          Id,
                                          @{N='Message';E={$_.Message.Trim()}}

# 5. Construct Final JSON Object
$finalReport = @{
    ReportType = "Windows 11 Performance & Error Log"
    GeneratedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    SystemContext = $sysInfo
    EventCount = $cleanEvents.Count
    Events = $cleanEvents
}

# 6. Export to JSON
Write-Host "[-] Exporting to $outputFile..."
$finalReport | ConvertTo-Json -Depth 3 | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "Done! Upload 'Win11_Log_Analysis.json' from your Desktop to the LLM." -ForegroundColor Green
Start-Sleep -Seconds 3