# 🛠️ Windows 11 PowerShell Optimization & Maintenance Collection

A curated collection of professional PowerShell scripts designed to fix specific Windows 11 annoyances, optimize performance, and gather deep system diagnostics.

> **Why this collection?**
> Windows 11 defaults often favor battery life or "user-friendliness" over raw performance and reliability. This collection fixes common pain points like **network throttling**, **slow shutdowns**, **modern standby battery drain**, and **bloated event logs**, making your system faster and more predictable.

---

## ⚡ Quick Start

1.  **Download** the collection.
2.  Open **PowerShell as Administrator**.
3.  **Unblock** scripts (if needed):
    ```powershell
    Get-ChildItem -Recurse | Unblock-File
    ```
4.  **Run** a script:
    ```powershell
    .\Optimize-Network.ps1
    ```

---

## 📚 Script Deep Dive

### 🚀 Optimization Scripts

#### [Optimize-Network.ps1](Optimize-Network.ps1)
**The Problem:** High latency, lag spikes in games, or slow download speeds despite a fast internet connection. This is often caused by power-saving features in modern Intel/Realtek adapters and a specific bug in the Windows 11 TCP stack.
**The Fix:**
*   **Disables MIMO Power Save Mode**: Forces your Wi-Fi card to keep all antennas active, preventing signal drops during low traffic.
*   **Disables Packet Coalescing**: Stops the adapter from buffering packets to save CPU, which reduces latency.
*   **Disables Global RSC (Receive Segment Coalescing)**: Fixes a known bug where Windows tries to merge packets in software, causing massive throughput loss on some Wi-FI 6 chipsets.
*   **Enables Throughput Booster**: Optimizes the adapter for burst speeds.
**Usage**: `.\Optimize-Network.ps1` (Auto-detects adapters)

#### [Optimize-WindowsShutdown.ps1](Optimize-WindowsShutdown.ps1)
**The Problem:** Windows takes forever to shut down or restart, sometimes hanging on "Getting Windows ready" or just a black screen.
**The Fix:**
*   **Disables Fast Startup (Hiberboot)**: Fast Startup saves the kernel state to disk. Over time, this file gets corrupted, causing bugs and slow boots. Disabling it forces a fresh, clean Kernel boot every time (which is negligible on modern SSDs).
*   **Disables ClearPageFileAtShutdown**: A security feature that wipes the swap file on shutdown. If enabled effectively "bricks" shutdown speed. This script ensures it is OFF.
*   **Optimizes Timeouts**: Reduces the time Windows waits for hung services/apps from 5-10s down to **2s**.
*   **Enables AutoEndTasks**: Automatically kills apps that refuse to close, instead of asking you.
**Usage**: `.\Optimize-WindowsShutdown.ps1`

#### [Disable-WakeSources.ps1](Disable-WakeSources.ps1)
**The Problem:** You put your laptop in your bag, and it wakes up, heats up, and drains the battery. This is "Modern Standby" (S0) behaving badly.
**The Fix:**
*   **Nuclear Option**: Enumerates EVERY device allowed to wake the system (Mouse, Keyboard, Network Card) and **disables** their wake permission.
*   **Disables Wake Timers**: Prevents Windows Update or Maintenance tasks from waking the PC at 3 AM.
*   **Result**: The **only** thing that will wake your PC is physically pressing the Power Button.
**Usage**: `.\Disable-WakeSources.ps1` (Revert by using Device Manager if you need USB wake back).

#### [Disable-WindowsAutoRestart.ps1](Disable-WindowsAutoRestart.ps1)
**The Problem:** Windows Update forcing a restart while you have unsaved work.
**The Fix:**
*   **Sets Active Hours to Max**: Configures the "Active Hours" window to the maximum 18 hours allowed (e.g., 6 AM - 12 AM).
*   **Registry Tweaks**: Sets `NoAutoRebootWithLoggedOnUsers` to true, preventing forced restarts when a user session is active.
**Usage**: `.\Disable-WindowsAutoRestart.ps1`

#### [Disable-Prefetch.ps1](Disable-Prefetch.ps1)
**The Problem:** Frequent disk writes and background CPU usage by "SysMain" (Superfetch).
**The Fix:**
*   **Disables SysMain**: Stops the service that pre-loads apps into RAM. On modern fast NVMe SSDs, the performance gain from prefetching is negligible, but the background processing/indexing can cause micro-stutters.
**Usage**: `.\Disable-Prefetch.ps1`

#### [Disable-SearchIndex.ps1](Disable-SearchIndex.ps1)
**The Problem:** High disk usage and CPU spikes from "Windows Search Indexer", especially on larger drives.
**The Fix:**
*   **Stops & Disables WSearch**: Completely kills the indexing service.
*   **Clears Database**: Deletes the standard `windows.edb` file to reclaim disk space (often GBs in size).
**Note**: Windows Search will stop working for files. Use an alternative like "Everything" by voidtools.
**Usage**: `.\Disable-SearchIndex.ps1`

