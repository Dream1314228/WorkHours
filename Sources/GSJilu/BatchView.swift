import SwiftUI

struct BatchView: View {
    var initialKey: String
    var onDone: (Int) -> Void
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @Environment(\.presentationMode) var presentation

    @State private var year: Int = 2026
    @State private var month: Int = 1
    @State private var selected: Set<String> = []
    @State private var hoursText = "8"
    @State private var otText = "0"
    @State private var bonusText = "0"
    @State private var night = false
    @State private var blankOnly = true
    @State private var skipWeekend = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                calendarCard
                hoursCard
                classCard
                optionsCard
                Button(action: apply) {
                    Text("应用批量工时").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(GSTheme.color(for: store.themeKey))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button(action: applyLeave) {
                    Text("批量设为休假").font(.system(size: 14, weight: .semibold)).foregroundColor(GSWarningColor())
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(GSColorHex("#FFFAEB"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button { if selected.isEmpty { alert("没有选日期", "先在日历上点几天。") } else { confirmClear = true } } label: {
                    Text("批量清空工时").font(.system(size: 14, weight: .semibold)).foregroundColor(GSDangerColor())
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(GSColorHex("#FEF3F2"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Color.clear.frame(height: 40)
            }
            .padding(GSPageMargin)
        }
        .background(GSPageBackground().ignoresSafeArea())
        .navigationBarTitle("批量设置工时", displayMode: .inline)
        .navigationBarItems(
            leading: Button("取消") { presentation.wrappedValue.dismiss() },
            trailing: Button("应用") { apply() }.font(.system(size: 17, weight: .semibold))
        )
        .onAppear {
            let d = GSDate.date(from: initialKey.isEmpty ? GSDate.todayKey() : initialKey)
            year = GSDate.gregorian.component(.year, from: d)
            month = GSDate.gregorian.component(.month, from: d)
            selected = [GSDate.key(from: d)]
            let current = store.stringSetting("currentClass", default: "1")
            if let name = store.classItem(id: current)?["name"] as? String {
                night = name.contains("夜") || name.contains("中") || name.contains("晚")
            }
        }
        .alert(isPresented: Binding(
            get: { showAlert || confirmClear },
            set: { if !$0 { showAlert = false; confirmClear = false } }
        )) {
            if confirmClear {
                return Alert(
                    title: Text("批量清空工时"),
                    message: Text("将删除选中的 \(selected.count) 天记录，不能撤销。"),
                    primaryButton: .destructive(Text("清空")) { doClear() },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            return Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("好")))
        }
    }

    private var calendarCard: some View {
        GSCard(padding: 12) {
            VStack(spacing: 10) {
                HStack {
                    Button { let c = GSDate.monthAdd(year: year, month: month, delta: -1); year = c.year; month = c.month } label: {
                        Image(systemName: "chevron.left").foregroundColor(GSTheme.color(for: store.themeKey)).frame(width: 30, height: 30)
                    }
                    Spacer()
                    Text("\(year)年\(month)月").font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button { let c = GSDate.monthAdd(year: year, month: month, delta: 1); year = c.year; month = c.month } label: {
                        Image(systemName: "chevron.right").foregroundColor(GSTheme.color(for: store.themeKey)).frame(width: 30, height: 30)
                    }
                }
                let weekStart = store.weekStart
                let names = weekStart == 0 ? ["日","一","二","三","四","五","六"] : ["一","二","三","四","五","六","日"]
                HStack(spacing: 2) {
                    ForEach(names, id: \.self) { n in
                        Text(n).font(.system(size: 11, weight: .medium)).foregroundColor(GSTextTertiary()).frame(maxWidth: .infinity)
                    }
                }
                calendarGrid
                HStack(spacing: 12) {
                    Button("全月") { selectWholeMonth() }.font(.system(size: 12, weight: .semibold)).foregroundColor(GSTheme.color(for: store.themeKey))
                    Button("清空") { selected.removeAll() }.font(.system(size: 12, weight: .semibold)).foregroundColor(GSTextSecondary())
                    Spacer()
                    Text("已选 \(selected.count) 天").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                }
            }
        }
    }

    private var calendarGrid: some View {
        let weekStart = store.weekStart
        let dim = GSDate.daysInMonth(year: year, month: month)
        var c = DateComponents(); c.year = year; c.month = month; c.day = 1
        let first = GSDate.gregorian.date(from: c) ?? Date()
        let weekday = GSDate.gregorian.component(.weekday, from: first)
        let offset = (weekday - 1 - weekStart + 7) % 7
        let today = GSDate.todayKey()
        return VStack(spacing: 2) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col - offset + 1
                        if index < 1 || index > dim {
                            Color.clear.frame(height: 36)
                        } else {
                            let key = GSDate.dayKey(year, month, index)
                            let on = selected.contains(key)
                            let recorded = store.record(for: key) != nil
                            Button {
                                if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
                                GSHaptic()
                            } label: {
                                ZStack(alignment: .bottom) {
                                    Text("\(index)")
                                        .font(.system(size: 13, weight: on ? .bold : .regular))
                                        .foregroundColor(on ? .white : GSTextPrimary())
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                    if recorded {
                                        Circle().fill(on ? Color.white : GSTheme.color(for: store.themeKey)).frame(width: 4, height: 4).padding(.bottom, 3)
                                    }
                                }
                                .background(on ? GSTheme.color(for: store.themeKey) : Color.clear)
                                .overlay(
                                    Circle().stroke(key == today && !on ? GSTheme.color(for: store.themeKey) : .clear, lineWidth: 1)
                                )
                                .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var hoursCard: some View {
        GSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("每天工时").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextStrong())
                HStack(spacing: 10) {
                    VStack(spacing: 4) {
                        TextField("8", text: $hoursText).keyboardType(.decimalPad).multilineTextAlignment(.center)
                            .font(.system(size: 22, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                            .frame(height: 54).background(GSColorHex("#F7F9FC")).clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("正常工时").font(.system(size: 11)).foregroundColor(GSTextSecondary())
                    }
                    VStack(spacing: 4) {
                        TextField("0", text: $otText).keyboardType(.decimalPad).multilineTextAlignment(.center)
                            .font(.system(size: 22, weight: .bold)).foregroundColor(GSColorHex("#D92D20"))
                            .frame(height: 54).background(GSColorHex("#F7F9FC")).clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("加班工时").font(.system(size: 11)).foregroundColor(GSTextSecondary())
                    }
                }
                Text("正常工时自动落到正班/周末/节假；加班统一记加班。识别周末和法定节假日。")
                    .font(.system(size: 11)).foregroundColor(GSTextSecondary())
            }
        }
    }

    private var classCard: some View {
        GSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("班制与补贴").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextStrong())
                Picker("", selection: $night) {
                    Text("白班").tag(false)
                    Text("夜班").tag(true)
                }.pickerStyle(.segmented)
                HStack {
                    Text("补贴（元/天）").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextStrong())
                    Spacer()
                    TextField("0", text: $bonusText).keyboardType(.decimalPad).multilineTextAlignment(.center)
                        .font(.system(size: 18, weight: .bold)).foregroundColor(GSColorHex("#12B76A"))
                        .frame(width: 100, height: 44).background(GSColorHex("#F7F9FC")).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text("白班自动匹配白/早班补助，夜班匹配中/晚/夜班补助；补贴按天叠加。")
                    .font(.system(size: 11)).foregroundColor(GSTextSecondary())
            }
        }
    }

    private var optionsCard: some View {
        GSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("选项").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextStrong())
                Toggle("只填充没有记录的日期", isOn: $blankOnly).tint(GSTheme.color(for: store.themeKey))
                Toggle("跳过周末", isOn: $skipWeekend).tint(GSTheme.color(for: store.themeKey))
            }
        }
    }

