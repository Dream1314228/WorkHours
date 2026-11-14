# WorkHours 修复版源码

- 基线：commit `252ece6`（产品代码 `8426358` + CI workflow 修复）
- 导出时间：2026-11-15
- 说明：这份源码**从未被编译过**（我们这边没有 Xcode），以下内容都来自静态审查与逻辑推演。

## 这个包里有什么

**数据安全（这是这轮的主线）**

- 导入空备份不再清库：拒绝并提示，原数据一条不动
- 启动时存档解码失败，不再静默用空库覆盖原文件：先把坏文件改名成 `gsjilu.json.broken-<日期>` 留证
- 导入前自动快照 + 二次确认 + 提供「恢复导入前的数据」
- 无有效数据的整库文件（`{"records":{}}`）整份拒绝
- 记录值畸形（`[]` / `"x"` / `null`）或好消息里掺一条坏记录：整份拒绝，不做部分导入
- 旧格式 `c/p/t/w` 短键的备份不再把工时读成 0
- 记录日期键格式非法（`2026-1-1`、平年的 `2026-02-29`）整份拒绝

**交互修正**

导入弹窗不再被 sheet 吞掉、恢复行带快照时间、计数为 0 时文案不再读反、确认弹窗带文件名、主按钮改「替换并导入」、系统错误有中文兜底、恢复行整行一个无障碍 label。

**结构**

日历格子数据层重构（`DayCellData` + 父层按 revision 预计算）、`Store(payload:dataURL:)` 可注入测试路径、单测 target `WorkHoursTests`。

## 这个包里没有

- 批一：字号跟随系统、几何 `@ScaledMetric`、选中态对比度 —— 等这次编过再开
- 动效批：删 flip 层、`reduceMotion`、曲线重做
- iOS 17 降级：工程目标仍是 `IPHONEOS_DEPLOYMENT_TARGET = 26.0`

## 怎么编

需要 macOS + Xcode 26（SDK 26.x）+ xcodegen。

```sh
brew install xcodegen      # 已装可跳过
cd swiftui
xcodegen generate
xcodebuild -project WorkHours.xcodeproj -scheme WorkHours \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build
```

产物在 `swiftui/build/Build/Products/Release-iphoneos/WorkHours.app`。

打成未签名 IPA：

```sh
cd swiftui/build/Build/Products/Release-iphoneos
mkdir -p Payload && cp -R WorkHours.app Payload/
zip -qry WorkHours-fixed-unsigned.ipa Payload
```

## 编译报错了怎么办

把 `error:` 开头的原文整段贴回群里，我来定位。第一次编大概率是配置层问题（`TEST_HOST` / `BUNDLE_LOADER` 指向、xcodegen 参数、模拟器），不一定是产品代码 —— 别一看到红就以为这批改动全砸了。

## 已知：单测里有几条会红，不是编译问题

`swiftui/WorkHoursTests/` 是**按修复前的行为写的早期版本**，其中几条断言与新语义正面冲突，例如「整库 JSON 只带 records 也能导入」——这条现在的正确行为是**必须拒绝**。

所以：

- **只编 App**：不受任何影响，放心编。
- **跑单测**：先别把那几条红当成失败，测试线已经在另一条分支把这批断言改好了，等 CI 接通再并进来。真要现在跑：`xcodebuild test -project WorkHours.xcodeproj -scheme WorkHours -destination 'platform=iOS Simulator,name=<任一 iPhone>' CODE_SIGNING_ALLOWED=NO`。

## 验证过的和没验证过的

**验过**：76 个文件与仓库 `main` 逐字节一致（起点）、各条修复的代码位置与逻辑路径经两条线交叉静态复核、新增符号无悬空引用、无冲突标记。

**没验过**：一次都没编译，一次都没跑过测试，一次都没上过真机。任何「应该能过」的判断都是推演。
