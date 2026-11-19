import Foundation
import ActivityKit

/// 灵动岛能显示的数据项。App 的配置页和 Widget 的渲染共用这一份清单，
/// 加一项只要在这里加 case，两边自动出现。
enum IslandField: String, CaseIterable, Identifiable, Codable {
    case todayHours      // 今日工时
    case todayPay        // 今日工资
    case need            // 今日应上
    case progress        // 工时进度
    case periodPay       // 本周期工资
    case monthHours      // 本月工时
    case monthPay        // 本月工资
    case streak          // 连续记账
    case paydayLeft      // 距发薪日
    case shift           // 班次
    case project         // 项目
    case leaveLeft       // 年假剩余

    var id: String { rawValue }

    var name: String {
        switch self {
        case .todayHours: return "今日工时"
        case .todayPay: return "今日工资"
        case .need: return "今日应上"
        case .progress: return "工时进度"
        case .periodPay: return "本期工资"
        case .monthHours: return "本月工时"
        case .monthPay: return "本月工资"
        case .streak: return "连续记账"
        case .paydayLeft: return "距发薪日"
        case .shift: return "班次"
        case .project: return "项目"
        case .leaveLeft: return "年假剩余"
        }
    }

    /// 紧凑区只能塞几个字，用短名
    var tight: String {
        switch self {
        case .todayHours: return "H"
        case .todayPay: return "¥"
        case .need: return "应"
        case .progress: return "%"
        case .periodPay: return "期"
        case .monthHours: return "月H"
        case .monthPay: return "月¥"
        case .streak: return "连"
        case .paydayLeft: return "发"
        case .shift: return "班"
        case .project: return "项"
        case .leaveLeft: return "假"
        }
    }
}

/// 灵动岛/锁屏活动的数据契约。改了字段名要连带改 widget 里的读取。
struct WorkIslandAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var todayHours: Double = 0
        var todayPay: Double = 0
        var periodPay: Double = 0
        var monthHours: Double = 0
        var monthPay: Double = 0
        var streak: Int = 0
        var paydayLeft: Int = 0
        var shift: String = ""
        var project: String = ""
        var leaveLeft: Double = 0
        var need: Double = 8
        var style: String = "dark"
        var compactLeading: String = IslandField.todayHours.rawValue
        var compactTrailing: String = IslandField.todayPay.rawValue
        var expanded: [String] = [
            IslandField.todayHours.rawValue,
            IslandField.todayPay.rawValue,
            IslandField.streak.rawValue
        ]
        var updatedAt: Date = Date()
    }

    var dateKey: String
}
