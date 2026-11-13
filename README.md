# 工时记录 · WorkHours

**适合中国人的工时记录 App · 零人工 · 纯 AI 编写**

作者 / 维护：**Dream.or**

按日历记下每天上什么班、干了几个小时，自动算加班费、补贴和当月工资，月底直接看报表。不用注册、不联网，数据只存在手机本地。

![App 图标](shell/icons/AppIcon1024.png)

## 为什么做这个东西

国内工厂、车间、门店的工时算法跟国外工时 App 的设计习惯对不上：班次分白班夜班、加班要区分平时和周末、有发薪日、有年假和调休、节假日还有三倍工资。市面上的工时 App 大多按国外工作习惯做，班次、补贴、发薪周期都改不动。

这个项目把国内实际用得上的那套直接写进去，配置项全部开放：班次时长、时薪、加班倍率、补贴、发薪日、年假额度，都能在设置里改成自己厂里的规则。

## 功能

- **日历记录**：月历一屏看全，哪天记了工时、上的是什么班、节假日和周末、发薪日，用颜色和角标标出来；节假日、周末、发薪日的文字标识放在日期右侧
- **班次管理**：自己建班次（白班 / 夜班 / 早班…），每个班次可预设上下班时间和默认时长，记工时点一下带出
- **工时明细**：一天可拆成正常工时、加班工时、请假或调休，按项目分别计薪
- **批量设置**：日历里多选任意几天，统一设成同一个班次，一周的排班一分钟录完
- **项目与薪资**：多项目并行，每个项目单独设时薪；「薪资设置」和「项目管理」合并成一个入口，不用两处改
- **补贴与扣款**：固定补贴、按天自动补贴、临时补贴 / 扣款，支持一键复用上月数据
- **年假管理**：年度额度、已用天数、剩余天数自动计算
- **工资计算器**：临时算一笔，不写进记录
- **统计报表**：月度与年度统计，十二个月柱状图用不同颜色区分正常工时、加班工时和补贴
- **提醒**：每天固定时间提醒记账
- **备份还原**：整库导出 / 导入，换手机不丢数据
- **外观**：多套主题、顶部卡片圆角可调、状态栏跟随背景不出现色差

## 技术

- Objective-C + UIKit，纯原生，没有第三方库，没有 CocoaPods / SPM 依赖
- 单 target，底部毛玻璃质感 TabBar 和页面切换动画都是手写的，支持 iOS 15 及以上
- 数据存在 App 沙盒 Documents 下的一个 plist 文件里，不上传、不联网、没有账号体系
- 图标全部用 SF Symbols，农历和节假日用系统日历换算

## 目录

```
native/           全部 .h / .m 源码：AppDelegate、SceneDelegate、
                  十个 ViewController、数据层 GSStore、公共组件
shell/            Info.plist 与 App 图标
docs/             功能需求规格（PDR）与操作作业规程（SOP）
build_native.sh   编译脚本
```

## 自己编译

需要 iOS SDK（`iPhoneOSxx.x.sdk`）、`clang`、`ld64.lld`。

```sh
SDKROOT=/path/to/iPhoneOS27.2.sdk ./build_native.sh
```

脚本逐个编译 `native/*.m`，用 `ld64.lld` 链接成 arm64 可执行文件，做 ad-hoc 签名，再把 `Payload` 打成未签名 ipa，输出到 `out/`。装到未越狱设备上需要自己用 AltStore、Sideloadly 这类工具重签。

## 云端自动编译

没有 Mac 也能出包。仓库自带 `.github/workflows/build-ipa.yml`：推到 `main` 或者手动触发，GitHub 会分配一台临时 Mac（预装 Xcode），编译、组装、打成未签名 ipa，然后作为 artifact 上传。

产物在 **Actions → 某次运行 → 页面底部的 Artifacts** 里，下载下来是一个 zip，里面有 `工时记录-x.y.z-unsigned.ipa`。artifact 默认保留 90 天。

公开仓库的 macOS runner 不花钱；私有仓库要算额度，而且 macOS 是按 10 倍时长扣的。

## SwiftUI 版（swiftui/ 目录）

UIKit 版之外的第二个实现，界面换成 iOS 26 的液态玻璃，功能对齐 UIKit 版。两版各自独立，数据文件同名但沙盒分开，互不影响。

- 纯 SwiftUI，最低 iOS 26.0，没有第三方依赖
- 玻璃效果用系统 `.glassEffect()`，TabBar、弹窗、按钮自动带液态玻璃
- `swiftui/project.yml` 用 XcodeGen 描述工程，`swiftui/WorkHours/` 是全部源码
- 目录：`Model/` 数据与计算，`UI/` 页面与玻璃组件，`WorkHoursApp.swift` 入口
- 构建工作流：`.github/workflows/build-swiftui.yml`，推 `main` 或手动触发，产物是未签名 ipa

本地构建（需要 Xcode 26 或更新）：

```sh
cd swiftui
brew install xcodegen     # 只需一次
xcodegen generate
open WorkHours.xcodeproj  # 或者用下面的命令行
xcodebuild -project WorkHours.xcodeproj -scheme WorkHours \
  -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO build
```

Bundle ID 是 `cn.gongshijilu.jxt.swiftui`，和 UIKit 版分开，可以同时装在一台手机上。

## 已知限制

- 只有 iOS 端，没有 Android，没有云端同步
- 未签名 ipa 只能自签安装，证书过期要重签
- 数据只在本机，卸载 App 会一起清掉，换机前记得先导出备份
- 编译脚本是按 Linux / 无 Xcode 环境（clang + ld64.lld）写的；在 Mac 上改成 Xcode 工程会更省事

## 关于「零人工、纯 AI」

这个 App 的代码全部由 AI 生成：提需求、验收、决定下一次改哪里由人来做，写代码、查错、打包由 AI 完成，没有一行是手敲的。放在这里作为一份公开样本。

## 许可

MIT 许可，见 [LICENSE](LICENSE)。作者署名：**Dream.or**。
