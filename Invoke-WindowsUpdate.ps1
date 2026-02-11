#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Forces Windows Update to check for, download, and install updates, then reboots if necessary.
.DESCRIPTION
    This script automates the Windows Update process on Windows 11.
    It will:
    1. Ensure the NuGet package provider is available.
    2. Install the PSWindowsUpdate module if it's not already installed.
    3. Import the PSWindowsUpdate module.
    4. Check for available Windows updates from Microsoft Update.
    5. Download and install all accepted updates.
    6. Automatically reboot the computer if any installed updates require a restart.
.NOTES
    Version: 1.0

    Creation Date: 2025-05-10
    Requires: Windows 11, PowerShell 5.1 or higher, Internet Connection.
    Must be run with Administrator privileges.
#>

# --- Script Start ---

Write-Host "Starting Windows Update and Reboot script..." -ForegroundColor Yellow

# Set Execution Policy for the current process to ensure the script can run
# This does not persistently change the system's execution policy.
Try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
    Write-Host "Execution policy for the current process set to Bypass." -ForegroundColor Green
}
Catch {
    Write-Error "Failed to set execution policy for the current process. Ensure you are running as Administrator. Error: $($_.Exception.Message)"
    Exit 1
}

# Install NuGet package provider if it's not already installed (required for PSWindowsUpdate)
Write-Host "Checking for NuGet package provider..."
If (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "NuGet package provider not found. Installing..." -ForegroundColor Yellow
    Try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop
        Write-Host "NuGet package provider installed successfully." -ForegroundColor Green
    }
    Catch {
        Write-Error "Failed to install NuGet package provider. Error: $($_.Exception.Message)"
        Exit 1
    }
}
Else {
    Write-Host "NuGet package provider is already installed." -ForegroundColor Green
}

# Install PSWindowsUpdate module if it's not already installed
Write-Host "Checking for PSWindowsUpdate module..."
If (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "PSWindowsUpdate module not found. Installing..." -ForegroundColor Yellow
    Try {
        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -Scope AllUsers -ErrorAction Stop
        Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green
    }
    Catch {
        Write-Error "Failed to install PSWindowsUpdate module. Error: $($_.Exception.Message)"
        Write-Warning "Please ensure PowerShell can access the PowerShell Gallery (psgallery.com)."
        Exit 1
    }
}
Else {
    Write-Host "PSWindowsUpdate module is already installed." -ForegroundColor Green
}

# Import the PSWindowsUpdate module
Write-Host "Importing PSWindowsUpdate module..."
Try {
    Import-Module PSWindowsUpdate -ErrorAction Stop
    Write-Host "PSWindowsUpdate module imported successfully." -ForegroundColor Green
}
Catch {
    Write-Error "Failed to import PSWindowsUpdate module. Error: $($_.Exception.Message)"
    Exit 1
}

# Check for updates, download, install, and automatically reboot if required
Write-Host "Checking for, downloading, and installing Windows Updates..." -ForegroundColor Yellow
Write-Host "This process may take a significant amount of time and will automatically reboot if necessary."
Try {
    Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -AutoReboot -Verbose -ErrorAction Stop
    # Alternative command: Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose -ErrorAction Stop
    Write-Host "Windows Update check, download, and installation process initiated." -ForegroundColor Green
    Write-Host "If updates were installed that require a reboot, the system will restart automatically."
}
Catch {
    Write-Error "An error occurred during the Windows Update process. Error: $($_.Exception.Message)"
    # Check if a reboot is pending despite an error during the full process
    If (Get-WURebootStatus -Silent) {
        Write-Warning "A reboot is pending from a partially completed update process. Initiating reboot."
        Restart-Computer -Force
    }
    Else {
        Write-Host "No reboot is currently pending according to Get-WURebootStatus."
    }
    Exit 1
}

# Final check for pending reboot (often handled by -AutoReboot, but as a safeguard)
Write-Host "Verifying reboot status..."
If (Get-WURebootStatus -Silent) {
    Write-Host "Updates have been installed and a reboot is pending. Restarting computer in 60 seconds..." -ForegroundColor Yellow
    Restart-Computer -Force -Timeout 60
}
Else {
    Write-Host "No reboot required by Windows Updates at this time, or the -AutoReboot parameter has already handled it." -ForegroundColor Green
}

Write-Host "Windows Update and Reboot script finished." -ForegroundColor Yellow
# --- Script End ---