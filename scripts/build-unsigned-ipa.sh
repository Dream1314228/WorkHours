#!/usr/bin/env bash
# 在 macOS + 官方 Xcode 上构建未签名 IPA。不要在 Linux 上运行，也不要自行下载非官方 iOS SDK。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "未找到 xcodebuild。请在安装了官方 Xcode 的 Mac 上运行，或使用 GitHub Actions 工作流 .github/workflows/build-unsigned-ipa.yml。" >&2
  exit 1
fi

OUT="$ROOT/dist"
rm -rf "$OUT"
mkdir -p "$OUT"
DERIVED="$OUT/DerivedData"

xcodebuild \
  -project GSJilu.xcodeproj \
  -scheme GSJilu \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  build

APP="$(find "$DERIVED/Build/Products" -name 'GSJilu.app' -type d -print -quit)"
if [[ -z "${APP}" ]]; then
  echo "构建完成但没有找到 GSJilu.app" >&2
  exit 1
fi

mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/GSJilu.app"

# Info.plist 通过 CFBundleIconFiles 引用 60pt 图标；若未打进 app 则从工程资源补一份
for SCALE in 2x 3x; do
  SRC="$ROOT/Resources/AppIcon60x60@${SCALE}.png"
  DST="$OUT/Payload/GSJilu.app/AppIcon60x60@${SCALE}.png"
  if [[ -f "$SRC" && ! -f "$DST" ]]; then
    cp "$SRC" "$DST"
  fi
done

(
  cd "$OUT"
  zip -r -y "GSJilu-3.2.0-unsigned.ipa" Payload >/dev/null
)

rm -rf "$OUT/Payload" "$DERIVED"
echo "已生成未签名 IPA：$OUT/GSJilu-3.2.0-unsigned.ipa"
