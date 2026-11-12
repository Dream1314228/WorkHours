# 工时记录 SwiftUI 3.2.0 UI 修复报告（中途交接）

时间：2026-11-12 13:17（亚洲/上海）

**源码状态：未改动，仍是接手时的可编译原状。**  
`/workspace/workhours-swiftui/Sources/GSJilu/` 下所有 `.swift` 文件均未写入补丁（mtime 仍为 12:33–12:46）。本轮只做了对照、截图核对和方案准备；DeepSeek 写补丁的调用在产出前被中断。帮手 bot 可直接在现有源码上继续改。

对照基准：
- SwiftUI：`/workspace/workhours-swiftui/Sources/GSJilu/`
- UIKit 3.1.1 原版（只读）：`/workspace/workhours-swiftui/uikit-source/WorkHours-3.1.1-source/native/`
- Dream 真机截图（当前 SwiftUI 3.2.0，不是原版）：`/home/box/wechat-clawbot/data/attachments/20261112-130953-image.jpg`

---

## 已完成

- 按屏对照了 UIKit 与 SwiftUI（记录 / 统计 / 排班 / 我的 / 编辑 / 批量 / 补扣 / 设置 / 顶栏与 Tab）。
- 用截图核实了 Dream 指出的界面问题。
- 确认了原版 FAB、顶栏高度、Tab 拖动、液态玻璃 API 的改法，可直接落地（见下方「未完成」）。
- 先前覆盖率报告里的三项（ExtrasView 入口、BatchView 入口、「薪资与项目」合并）已复核，**不是缺口**，不要再当 bug 重报：
  - `StatsView` 已有「管理」按钮打开 `ExtrasView`
  - `RecordView` 日历下已有「批量设置工时」
  - 原版「我的」菜单同样是合并的「薪资与项目」（`openSalary` 进 `page=salary`）

工时UI重构乙（本轮，2026-11-12 13:31，亚洲/上海）已完成自己负责的部分，详见文末补记：
- Tab 栏 iOS 26 Liquid Glass + 拖动选择 + 软色 pill（`Components.swift` / `RootView.swift`）
- 切 Tab 不再整页重建，四页常驻；动画尊重 `store.animations` 与 Reduce Motion
- 统计 / 排班 / 我的 / 补扣顶栏按安全区加高并对齐；排班默认看板；我的根页隐藏系统导航栏
- 仅在自己负责的文件里去掉年/月/日序号的千分位；**未改 `GSMoney`，货币仍为 ¥2,672.05 这类格式**
- `GSSafeAreaTop()` 使用甲已写入 `Common.swift` 的版本，未在 `Components.swift` 重复定义

---

## 未完成（请帮手按此优先顺序改源码）

Dream 要求的 4 点 + 后补 3 点都还没写进源码。

### 1. 日历标题年份出现千分位（截图已确认）

现象：日历中间是「2,026年11月」，顶部大标题「2026 年」正常。  
原因：`Text("\(year)年\(month)月")` 走 `LocalizedStringKey`，按地区格式化 Int。  
`GSHeaderBlock(title: "\(year)年")` 传入的是 `String` 变量，不会加逗号。

至少要改成 `Text(verbatim:)` 或先 `String(format: "%d年%d月", year, month)`：

- `RecordView.swift:115` — `Text("\(year)年\(month)月")`（截图中的那一处）
- `RecordView.swift:78` — `Text("\(month)月")`
- `RecordView.swift:389` — `Text("\(day)")`
- `BatchView.swift:93` — `Text("\(year)年\(month)月")`
- `BatchView.swift:141` — `Text("\(index)")`
- `ScheduleView.swift` — `Text("\(year)年 \(month)月")`、`Text("\(i+1)")`、`Text("\(i+1)月")` **【乙已改为 Text(verbatim:)】**
- `StatsView.swift` — `Text("\(month)月")` **【乙已改为 Text(verbatim:)】**
- `ExtrasView.swift` — `Text("补扣管理 · \(month)月")` **【乙已改为 Text(verbatim:)】**

请再全局扫一遍其它 `Text("\(year|month|day)...")`。

### 2. 「记一笔」应从当日卡片挪成右下角悬浮 FAB（截图已确认）

当前：「记一笔」在 dayCard 里面；空态文案却是「点这里或右下角记一笔」。  
原版 `GSRecordViewController.m`：

