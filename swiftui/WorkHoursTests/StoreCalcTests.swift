import Foundation
import Testing
@testable import WorkHours

// MARK: - 第 1 组：dayPay

/// 默认项目单价 zb 12.82 / jb 19.23 / zm 25.64 / jj 38.46。
struct DayPayTests {
    @Test func 默认项目四段单价() {
        let s = FX.store(FX.payload())
        let p = s.project("default")
        expectClose(p.rates.zb, 12.82, "zb")
        expectClose(p.rates.jb, 19.23, "jb")
        expectClose(p.rates.zm, 25.64, "zm")
        expectClose(p.rates.jj, 38.46, "jj")
    }

    @Test func 正班8加班2等于141点02() {
        let s = FX.store(FX.payload(records: ["2026-03-02": FX.rec(zb: 8, jb: 2)]))
        expectClose(s.dayPay(s.record("2026-03-02")!), 141.02)
    }

    @Test func 四段都算() {
        let s = FX.store(FX.payload(records: [
            "2026-03-02": FX.rec(zb: 8, jb: 2, zm: 10, jj: 10)
        ]))
        // 102.56 + 38.46 + 256.4 + 384.6
        expectClose(s.dayPay(s.record("2026-03-02")!), 782.02)
    }

    @Test func 日结只加补助忽略工时() {
        let rec = FX.rec(zb: 8, jb: 2, settle: 300, bt: [BonusItem(name: "餐补", money: 20)])
        let s = FX.store(FX.payload(records: ["2026-03-02": rec]))
        expectClose(s.dayPay(s.record("2026-03-02")!), 320)
    }

    @Test func 请假按金额直加() {
        let rec = FX.rec(leave: LeaveInfo(type: "xiu", hour: 8, rule: "money", multiple: 0, money: 50))
        let s = FX.store(FX.payload(records: ["2026-03-03": rec]))
        expectClose(s.dayPay(s.record("2026-03-03")!), 50)
    }

    @Test func 请假按小时乘正班单价乘倍数() {
        let rec = FX.rec(leave: LeaveInfo(type: "xiu", hour: 4, rule: "hour", multiple: 1.5))
        let s = FX.store(FX.payload(records: ["2026-03-03": rec]))
        // 4 × 12.82 × 1.5 = 76.92
        expectClose(s.dayPay(s.record("2026-03-03")!), 76.92)
    }

    @Test func 负数补助从合计里扣() {
        let rec = FX.rec(zb: 8, bt: [BonusItem(name: "扣款", money: -20)])
        let s = FX.store(FX.payload(records: ["2026-03-02": rec]))
        expectClose(s.dayPay(s.record("2026-03-02")!), 82.56)
    }

    @Test func 单价取记录里的项目() {
        let rec = FX.rec(zb: 8, projectId: "2")
        let s = FX.store(FX.payload(records: ["2026-03-02": rec]))
        // 祥发模具 zb 18.97 → 151.76
        expectClose(s.dayPay(s.record("2026-03-02")!), 151.76)
    }

    @Test func 找不到项目回落到第一个() {
        let rec = FX.rec(zb: 8, projectId: "不存在的项目")
        let s = FX.store(FX.payload(records: ["2026-03-02": rec]))
        expectClose(s.dayPay(s.record("2026-03-02")!), 102.56)
    }
}

// MARK: - 第 2 组：自动补助

struct AllowanceTests {
    /// 种子班次 1 白班 / 2 早班 / 3 中班 / 4 晚班，另加 5 夜班、6 日班（无关键字）。
    static func classes() -> [ShiftClass] {
        var list = AppData().classes
        list.append(ShiftClass(id: "5", name: "夜班", color: "#224799"))
        list.append(ShiftClass(id: "6", name: "日班", color: "#FCB819"))
        return list
    }

    @Test func 班次名映射到补助名() {
        let s = FX.store(FX.payload(classes: Self.classes()))
        #expect(s.allowanceName(forClass: "1") == "白班补助")   // 白班
        #expect(s.allowanceName(forClass: "2") == "白班补助")   // 早班
        #expect(s.allowanceName(forClass: "3") == "夜班补助")   // 中班
        #expect(s.allowanceName(forClass: "4") == "夜班补助")   // 晚班
        #expect(s.allowanceName(forClass: "5") == "夜班补助")   // 夜班
        #expect(s.allowanceName(forClass: "6") == nil)          // 日班：无关键字
        #expect(s.allowanceName(forClass: "查无此班") == nil)
    }

    @Test func 总开关关时不加补助() {
        let s = FX.store(FX.payload(autoBonus: false))
        var r = FX.rec(zb: 8, classId: "3")
        s.ensureAutoAllowance(&r)
        #expect(r.bt.isEmpty)
    }

    @Test func 休假类型不加补助() {
        let s = FX.store(FX.payload())
        var r = FX.rec(type: "xiu", classId: "3", leave: LeaveInfo(type: "xiu", hour: 8))
        s.ensureAutoAllowance(&r)
        #expect(r.bt.isEmpty)
    }

    @Test func 没工时也没请假不加补助() {
        let s = FX.store(FX.payload())
        var r = FX.rec(classId: "3")
        s.ensureAutoAllowance(&r)
        #expect(r.bt.isEmpty)
    }

    @Test func 有工时加夜班补助20() {
        let s = FX.store(FX.payload())
        var r = FX.rec(zb: 8, classId: "3")
        s.ensureAutoAllowance(&r)
        #expect(r.bt.count == 1)
        #expect(r.bt.first?.name == "夜班补助")
        expectClose(r.bt.first?.money ?? 0, 20)
        #expect(r.bt.first?.autoAllowance == true)
    }

