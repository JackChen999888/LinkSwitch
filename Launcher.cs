using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
class Launcher {
    [STAThread]
    static void Main() {
        try {
            string panel = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Panel.ps1");
            string shell = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
            Process.Start(new ProcessStartInfo(shell, "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + panel + "\"") {
                UseShellExecute = false, CreateNoWindow = true
            });
        } catch (Exception e) { MessageBox.Show(e.Message, "网络线路面板"); }
    }
}
