import Foundation

/// 日期、农历、节假日、考勤期的纯函数集合。
enum Cal {
    static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = .current
        c.firstWeekday = 1
        return c
    }()

    static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }

    /// 解析 yyyy-MM-dd。日历一屏 42 格、翻页三页都要用它，DateFormatter 太贵，
    /// 直接拆字符串走 DateComponents（Calendar 是值类型，不受线程影响）。
    static func date(_ key: String) -> Date {
        guard key.count >= 10,
              let y = Int(key.prefix(4)),
              let m = Int(key.dropFirst(5).prefix(2)),
              let d = Int(key.suffix(2)),
              y > 0, (1...12).contains(m), (1...31).contains(d) else { return Date() }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        return gregorian.date(from: comps) ?? Date()
    }
    static func todayKey() -> String { key(Date()) }
    static func year(_ key: String) -> Int { Int(key.prefix(4)) ?? 0 }
    static func month(_ key: String) -> Int {
        guard key.count >= 7 else { return 0 }
        return Int(key.dropFirst(5).prefix(2)) ?? 0
    }
    static func day(_ key: String) -> Int {
        guard key.count >= 10 else { return 0 }
        return Int(key.suffix(2)) ?? 0
    }

    static func daysInMonth(_ y: Int, _ m: Int) -> Int {
        let comps = DateComponents(year: y, month: m, day: 1)
        guard let d = gregorian.date(from: comps),
              let range = gregorian.range(of: .day, in: .month, for: d) else { return 30 }
        return range.count
    }

    static func monthAdd(_ y: Int, _ m: Int, _ delta: Int) -> (year: Int, month: Int) {
        let idx = y * 12 + (m - 1) + delta
        return (idx / 12, idx % 12 + 1)
    }

    /// 1 = 周日 … 7 = 周六
    static func weekday(_ key: String) -> Int {
        let w = gregorian.component(.weekday, from: date(key))
        return w
    }

    static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    static func weekdayName(_ key: String) -> String {
        weekdayNames[max(0, min(6, weekday(key) - 1))]
    }
    static func weekdayShort(_ key: String) -> String {
        ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, weekday(key) - 1))]
    }


    /// 只认 yyyy-MM-dd 这一种形状，且必须是真实存在的日期。
    /// 导入整库时用它挡掉日历和统计都筛不出来的"幽灵记录"（比如 2026-1-1、2026-2-30）。
    static func isValidKey(_ key: String) -> Bool {
        guard key.count == 10 else { return false }
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              y > 1970, (1...12).contains(m), (1...31).contains(d) else { return false }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        guard let date = gregorian.date(from: comps) else { return false }
        let back = gregorian.dateComponents([.year, .month, .day], from: date)
        return back.year == y && back.month == m && back.day == d
    }

    /// 某月 1 号在 7 列里占第几格。weekStart: 1 = 周一, 7 = 周日。
    /// 原来这段算式在 MonthCalendar / BatchSheet / CalendarPage / ShiftPage 各写了一遍，来这里收口。
    static func weekStartOffset(year: Int, month: Int, weekStart: Int) -> Int {
        let first = String(format: "%04d-%02d-01", year, month)
        return (weekday(first) - 1 - weekStart + 7) % 7
    }

    static func isWeekend(_ key: String) -> Bool {
        let w = weekday(key)
        return w == 1 || w == 7
    }

    // MARK: 农历

    static let lunarCalendar: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.timeZone = .current
        return c
    }()

    static let lunarDayNames = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                                "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                                "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    static let lunarMonthNames = ["正月", "二月", "三月", "四月", "五月", "六月",
                                  "七月", "八月", "九月", "十月", "冬月", "腊月"]

    static func lunarDay(_ key: String) -> String {
        let comps = lunarCalendar.dateComponents([.day], from: date(key))
        guard let d = comps.day, d >= 1, d <= 30 else { return "" }
        return lunarDayNames[d - 1]
    }

    static func lunarFull(_ key: String) -> String {
        let comps = lunarCalendar.dateComponents([.month, .day, .isLeapMonth], from: date(key))
        guard let m = comps.month, m >= 1, m <= 12, let d = comps.day, d >= 1, d <= 30 else {
            return lunarDay(key)
        }
        var name = lunarMonthNames[m - 1]
        if comps.isLeapMonth == true { name = "闰" + name }
        return name + lunarDayNames[d - 1]
    }

    /// 农历初一显示月名，其余显示日名，日历格子用。
    static func lunarCellText(_ key: String) -> String {
        let comps = lunarCalendar.dateComponents([.month, .day, .isLeapMonth], from: date(key))
        guard let m = comps.month, m >= 1, m <= 12, let d = comps.day else { return "" }
        if d == 1 {
            var name = lunarMonthNames[m - 1]
            if comps.isLeapMonth == true { name = "闰" + name }
            return name
        }
        return lunarDayNames[max(0, min(29, d - 1))]
    }

    // MARK: 节假日（表在 Holidays.swift，跨年可用 JSON 覆盖）

    static func holidayName(_ key: String) -> String? { HolidayData.shared.holidayName(key) }
    static func isMakeupWorkday(_ key: String) -> Bool { HolidayData.shared.isWorkday(key) }

    /// 默认记录类型：jj 节假 / zm 周末 / zb 正班
    static func dayKind(_ key: String) -> String {
        if HolidayData.shared.holidayName(key) != nil { return "jj" }
        if HolidayData.shared.isWorkday(key) { return "zb" }
        return isWeekend(key) ? "zm" : "zb"
    }

    static func leaveName(_ type: String) -> String {
        switch type {
        case "bing": return "病假"
        case "shi": return "事假"
        case "tiao": return "调休"
        default: return "薪假"
        }
    }

    static func kindName(_ kind: String) -> String {
        switch kind {
        case "jj": return "节假"
        case "zm": return "周末"
        case "xiu": return "休假"
        default: return "正班"
        }
    }

    // MARK: 展示

    static func monthTitle(year: Int, month: Int) -> String { "\(year) 年 \(month) 月" }
    static func shortDate(_ key: String) -> String {
        guard key.count >= 10 else { return key }
        return "\(month(key)) 月 \(day(key)) 日"
    }
    static func periodLabel(start: String, end: String) -> String {
        guard start.count >= 10, end.count >= 10 else { return "" }
        return "\(month(start)).\(day(start)) - \(month(end)).\(day(end))"
    }

    /// 数字格式化：整数不带小数点，其余最多两位
    static func num(_ v: Double) -> String {
        if abs(v.rounded() - v) < 0.005 { return String(format: "%.0f", v.rounded()) }
        return String(format: "%.2f", v)
    }

    static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    static func money(_ v: Double) -> String {
        "¥" + (moneyFormatter.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v))
    }

    static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
}
