## A. 记录页空白原因排序

按可能性从高到低：

1. **`Common.swift` 的 `GSSafeAreaTop()` 在 SwiftUI `body` 求值时直接操作 key window，并触发 `GSStore.shared.objectWillChange.send()`**  
   这会在布局阶段改变 window 层级并通知 store，造成 body 反复重算、循环刷新，甚至直接卡死/空白。  
   **一句改法：** 删除 UIWindow probe 和 objectWillChange，改用 `@Environment(\.safeAreaInsets)` 或 `GeometryReader` 安全区。

2. **`RecordView` 入场动画初始 `appeared=false`，内容 opacity 为 0，依赖 `ScrollView.onAppear` 才置 true**  
   `onAppear` 在四页常驻结构、store 刷新、View 复用或重建时不保证再触发，内容会一直不可见；顶栏不在动画内，所以可能只看到顶栏。  
   **一句改法：** 删除 `appeared=false` 的显隐控制，初始默认可见，动画只做用户操作/数据变化触发。

3. **`RootView` 四页常驻 `ZStack` 的 opacity+offset 页面切换机制**  
   一旦 store 刷新或根 body 重算，页面隐藏状态和 `onAppear` 生命周期会耦合，容易让 RecordView 停留在 `opacity(0)` 或 offset 移出。  
   **一句改法：** 改用 `TabView(selection:)` 保存各页状态，禁止对整页做 opacity/offset 隐藏。

4. **无版本兼容的 `glassEffect` / 材质背景**  
   如果 iOS 26 的 Liquid Glass API 没做 `if #available`，低系统可能渲染失败或崩溃。  
   **一句改法：** 所有新材质封装成 `LiquidGlassModifier`，iOS 26 用 glass effect，旧系统回退 `.ultraThinMaterial`。

5. **其它可能点：body 内发送 `objectWillChange`、主线程做 JSON 解析、旧的安全区刷新回调**  
   会造成 body 重算竞争。  
   **一句改法：** 禁止 body/layout 回调里触发 store 刷新；数据解析保持原 Store 逻辑，不新增主线程 IO。

---

## B. 必须先做的阻断修复

不要先做视觉重构，先修到“记录页打开即见、不再卡死”。

### 1. `Common.swift` 安全区辅助

**改法：**

- 删除旧无参 `GSSafeAreaTop()`，尤其是：
  - `keyWindow.addSubview(probe)`
  - `DispatchQueue.main.async { GSStore.shared.objectWillChange.send() }`
- 替换为纯函数：

```swift
func GSSafeAreaTop(_ safeAreaInsets: EdgeInsets) -> CGFloat {
    safeAreaInsets.top
}
```

- 全局搜索 `GSSafeAreaTop()` 调用，全部改为在 View 内：

```swift
@Environment(\.safeAreaInsets) private var safeAreaInsets
...
GSSafeAreaTop(safeAreaInsets)
```

- `Common.swift` 不再包含任何 UIKit window 访问。  
- `GSMoney` 保持完全不动。

### 2. `RecordView.swift` 可见性

**改法：**

- 删除/改为：

```swift
@State private var appeared = true
```

- 删除所有：

```swift
.opacity(appeared ? 1 : 0)
.offset(y: appeared ? 0 : 12)
```

- `ScrollView.onAppear` 只保留统计、触感等一次性副作用，不再控制页面可见性。

### 3. `RootView.swift` 根页面隐藏

**改法：**

- 如果当前是四页常驻 `ZStack` + opacity/offset，改为 `TabView`：

```swift
TabView(selection: $selectedTab) {
    RecordView().tag(RootTab.record)
    StatsView().tag(RootTab.stats)
    ScheduleView().tag(RootTab.schedule)
    MeView().tag(RootTab.me)
}
.tabViewStyle(.automatic)
.toolbar(.hidden, for: .tabBar)
```

- 不要对整页做 opacity 隐藏。  
- 如果暂时仍用 `ZStack`，非当前页使用 `.hidden()`，不是 `.opacity(0)`。

### 4. `glassEffect` 版本检查

**改法：**

- 所有新 Liquid Glass 材质集中到 `LiquidGlassModifier`：

```swift
if #available(iOS 26.0, *) {
    content.glassEffect(...)
} else {
    content.background(.ultraThinMaterial, in: RoundedRectangle(...))
}
```

