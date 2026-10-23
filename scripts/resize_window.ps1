$ErrorActionPreference = 'Stop'

$Width = 960
$Height = 540
$Title = -join [char[]](0x771F, 0x679C, 0x9274)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class AppWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindowW(string className, string windowName);

    [DllImport("user32.dll")]
    public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);

    [DllImport("user32.dll")]
    public static extern uint GetDpiForWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern int GetWindowLongW(IntPtr hwnd, int index);

    [DllImport("user32.dll")]
    public static extern bool AdjustWindowRectExForDpi(ref RECT rect, int style, bool menu, int exStyle, uint dpi);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hwnd, int command);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);
}
'@

$PerMonitorAwareV2 = [IntPtr]-4
$GwlStyle = -16
$GwlExStyle = -20
$SwRestore = 9
$SwpNoMoveNoZOrderNoActivate = 0x0016

$null = [AppWindow]::SetThreadDpiAwarenessContext($PerMonitorAwareV2)

$hwnd = [AppWindow]::FindWindowW('FLUTTER_RUNNER_WIN32_WINDOW', $Title)
if ($hwnd -eq [IntPtr]::Zero) {
    Write-Error "Window '$Title' not found."
}

$null = [AppWindow]::ShowWindow($hwnd, $SwRestore)

$dpi = [AppWindow]::GetDpiForWindow($hwnd)
$rect = New-Object AppWindow+RECT
$rect.Right = [int][math]::Round($Width * $dpi / 96)
$rect.Bottom = [int][math]::Round($Height * $dpi / 96)
$style = [AppWindow]::GetWindowLongW($hwnd, $GwlStyle)
$exStyle = [AppWindow]::GetWindowLongW($hwnd, $GwlExStyle)
$null = [AppWindow]::AdjustWindowRectExForDpi([ref]$rect, $style, $false, $exStyle, $dpi)

$null = [AppWindow]::SetWindowPos(
    $hwnd, [IntPtr]::Zero, 0, 0,
    $rect.Right - $rect.Left, $rect.Bottom - $rect.Top,
    $SwpNoMoveNoZOrderNoActivate)