- FAB 加在 `self.view` 上，不是 dayCard 里
- `trailing = view.trailing - 20`
- `bottom = safeAreaLayoutGuide.bottom - 86`
- 尺寸 102×46，圆角 23，主题色渐变 + 阴影
- 「今天」按钮：`todayBtn.trailing = fab.leading - 8`，58×44，圆角 22，白底

状态与原版 `reload` 一致：

- 无记录：FAB 显示「记一笔」；若不是今天，左侧显示「今天」
- 有记录且不是今天：FAB 显示「回今天」，隐藏「今天」按钮
- 有记录且是今天：两者都隐藏

点击：无记录打开编辑器；有记录则回到今天（`primaryTapped`）。  
`RootView` 已给 Tab 内容 `.padding(.bottom, 76)`，FAB 在 RecordView 底部再垫约 10pt，即可接近原版的 safeArea.bottom - 86。请保证不被 Tab 挡住。  
dayCard 内现有的 `fab("记一笔")` / `fab("回今天")` / 「回到今天」文字按钮应移除，避免重复。

### 3. 顶部大面积白块 / 顶栏过矮（截图已确认）

当前 `GSHeaderBlock.frame(height: 150)`（记录/统计）、排班 130、我的 140，太矮。  
原版高度：

- 记录：`safeAreaInsets.top + 170`（约 230），标题 `yearLabel.top` 最终为 `safeArea.top + 12`
- 统计 / 我的：`safeArea.top + 100`
- 排班：`safeArea.top + 258`（大数字、指标条和分段都在顶栏内）

改法：

- 增加 `GSSafeAreaTop()`，顶栏高度用「安全区顶部 + 对应超额」
- 紫色/主题渐变必须铺到屏幕最顶端（只靠 ScrollView 的 `ignoresSafeArea` 不可靠时，用明确的 top padding + 背景延伸）
- 标题从安全区下方开始，不要贴在色块底部
- `GSHeaderShape` 只圆下方两角，不要裁掉顶部
- 原版记录顶栏的出勤/工时/工资是**顶栏内部**半透明深色条、白字，不是叠在顶栏上的白色卡片；白色指标卡正是截图里顶部的大块白底。排班顶栏同理（指标和「排班/看板」分段在顶栏内；原版默认打开「看板」`boardView = YES`，SwiftUI 默认却是排班日历）

### 4. Tab 栏改成 iOS 26 Liquid Glass，并加回拖动切换

**【乙已落地，见文末补记。Linux 无法用 Xcode 26 真编译，Liquid Glass 须在真机/模拟器验证。】**

当前 `GSGlassTabBar` 是 `.ultraThinMaterial` + 白描边，截图里像实心白胶囊。  
本工程用 Xcode 26.6 / iPhoneOS 26.5 SDK 打包，部署仍是 iOS 15。

建议 API（须包在 `#available(iOS 26.0, *)`）：

```swift
.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
```

若 `.regular.interactive()` 编译不过，改用 `.glassEffect(.regular, in: shape)`。  
iOS 15–18 回退：`ultraThinMaterial`，不要粗白描边。圆角跟原版一样用 26。  
不要在 Liquid Glass 上再盖一层实心白。

拖动选择（原版 `GSComponents.m` 的 `handlePan:` / `updateDragPill:`）：

- 手指在底栏上滑动，滑到哪一列就高亮哪一列
- 换列时 `GSHaptic()`
- 松手选中该项；点击仍然可用
- 选中项有主题软色 pill（圆角 20）跟随

四个 Tab 仍是：记录、统计、排班、我的。

另外：`RootView` 里 `.id("\(selected)-\(store.themeKey)")` 会在切 Tab 时整页重建，切换很跳。主题变化才需要刷新；切 Tab 应保留各页状态（原版四个 VC 一直留在 `tabs` 数组里）。

### 5. 动画更流畅（后补，未做）

**【乙已在 RootView / GSGlassTabBar / GSRowButton 及自己负责的页面落地，并读取 animations 与 Reduce Motion。记录页日历点选、dayCard 溶解、卡片入场属于记录页，留给甲。】**

尊重设置里的「动画」开关和 Reduce Motion：

- 打开：Tab 切换、日历点选、月份切换、卡片出现、按钮按压缩放用弹簧或 easeOut（原版 Tab 图标 0.86 再弹回，damping 约 0.84；卡片栈 0.28 / damping 0.92）
- 关闭：立刻切换，不要动画

### 6. 其它视觉对齐（后补，已对照，未改代码）

记录页（用户一打开就能看出）：

