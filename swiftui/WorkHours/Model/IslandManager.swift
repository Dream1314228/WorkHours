import Foundation
import ActivityKit

/// 灵动岛的唯一入口：App 侧只跟它打交道，它负责起、更、停。
/// 配置改了、记了一笔、切了月份，都只是再调一次 sync。
@MainActor
final class IslandManager {
    static let shared = IslandManager()

    private var activity: Activity<WorkIslandAttributes>?

    private init() {}

    /// 按当前数据和配置对齐灵动岛：该有就起/更新，不该有就关
    func sync(store: Store) {
        let cfg = store.data.settings.island
        guard cfg.enabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            endAll()
            return
        }
        let today = Cal.todayKey()
        guard cfg.showEmpty || store.record(today) != nil else {
            endAll()
            return
        }
        let state = makeState(store: store, cfg: cfg, key: today)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(1800))

        if let a = activity ?? Activity<WorkIslandAttributes>.activities.first {
            activity = a
            Task { await a.update(content) }
        } else {
            do {
                activity = try Activity.request(
                    attributes: WorkIslandAttributes(dateKey: today),
                    content: content,
                    pushType: nil
                )
            } catch {
                // 用户在设置里关了「实时活动」，或系统限流，静默失败
                activity = nil
            }
        }
    }

    /// 关掉所有这个 App 的活动（换日期、关开关时用）
    func endAll() {
        activity = nil
        Task {
            for a in Activity<WorkIslandAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: 组数据

    private func makeState(store: Store, cfg: IslandConfig, key: String) -> WorkIslandAttributes.ContentState {
        var s = WorkIslandAttributes.ContentState()
        let rec = store.record(key)
        let settings = store.data.settings
        let need = needHours(store: store, rec: rec)
        let day = Calendar.current.component(.day, from: Cal.date(key))

        s.todayHours = rec?.work.total ?? 0
        s.todayPay = rec.map { store.dayPay($0) } ?? 0
        s.need = need
        s.streak = streak(store: store, key: key)
        s.paydayLeft = paydayLeft(settings: settings, key: key, day: day)
        s.shift = rec.flatMap { store.shiftClass($0.classId) }?.name ?? ""
        s.project = store.project(rec?.projectId ?? settings.projectId).name
        s.leaveLeft = store.annualLeaveRemaining(year: Cal.year(key))

        let period = store.currentPeriodKey()
        s.periodPay = store.monthStats(year: period.year, month: period.month).pay
        let natural = store.monthStats(year: Cal.year(key), month: Cal.month(key), usePeriod: false)
        s.monthHours = natural.hours
        s.monthPay = natural.pay

        s.style = cfg.style
        s.compactLeading = cfg.compactLeading
        s.compactTrailing = cfg.compactTrailing
        s.expanded = cfg.expanded
        s.updatedAt = Date()
        return s
    }

    /// 应上工时 = 班次配置的四栏总和；1.8.7 里「整天假/半天假」也是按这个判的，保持一致
    private func needHours(store: Store, rec: DayRecord?) -> Double {
        guard let rec = rec else {
            let w = store.defaultWork(forClass: store.data.settings.currentClass)
            return w.total > 0 ? w.total : 8
        }
        let w = store.defaultWork(forClass: rec.classId)
        return w.total > 0 ? w.total : 8
    }

    /// 连续记账天数：今天有就从今天数，没有就从昨天数
    private func streak(store: Store, key: String) -> Int {
        var k = store.record(key) != nil ? key : dayBefore(key)
        var n = 0
        while store.record(k) != nil && n < 3660 {
            n += 1
            k = dayBefore(k)
        }
        return n
    }

    private func dayBefore(_ key: String) -> String {
        guard let d = Calendar.current.date(byAdding: .day, value: -1, to: Cal.date(key)) else { return key }
        return Cal.key(d)
    }

    /// 距发薪日还有几天；发了就是 0，没配就是 -1
    private func paydayLeft(settings: Settings, key: String, day: Int) -> Int {
        let p = settings.payday
        guard p > 0 else { return -1 }
        let y = Cal.year(key), m = Cal.month(key)
        let dim = Cal.daysInMonth(y, m)
        let target = min(p, dim)
        if day == target { return 0 }
        if day < target { return target - day }
        let next = Cal.monthAdd(y, m, 1)
        let nd = min(p, Cal.daysInMonth(next.year, next.month))
        let nextKey = String(format: "%04d-%02d-%02d", next.year, next.month, nd)
        let days = Calendar.current.dateComponents([.day], from: Cal.date(key), to: Cal.date(nextKey)).day ?? 0
        return max(0, days)
    }
}
