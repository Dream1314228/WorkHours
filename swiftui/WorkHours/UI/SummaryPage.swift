import SwiftUI

/// 总结页：全年 / 整月两种口径，从统计页里分出来。
struct SummaryPage: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    @State private var mode = 0        // 0 全年 / 1 整月
    @State private var year = Cal.year(Cal.todayKey())
    @State private var month = Cal.month(Cal.todayKey())

    private var ys: YearStats { store.yearStats(year: year) }
    private var zbTotal: Double { ys.months.reduce(0) { $0 + $1.zb } }
    private var jbTotal: Double { ys.months.reduce(0) { $0 + $1.jb } }
    private var zmTotal: Double { ys.months.reduce(0) { $0 + $1.zm } }
    private var jjTotal: Double { ys.months.reduce(0) { $0 + $1.jj } }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if mode == 0 {
                        yearView
                    } else {
                        MonthSummaryContent(year: year, month: month, palette: palette)
                            .id("\(year)-\(month)")
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode == 0 ? "\(String(year)) 年总结" : "\(year) 年 \(month) 月总结")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Ledger.ink)
                        .contentTransition(.numericText())
                    Text(mode == 0
                         ? "全年 \(Cal.num(ys.hours)) 小时 · \(Cal.money(ys.pay)) 元"
                         : "考勤期 \(store.monthStats(year: year, month: month).start) 至 \(store.monthStats(year: year, month: month).end)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 4)
                circleButton("chevron.left") { step(-1) }
                circleButton("chevron.right") { step(1) }
            }

            HStack(spacing: 6) {
                segment("全年", 0, "calendar")
                segment("整月", 1, "calendar.badge.clock")
                Spacer()
            }
        }
        .padding(.horizontal, 2)
    }

    private func segment(_ title: String, _ value: Int, _ icon: String) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { mode = value }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(mode == value ? palette.onPrimary : Ledger.inkSoft)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background {
                Capsule().fill(mode == value ? palette.primary : Color.primary.opacity(0.06))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.95))
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
        withAnimation(.snappy(duration: 0.24)) {
            if mode == 0 {
                year += delta
            } else {
                let next = Cal.monthAdd(year, month, delta)
                year = next.year
                month = next.month
            }
        }
    }

    // MARK: 全年

    private var yearView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                StatTile(value: "\(Cal.num(ys.hours))H", label: "全年工时",
                         color: Color.primary, palette: palette)
                StatTile(value: "\(Cal.num(ys.days))天", label: "出勤", palette: palette)
                StatTile(value: Cal.money(ys.pay), label: "全年工资",
                         color: Color.gsOrange, palette: palette)
            }

            VStack(alignment: .leading, spacing: 10) {
                IconTitle(icon: "chart.bar.xaxis", title: "每月工时", subtitle: "单位：小时 · 点柱子看整月")
                MonthBarChart(months: ys.months, palette: palette) { m in
                    withAnimation(.snappy(duration: 0.2)) {
                        month = m
                        mode = 1
                    }
                }
                HStack(spacing: 14) {
                    legend("正班", palette.primary)
                    legend("加班 / 周末 / 节假", Color.gsOrange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: store.settings.cardRadius)

            VStack(alignment: .leading, spacing: 12) {
                IconTitle(icon: "sum", title: "全年构成",
                          subtitle: "\(Cal.num(ys.days)) 天 · \(Cal.num(ys.hours)) 小时")

                HStack(alignment: .center, spacing: 14) {
                    HoursDonut(zb: zbTotal, ot: jbTotal, zm: zmTotal, jj: jjTotal, palette: palette)
                    VStack(alignment: .leading, spacing: 7) {
                        legendRow(palette.primary, "正班", zbTotal)
                        legendRow(Color.gsOrange, "加班", jbTotal)
                        legendRow(Color.gsGreen, "周末", zmTotal)
                        legendRow(Color.gsRed, "节假", jjTotal)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)

                Divider().opacity(0.4)

                compareBar("补贴", ys.bonus, Color.gsGreen)
                compareBar("扣款", ys.deduct, Color.gsRed)

                Divider().opacity(0.4)
                iconRow("gauge.with.dots.needle.33percent", "平均时薪", Cal.money(ys.avg), .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: store.settings.cardRadius)

            VStack(alignment: .leading, spacing: 0) {
                IconTitle(icon: "tablecells", title: "逐月", subtitle: "点一行看整月总结")
                    .padding(.bottom, 8)
                LedgerRule(strong: true)
                HStack(spacing: 8) {
                    Text("月").frame(width: 26, alignment: .leading)
                    Text("天").frame(width: 30, alignment: .leading)
                    Text("工时").frame(width: 52, alignment: .trailing)
                    Spacer()
                    Text("工资").frame(width: 84, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Ledger.inkSoft)
                .padding(.vertical, 7)
                LedgerRule()

                ForEach(1...12, id: \.self) { m in
                    let st = ys.months[m - 1]
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            month = m
                            mode = 1
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("\(m)").font(.system(size: 13, weight: .semibold)).frame(width: 26, alignment: .leading)
                            Text("\(Cal.num(st.days))").font(.system(size: 11)).foregroundStyle(Color.gsSecondary).frame(width: 30, alignment: .leading)
                            Text("\(Cal.num(st.hours))").font(.system(size: 12)).monospacedDigit().frame(width: 52, alignment: .trailing)
                            Spacer()
                            Text(Cal.money(st.pay)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                                .foregroundStyle(st.pay > 0 ? Color.gsOrange : Color.gsSecondary)
                                .frame(width: 84, alignment: .trailing)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.gsSecondary)
                        }
                        .frame(height: 40)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle(scale: 0.99))
                    LedgerRule()
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

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2.5).fill(color).frame(width: 9, height: 9)
            Text(title).font(.system(size: 10)).foregroundStyle(Color.gsSecondary)
        }
    }

    private func legendRow(_ color: Color, _ name: String, _ v: Double) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
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

    private func compareBar(_ name: String, _ value: Double, _ color: Color) -> some View {
        let peak = max(1, ys.bonus, ys.deduct)
        return HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(Color.gsSecondary)
                .frame(width: 30, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.14))
                    Capsule().fill(color)
                        .frame(width: max(value > 0 ? 5 : 0,
                                          g.size.width * CGFloat(value / peak)))
                }
            }
            .frame(height: 8)
            Text(Cal.money(value))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(width: 74, alignment: .trailing)
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
                .foregroundStyle(color)
        }
    }
}

