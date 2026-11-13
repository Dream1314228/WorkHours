import Foundation

// MARK: - 容错解码

extension KeyedDecodingContainer {
    func dbl(_ key: Key) -> Double {
        (try? decodeIfPresent(Double.self, forKey: key)) ?? 0
    }
    func intg(_ key: Key) -> Int {
        (try? decodeIfPresent(Int.self, forKey: key)) ?? 0
    }
    func strg(_ key: Key, _ def: String = "") -> String {
        (try? decodeIfPresent(String.self, forKey: key)) ?? def
    }
    func boolv(_ key: Key, _ def: Bool = false) -> Bool {
        (try? decodeIfPresent(Bool.self, forKey: key)) ?? def
    }
    func dblOpt(_ key: Key) -> Double? {
        (try? decodeIfPresent(Double.self, forKey: key))
    }
}

// MARK: - 工时四段

/// 四类工时，字段名沿用旧版 JSON：zb 正班 / jb 加班 / zm 周末 / jj 节假
struct WorkHours: Codable, Hashable {
    var zb: Double = 0
    var jb: Double = 0
    var zm: Double = 0
    var jj: Double = 0

    init(zb: Double = 0, jb: Double = 0, zm: Double = 0, jj: Double = 0) {
        self.zb = zb; self.jb = jb; self.zm = zm; self.jj = jj
    }

    enum CodingKeys: String, CodingKey { case zb, jb, zm, jj }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zb = c.dbl(.zb); jb = c.dbl(.jb); zm = c.dbl(.zm); jj = c.dbl(.jj)
    }

    var total: Double { zb + jb + zm + jj }

    subscript(_ key: String) -> Double {
        get {
            switch key {
            case "zb": return zb
            case "jb": return jb
            case "zm": return zm
            case "jj": return jj
            default: return 0
            }
        }
        set {
            switch key {
            case "zb": zb = newValue
            case "jb": jb = newValue
            case "zm": zm = newValue
            case "jj": jj = newValue
            default: break
            }
        }
    }
}

// MARK: - 补贴 / 扣款

struct BonusItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var money: Double = 0
    var note: String = ""
    var autoAllowance: Bool = false

    enum CodingKeys: String, CodingKey { case id, name, money, note, autoAllowance }

    init(name: String, money: Double, note: String = "", autoAllowance: Bool = false) {
        self.name = name; self.money = money; self.note = note; self.autoAllowance = autoAllowance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.strg(.id, UUID().uuidString)
        name = c.strg(.name)
        money = c.dbl(.money)
        note = c.strg(.note)
        autoAllowance = c.boolv(.autoAllowance)
        if id.isEmpty { id = UUID().uuidString }
    }
}

// MARK: - 请假

struct LeaveInfo: Codable, Hashable {
    var type: String = "xiu"          // xiu / shi / bing / nian
    var hour: Double = 8
    var rule: String = "hour"          // hour / money
    var multiple: Double = 0
    var money: Double = 0

    enum CodingKeys: String, CodingKey { case type, hour, rule, multiple, money }

    init(type: String = "xiu", hour: Double = 8, rule: String = "hour", multiple: Double = 0, money: Double = 0) {
        self.type = type; self.hour = hour; self.rule = rule; self.multiple = multiple; self.money = money
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.strg(.type, "xiu")
        hour = c.dbl(.hour)
        rule = c.strg(.rule, "hour")
        multiple = c.dbl(.multiple)
        money = c.dbl(.money)
    }
}

// MARK: - 一天的记录

struct DayRecord: Codable, Hashable {
    var classId: String = "1"
    var projectId: String = "default"
    var type: String = "zb"            // zb / zm / jj / xiu
    var work: WorkHours = WorkHours()
    var bt: [BonusItem] = []
    var leave: LeaveInfo? = nil
    var settle: Double = 0
    var note: String = ""

    enum CodingKeys: String, CodingKey { case classId, projectId, type, work, bt, leave, settle, note }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        classId = c.strg(.classId, "1")
        projectId = c.strg(.projectId, "default")
        type = c.strg(.type, "zb")
        work = (try? c.decodeIfPresent(WorkHours.self, forKey: .work)) ?? WorkHours()
        bt = (try? c.decodeIfPresent([BonusItem].self, forKey: .bt)) ?? []
        leave = (try? c.decodeIfPresent(LeaveInfo.self, forKey: .leave))
        settle = c.dbl(.settle)
        note = c.strg(.note)
    }
}

// MARK: - 项目 / 班次

