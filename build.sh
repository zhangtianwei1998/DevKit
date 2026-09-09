#!/bin/bash
# 编译 DevKit 并组装成 .app。用法: ./build.sh [run]
set -euo pipefail
cd "$(dirname "$0")"

APP=DevKit
BUNDLE_ID=com.tianweizhang.devkit
DIST="dist/$APP.app"
SDK=$(xcrun --show-sdk-path --sdk macosx)

rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"

# 图标。生成一次就缓存着，每次构建重算十几个尺寸没必要。
if [ ! -f Icon/DevKit.icns ] || [ Icon/icon.swift -nt Icon/DevKit.icns ]; then
  ./Icon/make.sh Icon/DevKit.icns >/dev/null
fi
cp Icon/DevKit.icns "$DIST/Contents/Resources/"

xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -parse-as-library \
  Sources/*.swift \
  -o "$DIST/Contents/MacOS/$APP"

cat > "$DIST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>DevKit</string>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 用固定身份签名，这样 TCC 记住的是证书而不是代码指纹，
# 改代码重新构建后屏幕录制/辅助功能授权不会失效。
# 没有证书时退回 ad-hoc，但那样每次改代码都要重新授权。
ID="DevKit Local Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$ID"; then
  codesign --force --sign "$ID" --identifier "$BUNDLE_ID" "$DIST" 2>/dev/null
else
  echo "warn: 没找到证书 '$ID'，退回 ad-hoc 签名，授权会反复失效"
  codesign --force --sign - "$DIST" 2>/dev/null
fi

echo "built: $DIST"
[ "${1:-}" = run ] && { pkill -x "$APP" 2>/dev/null || true; open "$DIST"; }
exit 0
