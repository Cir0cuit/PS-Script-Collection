<#
.SYNOPSIS
    Diagnose Idle System Resources (CPU, RAM, Disk)
    Runs for 30 minutes and exports data to CSV files for analysis.

.DESCRIPTION
    1. Collects System Totals (CPU%, Mem, Disk Active%) every 10s.
    2. Collects Top 10 CPU & Memory Processes every 60s.
    3. Exports Error/Warning Event Logs from the last 30 mins.
    4. Exports Active Services snapshot.

    Run as Administrator for full access to Event Logs and System Counters.
#>
#Requires -RunAsAdministrator

# --- Configuration ---
$DurationMinutes = 30
$IntervalSeconds = 2        # Capture system totals every 2 seconds (was 10)
$ProcessLogInterval = 5     # Capture top processes every 5th interval (5 * 2s = 10s)
$BaseDir = "$([Environment]::GetFolderPath('Desktop'))\IdleDiagnostics_$(Get-Date -Format 'yyyyMMdd_HHmm')"

# --- Setup ---
Write-Host "Starting Idle Diagnostics..." -ForegroundColor Cyan
Write-Host "Logs will be saved to: $BaseDir"
Write-Host "Duration: $DurationMinutes minutes. Please LEAVE THE SYSTEM IDLE." -ForegroundColor Yellow

New-Item -Path $BaseDir -ItemType Directory -Force | Out-Null
$GlobalLog = "$BaseDir\System_Totals.csv"
$ProcessLog = "$BaseDir\Top_Processes.csv"

# --- Headers for CSVs ---
"Timestamp,CPU_Total_%,Available_Memory_MB,Disk_Active_%" | Out-File $GlobalLog -Encoding utf8
"Timestamp,ProcessName,ID,Metric,Value,Description" | Out-File $ProcessLog -Encoding utf8

# --- Helper Function: Get Top Processes ---
function Get-TopProcesses {
    param ([string]$Timestamp)
    
    # Top CPU (Snapshot)
    # Note: Get-Process CPU is total time, so we use WMI/Counter for instant usage or simplified approximation
    $TopCPU = Get-WmiObject Win32_PerfFormattedData_PerfProc_Process | 
    Where-Object { $_.Name -ne "_Total" -and $_.Name -ne "Idle" -and $_.PercentProcessorTime -gt 0 } | 
    Sort-Object PercentProcessorTime -Descending | Select-Object -First 10
    
    foreach ($proc in $TopCPU) {
        "$Timestamp,$($proc.Name),$($proc.ID_Process),CPU_Usage_%,$($proc.PercentProcessorTime),Top_CPU_Consumer" | Out-File $ProcessLog -Append -Encoding utf8
    }

    # Top Memory (Working Set)
    $TopMem = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
    foreach ($proc in $TopMem) {
        $memMB = [math]::Round($proc.WorkingSet / 1MB, 2)
        "$Timestamp,$($proc.ProcessName),$($proc.Id),Memory_MB,$memMB,Top_Memory_Consumer" | Out-File $ProcessLog -Append -Encoding utf8
    }
}

# --- Main Monitoring Loop ---
$StartTime = Get-Date
$EndTime = $StartTime.AddMinutes($DurationMinutes)
$Counter = 0

try {
    do {
        $CurrentTime = Get-Date
        $Timestamp = $CurrentTime.ToString("HH:mm:ss")
        $TimeRemaining = New-TimeSpan -Start $CurrentTime -End $EndTime
        
        Write-Progress -Activity "Monitoring System Resources" -Status "Time Remaining: $($TimeRemaining.ToString('mm\:ss'))" -PercentComplete (100 - ($TimeRemaining.TotalMinutes / $DurationMinutes * 100))

        # 1. System Totals
        try {
            $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            $mem = (Get-Counter "\Memory\Available MBytes" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
            $disk = (Get-Counter "\PhysicalDisk(_Total)\% Disk Time" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
            
            # Sanitize data
            if (-not $cpu) { $cpu = 0 }
            if (-not $mem) { $mem = 0 }
            if (-not $disk) { $disk = 0 }

            "$Timestamp,$cpu,$mem,$disk" | Out-File $GlobalLog -Append -Encoding utf8
        }
        catch {
            Write-Warning "Failed to fetch system counters at $Timestamp"
        }

        # 2. Top Processes (Every 60s approx)
        if ($Counter % $ProcessLogInterval -eq 0) {
            Get-TopProcesses -Timestamp $Timestamp
        }

        $Counter++
        Start-Sleep -Seconds $IntervalSeconds

    } while ((Get-Date) -lt $EndTime)
}
catch {
    Write-Error "An error occurred during monitoring: $_"
}

# --- Post-Run Collection ---
Write-Host "Collection finished. Exporting Event Logs & Services..." -ForegroundColor Cyan

# 3. Export Event Logs (Errors/Warnings from last 30 mins)
$EventLogFile = "$BaseDir\System_Events.csv"
try {
    Get-EventLog -LogName System, Application -After $StartTime -EntryType Error, Warning | 
    Select-Object TimeGenerated, EntryType, Source, EventID, Message | 
    Export-Csv -Path $EventLogFile -NoTypeInformation -Encoding utf8
}
catch { Write-Warning "Could not export Event Logs (Run as Admin?)" }

# 4. Export Running Services
$ServicesFile = "$BaseDir\Running_Services.csv"
Get-Service | Where-Object { $_.Status -eq 'Running' } | 
Select-Object Name, DisplayName, StartType | 
Export-Csv -Path $ServicesFile -NoTypeInformation -Encoding utf8

Write-Host "Done! Diagnostics saved to: $BaseDir" -ForegroundColor Green
Write-Host "You can now upload the files from this folder to Gemini/Perplexity for analysis." -ForegroundColor Green
Start-Process "explorer.exe" $BaseDir