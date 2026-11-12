# 工时记录（GSJilu）SwiftUI 重写规格

目标：根据已有 UIKit IPA `WorkHours-3.1.1-unsigned.ipa` 还原功能与中文文案，重写成 SwiftUI，保持本地数据、不登录、无广告、无云同步。

## 身份

- 显示名：工时记录
- 内部名：GSJilu
- Bundle ID：`com.dream.gsjilu`（必须一致，方便 Dream 用原证书签名）
- 版本：3.2.0（SwiftUI 重写）；build：29
- 最低系统：iOS 15.0
- 设备：iPhone only，竖屏，全屏
- 分类：productivity
- 本地化：zh_CN
- 图标：使用 `assets/AppIcon60x60@2x.png` 与 `assets/AppIcon60x60@3x.png`（来自原 IPA）
- Info.plist 要点：`UIFileSharingEnabled=YES`，`LSSupportsOpeningDocumentsInPlace=YES`，`NSAllowsArbitraryLoads=YES`，`UILaunchScreen={}`，状态栏 dark content，需通知权限说明（本地提醒）
- 原包未签名要求：本工程也只需产出未签名 IPA；不要配置开发者证书

## 原应用结构（从 Mach-O 还原，无 Swift/SwiftUI）

底部四 Tab：记录、统计、排班、我的。另有编辑工时、批量设置、项目编辑、班次、考勤周期、软件设置、工资计算器、补扣管理等页面。

## 数据（本地 JSON）

主文件名：`gsjilu.json`（Documents 或 App Group 本地）。备份扩展名：`.gsjilu`，导出文件名格式：`工时记录备份-%@.gsjilu`。导入会覆盖项目、班次、设置和全部工时记录。清空记录只清工时和排班，保留项目、班次、设置。

必须使用从二进制里看到的这些字段名（便于兼容原备份，能解析的键就解析，缺的给合理默认）：

settings / 根级常见键：
`version, theme, weekStart, nightMode, recordMode, reminderEnabled, reminderHour, reminderMinute, payday, cardRadius, cardShadow, animations, showLunar, headerRadius, autoAllowance, autoCarryMonth, dayAllowance, nightAllowance, annualLeaveDays, defaultWork, currentClass, period, customPeriods, classDisplay, projects, classes, records, plans, bonuses, deductions, extras, salary, exportedAt`

项目 `projects[]`：`id, name, rates`（底薪 base、正班 zb、加班 ot/jb、周末 zm、节假 jj），可能有日结 `settle`。默认示例项目名「祥发模具」。文案：底薪和四类时薪只在本项目生效；修改后已记录工时的工资按新费率重算。可设为当前项目。

班次 `classes[]`：`id, name, classDefaults`（默认正班/加班/周末/节假时长）。预置：白班、早班、中班、晚班。可设默认班次。

记录 `records[]`：日期、`projectId`、`classId`、`classDisplay`、`hours`（正班/加班/周末/节假/休假）、`work`、`workPay`、日结、备注 `note`、补贴扣款、班次自动补助。

排班 `plans[]`：日期 + 班次。排班只做标记，不自动生成工时。

补扣：月度/每日；类型分补贴 `bonuses` 与扣款 `deductions`；来源分自动补助、上月自动导入 `autoCarryMonth`、手动添加。字段含 `name, money, note, type, multiple, auto` 等。日结「填了就不按工时算」。补扣可「按倍数算补贴/扣款」。病假/事假/调休/薪假。薪假按 8H/天从年假余额扣除。

## 工资算法（必须实现）