- 原版月份左右箭头在**顶栏**，日历卡里没有「年/月」标题行
- 「批量设置工时 / 删除当前工时」在时间轴卡片**下方**的 toolRow，不在日历卡里
- 当日卡片里农历「农 …」原版一直显示，SwiftUI 被 `showLunar` 关掉（`showLunar` 只控制日历格子）

排班页：默认应为看板；顶栏应包含大数字、指标条和分段。  
我的：根页 `NavigationView` 没有 `navigationBarHidden(true)`，系统导航栏可能盖住自定义顶栏；进入设置页时再显示导航栏。  
编辑 / 补扣弹层顶栏固定 88pt，原版是 `safeArea.top + 52`。  
编辑页卡片写死圆角 20，没有跟「卡片圆角」设置。  
背景目前是纯色 `#F2F5FA`，原版有 `GSBackdropView` 色斑和点纹（非必须，属视觉对齐）。

### 不要回退、不要当成 bug 去改

- `SettingsViews.swift` 中 `SoftwareSettingsView` 的闭合 `}`（已齐，223/223）
- `Store.swift` 的 `sanitizeData` 对 bool 同时接受 Bool 与 NSNumber
- 版本 3.2.0 / build 29；Bundle ID `com.dream.gsjilu`
- 节假日覆盖 2024–2027
- `recordMode` 已保存但编辑器未使用（与原版一致）
- 备份导入也接受明文 JSON
- 周起始选择器标签与存储值的映射是对的（周一=weekStart 1，周日=0），不要改反

---

## 无法从代码 / 截图完全确认的风险

- Linux 上没有 Xcode，无法真编译；Liquid Glass API 需在 Xcode 26 上确认 `.regular.interactive()` 能否通过。
- 顶栏在 ScrollView 里 `ignoresSafeArea` 的实际表现因机型而异，改完要用真机/模拟器看状态栏下方是否还有白缝。
- 未看到统计 / 排班 / 我的 / 编辑页的打回截图，那些页的间距和对齐只能靠对照原版，不能保证像素级一致。
- 夜班模式原版也是「凌晨 6 点前才选昨天」，和文案「默认选中昨天日期」不完全一样；应按原版代码，不要擅自改成整天都选昨天。

---

## 本轮未改动的文件

无。帮手请直接改 `/workspace/workhours-swiftui/Sources/GSJilu/`（主要是 `RecordView.swift`、`Components.swift`、`Common.swift`、`RootView.swift`、`ScheduleView.swift`、`StatsView.swift`、`MeView.swift`、`BatchView.swift`、`ExtrasView.swift`、`EditorView.swift`），并更新本报告的「已完成」部分。

---

## 工时UI重构甲补记（2026-11-12 13:28，亚洲/上海）

已按本报告第 1–3 项落地记录页相关修复，未改写上文既有章节。

改动文件：
- `Sources/GSJilu/RecordView.swift`
- `Sources/GSJilu/BatchView.swift`
- `Sources/GSJilu/Common.swift`（仅追加 `GSSafeAreaTop()`）
- `EditorView.swift` 未改：日期标题已是 `String(format:)`，年假文案是 String 再 Text；未动货币格式。

完成要点：
1. 年/月/日改为 `Text(verbatim: String(format:))`，去掉「2,026年11月」。`GSMoney` 未改，工资仍为 ¥2,672.05 这类格式。
2. 「记一笔 / 回今天」已从 dayCard 挪到右下角悬浮 FAB（102×46，圆角 23，trailing 20，RecordView 底再垫 10pt，叠加 RootView 已有的 76 ≈ 原版 safeArea.bottom-86）。「今天」在左侧（58×44，圆角 22，间距 8）。四态与原版 reload 一致：无记录今天只显示「记一笔」；无记录非今天为「记一笔」+「今天」；有记录非今天只显示「回今天」；有记录且是今天两者都隐藏。
3. 记录页顶栏高度改为 `GSSafeAreaTop() + 170`，标题从安全区下 12pt 开始，紫色铺到屏幕顶。出勤/工时/工资改为顶栏内部半透明深色条（黑 9%、高 72、圆角 20、白边 18%）、白字，不再用叠在顶栏上的白色卡片。仍用 `GSHeaderShape` 只圆下方两角。未改共享 `GSHeaderBlock`，以免影响其它 Tab。

未做（不属于本轮记录页 1–3 项，或文件不在负责范围）：月份箭头挪到顶栏、批量/删除挪到时间轴下方、dayCard 农历始终显示、动画、Tab 液态玻璃、统计/排班/我的顶栏。