    private func alert(_ t: String, _ m: String) { alertTitle = t; alertMessage = m; showAlert = true }

    private func classIdForNight(_ night: Bool) -> String {
        let classes = store.classes
        if classes.isEmpty { return "1" }
        let keys = night ? ["夜", "晚", "中"] : ["白", "早"]
        for key in keys {
            for c in classes {
                if ((c["name"] as? String) ?? "").contains(key) { return (c["id"] as? String) ?? "1" }
            }
        }
        return (classes[night ? classes.count - 1 : 0]["id"] as? String) ?? "1"
    }

    private func putBonus(_ bonus: Double, in rec: inout [String: Any]) {
        var bt = (rec["bt"] as? [[String: Any]]) ?? []
        bt = bt.filter { ($0["name"] as? String) != "批量补贴" }
        if bonus > 0 {
            bt.append(["name": "批量补贴", "money": bonus, "note": "批量设置", "batchBonus": true])
        }
        rec["bt"] = bt
    }

    private func apply() {
        let normal = Double(hoursText) ?? 0
        let overtime = Double(otText) ?? 0
        let bonus = max(0, Double(bonusText) ?? 0)
        if normal < 0 || overtime < 0 || normal + overtime <= 0 {
            alert("工时不对", "正常工时和加班工时不能都是 0，也不能为负。"); return
        }
        if selected.isEmpty { alert("没有选日期", "先在日历上点几天。"); return }
        let classId = classIdForNight(night)
        var count = 0
        for key in selected.sorted() {
            let existing = store.record(for: key)
            if blankOnly && existing != nil { continue }
            let kind = GSDayKind(key)
            if skipWeekend && kind == "zm" { continue }
            var rec = existing ?? [:]
            rec["classId"] = classId
            rec["projectId"] = store.stringSetting("projectId", default: "default")
            rec["type"] = kind
            rec.removeValue(forKey: "leave")
            var work: [String: Any] = ["zb": 0, "jb": 0, "zm": 0, "jj": 0]
            let workKey = kind == "jj" ? "jj" : (kind == "zm" ? "zm" : "zb")
            work[workKey] = normal
            work["jb"] = overtime
            rec["work"] = work
            store.ensureAutoAllowance(&rec)
            putBonus(bonus, in: &rec)
            store.setRecord(rec, for: key)
            count += 1
        }
        if count == 0 { alert("没有可设置的日期", "选中的日期都被跳过或已有记录，检查一下筛选条件。"); return }
        toast.show("已批量设置 \(count) 天")
        GSReminder.syncFromSettings()
        onDone(count)
        presentation.wrappedValue.dismiss()
    }

