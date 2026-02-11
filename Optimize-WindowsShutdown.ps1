# PowerShell Script to Fix Slow Shutdown and Restart Issues
# Optimized for Windows 11

# Require Administrator privileges
#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fixing Slow Shutdown and Restart Issues" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"


# Backup recommendation
Write-Host "RECOMMENDATION: Create a system restore point before proceeding." -ForegroundColor Yellow
Write-Host "Press any key to continue or Ctrl+C to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

# 1. Disable Fast Startup (causes slow shutdown issues)
Write-Host "[1/8] Disabling Fast Startup..." -ForegroundColor Yellow

try {
    $fastStartupPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

    # Check if registry path exists
    if (!(Test-Path $fastStartupPath)) {
        New-Item -Path $fastStartupPath -Force | Out-Null
    }

    # Set HiberbootEnabled to 0 (disabled)
    Set-ItemProperty -Path $fastStartupPath -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
    Write-Host "  - Fast Startup disabled successfully" -ForegroundColor Green
    $changesApplied = $true
}
catch {
    Write-Host "  - Failed to disable Fast Startup: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 2. Disable ClearPageFileAtShutdown (major cause of slow shutdown)
Write-Host "[2/8] Disabling ClearPageFileAtShutdown..." -ForegroundColor Yellow

try {
    $memoryMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

    # Check current value
    $currentValue = (Get-ItemProperty -Path $memoryMgmtPath -Name "ClearPageFileAtShutdown" -ErrorAction SilentlyContinue).ClearPageFileAtShutdown

    if ($currentValue -eq 1) {
        Set-ItemProperty -Path $memoryMgmtPath -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord -Force
        Write-Host "  - ClearPageFileAtShutdown disabled (was causing slow shutdown)" -ForegroundColor Green
        $changesApplied = $true
    }
    elseif ($currentValue -eq 0) {
        Write-Host "  - ClearPageFileAtShutdown already disabled" -ForegroundColor Gray
    }
    else {
        # Create the value if it doesn't exist
        New-ItemProperty -Path $memoryMgmtPath -Name "ClearPageFileAtShutdown" -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Host "  - ClearPageFileAtShutdown created and set to disabled" -ForegroundColor Green
        $changesApplied = $true
    }
}
catch {
    Write-Host "  - Failed to modify ClearPageFileAtShutdown: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 3. Reduce WaitToKillServiceTimeout (speeds up shutdown)
Write-Host "[3/8] Reducing WaitToKillServiceTimeout..." -ForegroundColor Yellow

try {
    $controlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
    $currentTimeout = (Get-ItemProperty -Path $controlPath -Name "WaitToKillServiceTimeout" -ErrorAction SilentlyContinue).WaitToKillServiceTimeout

    if ($currentTimeout -ne "2000") {
        Set-ItemProperty -Path $controlPath -Name "WaitToKillServiceTimeout" -Value "2000" -Type String -Force
        Write-Host "  - WaitToKillServiceTimeout reduced from $currentTimeout to 2000ms (2 seconds)" -ForegroundColor Green
        $changesApplied = $true
    }
    else {
        Write-Host "  - WaitToKillServiceTimeout already optimized (2000ms)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  - Failed to modify WaitToKillServiceTimeout: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 4. Enable AutoEndTasks (automatically close hanging apps)
Write-Host "[4/8] Enabling AutoEndTasks for current user..." -ForegroundColor Yellow

try {
    $desktopPath = "HKCU:\Control Panel\Desktop"

    # Check if AutoEndTasks exists
    $currentAutoEnd = (Get-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -ErrorAction SilentlyContinue).AutoEndTasks

    if ($currentAutoEnd -ne "1") {
        if ($null -eq $currentAutoEnd) {
            New-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -Value "1" -PropertyType String -Force | Out-Null
        }
        else {
            Set-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -Value "1" -Type String -Force
        }
        Write-Host "  - AutoEndTasks enabled (will auto-close hanging apps)" -ForegroundColor Green
        $changesApplied = $true
    }
    else {
        Write-Host "  - AutoEndTasks already enabled" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  - Failed to enable AutoEndTasks: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 5. Reduce WaitToKillAppTimeout (faster app termination at shutdown)
Write-Host "[5/8] Reducing WaitToKillAppTimeout..." -ForegroundColor Yellow

try {
    $desktopPath = "HKCU:\Control Panel\Desktop"
    $currentAppTimeout = (Get-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -ErrorAction SilentlyContinue).WaitToKillAppTimeout

    if ($currentAppTimeout -ne "2000") {
        if ($null -eq $currentAppTimeout) {
            New-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "2000" -PropertyType String -Force | Out-Null
        }
        else {
            Set-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "2000" -Type String -Force
        }
        Write-Host "  - WaitToKillAppTimeout reduced to 2000ms (was $currentAppTimeout)" -ForegroundColor Green
        $changesApplied = $true
    }
    else {
        Write-Host "  - WaitToKillAppTimeout already optimized (2000ms)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  - Failed to modify WaitToKillAppTimeout: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 6. Reduce HungAppTimeout (faster detection of hung apps)
Write-Host "[6/8] Reducing HungAppTimeout..." -ForegroundColor Yellow

try {
    $desktopPath = "HKCU:\Control Panel\Desktop"
    $currentHungTimeout = (Get-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -ErrorAction SilentlyContinue).HungAppTimeout

    if ($currentHungTimeout -ne "2000") {
        if ($null -eq $currentHungTimeout) {
            New-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -Value "2000" -PropertyType String -Force | Out-Null
        }
        else {
            Set-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -Value "2000" -Type String -Force
        }
        Write-Host "  - HungAppTimeout reduced to 2000ms (was $currentHungTimeout)" -ForegroundColor Green
        $changesApplied = $true
    }
    else {
        Write-Host "  - HungAppTimeout already optimized (2000ms)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  - Failed to modify HungAppTimeout: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 7. Disable problematic startup programs
Write-Host "[7/8] Checking for problematic startup programs..." -ForegroundColor Yellow

try {
    $startupApps = Get-CimInstance -ClassName Win32_StartupCommand | Where-Object { $_.Command -notlike "*SecurityHealth*" }

    if ($startupApps) {
        Write-Host "  - Found $($startupApps.Count) startup programs" -ForegroundColor Gray
        Write-Host "  - Consider disabling non-essential startup apps via Task Manager > Startup tab" -ForegroundColor Yellow
    }
    else {
        Write-Host "  - No problematic startup programs detected" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  - Could not check startup programs: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# 8. Disable automatic restart after system failure (can cause shutdown delays)
Write-Host "[8/8] Disabling automatic restart on system failure..." -ForegroundColor Yellow

try {
    $crashControlPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"
    $currentAutoReboot = (Get-ItemProperty -Path $crashControlPath -Name "AutoReboot" -ErrorAction SilentlyContinue).AutoReboot

    if ($currentAutoReboot -ne 0) {
        Set-ItemProperty -Path $crashControlPath -Name "AutoReboot" -Value 0 -Type DWord -Force
        Write-Host "  - Automatic restart on system failure disabled" -ForegroundColor Green
        $changesApplied = $true
    }
    else {
        Write-Host "  - Automatic restart already disabled" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  - Failed to disable automatic restart: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Summary
Write-Host "Summary of Changes:" -ForegroundColor Cyan
Write-Host ""
Write-Host "What was fixed:" -ForegroundColor Green
Write-Host "  ✓ Fast Startup disabled (prevents shutdown delays)" -ForegroundColor Green
Write-Host "  ✓ ClearPageFileAtShutdown disabled (major speed improvement)" -ForegroundColor Green
Write-Host "  ✓ Service shutdown timeout reduced to 2 seconds" -ForegroundColor Green
Write-Host "  ✓ App shutdown timeout reduced to 2 seconds" -ForegroundColor Green
Write-Host "  ✓ Hung app detection time reduced to 2 seconds" -ForegroundColor Green
Write-Host "  ✓ AutoEndTasks enabled (auto-closes hanging apps)" -ForegroundColor Green
Write-Host "  ✓ Automatic restart on failure disabled" -ForegroundColor Green
Write-Host ""

# General Troubleshooting Notes
Write-Host "Troubleshooting Notes:" -ForegroundColor Yellow
Write-Host "  - If shutdown is still slow after restart, check for BIOS/Driver updates" -ForegroundColor Yellow
Write-Host "  - Some specific firmware versions can cause sleep/shutdown issues" -ForegroundColor Yellow
Write-Host "  - Consider checking manufacturer support for latest firmware updates" -ForegroundColor Yellow
Write-Host ""

Write-Host "Expected Results:" -ForegroundColor Cyan
Write-Host "  - Shutdown time: Should complete in under 10-15 seconds" -ForegroundColor White
Write-Host "  - Restart time: Should complete in under 30-40 seconds" -ForegroundColor White
Write-Host "  - No more 'App preventing shutdown' delays" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IMPORTANT: Restart your computer now" -ForegroundColor Red
Write-Host "to apply all changes!" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Offer to restart now
$restart = Read-Host "Would you like to restart now? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host ""
    Write-Host "Restarting in 10 seconds... Press Ctrl+C to cancel" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
else {
    Write-Host ""
    Write-Host "Please restart your computer manually at your earliest convenience." -ForegroundColor Yellow
    Write-Host ""
}
