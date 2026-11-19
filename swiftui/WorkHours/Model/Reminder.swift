import Foundation
import UserNotifications

/// 每天固定时间提醒记账。
final class Reminder {
    static let shared = Reminder()
    private let center = UNUserNotificationCenter.current()
    private let identifier = "gs.daily.reminder"

    func sync(enabled: Bool, hour: Int, minute: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "工时记录"
            content.body = "今天还没记账，花十秒补上吧。"
            content.sound = .default
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: self.identifier, content: content, trigger: trigger)
            self.center.add(request)
        }
    }
}

/// 前台也要弹通知的代理。没有它，App 里记错日期时那条通知会被系统吞掉。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

extension Reminder {
    /// 记的日期和今天不一致时提醒一句：多半是点错了格子，不是真想补记。
    func notifyDateMismatch(recorded: String, today: String) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "记的不是今天"
            content.body = "这次记的是 \(Cal.shortDate(recorded))，今天是 \(Cal.shortDate(today))。点错格子的话回去改一下。"
            content.sound = .default
            let request = UNNotificationRequest(identifier: "gs.date.mismatch.\(recorded)",
                                                content: content,
                                                trigger: nil)
            self.center.add(request)
        }
    }
}