- 工时工资 = 底薪 + 正班时薪×正班时数 + 加班时薪×加班时数 + 周末时薪×周末时数 + 节假时薪×节假时数
- 若该日记了「日结」金额，则当天不按工时算（用日结）
- 实发 = 工时工资（或日结）+ 补贴 - 扣款
- 工资计算器按当前项目费率试算：底薪、四类时数、补贴、扣款；文案说明不含社保个税
- 正常工时自动落到正班/周末/节假；加班统一记加班。识别周末和中国法定节假日（含常见调休，至少覆盖 2024–2027）
- 考勤周期：默认文案提到「还没有自定义周期，默认按 26 号 - 下月 25 号」；也支持每月 1 号-月底；「原版 29 档：每月 1~29 号起算，命中自定义周期时优先用自定义区间」
- 班次自动补助：白班/早班 → 白班补助；中班/晚班/夜班 → 夜班补助；填 0 即关闭并清除已有自动补助。记录工时时自动带入（可关）
- 夜班模式：默认选中昨天日期

## 界面与文案

所有用户可见中文必须尽量使用 `assets/ustrings.txt` 里的原句，不要随意改写。主题色：海蓝 blue、青绿 teal、葡萄紫 purple、日落橙 orange、樱花粉 pink、森林绿 green。日历可选农历、节/休/薪标记；发薪日当天日号金色，左上角「薪」，底栏金条。班次标记：图标（太阳/月亮）/ 文本（白班/夜班）/ 不显示。卡片圆角、阴影、动画、顶部色块圆角可调。

### 记录 Tab
日历月视图 + 当天工时摘要；回到今天；记一笔；批量设置工时；删除当前工时。当天类型、班次、项目、加班、按项目时薪、日结、补扣、备注。批量：选多天、每天工时/正常+加班、只填充没有记录的日期、跳过周末、批量休假、批量清空、批量补贴。校验：正常和加班不能都为 0 也不能为负。

### 统计 Tab
按考勤周期看本期合计（总工时、出勤、补贴、扣款、平均时薪、加班/周末/节假）、收入构成、工时构成、每日明细、补扣明细（可管理）、复制报表。年度看板：总工时、出勤、平均时薪、加班、排班、日均/月均、年假使用、十二个月工时结构、月度工资趋势、导出 HTML 报表（样式见原 IPA 内嵌 CSS，文件名 `工时记录-%ld-看板.html`）。

### 排班 Tab
先选班次再点日期切换；显示已排/未排天数；清除。

### 我的 Tab
分组：记录与薪资（记录设置、薪资与项目、工资计算器）、班次管理、考勤周期、个性化/软件设置、数据（导出/导入 .gsjilu、清空记录）。页脚：`工时记录 3.2.0 · 数据只存在本机`（版本随新版本）。关于文案保留「数据只存在本机；登录、VIP、广告、云同步不包含」。

记录设置：考勤周期、发薪日、每周工作日起算（周一/周日）、夜班模式、日补扣自动记录、班次自动补助金额、年假额度、打卡记录方式（时长记录/时间记录）、默认时长、每天本地通知提醒。
个性化：班次标记、卡片圆角/阴影、动画、农历、顶部色块圆角、主题色彩。

## 其他

- 本地通知：`GSRecordDailyReminder`，关闭开关取消通知，不上传数据
- 文件共享/打开文档以导入备份
- 不要用 SwiftUI `#Preview` 宏（若以后用 Linux 工具链会失败）；可用 `#if DEBUG` 包起来或不用
- 工程形态：SwiftPM executable（Package.swift，platforms iOS 15+）+ 一份 GitHub Actions workflow，在 `macos-latest` 上用 `xcodebuild` 打出 **CODE_SIGNING_ALLOWED=NO** 的未签名 IPA 作为 artifact
- 同时尽量提供可用的 Xcode 工程（可用 `swift package generate-xcodeproj` 或手写 pbxproj，或 README 写明在 Mac 上用 Xcode 打开 Package.swift）
- README 用中文，说明如何在 Mac 上打包未签名 IPA，以及数据/备份说明
- 不要尝试在 Linux 上通过非官方 iOS SDK 镜像交叉编译；本环境是 Linux，没有 Xcode

完整原文字符串：`assets/ustrings.txt`
原 cstring / 字段名：`assets/cstrings.txt`
原 Info.plist：`assets/original-Info.plist`
