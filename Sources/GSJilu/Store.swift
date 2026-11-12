import Foundation
import Combine
import Compression

final class GSStore: ObservableObject {
    static let shared = GSStore()

    @Published private(set) var revision: Int = 0
    private(set) var data: [String: Any] = [:]

    var settings: [String: Any] { GSJSONDict(data["settings"]) }
    var projects: [[String: Any]] { (data["projects"] as? [[String: Any]]) ?? [] }
    var classes: [[String: Any]] { (data["classes"] as? [[String: Any]]) ?? [] }
    var records: [String: [String: Any]] {
        (data["records"] as? [String: [String: Any]]) ?? [:]
    }
    var plans: [String: String] {
        var out: [String: String] = [:]
        for (k, v) in GSJSONDict(data["plans"]) {
            if let s = v as? String { out[k] = s }
        }
        return out
    }

    private init() { load() }

    private func filePath() -> String {
        let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
        return (dir as NSString).appendingPathComponent("gsjilu.json")
    }

    private func defaults() -> [String: Any] {
        let settings: [String: Any] = [
            "period": 26,
            "customPeriods": [[String: Any]](),
            "weekStart": 1,
            "payday": 0,
            "nightMode": true,
            "autoBonus": true,
            "recordMode": "hour",
            "classDisplay": "icon",
            "annualLeaveDays": 5,
            "theme": "blue",
            "headerRadius": 24,
            "cardRadius": 20,
            "cardShadow": true,
            "animations": true,
            "showLunar": true,
            "defaultWork": ["zb": 8, "jb": 2, "zm": 10, "jj": 10],
            "dayAllowance": 10,
            "nightAllowance": 20,
            "reminderEnabled": false,
            "reminderHour": 21,
            "reminderMinute": 0,
            "classDefaults": [
                "1": ["zb": 8, "jb": 2, "zm": 10, "jj": 10, "rjgz": 0],
                "4": ["zb": 8, "jb": 4, "zm": 12, "jj": 12, "rjgz": 0]
            ],
            "projectId": "default",
            "currentClass": "1",
            "autoCarryMonth": ""
        ]
        let projects: [[String: Any]] = [
            ["id": "default", "name": "默认项目", "mode": "dxjs", "base": 2230,
             "rates": ["zb": 12.82, "jb": 19.23, "zm": 25.64, "jj": 38.46]],
            ["id": "2", "name": "祥发模具", "mode": "gddx", "base": 3300,
             "rates": ["zb": 18.97, "jb": 18.96, "zm": 25.28, "jj": 37.92]]
        ]
        let classes: [[String: Any]] = [
            ["id": "1", "name": "白班", "color": "#FCB819"],
            ["id": "2", "name": "早班", "color": "#33A0FF"],
            ["id": "3", "name": "中班", "color": "#FF9900"],
            ["id": "4", "name": "晚班", "color": "#224799"]
        ]
        return [
            "v": 2,
            "settings": settings,
            "projects": projects,
            "classes": classes,
            "records": [String: Any](),
            "plans": [String: Any](),
            "bonuses": [String: Any](),
            "deductions": [String: Any]()
        ]
    }