struct Project: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = "项目"
    var mode: String = "dxjs"          // dxjs 底薪+时薪 / gddx 固定单价
    var base: Double = 0
    var rates: WorkHours = WorkHours()

    enum CodingKeys: String, CodingKey { case id, name, mode, base, rates }

    init(id: String = UUID().uuidString, name: String, mode: String = "dxjs", base: Double = 0, rates: WorkHours = WorkHours()) {
        self.id = id; self.name = name; self.mode = mode; self.base = base; self.rates = rates
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.strg(.id, UUID().uuidString)
        name = c.strg(.name, "项目")
        mode = c.strg(.mode, "dxjs")
        base = c.dbl(.base)
        rates = (try? c.decodeIfPresent(WorkHours.self, forKey: .rates)) ?? WorkHours()
        if id.isEmpty { id = UUID().uuidString }
    }
}

struct ShiftClass: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String = "班次"
    var color: String = "#33A0FF"

    enum CodingKeys: String, CodingKey { case id, name, color }

    init(id: String = UUID().uuidString, name: String, color: String = "#33A0FF") {
        self.id = id; self.name = name; self.color = color
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.strg(.id, UUID().uuidString)
        name = c.strg(.name, "班次")
        color = c.strg(.color, "#33A0FF")
        if id.isEmpty { id = UUID().uuidString }
    }
}

extension ShiftClass {
    /// 班次图标，按名字猜，不写进数据
    var symbol: String {
        if name.contains("白") { return "sun.max.fill" }
        if name.contains("早") { return "sunrise.fill" }
        if name.contains("中") { return "sun.haze.fill" }
        if name.contains("晚") || name.contains("夜") { return "moon.stars.fill" }
        return "clock.fill"
    }
}

/// 班次默认工时（settings.classDefaults）
struct ClassDefault: Codable, Hashable {
    var zb: Double = 0
    var jb: Double = 0
    var zm: Double = 0
    var jj: Double = 0
    var rjgz: Double = 0

    enum CodingKeys: String, CodingKey { case zb, jb, zm, jj, rjgz }

    init(zb: Double = 0, jb: Double = 0, zm: Double = 0, jj: Double = 0, rjgz: Double = 0) {
        self.zb = zb; self.jb = jb; self.zm = zm; self.jj = jj; self.rjgz = rjgz
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zb = c.dbl(.zb); jb = c.dbl(.jb); zm = c.dbl(.zm); jj = c.dbl(.jj); rjgz = c.dbl(.rjgz)
    }

    var work: WorkHours { WorkHours(zb: zb, jb: jb, zm: zm, jj: jj) }
}

// MARK: - 手动考勤期

struct CustomPeriod: Codable, Hashable, Identifiable {
    var start: String = ""             // yyyy-MM-dd
    var end: String = ""
    var id: String { start + end }

    enum CodingKeys: String, CodingKey { case start, end }

    init(start: String, end: String) { self.start = start; self.end = end }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = c.strg(.start)
        end = c.strg(.end)
    }
}

// MARK: - 设置

struct Settings: Codable {
    var period: Int = 26                // 每月几号起算，1 表示自然月
    var customPeriods: [CustomPeriod] = []
    var weekStart: Int = 1              // 1 周一 / 7 周日
    var payday: Int = 0
    var nightMode: Bool = true
    var autoBonus: Bool = true
    var recordMode: String = "hour"
    var classDisplay: String = "icon"
    var annualLeaveDays: Double = 5
    var theme: String = "blue"
    var headerRadius: Double = 24
    var cardRadius: Double = 4
    var cardShadow: Bool = true
    var animations: Bool = true
    var showLunar: Bool = true
    var defaultWork: WorkHours = WorkHours(zb: 8, jb: 2, zm: 10, jj: 10)
    var dayAllowance: Double = 10
    var nightAllowance: Double = 20
    var reminderEnabled: Bool = false
    var reminderHour: Int = 21
    var reminderMinute: Int = 0
    var classDefaults: [String: ClassDefault] = [
        "1": ClassDefault(zb: 8, jb: 2, zm: 10, jj: 10),
        "4": ClassDefault(zb: 8, jb: 4, zm: 12, jj: 12)
    ]
    var projectId: String = "default"
    var currentClass: String = "1"
    var autoCarryMonth: String = ""

