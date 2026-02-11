# Advanced Windows Event Log Export Script for LLM Analysis
# Exports Error, Warning, and Critical events from last 7 days with optimization

# Date: 2025-11-13
# Purpose: Export event logs in optimized format for LLM analysis with size management

#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exports Windows Event Logs for LLM analysis with automatic size management.

.DESCRIPTION
    This script exports Windows Event Logs (Application, System, Security) from the last 7 days,
    focusing on Critical, Error, and Warning events. The output is formatted as CSV files
    optimized for LLM analysis with automatic file size management to prevent exceeding
    upload limits.

.PARAMETER ExportPath
    Directory where exported files will be saved. Default: C:\EventLogExports

.PARAMETER DaysToExport
    Number of days to export. Default: 7

.PARAMETER MaxFileSizeMB
    Maximum file size in MB before creating separate files. Default: 10

.PARAMETER IncludeInformational
    Switch to include Informational events (Level 4). Default: False

.EXAMPLE
    .\Export-EventLogsForLLM.ps1

.EXAMPLE
    .\Export-EventLogsForLLM.ps1 -DaysToExport 3 -MaxFileSizeMB 5

.NOTES
    Requires Administrator privileges to access Security log.
#>

param(
    [string]$ExportPath = "C:\EventLogExports",
    [int]$DaysToExport = 7,
    [int]$MaxFileSizeMB = 10,
    [switch]$IncludeInformational
)

# Configuration
$DateStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$ComputerName = $env:COMPUTERNAME

# Event Levels to Export
if ($IncludeInformational) {
    $EventLevels = @(1, 2, 3, 4)  # Critical, Error, Warning, Information
    Write-Host "Including Informational events" -ForegroundColor Yellow
}
else {
    $EventLevels = @(1, 2, 3)  # Critical, Error, Warning only
}

# Logs to Export
$LogsToExport = @(
    @{ Name = "Application"; Description = "Application errors and events" },
    @{ Name = "System"; Description = "System component events" },
    @{ Name = "Security"; Description = "Security audit events" }
)

# Create export directory
if (-not (Test-Path -Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
}

# Calculate start date
$StartDate = (Get-Date).AddDays(-$DaysToExport)

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "  Windows Event Log Export for LLM Analysis" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Computer Name: $ComputerName"
Write-Host "  Export Period: Last $DaysToExport days"
Write-Host "  Start Date: $($StartDate.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "  Export Path: $ExportPath"
Write-Host "  Max File Size: $MaxFileSizeMB MB"
Write-Host ""

# Function to convert event level to readable text
function Get-EventLevelText {
    param([int]$Level)
    switch ($Level) {
        1 { return "Critical" }
        2 { return "Error" }
        3 { return "Warning" }
        4 { return "Information" }
        5 { return "Verbose" }
        default { return "Unknown" }
    }
}

# Function to sanitize text for CSV and LLM readability
function Sanitize-Text {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return "N/A"
    }

    # Replace line breaks and normalize whitespace
    $Text = $Text -replace "`r`n", " | " -replace "`n", " | " -replace "`r", " | "
    # Replace quotes to prevent CSV issues
    $Text = $Text -replace '"', "'" 
    # Normalize multiple spaces
    $Text = $Text -replace '\s+', ' '
    # Trim
    $Text = $Text.Trim()

    return $Text
}