- 不散落业务页面，避免低系统崩溃。

### 5. 静态阻断标准

在 Linux 直接可跑：

```bash
grep -R "addSubview" GSJilu/
grep -R "objectWillChange.send" GSJilu/
grep -R "appeared = false" GSJilu/
grep -R "GSSafeAreaTop()" GSJilu/
```

目标：  
- 无 `addSubview`  
- 无 body 内 `objectWillChange.send`  
- 无旧无参 `GSSafeAreaTop()`  
- RecordView 不再有 `appeared=false`

---

## C. 全面重构方案

对齐 UIKit 3.1.1 的功能与尺寸，但实现必须稳健 SwiftUI，不再打补丁。

---

### 1. UI 框架

#### 1.1 安全区

**废弃 UIWindow probe。**

统一规则：

- 顶部高度 = `safeAreaInsets.top + contentHeight`
- 底部浮层 = `safeAreaInsets.bottom + fixedHeight`

关键组件：

```swift
@Environment(\.safeAreaInsets) private var safeAreaInsets
```

- `GSTopBar` 内部读取 top safe area。
- `LiquidGlassTabBar` 内部读取 bottom safe area。
- FAB、底部编辑栏、批量操作栏都读取 bottom safe area。

不把安全区写回 `GSStore`，SwiftUI 会自动刷新依赖环境值的 body。

#### 1.2 根页面结构

使用 `TabView` 保留状态，不用四页 opacity+offset 常驻 ZStack。

结构：

```swift
enum RootTab: Hashable {
    case record
    case stats
    case schedule
    case me
}

RootView
├─ ZStack(alignment: .bottom)
│   ├─ TabView(selection: $selectedTab)
│   │   ├─ RecordView().tag(RootTab.record)
│   │   ├─ StatsView().tag(RootTab.stats)
│   │   ├─ ScheduleView().tag(RootTab.schedule)
│   │   └─ MeView().tag(RootTab.me)
│   └─ LiquidGlassTabBar(selection: $selectedTab)
```

规则：

- 不设置 `.id(selectedTab)`，避免 Tab 切换销毁状态。
- 各页面内部保留自己的 `ScrollView` 位置、选中日期、筛选状态。
- 每个 Tab 页面自己的 `NavigationStack`，不要全局一个 NavigationView 套 TabView。

#### 1.3 顶栏组件

共享组件：

```swift
GSTopBar<Content: View>: View {
    let contentHeight: CGFloat
    let content: Content

    init(contentHeight: CGFloat, @ViewBuilder content: () -> Content)
}
```

内部：

```swift
VStack(spacing: 0) {
    Rectangle().fill(.clear).frame(height: safeAreaInsets.top)
    content.frame(height: contentHeight)
    Spacer(minLength: 0)
}
.frame(height: safeAreaInsets.top + contentHeight)
.background(.bar)
```

用途：

- 记录页：`ContentHeight = 170`
- 统计/我的：`ContentHeight = 100`
- 排班看板：`ContentHeight = 258`

#### 1.4 Tab 栏

`LiquidGlassTabBar`：

- iOS 26+ 使用 Liquid Glass 材质。
- 旧系统回退 `ultraThinMaterial`。
- 选中指示器使用 `matchedGeometryEffect`，但仅在动画开启且非 Reduce Motion 时启用。
- 拖动选择：

```swift
GeometryReader { proxy in
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .onChanged { value in
            let index = Int(value.location.x / (proxy.size.width / CGFloat(tabs.count)))
            selectedTab = tab(for: index)
        }
}
```

- 位置：

```swift
.padding(.horizontal, 20)
.padding(.bottom, max(safeAreaInsets.bottom, 8))
```

#### 1.5 导航

- 记录、统计、排班、我的各自持有 `NavigationStack`。
- `EditorView`、`BatchView` 用 `.sheet` 或 `.fullScreenCover` present，不在 TabView 内塞隐藏页面。
- 设置/Extras 从“我的” push，不在根层叠加。

---

### 2. UI 布局

#### 2.1 记录页 `RecordView`

结构：

```text
RecordView
├─ GSTopBar(contentHeight: 170)
│   ├─ 月份导航：上/下月
│   ├─ 月份标题
│   └─ 收入 / 支出 / 结余指标
└─ ScrollView
    ├─ GSCalendarSection          // 不包含月份标题
    ├─ GSDayCard                   // 选中日摘要
    ├─ GSTimeLine                  // 当日时间轴
    └─ GSToolRow                   // 工具行，在时间轴下方
overlay
└─ RecordFAB                       // 右下角四态 FAB
```

