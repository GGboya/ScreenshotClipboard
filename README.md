# ScreenshotClipboard

macOS 菜单栏截图小工具。截图后直接复制到剪贴板，不生成文件，可以立即粘贴使用。

## 功能

- **区域截图** — 框选屏幕任意区域，复制到剪贴板
- **窗口截图** — 点击选择窗口，复制到剪贴板
- **全屏截图** — 整屏截图，复制到剪贴板
- **全局快捷键** — 随时一键截图，可自定义
- **开机自启动** — 菜单中一键开关
- **Toast 提示** — 截图成功后屏幕顶部浮现提示

## 默认快捷键

| 功能 | 快捷键 |
|------|--------|
| 区域截图 | `⌃⌥A` (Control + Option + A) |
| 窗口截图 | `⌃⌥W` (Control + Option + W) |
| 全屏截图 | `⌃⌥F` (Control + Option + F) |

快捷键可在菜单 → 「快捷键设置...」中自定义。

## 安装

### 环境要求

- macOS 12.0+
- Xcode Command Line Tools（需要 `swiftc`）

### 编译

```bash
git clone <your-repo-url>
cd mac-screenshot-clipboard
bash build.sh
```

### 运行

```bash
open ScreenshotClipboard.app
```

或在 Finder 中双击 `ScreenshotClipboard.app`。

首次运行需要在 **系统设置 → 隐私与安全性 → 录屏与系统录音** 中授予权限。

## 技术细节

- 纯 Swift + AppKit 实现，无第三方依赖
- 调用系统 `screencapture` 命令，通过 `-c` 参数直接写入剪贴板
- Carbon Event API 注册全局快捷键
- `SMAppService` 实现开机自启动
- `LSUIElement = true`，仅菜单栏图标，不占 Dock 位置
- 快捷键配置保存在 `~/Library/Application Support/ScreenshotClipboard/shortcuts.json`

## 项目结构

```
├── main.swift          # 应用源码
├── build.sh            # 编译 & 签名脚本
└── ScreenshotClipboard.app/
    └── Contents/
        ├── Info.plist  # 应用配置
        └── MacOS/      # 编译产物（git 忽略）
```

## License

MIT
