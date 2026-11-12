import SwiftUI
import UIKit

enum GSAppInfo {
    static let displayName = "工时记录"
    static let version = "3.2.0"
    static let build = "29"
    static let bundleId = "com.dream.gsjilu"
}

let GSPageMargin: CGFloat = 18
let GSCardPadding: CGFloat = 18
let GSDefaultCardRadius: CGFloat = 20

func GSColorHex(_ hex: String, alpha: CGFloat = 1) -> Color {
    Color(uiColor: GSUIColorHex(hex, alpha: alpha))
}

func GSUIColorHex(_ hex: String, alpha: CGFloat = 1) -> UIColor {
    var s = hex.replacingOccurrences(of: "#", with: "")
    if s.count == 3 {
        s = s.map { "\($0)\($0)" }.joined()
    }
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return UIColor(
        red: CGFloat((v >> 16) & 0xFF) / 255.0,
        green: CGFloat((v >> 8) & 0xFF) / 255.0,
        blue: CGFloat(v & 0xFF) / 255.0,
        alpha: alpha
    )
}

func GSTextPrimary() -> Color { GSColorHex("#101828") }
func GSTextSecondary() -> Color { GSColorHex("#667085") }
func GSTextTertiary() -> Color { GSColorHex("#98A2B3") }
func GSTextStrong() -> Color { GSColorHex("#344054") }
func GSSurfaceMuted() -> Color { GSColorHex("#F4F7FB") }
func GSBorderColor() -> Color { GSColorHex("#EDF1F7") }
func GSSuccessColor() -> Color { GSColorHex("#067647") }
func GSWarningColor() -> Color { GSColorHex("#B54708") }
func GSDangerColor() -> Color { GSColorHex("#B42318") }
func GSMoneyColor() -> Color { GSColorHex("#B45309") }
func GSPageBackground() -> Color { GSColorHex("#F2F5FA") }

func GSRound2(_ v: Double) -> Double { (v * 100.0).rounded() / 100.0 }

func GSNum(_ v: Double) -> String {
    if abs(v - v.rounded()) < 0.001 {
        return String(format: "%.0f", v)
    }
    return String(format: "%.2f", v)
}

func GSMoney(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencySymbol = "¥"
    f.locale = Locale(identifier: "zh_CN")
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 2
    return f.string(from: NSNumber(value: GSRound2(v))) ?? "¥0"
}

enum GSTheme {
    static let keys = ["blue", "teal", "purple", "orange", "pink", "green"]
    static let names = ["海蓝", "青绿", "葡萄紫", "日落橙", "樱花粉", "森林绿"]
    static let table: [String: (String, String, String)] = [
        "blue":   ("海蓝", "#1E5BD6", "#2563EB"),
        "teal":   ("青绿", "#0F766E", "#14B8A6"),
        "purple": ("葡萄紫", "#7C3AED", "#8B5CF6"),
        "orange": ("日落橙", "#EA580C", "#F97316"),
        "pink":   ("樱花粉", "#DB2777", "#EC4899"),
        "green":  ("森林绿", "#16A34A", "#22C55E")
    ]

    static func name(for key: String) -> String { table[normalized(key)]?.0 ?? "海蓝" }
    static func hex(for key: String) -> String { table[normalized(key)]?.1 ?? "#1E5BD6" }
    static func darkHex(for key: String) -> String { table[normalized(key)]?.2 ?? "#2563EB" }
    static func color(for key: String) -> Color { GSColorHex(hex(for: key)) }
    static func darkColor(for key: String) -> Color { GSColorHex(darkHex(for: key)) }
    static func softColor(for key: String) -> Color { color(for: key).opacity(0.12) }
    static func normalized(_ key: String) -> String { table[key] != nil ? key : "blue" }
}

