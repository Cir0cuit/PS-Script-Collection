#Requires -RunAsAdministrator

Clear-Host
Write-Host "Starting Search Indexer cleanup..." -ForegroundColor Cyan
Write-Host "----------------------------------"

# 1. Disable Windows Search Service
try {
    Write-Host "Stopping Windows Search (WSearch) service..." -NoNewline
    
    # Force stop the service
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
    
    # Wait a moment to ensure file locks are released
    Start-Sleep -Seconds 3
    
    # Disable the service so it doesn't restart on boot
    Set-Service -Name "WSearch" -StartupType Disabled
    Write-Host " [OK]" -ForegroundColor Green
}
catch {
    Write-Host " [Error]" -ForegroundColor Red
    Write-Host "Could not manage WSearch service. It may not be running."
}

# 2. Define path to Search Data
# The standard location for the index database
$searchDataPath = "C:\ProgramData\Microsoft\Search"

# 3. Calculate Space and Clean Up
if (Test-Path $searchDataPath) {
    try {
        Write-Host "Locating index database files..."
        
        # Calculate size of the Search folder
        $files = Get-ChildItem -Path $searchDataPath -Recurse -Force -ErrorAction SilentlyContinue
        
        if ($files) {
            $measure = $files | Measure-Object -Property Length -Sum
            $sizeBytes = $measure.Sum
            $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
            
            Write-Host "Found index data. Deleting..." -NoNewline

            # Remove the folder and its contents
            Remove-Item -Path $searchDataPath -Force -Recurse -ErrorAction Stop
            
            Write-Host " [OK]" -ForegroundColor Green
            Write-Host "----------------------------------"
            Write-Host "Success! Windows Search has been disabled." -ForegroundColor Green
            Write-Host "Total disk space freed: $sizeMB MB" -ForegroundColor Yellow
        }
        else {
            Write-Host "Search data folder exists but is empty." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host " [Error]" -ForegroundColor Red
        Write-Host "Could not delete files. The service might still be holding them."
        Write-Host "Try restarting your computer and running this script again immediately."
    }
}
else {
    Write-Host "Search data folder not found (already cleaned?)." -ForegroundColor Yellow
}

Write-Host "----------------------------------"
Write-Host "Press any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")