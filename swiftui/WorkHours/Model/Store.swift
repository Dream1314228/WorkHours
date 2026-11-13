import Foundation
import SwiftUI

/// 全部数据与计算。对外只暴露方法，视图不直接改文件。
final class Store: ObservableObject {
    static let shared = Store()

    @Published var data: AppData = AppData() {
        didSet { scheduleSave() }
    }

    private var loaded = false
    private var saveWork: DispatchWorkItem?

    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("gsjilu.json")
    }

    private init() {
        load()
        loaded = true
        autoCarry()
        saveNow()
    }

    // MARK: 读写

    func load() {
        guard let raw = try? Data(contentsOf: Self.fileURL) else { return }
        let dec = JSONDecoder()
        if let d = try? dec.decode(AppData.self, from: raw) {
            data = d
        }
    }

    private func scheduleSave() {
        guard loaded else { return }
        saveWork?.cancel()
        let snap = data
        let work = DispatchWorkItem {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let raw = try? enc.encode(snap) else { return }
            try? raw.write(to: Self.fileURL, options: .atomic)
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let raw = try? enc.encode(data) else { return }
        try? raw.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: 设置别名

    var settings: Settings {
        get { data.settings }
        set { data.settings = newValue }
    }

    var projects: [Project] { data.projects }
    var classes: [ShiftClass] { data.classes }

    func project(_ id: String) -> Project {
        data.projects.first(where: { $0.id == id }) ?? data.projects.first
            ?? Project(id: "default", name: "默认项目")
    }

    func shiftClass(_ id: String) -> ShiftClass? {
        data.classes.first(where: { $0.id == id })
    }

    // MARK: 记录

    func record(_ key: String) -> DayRecord? { data.records[key] }

    func hasRecord(_ key: String) -> Bool { data.records[key] != nil }

    func setRecord(_ rec: DayRecord, for key: String) {
        var r = rec
        ensureAutoAllowance(&r)
        data.records[key] = r
    }

    func removeRecord(_ key: String) {
        data.records.removeValue(forKey: key)
    }

    func plan(_ key: String) -> String { data.plans[key] ?? "" }

    func setPlan(_ classId: String, for key: String) {
        if classId.isEmpty { data.plans.removeValue(forKey: key) }
        else { data.plans[key] = classId }
    }

    func records(in year: Int, month: Int) -> [(String, DayRecord)] {
        let prefix = String(format: "%04d-%02d-", year, month)
        return data.records.filter { $0.key.hasPrefix(prefix) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    // MARK: 工资

    func rate(projectId: String, type: String) -> Double {
        project(projectId).rates[type]
    }

    func dayHours(_ rec: DayRecord) -> Double { rec.work.total }

    func leavePay(_ rec: DayRecord) -> Double {
        guard let l = rec.leave, l.hour > 0 else { return 0 }
        if l.rule == "money" { return l.money }
        return l.hour * rate(projectId: rec.projectId, type: "zb") * l.multiple
    }

    func bonusTotal(_ rec: DayRecord) -> Double {
        rec.bt.reduce(0) { $0 + $1.money }
    }

    func dayPay(_ rec: DayRecord) -> Double {
        let extra = bonusTotal(rec)
        if rec.settle > 0 { return Cal.round2(rec.settle + extra) }
        var p = 0.0
        p += rec.work.zb * rate(projectId: rec.projectId, type: "zb")
        p += rec.work.jb * rate(projectId: rec.projectId, type: "jb")
        p += rec.work.zm * rate(projectId: rec.projectId, type: "zm")
        p += rec.work.jj * rate(projectId: rec.projectId, type: "jj")
        p += leavePay(rec)
        return Cal.round2(p + extra)
    }

    func daySummary(_ rec: DayRecord?) -> String {
        guard let rec = rec else { return "未记录" }
        if rec.work.zb > 0 && rec.work.jb > 0 {
            return "\(Cal.num(rec.work.zb))+\(Cal.num(rec.work.jb))"
        }
        if rec.work.total > 0 { return "\(Cal.num(rec.work.total))h" }
        if let l = rec.leave { return "休\(Cal.num(l.hour))" }
        if rec.settle > 0 { return "日结" }
        return "记"
    }

    /// 班次名里带「夜/中/晚」发夜班补助，带「白/早」发白班补助
    func allowanceName(forClass classId: String) -> String? {
        let name = shiftClass(classId)?.name ?? ""
        if name.contains("夜") || name.contains("中") || name.contains("晚") { return "夜班补助" }
        if name.contains("白") || name.contains("早") { return "白班补助" }
        return nil
    }

    func ensureAutoAllowance(_ rec: inout DayRecord) {
        guard data.settings.autoBonus else { return }
        if rec.type == "xiu" { return }
        let hasLeave = rec.leave != nil
        if rec.work.total <= 0 && !hasLeave { return }
        guard let name = allowanceName(forClass: rec.classId) else { return }
        let night = name == "夜班补助"
        let amount = night ? data.settings.nightAllowance : data.settings.dayAllowance
        if amount <= 0 { return }
        if rec.bt.contains(where: { $0.name == name }) { return }
        rec.bt.append(BonusItem(name: name, money: amount, note: "自动补助", autoAllowance: true))
    }

    func defaultWork(forClass classId: String) -> WorkHours {
        data.settings.classDefaults[classId]?.work ?? data.settings.defaultWork
    }

    func setClassDefault(_ classId: String, _ key: String, _ value: Double) {
        var d = data.settings.classDefaults[classId] ?? ClassDefault()
        switch key {
        case "zb": d.zb = value
        case "jb": d.jb = value
        case "zm": d.zm = value
        case "jj": d.jj = value
        case "rjgz": d.rjgz = value
        default: break
        }
        data.settings.classDefaults[classId] = d
    }

    // MARK: 年假

    var annualLeaveTotal: Double { max(0, data.settings.annualLeaveDays) }

    func annualLeaveUsed(year: Int) -> Double {
        let prefix = String(format: "%04d-", year)
        var hours = 0.0
        for (k, r) in data.records where k.hasPrefix(prefix) {
            if let l = r.leave, l.type == "xiu" { hours += l.hour }
        }
        return Cal.round2(hours / 8)
    }

    func annualLeaveRemaining(year: Int) -> Double {
        Cal.round2(annualLeaveTotal - annualLeaveUsed(year: year))
    }

    // MARK: 考勤期

    /// 手动期优先，否则按「每月 N 号」的默认规律。
    func periodRange(year: Int, month: Int) -> (start: String, end: String, label: String) {
        let prefix = String(format: "%04d-%02d", year, month)
        if let p = data.settings.customPeriods.first(where: { $0.start.hasPrefix(prefix) }) {
            return (p.start, p.end, Cal.periodLabel(start: p.start, end: p.end))
        }
        let day = data.settings.period
        let curDays = Cal.daysInMonth(year, month)
        if day <= 1 {
            let s = String(format: "%04d-%02d-01", year, month)
            let e = String(format: "%04d-%02d-%02d", year, month, curDays)
            return (s, e, "1 号 - 月底")
        }
        let next = Cal.monthAdd(year, month, 1)
        let nextDays = Cal.daysInMonth(next.year, next.month)
        let sd = min(day, curDays)
        let ed = min(day - 1, nextDays)
        let s = String(format: "%04d-%02d-%02d", year, month, sd)
        let e = String(format: "%04d-%02d-%02d", next.year, next.month, ed)
        return (s, e, Cal.periodLabel(start: s, end: e))
    }

    // MARK: 统计

    func monthStats(year: Int, month: Int, usePeriod: Bool = true) -> MonthStats {
        let range = periodRange(year: year, month: month)
        let prefix = String(format: "%04d-%02d-", year, month)
        var st = MonthStats()
        st.start = range.start; st.end = range.end; st.label = range.label
        for (k, r) in data.records {
            if usePeriod {
                if k < range.start || k > range.end { continue }
            } else if !k.hasPrefix(prefix) {
                continue
            }
            st.days += 1
            st.hours += r.work.total
            st.pay += dayPay(r)
            st.zb += r.work.zb; st.jb += r.work.jb; st.zm += r.work.zm; st.jj += r.work.jj
            for b in r.bt {
                if b.money >= 0 { st.bonus += b.money } else { st.deduct -= b.money }
            }
        }
        let mk = monthKey(year, month)
        for b in data.bonuses[mk] ?? [] {
            st.bonus += b.money; st.pay += b.money
        }
        for b in data.deductions[mk] ?? [] {
            st.deduct += b.money; st.pay -= b.money
        }
        st.hours = Cal.round2(st.hours)
        st.pay = Cal.round2(st.pay)
        st.zb = Cal.round2(st.zb); st.jb = Cal.round2(st.jb)
        st.zm = Cal.round2(st.zm); st.jj = Cal.round2(st.jj)
        st.bonus = Cal.round2(st.bonus); st.deduct = Cal.round2(st.deduct)
        return st
    }

    func yearStats(year: Int) -> YearStats {
        var buckets = Array(repeating: MonthStats(), count: 12)
        let yearPrefix = String(format: "%04d-", year)
        for (k, r) in data.records {
            guard k.count >= 7, k.hasPrefix(yearPrefix) else { continue }
            let m = Cal.month(k)
            guard m >= 1, m <= 12 else { continue }
            buckets[m - 1].days += 1
            buckets[m - 1].hours += r.work.total
            buckets[m - 1].pay += dayPay(r)
            buckets[m - 1].zb += r.work.zb
            buckets[m - 1].jb += r.work.jb
            buckets[m - 1].zm += r.work.zm
            buckets[m - 1].jj += r.work.jj
            for b in r.bt {
                if b.money >= 0 { buckets[m - 1].bonus += b.money }
                else { buckets[m - 1].deduct -= b.money }
            }
        }
        var ys = YearStats()
        for m in 1...12 {
            var b = buckets[m - 1]
            let mk = monthKey(year, m)
            for item in data.bonuses[mk] ?? [] {
                b.bonus += item.money; b.pay += item.money
            }
            for item in data.deductions[mk] ?? [] {
                b.deduct += item.money; b.pay -= item.money
            }
            let range = periodRange(year: year, month: m)
            b.start = range.start; b.end = range.end; b.label = range.label
            b.hours = Cal.round2(b.hours); b.pay = Cal.round2(b.pay)
            b.zb = Cal.round2(b.zb); b.jb = Cal.round2(b.jb)
            b.zm = Cal.round2(b.zm); b.jj = Cal.round2(b.jj)
            b.bonus = Cal.round2(b.bonus); b.deduct = Cal.round2(b.deduct)
            ys.months[m - 1] = b
            ys.pay += b.pay; ys.hours += b.hours; ys.days += b.days
            ys.ot += b.jb + b.zm + b.jj
            ys.bonus += b.bonus; ys.deduct += b.deduct
        }
        ys.pay = Cal.round2(ys.pay)
        ys.hours = Cal.round2(ys.hours)
        ys.ot = Cal.round2(ys.ot)
        ys.bonus = Cal.round2(ys.bonus)
        ys.deduct = Cal.round2(ys.deduct)
        return ys
    }

    // MARK: 月度补贴 / 扣款

    func monthKey(_ year: Int, _ month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    func extras(_ kind: String, year: Int, month: Int) -> [BonusItem] {
        let mk = monthKey(year, month)
        return kind == "bonus" ? (data.bonuses[mk] ?? []) : (data.deductions[mk] ?? [])
    }

    func addExtra(_ kind: String, year: Int, month: Int, name: String, money: Double, note: String = "") {
        let mk = monthKey(year, month)
        let item = BonusItem(name: name.isEmpty ? (kind == "bonus" ? "补贴" : "扣款") : name,
                             money: abs(money), note: note)
        if kind == "bonus" { data.bonuses[mk, default: []].append(item) }
        else { data.deductions[mk, default: []].append(item) }
    }

    func deleteExtra(_ kind: String, year: Int, month: Int, id: String) {
        let mk = monthKey(year, month)
        if kind == "bonus" { data.bonuses[mk]?.removeAll { $0.id == id } }
        else { data.deductions[mk]?.removeAll { $0.id == id } }
    }

    func importLastMonth(_ kind: String, year: Int, month: Int) {
        let prev = Cal.monthAdd(year, month, -1)
        let src = extras(kind, year: prev.year, month: prev.month)
        guard !src.isEmpty else { return }
        let mk = monthKey(year, month)
        var list = kind == "bonus" ? (data.bonuses[mk] ?? []) : (data.deductions[mk] ?? [])
        for b in src {
            let exists = list.contains { $0.name == b.name && abs($0.money - b.money) < 0.001 }
            if !exists {
                list.append(BonusItem(name: b.name, money: b.money, note: "上月导入"))
            }
        }
        if kind == "bonus" { data.bonuses[mk] = list } else { data.deductions[mk] = list }
    }

    /// 每月第一次打开，把上月补贴扣款带过来（旧版行为）
    func autoCarry() {
        let now = Date()
        let y = Cal.gregorian.component(.year, from: now)
        let m = Cal.gregorian.component(.month, from: now)
        let cur = monthKey(y, m)
        if data.settings.autoCarryMonth == cur { return }
        importLastMonth("bonus", year: y, month: m)
        importLastMonth("deduct", year: y, month: m)
        data.settings.autoCarryMonth = cur
    }

    // MARK: 批量

    /// 给一组日期统一设班次与工时；skipWeekend 跳过周末。
    func batchApply(dates: [String], classId: String, normal: Double, overtime: Double,
                    projectId: String, skipWeekend: Bool) {
        for key in dates {
            if skipWeekend && Cal.isWeekend(key) { continue }
            var rec = data.records[key] ?? DayRecord()
            rec.classId = classId
            rec.projectId = projectId
            rec.type = Cal.dayKind(key)
            var w = WorkHours()
            switch rec.type {
            case "zm": w.zm = normal; w.jb = overtime
            case "jj": w.jj = normal; w.jb = overtime
            default: w.zb = normal; w.jb = overtime
            }
            if w.total <= 0 { continue }
            rec.work = w
            rec.leave = nil
            rec.settle = 0
            if rec.note.isEmpty { rec.note = "" }
            ensureAutoAllowance(&rec)
            data.records[key] = rec
        }
    }

    // MARK: 清空 / 备份

    func clearAllRecords() {
        data.records = [:]
        data.plans = [:]
        data.bonuses = [:]
        data.deductions = [:]
        saveNow()
    }

    func backupData() -> Data? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(data)
    }

    enum ImportError: LocalizedError {
        case badFile
        var errorDescription: String? { "这个文件不是工时记录的备份" }
    }

    /// 先按整库 JSON 读；读不了再按旧版备份（days 数组）转换。
    func importBackup(_ raw: Data) throws {
        let dec = JSONDecoder()
        if let d = try? dec.decode(AppData.self, from: raw) {
            data = d
            saveNow()
            return
        }
        if let any = try? JSONSerialization.jsonObject(with: raw),
           let obj = any as? [String: Any],
           let days = obj["days"] as? [[String: Any]] {
            var imported = data
            for item in days {
                guard let key = item["d"] as? String, key.count == 10 else { continue }
                var rec = DayRecord()
                rec.classId = item["c"] as? String ?? "1"
                rec.projectId = item["p"] as? String ?? data.settings.projectId
                rec.type = item["t"] as? String ?? "zb"
                if let w = item["w"] as? [Double], w.count >= 4 {
                    rec.work = WorkHours(zb: w[0], jb: w[1], zm: w[2], jj: w[3])
                }
                rec.settle = (item["s"] as? Double) ?? 0
                rec.note = item["n"] as? String ?? ""
                if let b = item["b"] as? [[String: Any]] {
                    rec.bt = b.map {
                        BonusItem(name: $0["name"] as? String ?? "补贴",
                                  money: ($0["money"] as? Double) ?? 0,
                                  note: $0["note"] as? String ?? "")
                    }
                }
                if let l = item["l"] as? [String: Any] {
                    rec.leave = LeaveInfo(type: l["type"] as? String ?? "xiu",
                                          hour: (l["hour"] as? Double) ?? 0,
                                          rule: l["rule"] as? String ?? "hour",
                                          multiple: (l["multiple"] as? Double) ?? 0,
                                          money: (l["money"] as? Double) ?? 0)
                }
                imported.records[key] = rec
            }
            data = imported
            saveNow()
            return
        }
        throw ImportError.badFile
    }

    // MARK: 报表文本

    func reportText(year: Int, month: Int) -> String {
        let st = monthStats(year: year, month: month)
        var lines: [String] = []
        lines.append("工时记录 · \(year) 年 \(month) 月")
        lines.append("考勤期：\(st.start) 至 \(st.end)")
        lines.append("")
        lines.append("出勤 \(Cal.num(st.days)) 天，总工时 \(Cal.num(st.hours)) H")
        lines.append("正班 \(Cal.num(st.zb)) H / 加班 \(Cal.num(st.jb)) H / 周末 \(Cal.num(st.zm)) H / 节假 \(Cal.num(st.jj)) H")
        lines.append("补贴 \(Cal.money(st.bonus))，扣款 \(Cal.money(st.deduct))")
        lines.append("实发工资 \(Cal.money(st.pay))")
        lines.append("")
        lines.append("日期        班次    工时          金额")
        let prefix = String(format: "%04d-%02d-", year, month)
        let rows = data.records.filter { $0.key.hasPrefix(prefix) }.sorted { $0.key < $1.key }
        for (k, r) in rows {
            let name = shiftClass(r.classId)?.name ?? "-"
            lines.append("\(k)  \(name.padding(toLength: 4, withPad: " ", startingAt: 0))  \(Cal.num(r.work.total))H  \(Cal.money(dayPay(r)))")
        }
        return lines.joined(separator: "\n")
    }
}
