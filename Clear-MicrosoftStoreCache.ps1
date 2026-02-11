#Requires -RunAsAdministrator
# Stop Store services
Stop-Service -Name "InstallService" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "ClipSVC" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "AppXSvc" -Force -ErrorAction SilentlyContinue

# Clear Store cache
Remove-Item -Path "$env:ProgramData\Microsoft\Windows\AppRepository\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LocalAppData\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LocalAppData\Packages\*Store*\LocalState\*" -Recurse -Force -ErrorAction SilentlyContinue

# Restart services
Start-Service -Name "AppXSvc" -ErrorAction SilentlyContinue
Start-Service -Name "ClipSVC" -ErrorAction SilentlyContinue
Start-Service -Name "InstallService" -ErrorAction SilentlyContinue

Write-Host "Store cache cleared. Restart your computer."
