#!/bin/sh
set -eu
cd "$(dirname "$0")"
SDK=/workspace/sdk/iPhoneOS27.2.sdk
FW="$SDK/System/Library/Frameworks"
SUB="$SDK/System/Library/SubFrameworks"
CFW="$SDK/System/Cryptexes/OS/System/Library/Frameworks"
OUT=out/WorkHours-3.1.1-unsigned.ipa
rm -rf build-native
mkdir -p build-native/Payload/GSJilu.app out
CFLAGS="-target arm64-apple-ios15.0 -isysroot $SDK -F $FW -F $SUB -F $CFW -fobjc-arc -O0 -Inative"
for f in native/*.m; do
  obj="build-native/$(basename "$f" .m).o"
  if [ -f "$obj" ] && [ "$obj" -nt "$f" ]; then continue; fi
  clang $CFLAGS -c "$f" -o "$obj"
done
ld64.lld -arch arm64 -platform_version ios 15.0 27.2 -syslibroot "$SDK" \
  -F "$FW" -F "$SUB" -F "$CFW" -L "$SDK/usr/lib" -adhoc_codesign \
  -o build-native/Payload/GSJilu.app/GSJilu build-native/*.o \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework UserNotifications -lSystem.B -lobjc.A
cp shell/Info.plist build-native/Payload/GSJilu.app/Info.plist
cp shell/icons/AppIcon60x60@2x.png shell/icons/AppIcon60x60@3x.png build-native/Payload/GSJilu.app/
printf 'APPL????' > build-native/Payload/GSJilu.app/PkgInfo
cd build-native
rm -f "../$OUT"
zip -qry "../$OUT" Payload
echo "built $OUT"