尺寸规则：

| 组件 | 尺寸 |
|---|---|
| 记录顶栏总高 | `safeAreaInsets.top + 170` |
| 顶栏内指标高度 | 约 64–70，居中 |
| 日历 weekday header | 44 |
| 日历单行 | 44 |
| 日历最大行数 | 6 |
| DayCard | 最小高度 72，水平 16，圆角 `store.cardRadius` |
| ToolRow | 高度 56，水平 16 |
| 页面底部滚动内边距 | 至少 100，给 FAB 留空间 |

FAB 四态：

```swift
enum RecordFabState {
    case collapsed
    case add
    case batch
    case more
}
```

位置：

```swift
.overlay(alignment: .bottomTrailing) {
    RecordFAB(state: $fabState)
        .padding(.trailing, 20)
        .padding(.bottom, safeAreaInsets.bottom + tabBarHeight + 16)
}
```

主按钮 56×56，展开项 44×44。

#### 2.2 日历 `GSCalendarSection`

- 只包含 weekday header + 日期网格。
- 不包含月份标题。
- 不包含工具行。
- 选中格白边：

```swift
.overlay(
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
)
```

#### 2.3 统计页 / 我的页

```text
StatsView
├─ GSTopBar(contentHeight: 100)
└─ ScrollView
    ├─ 统计卡片
    └─ 图表/列表

MeView
├─ GSTopBar(contentHeight: 100)
└─ ScrollView
    ├─ 头像/昵称
    ├─ 设置入口
    └─ Extras
```

#### 2.4 排班页

```text
ScheduleView
├─ GSTopBar(contentHeight: 258)
│   └─ 默认看板
└─ ScrollView
    └─ 排班列表/详细排班
```

默认看板总高：`safeAreaInsets.top + 258`。

#### 2.5 编辑页 / 批量页

`EditorView`：

```text
NavigationStack
├─ GSTopBar(contentHeight: 100)
├─ Form / ScrollView
└─ BottomSaveBar
```

`BatchView`：

```text
NavigationStack
├─ GSTopBar(contentHeight: 100)
├─ 多选列表
└─ BottomBatchToolbar
```

底部栏高度：

```text
max(safeAreaInsets.bottom, 16) + 56
```

---

### 3. UI 设计

#### 3.1 色彩

- 全部走 Assets 动态色，不硬编码 hex。
- 页面背景用系统分组背景：

```swift
Color(uiColor: .systemGroupedBackground)
```

- 卡片背景：

```swift
Color(uiColor: .secondarySystemGroupedBackground)
```

#### 3.2 圆角

所有卡片：

```swift
RoundedRectangle(
    cornerRadius: store.cardRadius,
    style: .continuous
)
```

禁止写死 `cornerRadius: 12` 之类。

#### 3.3 年份/月份格式

禁止千分位：

```swift
Text(verbatim: String(format: "%d", year))
Text(verbatim: String(format: "%d", month))
```

禁止：

```swift
Text(year, format: .number)
```

#### 3.4 货币

继续使用 `GSMoney`，禁止直接用：

```swift
Text(amount, format: .currency)
```

或 `String(format: "%.2f")` 处理货币显示。

#### 3.5 选中格

- 普通格：默认背景。
- 选中格：白边 `lineWidth = 2`。
- 今日：不同背景色，但仍遵守选中白边。

---

### 4. UI 动画

#### 4.1 全局动画策略

尊重两个开关：

- `store.settings.animationsEnabled`
- `@Environment(\.accessibilityReduceMotion)` Reduce Motion

集中 helper：

```swift
enum GSAnim {
    static func spring(
        animationsEnabled: Bool,
        reduceMotion: Bool
    ) -> Animation? {
        guard animationsEnabled, !reduceMotion else { return nil }
        return .spring(response: 0.30, dampingFraction: 0.75)
    }
}
```

用户触发时：

```swift
withAnimation(GSAnim.spring(...)) {
    selectedDay = day
}
```

#### 4.2 禁止“先 opacity 0 等 onAppear”

所有页面初始必须可见。

