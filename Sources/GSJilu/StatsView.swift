import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var year: Int = GSDate.gregorian.component(.year, from: Date())
    @State private var month: Int = GSDate.gregorian.component(.month, from: Date())
    @State private var showExtras = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let st = store.monthStats(year: year, month: month, usePeriod: true)
        return VStack(spacing: 0) {
            header(st)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    summary(st)
                    income(st)
                    hoursDonut(st)
                    daily(st)
                    extras(st)
                    Color.clear.frame(height: 20)
                }
            }
        }
        .fullScreenCover(isPresented: $showExtras) {
            ExtrasView(year: year, month: month) { showExtras = false }
                .environmentObject(store)
                .environmentObject(toast)
        }
    }

    private func header(_ st: [String: Any]) -> some View {
        let subtitle = String(format: "%d年 · %@", year, st["label"] as? String ?? "")
        return GSHeaderBlock(
            title: "统计",
            subtitle: subtitle,
            trailing: AnyView(
                HStack(spacing: 12) {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left").foregroundColor(.white)
                    }
                    .buttonStyle(GSPressButtonStyle())
                    Text(verbatim: String(format: "%d月", month))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right").foregroundColor(.white)
                    }
                    .buttonStyle(GSPressButtonStyle())
                }
            ),
            contentHeight: 100
        )
    }

    private func summary(_ st: [String: Any]) -> some View {
        let ot = GSJSONNumber(st["jb"]) + GSJSONNumber(st["zm"]) + GSJSONNumber(st["jj"])
        return GSCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(GSMoney(GSJSONNumber(st["pay"]))).font(.system(size: 31, weight: .bold)).foregroundColor(GSMoneyColor())
                    Text("本期合计").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                }
                HStack(spacing: 8) {
                    GSStatBox(value: GSNum(GSJSONNumber(st["hours"])), label: "总工时", color: GSTheme.color(for: store.themeKey))
                    GSStatBox(value: GSNum(GSJSONNumber(st["days"])), label: "出勤天数", color: GSTextPrimary())
                }
                HStack(spacing: 8) {
                    GSStatBox(value: GSMoney(GSJSONNumber(st["bonus"])), label: "补贴", color: GSSuccessColor())
                    GSStatBox(value: GSMoney(GSJSONNumber(st["deduct"])), label: "扣款", color: GSDangerColor())
                }
                HStack(spacing: 8) {
                    GSStatBox(value: String(format: "%.1f", GSJSONNumber(st["avg"])), label: "平均时薪", color: GSTheme.color(for: store.themeKey))
                    GSStatBox(value: "\(GSNum(ot))H", label: "加班/周末/节假", color: GSWarningColor())
                }
            }
        }.padding(.horizontal, 18)
    }

    private func income(_ st: [String: Any]) -> some View {
        let workPay = GSJSONNumber(st["pay"]) - GSJSONNumber(st["bonus"]) + GSJSONNumber(st["deduct"])
        return GSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("本期收入构成").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                HStack {
                    Text("工时工资  \(GSMoney(workPay))").font(.system(size: 13)).foregroundColor(GSTextSecondary())
                    Spacer()
                    Text("补贴  +\(GSMoney(GSJSONNumber(st["bonus"])))").font(.system(size: 13)).foregroundColor(GSSuccessColor())
                }
                HStack {
                    Text("扣款  -\(GSMoney(GSJSONNumber(st["deduct"])))").font(.system(size: 13)).foregroundColor(GSDangerColor())
                    Spacer()
                    Text("实发  \(GSMoney(GSJSONNumber(st["pay"])))").font(.system(size: 14, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                }
            }
        }.padding(.horizontal, 18)
    }

    private func hoursDonut(_ st: [String: Any]) -> some View {
        let keys = ["zb","jb","zm","jj"]
        let names = ["正班","加班","周末","节假"]
        let colors: [Color] = [GSColorHex("#1859D9"), GSColorHex("#D92D20"), GSColorHex("#12B76A"), GSColorHex("#F79009")]
        let vals = keys.map { GSJSONNumber(st[$0]) }
        let total = vals.reduce(0, +)
        return GSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("工时构成").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                HStack(spacing: 14) {
                    GSDonutChart(values: vals, colors: colors, centerTitle: "\(GSNum(total))H", centerSubtitle: "总工时")
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(0..<4, id: \.self) { i in
                            HStack(spacing: 6) {
                                Circle().fill(colors[i]).frame(width: 6, height: 6)
                                Text(names[i]).font(.system(size: 11)).foregroundColor(GSTextSecondary())
                                Spacer()
                                Text(String(format: "%@H  %.0f%%", GSNum(vals[i]), total > 0 ? vals[i] / total * 100 : 0))
                                    .font(.system(size: 11, weight: .semibold)).foregroundColor(GSTextPrimary())
                            }
                        }
                    }
                }
            }
        }.padding(.horizontal, 18)
    }

    private func daily(_ st: [String: Any]) -> some View {
        let keys = store.dailyKeys(year: year, month: month)
        return GSCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("每日明细").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    Spacer()
                    Button("复制报表") {
                        UIPasteboard.general.string = store.reportText(year: year, month: month)
                        toast.show("报表已复制")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(GSTheme.color(for: store.themeKey))
                    .buttonStyle(GSPressButtonStyle())
                }
                if keys.isEmpty {
                    Text("本月还没有记录").font(.system(size: 14)).foregroundColor(GSTextSecondary())
                } else {
                    ForEach(keys, id: \.self) { k in
                        if let r = store.record(for: k) {
                            HStack(spacing: 8) {
                                Text(String(k.dropFirst(5))).font(.system(size: 12, weight: .semibold)).foregroundColor(GSTextPrimary()).frame(width: 42, alignment: .leading)
                                let c = store.classItem(id: r["classId"] as? String)
                                let summary = store.daySummary(r)
                                let detail = (c?["name"] as? String).map { "\($0) · \(summary)" } ?? summary
                                Text(detail).font(.system(size: 11)).foregroundColor(GSTextSecondary()).lineLimit(2)
                                Spacer()
                                Text(GSMoney(store.dayPay(r))).font(.system(size: 12, weight: .bold)).foregroundColor(GSMoneyColor())
                            }
                        }
                    }
                }
            }
        }.padding(.horizontal, 18)
    }

    private func extras(_ st: [String: Any]) -> some View {
        let bs = store.extras(kind: "bonus", year: year, month: month)
        let ds = store.extras(kind: "deduct", year: year, month: month)
        let bsSum = bs.reduce(0.0) { $0 + GSJSONNumber($1["money"]) }
        let dsSum = ds.reduce(0.0) { $0 + GSJSONNumber($1["money"]) }
        var dailyGroups: [String: (name: String, count: Int, sum: Double)] = [:]
        for date in store.dailyKeys(year: year, month: month) {
            guard let rec = store.record(for: date) else { continue }
            for b in (rec["bt"] as? [[String: Any]]) ?? [] {
                let bm = GSJSONNumber(b["money"])
                if abs(bm) < 0.001 { continue }
                let name = (b["name"] as? String) ?? "补扣"
                let key = "\(name)|\(bm > 0 ? 1 : 0)"
                var g = dailyGroups[key] ?? (name, 0, 0)
                g.count += 1; g.sum += bm
                dailyGroups[key] = g
            }
        }
        return GSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("本期补扣明细").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    Spacer()
                    Button("管理") { showExtras = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GSTheme.color(for: store.themeKey))
                        .buttonStyle(GSPressButtonStyle())
                }
                Text(String(format: "月度补贴 +%@ · %ld 笔    月度扣款 -%@ · %ld 笔", GSMoney(bsSum), bs.count, GSMoney(dsSum), ds.count))
                    .font(.system(size: 12)).foregroundColor(GSTextSecondary())
                extraSection(title: "补贴", items: bs, isBonus: true)
                extraSection(title: "扣款", items: ds, isBonus: false)
                if !dailyGroups.isEmpty {
                    Text("每日补扣汇总").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary()).padding(.top, 4)
                    ForEach(dailyGroups.keys.sorted(), id: \.self) { key in
                        if let g = dailyGroups[key] {
                            HStack {
                                Text("每日 · \(g.name) ×\(g.count)").font(.system(size: 12)).foregroundColor(GSColorHex("#475467"))
                                Spacer()
                                Text("\(g.sum > 0 ? "+" : "-")\(GSMoney(abs(g.sum)))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(g.sum > 0 ? GSSuccessColor() : GSDangerColor())
                            }
                        }
                    }
                }
                Text("月度台账和每日补扣都会列出；上方本期总额已包含这两部分。")
                    .font(.system(size: 10)).foregroundColor(GSTextTertiary())
            }
        }.padding(.horizontal, 18)
    }

    private func extraSection(title: String, items: [[String: Any]], isBonus: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            let total = items.reduce(0.0) { $0 + GSJSONNumber($1["money"]) }
            Text("\(title) · \(items.count) 笔 · \(isBonus ? "+" : "-")\(GSMoney(total))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isBonus ? GSSuccessColor() : GSDangerColor())
            if items.isEmpty {
                Text(isBonus ? "本期没有补贴" : "本期没有扣款").font(.system(size: 12)).foregroundColor(GSTextTertiary())
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, b in
                    let name = (b["name"] as? String) ?? title
                    let note = (b["note"] as? String) ?? ""
                    let autoImport = GSJSONBool(b["auto"])
                    let source = autoImport ? "自动导入" : (note.isEmpty ? "手动添加" : note)
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name).font(.system(size: 13, weight: .semibold)).foregroundColor(GSTextStrong())
                            Text(source).font(.system(size: 10)).foregroundColor(GSTextTertiary())
                        }
                        Spacer()
                        Text("\(isBonus ? "+" : "-")\(GSMoney(GSJSONNumber(b["money"])))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isBonus ? GSSuccessColor() : GSDangerColor())
                    }
                }
            }
        }
    }

    private func changeMonth(_ delta: Int) {
        let c = GSDate.monthAdd(year: year, month: month, delta: delta)
        if GSMotionEnabled(store, reduceMotion: reduceMotion) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                year = c.year; month = c.month
            }
        } else {
            year = c.year; month = c.month
        }
        GSHaptic()
    }
}
