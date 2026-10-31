#Requires -Version 5.1
<#
.SYNOPSIS
    Switch virtual desktop, then activate the last-used window there.
.DESCRIPTION
    The VirtualDesktop module's Switch-Desktop (MakeVisible in its C#)
    deliberately foregrounds Program Manager and then minimizes it "to give
    away focus", which leaves no window active on the new desktop. This
    wrapper calls Switch-Desktop, then walks the global Z-order from the top
    and activates the first real application window that is not cloaked
    (windows on other virtual desktops are DWM-cloaked). Z-order is kept per
    window across desktop switches, so the topmost window on a desktop is
    the one last used there - including a window just sent over with
    Move-ActiveWindow.

    The Win32 helper is compiled once into a cached DLL under
    %LOCALAPPDATA%\whkd_workflow so each hotkey press only loads it.
.PARAMETER Desktop
    Zero-based desktop index, as for Switch-Desktop.
.PARAMETER NoSwitch
    Skip the switch and only activate the topmost window on the current
    desktop (for testing).
#>
param(
    [Parameter(Position = 0)][int]$Desktop = 0,
    [switch]$NoSwitch
)

$source = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace WhkdWorkflow {
public static class DesktopFocus {
    [DllImport("user32.dll")] static extern IntPtr GetTopWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr pid);
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hWnd, int attr, out int val, int size);

    const uint GW_HWNDNEXT = 2, GW_OWNER = 4;
    const int GWL_EXSTYLE = -20;
    const int WS_EX_TOOLWINDOW = 0x80, WS_EX_NOACTIVATE = 0x08000000;
    const int DWMWA_CLOAKED = 14;

    static bool IsCandidate(IntPtr h) {
        if (!IsWindowVisible(h) || IsIconic(h)) return false;
        if (GetWindow(h, GW_OWNER) != IntPtr.Zero) return false;
        int ex = GetWindowLong(h, GWL_EXSTYLE);
        if ((ex & (WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE)) != 0) return false;
        if (GetWindowTextLength(h) == 0) return false;
        int cloaked;
        if (DwmGetWindowAttribute(h, DWMWA_CLOAKED, out cloaked, 4) == 0 && cloaked != 0) return false;
        var cls = new StringBuilder(256);
        GetClassName(h, cls, cls.Capacity);
        switch (cls.ToString()) {
            case "Progman": case "WorkerW": case "Shell_TrayWnd":
            case "Shell_SecondaryTrayWnd": case "Windows.UI.Core.CoreWindow":
                return false;
        }
        return true;
    }

    public static IntPtr FindTopWindow() {
        for (IntPtr h = GetTopWindow(IntPtr.Zero); h != IntPtr.Zero; h = GetWindow(h, GW_HWNDNEXT))
            if (IsCandidate(h)) return h;
        return IntPtr.Zero;
    }

    public static bool Activate(IntPtr h) {
        uint me = GetCurrentThreadId();
        IntPtr fg = GetForegroundWindow();
        uint fgThread = fg == IntPtr.Zero ? 0 : GetWindowThreadProcessId(fg, IntPtr.Zero);
        uint target = GetWindowThreadProcessId(h, IntPtr.Zero);
        bool a1 = fgThread != 0 && fgThread != me && AttachThreadInput(fgThread, me, true);
        bool a2 = target != 0 && target != me && AttachThreadInput(target, me, true);
        BringWindowToTop(h);
        bool ok = SetForegroundWindow(h);
        if (a2) AttachThreadInput(target, me, false);
        if (a1) AttachThreadInput(fgThread, me, false);
        return ok && GetForegroundWindow() == h;
    }
}
}
'@

# Compile once per source version; later runs just load the cached DLL.
if (-not ('WhkdWorkflow.DesktopFocus' -as [type])) {
    $cacheDir = Join-Path $env:LOCALAPPDATA 'whkd_workflow'
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($source))[0..5] | ForEach-Object { $_.ToString('x2') })
    $dll = Join-Path $cacheDir "DesktopFocus-$hash.dll"
    if (-not (Test-Path $dll)) {
        New-Item -ItemType Directory -Force $cacheDir | Out-Null
        Get-ChildItem $cacheDir -Filter 'DesktopFocus-*.dll' -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
        Add-Type -TypeDefinition $source -OutputAssembly $dll -OutputType Library
    }
    Add-Type -Path $dll
}

if (-not $NoSwitch) {
    Switch-Desktop -Desktop $Desktop
}

# Cloaking flips as the switch completes; retry briefly until a window
# on the new desktop shows up uncloaked (an empty desktop just times out).
for ($i = 0; $i -lt 10; $i++) {
    $hwnd = [WhkdWorkflow.DesktopFocus]::FindTopWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        if ([WhkdWorkflow.DesktopFocus]::Activate($hwnd)) { break }
    }
    Start-Sleep -Milliseconds 50
}