- 不设 `appeared=false`。
- 不用 `onAppear` 把 opacity 从 0 改到 1。
- 入场动画只能在已可见前提下做 scale/offset，且不得影响最终可见性。

#### 4.3 点击缩放

使用 `ButtonStyle`：

```swift
PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @EnvironmentObject var store: GSStore

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(
                GSAnim.spring(
                    animationsEnabled: store.settings.animationsEnabled,
                    reduceMotion: reduceMotion
                ),
                value: configuration.isPressed
            )
    }
}
```

#### 4.4 DayCard 溶解

数据变化时：

```swift
GSDayCard(...)
    .id(selectedDay)
    .transition(.opacity)
```

选中日变化：

```swift
withAnimation(GSAnim.spring(...)) {
    selectedDay = day
}
```

只让 DayCard 内容交叉溶解，不允许整个页面 opacity 变化。

#### 4.5 切 Tab 保留状态

- `TabView` 本身保留页面状态。
- Tab 切换不透明度/偏移动画。
- 只对 Tab 栏选中指示器做 `matchedGeometryEffect` 或 spring。
- Reduce Motion 或动画关闭时，指示器直接跳转，不用 matchedGeometry。

---

## D. 文件分工

### 甲：记录域

负责：

- `RecordView.swift`
- `EditorView.swift`
- `BatchView.swift`
- `Common.swift` 中安全区辅助，仅限改为稳健实现

规则：

- 可新增轻量安全区纯函数或 View extension。
- **禁止再改 `GSMoney`**。
- **禁止改 Store 业务逻辑**。
- **禁止改 weekStart 映射**。
- **禁止改夜班“凌晨 6 点前才选昨天”规则**。

### 乙：框架与其它页面

负责：

- `RootView.swift`
- `Components/LiquidGlassTabBar.swift`
- `Components/GSTopBar.swift`
- `Components/PressableButtonStyle.swift`
- `Components/LiquidGlassModifier.swift`
- `StatsView.swift`
- `ScheduleView.swift`
- `MeView.swift`
- `SettingsView.swift`
- `ExtrasView.swift`

规则：

- **禁止跨甲的文件**：不改 `RecordView / EditorView / BatchView`。
- 共享组件 API 必须稳定，甲只调用 `GSTopBar`、`PressableButtonStyle`，不关心内部实现。

---

## E. 实施顺序与验收标准

### Step 0：静态排查与冻结

**改法：**  
先在 Linux 上 grep 旧安全区 probe、body 刷新、appeared=false。

**验收：**

```bash
grep -R "addSubview" .
grep -R "objectWillChange.send" .
grep -R "appeared = false" .
grep -R "GSSafeAreaTop()" .
```

目标：  
定位所有旧问题，并确认未合并任何 git 分支。

---

### Step 1：阻断修复

**改法：**  
执行 B 中的 1–5。

**验收：**

- 无 `addSubview` 和旧 `GSSafeAreaTop()`。
- 无 body 内 `objectWillChange.send`。
- `RecordView` 初始可见，不依赖 `onAppear` 显隐。
- `RootView` 不再用整页 opacity 隐藏。
- `glassEffect` 有版本回退。
- 有 Xcode 的同事跑模拟器：冷启动记录页可见，切 Tab 后回来仍可见。

---

### Step 2：根框架与 Tab 栏

**改法：**  
乙重构 `RootView`、`LiquidGlassTabBar`、`GSTopBar`。

**验收：**

- 四个 Tab 可切换。
- Tab 切换保留各页状态：滚动位置、选中日期、筛选状态。
- 自定义 Tab 栏点击、拖动选择正常。
- 无系统 TabBar 双栏。
- 顶部/底部安全区在刘海屏、动态岛、iPad 分屏下正确。
- Reduce Motion 下 Tab 指示器不飞。

---

### Step 3：记录页 / 编辑 / 批量

**改法：**  
甲按 C.2 重构布局。

**验收：**

- 记录顶栏总高 = `safeAreaInsets.top + 170`。
- 指标在顶栏内。
- 日历不包含月份标题和工具行。
- DayCard 在日历下方。
- ToolRow 在时间轴下。
- FAB 四态在右下角，点击展开不遮挡时间轴。
- Editor/Batch 不空白，底部栏不被 Tab 栏遮挡。

---

### Step 4：统计 / 排班 / 我的 / 设置 / Extras

