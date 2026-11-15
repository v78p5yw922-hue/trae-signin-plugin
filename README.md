# TRAE 每日签到插件

在 TRAE 桌面客户端里一键完成当日签到、领取积分。

## 平台支持

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Windows | 已验证 | 通过向 Chromium 渲染子窗口投递鼠标消息实现点击，**不移动真实光标、不抢前台**，不会误点其他窗口 |
| macOS | 实验性（未真机验证） | AppleScript 取窗口 + CGEvent 投递点击，需要「辅助功能」授权 |
| iOS / Android | 不支持 | TRAE 移动端目前没有签到入口，任何自动化都无法完成签到 |

签到入口位于桌面客户端左下角账户头像弹出的菜单中（「每日领 100 积分」行右侧）。

## 安装

### 从 GitHub 安装（推荐分发方式）

仓库即为插件结构，且只有一份 `SKILL.md`（位于 `skills/trae-daily-signin/`），因此可以直接按地址安装。

在 TRAE 对话框里直接说：

> 安装技能 https://github.com/&lt;你的账号&gt;/trae-daily-signin

TRAE 会把技能目录下载到全局技能根目录（国内版 `~/.trae-cn/skills/trae-daily-signin/`，国际版 `~/.trae/skills/`），脚本随技能一起落地，无需额外安装步骤。

手动安装：

```bash
git clone https://github.com/<你的账号>/trae-daily-signin.git
mkdir -p ~/.trae-cn/skills
cp -r trae-daily-signin/skills/trae-daily-signin ~/.trae-cn/skills/
```

### 作为插件本地加载

- 本地试用：把本目录放到插件目录下（如 `~/.trae-cn/plugins/<publisher>/trae-daily-signin/0.1.0/`），重启 TRAE 后在插件列表启用。
- 上传技能：把 `skills/trae-daily-signin/` 打成根级含 `SKILL.md` 的 zip，在 插件市场 → 技能 → 上传技能 中安装。
- 上传插件库：以本目录为插件根目录打包（`.trae-plugin/plugin.json` 必须在包根）。

## 使用

对话里直接说「帮我签到」或「每天 8:00 自动签到」：

- 一次性签到：调用 Skill `trae-daily-signin`，按流程打开菜单 → 点击「签到」→ 截图验证。
- 定时签到：创建 08:00 的定时任务，任务内容指向同一 Skill。

## 权限与依赖

- Windows：无第三方依赖，使用 PowerShell 5.1 自带能力。
- macOS：需要「系统设置 > 隐私与安全性 > 辅助功能」授权；无第三方依赖。
- 客户端必须已安装且已登录。

## 已知限制

- 属于界面自动化，客户端改版后按钮位置会变（因此流程要求每次按截图读数定位，而不是写死坐标）。
- 窗口最小化时无法截图，需要先还原窗口。
- 仅在客户端内生效，网页版与移动端没有签到入口。

## 免责声明

本插件只做「点一次签到按钮」的等价操作，不代刷、不修改任何账号数据。请遵守 TRAE 的服务条款，账号风险自负。

## 目录结构

```
.trae-plugin/plugin.json          插件清单
assets/app-icon.svg               图标
skills/trae-daily-signin/
  SKILL.md                        技能说明与执行流程
  scripts/win/signin.ps1          Windows 签到脚本
  scripts/mac/signin.sh           macOS 签到脚本（实验性）
```