    private func sanitizeData() {
        var settings = GSJSONDict(data["settings"])
        if !(settings["period"] is NSNumber || settings["period"] is Int) { settings["period"] = 26 }
        var pday = GSJSONInt(settings["period"])
        if pday < 1 || pday > 29 { settings["period"] = 26; pday = 26 }
        if !(settings["weekStart"] is NSNumber || settings["weekStart"] is Int) { settings["weekStart"] = 1 }
        if !(settings["theme"] is String) { settings["theme"] = "blue" }
        if !(settings["headerRadius"] is NSNumber || settings["headerRadius"] is Double || settings["headerRadius"] is Int) { settings["headerRadius"] = 24 }
        if !(settings["cardRadius"] is NSNumber || settings["cardRadius"] is Double || settings["cardRadius"] is Int) { settings["cardRadius"] = 20 }
        if !(settings["cardShadow"] is Bool || settings["cardShadow"] is NSNumber) { settings["cardShadow"] = true }
        if !(settings["animations"] is Bool || settings["animations"] is NSNumber) { settings["animations"] = true }
        if !(settings["showLunar"] is Bool || settings["showLunar"] is NSNumber) { settings["showLunar"] = true }
        var hr = GSJSONNumber(settings["headerRadius"])
        if hr < 0 { hr = 0 }
        if hr > 40 { hr = 40 }
        settings["headerRadius"] = hr
        if !(settings["payday"] is NSNumber || settings["payday"] is Int) { settings["payday"] = 0 }
        var payday = GSJSONInt(settings["payday"])
        if payday < 0 || payday > 31 { settings["payday"] = 0; payday = 0 }
        if !(settings["nightMode"] is Bool || settings["nightMode"] is NSNumber) { settings["nightMode"] = true }
        if !(settings["autoBonus"] is Bool || settings["autoBonus"] is NSNumber) { settings["autoBonus"] = true }
        if !(settings["annualLeaveDays"] is NSNumber || settings["annualLeaveDays"] is Double || settings["annualLeaveDays"] is Int) { settings["annualLeaveDays"] = 5 }
        if !(settings["dayAllowance"] is NSNumber || settings["dayAllowance"] is Double || settings["dayAllowance"] is Int) { settings["dayAllowance"] = 10 }
        if !(settings["nightAllowance"] is NSNumber || settings["nightAllowance"] is Double || settings["nightAllowance"] is Int) { settings["nightAllowance"] = 20 }
        if !(settings["reminderEnabled"] is Bool || settings["reminderEnabled"] is NSNumber) { settings["reminderEnabled"] = false }
        if !(settings["reminderHour"] is NSNumber || settings["reminderHour"] is Int) { settings["reminderHour"] = 21 }
        if !(settings["reminderMinute"] is NSNumber || settings["reminderMinute"] is Int) { settings["reminderMinute"] = 0 }
        var rh = GSJSONInt(settings["reminderHour"]); if rh < 0 || rh > 23 { settings["reminderHour"] = 21 }
        var rm = GSJSONInt(settings["reminderMinute"]); if rm < 0 || rm > 59 { settings["reminderMinute"] = 0 }
        if !(settings["projectId"] is String) { settings["projectId"] = "default" }
        if !(settings["currentClass"] is String) { settings["currentClass"] = "1" }

        var cleanPeriods: [[String: Any]] = []
        for p in GSJSONArray(settings["customPeriods"]) {
            guard let dict = p as? [String: Any],
                  dict["start"] is String, dict["end"] is String else { continue }
            cleanPeriods.append(["start": dict["start"] as Any, "end": dict["end"] as Any])
        }
        settings["customPeriods"] = cleanPeriods

        var cd = GSJSONDict(settings["classDefaults"])
        for ck in Array(cd.keys) {
            guard var cv = cd[ck] as? [String: Any] else { cd.removeValue(forKey: ck); continue }
            for wk in ["zb", "jb", "zm", "jj", "rjgz"] {
                if !(cv[wk] is NSNumber || cv[wk] is Double || cv[wk] is Int) { cv[wk] = 0 }
            }
            cd[ck] = cv
        }
        settings["classDefaults"] = cd
        if !(settings["defaultWork"] is [String: Any]) {
            settings["defaultWork"] = ["zb": 8, "jb": 2, "zm": 10, "jj": 10]
        }
        data["settings"] = settings

        if let projects = data["projects"] as? [Any] {
            var clean: [[String: Any]] = []
            for p in projects {
                guard var pp = p as? [String: Any] else { continue }
                if !(pp["id"] is String) { pp["id"] = UUID().uuidString }
                if !(pp["name"] is String) { pp["name"] = "项目" }
                var rates = GSJSONDict(pp["rates"])
                for rk in ["zb", "jb", "zm", "jj"] {
                    if !(rates[rk] is NSNumber || rates[rk] is Double || rates[rk] is Int) { rates[rk] = 0 }
                }
                pp["rates"] = rates
                if !(pp["base"] is NSNumber || pp["base"] is Double || pp["base"] is Int) { pp["base"] = 0 }
                clean.append(pp)
            }
            data["projects"] = clean
        }

        var records = GSJSONDict(data["records"])
        for k in Array(records.keys) {
            guard var r = records[k] as? [String: Any] else { records.removeValue(forKey: k); continue }
            if var w = r["work"] as? [String: Any] {
                for wk in ["zb", "jb", "zm", "jj"] {
                    if !(w[wk] is NSNumber || w[wk] is Double || w[wk] is Int) { w[wk] = 0 }
                }
                r["work"] = w
            } else {
                r["work"] = ["zb": 0, "jb": 0, "zm": 0, "jj": 0]
            }
            if let bt = r["bt"] as? [Any] {
                var clean: [[String: Any]] = []
                for b in bt {
                    guard var bb = b as? [String: Any] else { continue }
                    if !(bb["name"] is String) { bb["name"] = "" }
                    if !(bb["money"] is NSNumber || bb["money"] is Double || bb["money"] is Int) { bb["money"] = 0 }
                    clean.append(bb)
                }
                r["bt"] = clean
            } else {
                r["bt"] = [[String: Any]]()
            }
            if r["leave"] != nil, !(r["leave"] is [String: Any]) {
                r.removeValue(forKey: "leave")
            } else if var lv = r["leave"] as? [String: Any] {
                if !(lv["hour"] is NSNumber || lv["hour"] is Double || lv["hour"] is Int) { lv["hour"] = 0 }
                if !(lv["multiple"] is NSNumber || lv["multiple"] is Double || lv["multiple"] is Int) { lv["multiple"] = 1 }
                if !(lv["rule"] is String) { lv["rule"] = "hour" }
                if !(lv["type"] is String) { lv["type"] = "xiu" }
                if !(lv["money"] is NSNumber || lv["money"] is Double || lv["money"] is Int) { lv["money"] = 0 }
                r["leave"] = lv
            }
            if !(r["settle"] is NSNumber || r["settle"] is Double || r["settle"] is Int) { r["settle"] = 0 }
            if r["note"] != nil, !(r["note"] is String) { r["note"] = "" }
            if !(r["projectId"] is String) { r["projectId"] = GSJSONString(settings["projectId"]) ?? "default" }
            if !(r["classId"] is String) { r["classId"] = GSJSONString(settings["currentClass"]) ?? "1" }
            records[k] = r
        }
        data["records"] = records

        for key in ["bonuses", "deductions"] {
            var bd = GSJSONDict(data[key])
            for mk in Array(bd.keys) {
                guard let arr = bd[mk] as? [Any] else { bd.removeValue(forKey: mk); continue }
                var clean: [[String: Any]] = []
                for b in arr {
                    guard var bb = b as? [String: Any] else { continue }
                    if !(bb["name"] is String) { bb["name"] = "补扣" }
                    if !(bb["money"] is NSNumber || bb["money"] is Double || bb["money"] is Int) { bb["money"] = 0 }
                    clean.append(bb)
                }
                bd[mk] = clean
            }
            data[key] = bd
        }
    }

