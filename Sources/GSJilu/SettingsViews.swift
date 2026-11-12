
import SwiftUI

struct SettingsPage: View {
    var page: String
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter

    var title: String {
        switch page {
        case "record": return "记录设置"
        case "salary": return "薪资与项目"
        case "classes": return "班次管理"
        case "period": return "考勤周期"
        default: return "软件设置"
        }
    }

    var body: some View {
        ScrollView {
            Group {
                switch page {
                case "record": RecordSettingsView()
                case "salary": ProjectsView(salary: true)
                case "classes": ClassesView()
                case "period": PeriodSettingsView()
                default: SoftwareSettingsView()
                }
            }
            .padding(GSPageMargin)
            Color.clear.frame(height: 30)
        }
        .background(GSPageBackground().ignoresSafeArea())
        .navigationBarTitle(title, displayMode: .inline)
    }
}

struct RecordSettingsView: View {
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var defClass: String = GSStore.shared.stringSetting("currentClass", default: "1")
    @State private var dayAllow: String = ""
    @State private var nightAllow: String = ""

    var body: some View {
        let s = store.settings
        let periodDay = { () -> Int in
            var d = GSJSONInt(s["period"]); if d < 1 || d > 29 { d = 26 }; return d
        }()
        return VStack(alignment: .leading, spacing: 14) {
            section("考勤计算周期")
            GSCard {
                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        ForEach(1...29, id: \.self) { d in
                            Button(periodTitle(d)) {
                                store.setSetting("period", d)
                                toast.show("已切换考勤周期")
                            }
                        }
                    } label: {
                        Text(periodTitle(periodDay))
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).frame(height: 46)
                            .background(GSSurfaceMuted())
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("原版 29 档：每月 1~29 号起算，命中自定义周期时优先用自定义区间")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                }
            }
            NavigationLink(destination: SettingsPage(page: "period")) {
                row("自定义考勤周期", "\(GSJSONArray(s["customPeriods"]).count) 段")
            }