# Function to export event logs with size management
function Export-EventLogData {
    param (
        [hashtable]$LogInfo,
        [datetime]$StartDate,
        [int[]]$Levels,
        [string]$OutputPath,
        [int]$MaxSizeMB
    )

    $LogName = $LogInfo.Name
    Write-Host "[$($LogName)] Processing..." -ForegroundColor Cyan

    try {
        # Build filter hashtable
        $FilterHashtable = @{
            LogName   = $LogName
            Level     = $Levels
            StartTime = $StartDate
        }

        # Get events
        $Events = Get-WinEvent -FilterHashtable $FilterHashtable -ErrorAction Stop

        if ($Events.Count -eq 0) {
            Write-Host "[$($LogName)] No events found." -ForegroundColor Gray
            return @{ Count = 0; Files = @() }
        }

        Write-Host "[$($LogName)] Found $($Events.Count) events. Processing..." -ForegroundColor Yellow

        # Process events
        $ProcessedEvents = @()
        $EventCounter = 0

        foreach ($Event in $Events) {
            $EventCounter++

            # Progress indicator
            if ($EventCounter % 100 -eq 0) {
                Write-Progress -Activity "Processing $LogName Events" `
                    -Status "Processing event $EventCounter of $($Events.Count)" `
                    -PercentComplete (($EventCounter / $Events.Count) * 100)
            }

            $LevelText = Get-EventLevelText -Level $Event.Level

            # Parse XML for event data
            [xml]$EventXml = $Event.ToXml()
            $EventData = $EventXml.Event.EventData.Data

            # Build event data string
            $EventDataString = ""
            if ($EventData) {
                $DataPairs = @()
                for ($i = 0; $i -lt $EventData.Count; $i++) {
                    if ($EventData[$i].Name) {
                        $DataPairs += "$($EventData[$i].Name)=$($EventData[$i].'#text')"
                    }
                    else {
                        $DataPairs += "Data$i=$($EventData[$i])"
                    }
                }
                $EventDataString = $DataPairs -join "; "
            }

            # Create custom object
            $ProcessedEvent = [PSCustomObject]@{
                TimeCreated  = $Event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss.fff")
                LogName      = $Event.LogName
                Level        = $LevelText
                LevelId      = $Event.Level
                EventID      = $Event.Id
                Source       = $Event.ProviderName
                TaskCategory = if ($Event.TaskDisplayName) { $Event.TaskDisplayName } else { "None" }
                Computer     = $Event.MachineName
                UserName     = if ($Event.UserId) { $Event.UserId.Value } else { "SYSTEM" }
                ProcessId    = $Event.ProcessId
                Message      = Sanitize-Text -Text $Event.Message
                EventData    = Sanitize-Text -Text $EventDataString
                RecordId     = $Event.RecordId
            }

            $ProcessedEvents += $ProcessedEvent
        }

        Write-Progress -Activity "Processing $LogName Events" -Completed

        # Sort by time (newest first)
        $ProcessedEvents = $ProcessedEvents | Sort-Object TimeCreated -Descending

        # Calculate size and split if necessary
        $TempFile = "$env:TEMP\temp_eventlog.csv"
        $ProcessedEvents | Export-Csv -Path $TempFile -NoTypeInformation -Encoding UTF8
        $FileSize = (Get-Item $TempFile).Length / 1MB
        Remove-Item $TempFile

        $ExportedFiles = @()

        if ($FileSize -gt $MaxSizeMB) {
            # Split into multiple files
            $EventsPerFile = [math]::Floor($ProcessedEvents.Count / [math]::Ceiling($FileSize / $MaxSizeMB))
            $FileNumber = 1

            Write-Host "[$($LogName)] File size would be $([math]::Round($FileSize, 2)) MB. Splitting into multiple files..." -ForegroundColor Yellow

            for ($i = 0; $i -lt $ProcessedEvents.Count; $i += $EventsPerFile) {
                $EndIndex = [math]::Min($i + $EventsPerFile - 1, $ProcessedEvents.Count - 1)
                $Batch = $ProcessedEvents[$i..$EndIndex]

                $CsvFileName = "$OutputPath\${ComputerName}_${LogName}_Part${FileNumber}_${DateStamp}.csv"
                $Batch | Export-Csv -Path $CsvFileName -NoTypeInformation -Encoding UTF8

                $ActualSize = [math]::Round((Get-Item $CsvFileName).Length / 1KB, 2)
                Write-Host "[$($LogName)] Part $FileNumber exported: $($Batch.Count) events ($ActualSize KB)" -ForegroundColor Green

                $ExportedFiles += $CsvFileName
                $FileNumber++
            }
        }
        else {
            # Single file export
            $CsvFileName = "$OutputPath\${ComputerName}_${LogName}_${DateStamp}.csv"
            $ProcessedEvents | Export-Csv -Path $CsvFileName -NoTypeInformation -Encoding UTF8

            $ActualSize = [math]::Round((Get-Item $CsvFileName).Length / 1KB, 2)
            Write-Host "[$($LogName)] Exported: $($ProcessedEvents.Count) events ($ActualSize KB)" -ForegroundColor Green

            $ExportedFiles += $CsvFileName
        }

        return @{
            Count = $Events.Count
            Files = $ExportedFiles
        }

    }
    catch {
        if ($_.Exception.Message -like "*No events were found*") {
            Write-Host "[$($LogName)] No matching events found." -ForegroundColor Gray
            return @{ Count = 0; Files = @() }
        }
        else {
            Write-Host "[$($LogName)] Error: $($_.Exception.Message)" -ForegroundColor Red
            return @{ Count = 0; Files = @() }
        }
    }
}

# Main execution
$StartTime = Get-Date
$TotalEvents = 0
$AllExportedFiles = @()
$ExportStats = @()

