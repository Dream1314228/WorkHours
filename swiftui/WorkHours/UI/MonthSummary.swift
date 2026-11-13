import SwiftUI

/// 一个考勤周期的完整内容：概览、工时构成、每日柱状图、补贴/扣款明细、逐日明细。
/// 统计页和总结页共用这一块，避免两套口径。
struct MonthSummaryContent: View {
    let year: Int
    let month: Int
    var palette: Palette
    var showChart: Bool = true

    @EnvironmentObject private var store: Store
    @State private var appeared = false

    private var st: MonthStats { store.monthStats(year: year, month: month) }
    private var rows: [(String, DayRecord)] { store.periodRecords(year: year, month: month) }
    private var bonuses: [BonusItem] { store.extras("bonus", year: year, month: month) }
    private var deductions: [BonusItem] { store.extras("deduct", year: year, month: month) }

    var body: some View {
        VStack(spacing: 14) {
            headerTiles

            compositionCard

            radarCard

            if showChart {
                dayChartCard
            }

            allowanceCard(kind: "bonus", title: "补贴明细", icon: "arrow.up.circle.fill",
                          color: Color.gsGreen, items: bonuses, daily: dailyExtras(positive: true))
            allowanceCard(kind: "deduct", title: "扣款明细", icon: "arrow.down.circle.fill",
                          color: Color.gsRed, items: deductions, daily: dailyExtras(positive: false))

            dayDetailCard
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            guard store.pageMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private var radarAxes: [(String, Double)] {
        let ot = st.jb + st.zm + st.jj
        return [
            ("出勤", min(1, Double(st.days) / 22)),
            ("工时", min(1, st.hours / 200)),
            ("加班", min(1, ot / 60)),
            ("补贴", min(1, st.bonus / 600)),
            ("少扣", 1 - min(1, st.deduct / 600)),
            ("时薪", min(1, st.avg / 60))
        ]
    }

    private var radarCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            IconTitle(icon: "hexagon.fill", title: "这个周期的手感",
                      subtitle: "六项满分 100，看相对强弱")
            RadarChart(axes: radarAxes, palette: palette)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 概览

    private var headerTiles: some View {
        HStack(spacing: 8) {
            StatTile(value: "\(Cal.num(st.hours))H", label: "总工时",
                     color: Color.primary, palette: palette)
            StatTile(value: "\(Cal.num(st.days))天", label: "出勤", palette: palette)
            StatTile(value: Cal.money(st.pay), label: "实发工资",
                     color: Color.gsOrange, palette: palette)
        }
    }

    private var compositionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconTitle(icon: "chart.pie.fill", title: "工时构成",
                      subtitle: "共 \(Cal.num(st.hours)) 小时")
            HStack(alignment: .center, spacing: 14) {
                HoursDonut(zb: st.zb, ot: st.jb, zm: st.zm, jj: st.jj, palette: palette)
                VStack(alignment: .leading, spacing: 8) {
                    legendRow(palette.primary, "正班", st.zb)
                    legendRow(Color.gsOrange, "加班", st.jb)
                    legendRow(Color.gsGreen, "周末", st.zm)
                    legendRow(Color.gsRed, "节假", st.jj)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            Divider().opacity(0.4)
            iconRow("yensign.circle.fill", "补贴", "+" + Cal.money(st.bonus), Color.gsGreen)
            iconRow("minus.circle.fill", "扣款", "-" + Cal.money(st.deduct), Color.gsRed)
            iconRow("clock.arrow.circlepath", "日均工时",
                    "\(Cal.num(st.days > 0 ? st.hours / st.days : 0)) H", .primary)
            iconRow("gauge.with.dots.needle.33percent", "平均时薪", Cal.money(st.avg), .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func hourTile(_ title: String, _ value: Double, _ color: Color, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.opacity(0.85))
            Text(Cal.num(value))
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.gsSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.10))
        }
    }

    private func iconRow(_ icon: String, _ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 14)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.gsSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color == .primary ? Color.primary : color)
        }
    }

    // MARK: 每日柱状图

    private var dayChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconTitle(icon: "chart.bar.fill", title: "每日工时", subtitle: "单位：小时")
            DayBarChart(rows: rows, palette: palette)
            HStack(spacing: 14) {
                legend("正班", palette.primary)
                legend("加班 / 周末 / 节假", Color.gsOrange)
                Spacer()
                Text("最高 \(Cal.num(rows.map { $0.1.work.total }.max() ?? 0)) H")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(Ledger.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func legendRow(_ color: Color, _ name: String, _ v: Double) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(Color.gsSecondary)
                .frame(width: 26, alignment: .leading)
            Text(Cal.num(v))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
            Text("H")
                .font(.system(size: 9))
                .foregroundStyle(Color.gsSecondary)
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.gsSecondary)
        }
    }

    // MARK: 补贴 / 扣款

    private func allowanceCard(kind: String, title: String, icon: String, color: Color,
                               items: [BonusItem],
                               daily: [(name: String, money: Double, note: String)]) -> some View {
        let total = items.reduce(0) { $0 + $1.money } + daily.reduce(0) { $0 + $1.money }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconTitle(icon: icon, title: title,
                          subtitle: "共 \(Cal.money(total)) 元")
                Spacer()
                Button {
                    let before = kind == "bonus" ? bonuses.count : deductions.count
                    store.importLastMonth(kind, year: year, month: month)
                    store.saveNow()
                    let after = kind == "bonus" ? bonuses.count : deductions.count
                    ToastCenter.shared.show(after > before
                        ? "已带入上月\(kind == "bonus" ? "补贴" : "扣款")"
                        : "上月没有可带入的\(kind == "bonus" ? "补贴" : "扣款")")
                } label: {
                    Label("带入上月", systemImage: "arrow.down.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            }

            if items.isEmpty && daily.isEmpty {
                Text("这个周期还没有\(title.replacingOccurrences(of: "明细", with: ""))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
                    .padding(.vertical, 6)
            }

            ForEach(items) { item in
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary)
                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gsSecondary)
                    }
                    Spacer()
                    Text(Cal.money(item.money))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(color)
                    Button {
                        store.deleteExtra(kind, year: year, month: month, id: item.id)
                        store.saveNow()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gsSecondary.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle(scale: 0.9))
                }
                .frame(height: 32)
            }

            if !daily.isEmpty {
                Divider().opacity(0.35)
                Text("记在每天里的")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.gsSecondary)
                ForEach(Array(daily.enumerated()), id: \.offset) { _, d in
                    HStack(spacing: 8) {
                        Text(d.name)
                            .font(.system(size: 12))
                        Text(d.note)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gsSecondary)
                        Spacer()
                        Text(Cal.money(d.money))
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(color)
                    }
                    .frame(height: 26)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func dailyExtras(positive: Bool) -> [(name: String, money: Double, note: String)] {
        var out: [(name: String, money: Double, note: String)] = []
        for (key, rec) in rows {
            for b in rec.bt where positive ? b.money >= 0 : b.money < 0 {
                let name = b.name.isEmpty ? (positive ? "补贴" : "扣款") : b.name
                let note = Cal.shortDate(key) + (b.note.isEmpty ? "" : " · " + b.note)
                out.append((name, abs(b.money), note))
            }
        }
        return out
    }

    // MARK: 每日明细

    private var dayDetailCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconTitle(icon: "list.bullet.rectangle.portrait", title: "每日明细",
                      subtitle: "共 \(rows.count) 天 · 点一行可看当天备注")
            .padding(.bottom, 8)

            LedgerRule(strong: true)

            HStack(spacing: 8) {
                Text("日").frame(width: 26, alignment: .leading)
                Text("班次").frame(width: 52, alignment: .leading)
                Text("工时").frame(width: 44, alignment: .trailing)
                Spacer()
                Text("金额").frame(width: 76, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(Ledger.inkSoft)
            .padding(.vertical, 7)

            LedgerRule()

            if rows.isEmpty {
                Text("这个周期还没有记录")
                    .font(.system(size: 12))
                    .foregroundStyle(Ledger.inkSoft)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(rows, id: \.0) { row in
                    let key = row.0
                    let rec = row.1
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", Cal.day(key)))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(Ledger.ink)
                                .frame(width: 26, alignment: .leading)
                            Text(store.shiftClass(rec.classId)?.name ?? "—")
                                .font(.system(size: 12))
                                .foregroundStyle(Ledger.inkSoft)
                                .lineLimit(1)
                                .frame(width: 52, alignment: .leading)
                            Text(Cal.num(rec.work.total))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Ledger.ink)
                                .frame(width: 44, alignment: .trailing)
                            Spacer()
                            AmountText(text: Cal.money(store.dayPay(rec)), size: 13)
                                .frame(width: 76, alignment: .trailing)
                        }
                        .frame(height: 38)

                        if !rec.note.isEmpty {
                            HStack {
                                Text(rec.note)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Ledger.inkSoft)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .padding(.bottom, 6)
                        }
                    }
                    LedgerRule()
                }

                HStack {
                    Text("合计 \(Cal.num(st.days)) 天 · \(Cal.num(st.hours)) H")
                        .font(.system(size: 11))
                        .foregroundStyle(Ledger.inkSoft)
                    Spacer()
                    AmountText(text: Cal.money(st.pay), size: 15, color: Ledger.red)
                }
                .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Ledger.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Ledger.rule, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 每日工时柱状图

