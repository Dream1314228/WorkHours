import Foundation

/// 一年的放假安排：holidays 是日期 -> 节日名，workdays 是调休上班的周末。
struct HolidayYear: Codable {
    var holidays: [String: String] = [:]
    var workdays: [String] = []

    enum CodingKeys: String, CodingKey { case holidays, workdays }

    init(holidays: [String: String] = [:], workdays: [String] = []) {
        self.holidays = holidays
        self.workdays = workdays
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        holidays = (try? c.decodeIfPresent([String: String].self, forKey: .holidays)) ?? [:]
        workdays = (try? c.decodeIfPresent([String].self, forKey: .workdays)) ?? []
    }
}

/// 节假日表：内置 2025、2026，跨年后从设置里导入新的 JSON 覆盖，不用改代码。
final class HolidayData {
    static let shared = HolidayData()

    private(set) var years: [String: HolidayYear] = [:]
    private(set) var customYears: Set<String> = []

    static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("holidays.json")
    }()

    private init() {
        var merged = HolidayData.builtin
        if let raw = try? Data(contentsOf: HolidayData.fileURL),
           let custom = try? JSONDecoder().decode([String: HolidayYear].self, from: raw) {
            for (year, value) in custom {
                merged[year] = value
                customYears.insert(year)
            }
        }
        years = merged
    }

    var coveredYears: [Int] {
        years.keys.compactMap { Int($0) }.sorted()
    }

    func holidayName(_ key: String) -> String? {
        years[String(key.prefix(4))]?.holidays[key]
    }

    func isWorkday(_ key: String) -> Bool {
        years[String(key.prefix(4))]?.workdays.contains(key) ?? false
    }

    /// 导入 {"2027":{"holidays":{...},"workdays":[...]}}，返回覆盖到的年份
    @discardableResult
    func importJSON(_ data: Data) throws -> [Int] {
        let incoming = try JSONDecoder().decode([String: HolidayYear].self, from: data)
        guard !incoming.isEmpty else { throw ImportError.empty }

        var custom: [String: HolidayYear] = [:]
        if let raw = try? Data(contentsOf: HolidayData.fileURL),
           let old = try? JSONDecoder().decode([String: HolidayYear].self, from: raw) {
            custom = old
        }
        for (year, value) in incoming {
            custom[year] = value
            years[year] = value
            customYears.insert(year)
        }

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(custom).write(to: HolidayData.fileURL, options: .atomic)

        return incoming.keys.compactMap { Int($0) }.sorted()
    }

    func resetCustom() {
        try? FileManager.default.removeItem(at: HolidayData.fileURL)
        customYears = []
        years = HolidayData.builtin
    }

    enum ImportError: LocalizedError {
        case empty
        var errorDescription: String? { "文件里没有可用的年份数据" }
    }

    // MARK: 内置表

    static let builtin: [String: HolidayYear] = [
        "2025": HolidayYear(
            holidays: [
                "2025-01-01": "元旦",
                "2025-01-28": "春节", "2025-01-29": "春节", "2025-01-30": "春节",
                "2025-01-31": "春节", "2025-02-01": "春节", "2025-02-02": "春节",
                "2025-02-03": "春节", "2025-02-04": "春节",
                "2025-04-04": "清明", "2025-04-05": "清明", "2025-04-06": "清明",
                "2025-05-01": "劳动节", "2025-05-02": "劳动节", "2025-05-03": "劳动节",
                "2025-05-04": "劳动节", "2025-05-05": "劳动节",
                "2025-05-31": "端午", "2025-06-01": "端午", "2025-06-02": "端午",
                "2025-10-01": "国庆", "2025-10-02": "国庆", "2025-10-03": "国庆",
                "2025-10-04": "国庆", "2025-10-05": "国庆", "2025-10-06": "国庆",
                "2025-10-07": "国庆", "2025-10-08": "国庆"
            ],
            workdays: ["2025-01-26", "2025-02-08", "2025-04-27", "2025-09-28", "2025-10-11"]
        ),
        "2026": HolidayYear(
            holidays: [
                "2026-01-01": "元旦", "2026-01-02": "元旦", "2026-01-03": "元旦",
                "2026-02-16": "春节", "2026-02-17": "春节", "2026-02-18": "春节",
                "2026-02-19": "春节", "2026-02-20": "春节", "2026-02-21": "春节",
                "2026-02-22": "春节",
                "2026-04-04": "清明", "2026-04-05": "清明", "2026-04-06": "清明",
                "2026-05-01": "劳动节", "2026-05-02": "劳动节", "2026-05-03": "劳动节",
                "2026-05-04": "劳动节", "2026-05-05": "劳动节",
                "2026-06-19": "端午", "2026-06-20": "端午", "2026-06-21": "端午",
                "2026-09-25": "中秋", "2026-09-26": "中秋", "2026-09-27": "中秋",
                "2026-10-01": "国庆", "2026-10-02": "国庆", "2026-10-03": "国庆",
                "2026-10-04": "国庆", "2026-10-05": "国庆", "2026-10-06": "国庆",
                "2026-10-07": "国庆"
            ],
            workdays: ["2026-02-14", "2026-02-28", "2026-04-26",
                       "2026-05-09", "2026-09-20", "2026-10-10"]
        )
    ]
}