    enum CodingKeys: String, CodingKey {
        case period, customPeriods, weekStart, payday, nightMode, autoBonus, recordMode, classDisplay
        case annualLeaveDays, theme, headerRadius, cardRadius, cardShadow, animations, showLunar
        case defaultWork, dayAllowance, nightAllowance, reminderEnabled, reminderHour, reminderMinute
        case classDefaults, projectId, currentClass, autoCarryMonth
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        period = c.intg(.period)
        if period < 1 || period > 29 { period = 26 }
        customPeriods = (try? c.decodeIfPresent([CustomPeriod].self, forKey: .customPeriods)) ?? []
        customPeriods = customPeriods.filter { !$0.start.isEmpty && !$0.end.isEmpty }
        weekStart = c.intg(.weekStart)
        if weekStart != 1 && weekStart != 7 { weekStart = 1 }
        payday = c.intg(.payday)
        nightMode = c.boolv(.nightMode, true)
        autoBonus = c.boolv(.autoBonus, true)
        recordMode = c.strg(.recordMode, "hour")
        classDisplay = c.strg(.classDisplay, "icon")
        annualLeaveDays = c.dblOpt(.annualLeaveDays) ?? 5
        theme = c.strg(.theme, "blue")
        headerRadius = min(40, max(0, c.dblOpt(.headerRadius) ?? 24))
        cardRadius = min(36, max(0, c.dblOpt(.cardRadius) ?? 4))
        cardShadow = c.boolv(.cardShadow, true)
        animations = c.boolv(.animations, true)
        showLunar = c.boolv(.showLunar, true)
        defaultWork = (try? c.decodeIfPresent(WorkHours.self, forKey: .defaultWork))
            ?? WorkHours(zb: 8, jb: 2, zm: 10, jj: 10)
        dayAllowance = c.dbl(.dayAllowance)
        nightAllowance = c.dbl(.nightAllowance)
        reminderEnabled = c.boolv(.reminderEnabled, false)
        let rh: Int? = (try? c.decodeIfPresent(Int.self, forKey: .reminderHour))
        reminderHour = min(23, max(0, rh ?? 21))
        reminderMinute = min(59, max(0, c.intg(.reminderMinute)))
        let cd = (try? c.decodeIfPresent([String: ClassDefault].self, forKey: .classDefaults))
        if let cd = cd, !cd.isEmpty { classDefaults = cd }
        projectId = c.strg(.projectId, "default")
        currentClass = c.strg(.currentClass, "1")
        autoCarryMonth = c.strg(.autoCarryMonth)
    }
}

// MARK: - 整库

struct AppData: Codable {
    var v: Int = 2
    var settings: Settings = Settings()
    var projects: [Project] = []
    var classes: [ShiftClass] = []
    var records: [String: DayRecord] = [:]
    var plans: [String: String] = [:]
    var bonuses: [String: [BonusItem]] = [:]
    var deductions: [String: [BonusItem]] = [:]

    enum CodingKeys: String, CodingKey { case v, settings, projects, classes, records, plans, bonuses, deductions }

    init() {
        projects = [
            Project(id: "default", name: "默认项目", mode: "dxjs", base: 2230,
                    rates: WorkHours(zb: 12.82, jb: 19.23, zm: 25.64, jj: 38.46)),
            Project(id: "2", name: "祥发模具", mode: "gddx", base: 3300,
                    rates: WorkHours(zb: 18.97, jb: 18.96, zm: 25.28, jj: 37.92))
        ]
        classes = [
            ShiftClass(id: "1", name: "白班", color: "#FCB819"),
            ShiftClass(id: "2", name: "早班", color: "#33A0FF"),
            ShiftClass(id: "3", name: "中班", color: "#FF9900"),
            ShiftClass(id: "4", name: "晚班", color: "#224799")
        ]
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = c.intg(.v)
        settings = (try? c.decodeIfPresent(Settings.self, forKey: .settings)) ?? Settings()
        projects = (try? c.decodeIfPresent([Project].self, forKey: .projects)) ?? []
        classes = (try? c.decodeIfPresent([ShiftClass].self, forKey: .classes)) ?? []
        records = (try? c.decodeIfPresent([String: DayRecord].self, forKey: .records)) ?? [:]
        plans = (try? c.decodeIfPresent([String: String].self, forKey: .plans)) ?? [:]
        bonuses = (try? c.decodeIfPresent([String: [BonusItem]].self, forKey: .bonuses)) ?? [:]
        deductions = (try? c.decodeIfPresent([String: [BonusItem]].self, forKey: .deductions)) ?? [:]

        if projects.isEmpty {
            projects = AppData().projects
        }
        if classes.isEmpty {
            classes = AppData().classes
        }
    }
}

// MARK: - 统计结果

struct MonthStats {
    var days: Double = 0
    var hours: Double = 0
    var pay: Double = 0
    var zb: Double = 0
    var jb: Double = 0
    var zm: Double = 0
    var jj: Double = 0
    var bonus: Double = 0
    var deduct: Double = 0
    var start: String = ""
    var end: String = ""
    var label: String = ""

    var avg: Double { hours > 0 ? pay / hours : 0 }
    var overtime: Double { jb + zm + jj }
}

struct YearStats {
    var months: [MonthStats] = Array(repeating: MonthStats(), count: 12)
    var pay: Double = 0
    var hours: Double = 0
    var days: Double = 0
    var ot: Double = 0
    var bonus: Double = 0
    var deduct: Double = 0
    var workPay: Double { pay - bonus + deduct }
    var avg: Double { hours > 0 ? pay / hours : 0 }
}
