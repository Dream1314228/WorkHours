import SwiftUI
import UIKit

struct StatsPage: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    @State private var year = Cal.year(Cal.todayKey())
    @State private var month = Cal.month(Cal.todayKey())
    @State private var mode = 0     // 0 月 / 1 年

    private var monthStats: MonthStats { store.monthStats(year: year, month: month) }
    private var yearStats: YearStats { store.yearStats(year: year) }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    modePicker
                    if mode == 0 {
                        monthView
                    } else {
                        yearView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(mode == 0 ? Cal.monthTitle(year: year, month: month) : "\(String(year)) 年")
                    .font(.system(size: 26, weight: .bold))
                Text(mode == 0 ? "考勤期 \(monthStats.start) 至 \(monthStats.end)" : "全年 \(Cal.num(yearStats.hours)) 小时")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
                    .monospacedDigit()
            }
            Spacer()
            if mode == 0 {
                stepButton("chevron.left") { step(-1) }
                stepButton("chevron.right") { step(1) }
            } else {
                stepButton("chevron.left") { year -= 1 }
                stepButton("chevron.right") { year += 1 }
            }
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .contentShape(Circle().inset(by: -5))
                    .background(Circle().fill(Color.primary.opacity(0.08)))
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 2)
    }

    private var shareText: String {
        if mode == 0 { return store.reportText(year: year, month: month) }
        var lines = ["工时记录 · \(year) 年"]
        for m in 1...12 {
            let st = yearStats.months[m - 1]
            lines.append("\(m) 月：\(Cal.num(st.hours))H，\(Cal.num(st.days)) 天，\(Cal.money(st.pay))")
        }
        lines.append("合计：\(Cal.num(yearStats.hours))H，\(Cal.money(yearStats.pay))")
        return lines.joined(separator: "\n")
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .contentShape(Circle().inset(by: -5))
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
        }
        .buttonStyle(PressableStyle())
    }

    private func step(_ delta: Int) {
        let next = Cal.monthAdd(year, month, delta)
        year = next.year
        month = next.month
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            Button { mode = 0 } label: {
                ChipView(title: "按月", selected: mode == 0, palette: palette)
            }
            .buttonStyle(PressableStyle())
            Button { mode = 1 } label: {
                ChipView(title: "按年", selected: mode == 1, palette: palette)
            }
            .buttonStyle(PressableStyle())
            Spacer()
            if mode == 1 {
                Button {
                    year += 1
                } label: {
                    Text("下一年")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: 月

    private var monthView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                StatTile(value: "\(Cal.num(monthStats.hours))H", label: "总工时",
                         color: Color.primary, palette: palette)
                StatTile(value: "\(Cal.num(monthStats.days))天", label: "出勤", palette: palette)
                StatTile(value: Cal.money(monthStats.pay), label: "实发工资",
                         color: Color.gsOrange, palette: palette)
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "工时构成", subtitle: "共 \(Cal.num(monthStats.hours)) 小时")
                HStack(spacing: 8) {
                    hourTile("正班", monthStats.zb, Color.primary)
                    hourTile("加班", monthStats.jb, Color.gsOrange)
                    hourTile("周末", monthStats.zm, Color.gsOrange)
                    hourTile("节假", monthStats.jj, Color.gsRed)
                }
                Divider().opacity(0.4)
                statRow("补贴", Cal.money(monthStats.bonus),
                        color: Color.gsGreen)
                statRow("扣款", Cal.money(monthStats.deduct),
                        color: Color.gsRed)
                statRow("日均工时", "\(Cal.num(monthStats.days > 0 ? monthStats.hours / monthStats.days : 0)) H")
                statRow("平均时薪", Cal.money(monthStats.avg))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: store.settings.cardRadius)

            chartCard(months: yearStats.months, title: "\(String(year)) 年每月工时")

            monthDetailCard
        }
    }

    private func hourTile(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(Cal.num(value))
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
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

    private func statRow(_ title: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
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

    private var monthDetailCard: some View {
        let rows = store.records(in: year, month: month)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                LedgerCaption(text: "账目明细")
                Spacer()
                Button {
                    UIPasteboard.general.string = shareText
                    ToastCenter.shared.show("报表已复制")
                } label: {
                    Text("复制")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Ledger.blue)
                        .padding(.horizontal, 9)
                        .frame(height: 26)
                        .overlay {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Ledger.rule, lineWidth: 0.8)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.bottom, 6)

            LedgerRule(strong: true)

            HStack(spacing: 8) {
                Text("日").frame(width: 26, alignment: .leading)
                Text("班次").frame(width: 44, alignment: .leading)
                Text("工时").frame(width: 44, alignment: .trailing)
                Spacer()
                Text("金额").frame(width: 72, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(Ledger.inkSoft)
            .padding(.vertical, 7)

            LedgerRule()

            if rows.isEmpty {
                Text("这个月还没有记录")
                    .font(.system(size: 12))
                    .foregroundStyle(Ledger.inkSoft)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(rows, id: \.0) { row in
                    let key = row.0
                    let rec = row.1
                    HStack(spacing: 8) {
                        Text(String(format: "%02d", Cal.day(key)))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Ledger.ink)
                            .frame(width: 26, alignment: .leading)
                        Text(store.shiftClass(rec.classId)?.name ?? "—")
                            .font(.system(size: 12))
                            .foregroundStyle(Ledger.inkSoft)
                            .lineLimit(1)
                            .frame(width: 44, alignment: .leading)
                        Text(Cal.num(rec.work.total))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Ledger.ink)
                            .frame(width: 44, alignment: .trailing)
                        Spacer()
                        AmountText(text: Cal.money(store.dayPay(rec)), size: 13)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    LedgerRule()
                }

                HStack {
                    Text("合计 \(Cal.num(monthStats.days)) 天 · \(Cal.num(monthStats.hours)) H")
                        .font(.system(size: 11))
                        .foregroundStyle(Ledger.inkSoft)
                    Spacer()
                    AmountText(text: Cal.money(monthStats.pay), size: 15, color: Ledger.red)
                }
                .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Ledger.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Ledger.rule, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    // MARK: 年

    private var yearView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                StatTile(value: "\(Cal.num(yearStats.hours))H", label: "全年工时",
                         color: Color.primary, palette: palette)
                StatTile(value: "\(Cal.num(yearStats.days))天", label: "出勤", palette: palette)
                StatTile(value: Cal.money(yearStats.pay), label: "全年工资",
                         color: Color.gsOrange, palette: palette)
            }

            chartCard(months: yearStats.months, title: "每月工时")

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "全年合计")
                statRow("加班 / 周末 / 节假", "\(Cal.num(yearStats.ot)) H",
                        color: Color.gsOrange)
                statRow("补贴", Cal.money(yearStats.bonus),
                        color: Color.gsGreen)
                statRow("扣款", Cal.money(yearStats.deduct),
                        color: Color.gsRed)
                statRow("平均时薪", Cal.money(yearStats.avg))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: store.settings.cardRadius)

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "逐月", subtitle: "点一行切到那个月")
                ForEach(1...12, id: \.self) { m in
                    let st = yearStats.months[m - 1]
                    Button {
                        month = m
                        mode = 0
                    } label: {
                        HStack {
                            Text("\(m) 月")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 36, alignment: .leading)
                            Text("\(Cal.num(st.days))天")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.gsSecondary)
                                .frame(width: 40, alignment: .leading)
                            Text("\(Cal.num(st.hours))H")
                                .font(.system(size: 12))
                                .monospacedDigit()
                            Spacer()
                            Text(Cal.money(st.pay))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(st.pay > 0 ? Color.gsOrange : Color.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.gsSecondary)
                        }
                        .frame(height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle(scale: 0.99))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: store.settings.cardRadius)
        }
    }

    // MARK: 图表

    private func chartCard(months: [MonthStats], title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: title, subtitle: "单位：小时")
            MonthBarChart(months: months, palette: palette) { m in
                month = m
                mode = 0
            }
            HStack(spacing: 12) {
                legendDot("正班", palette.primary)
                legendDot("加班/周末/节假", Color.gsOrange)
                legendDot("补贴", Color.gsGreen)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func legendDot(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.gsSecondary)
        }
    }
}

