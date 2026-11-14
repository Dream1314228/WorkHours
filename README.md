# 工时记录 · WorkHours

**给车间、门店、工厂用的工时记录 App** — 记每天上什么班、干了几个小时，自动算加班费、补贴和当月工资。

作者 / 维护：**Dream.or** · MIT 协议 · 数据只存在本机，不联网、不要账号。

仓库里是同一款 App 的两套原生实现：**功能对齐，UI 是两套完全不同的设计**。不是同一套界面换个框架重写一遍——布局、配色、组件形态、转场动效都各自从头设计，连页面怎么组织都不一样：UIKit 版是经典 TabBar + 卡片列表，SwiftUI 版用液态玻璃、跟手翻月、环形构成图和一整套新的设置页结构。两套代码看起来像两个 App，这是故意的。

| 版本 | 语言 | 最低系统 | UI 设计 | 成品包 | 源码 |
|---|---|---|---|---|---|
| UIKit 版 | Objective-C + UIKit | iOS 15 | 经典原生风：TabBar、卡片列表、手写毛玻璃 | `releases/WorkHours-uikit-3.1.1-unsigned.ipa` | `uikit/` |
| SwiftUI 版 | Swift + SwiftUI | iOS 26 | 重做：液态玻璃、动态效果、图表页全新版式 | `releases/WorkHours-swiftui-1.2.1-unsigned.ipa` | `swiftui/` |

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

- **SwiftUI 1.2.1**（2026-11-14）：修横滑切月只能单向滑（初始页未居中）与切月重建闪动；设置页新增「配置默认时长」，按班次配正班/加班/周末/节假/日结
- **SwiftUI 1.2.0**（2026-11-14）：日历横滑切月改横向分页 ScrollView（纵向滚动不再冲突）；统计页加「本期」一键回到当前考勤期；发薪日选中后仍为金色（改用浅底）；日历副行显示节假日名称
- **SwiftUI 1.1.1**（2026-11-14）：「薪」去掉金底只留金字；日历不再挂横向拖动手势，纵向滚动不再被抢（切月用箭头）；统计页默认落在今天所属考勤期
- **SwiftUI 1.1.0**（2026-11-14）：日历恢复纵向滚动、底部操作条透明、日历右上角角标内收、发薪日金色重做、环形图与图例配比、页面切换加过渡、HTML 报表窄屏改卡片且打印锁 A4
- **SwiftUI 1.0.0**（2026-11-13）：按全新设计做的一版，界面与 UIKit 版不共用同一套布局；动态效果开关、柱状图与 HTML 报表重做、雷达图与年度热力图、日历跟手翻月
- **UIKit 3.1.1**（2026-11-11）：备份兼容老版、统计按考勤期聚合、账单卡可折叠
- **UIKit 3.0.0**（2026-11-06）：首个开源版本

## 许可

MIT，见 `LICENSE`。
