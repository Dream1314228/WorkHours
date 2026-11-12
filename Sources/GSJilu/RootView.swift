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
                RecordView()
                    .opacity(selected == 0 ? 1 : 0)
                    .offset(y: motion ? (selected == 0 ? 0 : 6) : 0)
                    .allowsHitTesting(selected == 0)
                StatsView()
                    .opacity(selected == 1 ? 1 : 0)
                    .offset(y: motion ? (selected == 1 ? 0 : 6) : 0)
                    .allowsHitTesting(selected == 1)
                ScheduleView()
                    .opacity(selected == 2 ? 1 : 0)
                    .offset(y: motion ? (selected == 2 ? 0 : 6) : 0)
                    .allowsHitTesting(selected == 2)
                MeView()
                    .opacity(selected == 3 ? 1 : 0)
                    .offset(y: motion ? (selected == 3 ? 0 : 6) : 0)
                    .allowsHitTesting(selected == 3)
            }
            .id(store.themeKey)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 76)
            .animation(motion ? .easeOut(duration: 0.26) : nil, value: selected)

            GSGlassTabBar(selected: $selected)
        }
        .ignoresSafeArea(.keyboard)
        .overlay(GSToastBanner())
    }
}
