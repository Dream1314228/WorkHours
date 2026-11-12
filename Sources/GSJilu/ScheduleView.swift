
import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: GSStore
    @State private var boardView = false
    @State private var year: Int = GSDate.gregorian.component(.year, from: Date())
    @State private var month: Int = GSDate.gregorian.component(.month, from: Date())
    @State private var selectedDate: String = GSDate.todayKey()
    @State private var palette: String = GSStore.shared.stringSetting("currentClass", default: "1")
    @EnvironmentObject var toast: GSToastCenter
    @State private var shareURL: URL?

    var body: some View {
        let st = store.yearStats(year: year)
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header(st)
                Picker("", selection: $boardView) {
                    Text("排班").tag(false)
                    Text("看板").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                if boardView { board(st) } else { schedule }
                Color.clear.frame(height: 20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(item: Binding(
            get: { shareURL.map { IdentifiedURL(url: $0) } },
            set: { shareURL = $0?.url }
        )) { item in
            GSShareSheet(items: [item.url])
        }
    }

    private func header(_ st: [String: Any]) -> some View {
        let planned: Int = {
            let dim = GSDate.daysInMonth(year: year, month: month)
            var n = 0
            for d in 1...dim { if !store.plan(for: GSDate.dayKey(year, month, d)).isEmpty { n += 1 } }
            return n
        }()
        let dim = GSDate.daysInMonth(year: year, month: month)
        let recorded: Int = {
            var n = 0
            for d in 1...dim { if store.record(for: GSDate.dayKey(year, month, d)) != nil { n += 1 } }
            return n
        }()
        var classSet = Set<String>()
        for d in 1...dim {
            let p = store.plan(for: GSDate.dayKey(year, month, d))
            if !p.isEmpty { classSet.insert(p) }
        }
        let title = boardView ? "\(year) 年度" : "\(year) 年 \(month) 月"
        let big = boardView ? "¥\(GSNum(GSJSONNumber(st["pay"])))" : "排班计划"
        let sub = boardView
            ? String(format: "时薪 %.0f元  ·  %ld年 %@ 天出勤", GSJSONNumber(st["avg"]), year, GSNum(GSJSONNumber(st["days"])))
            : "已排 \(planned) 天 · 未排 \(dim - planned) 天 · 点日期切换班次"
        return VStack(spacing: 0) {
            GSHeaderBlock(title: title, subtitle: sub, trailing: AnyView(
                HStack(spacing: 10) {
                    if boardView {
                        Button { year -= 1 } label: { Image(systemName: "chevron.left").foregroundColor(.white) }
                        Button { year += 1 } label: { Image(systemName: "chevron.right").foregroundColor(.white) }
                    }
                }
            )).frame(height: 130)
            HStack(spacing: 8) {
                if boardView {
                    headerStat("\(GSNum(GSJSONNumber(st["hours"])))H", "总工时")
                    headerStat("\(GSNum(GSJSONNumber(st["days"])))天", "出勤")
                    headerStat(String(format: "%.0f元", GSJSONNumber(st["avg"])), "平均时薪")
                    headerStat("\(GSNum(GSJSONNumber(st["ot"])))H", "加班")
                } else {
                    headerStat("\(planned)天", "已排")
                    headerStat("\(dim - planned)天", "未排")
                    headerStat("\(classSet.count)", "班次数")
                    headerStat("\(recorded)天", "已记录")
                }
            }
            .padding(.horizontal, 18)
            .offset(y: 14)
            .padding(.bottom, 14)
        }
    }

    private func headerStat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 14, weight: .bold)).foregroundColor(GSTextPrimary()).lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(.system(size: 10)).foregroundColor(GSTextSecondary())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: store.cardShadow ? Color.black.opacity(0.05) : .clear, radius: 6, x: 0, y: 2)
    }

    private var schedule: some View {
        GSCard {
            VStack(spacing: 14) {
                HStack {
                    Button { let c = GSDate.monthAdd(year: year, month: month, delta: -1); year = c.year; month = c.month; selectedDate = GSDate.dayKey(year, month, 1) } label: {
                        Image(systemName: "chevron.left").foregroundColor(GSTextPrimary())
                            .frame(width: 34, height: 34).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Spacer()
                    Text("\(year)年 \(month)月").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    Spacer()
                    Button { let c = GSDate.monthAdd(year: year, month: month, delta: 1); year = c.year; month = c.month; selectedDate = GSDate.dayKey(year, month, 1) } label: {
                        Image(systemName: "chevron.right").foregroundColor(GSTextPrimary())
                            .frame(width: 34, height: 34).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                GSMonthCalendar(year: year, month: month, selectedDate: $selectedDate) { key in
                    assignPlan(key)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("排班标记 · 先选班次，再点日期").font(.system(size: 12, weight: .medium)).foregroundColor(GSTextSecondary())
                    Text("当前：\((store.classItem(id: palette)?["name"] as? String) ?? "未选班次") · 点日期排班")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                    HStack(spacing: 6) {
                        ForEach(Array(store.classes.enumerated()), id: \.offset) { _, c in
                            let on = palette == (c["id"] as? String)
                            Button {
                                palette = (c["id"] as? String) ?? "1"
                            } label: {
                                Text(c["name"] as? String ?? "")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(on ? GSTheme.color(for: store.themeKey) : GSTextSecondary())
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(on ? GSTheme.softColor(for: store.themeKey) : GSColorHex("#F2F5FA"))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? GSTheme.color(for: store.themeKey) : .clear, lineWidth: 1.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        Button("清除") {
                            store.setPlan("", for: selectedDate)
                            toast.show("已清除")
                            GSHaptic()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GSTextSecondary())
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(GSColorHex("#F2F5FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                Text("排班只做标记，不会自动生成工时；记录页仍按实际工时算工资。")
                    .font(.system(size: 11)).foregroundColor(GSTextSecondary())
            }
        }
        .padding(.horizontal, 18)
    }

    private func assignPlan(_ date: String) {
        if palette.isEmpty { return }
        store.setPlan(palette, for: date)
        selectedDate = date
        GSHaptic()
    }

    private func board(_ st: [String: Any]) -> some View {
        let months = (st["months"] as? [[String: Any]]) ?? []
        let totalH = GSJSONNumber(st["hours"]), totalDays = GSJSONNumber(st["days"])
        let totalOT = GSJSONNumber(st["ot"]), totalPay = GSJSONNumber(st["pay"])
        var weekendH = 0.0, holidayH = 0.0, normalH = 0.0, overtimeH = 0.0, bestH = 0.0, maxPay = 0.0, minPay = 0.0
        var activeMonths = 0, bestMonth = 0, bestPayMonth = 0, lowestPayMonth = 0
        for (i, m) in months.enumerated() {
            let h = GSJSONNumber(m["hours"])
            normalH += GSJSONNumber(m["zb"])
            overtimeH += GSJSONNumber(m["jb"])
            weekendH += GSJSONNumber(m["zm"])
            holidayH += GSJSONNumber(m["jj"])
            if h > 0 {
                activeMonths += 1
                let mp = GSJSONNumber(m["pay"])
                if bestPayMonth == 0 || mp > maxPay { maxPay = mp; bestPayMonth = i + 1 }
                if lowestPayMonth == 0 || mp < minPay { minPay = mp; lowestPayMonth = i + 1 }
            }
            if h > bestH { bestH = h; bestMonth = i + 1 }
        }
        let avgDaily = totalDays > 0 ? totalH / totalDays : 0
        let avgMonth = activeMonths > 0 ? totalH / Double(activeMonths) : 0
        let avgMonthPay = activeMonths > 0 ? totalPay / Double(activeMonths) : 0
        let otRate = totalH > 0 ? totalOT / totalH * 100 : 0
        let leaveTotal = store.annualLeaveTotalDays()
        let leaveUsed = store.annualLeaveUsedDays(year: year)
        let boardWork = max(0, GSJSONNumber(st["workPay"]))
        let boardBonus = max(0, GSJSONNumber(st["bonus"]))

        return VStack(spacing: 14) {
            Button {
                if let url = GSHTMLReport.generate(year: year) { shareURL = url }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出 HTML 报表")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GSTheme.color(for: store.themeKey))
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(GSBorderColor(), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 18)

            GSCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("年度概览").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    metricRow([
                        ("日均工时", "\(GSNum(avgDaily))H", GSTheme.color(for: store.themeKey)),
                        ("加班占比", String(format: "%.0f%%", otRate), GSWarningColor()),
                        ("有记录月份", "\(activeMonths)", GSSuccessColor())
                    ])
                    metricRow([
                        ("月均工时", "\(GSNum(avgMonth))H", GSTheme.color(for: store.themeKey)),
                        ("年假使用", "\(GSNum(leaveUsed))/\(GSNum(leaveTotal))天", GSColorHex("#6941C6")),
                        ("最高月", bestMonth > 0 ? "\(bestMonth)月" : "—", GSDangerColor())
                    ])
                    metricRow([
                        ("最高月工资", bestPayMonth > 0 ? "\(bestPayMonth)月 \(GSMoney(maxPay))" : "—", GSSuccessColor()),
                        ("月均工资", GSMoney(avgMonthPay), GSTheme.color(for: store.themeKey)),
                        ("最低月工资", lowestPayMonth > 0 ? "\(lowestPayMonth)月 \(GSMoney(minPay))" : "—", GSWarningColor())
                    ])
                }
            }.padding(.horizontal, 18)

            yearParts(normalH: normalH, overtimeH: overtimeH, weekendH: weekendH, holidayH: holidayH, totalH: totalH)
            monthBars(months: months)
            payTrend(months: months)
            heat
            incomeYear(st: st, boardWork: boardWork, boardBonus: boardBonus)
            incomeDetail(st: st, months: months)
        }
    }

    private func metricRow(_ items: [(String, String, Color)]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                VStack(spacing: 3) {
                    Text(it.1).font(.system(size: 14, weight: .bold)).foregroundColor(it.2).lineLimit(1).minimumScaleFactor(0.6)
                    Text(it.0).font(.system(size: 10)).foregroundColor(GSTextSecondary())
                }
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(GSColorHex("#F7F9FC"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func yearParts(normalH: Double, overtimeH: Double, weekendH: Double, holidayH: Double, totalH: Double) -> some View {
        let parts = [("正班", normalH, GSColorHex("#1859D9")), ("加班", overtimeH, GSColorHex("#D92D20")), ("周末", weekendH, GSColorHex("#12B76A")), ("节假", holidayH, GSColorHex("#F79009"))]
        return GSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("工时构成 · 全年").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                ForEach(0..<4, id: \.self) { i in
                    let v = parts[i].1
                    let ratio = totalH > 0 ? v / totalH : 0
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(parts[i].0).font(.system(size: 13, weight: .semibold)).foregroundColor(GSTextStrong())
                            Spacer()
                            Text(String(format: "%@H · %.0f%%", GSNum(v), ratio * 100)).font(.system(size: 12, weight: .medium)).foregroundColor(parts[i].2)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(GSColorHex("#EEF2F7"))
                                Capsule().fill(parts[i].2).frame(width: geo.size.width * CGFloat(max(0, min(1, ratio))))
                            }
                        }.frame(height: 6)
                    }
                }
            }
        }.padding(.horizontal, 18)
    }

    private func monthBars(months: [[String: Any]]) -> some View {
        let maxH = max(months.map { GSJSONNumber($0["hours"]) }.max() ?? 1, 1)
        return GSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("十二个月工时结构").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<12, id: \.self) { i in
                        let m = i < months.count ? months[i] : [:]
                        let total = GSJSONNumber(m["hours"])
                        let normal = GSJSONNumber(m["zb"])
                        let h = 8 + total / maxH * 118
                        let normalH = total > 0 ? h * normal / total : 0
                        let otH = total > 0 ? h - normalH : 0
                        VStack(spacing: 4) {
                            VStack(spacing: 0) {
                                GSColorHex("#D92D20").frame(height: CGFloat(otH))
                                GSTheme.color(for: store.themeKey).frame(height: CGFloat(normalH))
                            }
                            .frame(width: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .background(GSColorHex("#E7EDF6"))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            Text("\(i+1)").font(.system(size: 10)).foregroundColor(GSTextSecondary())
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 150)
                HStack(spacing: 16) {
                    HStack(spacing: 4) { Circle().fill(GSColorHex("#1859D9")).frame(width: 8, height: 8); Text("正班工时").font(.system(size: 10)).foregroundColor(GSTextSecondary()) }
                    HStack(spacing: 4) { Circle().fill(GSColorHex("#D92D20")).frame(width: 8, height: 8); Text("加班/周末/节假").font(.system(size: 10)).foregroundColor(GSTextSecondary()) }
                }
                Text("柱高为当月总工时；颜色只分段正班与其他工时，补贴不在工时图中。")
                    .font(.system(size: 10)).foregroundColor(GSTextTertiary())
            }
        }.padding(.horizontal, 18)
    }

    private func payTrend(months: [[String: Any]]) -> some View {
        GSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("月度工资趋势").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                GSTrendChart(values: months.map { GSJSONNumber($0["pay"]) }, labels: (1...12).map { "\($0)" }, lineColor: GSColorHex("#1859D9"))
                    .frame(height: 150)
                Text("按月实发工资；包含补贴、扣款，不含未记录月份。")
                    .font(.system(size: 10)).foregroundColor(GSTextTertiary())
            }
        }.padding(.horizontal, 18)
    }

    private var heat: some View {
        GSCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("全年节奏").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                VStack(spacing: 3) {
                    ForEach(0..<12, id: \.self) { m in
                        let dim = GSDate.daysInMonth(year: year, month: m + 1)
                        HStack(spacing: 2) {
                            ForEach(1...31, id: \.self) { d in
                                let color: Color = {
                                    if d > dim { return GSColorHex("#EEF2F7").opacity(0.3) }
                                    let r = store.record(for: GSDate.dayKey(year, m + 1, d))
                                    let h = store.dayHours(r)
                                    if h >= 10 { return GSTheme.color(for: store.themeKey) }
                                    if h >= 8 { return GSTheme.color(for: store.themeKey).opacity(0.68) }
                                    if h >= 6 { return GSTheme.color(for: store.themeKey).opacity(0.42) }
                                    if h > 0 { return GSTheme.color(for: store.themeKey).opacity(0.20) }
                                    return GSColorHex("#EEF2F7")
                                }()
                                RoundedRectangle(cornerRadius: 1.5).fill(color).frame(height: 6)
                            }
                        }
                    }
                }
            }
        }.padding(.horizontal, 18)
    }

    private func incomeYear(st: [String: Any], boardWork: Double, boardBonus: Double) -> some View {
        GSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("收入构成 · 全年").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                HStack(spacing: 14) {
                    GSDonutChart(values: [boardWork, boardBonus], colors: [GSColorHex("#1859D9"), GSColorHex("#12B76A")],
                                 centerTitle: GSNum(GSJSONNumber(st["pay"])), centerSubtitle: "实发工资")
                    VStack(alignment: .leading, spacing: 7) {
                        Text("工时工资  \(GSMoney(boardWork))").font(.system(size: 11)).foregroundColor(GSTextSecondary())
                        Text("补贴  +\(GSMoney(boardBonus))").font(.system(size: 11)).foregroundColor(GSSuccessColor())
                        Text("扣款  -\(GSMoney(GSJSONNumber(st["deduct"])))").font(.system(size: 11)).foregroundColor(GSDangerColor())
                    }
                }
            }
        }.padding(.horizontal, 18)
    }

    private func incomeDetail(st: [String: Any], months: [[String: Any]]) -> some View {
        let work = GSJSONNumber(st["workPay"]), bonus = GSJSONNumber(st["bonus"]), deduct = GSJSONNumber(st["deduct"])
        let allPay = GSJSONNumber(st["pay"]), allDays = GSJSONNumber(st["days"])
        let avgDayPay = allDays > 0 ? allPay / allDays : 0
        return VStack(spacing: 14) {
            GSCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("收入构成").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    GeometryReader { geo in
                        let total = max(work, 0) + max(bonus, 0)
                        HStack(spacing: 0) {
                            GSTheme.color(for: store.themeKey).frame(width: total > 0 ? geo.size.width * CGFloat(max(work,0)/total) : 0)
                            GSSuccessColor()
                        }
                    }
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    HStack {
                        Text("工时工资  \(GSMoney(work))").font(.system(size: 13)).foregroundColor(GSTextSecondary())
                        Spacer()
                        Text("日均工资  \(GSMoney(avgDayPay))").font(.system(size: 13)).foregroundColor(GSTextSecondary())
                    }
                    HStack {
                        Text("补贴  \(GSMoney(bonus))").font(.system(size: 13)).foregroundColor(GSTextSecondary())
                        Spacer()
                        Text("扣款  -\(GSMoney(deduct))").font(.system(size: 13)).foregroundColor(GSTextSecondary())
                    }
                    Text("实发工资  \(GSMoney(allPay))").font(.system(size: 14, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                }
            }.padding(.horizontal, 18)

            GSCard {
                VStack(alignment: .leading, spacing: 7) {
                    Text("月度明细").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    ForEach(0..<12, id: \.self) { i in
                        let m = i < months.count ? months[i] : [:]
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(i+1)月").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                                Spacer()
                                Text(GSMoney(GSJSONNumber(m["pay"]))).font(.system(size: 14, weight: .bold)).foregroundColor(GSTextPrimary())
                            }
                            Text("\(GSNum(GSJSONNumber(m["days"])))天 · \(GSNum(GSJSONNumber(m["hours"])))H · 正班 \(GSNum(GSJSONNumber(m["zb"])))H / 加班 \(GSNum(GSJSONNumber(m["jb"])))H / 周末 \(GSNum(GSJSONNumber(m["zm"])))H / 节假 \(GSNum(GSJSONNumber(m["jj"])))H")
                                .font(.system(size: 10)).foregroundColor(GSTextSecondary())
                            Text("补贴 +\(GSMoney(GSJSONNumber(m["bonus"])))  ·  扣款 -\(GSMoney(GSJSONNumber(m["deduct"])))  ·  净额 \(GSMoney(GSJSONNumber(m["bonus"]) - GSJSONNumber(m["deduct"])))")
                                .font(.system(size: 10)).foregroundColor(GSTextTertiary())
                        }
                        if i < 11 { Divider() }
                    }
                    HStack {
                        Text("全年合计").font(.system(size: 13, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                        Spacer()
                        Text(GSMoney(GSJSONNumber(st["pay"]))).font(.system(size: 16, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                    }
                    Text("\(GSNum(GSJSONNumber(st["days"])))天 · \(GSNum(GSJSONNumber(st["hours"])))H · 补贴 +\(GSMoney(GSJSONNumber(st["bonus"]))) · 扣款 -\(GSMoney(GSJSONNumber(st["deduct"])))")
                        .font(.system(size: 10)).foregroundColor(GSTextSecondary())
                }
            }.padding(.horizontal, 18)
        }
    }
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
