import SwiftUI

@main
struct WorkHoursApp: App {
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0

    var palette: Palette { Theme.of(store.data.settings.theme) }

    var body: some View {
        TabView(selection: $tab) {
            CalendarPage(palette: palette)
                .tabItem { Label("记录", systemImage: "calendar") }
                .tag(0)
                .modifier(PageReveal(active: tab == 0))
            StatsPage(palette: palette)
                .tabItem { Label("统计", systemImage: "chart.bar.xaxis") }
                .tag(1)
                .modifier(PageReveal(active: tab == 1))
            SummaryPage(palette: palette)
                .tabItem { Label("总结", systemImage: "chart.pie.fill") }
                .tag(2)
                .modifier(PageReveal(active: tab == 2))
            ShiftPage(palette: palette)
                .tabItem { Label("排班", systemImage: "square.grid.3x3.fill") }
                .tag(3)
                .modifier(PageReveal(active: tab == 3))
            SettingsPage(palette: palette)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
                .modifier(PageReveal(active: tab == 4))
        }
        .tint(palette.primary)
        .onChange(of: tab) { _, _ in
            // 换标签页时让图表重新播一遍
            store.refreshCharts()
        }
        .overlay(ToastOverlay())
        .onAppear {
            let s = store.settings
            Reminder.shared.sync(enabled: s.reminderEnabled, hour: s.reminderHour, minute: s.reminderMinute)
            // 启动时数据文件读不出来，开屏说一次，别让用户以为记录凭空没了
            if let issue = store.loadIssue {
                ToastCenter.shared.show(issue)
            }
        }
    }
}

/// 标签页切换：新页淡入 + 8pt 上浮，替掉系统那种硬切。
/// 系统 TabView 本身不给过渡动画，只能在页面出场这一帧自己补。
struct PageReveal: ViewModifier {
    let active: Bool
    @EnvironmentObject private var store: Store
    @State private var shown = false

    private var anim: Animation? {
        store.pageMotion ? .easeOut(duration: 0.22) : nil
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0.001)
            .offset(y: shown ? 0 : 8)
            .scaleEffect(shown ? 1 : 0.994)
            .onChange(of: active) { _, now in
                guard now else {
                    shown = false
                    return
                }
                shown = false
                withAnimation(anim) { shown = true }
            }
            .onAppear {
                withAnimation(anim) { shown = true }
            }
    }
}
