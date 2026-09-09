#!/bin/bash
# 生成 DevKit.icns。用法: ./make.sh [输出路径]
set -euo pipefail
# 先把输出路径转成绝对路径，再 cd。
# 否则调用方传的相对路径会被当成相对于 Icon/ 目录，写到错的地方。
OUT="${1:-DevKit.icns}"
case "$OUT" in
  /*) ;;
  *) OUT="$PWD/$OUT" ;;
esac

cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

xcrun swiftc -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
  -target arm64-apple-macos13.0 icon.swift -o "$WORK/mkicon"

SET="$WORK/DevKit.iconset"
mkdir -p "$SET"

# icns 需要这几档尺寸，@2x 是同一档的两倍像素
# 注意：sips 和 mkicon 的输出必须在这里就丢掉。
# 如果交给调用方用 >/dev/null 包起来，sips 会因为 stdout 不是
# 终端而变得奇怂，配上 pipefail 直接把构建弄挂。
for sz in 16 32 128 256 512; do
  "$WORK/mkicon" "$SET/icon_${sz}x${sz}.png" >/dev/null 2>&1
  sips -Z "$sz" "$SET/icon_${sz}x${sz}.png" >/dev/null 2>&1
  "$WORK/mkicon" "$SET/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1
  sips -Z $((sz * 2)) "$SET/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1
done

iconutil -c icns "$SET" -o "$OUT"
echo "wrote $OUT"
