import Foundation
import UserNotifications

/// 每日提醒。
///
/// 方案 C：一条 `repeats: true` 的通知，每天固定时刻响，长期挂在系统里。
/// 不预排、不随记录状态变化——哪天记没记都弹，它不判断。
/// 好处是永远不会断：哪怕一个月不开 App，第二天照样提醒。
///
/// 「记的不是今天」那条即时通知已按用户要求去掉。
final class Reminder {
    static let shared = Reminder()
    private let center = UNUserNotificationCenter.current()
    private let dailyID = "gs.daily"

    /// 重排每日提醒。开关关掉就只清理不排。
    func refresh(store: Store) {
        center.removeAllPendingNotificationRequests()

        let settings = store.settings
        guard settings.reminderEnabled else { return }

        var comps = DateComponents()
        comps.hour = settings.reminderHour
        comps.minute = settings.reminderMinute

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "记一笔"
            content.body = "今天的工时还没记，花十秒补上吧。"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            self.center.add(UNNotificationRequest(identifier: self.dailyID,
                                                  content: content,
                                                  trigger: trigger))
        }
    }

    /// 关掉提醒时清空已排的
    func clear() {
        center.removeAllPendingNotificationRequests()
    }
}

/// 前台也要弹通知的代理。没有它，App 开着的时候那条提醒会被系统吞掉。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