    @Test func 白班加白班补助10() {
        let s = FX.store(FX.payload())
        var r = FX.rec(zb: 8, classId: "1")
        s.ensureAutoAllowance(&r)
        #expect(r.bt.count == 1)
        #expect(r.bt.first?.name == "白班补助")
        expectClose(r.bt.first?.money ?? 0, 10)
    }

    @Test func 金额设0清掉旧的自动补助() {
        let s = FX.store(FX.payload(nightAllowance: 0))
        var r = FX.rec(zb: 8, classId: "3",
                       bt: [BonusItem(name: "夜班补助", money: 20, note: "自动补助", autoAllowance: true)])
        s.ensureAutoAllowance(&r)
        #expect(r.bt.isEmpty)
    }

    @Test func 已存在同名手加补助不重复加() {
        let s = FX.store(FX.payload())
        var r = FX.rec(zb: 8, classId: "3",
                       bt: [BonusItem(name: "夜班补助", money: 5, note: "自己加的", autoAllowance: false)])
        s.ensureAutoAllowance(&r)
        #expect(r.bt.count == 1)
        expectClose(r.bt.first?.money ?? 0, 5)
    }
}

// MARK: - 第 9 组：年假

struct AnnualLeaveTests {
    @Test func 只统计薪假并换算成天() {
        let records = [
            "2026-01-05": FX.rec(leave: LeaveInfo(type: "xiu", hour: 8)),   // 1 天
            "2026-01-06": FX.rec(leave: LeaveInfo(type: "shi", hour: 8)),   // 事假不算
            "2026-01-07": FX.rec(leave: LeaveInfo(type: "xiu", hour: 4)),   // 0.5 天
            "2025-12-31": FX.rec(leave: LeaveInfo(type: "xiu", hour: 8))    // 别的年份不算
        ]
        let s = FX.store(FX.payload(records: records, annualLeaveDays: 5))
        expectClose(s.annualLeaveUsed(year: 2026), 1.5)
        expectClose(s.annualLeaveRemaining(year: 2026), 3.5)
    }

    @Test func 年假小数按两位四舍五入() {
        let records = ["2026-01-05": FX.rec(leave: LeaveInfo(type: "xiu", hour: 3))]   // 0.375 天
        let s = FX.store(FX.payload(records: records, annualLeaveDays: 5))
        expectClose(s.annualLeaveUsed(year: 2026), 0.38)
    }
}

// MARK: - 第 5 组：月度 / 年度口径

/// 各月页按考勤期、年度页按自然月分桶 —— 两边口径不同，这里把差异钉死。
/// 口径一旦统一，本组断言会主动失败，提醒回来改。
struct StatsCaliberTests {
    @Test func 跨年记录年度页看不到但月页算得到() {
        // 2027-01-05 属于 2026 年 12 月那一期（12-26 ~ 01-25）
        let s = FX.store(FX.payload(period: 26, records: ["2027-01-05": FX.rec(zb: 8)]))
        expectClose(s.yearStats(year: 2026).pay, 0, "年度页按 2026- 前缀过滤，看不到 2027-01-05")
        expectClose(s.monthStats(year: 2026, month: 12).pay, 102.56, "月页按考勤期，算进 2026 年 12 月期")

        var sum = 0.0
        for m in 1...12 { sum += s.monthStats(year: 2026, month: m).pay }
        expectClose(sum, 102.56, "12 个月页之和")
        // DEF-06：年度合计 ≠ 12 个月页之和
        #expect(s.yearStats(year: 2026).pay != Cal.round2(sum))
    }

    @Test func 年初几天不在月页但在年度页() {
        // 2026-01-05 属于 2025 年 12 月期
        let s = FX.store(FX.payload(period: 26, records: ["2026-01-05": FX.rec(zb: 8)]))
        #expect(s.monthStats(year: 2026, month: 1).days == 0)
        #expect(s.yearStats(year: 2026).months[0].days == 1)
        expectClose(s.yearStats(year: 2026).pay, 102.56)
    }

    @Test func 自然月模式下两边一致() {
        // 反向用例：period=1 时没有跨期问题，年度合计应等于 12 个月页之和
        let s = FX.store(FX.payload(period: 1, records: [
            "2026-01-05": FX.rec(zb: 8),
            "2026-12-20": FX.rec(zb: 8)
        ]))
        var sum = 0.0
        for m in 1...12 { sum += s.monthStats(year: 2026, month: m).pay }
        expectClose(s.yearStats(year: 2026).pay, 205.12)
        expectClose(sum, 205.12)
    }

    @Test func 月度补贴扣款按月键计入() {
        let s = FX.store(FX.payload(
            period: 1,
            records: ["2026-03-10": FX.rec(zb: 8)],
            bonuses: ["2026-03": [BonusItem(name: "全勤", money: 200)]],
            deductions: ["2026-03": [BonusItem(name: "迟到", money: 50)]]
        ))
        let st = s.monthStats(year: 2026, month: 3)
        expectClose(st.pay, 252.56)      // 102.56 + 200 - 50
        expectClose(st.bonus, 200)
        expectClose(st.deduct, 50)
        expectClose(st.hours, 8)
        #expect(st.days == 1)
    }

    @Test func 用自然月口径取统计时排除跨期日() {
        let s = FX.store(FX.payload(period: 26, records: [
            "2026-01-05": FX.rec(zb: 8),     // 自然月 1 月，但属于 2025 年 12 月期
            "2026-01-27": FX.rec(zb: 8)      // 自然月 1 月，也属于 2026 年 1 月期
        ]))
        #expect(s.monthStats(year: 2026, month: 1, usePeriod: false).days == 2)
        #expect(s.monthStats(year: 2026, month: 1, usePeriod: true).days == 1)
    }
}
