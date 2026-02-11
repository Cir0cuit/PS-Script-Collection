#Requires -RunAsAdministrator

Clear-Host
Write-Host "Starting cleanup process..." -ForegroundColor Cyan
Write-Host "---------------------------"

# 1. Disable SysMain Service (Formerly Superfetch)
try {
    Write-Host "Disabling SysMain (Superfetch) service..." -NoNewline
    Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "SysMain" -StartupType Disabled
    Write-Host " [OK]" -ForegroundColor Green
}
catch {
    Write-Host " [Error]" -ForegroundColor Red
    Write-Host "Could not manage SysMain service. It may already be disabled or missing."
}

# 2. Disable Prefetch via Registry
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"

try {
    Write-Host "Disabling Prefetcher in Registry..." -NoNewline
    # Set EnablePrefetcher to 0 (Disabled)
    Set-ItemProperty -Path $regPath -Name "EnablePrefetcher" -Value 0 -ErrorAction Stop
    # Attempt to disable Superfetch key if it exists
    Set-ItemProperty -Path $regPath -Name "EnableSuperfetch" -Value 0 -ErrorAction SilentlyContinue
    Write-Host " [OK]" -ForegroundColor Green
}
catch {
    Write-Host " [Error]" -ForegroundColor Red
    Write-Host "Could not access Registry key."
}

# 3. Calculate Space and Clean Up Files
$prefetchDir = "C:\Windows\Prefetch"
Write-Host "Cleaning Prefetch directory..."

if (Test-Path $prefetchDir) {
    # Calculate size of files before deletion
    $files = Get-ChildItem -Path $prefetchDir -Force -ErrorAction SilentlyContinue
    
    if ($files) {
        $measure = $files | Measure-Object -Property Length -Sum
        $sizeBytes = $measure.Sum
        $sizeMB = [math]::Round($sizeBytes / 1MB, 2)

        # Remove the files
        Remove-Item -Path "$prefetchDir\*" -Force -Recurse -ErrorAction SilentlyContinue

        Write-Host "---------------------------"
        Write-Host "Success! Prefetch and SysMain have been disabled." -ForegroundColor Green
        Write-Host "Total disk space freed: $sizeMB MB" -ForegroundColor Yellow
    }
    else {
        Write-Host "Prefetch folder was already empty." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Prefetch directory not found." -ForegroundColor Red
}

Write-Host "---------------------------"
Write-Host "Press any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")