            paydayCard
            section("每周工作日")
            GSCard {
                Picker("", selection: Binding(
                    get: { store.weekStart == 0 ? 1 : 0 },
                    set: { store.setSetting("weekStart", $0 == 1 ? 0 : 1); toast.show("已切换") }
                )) {
                    Text("周一").tag(0); Text("周日").tag(1)
                }.pickerStyle(.segmented)
            }
            GSCard {
                VStack(spacing: 8) {
                    toggle("夜班模式", "默认选中昨天日期", "nightMode", defaultOn: true)
                    toggle("日补扣自动记录", "记录工时时自动带入白班/夜班补助", "autoBonus", defaultOn: true)
                }
            }
            section("班次自动补助")
            GSCard {
                VStack(alignment: .leading, spacing: 8) {
                    allowanceRow("白班补助", $dayAllow, key: "dayAllowance", name: "白班补助")
                    allowanceRow("夜班补助", $nightAllow, key: "nightAllowance", name: "夜班补助")
                    Text("按班次名匹配：白班/早班加白班补助，中班/晚班/夜班加夜班补助；填 0 即关闭该类补助，并清除已有的自动补助。")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                }
            }
            annualCard
            section("打卡记录方式")
            GSCard {
                Picker("", selection: Binding(
                    get: { store.stringSetting("recordMode", default: "hour") == "time" ? 1 : 0 },
                    set: { store.setSetting("recordMode", $0 == 0 ? "hour" : "time") }
                )) {
                    Text("时长记录").tag(0); Text("时间记录").tag(1)
                }.pickerStyle(.segmented)
            }
            section("配置默认时长")
            defaultHoursCard
        }
        .onAppear {
            dayAllow = GSNum(max(0, store.numberSetting("dayAllowance", default: 10)))
            nightAllow = GSNum(max(0, store.numberSetting("nightAllowance", default: 20)))
        }
    }

    private func periodTitle(_ day: Int) -> String {
        if day == 1 { return "每月 1 号起算 · 1号 - 月底" }
        return "每月 \(day) 号起算 · \(day)号 - 下月\(day - 1)号"
    }

    private var paydayCard: some View {
        let payday: Int = {
            var p = store.intSetting("payday"); if p < 0 || p > 31 { p = 0 }; return p
        }()
        return VStack(alignment: .leading, spacing: 14) {
            section("发薪日")
            GSCard {
                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        Button("不设置") { store.setSetting("payday", 0); toast.show("已关闭发薪日标记") }
                        ForEach(1...31, id: \.self) { d in
                            Button("每月 \(d) 日") { store.setSetting("payday", d); toast.show("发薪日已更新") }
                        }
                    } label: {
                        Text(payday > 0 ? "每月 \(payday) 日" : "未设置")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).frame(height: 46)
                            .background(GSSurfaceMuted())
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("发薪日当天：日号变金色，左上角显示「薪」，底部金条常显；记录工时后工时数字也变金色。")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                }
            }
        }
    }

    private var annualCard: some View {
        let days = max(0, store.numberSetting("annualLeaveDays", default: 5))
        return VStack(alignment: .leading, spacing: 14) {
            section("年假")
            GSCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("年假额度").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                        Spacer()
                        Text("\(GSNum(days)) 天").font(.system(size: 16, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                    }
                    Slider(value: Binding(
                        get: { days },
                        set: { v in
                            let r = (v * 2).rounded() / 2
                            store.setSetting("annualLeaveDays", r)
                        }
                    ), in: 0...30)
                    .tint(GSTheme.color(for: store.themeKey))
                    Text("年假每年会变，直接拖动调整；薪假按 8H/天从年假余额里扣。")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                }
            }
        }
    }

    private var defaultHoursCard: some View {
        let classes = store.classes
        let def = store.defaultWork(for: defClass)
        let keys = ["zb","jb","zm","jj","rjgz"]
        let titles = ["正班","加班","周末","节假","日结"]
        let idx = classes.firstIndex(where: { ($0["id"] as? String) == defClass }) ?? 0
        return GSCard {
            VStack(spacing: 8) {
                if !classes.isEmpty {
                    Picker("", selection: Binding(
                        get: { idx },
                        set: { i in if i < classes.count { defClass = (classes[i]["id"] as? String) ?? defClass } }
                    )) {
                        ForEach(Array(classes.enumerated()), id: \.offset) { i, c in
                            Text(c["name"] as? String ?? "").tag(i)
                        }
                    }.pickerStyle(.segmented)
                }
                ForEach(0..<5, id: \.self) { i in
                    HStack {
                        Text(titles[i]).font(.system(size: 14)).foregroundColor(GSTextPrimary())
                        Spacer()
                        Text("\(GSNum(GSJSONNumber(def[keys[i]])))\(i == 4 ? "元" : "H")")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                        Stepper("", value: Binding(
                            get: { GSJSONNumber(def[keys[i]]) },
                            set: { store.setClassDefault(cid: defClass, key: keys[i], value: $0) }
                        ), in: 0...(i == 4 ? 100000 : 24), step: i == 4 ? 10 : 0.5)
                        .labelsHidden()
                    }
                    .frame(height: 48)
                }
            }
        }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.system(size: 13, weight: .semibold)).foregroundColor(GSTextTertiary())
    }

    private func row(_ title: String, _ value: String) -> some View {
        GSCard {
            HStack {
                Text(title).font(.system(size: 16)).foregroundColor(GSTextPrimary())
                Spacer()
                Text(value).font(.system(size: 14)).foregroundColor(GSTextSecondary())
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(GSTextSecondary())
            }
        }
    }

    private func toggle(_ title: String, _ sub: String, _ key: String, defaultOn: Bool) -> some View {
        Toggle(isOn: Binding(
            get: { store.boolSetting(key, default: defaultOn) },
            set: { store.setSetting(key, $0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .regular)).foregroundColor(GSTextPrimary())
                Text(sub).font(.system(size: 11)).foregroundColor(GSTextSecondary())
            }
        }
        .tint(GSTheme.color(for: store.themeKey))
    }

    private func allowanceRow(_ title: String, _ text: Binding<String>, key: String, name: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14)).foregroundColor(GSTextPrimary())
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GSTheme.color(for: store.themeKey))
                .frame(width: 100, height: 36)
                .onChange(of: text.wrappedValue) { v in
                    store.setSetting(key, max(0, Double(v) ?? 0))
                }
                .onChange(of: text.wrappedValue) { _ in }
        }
        .onDisappear {
            if (Double(text.wrappedValue) ?? 0) <= 0 {
                let removed = store.removeAutoAllowance(named: name)
                if removed > 0 { toast.show("已关闭\(name)，并清除 \(removed) 条自动补助") }
            }
        }
    }
}