---

## 工时UI重构乙补记（2026-11-12 13:31，亚洲/上海）

已按分工改底栏、动画，以及统计 / 排班 / 我的 / 设置 / 补扣的视觉对齐。未改 `RecordView.swift`、`EditorView.swift`、`BatchView.swift`、`Store.swift`、`Common.swift`。记录页 FAB、记录顶栏白卡、记录/批量年份千分位、编辑页顶栏仍归甲（甲已在 13:28 补记中处理了其中 1–3 项）。

改动文件：
- `Sources/GSJilu/RootView.swift`
- `Sources/GSJilu/Components.swift`（`GSGlassTabBar`、动画辅助、`GSHeaderBlock` 可选 `topInset`、`GSPressButtonStyle`、`GSRowButton` 按压；**未改矮 `GSHeaderShape`，默认 `topInset = 0` 不改变记录页若仍使用 `GSHeaderBlock` 时的底部对齐**）
- `Sources/GSJilu/StatsView.swift`
- `Sources/GSJilu/ScheduleView.swift`
- `Sources/GSJilu/MeView.swift`
- `Sources/GSJilu/SettingsViews.swift`（仅给设置子页 / 工资计算器加上 `.navigationBarHidden(false)`，未改 weekStart 映射或 SoftwareSettingsView 结构）
- `Sources/GSJilu/ExtrasView.swift`

完成要点：

1. **Liquid Glass Tab 栏**：`#available(iOS 26.0, *)` 下使用 `.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))`，背景为透明填充 + 玻璃，没有实心白、没有白描边。若 SDK 拒绝 `.interactive()`，把该分支改成 `.glassEffect(.regular, in: shape)` 即可。iOS 15–25 回退 `.ultraThinMaterial`，同样无粗白描边，圆角 26。软阴影 opacity 0.14、radius 24、offset (0, 10)。栏高 64，水平 14，底 8。Linux 无 Xcode，**必须在 Xcode 26 上确认能编译并在真机/模拟器上看玻璃折射**。

2. **拖动选择**：容器 `DragGesture(minimumDistance: 10)` 与 Button 点按并存（`simultaneousGesture`）。按 `floor(x / (width/4))` 夹在 0…3。拖动时隐藏选中 pill，主题软色拖动 pill（圆角 20，列 inset 6、高度栏高-12）跟随手指 X（夹在首尾 Tab 中心）。换列 `GSHaptic()`；点按切到不同 Tab 也有触感。松手选中该列。标题 11pt（选中 Semibold，未选 Medium）。

3. **动画与四页常驻**：`RootView` 去掉切 Tab 时的 `.id("selected-theme")`，四页用 ZStack + opacity / allowsHitTesting 常驻，仅 `.id(store.themeKey)`。仍保留 `.padding(.bottom, 76)`。`store.animations == true` 且未开 Reduce Motion 时：pill / 切页弹簧 response 0.26、damping 0.84；图标先缩到 0.86 再 0.22 / 0.62 弹回；`GSRowButton` 等有轻微按压缩放。任一关闭则瞬间切换、无回弹。

4. **页面对齐**：
   - 统计 / 我的顶栏：`topInset: GSSafeAreaTop()`，高度 `max(原高度, GSSafeAreaTop()+100)`，标题从安全区下约 14pt 开始，渐变铺到顶。
   - 排班默认 `boardView = true`；顶栏高度 `GSSafeAreaTop()+258`，大数字、半透明深色指标条（白字）和「排班/看板」分段都在顶栏内，不再用顶栏外的白卡 + 独立分段。
   - 我的根页 `.navigationBarHidden(true)`；`SettingsPage` 与 `WageCalculatorView` `.navigationBarHidden(false)`，进入设置后显示系统导航栏。
   - 补扣弹层顶栏改为 `GSSafeAreaTop()+52`，标题在安全区下方，颜色铺到顶。
   - 年份/月份/日号千分位只改乙负责的文件（统计「N月」、排班「N年 N月」/柱序号/「N月」、补扣标题）。货币仍走 `GSMoney`，未改 NumberFormatter。

未做 / 风险：
- 无法在本 Linux 箱编译 IPA 或验证 Liquid Glass 实机效果。
- 记录页日历点选弹簧、dayCard 溶解、卡片入场动画未改（记录页归甲）。
- 编辑页顶栏 88pt 未改（归甲）。
- 顶栏在不同刘海/灵动岛机型上是否还有白缝，需真机确认。
- `GSHeaderBlock` 增加了可选 `topInset`，默认 0；甲若记录页已不用该组件，互不影响。