/// 柱高按当天总工时，正班在底、加班/周末/节假在上；最高那天标数值，今天用主题色。
struct DayBarChart: View {
    let rows: [(String, DayRecord)]
    var palette: Palette

    @EnvironmentObject private var store: Store
    @State private var progress: CGFloat = 0

    private let plotH: CGFloat = 88

    var body: some View {
        let n = max(rows.count, 1)
        let peak = max(1, rows.map { $0.1.work.total }.max() ?? 1)
        let peakIdx = rows.firstIndex { abs($0.1.work.total - peak) < 0.001 }
        let today = Cal.todayKey()
        let labelEvery = n > 24 ? 3 : (n > 14 ? 2 : 1)
        let usable = plotH - 12

        return VStack(spacing: 5) {
            GeometryReader { geo in
                let colW = geo.size.width / CGFloat(n)
                let barW = max(3, min(18, colW * 0.56))
                let radius = min(3, barW / 2)

                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.7)
                        Spacer(minLength: 0)
                        Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 0.6)
                        Spacer(minLength: 0)
                        Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 0.6)
                    }
                    .frame(height: usable)

                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                            let rec = row.1
                            let total = max(0, rec.work.total)
                            let showPeak = idx == peakIdx && total > 0 && n <= 24
                            let avail = showPeak ? usable - 12 : usable
                            let h = avail * CGFloat(total / peak) * progress
                            let ot = rec.work.jb + rec.work.zm + rec.work.jj
                            let otH = total > 0 ? h * CGFloat(ot / total) : 0
                            let zbH = max(0, h - otH)
                            let isToday = row.0 == today

                            VStack(spacing: 1) {
                                Spacer(minLength: 0)

                                if showPeak {
                                    Text(Cal.num(total))
                                        .font(.system(size: 9, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(palette.primary)
                                        .frame(height: 10)
                                        .fixedSize()
                                        .opacity(progress > 0.15 ? 1 : 0)
                                }

                                VStack(spacing: 1) {
                                    if otH > 0.7 {
                                        UnevenRoundedRectangle(topLeadingRadius: radius,
                                                               bottomLeadingRadius: 0,
                                                               bottomTrailingRadius: 0,
                                                               topTrailingRadius: radius,
                                                               style: .continuous)
                                            .fill(Color.gsOrange.opacity(0.92))
                                            .frame(width: barW, height: otH)
                                    }
                                    if zbH > 0.7 {
                                        UnevenRoundedRectangle(topLeadingRadius: otH > 0.7 ? 0 : radius,
                                                               bottomLeadingRadius: 0,
                                                               bottomTrailingRadius: 0,
                                                               topTrailingRadius: otH > 0.7 ? 0 : radius,
                                                               style: .continuous)
                                            .fill(palette.primary.opacity(isToday ? 1 : 0.88))
                                            .frame(width: barW, height: zbH)
                                    }
                                    if total <= 0 {
                                        Capsule()
                                            .fill(Color.primary.opacity(0.10))
                                            .frame(width: barW, height: 1.5)
                                    }
                                }
                            }
                            .frame(width: colW, height: usable, alignment: .bottom)
                            .animation(store.chartMotion
                                       ? .spring(response: 0.55, dampingFraction: 0.85)
                                            .delay(Double(min(idx, 30)) * 0.012)
                                       : nil,
                                       value: progress)
                        }
                    }
                    .frame(height: usable, alignment: .bottom)

                    Rectangle()
                        .fill(Color.primary.opacity(0.16))
                        .frame(height: 0.8)
                }
            }
            .frame(height: plotH)

            HStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    Text(idx % labelEvery == 0 ? "\(Cal.day(row.0))" : " ")
                        .font(.system(size: 9,
                                      weight: row.0 == today ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(row.0 == today ? palette.primary : Ledger.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)
        }
        .onAppear { play() }
        .onChange(of: store.chartToken) { _, _ in play() }
    }

    private func play() {
        guard store.chartMotion else {
            progress = 1
            return
        }
        progress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            progress = 1
        }
    }
}

