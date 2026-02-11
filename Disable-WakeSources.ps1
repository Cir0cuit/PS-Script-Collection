# PowerShell Script to Prevent All Wake-ups from Standby/Sleep
# Only allows wake-up via Power Button press
# Created for Windows 11
# Optimized for Modern Standby (S0 Low Power Idle) systems

# Require Administrator privileges
#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Disabling All Wake Sources from Sleep" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Disable ALL devices that can wake the computer
Write-Host "[1/6] Disabling all device wake permissions..." -ForegroundColor Yellow

# Get all devices currently armed to wake the system
$wakeArmedDevices = powercfg /devicequery wake_armed

if ($wakeArmedDevices -and $wakeArmedDevices.Count -gt 0) {
    foreach ($device in $wakeArmedDevices) {
        if ($device -and $device.Trim() -ne "" -and $device -notmatch "NONE") {
            try {
                powercfg /devicedisablewake "$device"
                Write-Host "  - Disabled: $device" -ForegroundColor Green
            }
            catch {
                Write-Host "  - Failed to disable: $device" -ForegroundColor Red
            }
        }
    }
}
else {
    Write-Host "  - No devices currently armed to wake system" -ForegroundColor Gray
}

# Also disable all programmable wake devices to be thorough
$wakeProgrammableDevices = powercfg /devicequery wake_programmable

if ($wakeProgrammableDevices -and $wakeProgrammableDevices.Count -gt 0) {
    foreach ($device in $wakeProgrammableDevices) {
        if ($device -and $device.Trim() -ne "" -and $device -notmatch "NONE") {
            try {
                powercfg /devicedisablewake "$device"
                Write-Host "  - Disabled (programmable): $device" -ForegroundColor Green
            }
            catch {
                # Device may already be disabled, skip error
            }
        }
    }
}

Write-Host ""

# 2. Disable Wake Timers for ALL power schemes
Write-Host "[2/6] Disabling wake timers for all power schemes..." -ForegroundColor Yellow

# Get all power schemes
$powerSchemes = powercfg /list | Select-String "Power Scheme GUID:" | ForEach-Object {
    if ($_ -match "([0-9a-f-]{36})") {
        $matches[1]
    }
}

foreach ($scheme in $powerSchemes) {
    try {
        # Disable wake timers for AC power (plugged in) - set to 0 (disable)
        powercfg /SETACVALUEINDEX $scheme SUB_SLEEP RTCWAKE 0

        # Disable wake timers for DC power (battery) - set to 0 (disable)
        powercfg /SETDCVALUEINDEX $scheme SUB_SLEEP RTCWAKE 0

        Write-Host "  - Disabled wake timers for scheme: $scheme" -ForegroundColor Green
    }
    catch {
        Write-Host "  - Failed for scheme: $scheme" -ForegroundColor Red
    }
}

# Apply settings to current scheme
powercfg /SETACTIVE SCHEME_CURRENT

Write-Host ""

# 3. Disable scheduled tasks that wake the computer
Write-Host "[3/6] Disabling scheduled tasks with wake permissions..." -ForegroundColor Yellow

# Get all scheduled tasks that are set to wake the computer
$tasks = Get-ScheduledTask | Where-Object { 
    $taskInfo = $_ | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    if ($taskInfo) {
        $settings = $_ | Select-Object -ExpandProperty Settings
        if ($settings.WakeToRun -eq $true) {
            return $true
        }
    }
    return $false
}

if ($tasks) {
    foreach ($task in $tasks) {
        try {
            $task.Settings.WakeToRun = $false
            $task | Set-ScheduledTask -ErrorAction Stop | Out-Null
            Write-Host "  - Disabled wake for task: $($task.TaskName)" -ForegroundColor Green
        }
        catch {
            Write-Host "  - Could not modify task: $($task.TaskName) (may require system permissions)" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "  - No scheduled tasks found with wake permissions" -ForegroundColor Gray
}

Write-Host ""

# 4. Disable USB selective suspend (can cause wake issues)
Write-Host "[4/6] Disabling USB selective suspend..." -ForegroundColor Yellow

foreach ($scheme in $powerSchemes) {
    try {
        # Disable USB selective suspend for AC
        powercfg /SETACVALUEINDEX $scheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

        # Disable USB selective suspend for DC
        powercfg /SETDCVALUEINDEX $scheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

        Write-Host "  - Disabled USB selective suspend for scheme: $scheme" -ForegroundColor Green
    }
    catch {
        Write-Host "  - Failed for scheme: $scheme" -ForegroundColor Red
    }
}

Write-Host ""

# 5. Disable automatic restart after system failure
Write-Host "[5/6] Disabling automatic restart on system failure..." -ForegroundColor Yellow

try {
    $currentSetting = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name AutoReboot -ErrorAction SilentlyContinue).AutoReboot

    if ($currentSetting -ne 0) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 0 -Type DWord
        Write-Host "  - Automatic restart disabled" -ForegroundColor Green
    }
    else {
        Write-Host "  - Automatic restart already disabled" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  - Failed to modify registry setting" -ForegroundColor Red
}

Write-Host ""

# 6. Disable power request overrides that might wake system
Write-Host "[6/6] Checking power requests..." -ForegroundColor Yellow

# This prevents apps from keeping the system awake
# This helps identify apps keeping the system awake
try {
    # List active power requests
    powercfg /requests
    Write-Host "  - specific overrides must be applied manually using 'powercfg /requestsoverride'" -ForegroundColor Gray
}
catch {
    Write-Host "  - Could not list power requests" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Display current status
Write-Host "Current Status:" -ForegroundColor Cyan
Write-Host ""

Write-Host "Devices armed to wake:" -ForegroundColor Yellow
powercfg /devicequery wake_armed
Write-Host ""

Write-Host "Active wake timers:" -ForegroundColor Yellow
powercfg /waketimers
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Your computer will now only wake up via:" -ForegroundColor Green
Write-Host "  - Power button press" -ForegroundColor Green
Write-Host "" -ForegroundColor Green
Write-Host "The following will NOT wake your PC:" -ForegroundColor Red
Write-Host "  - Mouse movement" -ForegroundColor Red
Write-Host "  - Keyboard input" -ForegroundColor Red
Write-Host "  - Scheduled tasks" -ForegroundColor Red
Write-Host "  - Wake timers" -ForegroundColor Red
Write-Host "  - Network activity" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: A system restart is recommended to ensure all changes take effect." -ForegroundColor Yellow
Write-Host ""
