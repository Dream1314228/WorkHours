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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
        }
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
            HStack(spacing: 8) {
                hourTile("正班", st.zb, palette.primary, "sun.max.fill")
                hourTile("加班", st.jb, Color.gsOrange, "moon.stars.fill")
                hourTile("周末", st.zm, Color.gsOrange, "calendar.badge.clock")
                hourTile("节假", st.jj, Color.gsRed, "flag.fill")
            }
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
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
                if kind == "bonus" {
                    Button {
                        store.importLastMonth("bonus", year: year, month: month)
                        store.saveNow()
                        ToastCenter.shared.show("已带入上月补贴")
                    } label: {
                        Text("带入上月")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
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

struct DayBarChart: View {
    let rows: [(String, DayRecord)]
    var palette: Palette

    @State private var grown = false

    private let chartHeight: CGFloat = 84

    var body: some View {
        GeometryReader { geo in
            let count = max(rows.count, 1)
            let gap: CGFloat = count > 22 ? 2 : 4
            let barW = max(3, (geo.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            let maxV = max(1, rows.map { $0.1.work.total }.max() ?? 1)
            let labelEvery = count > 24 ? 3 : (count > 14 ? 2 : 1)

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    let rec = row.1
                    VStack(spacing: 3) {
                        VStack(spacing: 1) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: barW / 2.6, style: .continuous)
                                .fill(Color.gsOrange)
                                .frame(width: barW,
                                       height: max(0, chartHeight * CGFloat((rec.work.jb + rec.work.zm + rec.work.jj) / maxV) * (grown ? 1 : 0)))
                            RoundedRectangle(cornerRadius: barW / 2.6, style: .continuous)
                                .fill(palette.primary)
                                .frame(width: barW,
                                       height: max(0, chartHeight * CGFloat(rec.work.zb / maxV) * (grown ? 1 : 0)))
                        }
                        .frame(height: chartHeight, alignment: .bottom)

                        Text((idx % labelEvery == 0) ? "\(Cal.day(row.0))" : " ")
                            .font(.system(size: 8))
                            .monospacedDigit()
                            .foregroundStyle(Ledger.inkSoft)
                    }
                }
            }
        }
        .frame(height: chartHeight + 24)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86).delay(0.06)) {
                grown = true
            }
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
