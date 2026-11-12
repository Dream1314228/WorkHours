# 工时记录 SwiftUI 3.2.0 UI 审查意见（第 3 轮）

- 时间：2026-11-12 18:26（Asia/Shanghai）
- 审查范围：只审不改。对照 `/workspace/workhours-swiftui/Sources/GSJilu/`、UIKit 3.1.1（`uikit-source/WorkHours-3.1.1-source/native/`）、`UI-REBUILD-PLAN.md` 文末 F 决断、`UI-REVIEW-CHECKLIST.md`。第 1、2 轮意见与 `UI-FIX-REPORT.md` 只作背景，未改这些旧稿。打回截图为改前旧图，不用它否定已改源码。
- 工程无 `.git`，本轮改动文件按 mtime 记录；无法判定的不猜人。
- 审查推理走官方 DeepSeek API（deepseek-v4-pro），下列结论已逐条对照当前源码校对，冲突以源码为准。

## 本轮改动文件（按 mtime）

甲（2026-11-12 18:13:50 Asia/Shanghai）：

- `Sources/GSJilu/Common.swift`
- `Sources/GSJilu/EditorView.swift`
- `Sources/GSJilu/RecordView.swift`

乙（2026-11-12 18:17:28 Asia/Shanghai）：

- `Sources/GSJilu/Components.swift`
- `Sources/GSJilu/ExtrasView.swift`
- `Sources/GSJilu/MeView.swift`
- `Sources/GSJilu/RootView.swift`
- `Sources/GSJilu/ScheduleView.swift`
- `Sources/GSJilu/StatsView.swift`

本轮未改（mtime 更早，不据此猜本轮作者）：`BatchView.swift`（13:57）、`SettingsViews.swift`（13:31）、`Store.swift`（12:46）、`GSJiluApp.swift` / `HTMLReport.swift` / `Reminder.swift`（更早）。历史分工仍是：甲多改 RecordView / BatchView / Common / EditorView；乙多改 RootView / Components / Stats / Schedule / Me / Extras / SettingsViews。

---

## 1. 阻断打包的源码问题

源码层面未见阻断打包的问题，建议打包给 Dream 真机验证。

已核对的源码中，没有发现会导致真机再次空白、内容顶进刘海、编译失败（含 iOS 15 不存在且无 `#available` 的 API）、或丢失核心功能的问题：

- 上一轮空白的已知根因已拆除，不是换了一种写法仍使首帧不可见。
- 根结构默认选中记录页，第一帧即为 opacity 1、offset 0，且当前页不走淡入动画。
- 各页顶栏不再 `frame(height: inset + N)`，也没有整页 `ignoresSafeArea(.top)` 把标题/内容顶进刘海。
- FAB 四态与尺寸与原版/F 决断一致；`GSMoney`、weekStart、夜班「6 点前才选昨天」、排班大字 `¥`+`GSNum`、年份月份 `Text(verbatim: String(format:))` 均在。
- 部署目标 iOS 15；未使用 `@Environment(\.safeAreaInsets)`；`.glassEffect` 包在 `#available(iOS 26.0, *)` 内。

MeView 顶栏紫色可能被 `NavigationView` 裁剪、以及 iOS 26 `glassEffect(.regular.interactive())` 的 SDK 兼容，目前只是须真机/打包编译确认的风险，不升级为阻断。

---

## 2. 建议修改（非阻断，按甲/乙分工）

### 甲

#### 2.1 日历白底圆角与原版有轻微差异

- 现象：记录页日历白底容器使用 `store.cardRadius`，UIKit 原版该容器无圆角，视觉可能不完全一致。
- 证据：`RecordView.swift` 204–211，`calendarArea` 为 `GSMonthCalendar` + 白底 + `clipShape(RoundedRectangle(cornerRadius: store.cardRadius, style: .continuous))`。
- 负责方：甲
- 改法：若要严格对齐原版，把该容器圆角改为 0；若产品已接受此轻微差异，可保留。不阻断打包。

本轮甲文件未见其它必须先改的项。`EditorView.swift` 241 的年假说明是 `Text(balance)`，年份已先拼进 `String`，不是 `Text("\(year)年")` 那种 LocalizedStringKey 插值，不会再现记录页标题「2,026年」。无需当 bug 改。

### 乙

#### 2.2 MeView 顶栏紫色上延可能被 NavigationView 裁剪