// MARK: - 带图标的标题

struct IconTitle: View {
    let icon: String
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

// MARK: - 工时构成环形图

struct HoursDonut: View {
    let zb: Double
    let ot: Double
    let zm: Double
    let jj: Double
    var palette: Palette

    @EnvironmentObject private var store: Store
    @State private var appeared = false

    private var total: Double { max(0.0001, zb + ot + zm + jj) }

    var body: some View {
        let a = zb / total
        let b = (zb + ot) / total
        let c = (zb + ot + zm) / total

        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 11)

            arc(from: 0, to: appeared ? a : 0, color: palette.primary)
            arc(from: a, to: appeared ? b : a, color: Color.gsOrange)
            arc(from: b, to: appeared ? c : b, color: Color.gsGreen)
            arc(from: c, to: appeared ? 1 : c, color: Color.gsRed)

            VStack(spacing: 0) {
                Text(Cal.num(zb + ot + zm + jj))
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
                    .contentTransition(.numericText())
                Text("小时")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.gsSecondary)
            }
        }
        .frame(width: 104, height: 104)
        .onAppear { replay() }
        .onChange(of: store.chartToken) { _, _ in replay() }
    }

    private func replay() {
        guard store.chartMotion else {
            appeared = true
            return
        }
        appeared = false
        withAnimation(.easeOut(duration: 0.65)) { appeared = true }
    }

    private func arc(from: Double, to: Double, color: Color) -> some View {
        Circle()
            .trim(from: from, to: max(from, min(1, to)))
            .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}