---

## 工时UI重构乙补记（第 1 轮审查返工，2026-11-12 13:49，亚洲/上海）

对照 `UI-REVIEW-ROUND1.md` 中乙负责的审查项已落地。未改写上文既有章节（含此前甲、乙补记）。未改 `RecordView.swift`、`EditorView.swift`、`BatchView.swift`、`Common.swift`、`Store.swift`。未改 `GSMoney`。未把排班看板顶栏大字从 `¥`+`GSNum` 改成 `GSMoney`。未改 FAB 垂直位置（`RootView` 仍 `.padding(.bottom, 76)`）。仍只调用 `GSSafeAreaTop()`，未重复定义。

改动文件：
- `Sources/GSJilu/Components.swift`
- `Sources/GSJilu/RootView.swift`
- `Sources/GSJilu/StatsView.swift`
- `Sources/GSJilu/MeView.swift`

完成要点：

1. **4.2 Tab 图标弹回时序**：`selectTab` 不再用 `DispatchQueue.main.async` 立刻弹回。动画开启时先 `withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) { bouncingIcon = i }`，`selected = i` 不包进该弹簧（pill 仍用自身 `.animation(spring, value: selected)`，切页由 RootView 的 easeOut 负责）。约 0.26s 后（`DispatchWorkItem` + `asyncAfter`，因部署目标 iOS 15，未用仅 iOS 17+ 的 animation completion）再 `withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) { bouncingIcon = nil }`。快速连点或拖动松手会 `cancel` 过期弹回。关动画 / Reduce Motion 时 `bouncingIcon = nil`，无缩放、瞬间切 Tab。
2. **5.7 统计 / 我的顶栏高度**：去掉 `max(原高度, …)`，改为严格 `GSSafeAreaTop()+100`。
3. **4.3 切页过渡（可选微调）**：四页继续常驻。非当前页 `opacity 0` 且 `offset(y: motion ? 6 : 0)`；切到该页时 0.26s easeOut 回到 0；关动画则瞬间切换、无位移。拖动过程不改 `selected`，松手才 `selectTab`，避免与拖动选 Tab 打架。
4. **Tab 图标**：尺寸 18 改为 20。标题仍为 11pt（选中 semibold / 未选 medium）。

未做 / 风险：
- Linux 无法真机编译或录屏，4.2 弹回是否看得见、4.3 是否闪白或与拖动手感冲突，须真机确认。
- 弹回时机用固定 0.26s 延迟，而不是 spring completion 回调。
- 记录页 4.1/4.4/4.6、编辑页高度 88、5.12 页背景、`GSSafeAreaTop` 可刷新实现仍归甲，本轮未改。

---

## 工时UI重构甲补记（第 1 轮正式审查落地，2026-11-12 13:58，亚洲/上海）

已按 `UI-REVIEW-ROUND1.md` 改记录页 / 编辑页，以及 `Common.swift` 中的 `GSSafeAreaTop()`。未改写上文既有章节。未改乙负责的 RootView / Components / Stats / Schedule / Me / Extras / SettingsViews。未改 `GSMoney`、未改排班看板大字、未改 FAB 垂直位置（仍是 trailing 20、RecordView 底垫 10）。未 git push、未合并、未签名、未通知 Dream。Linux 无法真机编译，未打 IPA。

改动文件：
- `Sources/GSJilu/RecordView.swift`
- `Sources/GSJilu/EditorView.swift`
- `Sources/GSJilu/Common.swift`（仅替换/增强 `GSSafeAreaTop()` 并在文末追加 monitor/probe；`GSMoney` / `GSNum` / `GSPageBackground` 未动）
- `Sources/GSJilu/BatchView.swift`（仅两处数量 Int 改为 verbatim / `String(format:)`）

对照审查项：