struct SoftwareSettingsView: View {
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var reminderDate = Date()
    @State private var showTheme = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("记录提醒")
            GSCard {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { store.boolSetting("reminderEnabled") },
                        set: { on in
                            store.setSetting("reminderEnabled", on)
                            if on { GSReminder.requestAndSync() } else { GSReminder.syncFromSettings() }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("每天提醒").font(.system(size: 14)).foregroundColor(GSTextPrimary())
                            Text("到点提醒补记当天工时").font(.system(size: 11)).foregroundColor(GSTextSecondary())
                        }
                    }.tint(GSTheme.color(for: store.themeKey))
                    Text("提醒时间").font(.system(size: 13, weight: .medium)).foregroundColor(GSTextStrong())
                    DatePicker("", selection: $reminderDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .onChange(of: reminderDate) { d in
                            let c = GSDate.gregorian.dateComponents([.hour, .minute], from: d)
                            store.setSetting("reminderHour", c.hour ?? 21)
                            store.setSetting("reminderMinute", c.minute ?? 0)
                            GSReminder.syncFromSettings()
                        }
                    Text("关闭开关会取消本地通知；通知只在系统本地触发，不上传数据。请允许通知权限。")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                }
            }
            section("日历与班次")
            GSCard {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: Binding(
                        get: { store.weekStart == 0 ? 1 : 0 },
                        set: { store.setSetting("weekStart", $0 == 1 ? 0 : 1); toast.show("已切换") }
                    )) { Text("周一").tag(0); Text("周日").tag(1) }.pickerStyle(.segmented)
                    Text("班次标记").font(.system(size: 12, weight: .medium)).foregroundColor(GSTextSecondary())
                    let titles = ["图标", "文本", "不显示"]
                    let vals = ["icon", "text", "hide"]
                    let cur = store.stringSetting("classDisplay", default: "icon")
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Button(titles[i]) {
                                store.setSetting("classDisplay", vals[i])
                                toast.show("日历班次标记已更新")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(cur == vals[i] ? .white : GSTextSecondary())
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(cur == vals[i] ? GSTheme.color(for: store.themeKey) : GSSurfaceMuted())
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                    }
                    Text("图标：太阳/月亮；文本：白班/夜班；不显示：只留日期。选中项会填主题色。")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                }
            }
            section("界面细节")
            sliderCard(title: "卡片圆角", value: store.cardRadius, range: 8...30, hint: "影响所有白色卡片；拖动后立即生效。") { store.setSetting("cardRadius", $0) }
            GSCard {
                VStack(spacing: 8) {
                    uiToggle("卡片阴影", "关闭后页面更扁平", "cardShadow", true)
                    uiToggle("界面动画", "关闭后列表直接显示", "animations", true)
                    uiToggle("日历农历", "关闭后日期下方更简洁", "showLunar", true)
                }
            }
            sliderCard(title: "顶部色块圆角", value: store.headerRadius, range: 0...40, hint: "只影响顶部颜色块的下方两个角；0 为直角。") { store.setSetting("headerRadius", $0) }
            GSCard(padding: 0) {
                VStack(spacing: 0) {
                    Button { showTheme = true } label: {
                        HStack {
                            Text("主题色彩").font(.system(size: 16)).foregroundColor(GSTextPrimary())
                            Spacer()
                            Text(GSTheme.name(for: store.themeKey)).font(.system(size: 14)).foregroundColor(GSTextSecondary())
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                        }
                        .padding(.horizontal, 16).frame(height: 54)
                    }
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("关于").font(.system(size: 16)).foregroundColor(GSTextPrimary())
                        Spacer()
                        Text("工时记录 \(GSAppInfo.version)").font(.system(size: 14)).foregroundColor(GSTextSecondary())
                    }
                    .padding(.horizontal, 16).frame(height: 54)
                }
            }
            Text("数据只存在本机；登录、VIP、广告、云同步不包含")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(GSTextTertiary())
        }
        .onAppear {
            var c = DateComponents()
            c.hour = store.intSetting("reminderHour", default: 21)
            c.minute = store.intSetting("reminderMinute")
            reminderDate = GSDate.gregorian.date(from: c) ?? Date()
        }
        .confirmationDialog("主题色彩", isPresented: $showTheme, titleVisibility: .visible) {
            ForEach(Array(zip(GSTheme.keys, GSTheme.names)), id: \.0) { key, name in
                Button(name) {
                    store.setSetting("theme", key)
                    toast.show("已切换主题")
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("切换后会自动刷新界面")
        }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.system(size: 13, weight: .semibold)).foregroundColor(GSTextTertiary())
    }

    private func sliderCard(title: String, value: CGFloat, range: ClosedRange<Double>, hint: String, onChange: @escaping (Double) -> Void) -> some View {
        GSCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                    Spacer()
                    Text(String(format: "%.0f pt", value)).font(.system(size: 14, weight: .semibold)).foregroundColor(GSTheme.color(for: store.themeKey))
                }
                Slider(value: Binding(get: { Double(value) }, set: { onChange($0.rounded()) }), in: range)
                    .tint(GSTheme.color(for: store.themeKey))
                Text(hint).font(.system(size: 11)).foregroundColor(GSTextSecondary())
            }
        }
    }

    private func uiToggle(_ title: String, _ sub: String, _ key: String, _ def: Bool) -> some View {
        Toggle(isOn: Binding(
            get: { store.boolSetting(key, default: def) },
            set: { store.setSetting(key, $0); toast.show($0 ? "已开启" : "已关闭") }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(GSTextPrimary())
                Text(sub).font(.system(size: 11)).foregroundColor(GSTextSecondary())
            }
        }.tint(GSTheme.color(for: store.themeKey))
    }
}

