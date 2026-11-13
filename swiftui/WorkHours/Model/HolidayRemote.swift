import Foundation

/// 从 holiday-cn 拉某一年的放假安排。
/// 数据来源：https://github.com/NateScarlet/holiday-cn（每天自动抓国务院公告）
/// 三个源依次重试，jsDelivr 在国内一般更快。
enum HolidayRemote {
    enum RemoteError: LocalizedError {
        case noNetwork
        case badJSON
        case empty

        var errorDescription: String? {
            switch self {
            case .noNetwork: return "网络不通"
            case .badJSON: return "数据格式不对"
            case .empty: return "这一年还没公布"
            }
        }
    }

    static let sources = [
        "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%d.json",
        "https://fastly.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%d.json",
        "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%d.json"
    ]

    private struct Payload: Decodable {
        struct Day: Decodable {
            let name: String?
            let date: String
            let isOffDay: Bool?
        }
        let year: Int?
        let days: [Day]
    }

    /// 拉取一年，返回可直接并进 HolidayData 的结构。
    static func fetch(year: Int) async throws -> HolidayYear {
        var last: Error?
        for template in sources {
            guard let url = URL(string: String(format: template, year)) else { continue }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 12
                req.setValue("WorkHours/1.0", forHTTPHeaderField: "User-Agent")
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                    last = RemoteError.badJSON
                    continue
                }
                let payload = try JSONDecoder().decode(Payload.self, from: data)
                var result = HolidayYear()
                for d in payload.days where d.date.count == 10 {
                    if d.isOffDay ?? true {
                        result.holidays[d.date] = d.name ?? "节日"
                    } else {
                        result.workdays.append(d.date)
                    }
                }
                if result.holidays.isEmpty && result.workdays.isEmpty {
                    last = RemoteError.empty
                    continue
                }
                return result
            } catch {
                last = error is DecodingError ? RemoteError.badJSON : error
            }
        }
        throw last ?? RemoteError.noNetwork
    }
}