- **5.1 已做**：切月左右箭头（白图标、字号 18、30×30）移到记录页顶栏 trailing，与「N月」并排（next 距右 20，与月份间距 8）。日历区已去掉年/月标题行。
- **5.2 已做**：日历不再用带标题和工具按钮的 `GSCard`。改为 scroll 上的白底区域（左右 18，距顶栏底 14），只留周标题和日期网格；内边距 10。白底按 `store.cardRadius` 裁圆角，无外卡阴影。
- **5.3 已做**：「批量设置工时 / 删除当前工时」已到时间轴下方独立 toolRow：白底、圆角 16、高 52、左右 18、距时间轴 12；两按钮等宽、高 34、圆角 10，行内左右 10、间距 8。样式对齐原版（图标、主题软底 / #FEF3F2、字号 12）。无记录时删除钮 alpha .38 且 `.disabled(true)`。dayCard 与时间轴间距改为 12。
- **5.4 已做**：dayCard 去掉 `if store.showLunar`，当日卡片农历始终显示「农 …」。格子侧仍跟开关。
- **5.6 已做**：选中格子叠加白边 1、alpha .32（`RoundedRectangle` cornerRadius 13, continuous）。原有阴影/填充/发薪色/底横保留。
- **5.7 已做**：`EditorView` 顶栏由写死 88 改为 `GSSafeAreaTop()+52`，对照补扣页：ZStack 底对齐、标题 padding.bottom 12、紫色铺到顶、`GSHeaderShape`。未改 ExtrasView。
- **5.10 已做**：leaveCard / btCard / editorCard 的卡片圆角改为 `store.cardRadius`。内部小控件圆角（8/10/12/16）未动。
- **GSSafeAreaTop 已做**：不再只读一次 UIWindow 且失败固定返回 0。共享 `GSSafeAreaMonitor` 缓存 inset，窗口 probe 在 `safeAreaInsetsDidChange` / `didMoveToWindow` / `layoutSubviews` 上报，并监听 didBecomeActive、方向变化、窗口成为 key。测量顺序：window.safeAreaInsets.top，再试 statusBar 高度。值变化超过 0.5pt 时在主线程异步 `GSStore.shared.objectWillChange.send()`，让已有 `@EnvironmentObject store` 的记录/统计/排班/我的/补扣/编辑页无需改文件即可刷新。相对模型稿，落地时把 probe 改成 1×1 透明约束视图（避免 hidden + zero frame 收不到 inset），并在窗口首帧未就绪时主线程补装。
- **4.1 已做**：格子抽成带 `@State` 的 `GSCalendarCell`。动画开启且非 Reduce Motion 时，点击先 0.10s 缩到 0.92，再 0.34s spring（dampingFraction 0.55，delay 0.10）回弹，保留触感；关闭则立刻选中、无缩放。
- **4.4 已做**：换日期时 dayCard 以 `selectedDate` 为 `.id`，`.transition(.opacity)`，并在 `selectDate` / `changeMonth` / `goToday` 上使用 0.22s easeInOut；关动画则无过渡。
- **4.6 已做（仅记录页）**：日历区 / dayCard / timeline / toolRow 入场 0.28s、delay 0.022×i、damping 0.92、下移 8 + alpha 0。关动画则首帧即可见、无入场。未改其它 Tab。
- **5.12 未做**：`GSPageBackground` 在 Common.swift，本轮只允许改 `GSSafeAreaTop()`，不能改背景纹理。
- **BatchView 数量 Int**：已把「已选 N 天」「将删除选中的 N 天」改为 `Text(verbatim: String(format:))`。未动货币。
- **FAB / 「今天」/ 切月按压**：已加记录页私有 `RecordPressStyle`（按下 0.10s scale 0.96，松开 0.28s spring damping 0.68）。未改 Components.swift 的 `GSPressButtonStyle`。

未回归：
- FAB 四态与原版一致：无记录今天只「记一笔」；无记录非今天「记一笔」+ 左侧「今天」；有记录非今天只「回今天」；有记录且是今天两者都隐藏。
- 年/月/日仍为 verbatim / format；工资仍走未改的 `GSMoney`（¥2,672.05 这类格式）。
- 记录顶栏高度仍是 `GSSafeAreaTop()+170`，标题 `top+12`，指标为顶栏内半透明深色条、白字；`GSHeaderShape` 只圆下角。
- FAB 垂直位置未改。

剩余风险：
- Linux 无法真机/模拟器验证顶栏首帧 inset、日历缩放回弹、dayCard 溶解、卡片入场和 FAB 是否挡住 toolRow，须真机按审查第 3 节补截图/录屏。
- `GSSafeAreaTop` 依赖 `GSStore.shared.objectWillChange` 触发其它页刷新；若首帧窗口未就绪，需等下一 runloop 或变为 key window 后才能从 0 更新到真实 inset。
- 日历白底使用了 `store.cardRadius`（原版容器未设圆角），属轻微视觉对齐，不是规格禁止项。
- 4.1 的回弹用 `.spring(...).delay(0.10)` 叠在缩小动画之后，须真机确认短按也能走完 0.10s 再回弹。