struct ProjectsView: View {

    var salary: Bool
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var editIndex: Int? = nil
    @State private var showEdit = false

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(store.projects.enumerated()), id: \.offset) { i, p in
                let rates = GSJSONDict(p["rates"])
                let current = store.stringSetting("projectId", default: "default")
                let on = current == (p["id"] as? String)
                GSCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p["name"] as? String ?? "项目").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                                Text("底薪 ¥\(GSNum(GSJSONNumber(p["base"])))").font(.system(size: 11)).foregroundColor(GSTextSecondary())
                            }
                            Spacer()
                            Button("编辑") { editIndex = i; showEdit = true }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(GSTheme.color(for: store.themeKey))
                                .frame(width: 52, height: 30)
                                .background(GSTheme.softColor(for: store.themeKey))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        HStack {
                            Text("正班 ¥\(GSNum(GSJSONNumber(rates["zb"])))/h").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                            Spacer()
                            Text("加班 ¥\(GSNum(GSJSONNumber(rates["jb"])))/h").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                        }
                        HStack {
                            Text("周末 ¥\(GSNum(GSJSONNumber(rates["zm"])))/h").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                            Spacer()
                            Text("节假 ¥\(GSNum(GSJSONNumber(rates["jj"])))/h").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                        }
                        if salary {
                            Button(on ? "当前项目" : "设为当前") {
                                if !on, let id = p["id"] as? String {
                                    store.setSetting("projectId", id)
                                    toast.show("已切换项目")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(GSTheme.color(for: store.themeKey))
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(on ? GSTheme.softColor(for: store.themeKey) : GSSurfaceMuted())
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .disabled(on)
                        }
                    }
                }
            }
            Button("+ 新增项目") { editIndex = -1; showEdit = true }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(GSTheme.color(for: store.themeKey))
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(GSTheme.softColor(for: store.themeKey))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .fullScreenCover(isPresented: $showEdit) {
            NavigationView {
                ProjectEditView(index: editIndex ?? -1) { showEdit = false }
                    .environmentObject(store)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

struct ProjectEditView: View {
    var index: Int
    var onClose: () -> Void
    @EnvironmentObject var store: GSStore
    @State private var name = "新项目"
    @State private var base = "0"
    @State private var zb = "0"
    @State private var jb = "0"
    @State private var zm = "0"
    @State private var jj = "0"
    @State private var mode = "dxjs"
    @State private var pid = UUID().uuidString

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GSCard(padding: 8) {
                    VStack(spacing: 0) {
                        field("项目名称", $name, .default)
                        field("底薪", $base, .decimalPad)
                        field("正班时薪", $zb, .decimalPad)
                        field("加班时薪", $jb, .decimalPad)
                        field("周末时薪", $zm, .decimalPad)
                        field("节假时薪", $jj, .decimalPad)
                    }
                }
                Text("底薪和四类时薪只在本项目生效；修改后，已记录工时的工资会按新费率重新计算。")
                    .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                Button("保存项目") { save() }
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(GSTheme.color(for: store.themeKey))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(GSPageMargin)
        }
        .background(GSPageBackground().ignoresSafeArea())
        .navigationBarTitle(index >= 0 ? "编辑项目" : "新增项目", displayMode: .inline)
        .navigationBarItems(leading: Button("取消") { onClose() }, trailing: Button("保存") { save() })
        .onAppear {
            let projects = store.projects
            if index >= 0, index < projects.count {
                let p = projects[index]
                name = (p["name"] as? String) ?? "新项目"
                base = GSNum(GSJSONNumber(p["base"]))
                let r = GSJSONDict(p["rates"])
                zb = GSNum(GSJSONNumber(r["zb"])); jb = GSNum(GSJSONNumber(r["jb"]))
                zm = GSNum(GSJSONNumber(r["zm"])); jj = GSNum(GSJSONNumber(r["jj"]))
                mode = (p["mode"] as? String) ?? "dxjs"
                pid = (p["id"] as? String) ?? pid
            }
        }
    }

    private func field(_ title: String, _ text: Binding<String>, _ kb: UIKeyboardType) -> some View {
        HStack {
            Text(title).font(.system(size: 14)).foregroundColor(GSTextStrong())
            TextField("", text: text).keyboardType(kb).multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
        }.frame(height: 44).padding(.horizontal, 10)
    }

    private func save() {
        let n = name.isEmpty ? "新项目" : name
        let np: [String: Any] = [
            "id": pid, "name": n, "mode": mode,
            "base": Double(base) ?? 0,
            "rates": ["zb": Double(zb) ?? 0, "jb": Double(jb) ?? 0, "zm": Double(zm) ?? 0, "jj": Double(jj) ?? 0]
        ]
        var projects = store.projects
        if index >= 0, index < projects.count { projects[index] = np }
        else { projects.append(np) }
        store.setProjects(projects)
        if store.settings["projectId"] == nil { store.setSetting("projectId", pid) }
        onClose()
    }
}

