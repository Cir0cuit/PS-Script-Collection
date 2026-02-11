# PowerShell Script to Disable Windows 11 Automatic Restarts
# Run this script as Administrator

#Requires -RunAsAdministrator

Write-Host "Configuring Windows 11 to prevent automatic restarts..." -ForegroundColor Green

# Method 1: Set Registry Keys to Disable Auto-Restart
Write-Host "Setting registry keys to disable automatic restart..." -ForegroundColor Yellow

# Create the registry path if it doesn't exist
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
    Write-Host "Created registry path: $registryPath" -ForegroundColor Green
}

# Set NoAutoRebootWithLoggedOnUsers to prevent restart when users are logged on
Set-ItemProperty -Path $registryPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord -Force
Write-Host "Set NoAutoRebootWithLoggedOnUsers to 1" -ForegroundColor Green

# Set AUOptions to 4 (Auto download and schedule install) - required for NoAutoRebootWithLoggedOnUsers to work
Set-ItemProperty -Path $registryPath -Name "AUOptions" -Value 4 -Type DWord -Force
Write-Host "Set AUOptions to 4" -ForegroundColor Green

# Method 2: Configure Active Hours to Maximum (18 hours)
Write-Host "Setting Active Hours to maximum duration..." -ForegroundColor Yellow

$activeHoursPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
if (-not (Test-Path $activeHoursPath)) {
    New-Item -Path $activeHoursPath -Force | Out-Null
    Write-Host "Created registry path: $activeHoursPath" -ForegroundColor Green
}

# Set Active Hours from 6 AM to 12 AM (midnight) - 18 hours maximum
$startHour = 6
$endHour = 0  # 0 represents midnight (24:00)

Set-ItemProperty -Path $activeHoursPath -Name "ActiveHoursStart" -Value $startHour -Type DWord -Force
Set-ItemProperty -Path $activeHoursPath -Name "ActiveHoursEnd" -Value $endHour -Type DWord -Force
Write-Host "Set Active Hours from $startHour AM to 12 AM (18 hours maximum)" -ForegroundColor Green

# Method 3: Disable Automatic Maintenance
Write-Host "Disabling automatic maintenance..." -ForegroundColor Yellow

$maintenancePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
if (-not (Test-Path $maintenancePath)) {
    New-Item -Path $maintenancePath -Force | Out-Null
}

# Disable automatic maintenance
Set-ItemProperty -Path $maintenancePath -Name "MaintenanceDisabled" -Value 1 -Type DWord -Force
Write-Host "Disabled automatic maintenance" -ForegroundColor Green

# Method 4: Configure Windows Update Notification Settings
Write-Host "Configuring Windows Update notifications..." -ForegroundColor Yellow

$updateSettingsPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
# Enable restart notifications
Set-ItemProperty -Path $updateSettingsPath -Name "RestartNotificationsAllowed2" -Value 1 -Type DWord -Force
Write-Host "Enabled restart notifications" -ForegroundColor Green

# Method 5: Create a scheduled task to maintain active hours dynamically (Optional)
Write-Host "Creating scheduled task to maintain active hours..." -ForegroundColor Yellow

$taskName = "MaintainActiveHours"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed existing scheduled task" -ForegroundColor Yellow
}

# Create a script that will run every hour to maintain active hours
$scriptContent = @"
# Script to maintain active hours
`$currentHour = (Get-Date).Hour
`$startHour = (`$currentHour + 1) % 24
`$endHour = (`$currentHour + 19) % 24

`$registryPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
Set-ItemProperty -Path `$registryPath -Name "ActiveHoursStart" -Value `$startHour -Type DWord -Force
Set-ItemProperty -Path `$registryPath -Name "ActiveHoursEnd" -Value `$endHour -Type DWord -Force
"@

$scriptPath = "$env:TEMP\MaintainActiveHours.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8

# Create the scheduled task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Maintains active hours to prevent automatic restarts"
Write-Host "Created scheduled task to maintain active hours" -ForegroundColor Green

# Summary
Write-Host "`n=== Configuration Complete ===" -ForegroundColor Cyan
Write-Host "The following changes have been made:" -ForegroundColor White
Write-Host "1. Disabled automatic restart when users are logged on" -ForegroundColor White
Write-Host "2. Set Active Hours to maximum 18-hour window" -ForegroundColor White
Write-Host "3. Disabled automatic maintenance" -ForegroundColor White
Write-Host "4. Enabled restart notifications" -ForegroundColor White
Write-Host "5. Created scheduled task to maintain active hours" -ForegroundColor White
Write-Host "`nWindows will now:" -ForegroundColor Yellow
Write-Host "- NOT restart automatically after updates" -ForegroundColor Green
Write-Host "- Notify you when a restart is needed" -ForegroundColor Green
Write-Host "- Only restart when YOU choose to restart" -ForegroundColor Green
Write-Host "`nNote: You should still restart periodically to apply security updates." -ForegroundColor Red
Write-Host "A system restart is recommended to ensure all changes take effect." -ForegroundColor Yellow

# Optional: Ask user if they want to restart now
$restart = Read-Host "`nWould you like to restart now to apply changes? (y/n)"
if ($restart -eq 'y' -or $restart -eq 'Y') {
    Write-Host "Restarting system in 10 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
