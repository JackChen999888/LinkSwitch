using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class LinkSwitchWlan {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct Connection {
        public int mode;
        [MarshalAs(UnmanagedType.LPWStr)] public string profile;
        public IntPtr ssid;
        public IntPtr bssidList;
        public int bssType;
        public uint flags;
    }

    [DllImport("wlanapi.dll")] static extern uint WlanOpenHandle(uint version, IntPtr reserved, out uint actual, out IntPtr handle);
    [DllImport("wlanapi.dll")] static extern uint WlanCloseHandle(IntPtr handle, IntPtr reserved);
    [DllImport("wlanapi.dll")] static extern uint WlanQueryInterface(IntPtr h, ref Guid id, int opcode, IntPtr reserved, out uint size, out IntPtr data, out int type);
    [DllImport("wlanapi.dll")] static extern void WlanFreeMemory(IntPtr data);
    [DllImport("wlanapi.dll")] static extern uint WlanConnect(IntPtr h, ref Guid id, ref Connection parameters, IntPtr reserved);
    [DllImport("wlanapi.dll")] static extern uint WlanDisconnect(IntPtr h, ref Guid id, IntPtr reserved);

    static void Check(uint result) {
        if (result != 0) throw new Win32Exception((int)result);
    }
    static IntPtr Open() {
        uint version;
        IntPtr handle;
        Check(WlanOpenHandle(2, IntPtr.Zero, out version, out handle));
        return handle;
    }
    public static string Profile(Guid id) {
        IntPtr handle = Open(), data = IntPtr.Zero;
        try {
            uint size;
            int type;
            // wlan_intf_opcode_current_connection; WLAN_CONNECTION_ATTRIBUTES starts
            // with two 32-bit enums followed by WCHAR strProfileName[256].
            Check(WlanQueryInterface(handle, ref id, 7, IntPtr.Zero, out size, out data, out type));
            if (size < 520 || Marshal.ReadInt32(data) != 1) throw new InvalidOperationException("Wi-Fi 连接状态已变化，请重试。");
            string name = Marshal.PtrToStringUni(IntPtr.Add(data, 8), 256).TrimEnd('\0');
            if (String.IsNullOrEmpty(name)) throw new InvalidOperationException("无法确认用于恢复 Wi-Fi 的配置文件。");
            return name;
        } finally {
            if (data != IntPtr.Zero) WlanFreeMemory(data);
            WlanCloseHandle(handle, IntPtr.Zero);
        }
    }
    public static void Disconnect(Guid id) {
        IntPtr handle = Open();
        try { Check(WlanDisconnect(handle, ref id, IntPtr.Zero)); }
        finally { WlanCloseHandle(handle, IntPtr.Zero); }
    }
    public static void Connect(Guid id, string profile) {
        IntPtr handle = Open();
        try {
            var parameters = new Connection { mode = 0, profile = profile, bssType = 3 };
            Check(WlanConnect(handle, ref id, ref parameters, IntPtr.Zero));
        } finally { WlanCloseHandle(handle, IntPtr.Zero); }
    }
}
