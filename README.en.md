# LinkSwitch for Windows

[简体中文](README.md) · English

Keep your Ethernet cable plugged in and switch between wired Internet and Wi-Fi, including a phone hotspot. After a successful switch, Windows disables the other type of physical adapter. The desktop panel uses Chinese labels. The guide below includes the exact text to look for.

## Install

1. On x64 Windows, download the [LinkSwitch 1.0.1 MSI installer](https://github.com/JackChen999888/LinkSwitch/releases/download/v1.0.1/LinkSwitch-1.0.1-x64.msi).
2. Double-click the MSI and follow the Windows installation prompts.
3. Open **LinkSwitch 网络线路面板** from the desktop or Start menu. The app uses Windows PowerShell 5.1. Windows requests administrator permission when you switch adapters.

## Make your first switch

| Goal | What to do | How to confirm |
| --- | --- | --- |
| Use a phone hotspot while Ethernet is plugged in | Turn on the hotspot and click **使用 Wi-Fi 并断开网线**. If the Windows network picker opens, select the hotspot and connect. | The panel shows **仅使用 Wi-Fi** (Wi-Fi only). Ethernet shows **已停用** (disabled). |
| Switch back to Ethernet | Check that the cable is plugged in and click **使用网线并断开 Wi-Fi**. | The panel shows **仅使用网线** (Ethernet only). Wi-Fi shows **已停用** (disabled). |
| Choose another hotspot | In Wi-Fi-only mode, click **更换 Wi-Fi 热点…** and select a network in Windows. | Ethernet stays disabled. Check the Wi-Fi menu in Windows for the connected network name. |

Status refreshes about every three seconds. The panel waits for a default route and for Windows to report Internet access on the selected adapter before disabling the other adapter type. Both links may appear connected briefly during the handover. Switching can interrupt remote sessions on the old connection.

## Troubleshooting and removal

- **Both adapters show connected.** Choose a connection in LinkSwitch and wait for the Wi-Fi-only or Ethernet-only status. Joining a hotspot through Windows alone can leave Ethernet connected.
- **The switch times out or fails.** Check the cable, hotspot password and any network sign-in page. If verification fails after the previous connection was interrupted, LinkSwitch attempts to restore it and reports the outcome.
- **An adapter is missing after closing the panel.** A disabled adapter can stay disabled after the app closes. Reopen LinkSwitch and switch back, or open **Device Manager → Network adapters**, right-click the device and select **Enable device**.
- **Uninstall.** To leave both adapters available, enable them in Device Manager first. Then open **Windows Settings → Apps**, find LinkSwitch and uninstall it.

## Run from source

Open Windows PowerShell in the project directory:

~~~powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Panel.ps1
~~~

## Development and tests

Network.ps1 handles switching, Panel.ps1 implements the interface, and Wlan.cs uses the Windows WLAN API for connection profile lookup and recovery. Run the simulated regression tests with:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Network.Tests.ps1
~~~

To rebuild the optional launcher, run this in 64-bit Windows PowerShell:

~~~powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /win32icon:LinkSwitch.ico /out:网络线路面板.exe Launcher.cs
~~~

[MIT License](LICENSE)
