import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: GSStore
    @State private var selected = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            GSPageBackground().ignoresSafeArea()
            Group {
                switch selected {
                case 1: StatsView()
                case 2: ScheduleView()
                case 3: MeView()
                default: RecordView()
                }
            }
            .id("\(selected)-\(store.themeKey)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 76)

            GSGlassTabBar(selected: $selected)
        }
        .ignoresSafeArea(.keyboard)
        .overlay(GSToastBanner())
    }
}