    func load() {
        if let d = try? Data(contentsOf: URL(fileURLWithPath: filePath())),
           let obj = try? JSONSerialization.jsonObject(with: d, options: [.mutableContainers, .mutableLeaves]) as? [String: Any],
           GSJSONInt(obj["v"]) == 2 {
            data = obj
            if data["settings"] == nil { data["settings"] = defaults()["settings"] }
            if data["records"] == nil { data["records"] = [String: Any]() }
            if data["plans"] == nil { data["plans"] = [String: Any]() }
            if data["bonuses"] == nil { data["bonuses"] = [String: Any]() }
            if data["deductions"] == nil { data["deductions"] = [String: Any]() }
            sanitizeData()
            autoCarry()
            bump()
            return
        }
        data = defaults()
        sanitizeData()
        save()
        bump()
    }

    func save() {
        guard JSONSerialization.isValidJSONObject(data),
              let d = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .fragmentsAllowed]) else { return }
        try? d.write(to: URL(fileURLWithPath: filePath()), options: .atomic)
    }

    private func bump() {
        objectWillChange.send()
        revision += 1
    }

    private func mutate(_ block: () -> Void) {
        block()
        save()
        bump()
    }

    func setting<T>(_ key: String, default def: T) -> T {
        if let v = settings[key] as? T { return v }
        return def
    }

    func boolSetting(_ key: String, default def: Bool = false) -> Bool {
        GSJSONBool(settings[key], default: def)
    }

    func numberSetting(_ key: String, default def: Double = 0) -> Double {
        settings[key] == nil ? def : GSJSONNumber(settings[key])
    }

    func intSetting(_ key: String, default def: Int = 0) -> Int {
        settings[key] == nil ? def : GSJSONInt(settings[key])
    }

    func stringSetting(_ key: String, default def: String) -> String {
        GSJSONString(settings[key]) ?? def
    }

    func setSetting(_ key: String, _ value: Any) {
        mutate {
            var s = GSJSONDict(data["settings"])
            s[key] = value
            data["settings"] = s
        }
    }

    var themeKey: String { GSTheme.normalized(stringSetting("theme", default: "blue")) }
    var cardRadius: CGFloat {
        let v = numberSetting("cardRadius", default: 20)
        return CGFloat(max(8, min(30, v > 0 ? v : 20)))
    }
    var headerRadius: CGFloat {
        let v = numberSetting("headerRadius", default: 24)
        return CGFloat(max(0, min(40, v)))
    }
    var cardShadow: Bool { boolSetting("cardShadow", default: true) }
    var animations: Bool { settings["animations"] == nil ? true : boolSetting("animations", default: true) }
    var showLunar: Bool { settings["showLunar"] == nil ? true : boolSetting("showLunar", default: true) }
    var weekStart: Int { intSetting("weekStart", default: 1) == 0 ? 0 : 1 }

    func project(id pid: String?) -> [String: Any]? {
        if let pid = pid {
            if let p = projects.first(where: { ($0["id"] as? String) == pid }) { return p }
        }
        return projects.first
    }

    func classItem(id cid: String?) -> [String: Any]? {
        guard let cid = cid else { return nil }
        return classes.first(where: { ($0["id"] as? String) == cid })
    }

    func record(for date: String) -> [String: Any]? {
        GSJSONDict(data["records"])[date] as? [String: Any]
    }

    func setRecord(_ rec: [String: Any], for date: String) {
        mutate {
            var records = GSJSONDict(data["records"])
            records[date] = rec
            data["records"] = records
        }
    }

    func removeRecord(for date: String) {
        mutate {
            var records = GSJSONDict(data["records"])
            records.removeValue(forKey: date)
            data["records"] = records
        }
    }

    func plan(for date: String) -> String {
        let p = GSJSONDict(data["plans"])[date]
        return (p as? String) ?? ""
    }

    func setPlan(_ classId: String, for date: String) {
        mutate {
            var plans = GSJSONDict(data["plans"])
            if classId.isEmpty { plans.removeValue(forKey: date) }
            else { plans[date] = classId }
            data["plans"] = plans
        }
    }

    func rate(project pid: String?, type: String) -> Double {
        let p = project(id: pid)
        return GSJSONNumber(GSJSONDict(p?["rates"])[type])
    }

    func dayHours(_ rec: [String: Any]?) -> Double {
        guard let rec = rec else { return 0 }
        let w = GSJSONDict(rec["work"])
        return GSJSONNumber(w["zb"]) + GSJSONNumber(w["jb"]) + GSJSONNumber(w["zm"]) + GSJSONNumber(w["jj"])
    }

    func annualLeaveTotalDays() -> Double {
        max(0, numberSetting("annualLeaveDays", default: 5))
    }

    func annualLeaveUsedDays(year: Int) -> Double {
        var hours: Double = 0
        let prefix = String(format: "%04ld-", year)
        for (k, raw) in GSJSONDict(data["records"]) {
            if !k.hasPrefix(prefix) { continue }
            let r = GSJSONDict(raw)
            let lv = GSJSONDict(r["leave"])
            guard r["leave"] is [String: Any], (lv["type"] as? String) == "xiu" else { continue }
            hours += GSJSONNumber(lv["hour"])
        }
        return GSRound2(hours / 8.0)
    }

    func annualLeaveRemainingDays(year: Int) -> Double {
        GSRound2(annualLeaveTotalDays() - annualLeaveUsedDays(year: year))
    }

    func leavePay(_ rec: [String: Any]) -> Double {
        guard rec["leave"] is [String: Any] else { return 0 }
        let l = GSJSONDict(rec["leave"])
        let h = GSJSONNumber(l["hour"])
        if h <= 0 { return 0 }
        if (l["rule"] as? String) == "money" { return GSJSONNumber(l["money"]) }
        return h * rate(project: rec["projectId"] as? String, type: "zb") * GSJSONNumber(l["multiple"])
    }

    func dayPay(_ rec: [String: Any]?) -> Double {
        guard let rec = rec else { return 0 }
        let settle = GSJSONNumber(rec["settle"])
        var bt: Double = 0
        for b in GSJSONArray(rec["bt"]) {
            bt += GSJSONNumber(GSJSONDict(b)["money"])
        }
        if settle > 0 { return GSRound2(settle + bt) }
        var p: Double = 0
        let w = GSJSONDict(rec["work"])
        for k in ["zb", "jb", "zm", "jj"] {
            p += GSJSONNumber(w[k]) * rate(project: rec["projectId"] as? String, type: k)
        }
        p += leavePay(rec)
        return GSRound2(p + bt)
    }

    func daySummary(_ rec: [String: Any]?) -> String {
        guard let rec = rec else { return "未记录" }
        let w = GSJSONDict(rec["work"])
        let zb = GSJSONNumber(w["zb"]), jb = GSJSONNumber(w["jb"])
        if zb > 0 && jb > 0 { return "\(GSNum(zb))+\(GSNum(jb))" }
        let h = dayHours(rec)
        if h > 0 { return "\(GSNum(h))h" }
        if rec["leave"] is [String: Any] {
            return "休\(GSNum(GSJSONNumber(GSJSONDict(rec["leave"])["hour"])))"
        }
        if GSJSONNumber(rec["settle"]) > 0 { return "日结" }
        return "记"
    }

    func periodRange(year: Int, month: Int) -> [String: String] {
        let prefix = String(format: "%04ld-%02ld", year, month)
        for p in GSJSONArray(settings["customPeriods"]) {
            let dict = GSJSONDict(p)
            if let start = dict["start"] as? String, start.hasPrefix(prefix),
               let end = dict["end"] as? String, start.count >= 10, end.count >= 10 {
                let s = String(start.dropFirst(5))
                let e = String(end.dropFirst(5))
                return ["start": start, "end": end, "label": "\(s) - \(e)"]
            }
        }
        var day = intSetting("period", default: 26)
        if day < 1 || day > 29 { day = 26 }
        let curDays = GSDate.daysInMonth(year: year, month: month)
        if day == 1 {
            let s = String(format: "%04ld-%02ld-01", year, month)
            let e = String(format: "%04ld-%02ld-%02ld", year, month, curDays)
            return ["start": s, "end": e, "label": "1号 - 月底"]
        }
        let nc = GSDate.monthAdd(year: year, month: month, delta: 1)
        let nextDays = GSDate.daysInMonth(year: nc.year, month: nc.month)
        let sd = min(day, curDays)
        let ed = min(day - 1, nextDays)
        var ps = DateComponents(); ps.year = year; ps.month = month; ps.day = sd
        var ee = DateComponents(); ee.year = nc.year; ee.month = nc.month; ee.day = ed
        let sDate = GSDate.gregorian.date(from: ps) ?? Date()
        let eDate = GSDate.gregorian.date(from: ee) ?? Date()
        return [
            "start": GSDate.key(from: sDate),
            "end": GSDate.key(from: eDate),
            "label": "\(month).\(sd) - \(nc.month).\(ed)"
        ]
    }

    func monthStats(year: Int, month: Int, usePeriod: Bool) -> [String: Any] {
        let range = periodRange(year: year, month: month)
        let prefix = String(format: "%04ld-%02ld-", year, month)
        var days = 0.0, hours = 0.0, pay = 0.0, zb = 0.0, jb = 0.0, zm = 0.0, jj = 0.0, bonus = 0.0, deduct = 0.0
        let start = range["start"] ?? "", end = range["end"] ?? ""
        for (k, raw) in GSJSONDict(data["records"]) {
            if usePeriod {
                if k < start || k > end { continue }
            } else if !k.hasPrefix(prefix) {
                continue
            }
            let r = GSJSONDict(raw)
            days += 1
            hours += dayHours(r)
            pay += dayPay(r)
            let w = GSJSONDict(r["work"])
            zb += GSJSONNumber(w["zb"]); jb += GSJSONNumber(w["jb"]); zm += GSJSONNumber(w["zm"]); jj += GSJSONNumber(w["jj"])
            for b in GSJSONArray(r["bt"]) {
                let m = GSJSONNumber(GSJSONDict(b)["money"])
                if m >= 0 { bonus += m } else { deduct += -m }
            }
        }
        let mk = GSDate.monthKey(year, month)
        for b in extras(kind: "bonus", year: year, month: month) {
            let m = GSJSONNumber(b["money"]); bonus += m; pay += m
        }
        for b in extras(kind: "deduct", year: year, month: month) {
            let m = GSJSONNumber(b["money"]); deduct += m; pay -= m
        }
        _ = mk
        return [
            "days": days, "hours": GSRound2(hours), "pay": GSRound2(pay),
            "zb": GSRound2(zb), "jb": GSRound2(jb), "zm": GSRound2(zm), "jj": GSRound2(jj),
            "bonus": GSRound2(bonus), "deduct": GSRound2(deduct),
            "avg": hours > 0 ? GSRound2(pay / hours) : 0,
            "label": range["label"] ?? "", "start": start, "end": end
        ]
    }

    func yearStats(year: Int) -> [String: Any] {
        var buckets: [[String: Double]] = (0..<12).map { _ in
            ["days": 0, "hours": 0, "pay": 0, "zb": 0, "jb": 0, "zm": 0, "jj": 0, "bonus": 0, "deduct": 0]
        }
        let yearPrefix = String(format: "%04ld-", year)
        for (k, raw) in GSJSONDict(data["records"]) {
            if k.count < 7 || !k.hasPrefix(yearPrefix) { continue }
            let mon = Int(k.dropFirst(5).prefix(2)) ?? 0
            if mon < 1 || mon > 12 { continue }
            let r = GSJSONDict(raw)
            var b = buckets[mon - 1]
            b["days"] = (b["days"] ?? 0) + 1
            b["hours"] = (b["hours"] ?? 0) + dayHours(r)
            b["pay"] = (b["pay"] ?? 0) + dayPay(r)
            let w = GSJSONDict(r["work"])
            b["zb"] = (b["zb"] ?? 0) + GSJSONNumber(w["zb"])
            b["jb"] = (b["jb"] ?? 0) + GSJSONNumber(w["jb"])
            b["zm"] = (b["zm"] ?? 0) + GSJSONNumber(w["zm"])
            b["jj"] = (b["jj"] ?? 0) + GSJSONNumber(w["jj"])
            for item in GSJSONArray(r["bt"]) {
                let m = GSJSONNumber(GSJSONDict(item)["money"])
                if m >= 0 { b["bonus"] = (b["bonus"] ?? 0) + m }
                else { b["deduct"] = (b["deduct"] ?? 0) - m }
            }
            buckets[mon - 1] = b
        }
        var totalPay = 0.0, totalHours = 0.0, totalDays = 0.0, totalOT = 0.0, totalBonus = 0.0, totalDeduct = 0.0
        var months: [[String: Any]] = []
        for m in 1...12 {
            var b = buckets[m - 1]
            let range = periodRange(year: year, month: m)
            for item in extras(kind: "bonus", year: year, month: m) {
                let value = GSJSONNumber(item["money"])
                b["bonus"] = (b["bonus"] ?? 0) + value
                b["pay"] = (b["pay"] ?? 0) + value
            }
            for item in extras(kind: "deduct", year: year, month: m) {
                let value = GSJSONNumber(item["money"])
                b["deduct"] = (b["deduct"] ?? 0) + value
                b["pay"] = (b["pay"] ?? 0) - value
            }
            let rawHours = b["hours"] ?? 0
            let rawPay = b["pay"] ?? 0
            let monthHours = GSRound2(rawHours)
            let monthPay = GSRound2(rawPay)
            let monthBonus = GSRound2(b["bonus"] ?? 0)
            let monthDeduct = GSRound2(b["deduct"] ?? 0)
            let monthZB = GSRound2(b["zb"] ?? 0)
            let monthJB = GSRound2(b["jb"] ?? 0)
            let monthZM = GSRound2(b["zm"] ?? 0)
            let monthJJ = GSRound2(b["jj"] ?? 0)
            let monthDays = b["days"] ?? 0
            months.append([
                "days": monthDays, "hours": monthHours, "pay": monthPay,
                "zb": monthZB, "jb": monthJB, "zm": monthZM, "jj": monthJJ,
                "bonus": monthBonus, "deduct": monthDeduct,
                "avg": rawHours > 0 ? GSRound2(rawPay / rawHours) : 0,
                "label": range["label"] ?? "", "start": range["start"] ?? "", "end": range["end"] ?? ""
            ])
            totalPay += monthPay
            totalHours += monthHours
            totalDays += monthDays
            totalOT += monthJB + monthZM + monthJJ
            totalBonus += monthBonus
            totalDeduct += monthDeduct
        }
        totalPay = GSRound2(totalPay)
        totalHours = GSRound2(totalHours)
        totalOT = GSRound2(totalOT)
        totalBonus = GSRound2(totalBonus)
        totalDeduct = GSRound2(totalDeduct)
        return [
            "months": months, "pay": totalPay, "hours": totalHours, "days": totalDays,
            "ot": totalOT, "bonus": totalBonus, "deduct": totalDeduct,
            "workPay": GSRound2(totalPay - totalBonus + totalDeduct),
            "avg": totalHours > 0 ? GSRound2(totalPay / totalHours) : 0
        ]
    }

    func dailyKeys(year: Int, month: Int) -> [String] {
        let prefix = String(format: "%04ld-%02ld-", year, month)
        return GSJSONDict(data["records"]).keys.filter { $0.hasPrefix(prefix) }.sorted()
    }

    func extras(kind: String, year: Int, month: Int) -> [[String: Any]] {
        let dict = GSJSONDict(data[kind == "bonus" ? "bonuses" : "deductions"])
        return (dict[GSDate.monthKey(year, month)] as? [[String: Any]]) ?? []
    }

    func addExtra(kind: String, year: Int, month: Int, name: String, money: Double, note: String) {
        mutate {
            let key = kind == "bonus" ? "bonuses" : "deductions"
            var dict = GSJSONDict(data[key])
            let mk = GSDate.monthKey(year, month)
            var a = (dict[mk] as? [[String: Any]]) ?? []
            a.append(["id": UUID().uuidString, "name": name.isEmpty ? "补扣" : name, "money": abs(money), "note": note, "auto": false])
            dict[mk] = a
            data[key] = dict
        }
    }

    func deleteExtra(kind: String, year: Int, month: Int, index: Int) {
        mutate {
            let key = kind == "bonus" ? "bonuses" : "deductions"
            var dict = GSJSONDict(data[key])
            let mk = GSDate.monthKey(year, month)
            var a = (dict[mk] as? [[String: Any]]) ?? []
            if index >= 0 && index < a.count { a.remove(at: index); dict[mk] = a; data[key] = dict }
        }
    }

    func importLastMonth(kind: String, year: Int, month: Int) {
        let prev = GSDate.monthAdd(year: year, month: month, delta: -1)
        let src = extras(kind: kind, year: prev.year, month: prev.month)
        if src.isEmpty { return }
        mutate {
            let key = kind == "bonus" ? "bonuses" : "deductions"
            var dict = GSJSONDict(data[key])
            let mk = GSDate.monthKey(year, month)
            var a = (dict[mk] as? [[String: Any]]) ?? []
            for b in src {
                let exists = a.contains { ($0["name"] as? String) == (b["name"] as? String) && abs(GSJSONNumber($0["money"]) - GSJSONNumber(b["money"])) < 0.001 }
                if !exists {
                    a.append(["id": UUID().uuidString, "name": b["name"] ?? "补扣", "money": b["money"] ?? 0, "note": "上月导入", "auto": true])
                }
            }
            dict[mk] = a
            data[key] = dict
        }
    }

    func importLastMonthBoth(year: Int, month: Int) {
        importLastMonth(kind: "bonus", year: year, month: month)
        importLastMonth(kind: "deduct", year: year, month: month)
    }

    func autoCarry() {
        let now = Date()
        let y = GSDate.gregorian.component(.year, from: now)
        let m = GSDate.gregorian.component(.month, from: now)
        let cur = GSDate.monthKey(y, m)
        if stringSetting("autoCarryMonth", default: "") == cur { return }
        importLastMonth(kind: "bonus", year: y, month: m)
        importLastMonth(kind: "deduct", year: y, month: m)
        var s = GSJSONDict(data["settings"])
        s["autoCarryMonth"] = cur
        data["settings"] = s
        save()
    }

    func defaultWork(for cid: String?) -> [String: Any] {
        let cd = GSJSONDict(settings["classDefaults"])
        if let cid = cid, let d = cd[cid] as? [String: Any] { return d }
        let fallback = GSJSONDict(settings["defaultWork"])
        return fallback.isEmpty ? ["zb": 8, "jb": 2, "zm": 10, "jj": 10] : fallback
    }

    func allowanceName(for cid: String?) -> String? {
        let name = (classItem(id: cid)?["name"] as? String) ?? ""
        if name.contains("夜") || name.contains("中") || name.contains("晚") { return "夜班补助" }
        if name.contains("白") || name.contains("早") { return "白班补助" }
        return nil
    }

    func ensureAutoAllowance(_ rec: inout [String: Any]) {
        if !boolSetting("autoBonus", default: true) { return }
        if (rec["type"] as? String) == "xiu" { return }
        var workTotal: Double = 0
        let work = GSJSONDict(rec["work"])
        for k in ["zb", "jb", "zm", "jj"] { workTotal += GSJSONNumber(work[k]) }
        let hasLeave = rec["leave"] is [String: Any]
        if workTotal <= 0 && !hasLeave { return }
        guard let allowName = allowanceName(for: rec["classId"] as? String) else { return }
        let night = allowName == "夜班补助"
        let amount = night ? numberSetting("nightAllowance") : numberSetting("dayAllowance")
        if amount <= 0 { return }
        var bt = (rec["bt"] as? [[String: Any]]) ?? []
        if bt.contains(where: { ($0["name"] as? String) == allowName }) {
            rec["bt"] = bt
            return
        }
        bt.append(["name": allowName, "money": amount, "note": "自动补助", "autoAllowance": true])
        rec["bt"] = bt
    }

    func setClassDefault(cid: String, key: String, value: Double) {
        mutate {
            var s = GSJSONDict(data["settings"])
            var cd = GSJSONDict(s["classDefaults"])
            var d = GSJSONDict(cd[cid])
            d[key] = value
            cd[cid] = d
            s["classDefaults"] = cd
            data["settings"] = s
        }
    }

    @discardableResult
    func removeAutoAllowance(named name: String) -> Int {
        var removed = 0
        mutate {
            var records = GSJSONDict(data["records"])
            for key in Array(records.keys) {
                guard var rec = records[key] as? [String: Any] else { continue }
                let raw = rec["bt"] as? [[String: Any]] ?? []
                var kept: [[String: Any]] = []
                var changed = false
                for b in raw {
                    let autoEntry = GSJSONBool(b["autoAllowance"]) || (b["note"] as? String) == "自动补助"
                    if autoEntry && (b["name"] as? String) == name {
                        changed = true; removed += 1; continue
                    }
                    kept.append(b)
                }
                if changed { rec["bt"] = kept; records[key] = rec }
            }
            data["records"] = records
        }
        return removed
    }

    func clearAllRecords() {
        mutate {
            data["records"] = [String: Any]()
            data["plans"] = [String: Any]()
            data["bonuses"] = [String: Any]()
            data["deductions"] = [String: Any]()
        }
    }

    func backupDictionary() -> [String: Any] {
        var days: [[String: Any]] = []
        var totalHours = 0.0, totalPay = 0.0
        let keys = GSJSONDict(data["records"]).keys.sorted()
        for date in keys {
            guard let rec = record(for: date) else { continue }
            var item: [String: Any] = [:]
            item["d"] = date
            if let c = rec["classId"] { item["c"] = c }
            if let p = rec["projectId"] { item["p"] = p }
            item["t"] = rec["type"] ?? "zb"
            let w = GSJSONDict(rec["work"])
            item["w"] = [GSJSONNumber(w["zb"]), GSJSONNumber(w["jb"]), GSJSONNumber(w["zm"]), GSJSONNumber(w["jj"])]
            if GSJSONNumber(rec["settle"]) > 0 { item["s"] = rec["settle"] as Any }
            if let bt = rec["bt"] as? [Any], !bt.isEmpty { item["b"] = bt }
            if rec["leave"] is [String: Any] { item["l"] = rec["leave"] as Any }
            if let n = rec["note"] as? String, !n.isEmpty { item["n"] = n }
            days.append(item)
            totalHours += dayHours(rec)
            totalPay += dayPay(rec)
        }
        let fmt = ISO8601DateFormatter()
        return [
            "app": "工时记录",
            "format": "gsjilu-backup",
            "version": 4,
            "exportedAt": fmt.string(from: Date()),
            "summary": ["days": days.count, "hours": GSRound2(totalHours), "pay": GSRound2(totalPay)],
            "settings": settings,
            "projects": projects,
            "classes": classes,
            "plans": GSJSONDict(data["plans"]),
            "extras": ["bonus": GSJSONDict(data["bonuses"]), "deduct": GSJSONDict(data["deductions"])],
            "days": days
        ]
    }

    @discardableResult
    func importBackupData(_ raw: [String: Any]) -> Bool {
        var newData: [String: Any]
        if (raw["format"] as? String) == "gsjilu-backup", raw["days"] is [Any] {
            newData = defaults()
            if let s = raw["settings"] as? [String: Any] { newData["settings"] = s }
            if let p = raw["projects"] as? [Any] { newData["projects"] = p }
            if let c = raw["classes"] as? [Any] { newData["classes"] = c }
            if let p = raw["plans"] as? [String: Any] { newData["plans"] = p }
            let extras = GSJSONDict(raw["extras"])
            if let b = extras["bonus"] as? [String: Any] { newData["bonuses"] = b }
            if let d = extras["deduct"] as? [String: Any] { newData["deductions"] = d }
            var records: [String: Any] = [:]
            let defaultClass = GSJSONString(GSJSONDict(newData["settings"])["currentClass"]) ?? "1"
            let defaultProject = GSJSONString(GSJSONDict(newData["settings"])["projectId"]) ?? "default"
            for itemRaw in GSJSONArray(raw["days"]) {
                guard let item = itemRaw as? [String: Any],
                      let date = item["d"] as? String, date.count == 10 else { continue }
                var rec: [String: Any] = [:]
                rec["classId"] = (item["c"] as? String) ?? defaultClass
                rec["projectId"] = (item["p"] as? String) ?? defaultProject
                rec["type"] = (item["t"] as? String) ?? GSDayKind(date)
                let w = item["w"] as? [Any] ?? []
                rec["work"] = [
                    "zb": w.indices.contains(0) ? w[0] : 0,
                    "jb": w.indices.contains(1) ? w[1] : 0,
                    "zm": w.indices.contains(2) ? w[2] : 0,
                    "jj": w.indices.contains(3) ? w[3] : 0
                ]
                if let s = item["s"] { rec["settle"] = s }
                if let b = item["b"] as? [Any] { rec["bt"] = b }
                if let l = item["l"] as? [String: Any] { rec["leave"] = l }
                if let n = item["n"] as? String { rec["note"] = n }
                records[date] = rec
            }
            newData["records"] = records
        } else if raw["records"] is [String: Any] {
            newData = raw
        } else {
            return false
        }
        newData["v"] = 2
        data = newData
        sanitizeData()
        save()
        bump()
        return true
    }

    func reportText(year: Int, month: Int) -> String {
        let st = monthStats(year: year, month: month, usePeriod: true)
        let label = st["label"] as? String ?? ""
        var s = "\(year)年\(month)月 工时报表\n考勤周期 \(label)\n出勤 \(GSNum(GSJSONNumber(st["days"]))) 天 · 工时 \(GSNum(GSJSONNumber(st["hours"])))H · 工资 \(GSMoney(GSJSONNumber(st["pay"])))\n---\n"
        let start = st["start"] as? String ?? ""
        let end = st["end"] as? String ?? ""
        for k in GSJSONDict(data["records"]).keys.sorted() {
            if k < start || k > end { continue }
            if let r = record(for: k) {
                s += "\(k) \(daySummary(r)) \(GSMoney(dayPay(r)))\n"
            }
        }
        s += "---\n补贴 \(GSMoney(GSJSONNumber(st["bonus"]))) · 扣款 \(GSMoney(GSJSONNumber(st["deduct"])))\n"
        return s
    }

    func setProjects(_ list: [[String: Any]]) {
        mutate { data["projects"] = list }
    }

    func setClasses(_ list: [[String: Any]]) {
        mutate { data["classes"] = list }
    }

    func setCustomPeriods(_ list: [[String: Any]]) {
        mutate {
            var s = GSJSONDict(data["settings"])
            s["customPeriods"] = list
            data["settings"] = s
        }
    }
}
