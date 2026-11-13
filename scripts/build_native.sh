#!/bin/sh
# UIKit 版（Objective-C）本地构建：clang 编译 → ld64.lld 链接 → 打包未签名 ipa
# 用法：SDKROOT=/path/to/iPhoneOS27.2.sdk ./scripts/build_native.sh
# 依赖：clang、ld64.lld、zip
set -eu
cd "$(dirname "$0")/.."

: "${SDKROOT:?请先设置 SDKROOT 指向 iPhoneOS SDK 目录}"
SDK="$SDKROOT"
FW="$SDK/System/Library/Frameworks"
SUB="$SDK/System/Library/SubFrameworks"
CFW="$SDK/System/Cryptexes/OS/System/Library/Frameworks"
DEPLOY=15.0
OUT=out/WorkHours-uikit-3.1.1-unsigned.ipa

rm -rf build-native
mkdir -p build-native/Payload/GSJilu.app out

CFLAGS="-target arm64-apple-ios$DEPLOY -isysroot $SDK -F $FW -F $SUB -F $CFW -fobjc-arc -O2 -Iuikit"

for f in uikit/*.m; do
  obj="build-native/$(basename "$f" .m).o"
  if [ -f "$obj" ] && [ "$obj" -nt "$f" ]; then continue; fi
  clang $CFLAGS -c "$f" -o "$obj"
done

ld64.lld -arch arm64 -platform_version ios $DEPLOY 27.2 -syslibroot "$SDK" \
  -F "$FW" -F "$SUB" -F "$CFW" -L "$SDK/usr/lib" -adhoc_codesign \
  -o build-native/Payload/GSJilu.app/GSJilu build-native/*.o \
  -framework UIKit -framework Foundation -framework QuartzCore \
  -framework CoreGraphics -framework UserNotifications -lSystem.B -lobjc.A

cp uikit/Info.plist build-native/Payload/GSJilu.app/Info.plist
cp uikit/icons/AppIcon60x60@2x.png uikit/icons/AppIcon60x60@3x.png build-native/Payload/GSJilu.app/
printf 'APPL????' > build-native/Payload/GSJilu.app/PkgInfo

rm -f "$OUT"
( cd build-native && zip -qry "../$OUT" Payload )
echo "built $OUT"