- 现象：我的页顶栏紫色依赖 `gsHeaderChrome` 的 +120 / −120 溢出画进状态栏。该顶栏在 `NavigationView` 内，导航容器若 `clipsToBounds`，状态栏区域可能露出页背景或出现白缝，紫色铺不到顶。这不会把内容顶进刘海，也不是整页空白。
- 证据：`MeView.swift` 15–17、44–56：`NavigationView { VStack { GSHeaderBlock(..., contentHeight: 100); ScrollView } .background(GSPageBackground().ignoresSafeArea()) .navigationBarHidden(true) }`。`gsHeaderChrome` 在 `Common.swift` 318–328，`GSHeaderShape` 在 `Components.swift` 108–121，上延依赖父级不裁剪。记录/统计/排班/编辑/补扣顶栏不在 `NavigationView` 内（记录页的 `NavigationView` 只包批量页 `fullScreenCover`）。
- 负责方：乙
- 改法：先看真机「我的」顶栏（不要裁掉状态栏）。若确有白缝/紫色被切，不要给整页或标题加 `ignoresSafeArea(.top)`（会把内容顶进刘海）。推荐在 `NavigationView` **外侧**用 `ZStack(alignment: .top)` 垫一层与当前主题色相同、仅上边 `ignoresSafeArea(edges: .top)` 的色带，再放现有 `NavigationView`。不要把顶栏移到 `NavigationView` 外面，以免推入设置子页时顶栏仍留在屏幕上。

#### 2.3 iOS 26 `glassEffect(.regular.interactive())` 须用当前 SDK 编过

- 现象：若打包用的 SDK 有 `glassEffect` 但不接受 `.interactive()`，iOS 26 分支会编译失败。源码已用 `#available` 保护，并在注释里写了退路。
- 证据：`Components.swift` 279–291。
- 负责方：乙
- 改法：打包时用当前 Xcode/SDK 编译确认。若报错，按注释改为 `.glassEffect(.regular, in: shape)`，保留 `#available(iOS 26.0, *)` 与 `else` 的 `ultraThinMaterial`。不要去掉版本判断。

---

## 3. 残留风险与真机要看的点

Linux 无法真机硬证，下列只能打未签名包后由 Dream 在真机确认。

### 记录页是否再空白

- 源码已删除 `GSSafeAreaTop` / window probe / body 里对 store 发 `objectWillChange`，以及 `appeared=false`、整页 opacity 0 等 onAppear 才显示的逻辑。`RootView` 默认 `selected = 0`，记录页常驻且首帧 opacity 1。
- 真机：冷启动看默认记录页第一帧是否立即有顶栏、日历、卡片，有无白屏或闪一下再出来。再切到统计/排班/我的再切回，确认四页状态还在、当前页不会被弄没。日期切换时 `dayCard` 的 `.id(selectedDate).transition(.opacity)`（`RecordView.swift` 68–69）不应把整页弄空，最多卡片短暂淡变。

### 顶栏是否贴刘海 / 留白缝

- 内容高度已按 F 决断：记录 170、统计/我的 100、排班看板 258、编辑/补扣 52；标题从安全区下再约 12pt（编辑/补扣为底对齐 + 底垫 12）。紫色靠 `gsHeaderChrome` 上延，整页没有 `ignoresSafeArea(.top)`。
- `gsHeaderChrome` 固定上延 120pt，当前刘海/灵动岛约 47–59pt，一般够用；若某机 inset 超过 120，上沿可能露缝。父级若裁剪溢出，也会露缝。
- 真机：刘海、灵动岛、非刘海各一份，冷启动截图不要裁掉状态栏。看记录/统计/排班/我的/编辑/补扣：紫色是否铺到屏最顶、标题是否在安全区下方、内容有没有顶进刘海。尤其看「我的」是否被 `NavigationView` 裁切。

### Liquid Glass 与 Tab

- iOS 26 走 `.glassEffect(.regular.interactive())`，iOS 15–25 走 `ultraThinMaterial`，无粗白描边。拖动过程不改 `selected`，松手再切页。
- 真机：iOS 26 上看玻璃质感与拖动选 Tab；iOS 15/偏低版本看材料背景、点按/拖动是否顺手、会不会误切。关闭「动画」时图标不应缩放弹跳。

### FAB 四态与位置

- 源码四态、102×46 / 58×44、圆角 23 / 22、间距 8、trailing 20、内容底 10（根视图已留 76 给 Tab）均已对齐原版与 F 决断。
- 真机：无记录+今天只「记一笔」；无记录+非今天「记一笔」+左侧「今天」；有记录+非今天只「回今天」；有记录+今天都隐藏。位置是否贴右下且不被 Tab 挡住；不要再变成 56×56 圆钮。

### 其它须看

- 年份月份不要出现「2,026年11月」。记录顶栏工资等货币保持 `¥2,672.05` 这种千分位；排班看板大数字是 `¥`+`GSNum`（可能无千分位/小数），这是对齐原版，不要当 bug。
- 记录页：指标在紫色顶栏内半透明深色条（不是白卡）；日历不包月份标题和工具行；toolRow 在时间轴下；dayCard 农历常显；选中格白边。
- 夜班只在 6 点前默认选昨天；「回今天」仍回到日历今天（与原版一致）。
- 关闭动画后，记录按压、格子、切月、Tab 弹跳应瞬间到位，无缩放。
- 日历格短按回弹仍是 `spring.delay(0.10)`（`RecordView.swift` 571–576），须确认短按也能缩完再弹回。

