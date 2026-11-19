# LinkSwitch 网络线路面板

Windows 桌面工具。在网线保持插入时，选择用手机热点、其他 Wi-Fi 或以太网上网。

## 运行

从 [Releases](https://github.com/JackChen999888/LinkSwitch/releases/latest) 下载 **LinkSwitch-1.0.0-x64.msi**，双击安装，再从桌面或开始菜单打开 **LinkSwitch 网络线路面板**。适用于 x64 Windows。可在 Windows 设置的“已安装的应用”中卸载。需要 Windows PowerShell 5.1，切换网卡时 Windows 会请求管理员权限。

也可以下载源码，在项目目录直接启动面板：

~~~powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Panel.ps1
~~~

## 切换线路

点击 **使用 Wi-Fi 并断开网线** 或 **使用网线并断开 Wi-Fi**。面板先启用目标网卡，等待 Windows 报告可访问 Internet 并确认默认路由，再停用另一类物理网卡。交接期间两条线路可能短暂并存。请以面板显示的 **仅使用 Wi-Fi** 或 **仅使用网线** 为准。

面板约每三秒刷新一次。停用状态在关闭面板后仍可保留。再次打开面板即可切回，也可在 Windows 设备管理器的“网络适配器”中手动启用网卡。切换可能中断原线路上的连接；远程操作时请留意这一点。

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