struct ClassesView: View {
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var editName = ""
    @State private var editIndex: Int?
    @State private var showEdit = false

    var body: some View {
        let now = Date()
        let year = GSDate.gregorian.component(.year, from: now)
        let month = GSDate.gregorian.component(.month, from: now)
        let dim = GSDate.daysInMonth(year: year, month: month)
        let current = store.stringSetting("currentClass", default: "")
        return VStack(spacing: 14) {
            ForEach(Array(store.classes.enumerated()), id: \.offset) { i, c in
                let def = store.defaultWork(for: c["id"] as? String)
                let counts = monthCounts(cid: c["id"] as? String, year: year, month: month, dim: dim)
                let planned = counts.planned
                let recorded = counts.recorded
                let isDefault = current == (c["id"] as? String)
                GSCard {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 10) {
                            Circle().fill(GSColorHex((c["color"] as? String) ?? "#FCB819")).frame(width: 12, height: 12)
                            Text(c["name"] as? String ?? "").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                            Spacer()
                            Button("编辑") {
                                editIndex = i
                                editName = (c["name"] as? String) ?? "新班次"
                                showEdit = true
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(GSTheme.color(for: store.themeKey))
                            .frame(width: 48, height: 30)
                            .background(GSTheme.softColor(for: store.themeKey))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        Text("默认 正班 \(GSNum(GSJSONNumber(def["zb"])))H · 加班 \(GSNum(GSJSONNumber(def["jb"])))H · 周末 \(GSNum(GSJSONNumber(def["zm"])))H · 节假 \(GSNum(GSJSONNumber(def["jj"])))H")
                            .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                        Text("本月排班 \(planned) 天 · 记录 \(recorded) 天\(isDefault ? " · 当前默认" : "")")
                            .font(.system(size: 11)).foregroundColor(isDefault ? GSTheme.color(for: store.themeKey) : GSTextTertiary())
                        HStack(spacing: 8) {
                            Button(isDefault ? "当前默认" : "设为默认") {
                                if !isDefault, let id = c["id"] as? String {
                                    store.setSetting("currentClass", id)
                                    toast.show("已设为默认班次")
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isDefault ? GSTextTertiary() : GSTheme.color(for: store.themeKey))
                            .frame(maxWidth: .infinity).frame(height: 32)
                            .background(isDefault ? GSSurfaceMuted() : GSTheme.softColor(for: store.themeKey))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .disabled(isDefault)
                            NavigationLink(destination: SettingsPage(page: "record")) {
                                Text("调默认工时")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(GSTextSecondary())
                                    .frame(maxWidth: .infinity).frame(height: 32)
                                    .background(GSSurfaceMuted())
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                if let id = c["id"] as? String { store.setSetting("currentClass", id) }
                            })
                        }
                    }
                }
            }
            Button("+ 新增班次") {
                editIndex = -1
                editName = "新班次"
                showEdit = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(GSTheme.color(for: store.themeKey))
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(GSTheme.softColor(for: store.themeKey))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .textFieldAlert(isPresented: $showEdit, title: (editIndex ?? -1) >= 0 ? "编辑班次" : "新增班次", placeholder: "班次名称", text: $editName, onOK: saveClass)
    }

    private func monthCounts(cid: String?, year: Int, month: Int, dim: Int) -> (planned: Int, recorded: Int) {
        var planned = 0, recorded = 0
        for day in 1...dim {
            let key = GSDate.dayKey(year, month, day)
            if store.plan(for: key) == cid { planned += 1 }
            if let r = store.record(for: key), (r["classId"] as? String) == cid { recorded += 1 }
        }
        return (planned, recorded)
    }

    private func saveClass() {
        let colors = ["#FCB819", "#33A0FF", "#FF9900", "#224799", "#067647", "#6941C6"]
        var classes = store.classes
        let name = editName.isEmpty ? "新班次" : editName
        if let idx = editIndex, idx >= 0, idx < classes.count {
            var nc = classes[idx]
            nc["name"] = name
            classes[idx] = nc
        } else {
            let id = UUID().uuidString
            let color = colors[classes.count % colors.count]
            classes.append(["id": id, "name": name, "color": color])
            store.setClassDefault(cid: id, key: "zb", value: 8)
            store.setClassDefault(cid: id, key: "jb", value: 2)
            store.setClassDefault(cid: id, key: "zm", value: 10)
            store.setClassDefault(cid: id, key: "jj", value: 10)
            store.setClassDefault(cid: id, key: "rjgz", value: 0)
        }
        store.setClasses(classes)
        toast.show("班次已保存")
    }
}

struct TextFieldAlert: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var placeholder: String
    @Binding var text: String
    var onOK: () -> Void
    func body(content: Content) -> some View {
        content.background(
            TextFieldAlertController(isPresented: $isPresented, title: title, placeholder: placeholder, text: $text, onOK: onOK)
        )
    }
}

extension View {
    func textFieldAlert(isPresented: Binding<Bool>, title: String, placeholder: String, text: Binding<String>, onOK: @escaping () -> Void) -> some View {
        modifier(TextFieldAlert(isPresented: isPresented, title: title, placeholder: placeholder, text: text, onOK: onOK))
    }
}

struct TextFieldAlertController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var title: String
    var placeholder: String
    @Binding var text: String
    var onOK: () -> Void
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }
        let a = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        a.addTextField { tf in tf.placeholder = placeholder; tf.text = text }
        a.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in isPresented = false })
        a.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            text = a.textFields?.first?.text ?? text
            onOK()
            isPresented = false
        })
        DispatchQueue.main.async { uiViewController.present(a, animated: true) }
    }
}

