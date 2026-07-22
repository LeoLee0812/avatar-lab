#!/bin/bash
# 编译 AvatarLab 并打包成 build/AvatarLab.app
set -e
cd "$(dirname "$0")"

APP_NAME="AvatarLab"
BUNDLE_ID="com.avatarlab.app"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "==> 清理旧构建"
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

if [ -f Resources/AppIcon.icns ]; then
  echo "==> 拷贝图标"
  cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"
fi

echo "==> 编译（优化）"
swiftc -O -parse-as-library \
  -framework SwiftUI -framework AppKit \
  -o "$MACOS_DIR/$APP_NAME" \
  Sources/*.swift

echo "==> 写 Info.plist"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> 本地签名（ad-hoc）"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "==> 完成：$APP_DIR"
echo "    安装：cp -R \"$APP_DIR\" /Applications/ && open \"/Applications/$APP_NAME.app\""
