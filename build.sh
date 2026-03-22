#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ScreenshotClipboard"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "🔨 编译中..."
swiftc "$PROJECT_DIR/main.swift" \
    -o "$EXECUTABLE" \
    -framework Cocoa \
    -framework Carbon \
    -O

echo "🔏 签名中..."
codesign --force --sign - --identifier com.didi.screenshot-clipboard "$APP_BUNDLE"

echo "✅ 编译并签名成功！"
echo ""
echo "应用位置: $APP_BUNDLE"
echo ""
echo "运行方式："
echo "  双击 $APP_NAME.app 即可启动"
echo "  或命令行运行: open \"$APP_BUNDLE\""
echo ""
echo "快捷键："
echo "  ⌃⌥A  区域截图 → 剪贴板"
echo "  ⌃⌥W  窗口截图 → 剪贴板"
echo "  ⌃⌥F  全屏截图 → 剪贴板"
