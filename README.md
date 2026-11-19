# LinkSwitch 网络线路面板

简体中文 · [English](README.en.md)

网线可以一直插着。LinkSwitch 让你在以太网和 Wi-Fi（包括手机热点）之间切换。切换成功后，Windows 会停用另一类物理网卡。即使两条线路都在同一台路由器上，也能明确选用其中一条。

## 安装

1. 在 x64 Windows 上下载 [LinkSwitch 1.0.0 安装包](https://github.com/JackChen999888/LinkSwitch/releases/download/v1.0.0/LinkSwitch-1.0.0-x64.msi)。
2. 双击 MSI，按 Windows 提示完成安装。
3. 从桌面或开始菜单打开 **LinkSwitch 网络线路面板**。程序使用 Windows PowerShell 5.1，切换网卡时需要管理员权限。

## 第一次切换

| 想做什么 | 怎么操作 | 如何确认成功 |
| --- | --- | --- |
| 网线插着，改用手机流量 | 打开手机热点，点击 **使用 Wi-Fi 并断开网线**。如果弹出 Windows 无线网络列表，选中手机热点并连接。 | 顶部显示 **仅使用 Wi-Fi**，有线网卡显示 **已停用**。 |
| 从热点切回网线 | 确认网线已插好，点击 **使用网线并断开 Wi-Fi**。 | 顶部显示 **仅使用网线**，无线网卡显示 **已停用**。 |
| 更换热点 | 在 **仅使用 Wi-Fi** 模式下点击 **更换 Wi-Fi 热点…**，在 Windows 列表中选择网络。 | 有线网卡保持停用。可在 Windows 的 Wi-Fi 列表中核对热点名称。 |

面板约每三秒刷新一次。切换时会先确认目标线路有默认路由，且 Windows 报告可访问 Internet，再停用另一类网卡。因此交接期间可能短暂显示两条线路都已连接。切换可能中断依赖原线路的远程会话。

## 遇到问题时

- **两条线路都显示已连接**：点击要使用的线路，等待顶部出现对应的“仅使用”状态。只在 Windows 网络列表里连上热点，仍可能保留有线连接。
- **超时或切换失败**：检查网线、热点密码，以及目标网络是否需要网页登录。若在断开原线路后验证失败，面板会尝试恢复原线路并报告结果。
- **关闭面板后找不到 Wi-Fi 或网线**：网卡停用状态可以持续到面板关闭以后。重新打开面板切回，或在 Windows **设备管理器 → 网络适配器** 中右键对应设备，选择 **启用设备**。
- **卸载**：如果希望两张网卡都可用，先在设备管理器中启用它们，然后打开 Windows **设置 → 应用**，找到 LinkSwitch 并卸载。

## 从源码运行

在项目目录打开 Windows PowerShell：

~~~powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Panel.ps1
~~~

## 开发与测试

核心逻辑在 Network.ps1，界面在 Panel.ps1，Wlan.cs 通过 Windows WLAN API 读取当前连接配置名并支持失败回退。模拟测试可直接运行：

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Network.Tests.ps1
~~~

在 64 位 Windows PowerShell 中重新编译可选的桌面启动器：

~~~powershell
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /win32icon:LinkSwitch.ico /out:网络线路面板.exe Launcher.cs
~~~

[MIT License](LICENSE)
