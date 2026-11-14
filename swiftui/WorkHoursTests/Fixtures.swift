import Foundation
import Testing
@testable import WorkHours

/// 测试夹具：一律用 `Store(payload:)` 注入数据，不读磁盘、不触发自动保存。
enum FX {
    /// 一条普通记录，默认白班 + 默认项目（单价 zb 12.82 / jb 19.23 / zm 25.64 / jj 38.46）。
    static func rec(type: String = "zb",
                    zb: Double = 0, jb: Double = 0, zm: Double = 0, jj: Double = 0,
                    classId: String = "1", projectId: String = "default",
                    settle: Double = 0, bt: [BonusItem] = [],
                    leave: LeaveInfo? = nil, note: String = "") -> DayRecord {
        var r = DayRecord()
        r.type = type
        r.classId = classId
        r.projectId = projectId
        r.work = WorkHours(zb: zb, jb: jb, zm: zm, jj: jj)
        r.settle = settle
        r.bt = bt
        r.leave = leave
        r.note = note
        return r
    }

    /// 整库数据，默认带 `AppData()` 的种子项目和四个班次。
    static func payload(period: Int = 26,
                        records: [String: DayRecord] = [:],
                        autoBonus: Bool = true,
                        dayAllowance: Double = 10,
                        nightAllowance: Double = 20,
                        annualLeaveDays: Double = 5,
                        classes: [ShiftClass]? = nil,
                        bonuses: [String: [BonusItem]] = [:],
                        deductions: [String: [BonusItem]] = [:]) -> AppData {
        var d = AppData()
        d.settings.period = period
        d.settings.autoBonus = autoBonus
        d.settings.dayAllowance = dayAllowance
        d.settings.nightAllowance = nightAllowance
        d.settings.annualLeaveDays = annualLeaveDays
        if let classes = classes { d.classes = classes }
        d.records = records
        d.bonuses = bonuses
        d.deductions = deductions
        return d
    }

    static func store(_ d: AppData) -> Store { Store(payload: d) }
}

/// 金额断言：先 round2 再比，避开二进制浮点末位抖动。
/// 调用方必须给具体数值，不接受「大于 0」这种模糊断言。
func expectClose(_ actual: Double, _ expected: Double, _ note: String = "") {
    let rounded = Cal.round2(actual)
    #expect(rounded == expected, "\(note) 期望 \(expected)，实际 \(rounded)")
}

/// `importBackup` 正常成功能路径会经 `commitImport` 落盘（宿主 App 容器的 Documents）。
/// 走这条路的用例统一套本函数：跑完把原文件还原，绝不留测试数据、也绝不毁开发机上的真数据。
func withCleanStoreFiles(_ body: () throws -> Void) rethrows {
    let fm = FileManager.default
    let main = Store.fileURL
    let snapshot = Store.snapshotURL
    let savedMain = try? Data(contentsOf: main)
    let savedSnapshot = try? Data(contentsOf: snapshot)
    defer {
        try? fm.removeItem(at: main)
        try? fm.removeItem(at: snapshot)
        if let savedMain = savedMain { try? savedMain.write(to: main) }
        if let savedSnapshot = savedSnapshot { try? savedSnapshot.write(to: snapshot) }
    }
    try body()

    /// 取一份真实 settings 的 JSON 片段，拼进整库测试文件用。
    /// 整库导入现在要求 `settings` 存在（否则按没用的整库拒绝），手写 settings 容易漏字段。
    static func settingsFragment() throws -> String {
        let raw = try JSONEncoder().encode(FX.payload())
        let obj = try JSONSerialization.jsonObject(with: raw) as? [String: Any]
        let settings = obj?["settings"] ?? [:]
        let data = try JSONSerialization.data(withJSONObject: settings)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
