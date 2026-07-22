#!/bin/bash
# 把编译好的 AvatarLab.app 打成可直接拖拽安装的 DMG
# 用法：./build.sh && ./make_dmg.sh
set -e
cd "$(dirname "$0")"

APP_NAME="AvatarLab"
VERSION="${1:-1.0.0}"
APP="build/$APP_NAME.app"
STAGE="build/dmg"
DMG="build/$APP_NAME-$VERSION.dmg"

[ -d "$APP" ] || { echo "找不到 $APP，先跑 ./build.sh"; exit 1; }

echo "==> 准备 DMG 内容"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # 拖拽安装的目标

echo "==> 生成 $DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -ov "$DMG" >/dev/null

rm -rf "$STAGE"
echo "==> 完成：$DMG（$(du -h "$DMG" | cut -f1)）"
