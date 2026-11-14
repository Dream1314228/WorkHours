import Foundation
import Testing
@testable import WorkHours

// MARK: - 第 7 组：Cal 纯函数

struct CalTests {
    @Test func 跨年加减月() {
        let back = Cal.monthAdd(2026, 1, -1)
        #expect(back.year == 2025)
        #expect(back.month == 12)

        let fwd = Cal.monthAdd(2025, 12, 1)
        #expect(fwd.year == 2026)
        #expect(fwd.month == 1)

        let same = Cal.monthAdd(2026, 6, 0)
        #expect(same.year == 2026)
        #expect(same.month == 6)
    }

    @Test func 负年份边界走截断除法() {
        // 已知限制：idx 为负时 Swift 的 / 向零截断、% 得负数，月份会落到 0。
        // 正常日历路径不会走到公元 0 年以前，这里只把行为钉住，改了要回来确认没有连带影响。
        let edge = Cal.monthAdd(0, 1, -1)
        #expect(edge.year == 0)
        #expect(edge.month == 0)
    }

    @Test func 每月天数含闰年() {
        #expect(Cal.daysInMonth(2024, 2) == 29)
        #expect(Cal.daysInMonth(2026, 2) == 28)
        #expect(Cal.daysInMonth(2026, 1) == 31)
        #expect(Cal.daysInMonth(2026, 4) == 30)
    }

    @Test func 星期按一到七映射() {
        #expect(Cal.weekday("2026-01-01") == 5)   // 周四
        #expect(Cal.weekday("2026-01-03") == 7)   // 周六
        #expect(Cal.weekday("2026-01-04") == 1)   // 周日
        #expect(Cal.weekday("2026-01-05") == 2)   // 周一
        #expect(Cal.weekdayName("2026-01-01") == "周四")
        #expect(Cal.weekdayShort("2026-01-04") == "日")
        #expect(Cal.isWeekend("2026-01-03"))
        #expect(Cal.isWeekend("2026-01-04"))
        #expect(!Cal.isWeekend("2026-01-05"))
    }

    @Test func 日期键往返一致() {
        for key in ["2026-03-02", "2026-01-01", "2024-02-29", "2026-12-31"] {
            #expect(Cal.key(Cal.date(key)) == key)
            #expect(Cal.year(key) == Int(key.prefix(4)))
            #expect(Cal.month(key) == Int(key.dropFirst(5).prefix(2)))
            #expect(Cal.day(key) == Int(key.suffix(2)))
        }
    }

    @Test func 非法日期键不崩() {
        // 不参与取值断言，只要求不崩、不 return 可选值
        _ = Cal.date("")
        _ = Cal.date("abc")
        _ = Cal.date("2026-13-45")
        _ = Cal.date("2026-00-00")
    }

    /// 42 格首日偏移公式 `(weekday - 1 - weekStart + 7) % 7`。
    /// 目前这段是内联在 `UI/MonthCalendar.swift` 里的，`Cal` 没有对应函数，
    /// 所以只能先把两种起点的期望值写成禁用用例留档；等它提成 `Cal.weekStartOffset` 再放开。
    @Test func 四十二格首日偏移() {
        // 2026-01-01 是周四（weekday = 5）。这个用例原先禁用以等待 Cal.weekStartOffset，
        // 修复版已经把这个算式提成函数，所以放开并改为直接测那个函数。
        let mondayOffset: Int = Cal.weekStartOffset(year: 2026, month: 1, weekStart: 1)
        let sundayOffset: Int = Cal.weekStartOffset(year: 2026, month: 1, weekStart: 7)
        #expect(mondayOffset == 3)   // 周一开头：前面空 3 格（周一 二 三）
        #expect(sundayOffset == 4)   // 周日开头：前面空 4 格（周日 一 二 三）
    }
}

// MARK: - 第 3 组：考勤期

struct PeriodTests {
    @Test func 二十六号起算() {
        let s = FX.store(FX.payload(period: 26))
        let r = s.periodRange(year: 2026, month: 1)
        #expect(r.start == "2026-01-26")
        #expect(r.end == "2026-02-25")
        #expect(r.label == "1.26 - 2.25")
    }

    @Test func 自然月模式() {
        // 反向用例：period=1 时不该有任何跨月
        let s = FX.store(FX.payload(period: 1))
        let r = s.periodRange(year: 2026, month: 2)
        #expect(r.start == "2026-02-01")
        #expect(r.end == "2026-02-28")
        #expect(r.label == "1 号 - 月底")
    }

    @Test func 期号越界解码夹回26() {
        let big = try? JSONDecoder().decode(Settings.self, from: Data(#"{"period":45}"#.utf8))
        #expect(big?.period == 26)
        let zero = try? JSONDecoder().decode(Settings.self, from: Data(#"{"period":0}"#.utf8))
        #expect(zero?.period == 26)
        let ok = try? JSONDecoder().decode(Settings.self, from: Data(#"{"period":1}"#.utf8))
        #expect(ok?.period == 1)
    }

    @Test func 手动期优先于默认规律() {
        var d = FX.payload(period: 26)
        d.settings.customPeriods = [CustomPeriod(start: "2026-01-20", end: "2026-02-19")]
        let s = FX.store(d)
        let r = s.periodRange(year: 2026, month: 1)
        #expect(r.start == "2026-01-20")
        #expect(r.end == "2026-02-19")
    }

    @Test func 今天落进哪一期() {
        let s = FX.store(FX.payload(period: 26))
        let feb = s.currentPeriodKey(today: "2026-02-20")      // 1.26 ~ 2.25
        #expect(feb.year == 2026)
        #expect(feb.month == 1)

        let firstDay = s.currentPeriodKey(today: "2026-01-26") // 起始日当天
        #expect(firstDay.year == 2026)
        #expect(firstDay.month == 1)

        let lastDay = s.currentPeriodKey(today: "2026-01-25")  // 上一期最后一天
        #expect(lastDay.year == 2025)
        #expect(lastDay.month == 12)
    }

    @Test func 二十九号起算在平年二月重叠() {
        // 缺陷 DEF-07：period=29 + 平年 2 月，1 月期与 2 月期都含 2026-02-28
        let s = FX.store(FX.payload(period: 29))
        let jan = s.periodRange(year: 2026, month: 1)
        let feb = s.periodRange(year: 2026, month: 2)
        #expect(jan.start == "2026-01-29")
        #expect(jan.end == "2026-02-28")
        #expect(feb.start == "2026-02-28")
        #expect(feb.end == "2026-03-28")
        withKnownIssue("DEF-07：两期都覆盖 2026-02-28，这一天会被两期各算一次") {
            #expect(jan.end != feb.start)
        }
    }

    @Test func 闰年二月不重叠() {
        // 反向用例：闰年 2 月有 29 天，period=29 时 2 月期从 2-29 起，不与 1 月期重叠
        let s = FX.store(FX.payload(period: 29))
        let jan = s.periodRange(year: 2024, month: 1)
        let feb = s.periodRange(year: 2024, month: 2)
        #expect(jan.start == "2024-01-29")
        #expect(jan.end == "2024-02-28")
        #expect(feb.start == "2024-02-29")
        #expect(jan.end != feb.start)
    }
}