// MARK: - 12 个月柱状图

/// 只画工时，不掺补贴；柱宽、圆角、间距按 12 个月平分，看着整。
struct MonthBarChart: View {
    var months: [MonthStats]
    var palette: Palette
    var onSelect: (Int) -> Void

    @State private var grown = false

    private var maxHours: Double {
        max(1, months.map { $0.hours }.max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<12, id: \.self) { i in
                let m = months[i]
                Button {
                    onSelect(i + 1)
                } label: {
                    VStack(spacing: 5) {
                        VStack(spacing: 1.5) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.gsOrange.opacity(0.85))
                                .frame(height: max(0, 96 * CGFloat((m.jb + m.zm + m.jj) / maxHours) * (grown ? 1 : 0)))
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.primary.opacity(0.9))
                                .frame(height: max(0, 96 * CGFloat(m.zb / maxHours) * (grown ? 1 : 0)))
                            if m.hours <= 0 {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Ledger.rule)
                                    .frame(height: 2)
                            }
                        }
                        .frame(height: 96, alignment: .bottom)
                        Text("\(i + 1)")
                            .font(.system(size: 9, weight: m.hours > 0 ? .medium : .regular))
                            .monospacedDigit()
                            .foregroundStyle(m.hours > 0 ? Color.gsSecondary : Color.gsSecondary.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.94))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.05)) {
                grown = true
            }
        }
    }
}