**改法：**  
乙按 C.2 布局。

**验收：**

- 统计/我的顶栏总高 = `safeAreaInsets.top + 100`。
- 排班默认看板总高 = `safeAreaInsets.top + 258`。
- 所有页面在旋转、Dynamic Type 下不重叠、不空白。
- 页面内滚动不被 Tab 栏或安全区遮挡。

---

### Step 5：设计 token 统一

**改法：**  
统一颜色、圆角、年份、货币、白边。

**验收：**

- 圆角全部使用 `store.cardRadius`。
- 年份/月份显示无千分位。
- 货币继续走 `GSMoney`。
- 选中格有白边。
- 深色模式颜色正确。

---

### Step 6：动画改造

**改法：**  
甲/乙替换入场动画、点击缩放、DayCard 溶解。

**验收：**

- 动画开关关闭：无动画。
- Reduce Motion：无动画。
- 初始无 opacity 0。
- 点击缩放只作用于按下的按钮。
- DayCard 切换是溶解，不是整页淡出。
- Tab 切换不重建页面，不闪烁。

---

### Step 7：回归与打包

**验收：**

- 未改 Store 业务逻辑。
- 未改 weekStart 映射。
- 未改夜班规则。
- `Documents/gsjilu.json` 读写往返不受影响。
- 不使用未签名 IPA 作为可用版本。
- 有 Xcode 环境时导出签名构建，替换 3.2.0 build 29。
- 不合并 git 分支。

---

## F. 编程助手最终决断（必须遵守，覆盖上文冲突处）

1. 最低系统是 iOS 15。不要使用 `@Environment(\.safeAreaInsets)`（系统没有这个 Environment key）。不要把 `.toolbar(.hidden, for: .tabBar)` 当成唯一隐藏系统 TabBar 的办法（那是 iOS 16+）。
2. 顶栏不要再量 inset 后写死 `frame(height: inset + N)`，也不要在 body 里往 UIWindow 加 probe。正确写法：ScrollView/页面不要 `ignoresSafeArea(.top)` 把内容顶到刘海里；标题从安全区下方开始（再加约 12pt）；紫色渐变用 background 向上延伸到状态栏。注意 `clipShape` 不要把状态栏下的紫色裁掉。
3. 根结构优先保留四页常驻 ZStack + 自定义 `GSGlassTabBar`（为了 iOS 15 和切换时保留状态）。不要为了改框架强行换成 TabView。禁止用整页 opacity 把当前选中页弄成看不见；非当前页可用 opacity/hitTesting，但默认选中记录页必须一开始就可见。
4. FAB 四态保持原版，不要改成 collapsed/add/batch/more，也不要改成 56×56 圆钮：
   - 无记录 + 今天 → 只显示「记一笔」
   - 无记录 + 非今天 → 「记一笔」+ 左侧「今天」
   - 有记录 + 非今天 → 只显示「回今天」
   - 有记录 + 今天 → 两个都隐藏
   尺寸：记一笔/回今天 102×46，圆角 23；今天 58×44，圆角 22，间距 8；trailing 20，相对页面内容底约 10（根视图已留 76 给 Tab 栏，不要再叠加 safeArea.bottom + tabBarHeight）。
5. Editor / Extras 顶栏内容高度是 52，不是 100。统计/我的是 100，排班看板是 258，记录是 170。
6. 颜色、页面底 `#F2F5FA` / `GSPageBackground`、主题色继续走现有 `GSTheme`，不要改成 `systemGroupedBackground`。货币继续 `GSMoney`；排班看板大数字仍是 `¥` + `GSNum`，不要改成 GSMoney。年份月份必须 `Text(verbatim: String(format:))`。
7. 动画开关是 `store.animations`，不是 `store.settings.animationsEnabled`。统一用已有 `GSMotionEnabled`。入场动画绝不能以 opacity 0 作为初始态。
8. 不要新增独立文件（xcodeproj 在 Linux 上不好改），共享组件改 `Components.swift`，安全区辅助改 `Common.swift`。不要改 Store 业务逻辑、weekStart、夜班「6 点前才选昨天」、GSMoney。不要 git 操作。
9. 先完成阻断（安全区 probe、记录页初始可见、glassEffect 已有版本回退则保持），再在同一轮把布局/设计/框架/动画按上面规则重构到位，不要只改两三处补丁。

