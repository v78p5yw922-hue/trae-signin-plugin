---
name: trae-daily-signin
description: 在 TRAE 桌面客户端完成每日签到领积分（左下角头像 → 签到）。Windows 已验证；macOS 为实验性支持；iOS / Android 客户端暂无签到入口，不支持。
---

# TRAE 每日签到

## 适用范围

- 用于「在 TRAE 桌面客户端里完成当日签到并领取积分」这一件事。
- 签到入口位置：客户端左下角账户头像 → 弹出账户菜单 → 「每日领 100 积分」行右侧的「签到」按钮。
- **签到入口只存在于桌面客户端**。网页版、手机客户端均无签到入口，不要尝试用浏览器或手机端完成。
- 不负责：积分查询报表、活动抽奖、会员开通、其他账号操作。

## 平台支持

| 平台 | 状态 | 实现 |
| --- | --- | --- |
| Windows | 已验证可用 | `scripts/win/signin.ps1`（向渲染窗口投递鼠标消息 + PrintWindow 截图） |
| macOS | 实验性，未真机验证 | `scripts/mac/signin.sh`（AppleScript 取窗口 + CGEvent 点击 + screencapture） |
| iOS / Android | 不支持 | TRAE 移动端没有签到入口，任何自动化都无法完成 |

先用系统信息判断平台（Windows 用 PowerShell，macOS 用 bash），只调用对应脚本。

## 设计原则（务必遵守）

脚本刻意不移动真实光标：

- Windows 走 Chromium 渲染子窗口的消息投递，不抢前台、不移动鼠标，因此不会误点到其他应用窗口。
- macOS 通过 CGEvent 投递点击，需要「辅助功能」授权；若未授权脚本会明确报错。

因此**禁止**用鼠标宏、坐标硬编码、`cliclick`、AutoHotkey 之类的外部方式替代本脚本，否则极易误点其他窗口。

脚本动作保持无状态：每次 `open` 前会先发 Esc 复位，避免菜单已打开时点击变成「收起」。

## 标准流程

设 `SKILL_DIR` 为本 Skill 目录，`SHOT_DIR` 为截图输出目录（Windows 建议 `%TEMP%\trae-signin`，macOS 建议 `$TMPDIR/trae-signin`）。

### Windows

1. 打开账户菜单并截图：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\win\signin.ps1" -Action open -ShotPath "<SHOT_DIR>\open.png"
   ```

2. 用 Read 工具查看 `open.png`。截图叠加了 100px 网格与 `x100 / y300` 这类标注，**标注值就是窗口内相对坐标**，直接用作 `-RelX/-RelY`，不要按图片显示尺寸估算像素。
3. 判断：
   - 看不到账户菜单（正常应出现「每日领 100 积分」「升级权益」「管理账户」等条目）→ 再执行一次第 1 步。
   - 按钮文案是「已签到」→ 今日已完成，跳到第 6 步。
   - 按钮文案是「签到」→ 读出该按钮中心点坐标（按钮在「每日领 100 积分」这一行右侧，活动横幅有无会让它上下浮动，必须按截图读，不要用固定值）。
4. 点击并截图验证：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL_DIR>\scripts\win\signin.ps1" -Action click -RelX <x> -RelY <y> -ShotPath "<SHOT_DIR>\result.png"
   ```

5. 查看 `result.png`：按钮应变为「已签到」，顶部积分数字应增加。失败时最多重试 2 次（重跑 1→4）；仍失败则停止并记录现象。
6. 收尾：`-Action close` 关闭菜单。

### macOS

1. `bash "<SKILL_DIR>/scripts/mac/signin.sh" open 0 0 "<SHOT_DIR>/open.png"`
2. 脚本会输出窗口尺寸与截图缩放比（Retina 常见 2.00）。图中像素坐标要**除以缩放比**换算成窗口内相对坐标，再作为第 2、3 个参数传入。
3. `bash "<SKILL_DIR>/scripts/mac/signin.sh" click <relX> <relY> "<SHOT_DIR>/result.png"` 验证方式同上。
4. 收尾：`bash "<SKILL_DIR>/scripts/mac/signin.sh" close`

## 失败处理

- 「未找到 TRAE 桌面客户端」：提示用户先安装并登录客户端，不要尝试网页版。
- 「截图失败：窗口可能处于最小化状态」：提示用户还原窗口，终止本次执行，不要强行操作。
- 「取不到窗口信息 / 点击失败」：macOS 缺「辅助功能」权限，指引用户到 系统设置 > 隐私与安全性 > 辅助功能 授权后重试。
- 客户端未登录：菜单里没有积分与签到条目，此时提示用户手动登录，不要反复点击。

## 汇报要求

- 成功：今日签到成功，报告积分变化（截图能看清时给出数值）。
- 已签到：说明今日此前已完成，无需操作。
- 失败：给出具体失败环节与可执行的恢复步骤。