enum GSDate {
    static let posix: Locale = Locale(identifier: "en_US_POSIX")
    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = TimeZone.current
        return c
    }()
    static let chinese: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.timeZone = TimeZone.current
        return c
    }()

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = posix
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(from date: Date) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date { formatter.date(from: key) ?? Date() }
    static func todayKey() -> String { key(from: Date()) }

    static func weekdayName(_ key: String) -> String {
        let w = gregorian.component(.weekday, from: date(from: key))
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[(w - 1 + 7) % 7]
    }

    static func relativeDay(_ key: String) -> String {
        let a = date(from: todayKey())
        let b = date(from: key)
        let n = Int((a.timeIntervalSince(b) / 86400.0).rounded())
        if n == 0 { return "今天" }
        if n == 1 { return "1天前" }
        if n > 1 { return "\(n)天前" }
        if n == -1 { return "明天" }
        return "\(abs(n))天后"
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = 1
        guard let d = gregorian.date(from: c) else { return 30 }
        return gregorian.range(of: .day, in: .month, for: d)?.count ?? 30
    }

    static func monthAdd(year: Int, month: Int, delta: Int) -> (year: Int, month: Int) {
        let idx = year * 12 + (month - 1) + delta
        var y = idx / 12
        var m = idx % 12
        if m < 0 { m += 12; y -= 1 }
        return (y, m + 1)
    }

    static func components(from key: String) -> (year: Int, month: Int, day: Int) {
        let d = date(from: key)
        return (
            gregorian.component(.year, from: d),
            gregorian.component(.month, from: d),
            gregorian.component(.day, from: d)
        )
    }

    static func monthKey(_ year: Int, _ month: Int) -> String {
        String(format: "%04ld-%02ld", year, month)
    }

    static func dayKey(_ year: Int, _ month: Int, _ day: Int) -> String {
        String(format: "%04ld-%02ld-%02ld", year, month, day)
    }
}

enum GSLunar {
    static let days = [
        "初一","初二","初三","初四","初五","初六","初七","初八","初九","初十",
        "十一","十二","十三","十四","十五","十六","十七","十八","十九","二十",
        "廿一","廿二","廿三","廿四","廿五","廿六","廿七","廿八","廿九","三十"
    ]
    static let months = ["正月","二月","三月","四月","五月","六月","七月","八月","九月","十月","冬月","腊月"]

    static func day(_ date: Date) -> String {
        let d = GSDate.chinese.component(.day, from: date)
        if d < 1 || d > 30 { return "" }
        return days[d - 1]
    }

    static func full(_ date: Date) -> String {
        let c = GSDate.chinese.dateComponents([.month, .day, .year], from: date)
        let m = c.month ?? 0
        if m < 1 || m > 12 { return day(date) }
        var month = months[m - 1]
        if c.isLeapMonth == true { month = "闰" + month }
        return month + day(date)
    }
}

enum GSHoliday {
    /// Official State Council holiday rest days (label = festival name).
    /// 2026 matches the original 3.1.1 table exactly; 2024/2025/2027 are official notices
    /// added so weekend/holiday recognition also works outside 2026.
    static let holidays: [String: String] = {
        var d: [String: String] = [:]
        // 2024
        d["2024-01-01"] = "元旦"
        for k in range("2024-02-10", "2024-02-17") { d[k] = "春节" }
        for k in range("2024-04-04", "2024-04-06") { d[k] = "清明" }
        for k in range("2024-05-01", "2024-05-05") { d[k] = "劳动节" }
        for k in range("2024-06-08", "2024-06-10") { d[k] = "端午" }
        for k in range("2024-09-15", "2024-09-17") { d[k] = "中秋" }
        for k in range("2024-10-01", "2024-10-07") { d[k] = "国庆" }
        // 2025
        d["2025-01-01"] = "元旦"
        for k in range("2025-01-28", "2025-02-04") { d[k] = "春节" }
        for k in range("2025-04-04", "2025-04-06") { d[k] = "清明" }
        for k in range("2025-05-01", "2025-05-05") { d[k] = "劳动节" }
        for k in range("2025-05-31", "2025-06-02") { d[k] = "端午" }
        for k in range("2025-10-01", "2025-10-08") { d[k] = "国庆" }
        d["2025-10-06"] = "中秋"
        // 2026 (identical to GSCommon.m)
        for k in range("2026-01-01", "2026-01-03") { d[k] = "元旦" }
        for k in range("2026-02-16", "2026-02-22") { d[k] = "春节" }
        for k in range("2026-04-04", "2026-04-06") { d[k] = "清明" }
        for k in range("2026-05-01", "2026-05-05") { d[k] = "劳动节" }
        for k in range("2026-06-19", "2026-06-21") { d[k] = "端午" }
        for k in range("2026-09-25", "2026-09-27") { d[k] = "中秋" }
        for k in range("2026-10-01", "2026-10-07") { d[k] = "国庆" }
        // 2027 (国办发明电〔2026〕10号)
        for k in range("2027-01-01", "2027-01-03") { d[k] = "元旦" }
        for k in range("2027-02-05", "2027-02-13") { d[k] = "春节" }
        for k in range("2027-04-03", "2027-04-05") { d[k] = "清明" }
        for k in range("2027-05-01", "2027-05-05") { d[k] = "劳动节" }
        d["2027-06-09"] = "端午"
        d["2027-09-15"] = "中秋"
        for k in range("2027-10-01", "2027-10-07") { d[k] = "国庆" }
        return d
    }()

