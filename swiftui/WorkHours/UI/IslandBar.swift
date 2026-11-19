import SwiftUI

/// App 内自绘的「灵动岛」：贴在状态栏下面，只在 App 里出现，退到后台自然消失。
/// 不走 ActivityKit —— 那种岛会活到锁屏上，正是这次不要的。
struct IslandBar: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    @State private var expanded = false
    @State private var autoTask: Task<Void, Never>?

    private var today: String { Cal.todayKey() }
    private var rec: DayRecord? { store.record(today) }
    private var done: Bool { store.hasRecord(today) }
    private var hours: Double { rec?.work.total ?? 0 }
    private var pay: Double { rec.map { store.dayPay($0) } ?? 0 }
    private var streak: Int { store.recordStreak(endingAt: today) }
    private var payday: Bool { store.isPayday(today) }
    private var monthPay: Double {
        store.monthStats(year: Cal.year(today), month: Cal.month(today)).pay
    }

    private var boxWidth: CGFloat { expanded ? 338 : (done ? 162 : 136) }
    private var boxHeight: CGFloat { expanded ? 136 : 38 }
    private var cornerRadius: CGFloat { expanded ? 30 : 19 }

    var body: some View {
        content
            .frame(width: boxWidth, height: boxHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(payday ? Color(hex: "#F2C14E").opacity(0.7) : Color.white.opacity(0.10),
                                  lineWidth: payday ? 1.2 : 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.26), radius: 16, y: 7)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onTapGesture {
                autoTask?.cancel()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                    expanded.toggle()
                }
            }
            .onChange(of: rec) { _, new in
                // 刚记完这一笔：展开两秒，报一下今天多少小时多少钱
                guard new != nil, !expanded else { return }
                flash()
            }
            .onAppear {
                // 发薪日当天，一进来就把彩蛋亮出来
                guard payday, !expanded else { return }
                autoTask?.cancel()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { expanded = true }
                autoTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3.6))
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { expanded = false }
                }
            }
            .onDisappear { autoTask?.cancel() }
    }

    private var fill: LinearGradient {
        if payday {
            return LinearGradient(colors: [Color(hex: "#3B2E08"), Color(hex: "#161104")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Color(hex: "#1E1E20"), Color(hex: "#000000")],
                              startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder
    private var content: some View {
        if expanded { expandedContent } else { compact }
    }

    private var compact: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(done ? Color.gsGreen : (payday ? Color(hex: "#F2C14E") : Color.white.opacity(0.34)))
                .frame(width: 7, height: 7)
            Text(done ? "\(Cal.num(hours))H" : "记一笔")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
            if done {
                Text("¥" + Cal.num(pay))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.66))
            }
            if streak >= 3 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                    Text("\(streak)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(Color(hex: "#FF9F0A"))
            }
        }
        .padding(.horizontal, 13)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text(payday ? "发薪日" : Cal.shortDate(today))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(payday ? Color(hex: "#F2C14E") : Color.white.opacity(0.58))
                Text(Cal.weekdayName(today))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.34))
                Spacer(minLength: 6)
                if streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill").font(.system(size: 9))
                        Text("连续 \(streak) 天")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color(hex: "#FF9F0A").opacity(0.9))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Cal.signedMoney(payday ? monthPay : pay))
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(payday ? Color(hex: "#F2C14E") : Color.white)
                    .contentTransition(.numericText())
                Text(payday ? "本月" : "今天")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.42))
                Spacer(minLength: 6)
                Text("\(Cal.num(hours))H")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.78))
            }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 0.6)

            HStack(spacing: 0) {
                stat("正班", rec?.work.zb ?? 0)
                stat("加班", rec?.work.jb ?? 0)
                stat("补助", rec.map { store.bonusTotal($0) } ?? 0)
                stat("扣款", rec.map { store.leaveDeduct($0) } ?? 0)
            }

            Text(done ? "点一下收起" : "点一下记今天")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.32))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func stat(_ name: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.42))
            Text(Cal.num(value))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 记完一笔自动展开两秒
    private func flash() {
        autoTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { expanded = true }
        autoTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { expanded = false }
        }
    }
}
