param(
    [ValidateSet('open', 'click', 'shot', 'close')]
    [string]$Action = 'open',
    [int]$RelX = 0,
    [int]$RelY = 0,
    [string]$ShotPath = '',
    [string]$AppPath = '',
    [int]$LaunchWaitSec = 90,
    [switch]$NoGrid
)

# TRAE 桌面端签到辅助脚本（Windows）
# 原理：向 Chromium 渲染子窗口直接投递鼠标消息，不移动真实光标、不抢占前台，
#       因此不会误点到其他窗口；截图用 PrintWindow，窗口被遮挡时也能取到画面。
# 注意：签到入口只在桌面客户端内，网页版没有。

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Text;
using System.Threading;
using System.Runtime.InteropServices;
public class TraeSignIn {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    public static IntPtr FindRender(IntPtr root) {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(root, delegate(IntPtr h, IntPtr l) {
            StringBuilder sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            if (sb.ToString() == "Chrome_RenderWidgetHostHWND") { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    public static void Click(IntPtr h, int x, int y) {
        IntPtr lp = new IntPtr((y << 16) | (x & 0xFFFF));
        PostMessage(h, 0x0200, IntPtr.Zero, lp);       // WM_MOUSEMOVE
        Thread.Sleep(80);
        PostMessage(h, 0x0201, new IntPtr(1), lp);     // WM_LBUTTONDOWN
        Thread.Sleep(60);
        PostMessage(h, 0x0202, IntPtr.Zero, lp);       // WM_LBUTTONUP
    }

    public static void Esc(IntPtr h) {
        PostMessage(h, 0x0100, new IntPtr(0x1B), IntPtr.Zero);  // WM_KEYDOWN
        Thread.Sleep(60);
        PostMessage(h, 0x0101, new IntPtr(0x1B), IntPtr.Zero);  // WM_KEYUP
    }
}
"@

function Resolve-AppPath {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Trae CN\Trae CN.exe",
        "$env:LOCALAPPDATA\Programs\Trae\Trae.exe",
        "$env:ProgramFiles\Trae CN\Trae CN.exe",
        "${env:ProgramFiles(x86)}\Trae CN\Trae CN.exe",
        "C:\dev_tools\AI\Trae CN\Trae CN.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

function Get-AppWindow {
    $names = @('Trae CN', 'Trae')
    foreach ($n in $names) {
        $p = Get-Process -Name $n -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($p) { return $p }
    }

    $exe = if ($AppPath) { $AppPath } else { Resolve-AppPath }
    if (-not $exe -or -not (Test-Path $exe)) {
        throw "未找到 TRAE 桌面客户端。请先安装并登录，或用 -AppPath 指定可执行文件路径。"
    }
    Write-Output "客户端未运行，正在启动：$exe"
    Start-Process -FilePath $exe | Out-Null
    $deadline = (Get-Date).AddSeconds($LaunchWaitSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        foreach ($n in $names) {
            $p = Get-Process -Name $n -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
            if ($p) { return $p }
        }
    }
    throw "客户端启动后 ${LaunchWaitSec}s 内未出现主窗口，请手动打开后重试。"
}

function Save-Shot([int]$w, [int]$h, [string]$path) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [void][TraeSignIn]::PrintWindow($script:handle, $hdc, 2)   # PW_RENDERFULLCONTENT
    $g.ReleaseHdc($hdc)

    $sample = $bmp.GetPixel([int]($w / 2), [int]($h / 2))
    if ($sample.R -eq 0 -and $sample.G -eq 0 -and $sample.B -eq 0) {
        $g.Dispose(); $bmp.Dispose()
        throw "截图失败：窗口可能处于最小化状态，请先还原 TRAE 窗口后重试。"
    }

    if (-not $NoGrid) {
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 255, 0, 0), 1)
        $font = New-Object System.Drawing.Font('Consolas', 10, [System.Drawing.FontStyle]::Bold)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 255, 0, 0))
        $bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(160, 255, 255, 255))
        for ($x = 100; $x -lt $w; $x += 100) {
            $g.DrawLine($pen, $x, 0, $x, $h)
            $g.FillRectangle($bg, $x + 1, 0, 34, 16)
            $g.DrawString("x$x", $font, $brush, $x + 1, 0)
        }
        for ($y = 100; $y -lt $h; $y += 100) {
            $g.DrawLine($pen, 0, $y, $w, $y)
            $g.FillRectangle($bg, 0, $y + 1, 46, 16)
            $g.DrawString("y$y", $font, $brush, 0, $y + 1)
        }
        $pen.Dispose(); $font.Dispose(); $brush.Dispose(); $bg.Dispose()
    }
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "截图：$path"
    Write-Output "图像尺寸 ${w}x${h}；图中网格标注值 = 窗口内相对坐标，可直接作为 -RelX/-RelY"
}

if (-not $ShotPath) { $ShotPath = Join-Path $env:TEMP 'trae-signin\shot.png' }

$proc = Get-AppWindow
$script:handle = $proc.MainWindowHandle
$script:render = [TraeSignIn]::FindRender($script:handle)
if ($script:render -eq [IntPtr]::Zero) { throw "未找到渲染窗口，客户端可能仍在加载，请稍后重试。" }

$rect = New-Object TraeSignIn+RECT
[void][TraeSignIn]::GetWindowRect($script:handle, [ref]$rect)
$winW = $rect.Right - $rect.Left
$winH = $rect.Bottom - $rect.Top
Write-Output "窗口：进程=$($proc.ProcessName) 尺寸=${winW}x${winH}"

switch ($Action) {
    'open' {
        [TraeSignIn]::Esc($script:render)          # 先复位，避免菜单已开时点击变成收起
        Start-Sleep -Milliseconds 500
        [TraeSignIn]::Click($script:render, 28, ($winH - 34))   # 左下角账户头像
        Start-Sleep -Milliseconds 1600
        Save-Shot $winW $winH $ShotPath
    }
    'click' {
        [TraeSignIn]::Click($script:render, $RelX, $RelY)
        Start-Sleep -Milliseconds 2600
        Save-Shot $winW $winH $ShotPath
    }
    'shot' {
        Save-Shot $winW $winH $ShotPath
    }
    'close' {
        [TraeSignIn]::Esc($script:render)
        Write-Output "已发送 Esc 关闭菜单"
    }
}