    private func applyLeave() {
        if selected.isEmpty { alert("没有选日期", "先在日历上点几天。"); return }
        var leaveHours = Double(hoursText) ?? 0
        if leaveHours <= 0 { leaveHours = 8 }
        let classId = classIdForNight(night)
        var count = 0
        for key in selected.sorted() {
            let existing = store.record(for: key)
            if blankOnly && existing != nil { continue }
            let kind = GSDayKind(key)
            if skipWeekend && kind == "zm" { continue }
            var rec = existing ?? [:]
            rec["classId"] = classId
            rec["projectId"] = store.stringSetting("projectId", default: "default")
            rec["type"] = "xiu"
            rec["work"] = ["zb": 0, "jb": 0, "zm": 0, "jj": 0]
            rec["leave"] = ["type": "xiu", "hour": leaveHours, "rule": "hour", "multiple": 0]
            putBonus(0, in: &rec)
            store.setRecord(rec, for: key)
            count += 1
        }
        if count == 0 { alert("没有可设置的日期", "选中的日期都被跳过或已有记录，检查一下筛选条件。"); return }
        toast.show("已批量休假 \(count) 天")
        GSReminder.syncFromSettings()
        onDone(count)
        presentation.wrappedValue.dismiss()
    }

    private func doClear() {
        var count = 0
        for key in selected.sorted() {
            if store.record(for: key) != nil { store.removeRecord(for: key); count += 1 }
        }
        if count == 0 { alert("没有可清空的记录", "这些日期本来就没有记录。"); return }
        toast.show("已清空 \(count) 天工时")
        GSReminder.syncFromSettings()
        onDone(count)
        presentation.wrappedValue.dismiss()
    }

    private func selectWholeMonth() {
        let dim = GSDate.daysInMonth(year: year, month: month)
        for d in 1...dim { selected.insert(GSDate.dayKey(year, month, d)) }
    }
}