foreach ($Log in $LogsToExport) {
    $Result = Export-EventLogData -LogInfo $Log -StartDate $StartDate -Levels $EventLevels `
        -OutputPath $ExportPath -MaxSizeMB $MaxFileSizeMB

    $TotalEvents += $Result.Count
    $AllExportedFiles += $Result.Files

    $ExportStats += [PSCustomObject]@{
        LogName    = $Log.Name
        EventCount = $Result.Count
        FileCount  = $Result.Files.Count
    }
}

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Generate comprehensive summary
$SummaryFile = "$ExportPath\${ComputerName}_SUMMARY_${DateStamp}.txt"
$SummaryContent = @"
╔════════════════════════════════════════════════════════════╗
║  Windows Event Log Export Summary - LLM Analysis Ready    ║
╚════════════════════════════════════════════════════════════╝

EXPORT INFORMATION
==================
Computer Name    : $ComputerName
Export Date/Time : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Export Duration  : $($Duration.TotalSeconds.ToString("F2")) seconds
Export Period    : Last $DaysToExport days
Start Date       : $($StartDate.ToString("yyyy-MM-dd HH:mm:ss"))

CONFIGURATION
=============
Event Levels     : $(($EventLevels | ForEach-Object { Get-EventLevelText -Level $_ }) -join ", ")
Max File Size    : $MaxFileSizeMB MB
Export Path      : $ExportPath

STATISTICS
==========
Total Events Exported: $TotalEvents

Event Breakdown:
"@

foreach ($Stat in $ExportStats) {
    $SummaryContent += "`n  $($Stat.LogName.PadRight(15)) : $($Stat.EventCount) events in $($Stat.FileCount) file(s)"
}

$SummaryContent += @"


EXPORTED FILES
==============
"@

Get-ChildItem -Path $ExportPath -Filter "*_${DateStamp}*" | ForEach-Object {
    $FileSize = [math]::Round($_.Length / 1KB, 2)
    $SummaryContent += "`n  $($_.Name) ($FileSize KB)"
}

$SummaryContent += @"


LLM ANALYSIS GUIDE
==================
These CSV files are optimized for Large Language Model analysis.

File Structure:
- TimeCreated    : Timestamp of the event
- LogName        : Source log (Application/System/Security)
- Level          : Event severity (Critical/Error/Warning)
- EventID        : Unique event identifier
- Source         : Provider/component that logged the event
- Message        : Detailed event description
- Computer       : Machine name where event occurred
- UserName       : User context or SYSTEM
- EventData      : Additional event-specific parameters

Recommended Analysis Workflow:
1. Start with Critical events - these indicate severe failures
2. Analyze Error events for application/system issues
3. Review Warning events for potential problems
4. Look for patterns in EventID and Source fields
5. Correlate events across different logs by timestamp
6. Focus on recurring events (same EventID, similar messages)

Common Analysis Queries for LLM:
- "Summarize all Critical events and their root causes"
- "Identify patterns in Error messages over the time period"
- "Find security-related events and potential threats"
- "Analyze application crashes and their frequencies"
- "Suggest remediation steps for the top 5 recurring errors"

Event Level Priorities:
- Critical (1)    : Immediate action required - system failure
- Error (2)       : Significant problems requiring investigation
- Warning (3)     : Potential issues, may not need immediate action

Security Log Notes:
- Event 4624 : Successful logon
- Event 4625 : Failed logon attempt
- Event 4672 : Special privileges assigned
- Event 4688 : New process created

System Log Notes:
- Event 41   : System unexpectedly rebooted
- Event 1074 : System shutdown/restart
- Event 6008 : Unexpected shutdown

Application Log Notes:
- Event 1000 : Application error/crash
- Event 1001 : Windows Error Reporting fault

Data Sanitization Applied:
- Line breaks converted to " | " for CSV compatibility
- Double quotes converted to single quotes
- Multiple spaces normalized
- All text fields trimmed

File Size Management:
- Files automatically split if exceeding $MaxFileSizeMB MB
- Part numbers indicate sequence when split
- All parts sorted by newest events first

USAGE TIPS
==========
1. Upload files to LLM in order: Critical → Error → Warning
2. If file size is still too large, reduce DaysToExport parameter
3. Focus analysis on specific Event IDs if volume is high
4. Cross-reference events between different log types
5. Pay attention to timestamp clustering (multiple events at same time)

For more detailed analysis, consider:
- Filtering by specific Event IDs
- Narrowing time range to specific periods
- Focusing on specific sources/providers
- Comparing events before and after system changes

Generated with Advanced Event Log Export Script
================================================
"@

$SummaryContent | Out-File -FilePath $SummaryFile -Encoding UTF8

# Display final summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "  Export Complete!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  Total Events: $TotalEvents"
Write-Host "  Files Created: $($AllExportedFiles.Count)"
Write-Host "  Duration: $($Duration.TotalSeconds.ToString("F2")) seconds"
Write-Host "  Summary Report: $SummaryFile"
Write-Host "`nFiles are ready for LLM analysis!`n" -ForegroundColor Green
