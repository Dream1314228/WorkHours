import Foundation
import Testing
@testable import WorkHours

// MARK: - 第 8 组：休整天 / 休半天

/// 默认班次「1」是 8 正班 + 2 加班，应上按 8 算（不是 10）——这是这组的核心约定。
struct LeaveKindTests {

    @Test func 老数据请满折成休整天() {
        var d = FX.payload(records: [
            "2026-03-02": FX.rec(zb: 0, leave: LeaveInfo(type: "xiu", hour: 8, multiple: 0))
        ])
        let n = Store.migrateLeaveKinds(&d)
        #expect(n == 1)
        #expect(d.records["2026-03-02"]?.type == "xiu")
    }

    @Test func 老数据请一半折成休半天() {
        var d = FX.payload(records: [
            "2026-03-02": FX.rec(zb: 4, leave: LeaveInfo(type: "xiu", hour: 4, multiple: 0))
        ])
        _ = Store.migrateLeaveKinds(&d)
        #expect(d.records["2026-03-02"]?.type == "xban")
    }

    @Test func 十二小时班请八小时算半天() {
        var d = FX.payload(records: [
            "2026-03-02": FX.rec(zb: 4, leave: LeaveInfo(type: "xiu", hour: 8, multiple: 0))
        ])
        d.settings.classDefaults["1"] = ClassDefault(zb: 12)
        _ = Store.migrateLeaveKinds(&d)
        #expect(d.records["2026-03-02"]?.type == "xban")
    }

    @Test func 类型是休假却没假补一条整天() {
        var d = FX.payload(records: ["2026-03-02": FX.rec(type: "xiu")])
        _ = Store.migrateLeaveKinds(&d)
        #expect(d.records["2026-03-02"]?.type == "xiu")
        #expect(d.records["2026-03-02"]?.leave?.hour == 8)
    }

    @Test func 休半天扣一半钱且照发补助() {
        let rec = FX.rec(type: "xban", zb: 4,
                         bt: [BonusItem(name: "餐补", money: 20)],
                         leave: LeaveInfo(type: "xiu", hour: 4, multiple: 1))
        let s = FX.store(FX.payload(records: ["2026-03-02": rec]))
        let r = s.record("2026-03-02")!
        let m = s.dayMath(r)
        #expect(!m.fullLeave)
        #expect(m.halfLeave)
        #expect(m.need == 8)
        expectClose(m.deduct, 51.28)      // 4 × 12.82
        expectClose(s.dayPay(r), 20)      // 4×12.82 工时 − 51.28 扣款 + 20 补助
    }

    @Test func 休整天不发补助() {
        let rec = FX.rec(type: "xiu", zb: 0,
                         bt: [BonusItem(name: "餐补", money: 20)],
                         leave: LeaveInfo(type: "xiu", hour: 8, multiple: 1))
        let s = FX.store(FX.payload(records: ["2026-03-02": rec]))
        let r = s.record("2026-03-02")!
        #expect(s.dayMath(r).fullLeave)
        expectClose(s.dayPay(r), -102.56) // 没工时，扣 8×12.82，补助不发
    }

    @Test func 年假半天记零点五天() {
        let d = FX.payload(records: [
            "2026-03-02": FX.rec(type: "xiu", leave: LeaveInfo(type: "xiu", hour: 8, multiple: 0)),
            "2026-03-03": FX.rec(type: "xban", zb: 4, leave: LeaveInfo(type: "xiu", hour: 4, multiple: 0))
        ])
        let s = FX.store(d)
        expectClose(s.annualLeaveUsed(year: 2026), 1.5)
    }

    @Test func 连续记账从今天或昨天数() {
        let d = FX.payload(records: [
            "2026-03-01": FX.rec(zb: 8),
            "2026-03-02": FX.rec(zb: 8),
            "2026-03-03": FX.rec(zb: 8)
        ])
        let s = FX.store(d)
        #expect(s.recordStreak(endingAt: "2026-03-03") == 3)
        #expect(s.recordStreak(endingAt: "2026-03-04") == 3)
    }

    @Test func 发薪日在小月收敛到月末() {
        var d = FX.payload()
        d.settings.payday = 31
        let s = FX.store(d)
        #expect(s.isPayday("2026-02-28"))
        #expect(!s.isPayday("2026-02-27"))
    }
}
