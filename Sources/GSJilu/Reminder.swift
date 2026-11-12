import Foundation
import UserNotifications
import Compression

enum GSReminder {
    static func syncFromSettings() {
        let s = GSStore.shared.settings
        let center = UNUserNotificationCenter.current()
        if !GSJSONBool(s["reminderEnabled"]) {
            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers())
            return
        }
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .denied {
                center.removePendingNotificationRequests(withIdentifiers: allIdentifiers())
                return
            }
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { schedule(with: s) }
                }
            } else {
                schedule(with: s)
            }
        }
    }

    static func requestAndSync() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { syncFromSettings() }
        }
    }

    private static func allIdentifiers() -> [String] {
        var ids = ["GSRecordDailyReminder"]
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        for i in 0..<14 {
            if let day = cal.date(byAdding: .day, value: i, to: now) {
                ids.append("GSRecordDailyReminder-\(GSDate.key(from: day))")
            }
        }
        return ids
    }

    private static func schedule(with s: [String: Any]) {
        let center = UNUserNotificationCenter.current()
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let hour = max(0, min(23, GSJSONInt(s["reminderHour"])))
        let minute = max(0, min(59, GSJSONInt(s["reminderMinute"])))
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers())
        for i in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: i, to: now) else { continue }
            let key = GSDate.key(from: day)
            if GSStore.shared.record(for: key) != nil { continue }
            var c = cal.dateComponents([.year, .month, .day], from: day)
            c.hour = hour
            c.minute = minute
            guard let fireDate = cal.date(from: c), fireDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "工时记录"
            content.body = "\(c.month ?? 0)月\(c.day ?? 0)日还没有记录工时，花十秒补一笔。"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
            let identifier = "GSRecordDailyReminder-\(key)"
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger), withCompletionHandler: nil)
        }
    }
}

enum GSBackup {
    static func exportData() throws -> URL {
        let backup = GSStore.shared.backupDictionary()
        let plain = try JSONSerialization.data(withJSONObject: backup, options: [.sortedKeys])
        guard let compressed = plain.compressed(using: .lzfse) else {
            throw NSError(domain: "GSJilu", code: 1, userInfo: [NSLocalizedDescriptionKey: "备份生成失败"])
        }
        let name = String(format: "工时记录备份-%@.gsjilu", GSDate.key(from: Date()))
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        try compressed.write(to: url, options: .atomic)
        return url
    }

    static func parse(_ data: Data) -> [String: Any]? {
        // Original backups are LZFSE-compressed JSON. Also accept raw JSON.
        let plain: Data
        if let d = try? data.decompressed(using: .lzfse) {
            plain = d
        } else {
            plain = data
        }
        return (try? JSONSerialization.jsonObject(with: plain, options: [.mutableContainers])) as? [String: Any]
    }
}

extension Data {
    func compressed(using algorithm: NSData.CompressionAlgorithm) -> Data? {
        try? (self as NSData).compressed(using: algorithm) as Data
    }
    func decompressed(using algorithm: NSData.CompressionAlgorithm) -> Data? {
        try? (self as NSData).decompressed(using: algorithm) as Data
    }
}
