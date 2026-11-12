import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: GSStore
    @State private var selected = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        let motion = GSMotionEnabled(store, reduceMotion: reduceMotion)
        ZStack(alignment: .bottom) {
            GSPageBackground().ignoresSafeArea()
            ZStack {
                tabPage(0, motion: motion) { RecordView() }
                tabPage(1, motion: motion) { StatsView() }
                tabPage(2, motion: motion) { ScheduleView() }
                tabPage(3, motion: motion) { MeView() }
            }
            .id(store.themeKey)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 76)

            GSGlassTabBar(selected: $selected)
        }
        .ignoresSafeArea(.keyboard)
        .overlay(GSToastBanner())
    }

    @ViewBuilder
    private func tabPage<Content: View>(_ index: Int, motion: Bool, @ViewBuilder content: () -> Content) -> some View {
        let on = selected == index
        content()
            .opacity(on ? 1 : 0)
            .offset(y: (motion && !on) ? 6 : 0)
            .allowsHitTesting(on)
            .zIndex(on ? 1 : 0)
            .animation(motion && !on ? .easeOut(duration: 0.26) : nil, value: selected)
    }
}
