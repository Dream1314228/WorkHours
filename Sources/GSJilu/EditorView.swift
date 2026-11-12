import SwiftUI

struct EditorView: View {
    let date: String
    var onClose: () -> Void
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter

    @State private var draft: [String: Any] = [:]
    @State private var hadRecord = false
    @State private var note: String = ""
    @State private var settleText: String = ""
    @State private var workTexts: [String] = ["0","0","0","0"]
    @State private var showDelete = false

    private let typeKeys = ["zb", "zm", "jj", "xiu"]
    private let typeNames = ["正班", "周末", "节假", "休假"]
    private let workKeys = ["zb", "jb", "zm", "jj"]
    private let workNames = ["正班", "加班", "周末", "节假"]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 10) {
                    typeCard
                    classCard
                    projectCard
                    workCard
                    settleCard
                    leaveCard
                    btCard
                    noteCard
                    Color.clear.frame(height: 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
            }
            bottomBar
        }
        .background(GSPageBackground().ignoresSafeArea())
        .onAppear { setup() }
        .alert(isPresented: $showDelete) {
            Alert(
                title: Text("删除记录"),
                message: Text("删除这一天的全部工时？"),
                primaryButton: .destructive(Text("删除")) {
                    store.removeRecord(for: date)
                    GSReminder.syncFromSettings()
                    onClose()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var header: some View {
        let c = GSDate.components(from: date)
        return ZStack(alignment: .bottom) {
            LinearGradient(colors: [GSTheme.color(for: store.themeKey), GSTheme.darkColor(for: store.themeKey)], startPoint: .top, endPoint: .bottom)
            HStack {
                Text(verbatim: String(format: "%ld月%ld日 · %@", c.month, c.day, GSDate.weekdayName(date)))
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.12)).clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(height: GSSafeAreaTop() + 52)
        .clipShape(GSHeaderShape(radius: store.headerRadius))
        .ignoresSafeArea(edges: .top)
    }

    private var typeCard: some View {
        editorCard("当天类型") {
            Picker("", selection: typeBinding) {
                ForEach(0..<typeNames.count, id: \.self) { i in
                    Text(typeNames[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var typeBinding: Binding<Int> {
        Binding(
            get: {
                let t = (draft["type"] as? String) ?? "zb"
                return typeKeys.firstIndex(of: t) ?? 0
            },
            set: { i in
                draft["type"] = typeKeys[i]
                applyDefault()
            }
        )
    }

    private var classCard: some View {
        editorCard("班次") {
            HStack(spacing: 6) {
                ForEach(Array(store.classes.enumerated()), id: \.offset) { i, c in
                    let on = (c["id"] as? String) == (draft["classId"] as? String)
                    Button {
                        draft["classId"] = c["id"] as? String ?? "1"
                        applyDefault()
                    } label: {
                        Text(c["name"] as? String ?? "")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(on ? GSTheme.color(for: store.themeKey) : GSColorHex("#667085"))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(on ? GSTheme.softColor(for: store.themeKey) : GSColorHex("#F2F5FA"))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? GSTheme.color(for: store.themeKey) : .clear, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var projectCard: some View {
        editorCard("项目") {
            Menu {
                ForEach(Array(store.projects.enumerated()), id: \.offset) { _, p in
                    Button(p["name"] as? String ?? "") {
                        draft["projectId"] = p["id"] as? String ?? "default"
                        refreshWorkTexts()
                    }
                }
            } label: {
                HStack {
                    Text(store.project(id: draft["projectId"] as? String)?["name"] as? String ?? "项目")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(GSColorHex("#F5F7FA"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var workCard: some View {
        editorCard("工时 · 按项目时薪算") {
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { i in
                    let h = Double(workTexts[i]) ?? GSJSONNumber(GSJSONDict(draft["work"])[workKeys[i]])
                    let rate = store.rate(project: draft["projectId"] as? String, type: workKeys[i])
                    HStack(spacing: 5) {
                        Text(workNames[i]).font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary()).frame(width: 42, alignment: .leading)
                        Text("¥\(GSNum(rate))/h").font(.system(size: 10)).foregroundColor(GSColorHex("#5D6B82"))
                        Spacer()
                        TextField("0", text: Binding(
                            get: { workTexts.indices.contains(i) ? workTexts[i] : "0" },
                            set: { new in
                                var t = new
                                var v = Double(t) ?? 0
                                v = max(0, min(24, v))
                                if (Double(new) ?? 0) > 24 { t = "24" }
                                workTexts[i] = t
                                var w = GSJSONDict(draft["work"])
                                w[workKeys[i]] = v
                                draft["work"] = w
                            }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(GSTheme.color(for: store.themeKey))
                        .padding(.horizontal, 6)
                        .frame(width: 46, height: 32)
                        .background(GSColorHex("#F5F7FA"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("H").font(.system(size: 10)).foregroundColor(GSColorHex("#667085"))
                        Text(GSMoney(h * rate))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(i == 0 ? GSTextPrimary() : GSMoneyColor())
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var settleCard: some View {
        editorCard("日结 · 填了就不按工时算") {
            TextField("0（填了就不按工时算）", text: Binding(
                get: { settleText },
                set: { settleText = $0; draft["settle"] = Double($0) ?? 0 }
            ))
            .keyboardType(.decimalPad)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(GSColorHex("#F5F7FA"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var leaveCard: some View {
        let has = draft["leave"] is [String: Any]
        let leave = GSJSONDict(draft["leave"])
        let types = ["bing", "shi", "tiao", "xiu"]
        let typeNamesL = ["病假", "事假", "调休", "薪假"]
        let year = GSDate.components(from: date).year
        let total = store.annualLeaveTotalDays()
        let used = store.annualLeaveUsedDays(year: year)
        let remain = store.annualLeaveRemainingDays(year: year)
        let balance = total <= 0
            ? "\(year) 年年假未设置 · 去「记录设置」调整"
            : "\(year) 年年假：总额 \(GSNum(total)) 天 · 已用 \(GSNum(used)) 天 · 剩余 \(GSNum(remain)) 天"
        let hours = GSJSONNumber(leave["hour"])
        let mults: [Double] = [0, 0.5, 1, 1.5, 2, 3]
        let mi = mults.firstIndex(of: GSJSONNumber(leave["multiple"])) ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("休假").font(.system(size: 15, weight: .bold)).foregroundColor(GSTextPrimary())
                Text("按倍数算补贴/扣款").font(.system(size: 10)).foregroundColor(GSColorHex("#5D6B82"))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { has },
                    set: { on in
                        if on {
                            draft["leave"] = ["type": "xiu", "hour": 8, "rule": "hour", "multiple": 0]
                        } else {
                            draft.removeValue(forKey: "leave")
                        }
                    }
                )).labelsHidden().tint(GSTheme.color(for: store.themeKey))
            }
            Text(balance).font(.system(size: 10)).foregroundColor(GSColorHex("#5D6B82"))
            if has {
                Picker("", selection: Binding(
                    get: { types.firstIndex(of: (leave["type"] as? String) ?? "xiu") ?? 3 },
                    set: { i in
                        var lv = GSJSONDict(draft["leave"]); lv["type"] = types[i]; draft["leave"] = lv
                    }
                )) {
                    ForEach(0..<typeNamesL.count, id: \.self) { i in Text(typeNamesL[i]).tag(i) }
                }.pickerStyle(.segmented)

                HStack {
                    Text("时长").font(.system(size: 13, weight: .medium)).foregroundColor(GSColorHex("#667085"))
                    Spacer()
                    Text("\(GSNum(hours))H").font(.system(size: 13, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                    Stepper("", value: Binding(
                        get: { hours },
                        set: { v in
                            var lv = GSJSONDict(draft["leave"]); lv["hour"] = max(0, min(24, v)); draft["leave"] = lv
                        }
                    ), in: 0...24, step: 1).labelsHidden()
                }
                HStack {
                    Text("倍数").font(.system(size: 13, weight: .medium)).foregroundColor(GSColorHex("#667085"))
                    Picker("", selection: Binding(
                        get: { mi },
                        set: { i in
                            var lv = GSJSONDict(draft["leave"]); lv["multiple"] = mults[i]; draft["leave"] = lv
                        }
                    )) {
                        ForEach(0..<mults.count, id: \.self) { i in Text(GSNum(mults[i])).tag(i) }
                    }.pickerStyle(.segmented)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: store.cardRadius, style: .continuous))
    }

    private var btCard: some View {
        let bt = (draft["bt"] as? [[String: Any]]) ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("补扣").font(.system(size: 15, weight: .bold)).foregroundColor(GSTextPrimary())
            if bt.isEmpty {
                Text("还没有补扣").font(.system(size: 11)).foregroundColor(GSColorHex("#5D6B82"))
            }
            ForEach(Array(bt.enumerated()), id: \.offset) { i, b in
                HStack(spacing: 6) {
                    TextField("名称", text: Binding(
                        get: { (b["name"] as? String) ?? "" },
                        set: { v in var arr = bt; var item = arr[i]; item["name"] = v; arr[i] = item; draft["bt"] = arr }
                    ))
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .frame(height: 34)
                    .background(GSColorHex("#F5F7FA"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    TextField("金额", text: Binding(
                        get: {
                            let m = GSJSONNumber(b["money"])
                            return abs(m) > 0 ? GSNum(abs(m)) : ""
                        },
                        set: { v in
                            var arr = bt; var item = arr[i]
                            var sign = GSJSONNumber(item["sign"])
                            if sign == 0 { sign = GSJSONNumber(item["money"]) < 0 ? -1 : 1 }
                            item["money"] = sign * abs(Double(v) ?? 0)
                            arr[i] = item; draft["bt"] = arr
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .frame(width: 78, height: 34)
                    .background(GSColorHex("#F5F7FA"))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Button {
                        var arr = bt; arr.remove(at: i); draft["bt"] = arr
                    } label: {
                        Image(systemName: "trash").font(.system(size: 14)).foregroundColor(GSColorHex("#5D6B82"))
                    }
                }
            }
            HStack(spacing: 12) {
                Button("+ 补贴") { addBT(sign: 1) }.font(.system(size: 12, weight: .semibold)).foregroundColor(GSTheme.color(for: store.themeKey))
                Button("+ 扣款") { addBT(sign: -1) }.font(.system(size: 12, weight: .semibold)).foregroundColor(GSDangerColor())
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: store.cardRadius, style: .continuous))
    }

    private var noteCard: some View {
        editorCard("备注") {
            TextEditor(text: Binding(get: { note }, set: { note = $0; draft["note"] = $0 }))
                .frame(height: 76)
                .font(.system(size: 13))
                .padding(6)
                .background(GSColorHex("#F5F7FA"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("当天合计").font(.system(size: 12)).foregroundColor(GSColorHex("#5D6B82"))
                Text(GSMoney(store.dayPay(draft))).font(.system(size: 20, weight: .bold)).foregroundColor(GSMoneyColor())
            }
            Spacer()
            if hadRecord {
                Button("删除") { showDelete = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(GSDangerColor())
                    .frame(width: 82, height: 48)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(GSColorHex("#FFE0DF"), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Button("保存") { save() }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 130, height: 48)
                .background(GSTheme.color(for: store.themeKey))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.white)
    }

    private func editorCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(GSColorHex("#101828"))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: store.cardRadius, style: .continuous))
    }

    private func setup() {
        let base = store.record(for: date)
        hadRecord = base != nil
        var d = base ?? [:]
        if var w = d["work"] as? [String: Any] {
            for k in workKeys where w[k] == nil { w[k] = 0 }
            d["work"] = w
        } else {
            d["work"] = ["zb": 0, "jb": 0, "zm": 0, "jj": 0]
        }
        if let bt = d["bt"] as? [[String: Any]] {
            d["bt"] = bt
        } else { d["bt"] = [[String: Any]]() }
        if d["leave"] != nil && !(d["leave"] is [String: Any]) { d.removeValue(forKey: "leave") }
        if !(d["note"] is String) { d["note"] = "" }
        if !(d["classId"] is String) { d["classId"] = store.stringSetting("currentClass", default: "1") }
        if !hadRecord {
            let plan = store.plan(for: date)
            if !plan.isEmpty, store.classItem(id: plan) != nil { d["classId"] = plan }
            if !(d["type"] is String) { d["type"] = GSDayKind(date) }
        }
        if !(d["projectId"] is String) { d["projectId"] = store.stringSetting("projectId", default: "default") }
        if !(d["type"] is String) { d["type"] = inferType(d) }
        if !(d["settle"] is NSNumber || d["settle"] is Double || d["settle"] is Int) { d["settle"] = 0 }
        draft = d
        if !hadRecord { applyDefault() }
        else { store.ensureAutoAllowance(&draft) }
        note = (draft["note"] as? String) ?? ""
        let settle = GSJSONNumber(draft["settle"])
        settleText = settle > 0 ? GSNum(settle) : ""
        refreshWorkTexts()
    }

    private func inferType(_ rec: [String: Any]) -> String {
        let w = GSJSONDict(rec["work"])
        if rec["leave"] is [String: Any] { return "xiu" }
        if GSJSONNumber(w["zm"]) > 0 { return "zm" }
        if GSJSONNumber(w["jj"]) > 0 { return "jj" }
        return "zb"
    }

    private func applyDefault() {
        if var bt = draft["bt"] as? [[String: Any]] {
            bt = bt.filter { !GSJSONBool($0["autoAllowance"]) }
            draft["bt"] = bt
        }
        let def = store.defaultWork(for: draft["classId"] as? String)
        draft["work"] = ["zb": 0, "jb": 0, "zm": 0, "jj": 0]
        draft.removeValue(forKey: "leave")
        draft["settle"] = 0
        let type = draft["type"] as? String ?? "zb"
        var work = GSJSONDict(draft["work"])
        if type == "zb" {
            work["zb"] = GSJSONNumber(def["zb"]); work["jb"] = GSJSONNumber(def["jb"])
        } else if type == "zm" {
            work["zm"] = GSJSONNumber(def["zm"])
        } else if type == "jj" {
            work["jj"] = GSJSONNumber(def["jj"])
        } else if type == "xiu" {
            draft["leave"] = ["type": "xiu", "hour": 8, "rule": "hour", "multiple": 0]
        }
        draft["work"] = work
        if GSJSONNumber(def["rjgz"]) > 0 { draft["settle"] = def["rjgz"] }
        store.ensureAutoAllowance(&draft)
        let settle = GSJSONNumber(draft["settle"])
        settleText = settle > 0 ? GSNum(settle) : ""
        refreshWorkTexts()
    }

    private func refreshWorkTexts() {
        let w = GSJSONDict(draft["work"])
        workTexts = workKeys.map { GSNum(GSJSONNumber(w[$0])) }
    }

    private func addBT(sign: Int) {
        var bt = (draft["bt"] as? [[String: Any]]) ?? []
        bt.append(["name": sign > 0 ? "补贴" : "扣款", "money": 0, "sign": sign])
        draft["bt"] = bt
    }

    private func save() {
        var w = GSJSONDict(draft["work"])
        for k in workKeys {
            let v = max(0, min(24, GSJSONNumber(w[k])))
            w[k] = v
        }
        draft["work"] = w
        draft["settle"] = max(0, GSJSONNumber(draft["settle"]))
        store.ensureAutoAllowance(&draft)
        var bt: [[String: Any]] = []
        for b in (draft["bt"] as? [[String: Any]]) ?? [] {
            let n = (b["name"] as? String) ?? ""
            let m = GSJSONNumber(b["money"])
            if !n.isEmpty || abs(m) > 0.001 { bt.append(b) }
        }
        draft["bt"] = bt
        if let leave = draft["leave"] as? [String: Any], GSJSONNumber(leave["hour"]) <= 0 {
            draft.removeValue(forKey: "leave")
        }
        var n = note
        if n == "(null)" { n = "" }
        draft["note"] = n
        var has = false
        for k in workKeys { if GSJSONNumber(w[k]) > 0 { has = true } }
        if draft["leave"] is [String: Any] { has = true }
        if !bt.isEmpty { has = true }
        if GSJSONNumber(draft["settle"]) > 0 { has = true }
        if !n.isEmpty { has = true }
        if has { store.setRecord(draft, for: date) }
        else { store.removeRecord(for: date) }
        GSReminder.syncFromSettings()
        onClose()
    }
}