// MARK: - 雷达图

/// 六边形雷达，值都是 0...1，标签外圈显示百分数。
struct RadarChart: View {
    let axes: [(String, Double)]
    var palette: Palette

    @EnvironmentObject private var store: Store
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let radius = min(geo.size.width, geo.size.height) / 2 - 30
            let n = max(axes.count, 3)

            ZStack {
                ForEach(1...3, id: \.self) { k in
                    ringPath(cx, cy, radius * CGFloat(k) / 3, values: Array(repeating: 1, count: n))
                        .stroke(Color.primary.opacity(0.10), lineWidth: 0.7)
                }

                ForEach(0..<n, id: \.self) { i in
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: point(i, 1, cx, cy, radius, n))
                    }
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.7)
                }

                let scale = appeared ? 1.0 : 0.02

                ringPath(cx, cy, radius, values: axes.map { $0.1 * scale })
                    .fill(palette.primary.opacity(0.16))
                ringPath(cx, cy, radius, values: axes.map { $0.1 * scale })
                    .stroke(palette.primary, style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                    .shadow(color: palette.primary.opacity(0.25), radius: 3)

                ForEach(0..<n, id: \.self) { i in
                    Circle()
                        .fill(palette.primary)
                        .frame(width: 4.5, height: 4.5)
                        .position(point(i, axes[i].1 * scale, cx, cy, radius, n))
                }

                ForEach(0..<n, id: \.self) { i in
                    VStack(spacing: 0) {
                        Text(axes[i].0)
                            .font(.system(size: 9))
                            .foregroundStyle(Ledger.inkSoft)
                        Text("\(Int((axes[i].1 * 100).rounded()))")
                            .font(.system(size: 9, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                    }
                    .position(point(i, 1, cx, cy, radius + 18, n))
                }
            }
        }
        .frame(height: 196)
        .onAppear { replay() }
        .onChange(of: store.chartToken) { _, _ in replay() }
    }

    private func replay() {
        guard store.chartMotion else {
            appeared = true
            return
        }
        appeared = false
        withAnimation(.easeOut(duration: 0.65)) { appeared = true }
    }

    private func point(_ i: Int, _ v: Double, _ cx: CGFloat, _ cy: CGFloat,
                       _ r: CGFloat, _ n: Int) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(i) * 2 * CGFloat.pi / CGFloat(n)
        return CGPoint(x: cx + cos(angle) * r * CGFloat(v),
                       y: cy + sin(angle) * r * CGFloat(v))
    }

    private func ringPath(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat,
                          values: [Double]) -> Path {
        var p = Path()
        for (i, v) in values.enumerated() {
            let pt = point(i, v, cx, cy, r, values.count)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
