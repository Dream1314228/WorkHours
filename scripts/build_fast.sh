#!/bin/sh
# UIKit 版加速编译：PCH + 并行 + 真增量
# 用法：SDKROOT=/path/to/iPhoneOS27.2.sdk ./scripts/build_fast.sh [并行数]
# 环境变量：JOBS=6 并行数；PCH_FORCE=1 强制重建 PCH
set -eu
cd "$(dirname "$0")/.."

: "${SDKROOT:?请先设置 SDKROOT 指向 iPhoneOS SDK 目录}"
SDK="$SDKROOT"
FW="$SDK/System/Library/Frameworks"
SUB="$SDK/System/Library/SubFrameworks"
CFW="$SDK/System/Cryptexes/OS/System/Library/Frameworks"
DEPLOY=15.0
JOBS="${1:-${JOBS:-6}}"
B=build-native
APP=$B/Payload/GSJilu.app
OUT=out/WorkHours-uikit-3.1.1-unsigned.ipa
CF="-target arm64-apple-ios$DEPLOY -isysroot $SDK -F $FW -F $SUB -F $CFW -fobjc-arc -O2 -Iuikit -w"
mkdir -p "$APP" out

PCH=$B/pch.pch
if [ ! -f "$PCH" ] || [ -n "${PCH_FORCE:-}" ]; then
  printf '#import <UIKit/UIKit.h>\n#import <Foundation/Foundation.h>\n#import <QuartzCore/QuartzCore.h>\n#import <CoreGraphics/CoreGraphics.h>\n#import <UserNotifications/UserNotifications.h>\n' > "$B/pch.h"
  echo "[pch] 重建 $PCH"
  clang $CF -x objective-c-header "$B/pch.h" -o "$PCH"
fi

: > "$B/todo.txt"
for f in uikit/*.m; do
  obj="$B/$(basename "$f" .m).o"
  if [ -f "$obj" ] && [ "$obj" -nt "$f" ] && [ "$obj" -nt "$PCH" ]; then continue; fi
  echo "$f" >> "$B/todo.txt"
done
N=$(wc -l < "$B/todo.txt")
echo "[cc] 待编译 $N / $(ls uikit/*.m | wc -l) 个，并行 $JOBS"
if [ "$N" -gt 0 ]; then
  export CF B
  xargs -P "$JOBS" -I{} sh -c 'clang $CF -include-pch "$B/pch.pch" -c "{}" -o "$B/$(basename "{}" .m).o"' < "$B/todo.txt"
fi

echo "[ld] 链接"
rm -f "$APP/GSJilu"
ld64.lld -arch arm64 -platform_version ios $DEPLOY 27.2 -syslibroot "$SDK" \
  -F "$FW" -F "$SUB" -F "$CFW" -L "$SDK/usr/lib" -adhoc_codesign \
  -o "$APP/GSJilu" "$B"/*.o \
  -framework UIKit -framework Foundation -framework QuartzCore \
  -framework CoreGraphics -framework UserNotifications -lSystem.B -lobjc.A

cp uikit/Info.plist "$APP/Info.plist"
cp uikit/icons/AppIcon60x60@2x.png uikit/icons/AppIcon60x60@3x.png "$APP/"
printf 'APPL????' > "$APP/PkgInfo"

rm -f "$OUT"
( cd "$B" && zip -qry "../$OUT" Payload )
echo "[ok] $OUT $(wc -c < "$OUT") 字节"