---

### 🔍 Diagnostics & Logging Scripts

#### [Export-EventLog.ps1](Export-EventLog.ps1) (Advanced)
**The Problem:** Windows Event Logs are messy XML/Text blobs that are hard to read and impossible to paste into ChatGPT/Claude for analysis due to formatting and size.
**The Solution:**
*   **AI-Ready**: Scrubs newlines, normalizes spaces, and formats logs into a clean CSV designed for **LLM Analysis**.
*   **Chunking**: Automatically splits large logs into 10MB chunks to fit upload limits.
*   **Sanitization**: Removes binary data and formatting noise.
*   **Usage Tip**: Upload the generated CSVs to an LLM to ask "Why did my PC crash yesterday?" or "Summarize critical errors".
**Usage**: `.\Export-EventLog.ps1 -DaysToExport 3`

#### [Export-EventLogQuick.ps1](Export-EventLogQuick.ps1)
**The Description**: A lightweight, faster version of the advanced Event Log exporter.
**Use Case**: When you just want a quick 7-day snapshot of Errors and Warnings without the advanced configuration or chunking features of the main script.
**Usage**: `.\Export-EventLogQuick.ps1`

#### [Get-SystemHardwareInfo.ps1](Get-SystemHardwareInfo.ps1)
**The Description**: Uses low-level CIM/WMI queries to grab hardware details often hidden in Settings.
**LLM Compatibility**: Exports to a structured **JSON** file that AI models can perfectly parse. You can upload this file to an Agent and ask "Is my RAM running at full speed?" or "Do I have the latest driver for my GPU?".
**Data Points**:
*   **RAM**: Manufacturer, Speed, Voltage, Part Numbers.
*   **GPU**: Driver Date, Version, VRAM.
*   **Storage**: Partition style, Health status.
*   **Drivers**: List of all signed drivers using `Get-CimInstance Win32_PnPSignedDriver`.
**Usage**: `.\Get-SystemHardwareInfo.ps1`

#### [Get-SoftwareInventory.ps1](Get-SoftwareInventory.ps1)
**The Description**: Generates a complete inventory of every app installed on your machine.
**LLM Compatibility**: Exports to a clean **JSON** format. Upload this to an AI to identify bloatware, find outdated software, or compare installed apps between two machines.
**Features**:
*   Combines **Win32 Apps** (Control Panel) and **Modern Store Apps** (Appx) into one list.
*   Captures Version, Publisher, and Install Date.
**Usage**: `.\Get-SoftwareInventory.ps1`

#### [Measure-SystemIdle.ps1](Measure-SystemIdle.ps1)
**The Problem:** Your PC fans spin up when you are doing nothing, but by the time you open Task Manager, the culprit is gone.
**The Solution**:
*   **30-Minute Monitor**: Runs in the background and logs the "Top 10 CPU Consumers" every minute to a CSV.
*   **Event Correlation**: Exports error logs covering the exact same timeframe.
*   **Usage**: Run this, leave your PC idle for 30 mins, then upload the CSVs to an LLM to find the phantom process.
**Usage**: `.\Measure-SystemIdle.ps1`

#### [Get-NetworkDiagnostic.ps1](Get-NetworkDiagnostic.ps1)
**The Description**: A comprehensive network dumper for troubleshooting connectivity issues.
**Features**:
*   **RSC Status**: Checks if Receive Segment Coalescing is enabled (a common cause of Wi-Fi slowness).
*   **Driver Details**: Lists exact driver versions and dates for all physical adapters.
*   **Advanced Properties**: Dumps all hidden driver settings (Roaming Aggressiveness, Offloading, etc.).
**Usage**: `.\Get-NetworkDiagnostic.ps1`

---

### 🔧 Maintenance & Repair

#### [Clear-MicrosoftStoreCache.ps1](Clear-MicrosoftStoreCache.ps1)
**The Problem:** Microsoft Store apps stuck on "Pending" or "Downloading".
**The Fix:**
*   Stops `wuauserv`, `bits`, `cryptsvc` and the store install service.
*   Nuclear deletes the `SoftwareDistribution` and `AppRepository` cache folders.
*   Restarts services.
**Usage**: `.\Clear-MicrosoftStoreCache.ps1`

#### [Invoke-WindowsUpdate.ps1](Invoke-WindowsUpdate.ps1)
**The Solution**: A "Brute Force" update. Loads the `PSWindowsUpdate` module (installs it if missing) and forces a check/install cycle, bypassing the UI. Excellent for fresh installs or when the Settings app is broken.
**Usage**: `.\Invoke-WindowsUpdate.ps1`

---

## ⚠️ Disclaimer

These scripts modify system configurations (Registry, Services, Power Settings).
*   **Backup**: Always create a **System Restore Point** before applying optimization scripts.
*   **Review**: Read the code. It is commented thoroughly.
*   **Liability**: Use at your own risk. The author is not responsible for any system instability.

---


**License**: MIT