struct PeriodSettingsView: View {
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(30 * 86400)

    var body: some View {
        let periods = (store.settings["customPeriods"] as? [[String: Any]]) ?? []
        return VStack(alignment: .leading, spacing: 14) {
            GSCard {
                VStack(alignment: .leading, spacing: 8) {
                    if periods.isEmpty {
                        Text("还没有自定义周期，默认按 26 号 - 下月 25 号").font(.system(size: 13)).foregroundColor(GSTextSecondary())
                    }
                    ForEach(Array(periods.enumerated()), id: \.offset) { i, p in
                        HStack {
                            Text("\((p["start"] as? String) ?? "") → \((p["end"] as? String) ?? "")")
                                .font(.system(size: 14, weight: .medium)).foregroundColor(GSTextPrimary())
                            Spacer()
                            Button("删除") {
                                var list = periods; list.remove(at: i); store.setCustomPeriods(list)
                            }.font(.system(size: 13, weight: .semibold)).foregroundColor(GSDangerColor())
                        }
                    }
                }
            }
            GSCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("新增一段").font(.system(size: 13, weight: .medium)).foregroundColor(GSTextSecondary())
                    DatePicker("开始", selection: $start, displayedComponents: .date).environment(\.locale, Locale(identifier: "zh_CN"))
                    DatePicker("结束", selection: $end, displayedComponents: .date).environment(\.locale, Locale(identifier: "zh_CN"))
                    Button("保存这一段") {
                        if start > end { toast.show("起止日期不对"); return }
                        var list = periods
                        list.append(["start": GSDate.key(from: start), "end": GSDate.key(from: end)])
                        store.setCustomPeriods(list)
                        toast.show("周期已添加")
                    }
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(GSTheme.color(for: store.themeKey))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            Text("命中自定义周期时优先用它的起止日；没命中再按默认周期")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(GSTextTertiary())
        }
    }
}

