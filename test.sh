#!/bin/bash
# 跑全部自检。用法: ./test.sh
set -euo pipefail
cd "$(dirname "$0")"
SDK=$(xcrun --show-sdk-path --sdk macosx)
T=arm64-apple-macos13.0

# 纯逻辑：hosts 文本处理 + 钉图几何计算
xcrun swiftc -sdk "$SDK" -target $T \
  Sources/HostsFile.swift Sources/PinGeometry.swift Sources/HotKeySpec.swift Sources/ScrollCore.swift Sources/HostsStore.swift Tests/main.swift \
  -o /tmp/devkit-test
/tmp/devkit-test

# 需要 AppKit：视图布局 + 钉图记账
xcrun swiftc -sdk "$SDK" -target $T \
  Sources/HostsFile.swift Sources/HostsStore.swift Sources/HostsView.swift \
  Sources/PinGeometry.swift Sources/PinWindow.swift Sources/Snip.swift \
  Sources/SnipView.swift Sources/HotKeySpec.swift Sources/HotKey.swift \
  Sources/HotKeyField.swift Sources/Settings.swift \
  Sources/ScrollCore.swift Sources/ScrollTap.swift Sources/ScrollView2.swift \
  Tests/ui/main.swift \
  -o /tmp/devkit-uitest
/tmp/devkit-uitest

rm -f /tmp/devkit-test /tmp/devkit-uitest
