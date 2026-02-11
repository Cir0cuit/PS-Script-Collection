<#
.SYNOPSIS
Generates a comprehensive list of installed software (Win32 + Store Apps) 
and exports it to a JSON file formatted for LLM analysis.
#>

$ErrorActionPreference = "SilentlyContinue"
$ReportPath = "$env:USERPROFILE\Desktop\Software_Inventory.json"

Write-Host "Gathering software inventory... This may take a moment." -ForegroundColor Cyan

# --- List 1: Classic Desktop Apps (via Registry) ---
# We look in 3 locations: System 64-bit, System 32-bit, and User-specific installs
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$Win32Apps = $RegistryPaths | ForEach-Object {
    Get-ItemProperty $_ | Select-Object @{N='Name';E={$_.DisplayName}},
                                        @{N='Version';E={$_.DisplayVersion}},
                                        @{N='Publisher';E={$_.Publisher}},
                                        @{N='InstallDate';E={$_.InstallDate}},
                                        @{N='Type';E={'Win32_Desktop'}}
} | Where-Object { ![string]::IsNullOrWhiteSpace($_.Name) }

# --- List 2: Modern Store Apps (via Appx) ---
$StoreApps = Get-AppxPackage | Select-Object @{N='Name';E={$_.Name}},
                                             @{N='Version';E={$_.Version}},
                                             @{N='Publisher';E={$_.Publisher}},
                                             @{N='InstallDate';E={$_.InstalledDate}}, # Note: May be null on some systems
                                             @{N='Type';E={'Windows_Store_App'}}

# --- Combine and Clean ---
$FullInventory = $Win32Apps + $StoreApps

# Sort by name for easier human verification if needed
$FullInventory = $FullInventory | Sort-Object Name | Select-Object * -Unique

# --- Export to LLM-Readable JSON ---
# Depth 2 ensures nested objects are expanded if present
$FullInventory | ConvertTo-Json -Depth 2 | Set-Content -Path $ReportPath -Encoding UTF8

Write-Host "------------------------------------------------" -ForegroundColor Green
Write-Host "Success! Inventory saved to:" -ForegroundColor White
Write-Host $ReportPath -ForegroundColor Yellow
Write-Host "You can now upload this JSON file to an LLM for analysis." -ForegroundColor Gray
Write-Host "------------------------------------------------" -ForegroundColor Green
Start-Sleep -Seconds 5