struct WageCalculatorView: View {
    @EnvironmentObject var store: GSStore
    @State private var fields = ["0","0","0","0","0","0","0"]

    var body: some View {
        let project = store.project(id: store.stringSetting("projectId", default: "default")) ?? [:]
        let rates = GSJSONDict(project["rates"])
        let titles = ["底薪（元）","正班时数","加班时数","周末时数","节假时数","补贴（元）","扣款（元）"]
        let base = Double(fields[0]) ?? 0, zb = Double(fields[1]) ?? 0, jb = Double(fields[2]) ?? 0
        let zm = Double(fields[3]) ?? 0, jj = Double(fields[4]) ?? 0, bonus = Double(fields[5]) ?? 0, deduct = Double(fields[6]) ?? 0
        let total = base + zb * GSJSONNumber(rates["zb"]) + jb * GSJSONNumber(rates["jb"]) + zm * GSJSONNumber(rates["zm"]) + jj * GSJSONNumber(rates["jj"]) + bonus - deduct
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("按「\((project["name"] as? String) ?? "当前项目")」费率试算")
                    .font(.system(size: 13)).foregroundColor(GSTextSecondary())
                GSCard(padding: 16) {
                    VStack(spacing: 0) {
                        ForEach(0..<titles.count, id: \.self) { i in
                            HStack {
                                Text(titles[i]).font(.system(size: 14)).foregroundColor(GSTextStrong())
                                TextField("0", text: $fields[i]).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .font(.system(size: 16, weight: .semibold)).foregroundColor(GSTextPrimary())
                            }.frame(height: 44)
                        }
                    }
                }
                GSCard {
                    VStack(spacing: 4) {
                        Text("预计工资").font(.system(size: 12, weight: .medium)).foregroundColor(GSTextSecondary())
                        Text(GSMoney(total)).font(.system(size: 34, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                        Text("底薪 \(GSMoney(base)) + 正班 \(GSMoney(zb * GSJSONNumber(rates["zb"]))) + 加班 \(GSMoney(jb * GSJSONNumber(rates["jb"]))) + 周末 \(GSMoney(zm * GSJSONNumber(rates["zm"]))) + 节假 \(GSMoney(jj * GSJSONNumber(rates["jj"]))) + 补贴 \(GSMoney(bonus)) - 扣款 \(GSMoney(deduct))")
                            .font(.system(size: 12)).foregroundColor(GSTextSecondary())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                Text("只做估算：按当前项目底薪/时薪计算，不含社保、个税和其他扣款规则。")
                    .font(.system(size: 11)).foregroundColor(GSTextSecondary())
            }
            .padding(GSPageMargin)
        }
        .background(GSPageBackground().ignoresSafeArea())
        .navigationBarTitle("工资计算器", displayMode: .inline)
        .onAppear {
            fields[0] = GSNum(GSJSONNumber(project["base"]))
        }
    }
}
