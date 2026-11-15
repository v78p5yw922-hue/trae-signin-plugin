#!/bin/bash
# TRAE 桌面端签到辅助脚本（macOS，实验性：未在 macOS 真机验证）
#
# 依赖：macOS 自带 osascript / screencapture / sips，无第三方依赖。
# 权限：需要在「系统设置 > 隐私与安全性 > 辅助功能」里勾选运行本脚本的终端（或 TRAE）。
# 原理：AppleScript 取窗口位置 → JXA 通过 CGEvent 投递鼠标点击 → screencapture 截窗口区域。
# 注意：签到入口只在桌面客户端内，网页版没有。

set -uo pipefail

ACTION="${1:-open}"          # open | click | shot | close
RELX="${2:-0}"
RELY="${3:-0}"
SHOT="${4:-${TMPDIR:-/tmp}trae-signin/shot.png}"
APP_NAME="${TRAE_APP_NAME:-Trae}"
LAUNCH_WAIT="${TRAE_LAUNCH_WAIT:-60}"

die() { echo "错误：$*" >&2; exit 1; }

# 1) 确保应用在运行
if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "客户端未运行，正在启动：$APP_NAME"
  open -a "$APP_NAME" 2>/dev/null || die "无法启动 $APP_NAME，请确认已安装 TRAE 桌面客户端（或设置 TRAE_APP_NAME）。"
  for _ in $(seq 1 "$LAUNCH_WAIT"); do
    pgrep -x "$APP_NAME" >/dev/null 2>&1 && break
    sleep 1
  done
  pgrep -x "$APP_NAME" >/dev/null 2>&1 || die "客户端启动超时。"
  sleep 8
fi

# 2) 激活并取窗口几何（单位：point）
GEOM=$(osascript <<EOF 2>/dev/null
tell application "System Events"
  tell process "$APP_NAME"
    set frontmost to true
    delay 0.4
    if (count of windows) is 0 then return "NOWINDOW"
    set {wx, wy} to position of window 1
    set {ww, wh} to size of window 1
    return (wx as string) & "," & (wy as string) & "," & (ww as string) & "," & (wh as string)
  end tell
end tell
EOF
)

if [ -z "$GEOM" ] || [ "$GEOM" = "NOWINDOW" ]; then
  die "取不到窗口信息。请在「系统设置 > 隐私与安全性 > 辅助功能」中授权当前终端，并确认 TRAE 有可见窗口。"
fi

IFS=',' read -r WX WY WW WH <<< "$GEOM"
echo "窗口：位置=($WX,$WY) 尺寸=${WW}x${WH}（point）"

mkdir -p "$(dirname "$SHOT")"

click_at() {   # 参数：窗口内相对坐标（point）
  local rx="$1" ry="$2"
  local ax=$((WX + rx)) ay=$((WY + ry))
  osascript -l JavaScript <<EOF 2>/dev/null
ObjC.import('CoreGraphics');
function post(event) { $.CGEventPost(0, event); }
var p = $.CGPointMake($ax, $ay);
var down = $.CGEventCreateMouseEvent(null, 1, p, 0);
var up = $.CGEventCreateMouseEvent(null, 2, p, 0);
post(down);
$.NSThread.sleepForTimeInterval(0.06);
post(up);
EOF
  local rc=$?
  [ $rc -ne 0 ] && die "点击失败（可能是缺少辅助功能权限）。"
  echo "已点击窗口内坐标 ($rx,$ry) → 屏幕 ($ax,$ay)"
}

take_shot() {
  screencapture -x -R"${WX},${WY},${WW},${WH}" "$SHOT" 2>/dev/null || die "截图失败。"
  local pw ph
  pw=$(sips -g pixelWidth "$SHOT" 2>/dev/null | awk '/pixelWidth/{print $2}')
  ph=$(sips -g pixelHeight "$SHOT" 2>/dev/null | awk '/pixelHeight/{print $2}')
  local scale
  scale=$(awk -v a="$pw" -v b="$WW" 'BEGIN{ if (b>0) printf "%.2f", a/b; else print "1.00" }')
  echo "截图：$SHOT"
  echo "图像尺寸 ${pw}x${ph}px，窗口 ${WW}x${WH}point，缩放比 $scale"
  echo "换算：窗口内相对坐标 = 图中像素坐标 / $scale（换算后再作为 -RelX/-RelY 传入）"
}

case "$ACTION" in
  open)
    osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1   # Esc 复位
    sleep 0.5
    click_at 28 $((WH - 34))        # 左下角账户头像
    sleep 1.6
    take_shot
    ;;
  click)
    click_at "$RELX" "$RELY"
    sleep 2.6
    take_shot
    ;;
  shot)
    take_shot
    ;;
  close)
    osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1
    echo "已发送 Esc 关闭菜单"
    ;;
  *)
    die "未知动作：$ACTION（可选 open | click | shot | close）"
    ;;
esac