建议真机至少提供：冷启动记录页（含状态栏）、统计/排班/我的/编辑/补扣顶栏、FAB 四态各一张，以及切 Tab 与拖动 Tab 的短录屏。

---

## 4. 六大重点的逐项结论表

| 重点 | 结论 | 证据 | 是否阻断 |
|---|---|---|---|
| 1 空白页阻断 | 已知根因已拆除，默认记录页第一帧可见 | `Sources/GSJilu` 无 `GSSafeAreaTop` / probe / 在 View body 里 `objectWillChange`。`objectWillChange` 仅 `Store.swift` 243–246 `bump()`。无 `appeared`。`RootView.swift` 5 默认 `selected = 0`；13–16 四页常驻；28–36 当前页 opacity 1、offset 0、animation 为 nil。RecordView 无整页 opacity 0 / onAppear 才显示。 | 否 |
| 2 顶栏 | 高度与「内容从安全区下开始、紫色上延、整页不 ignoresSafeArea(.top)」已对齐；裁剪须真机看 | 记录 `RecordView.swift` 183–187 高度 170 + `gsHeaderChrome`，标题 top 12。统计 `StatsView.swift` 13–14、33–54 高度 100。我的 `MeView.swift` 17 高度 100。排班 `ScheduleView.swift` 83 高度 258，默认看板。编辑 `EditorView.swift` 73–74 高度 52。补扣 `ExtrasView.swift` 16 高度 52。`GSHeaderBlock`（`Components.swift` 52–82）不再 `inset+N`。`ignoresSafeArea` 只用于根/页背景或键盘，不是整页内容顶进刘海。 | 否 |
| 3 功能不丢 | 源码对齐，无回归 | FAB 四态与尺寸 `RecordView.swift` 44–55、81–84、312–341，对照 UIKit `GSRecordViewController.m`。夜班 `RecordView.swift` 16–19 仅 hour < 6。`weekStart` 在 `Store.swift` 295 及日历。`GSMoney` 在 `Common.swift` 55–63，记录/统计等仍调用。排班大字 `ScheduleView.swift` 61、123–124 为 `¥`+`GSNum`。年/月标题为 `Text(verbatim: String(format:))`。 | 否 |
| 4 记录页结构 | 已对齐 | 指标在顶栏内 `RecordView.swift` 165–179。日历只含周标题和网格，204–211。顺序：日历 → dayCard → 时间轴 → toolRow（61–76）。dayCard 农历常显 224。选中白边 628–630（白 0.32、线宽 1）。无记录时删除钮 disabled + opacity 0.38（301–302）。 | 否 |
| 5 RootView / Tab / 动画 | 已对齐；当前页不会被弄成看不见 | 四页常驻 ZStack + `GSGlassTabBar`，`RootView.swift` 10–22，只 `.id(store.themeKey)`，底垫 76。动画走 `GSMotionEnabled`（`store.animations && !reduceMotion`，`Components.swift` 7–9）。Tab：`Components.swift` 285–291 有 iOS 26 `#available` 回退；拖动 353–374 过程不改 selected。 | 否 |
| 6 最低 iOS 15 | 未见无版本判断的新 API | `Package.swift` `.iOS(.v15)`；`pbxproj` `IPHONEOS_DEPLOYMENT_TARGET = 15.0`。无 `@Environment(\.safeAreaInsets)`。全局未见无 `#available` 的 `NavigationStack` / `navigationDestination` / `toolbarBackground` / `presentationDetents` / `foregroundStyle` / `ShareLink` / `@Observable` 等。`.glassEffect` 仅在 `#available(iOS 26.0, *)` 内。 | 否 |

回归扫描：未回到白卡指标、年份千分位标题、FAB 进 dayCard、切 Tab 整页销毁。货币千分位正确；排班大字 `¥`+`GSNum` 对齐原版，不当 bug。

---

## 5. 总评

**建议打包。** 源码层面未见阻断打包的问题，建议打包给 Dream 真机验证。

不要先为 2.1–2.3 再开一轮大改；这些不是打包阻断。打包时用当前 SDK 编译确认 Tab 栏 iOS 26 分支。真机优先确认：记录页是否再空白、各页顶栏是否贴刘海或留白缝（尤其「我的」）、Liquid Glass / Tab 拖动、FAB 四态。若「我的」顶栏被 `NavigationView` 裁出白缝，再按 2.2 由乙改，不要给整页加 `ignoresSafeArea(.top)`。
