import Foundation
import SwiftUI

/// 全部数据与计算。对外只暴露方法，视图不直接改文件。
final class Store: ObservableObject {
    static let shared = Store()

    @Published var data: AppData = AppData() {
        didSet {
            guard loaded else { return }
            revision &+= 1
            chartToken &+= 1
            scheduleSave()
        }
    }

    /// 每次数据变动 +1。图表用它重播动画，切页面也会重来。
    @Published private(set) var revision = 0

    /// 图表专用的重播信号：数据变了、切到别的标签页，都让它 +1。
    @Published private(set) var chartToken = 0

    func refreshCharts() { chartToken &+= 1 }

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

    /// 节假日自动更新：七天一次，成功才记时间；失败静默，下次再试。
    func autoUpdateHoliday(force: Bool = false) async {
        let stampKey = "holidaySyncAt"
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: stampKey)
        let now = Date().timeIntervalSince1970
        if !force, last > 0, now - last < 7 * 24 * 3600 { return }

        let thisYear = Cal.gregorian.component(.year, from: Date())
        var got = 0
        for y in [thisYear, thisYear + 1] {
            guard let year = try? await HolidayRemote.fetch(year: y) else { continue }
            guard let payload = try? JSONEncoder().encode([String(y): year]) else { continue }
            if (try? HolidayData.shared.importJSON(payload)) != nil { got += 1 }
        }
        if got > 0 {
            defaults.set(now, forKey: stampKey)
            await MainActor.run { self.revision &+= 1 }
        }
    }

    // MARK: 动效开关

    /// 总开关。关掉后所有动画直接落到终值。
    var motionOn: Bool { data.settings.animations }
    var chartMotion: Bool { data.settings.animations && data.settings.chartAnimation }
    var calendarMotion: Bool { data.settings.animations && data.settings.calendarAnimation }
    var pageMotion: Bool { data.settings.animations && data.settings.pageAnimation }

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
        if amount <= 0 {
            rec.bt.removeAll { ($0.autoAllowance || $0.note == "自动补助") && $0.name == name }
            return
        }
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

    /// 最近一次同班次的实际工时，用来给没设默认值的新记录兜底。
    func lastWork(forClass id: String) -> WorkHours? {
        for key in data.records.keys.sorted(by: >) {
            guard let r = data.records[key], r.classId == id, r.work.total > 0 else { continue }
            return r.work
        }
        return nil
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

    /// 只排班：只写班次，不生成工时记录。
    func setPlanBatch(dates: [String], classId: String, skipWeekend: Bool) {
        for key in dates {
            if skipWeekend && Cal.isWeekend(key) { continue }
            data.plans[key] = classId
        }
    }

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

    // MARK: 备份（与 UIKit 版互导）

    private func jsonObject<T: Encodable>(_ value: T) -> Any? {
        let enc = JSONEncoder()
        guard let d = try? enc.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: d)
    }

    private func decodeValue<T: Decodable>(_ any: Any, as type: T.Type) -> T? {
        guard JSONSerialization.isValidJSONObject(any),
              let d = try? JSONSerialization.data(withJSONObject: any) else { return nil }
        return try? JSONDecoder().decode(type, from: d)
    }

    private func doubleOf(_ any: Any?) -> Double {
        if let n = any as? NSNumber { return n.doubleValue }
        if let d = any as? Double { return d }
        if let s = any as? String { return Double(s) ?? 0 }
        return 0
    }

    /// 旧版 .gsjilu 备份：format=gsjilu-backup、version=4。
    /// UIKit 版能直接导入，本版也能导入 UIKit 版导出的文件。
    func backupData() -> Data? {
        var days: [[String: Any]] = []
        var hours = 0.0
        var pay = 0.0
        for key in data.records.keys.sorted() {
            guard let r = data.records[key] else { continue }
            var item: [String: Any] = [
                "d": key,
                "c": r.classId,
                "p": r.projectId,
                "t": r.type,
                "w": [r.work.zb, r.work.jb, r.work.zm, r.work.jj]
            ]
            if r.settle > 0 { item["s"] = r.settle }
            if !r.bt.isEmpty { item["b"] = jsonObject(r.bt) ?? [] }
            if let l = r.leave { item["l"] = jsonObject(l) ?? [:] }
            if !r.note.isEmpty { item["n"] = r.note }
            days.append(item)
            hours += r.work.total
            pay += dayPay(r)
        }
        let obj: [String: Any] = [
            "app": "工时记录",
            "format": "gsjilu-backup",
            "version": 4,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "summary": ["days": days.count,
                        "hours": Cal.round2(hours),
                        "pay": Cal.round2(pay)],
            "settings": jsonObject(data.settings) ?? [:],
            "projects": jsonObject(data.projects) ?? [],
            "classes": jsonObject(data.classes) ?? [],
            "plans": data.plans,
            "extras": ["bonus": jsonObject(data.bonuses) ?? [:],
                       "deduct": jsonObject(data.deductions) ?? [:]],
            "days": days
        ]
        return try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    }

    enum ImportError: LocalizedError {
        case badFile
        var errorDescription: String? { "这个文件不是工时记录的备份" }
    }

    /// UIKit 老版导出的是 LZFSE 压缩 JSON（文件头 bvx2），新版是纯 JSON；两种都认。
    static func unwrapBackup(_ raw: Data) -> Data {
        guard raw.count > 8 else { return raw }
        let head = [UInt8](raw.prefix(4))
        let compressed = head == [0x62, 0x76, 0x78, 0x32]   // bvx2
            || head == [0x62, 0x76, 0x78, 0x31]             // bvx1
            || head == [0x62, 0x76, 0x78, 0x2d]             // bvx-
        guard compressed else { return raw }
        if let out = try? (raw as NSData).decompressed(using: .lzfse) {
            return out as Data
        }
        return raw
    }

    /// 先认旧版 gsjilu-backup；再认整库 JSON（含 records）。
    func importBackup(_ raw: Data) throws {
        let payload = Store.unwrapBackup(raw)
        guard let any = try? JSONSerialization.jsonObject(with: payload),
              let obj = any as? [String: Any] else { throw ImportError.badFile }

        if let days = obj["days"] as? [[String: Any]],
           (obj["format"] as? String) == "gsjilu-backup" || obj["format"] == nil {
            var imported = AppData()
            if let v = obj["settings"] {
                imported.settings = decodeValue(v, as: Settings.self) ?? Settings()
            }
            if let v = obj["projects"] {
                imported.projects = decodeValue(v, as: [Project].self) ?? []
            }
            if let v = obj["classes"] {
                imported.classes = decodeValue(v, as: [ShiftClass].self) ?? []
            }
            if let v = obj["plans"] as? [String: String] {
                imported.plans = v
            }
            if let extras = obj["extras"] as? [String: Any] {
                if let b = extras["bonus"] {
                    imported.bonuses = decodeValue(b, as: [String: [BonusItem]].self) ?? [:]
                }
                if let d = extras["deduct"] {
                    imported.deductions = decodeValue(d, as: [String: [BonusItem]].self) ?? [:]
                }
            }
            if imported.projects.isEmpty { imported.projects = AppData().projects }
            if imported.classes.isEmpty { imported.classes = AppData().classes }

            var records: [String: DayRecord] = [:]
            for item in days {
                guard let key = item["d"] as? String, key.count == 10 else { continue }
                var r = DayRecord()
                r.classId = item["c"] as? String ?? imported.settings.currentClass
                r.projectId = item["p"] as? String ?? imported.settings.projectId
                r.type = item["t"] as? String ?? Cal.dayKind(key)
                if let w = item["w"] as? [Any], w.count >= 4 {
                    r.work = WorkHours(zb: doubleOf(w[0]), jb: doubleOf(w[1]),
                                       zm: doubleOf(w[2]), jj: doubleOf(w[3]))
                }
                r.settle = doubleOf(item["s"])
                if let b = item["b"] {
                    r.bt = decodeValue(b, as: [BonusItem].self) ?? []
                }
                if let l = item["l"] {
                    r.leave = decodeValue(l, as: LeaveInfo.self)
                }
                r.note = item["n"] as? String ?? ""
                records[key] = r
            }
            imported.records = records
            data = imported
            saveNow()
            return
        }

        if let recObj = obj["records"] {
            if let d = try? JSONDecoder().decode(AppData.self, from: payload) {
                data = d
                saveNow()
                return
            }
            // 旧版整库 JSON：字段名可能对不上，按宽松方式逐条读
            var imported = AppData()
            if let v = obj["settings"] { imported.settings = decodeValue(v, as: Settings.self) ?? Settings() }
            if let v = obj["projects"], let list = decodeValue(v, as: [Project].self), !list.isEmpty {
                imported.projects = list
            }
            if let v = obj["classes"], let list = decodeValue(v, as: [ShiftClass].self), !list.isEmpty {
                imported.classes = list
            }
            if let v = obj["plans"] as? [String: String] { imported.plans = v }
            if let v = obj["bonuses"] { imported.bonuses = decodeValue(v, as: [String: [BonusItem]].self) ?? [:] }
            if let v = obj["deductions"] { imported.deductions = decodeValue(v, as: [String: [BonusItem]].self) ?? [:] }

            var records: [String: DayRecord] = [:]
            if let dict = recObj as? [String: [String: Any]] {
                for (key, item) in dict where key.count == 10 {
                    var r = DayRecord()
                    r.classId = (item["c"] as? String) ?? (item["classId"] as? String) ?? imported.settings.currentClass
                    r.projectId = (item["p"] as? String) ?? (item["projectId"] as? String) ?? imported.settings.projectId
                    r.type = (item["t"] as? String) ?? (item["type"] as? String) ?? Cal.dayKind(key)
                    if let w = item["w"] as? [Any], w.count >= 4 {
                        r.work = WorkHours(zb: doubleOf(w[0]), jb: doubleOf(w[1]),
                                           zm: doubleOf(w[2]), jj: doubleOf(w[3]))
                    } else {
                        r.work = WorkHours(zb: doubleOf(item["zb"]), jb: doubleOf(item["jb"]),
                                           zm: doubleOf(item["zm"]), jj: doubleOf(item["jj"]))
                    }
                    r.settle = doubleOf(item["s"])
                    if let b = item["bt"] { r.bt = decodeValue(b, as: [BonusItem].self) ?? [] }
                    if let l = item["leave"] { r.leave = decodeValue(l, as: LeaveInfo.self) }
                    r.note = (item["n"] as? String) ?? (item["note"] as? String) ?? ""
                    records[key] = r
                }
            }
            guard !records.isEmpty else { throw ImportError.badFile }
            imported.records = records
            if imported.projects.isEmpty { imported.projects = AppData().projects }
            if imported.classes.isEmpty { imported.classes = AppData().classes }
            data = imported
            saveNow()
            return
        }
        throw ImportError.badFile
    }

    /// 补助金额改成 0 时，把以前自动加进去的补助清掉
    @discardableResult
    func purgeAutoAllowance(name: String) -> Int {
        var removed = 0
        for key in data.records.keys {
            guard var rec = data.records[key] else { continue }
            let before = rec.bt.count
            rec.bt.removeAll { ($0.autoAllowance || $0.note == "自动补助") && $0.name == name }
            if rec.bt.count != before {
                removed += before - rec.bt.count
                data.records[key] = rec
            }
        }
        if removed > 0 { saveNow() }
        return removed
    }

    // MARK: 报表文本

    /// 按考勤期取记录（会跨月）
    func periodRecords(year: Int, month: Int) -> [(String, DayRecord)] {
        let r = periodRange(year: year, month: month)
        return data.records.filter { $0.key >= r.start && $0.key <= r.end }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    /// 导出 HTML 报表：周期汇总 + 工时构成 + 逐日明细 + 补扣明细，手机能看、打印成 PDF 也正。
    func htmlReport(year: Int, month: Int) -> String {
        let st = monthStats(year: year, month: month)
        let rows = periodRecords(year: year, month: month)
        let mk = monthKey(year, month)
        let bonuses = data.bonuses[mk] ?? []
        let deductions = data.deductions[mk] ?? []

        var dayRows = ""
        for (key, rec) in rows {
            let shift = shiftClass(rec.classId)?.name ?? "—"
            let note = rec.note.isEmpty ? "" : escapeHTML(rec.note)
            let extra = rec.bt.isEmpty ? "" : rec.bt.map {
                escapeHTML($0.name) + ": " + ($0.money >= 0 ? "+" : "") + Cal.money($0.money)
            }.joined(separator: "；")
            let tail = [note, extra].filter { !$0.isEmpty }.joined(separator: " · ")
            var cells: [String] = []
            cells.append("<td class=\"c\">" + String(format: "%02d", Cal.day(key)) + "</td>")
            cells.append("<td>" + Cal.weekdayName(key) + "</td>")
            cells.append("<td>" + escapeHTML(shift) + "</td>")
            cells.append("<td class=\"n\">" + Cal.num(rec.work.zb) + "</td>")
            cells.append("<td class=\"n\">" + Cal.num(rec.work.jb) + "</td>")
            cells.append("<td class=\"n\">" + Cal.num(rec.work.zm) + "</td>")
            cells.append("<td class=\"n\">" + Cal.num(rec.work.jj) + "</td>")
            cells.append("<td class=\"n b\">" + Cal.num(rec.work.total) + "</td>")
            cells.append("<td class=\"n b\">" + Cal.money(dayPay(rec)) + "</td>")
            cells.append("<td class=\"note\">" + (tail.isEmpty ? "—" : tail) + "</td>")
            dayRows += "<tr>" + cells.joined() + "</tr>"
        }
        if dayRows.isEmpty {
            dayRows = "<tr><td colspan=\"10\" class=\"empty\">这个周期还没有记录</td></tr>"
        }

        func extraTable(_ list: [BonusItem], _ cls: String) -> String {
            let body: String
            if list.isEmpty {
                body = "<tr><td colspan=\"2\" class=\"empty\">无</td></tr>"
            } else {
                body = list.map {
                    "<tr><td>" + escapeHTML($0.name.isEmpty ? "未命名" : $0.name)
                        + "</td><td class=\"n " + cls + "\">" + Cal.money($0.money) + "</td></tr>"
                }.joined()
            }
            return "<div class=\"table-wrap\"><table class=\"mini\"><thead><tr><th>项目</th>"
                + "<th class=\"n\">金额</th></tr></thead><tbody>" + body + "</tbody></table></div>"
        }

        let totalH = max(st.hours, 0.001)
        func pct(_ v: Double) -> Int { Int((v / totalH * 100).rounded()) }
        func bar(_ name: String, _ v: Double, _ color: String) -> String {
            return "<div class=\"bar\"><span class=\"lbl\">" + name + "</span>"
                + "<span class=\"track\"><span class=\"fill\" style=\"width:"
                + String(max(1, pct(v))) + "%;background:" + color + "\"></span></span>"
                + "<span class=\"num\">" + Cal.num(v) + " H</span></div>"
        }

        return """
        <!doctype html>
        <html lang="zh-CN"><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>工时记录 \(year) 年 \(month) 月</title>
        <style>
        :root {
          --bg:#f4f1ea; --paper:#ffffff; --ink:#15181d; --ink2:#4a5568; --ink3:#6b7686;
          --line:#e5e0d5; --accent:#1f3a6e; --orange:#b45309; --green:#15803d; --red:#b42318;
          --zebra:#f8f6f1; --radius:16px;
        }
        @media (prefers-color-scheme: dark) {
          :root { --bg:#0f1319; --paper:#171c24; --ink:#eef2f7; --ink2:#aeb9c9; --ink3:#8b97a8;
                  --line:#2a323e; --accent:#8fb3ff; --orange:#f0a35e; --green:#6bd694;
                  --red:#ff8f84; --zebra:#1d232c; }
        }
        * { box-sizing:border-box; }
        body { margin:0; padding:clamp(16px,4vw,40px) clamp(12px,3.4vw,32px) 56px;
               background:var(--bg); color:var(--ink);
               font:15px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC","Noto Sans SC",system-ui,sans-serif;
               -webkit-text-size-adjust:100%; }
        .wrap { max-width:820px; margin:0 auto; }
        header { display:flex; flex-wrap:wrap; gap:12px 16px; align-items:flex-end;
                 justify-content:space-between; margin-bottom:22px; }
        h1 { margin:0; font-size:clamp(20px,5.2vw,26px); letter-spacing:.02em; }
        .sub { margin:5px 0 0; color:var(--ink3); font-size:12px; font-variant-numeric:tabular-nums; }
        .pay { text-align:right; }
        .pay .k { font-size:11px; color:var(--ink3); letter-spacing:.1em; }
        .pay .v { font-size:clamp(24px,7vw,32px); font-weight:700;
                  font-variant-numeric:tabular-nums; line-height:1.15; }
        .cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(118px,1fr));
                 gap:10px; }
        .card { background:var(--paper); border:1px solid var(--line);
                border-radius:var(--radius); padding:12px 14px; }
        .card .k { font-size:11px; color:var(--ink3); }
        .card .v { margin-top:3px; font-size:20px; font-weight:650;
                   font-variant-numeric:tabular-nums; }
        .pos { color:var(--green); }
        .neg { color:var(--red); }
        h2 { display:flex; align-items:center; gap:10px; margin:26px 0 10px;
             font-size:12px; font-weight:650; letter-spacing:.12em; color:var(--ink2); }
        h2::after { content:""; flex:1; height:1px; background:var(--line); }
        .bars { background:var(--paper); border:1px solid var(--line);
                border-radius:var(--radius); padding:15px 16px;
                display:grid; gap:11px; }
        .bar { display:grid; grid-template-columns:44px 1fr 72px; align-items:center;
               gap:10px; font-size:12px; }
        .bar .lbl { color:var(--ink2); }
        .bar .track { height:8px; border-radius:99px; background:var(--line);
                      overflow:hidden; display:block; }
        .bar .fill { display:block; height:100%; border-radius:99px; }
        .bar .num { text-align:right; font-variant-numeric:tabular-nums; color:var(--ink2); }
        .table-wrap { background:var(--paper); border:1px solid var(--line);
                      border-radius:var(--radius); overflow-x:auto;
                      -webkit-overflow-scrolling:touch; }
        table { width:100%; min-width:660px; border-collapse:collapse; }
        table.mini { min-width:0; }
        th, td { padding:8px 10px; border-bottom:1px solid var(--line);
                 text-align:left; font-size:12.5px; vertical-align:top;
                 font-variant-numeric:tabular-nums; }
        th { background:var(--paper); color:var(--ink3); font-weight:600; font-size:11px;
             letter-spacing:.04em; white-space:nowrap; }
        tbody tr:nth-child(even) td { background:var(--zebra); }
        tbody tr:last-child td { border-bottom:none; }
        .n { text-align:right; }
        .c { text-align:center; }
        .b { font-weight:700; }
        .note { color:var(--ink2); min-width:130px; }
        .empty { text-align:center; color:var(--ink3); padding:22px; }
        .sum { display:flex; justify-content:space-between; align-items:baseline;
               gap:12px; margin-top:12px; font-size:12.5px; color:var(--ink2); }
        .sum b { font-size:19px; color:var(--ink); font-variant-numeric:tabular-nums; }
        .cols { display:grid; grid-template-columns:repeat(auto-fit,minmax(238px,1fr)); gap:12px; }
        footer { margin-top:30px; padding-top:14px; border-top:1px solid var(--line);
                 color:var(--ink3); font-size:11px; line-height:1.7; }
        @media (max-width: 420px) {
          th, td { padding: 7px 8px; }
          .bar { grid-template-columns: 38px 1fr 64px; }
        }
        @media print {
          :root { --bg:#fff; --paper:#fff; --line:#d8d4ca; --ink:#000; --ink2:#333;
                  --ink3:#555; --zebra:#f4f2ec; --accent:#1f3a6e; --orange:#8a4a09;
                  --green:#145c30; --red:#8f1d14; }
          body { padding:0; font-size:12px; }
          .card, .table-wrap, .bars { break-inside:avoid; }
          tbody tr { break-inside:avoid; }
          thead { display:table-header-group; }
          table { min-width:0; }
          .table-wrap { overflow:visible; }
          @page { margin:14mm 12mm; }
        }
        </style></head><body><div class="wrap">

        <header>
          <div>
            <h1>工时记录 · \(year) 年 \(month) 月</h1>
            <p class="sub">考勤期 \(st.start) 至 \(st.end) · \(Cal.num(st.days)) 天 · \(Cal.num(st.hours)) 小时 · 导出 \(Cal.todayKey())</p>
          </div>
          <div class="pay">
            <div class="k">实发工资</div>
            <div class="v">\(Cal.money(st.pay))<small style="font-size:12px;font-weight:400;color:var(--ink3)"> 元</small></div>
          </div>
        </header>

        <div class="cards">
          <div class="card"><div class="k">总工时</div><div class="v">\(Cal.num(st.hours)) <small style="font-size:11px;font-weight:400;color:var(--ink3)">H</small></div></div>
          <div class="card"><div class="k">出勤</div><div class="v">\(Cal.num(st.days)) <small style="font-size:11px;font-weight:400;color:var(--ink3)">天</small></div></div>
          <div class="card"><div class="k">日均工时</div><div class="v">\(Cal.num(st.days > 0 ? st.hours / st.days : 0)) <small style="font-size:11px;font-weight:400;color:var(--ink3)">H</small></div></div>
          <div class="card"><div class="k">补贴</div><div class="v pos">+\(Cal.money(st.bonus))</div></div>
          <div class="card"><div class="k">扣款</div><div class="v neg">-\(Cal.money(st.deduct))</div></div>
          <div class="card"><div class="k">平均时薪</div><div class="v">\(Cal.money(st.avg))</div></div>
        </div>

        <h2>工时构成</h2>
        <div class="bars">
          \(bar("正班", st.zb, "var(--accent)"))
          \(bar("加班", st.jb, "var(--orange)"))
          \(bar("周末", st.zm, "var(--orange)"))
          \(bar("节假", st.jj, "var(--red)"))
        </div>

        <h2>逐日明细</h2>
        <div class="table-wrap">
        <table><thead><tr><th class="c">日</th><th>星期</th><th>班次</th>
        <th class="n">正班</th><th class="n">加班</th><th class="n">周末</th><th class="n">节假</th>
        <th class="n">工时</th><th class="n">金额</th><th>备注</th></tr></thead>
        <tbody>\(dayRows)</tbody></table>
        </div>
        <div class="sum"><span>合计 \(Cal.num(st.days)) 天 · \(Cal.num(st.hours)) H</span><b>\(Cal.money(st.pay)) 元</b></div>

        <h2>补贴与扣款</h2>
        <div class="cols">
          <div>
            <div style="font-size:11px;color:var(--ink3);margin-bottom:6px">补贴 +\(Cal.money(st.bonus))</div>
            \(extraTable(bonuses, "pos"))
          </div>
          <div>
            <div style="font-size:11px;color:var(--ink3);margin-bottom:6px">扣款 -\(Cal.money(st.deduct))</div>
            \(extraTable(deductions, "neg"))
          </div>
        </div>

        <footer>
          由工时记录 App 导出 · 数据仅存于本机<br>
          表头数字单位：工时列均为小时，金额列为元。
        </footer>
        </div></body></html>
        """
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

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
