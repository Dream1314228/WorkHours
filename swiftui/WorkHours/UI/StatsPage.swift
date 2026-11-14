import SwiftUI
import UIKit

/// 统计页：只按考勤周期看，全年/整月放到「总结」页。
struct StatsPage: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    // 默认看「今天所属的那一期」，而不是今天所在的自然月：
    // 期跨月时（比如 10/27-11/26），11 月开头要看的还是 10 月那期。
    @State private var pickedYear: Int?
    @State private var pickedMonth: Int?
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    private var year: Int { pickedYear ?? store.currentPeriodKey().year }
    private var month: Int { pickedMonth ?? store.currentPeriodKey().month }

    /// 翻回当前期：把「手动选的月份」清掉，视图就自动落回今天所属那一期
    private var isCurrentPeriod: Bool {
        let k = store.currentPeriodKey()
        return year == k.year && month == k.month
    }

    private func backToCurrent() {
        withAnimation(store.pageMotion ? .snappy(duration: 0.24) : nil) {
            pickedYear = nil
            pickedMonth = nil
        }
    }

    private var st: MonthStats { store.monthStats(year: year, month: month) }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    MonthSummaryContent(year: year, month: month, palette: palette)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showShare) {
            ActivityView(items: shareItems)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(year) 年 \(month) 月")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Ledger.ink)
                    .contentTransition(.numericText())
                HStack(spacing: 6) {
                    Text("考勤期 \(st.start) 至 \(st.end)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if !isCurrentPeriod {
                        Button {
                            backToCurrent()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 8, weight: .bold))
                                Text("本期")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(palette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(palette.primary.opacity(0.12)))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            Spacer(minLength: 4)
            circleButton("chevron.left") { step(-1) }
            circleButton("chevron.right") { step(1) }
            circleButton("doc.badge.arrow.up") { exportHTML() }
        }
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ledger.ink)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
        }
        .buttonStyle(PressableStyle())
    }

    private func step(_ delta: Int) {
        let next = Cal.monthAdd(year, month, delta)
        withAnimation(store.pageMotion ? .snappy(duration: 0.24) : nil) {
            pickedYear = next.year
            pickedMonth = next.month
        }
    }

    private func exportHTML() {
        let html = store.htmlReport(year: year, month: month)
        let name = String(format: "工时记录-%04d-%02d.html", year, month)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try html.data(using: .utf8)?.write(to: url, options: .atomic)
            shareItems = [url]
            showShare = true
        } catch {
            ToastCenter.shared.show("导出失败：\(error.localizedDescription)")
        }
    }
}

/// 系统分享面板，用来把 HTML 存到文件 App 或发给别人。
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
