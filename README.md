# 工时记录 · WorkHours

**给车间、门店、工厂用的工时记录 App** — 记每天上什么班、干了几个小时，自动算加班费、补贴和当月工资。

作者 / 维护：**Dream.or** · MIT 协议 · 数据只存在本机，不联网、不要账号。

仓库里是同一款 App 的两套原生实现，功能对齐，界面各自做过：

| 版本 | 语言 | 最低系统 | 成品包 | 源码 |
|---|---|---|---|---|
| UIKit 版 | Objective-C + UIKit | iOS 15 | `releases/WorkHours-uikit-3.1.1-unsigned.ipa` | `uikit/` |
| SwiftUI 版 | Swift + SwiftUI | iOS 26 | `releases/WorkHours-swiftui-1.0.0-unsigned.ipa` | `swiftui/` |

两个包都是**未签名 IPA**，装到手机上要自己用 AltStore / Sideloadly / 证书重签。

## 功能

- **日历记录**：一屏看全整月，哪天记了工时、上什么班、节假日 / 周末 / 发薪日，用颜色和角标标出来
- **班次管理**：自己建班次（白班、夜班、早班…），预设上下班时间和默认时长，记工时点一下带出
- **工时明细**：一天拆成正常工时、加班、请假 / 调休，按项目分别计薪
- **批量设置**：日历里多选任意几天，统一设同一个班次；也能批量删记录
- **项目与薪资**：多项目并行，各自设时薪；薪资设置与项目管理合并成一个入口
- **补贴与扣款**：固定补贴、按天自动补贴、临时补扣，支持一键复用上月
- **年假**：额度、已用、剩余自动算
- **工资计算器**：临时算一笔，不写进记录
- **统计报表**：月度 / 年度统计，柱状图分色显示正班、加班、补贴；SwiftUI 版另有环形构成、工时雷达、年度热力图
- **HTML 导出**：一键导出整期报表，浏览器能看、能打印成 PDF
- **提醒**：每天固定时间提醒记账（本地通知）
- **备份还原**：`.gsjilu` 整库导出导入，换手机不丢数据；两版互相认对方的备份
- **外观**：多套主题，圆角、阴影、动态效果开关都能调

## 目录

```
uikit/          UIKit 版源码（19 个 .m/.h）+ Info.plist + icons
swiftui/        SwiftUI 版源码（工程在 WorkHours/ 下，project.yml 供 xcodegen）
releases/       两个成品未签名 IPA
scripts/        本地构建脚本（UIKit 版）
docs/           功能需求规格（PDR）、操作作业规程（SOP）
.github/        云端构建 workflow
```

## 自己构建

### UIKit 版（本地）

需要 iOS SDK、`clang`、`ld64.lld`、`zip`。

```sh
SDKROOT=/path/to/iPhoneOS27.2.sdk ./scripts/build_native.sh   # 全量
SDKROOT=/path/to/iPhoneOS27.2.sdk ./scripts/build_fast.sh 4   # PCH + 并行，日常用
```

产物在 `out/WorkHours-uikit-3.1.1-unsigned.ipa`。`build_fast.sh` 会建 PCH 复用，改动的文件才重编。

### SwiftUI 版

SwiftUI 只随 Xcode SDK 提供，得用 macOS：

```sh
cd swiftui && xcodegen generate && xcodebuild -project WorkHours.xcodeproj \
  -scheme WorkHours -configuration Release -sdk iphoneos \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

或者推到 `main`，`.github/workflows/build-swiftui.yml` 会在 `macos-26` 上自动编出未签名 IPA。

### UIKit 版（云端）

`.github/workflows/build-ipa.yml` 用 `macos-15` 跑同一套流程，推 `uikit/` 或手动 dispatch 都行。

## 数据

- 存在 App 沙盒 `Documents/` 下，一个 JSON 文件
- 备份文件 `.gsjilu`，内嵌设置、项目、班次、排班、每日工时、补贴扣款
- 没有服务器、没有埋点、没有第三方库

## 更新记录

- **SwiftUI 1.0.0**（2026-11-13）：从 UIKit 版重写；动态效果开关、柱状图与 HTML 报表重做、雷达图与年度热力图、日历跟手翻月
- **UIKit 3.1.1**（2026-11-11）：备份兼容老版、统计按考勤期聚合、账单卡可折叠
- **UIKit 3.0.0**（2026-11-06）：首个开源版本

## 许可

MIT，见 `LICENSE`。
