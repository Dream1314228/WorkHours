# 工时记录（SwiftUI 重写）

这是「工时记录」3.1.1（UIKit / Objective-C）的 SwiftUI 重写，版本 **3.2.0**（Build **29**），用来和原版区分。

- Bundle ID：`com.dream.gsjilu`（与原版相同，便于沿用你自己的开发者证书）
- 显示名：工时记录
- 系统要求：iOS 15+，仅 iPhone，竖屏
- 数据全部在本机，无登录、无 VIP、无广告、无云同步

本仓库在 Linux 上只交付源码，**不包含、也不会生成 IPA**。未签名 IPA 需要在安装了官方 Xcode 的 Mac 上，或通过下面的 GitHub Actions 工作流构建。不要使用非官方 iOS SDK，也不要自行签名本仓库产出的包——签名请用你自己的证书在本地完成。

## 工程结构

```
workhours-swiftui/
├── Package.swift                 SwiftPM 可执行目标（platforms: iOS 15+）
├── GSJilu.xcodeproj/             供 xcodebuild 使用的 Xcode 工程与共享 Scheme
├── Sources/GSJilu/               全部 SwiftUI / 业务源码
│   ├── GSJiluApp.swift、RootView.swift
│   ├── Store.swift、Common.swift、Reminder.swift、HTMLReport.swift
│   ├── RecordView.swift、EditorView.swift、BatchView.swift
│   ├── StatsView.swift、ExtrasView.swift、ScheduleView.swift
│   ├── MeView.swift、SettingsViews.swift、Components.swift
├── Resources/
│   ├── Info.plist
│   ├── Assets.xcassets/          App 图标（源自原版 shell/icons，含 1024 与各尺寸）
│   └── AppIcon60x60@2x.png、AppIcon60x60@3x.png
├── scripts/build-unsigned-ipa.sh 本机 Mac 构建未签名 IPA
└── .github/workflows/build-unsigned-ipa.yml
```

SwiftPM 的 `Package.swift` 只声明源码目标；真正打出 `.app` / IPA 请用 `GSJilu.xcodeproj`。

## 在 Mac 上构建未签名 IPA

需要：macOS、已安装的官方 Xcode（含 iOS SDK）、命令行工具。

```bash
cd workhours-swiftui
bash scripts/build-unsigned-ipa.sh
```

脚本会执行：

```bash
xcodebuild \
  -project GSJilu.xcodeproj \
  -scheme GSJilu \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

然后把 `GSJilu.app` 放进 `Payload/`，打成：

`dist/GSJilu-3.2.0-unsigned.ipa`

这是**未签名**包。安装到真机前，请用你自己的开发者证书和描述文件签名（例如 Apple 的 `codesign` / `xcodebuild` 签名流程，或你惯用的签名工具）。不要把未签名 IPA 直接分发给无法自行签名的设备。

也可以在 Xcode 中打开 `GSJilu.xcodeproj`，选择 scheme `GSJilu`，在 Build Settings 里保持不签名，再 Archive 或用上面的命令构建。

## 用 GitHub Actions 构建

工作流文件：`.github/workflows/build-unsigned-ipa.yml`

- 运行环境：`macos-latest`
- 触发：手动 `workflow_dispatch`，以及向 `main` / `master` 的 push、pull request
- 构建方式：调用 `scripts/build-unsigned-ipa.sh`，其中 `xcodebuild` 使用 `CODE_SIGNING_ALLOWED=NO`
- 产物：以 artifact 名 `GSJilu-3.2.0-unsigned` 上传 `dist/*.ipa`

把本仓库推到 GitHub 后，打开 Actions，运行 “Build unsigned IPA”，下载 artifact 即可。同样是未签名包，需自行用证书签名后再安装。

## 数据与备份

所有数据只存在本机，不会上传。

- 主数据文件：应用沙盒 `Documents/gsjilu.json`（格式版本 `v == 2`）
- 文件共享已打开（`UIFileSharingEnabled` / iTunes / 文件 App 可见 Documents）
- 备份格式：`.gsjilu`，UTI 为 `com.dream.gsjilu.backup`
- 备份内容为紧凑字典（短键 `d,c,p,t,w,s,b,l,n` 等），再经 **LZFSE** 压缩，版本为备份格式 v4
- 「我的 → 导出备份 .gsjilu」会生成可分享的备份文件
- 「我的 → 导入 .gsjilu 备份」会先确认，再覆盖当前的项目、班次、设置和全部工时记录；导入前建议先导出一份当前备份
- 系统「打开文件」若指向 `.gsjilu`，应用也会走同一套导入确认
- 导入时先尝试 LZFSE，失败再尝试明文 JSON（相对原版 3.1.1 仅支持 LZFSE，这是一点兼容增强）
- 「清空记录」只清除工时、排班和月度补扣，保留项目、班次和设置

原版 3.1.1 的 `.gsjilu` 备份以及同 Bundle ID 升级后的 `gsjilu.json` 应可继续使用。

## 功能概要

四个主标签与原版一致：

1. **记录**：月历、日工时编辑、批量设置、夜班模式（6 点前默认选昨天）、节假日/调休、发薪日标记、日补扣自动记录
2. **统计**：按考勤周期汇总收入与工时、分类占比、日报复制、月度补贴/扣款管理（含上月导入）
3. **排班**：先选班次再点日期做标记（不自动生成工时）；年度看板（工时/收入/热力/明细）及 HTML 报表分享
4. **我的**：记录设置、薪资与项目、工资计算器、班次管理、考勤周期、软件设置（提醒、主题、圆角等）、备份导入导出、清空记录

工资、请假计薪、年假（薪假按 8 小时/天）、班次自动补助（白/早 → 白班补助，中/晚/夜 → 夜班补助）、自定义考勤周期、月末自动结转上月补扣等逻辑按 3.1.1 源码移植。月度「底薪」和项目 `mode`（`dxjs` / `gddx`）只参与工资计算器，不会加进周期/年度统计——这与原版一致。

本地通知标识为 `GSRecordDailyReminder-yyyy-MM-dd`，按设置时刻预排未来 14 天，已有记录或已过点的不排。

## 与原版 3.1.1 可能不一致的地方

- 原版 `GSCommon` 只写死了 2026 年节假日和 6 个补班日；本版按国务院通知补全了 **2024–2027** 年休息日与补班（2027 年依据国办发明电〔2026〕10号，2026-11-05 公布）
- SwiftUI 重写，视觉与交互动画无法做到像素级相同，文案与计算行为以源码为准
- `recordMode`（时长记录 / 时间记录）会写入设置，但 3.1.1 的编辑页并未使用时间记录模式，本版保持同样行为
- 导入备份在 LZFSE 之外额外接受明文 JSON
- 关于与页脚版本号显示为 3.2.0，不再写 3.1.1
- 本仓库不交付已签名 IPA；未签名 IPA 需在官方 Xcode / GitHub Actions 上构建

## 许可与归属

业务逻辑与文案来自「工时记录」3.1.1 源码的忠实移植，供持有该应用及开发者证书的本人使用。