// MARK: - 12 个月柱状图

struct MonthBarChart: View {
    var months: [MonthStats]
    var palette: Palette
    var onSelect: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var maxHours: Double {
        max(1, months.map { $0.hours }.max() ?? 1)
    }
    private var maxBonus: Double {
        max(1, months.map { $0.bonus }.max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<12, id: \.self) { i in
                let m = months[i]
                Button {
                    onSelect(i + 1)
                } label: {
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            let h = geo.size.height
                            let grow: CGFloat = appeared ? 1 : 0
                            VStack(spacing: 1) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(Color.gsOrange)
                                    .frame(height: max(0, h * CGFloat((m.jb + m.zm + m.jj) / maxHours) * grow))
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(palette.primary)
                                    .frame(height: max(0, h * CGFloat(m.zb / maxHours) * grow))
                            }
                        }
                        .frame(height: 96)

                        // 补贴：独立归一化的细条，和工时不同量纲
                        Capsule()
                            .fill(Color.gsGreen)
                            .frame(width: 10,
                                   height: max(1.5, 8 * CGFloat(m.bonus / maxBonus) * CGFloat(appeared ? 1 : 0)))
                            .opacity(m.bonus > 0 ? 1 : 0.18)

                        Text("\(i + 1)")
                            .font(.system(size: 9))
                            .foregroundStyle(m.hours > 0 ? Color.secondary : Color.secondary.opacity(0.6))
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.95))
            }
        }
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.05)) {
                    appeared = true
                }
            }
        }
    }
}
