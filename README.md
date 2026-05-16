# Sunshine VDD Helper

Sunshine VDD Helper installs and configures a virtual display workflow for Sunshine + Moonlight on Windows.

It is designed for any Windows PC, not one specific computer. The installer detects the virtual display ID from Sunshine logs at install time and writes the correct `output_name` automatically.

## What It Does

- Installs MikeTheTech Virtual Display Driver.
- Installs NirSoft MultiMonitorTool for command-line monitor switching.
- Configures Sunshine to stream from the virtual display.
- Saves the user's full physical monitor layout when a stream starts.
- Restores the physical monitor layout after the stream ends.
- Supports multiple physical monitors by restoring the saved MultiMonitorTool layout, not by hardcoding one monitor.
- Creates startup tasks so the integration repairs itself after reboot.

## Requirements

- Windows 10 or Windows 11.
- Sunshine installed in the default path: `C:\Program Files\Sunshine`.
- Administrator rights.
- Internet access during installation.
- Moonlight client paired with Sunshine.

## Quick Install

1. Download the latest `SunshineVddHelper.zip` from Releases.
2. Extract the zip.
3. Right-click `Install.bat` and choose `Run as administrator`.
4. Accept the UAC prompts.
5. Reboot once if Sunshine does not show the virtual display immediately.
6. Start a stream from Moonlight.

## Custom Resolution

Default stream mode is `1920x1080 @ 60Hz`.

To install with a different mode, run PowerShell as administrator from the extracted folder:

```powershell
.\scripts\Install-SunshineVddHelper.ps1 -Resolution 2560x1440 -RefreshRate 60
```

## Multi-Monitor Behavior

When a Moonlight stream starts:

- The current monitor layout is saved to `physical-layout.cfg`.
- Sunshine switches the stream target to the virtual display.
- The virtual display becomes the primary display for the stream.

When the stream stops:

- The background watcher sees that no stream is active.
- It restores the saved monitor layout.
- It moves windows back to an active physical monitor.
- It disables the virtual display.

This is intended to work with one physical monitor or multiple physical monitors.

## Files Installed

By default files are installed to:

```text
C:\Program Files\SunshineVddHelper
```

The Virtual Display Driver settings file is written to:

```text
C:\VirtualDisplayDriver\vdd_settings.xml
```

Startup tasks created:

```text
SunshineVddHelperInit
SunshineVddHelperLocalDisplayWatch
```

## Uninstall

Run as administrator:

```text
Uninstall.bat
```

This removes the Sunshine integration and scheduled tasks. It leaves the Virtual Display Driver installed so Windows display state is not unexpectedly changed. Remove the driver manually from Device Manager if you want it fully gone.

## Notes

- This project downloads third-party tools from their official sources during installation.
- Virtual Display Driver is provided by VirtualDrivers/MikeTheTech.
- MultiMonitorTool is provided by NirSoft.
- If your PC gets a black screen after GPU driver changes, boot Safe Mode and remove the virtual display driver from Device Manager.
