#!/bin/bash
# 编译并打包 Desktop Sticky macOS 便签应用
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"
SRC="$ROOT/Sources"
APP="$ROOT/dist/Desktop Sticky.app"

echo "==> 清理旧构建"
rm -rf "$ROOT/dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> 编译 Swift 源码"
swiftc -O \
  -o "$APP/Contents/MacOS/DesktopSticky" \
  "$SRC/main.swift" \
  "$SRC/AppDelegate.swift" \
  "$SRC/Note.swift" \
  "$SRC/NoteStore.swift" \
  "$SRC/NoteViewController.swift" \
  "$SRC/ReminderManager.swift" \
  -framework AppKit \
  -framework UserNotifications \
  -framework Foundation

echo "==> 复制 Info.plist 与图标"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Assets/AppIcon.icns" ]; then
  cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> 本地签名（adhoc）"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "（签名跳过）"

echo "==> 完成：$APP"
ls -la "$APP/Contents/MacOS/"
