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
            StatsPage(palette: palette)
                .tabItem { Label("统计", systemImage: "chart.bar.xaxis") }
                .tag(1)
            SummaryPage(palette: palette)
                .tabItem { Label("总结", systemImage: "chart.pie.fill") }
                .tag(2)
            ShiftPage(palette: palette)
                .tabItem { Label("排班", systemImage: "square.grid.3x3.fill") }
                .tag(3)
            SettingsPage(palette: palette)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
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
        }
    }
}
