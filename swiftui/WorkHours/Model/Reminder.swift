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
