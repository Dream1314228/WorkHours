import Foundation
import UserNotifications

/// 每日提醒。
///
/// 规则：每天到点提醒一次；那天已经有工时记录就不提醒。
/// 只改了别的日子，不影响当天——到点照样提醒。
///
/// 做法：每次数据变动就把未来 14 天的通知整体重排一遍，
/// 已记录的日子跳过。这样 App 不打开也能按时弹，不用后台常驻。
final class Reminder {
    static let shared = Reminder()
    private let center = UNUserNotificationCenter.current()
    private let prefix = "gs.day."
    private let horizon = 14

    /// 文案池：每天随机一条，相邻两天不会重复
    private let pool: [String] = [
        "今天还没记工时，花十秒补上吧。",
        "今天的班上了，账还空着。",
        "别等月底翻记录，今天先记一笔。",
        "工时空一天，工资就少一天。",
        "今天干了多久？顺手记一下。",
        "日历上今天还是白的。",
        "月底对账全靠这个，别落下。",
        "记一笔今天的，三十秒的事。",
        "今天的数字，趁还记得。",
        "不记的话，明天就忘了干了几小时。",
        "今日工时待填。",
        "上完班顺手记，比回忆靠谱。",
        "今天的工时还差一笔。",
        "一天的账，两行数字。"
    ]

    /// 重排未来两周的通知。开关关掉就只清理不排。
    func rebuild(store: Store) {
        center.removeAllPendingNotificationRequests()

        let settings = store.settings
        guard settings.reminderEnabled else { return }

        let cal = Cal.gregorian
        let now = Date()
        var lastText = ""
        var plans: [(key: String, fire: Date, text: String)] = []

        for offset in 0..<horizon {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let key = Cal.key(day)
            // 这天已经记了工时，就不提醒
            if hasWork(store, key) { continue }

            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = settings.reminderHour
            comps.minute = settings.reminderMinute
            comps.second = 0
            guard let fire = cal.date(from: comps), fire > now else { continue }

            let text = pick(excluding: lastText)
            lastText = text
            plans.append((key, fire, text))
        }

        guard !plans.isEmpty else { return }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            for plan in plans {
                let content = UNMutableNotificationContent()
                content.title = "记一笔"
                content.body = plan.text
                content.sound = .default
                var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fire)
                comps.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                self.center.add(UNNotificationRequest(identifier: self.prefix + plan.key,
                                                      content: content,
                                                      trigger: trigger))
            }
        }
    }

    /// 关掉提醒时清空已排的
    func clear() {
        center.removeAllPendingNotificationRequests()
    }

    /// 那天算不算「已经记过」：有工时、有请假、有补贴扣款、有备注，任一条都算
    private func hasWork(_ store: Store, _ key: String) -> Bool {
        guard let r = store.record(key) else { return false }
        if r.work.total > 0 { return true }
        if r.leave != nil { return true }
        if !r.bt.isEmpty { return true }
        if !r.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return false
    }

    private func pick(excluding last: String) -> String {
        let candidates = pool.filter { $0 != last }
        return candidates.randomElement() ?? pool[0]
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