    /// Makeup workdays (weekends that are workdays). 2026 matches GSCommon.m.
    static let workdays: Set<String> = [
        "2024-02-04", "2024-02-18", "2024-04-07", "2024-04-28", "2024-05-11", "2024-09-14", "2024-09-29", "2024-10-12",
        "2025-01-26", "2025-02-08", "2025-04-27", "2025-09-28", "2025-10-11",
        "2026-02-14", "2026-02-28", "2026-04-26", "2026-05-09", "2026-09-20", "2026-10-10",
        "2027-01-31", "2027-02-14", "2027-05-08", "2027-09-26", "2027-10-09"
    ]

    static func holidayName(_ key: String) -> String? { holidays[key] }
    static func isWorkday(_ key: String) -> Bool { workdays.contains(key) }

    /// Day kind: jj / zm / zb. Matches GSDayKind.
    static func dayKind(_ key: String) -> String {
        if holidays[key] != nil { return "jj" }
        if isWorkday(key) { return "zb" }
        let w = GSDate.gregorian.component(.weekday, from: GSDate.date(from: key))
        return (w == 1 || w == 7) ? "zm" : "zb"
    }

    static func kindName(_ kind: String) -> String {
        switch kind {
        case "jj": return "节假"
        case "zm": return "周末"
        case "xiu": return "休假"
        default: return "正班"
        }
    }

    private static func range(_ start: String, _ end: String) -> [String] {
        var keys: [String] = []
        var d = GSDate.date(from: start)
        let last = GSDate.date(from: end)
        while d <= last {
            keys.append(GSDate.key(from: d))
            d = GSDate.gregorian.date(byAdding: .day, value: 1, to: d) ?? last.addingTimeInterval(86400)
        }
        return keys
    }
}

func GSKindName(_ kind: String) -> String { GSHoliday.kindName(kind) }
func GSDayKind(_ key: String) -> String { GSHoliday.dayKind(key) }
func GSHolidayName(_ key: String) -> String? { GSHoliday.holidayName(key) }
func GSIsWorkday(_ key: String) -> Bool { GSHoliday.isWorkday(key) }

func GSJSONNumber(_ value: Any?) -> Double {
    if let n = value as? NSNumber { return n.doubleValue }
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let s = value as? String { return Double(s) ?? 0 }
    return 0
}

func GSJSONInt(_ value: Any?) -> Int { Int(GSJSONNumber(value)) }

func GSJSONString(_ value: Any?) -> String? {
    if let s = value as? String { return s }
    return nil
}

func GSJSONBool(_ value: Any?, default def: Bool = false) -> Bool {
    if let b = value as? Bool { return b }
    if let n = value as? NSNumber { return n.boolValue }
    return def
}

func GSJSONDict(_ value: Any?) -> [String: Any] {
    value as? [String: Any] ?? [:]
}

func GSJSONArray(_ value: Any?) -> [Any] {
    value as? [Any] ?? []
}

func GSHaptic() {
    let g = UIImpactFeedbackGenerator(style: .light)
    g.prepare()
    g.impactOccurred()
}

extension View {
    func gsFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        let s = (size > 2 && size < 10) ? 10 : size
        return self.font(.system(size: s, weight: weight))
    }
}
