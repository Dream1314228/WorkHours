import SwiftUI
import UniformTypeIdentifiers

struct SettingsPage: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    @State private var editingProject: Project?
    @State private var isNewProject = false
    @State private var showPeriodEditor = false
    @State private var showWage = false
    @State private var showImporter = false
    @State private var backupURL: URL?
    @State private var confirmClear = false
    @State private var extraYear = Cal.year(Cal.todayKey())
    @State private var extraMonth = Cal.month(Cal.todayKey())
    @State private var showBonusAdd = false
    @State private var bonusKind = "bonus"
    @State private var bonusName = ""
    @State private var bonusMoney = 0.0

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var reminderSignature: String {
        "\(store.settings.reminderEnabled)-\(store.settings.reminderHour)-\(store.settings.reminderMinute)"
    }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                LazyVStack(spacing: 14) {
                    header
                    wageSection
                    bonusSection
                    leaveSection
                    periodSection
                    reminderSection
                    appearanceSection
                    dataSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $editingProject) { p in
            ProjectEditor(project: p, isNew: isNewProject, palette: palette)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPeriodEditor) {
            PeriodEditor(palette: palette)
                .environmentObject(store)
        }
        .sheet(isPresented: $showWage) {
            WagePage(palette: palette)
                .environmentObject(store)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert("加一笔\(bonusKind == "bonus" ? "补贴" : "扣款")", isPresented: $showBonusAdd) {
            TextField("名称", text: $bonusName)
            TextField("金额", value: $bonusMoney, format: .number)
                .keyboardType(.decimalPad)
            Button("加上") {
                store.addExtra(bonusKind, year: extraYear, month: extraMonth,
                               name: bonusName, money: bonusMoney)
                store.saveNow()
                ToastCenter.shared.show("已加上")
            }
            Button("取消", role: .cancel) {}
        }
        .alert("清除所有记录？", isPresented: $confirmClear) {
            Button("清除", role: .destructive) {
                store.clearAllRecords()
                ToastCenter.shared.show("记录已清空")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("工时、排班、补贴、扣款都会清掉。设置和项目保留。想留底就先导出备份。")
        }
        .onChange(of: reminderSignature) { _, _ in
            let s = store.settings
            Reminder.shared.sync(enabled: s.reminderEnabled, hour: s.reminderHour, minute: s.reminderMinute)
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("我的")
                    .font(.system(size: 26, weight: .bold))
                Text("数据只存在这台手机里，不联网")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("工时记录")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .glassCapsule(tint: palette.primary.opacity(0.08))
        }
        .padding(.horizontal, 2)
    }

    // MARK: 工资与项目

    private var wageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "工资与项目", subtitle: "时薪按项目分开算")
            ForEach(store.projects) { p in
                Button {
                    isNewProject = false
                    editingProject = p
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text("正班 \(Cal.num(p.rates.zb)) · 加班 \(Cal.num(p.rates.jb)) · 周末 \(Cal.num(p.rates.zm)) · 节假 \(Cal.num(p.rates.jj))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer()
                        if store.settings.projectId == p.id {
                            Text("默认")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 8)
                                .frame(height: 22)
                                .background(Capsule().fill(palette.primary.opacity(0.12)))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.99))
                Divider().opacity(0.35)
            }

            Button {
                isNewProject = true
                editingProject = Project(name: "新项目")
            } label: {
                Label("新增项目", systemImage: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(PressableStyle())

            Divider().opacity(0.35)

            Button {
                showWage = true
            } label: {
                HStack {
                    Label("工资计算器", systemImage: "function")
                        .font(.system(size: 14))
                    Spacer()
                    Text("试算一笔")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 36)
            }
            .buttonStyle(PressableStyle(scale: 0.99))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 补贴扣款

    private var bonusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "补贴与扣款", subtitle: "\(extraYear) 年 \(extraMonth) 月")
                Spacer()
                Button { stepExtra(-1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                Button { stepExtra(1) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            extraList(kind: "bonus", title: "补贴", color: Color.gsGreen)
            Divider().opacity(0.35)
            extraList(kind: "deduct", title: "扣款", color: Color.gsRed)

            HStack(spacing: 8) {
                Button {
                    bonusKind = "bonus"; bonusName = ""; bonusMoney = 0; showBonusAdd = true
                } label: {
                    Text("加补贴")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .glassCapsule(tint: palette.primary.opacity(0.06))
                }
                .buttonStyle(PressableStyle())

                Button {
                    bonusKind = "deduct"; bonusName = ""; bonusMoney = 0; showBonusAdd = true
                } label: {
                    Text("加扣款")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .glassCapsule()
                }
                .buttonStyle(PressableStyle())

                Button {
                    store.importLastMonth("bonus", year: extraYear, month: extraMonth)
                    store.importLastMonth("deduct", year: extraYear, month: extraMonth)
                    store.saveNow()
                    ToastCenter.shared.show("已导入上月")
                } label: {
                    Text("导入上月")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .glassCapsule()
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func extraList(kind: String, title: String, color: Color) -> some View {
        let items = store.extras(kind, year: extraYear, month: extraMonth)
        return VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
                Text(Cal.money(items.reduce(0) { $0 + $1.money }))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            if items.isEmpty {
                Text("这个月没有")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            } else {
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 13))
                        if !item.note.isEmpty {
                            Text(item.note)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Cal.money(item.money))
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                        Button {
                            store.deleteExtra(kind, year: extraYear, month: extraMonth, id: item.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 26)
                }
            }
        }
    }

    private func stepExtra(_ delta: Int) {
        let next = Cal.monthAdd(extraYear, extraMonth, delta)
        extraYear = next.year
        extraMonth = next.month
    }

    // MARK: 年假

    private var leaveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "年假", subtitle: "按 8 小时算一天")
            NumberRow(title: "年度额度", unit: "天",
                      value: $store.data.settings.annualLeaveDays,
                      palette: palette, range: 0...365)
            Divider().opacity(0.35)
            HStack {
                Text("今年已用")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Cal.num(store.annualLeaveUsed(year: Cal.year(Cal.todayKey())))) 天")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                Text("剩余 \(Cal.num(store.annualLeaveRemaining(year: Cal.year(Cal.todayKey())))) 天")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 考勤周期

    private var periodSection: some View {
        let range = store.periodRange(year: Cal.year(Cal.todayKey()), month: Cal.month(Cal.todayKey()))
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "考勤周期", subtitle: "默认规律 + 手动指定")

            HStack {
                Text("每月")
                    .font(.system(size: 14))
                Picker("起始日", selection: $store.data.settings.period) {
                    ForEach(1...29, id: \.self) { d in
                        Text("\(d) 号").tag(d)
                    }
                }
                .pickerStyle(.menu)
                .tint(palette.primary)
                Text("起算")
                    .font(.system(size: 14))
                Spacer()
            }

            Text(store.settings.period == 1
                 ? "当前：自然月，1 号到月底。"
                 : "当前：每月 \(store.settings.period) 号开始，到次月 \(store.settings.period - 1) 号结束。本月这一期是 \(range.start) 至 \(range.end)。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider().opacity(0.35)

            HStack {
                Text("手动指定的期")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showPeriodEditor = true
                } label: {
                    Label("加一期", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
            }

            let periods = store.settings.customPeriods.sorted { $0.start > $1.start }
            if periods.isEmpty {
                Text("没有手动期。排班每期不固定时，在这里直接填起止日期。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(periods) { p in
                    HStack {
                        Text("\(p.start) 至 \(p.end)")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                        Spacer()
                        Text("覆盖 \(String(p.start.prefix(7)))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Button {
                            store.data.settings.customPeriods.removeAll { $0.id == p.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 26)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 提醒

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "记账提醒")
            Toggle(isOn: $store.data.settings.reminderEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("每天提醒")
                        .font(.system(size: 15))
                    Text("到点弹一条通知，提醒补今天的工时")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(palette.primary)

            if store.settings.reminderEnabled {
                DatePicker("提醒时间", selection: reminderDate, displayedComponents: .hourAndMinute)
                    .font(.system(size: 14))
                    .tint(palette.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = store.settings.reminderHour
                c.minute = store.settings.reminderMinute
                return Cal.gregorian.date(from: c) ?? Date()
            },
            set: { d in
                let c = Cal.gregorian.dateComponents([.hour, .minute], from: d)
                store.data.settings.reminderHour = c.hour ?? 21
                store.data.settings.reminderMinute = c.minute ?? 0
            }
        )
    }

    // MARK: 外观

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "外观")

            HStack(spacing: 8) {
                ForEach(Theme.all, id: \.key) { t in
                    Button {
                        store.data.settings.theme = t.key
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Theme.of(t.key).primary)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    if store.settings.theme == t.key {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Theme.of(t.key).onPrimary)
                                    }
                                }
                            Text(t.name)
                                .font(.system(size: 9))
                                .foregroundStyle(store.settings.theme == t.key ? Color.primary : Color.secondary)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            Divider().opacity(0.35)

            VStack(spacing: 2) {
                HStack {
                    Text("卡片圆角")
                        .font(.system(size: 14))
                    Spacer()
                    Text(Cal.num(store.settings.cardRadius))
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $store.data.settings.cardRadius, in: 0...36, step: 1)
                    .tint(palette.primary)
            }

            VStack(spacing: 2) {
                HStack {
                    Text("顶部圆角")
                        .font(.system(size: 14))
                    Spacer()
                    Text(Cal.num(store.settings.headerRadius))
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $store.data.settings.headerRadius, in: 0...40, step: 1)
                    .tint(palette.primary)
            }

            Toggle("卡片阴影", isOn: $store.data.settings.cardShadow)
                .font(.system(size: 14))
                .tint(palette.primary)
            Toggle("界面动画", isOn: $store.data.settings.animations)
                .font(.system(size: 14))
                .tint(palette.primary)
            Toggle("日历显示农历", isOn: $store.data.settings.showLunar)
                .font(.system(size: 14))
                .tint(palette.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 数据

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "备份与还原", subtitle: "换手机前先导出")

            Button {
                exportBackup()
            } label: {
                HStack {
                    Label("导出备份", systemImage: "arrow.up.doc")
                        .font(.system(size: 14))
                    Spacer()
                    Text("JSON 文件")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 36)
            }
            .buttonStyle(PressableStyle(scale: 0.99))

            if let url = backupURL {
                ShareLink(item: url) {
                    HStack {
                        Label("分享刚导出的文件", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text(url.lastPathComponent)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(height: 34)
                }
            }

            Divider().opacity(0.35)

            Button {
                showImporter = true
            } label: {
                HStack {
                    Label("导入备份", systemImage: "arrow.down.doc")
                        .font(.system(size: 14))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 36)
            }
            .buttonStyle(PressableStyle(scale: 0.99))

            Divider().opacity(0.35)

            Button {
                confirmClear = true
            } label: {
                HStack {
                    Label("清除所有记录", systemImage: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.gsRed)
                    Spacer()
                }
                .frame(height: 36)
            }
            .buttonStyle(PressableStyle(scale: 0.99))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("工时记录 · SwiftUI 版 \(version)")
                .font(.system(size: 12, weight: .medium))
            Text("液态玻璃界面，iOS 26 起可用。数据存在 App 沙盒里的 gsjilu.json，卸载或清除会一起消失。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func exportBackup() {
        guard let data = store.backupData() else {
            ToastCenter.shared.show("导出失败")
            return
        }
        let name = "工时记录备份-\(Cal.todayKey()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            backupURL = url
            ToastCenter.shared.show("已生成，点下面分享")
        } catch {
            ToastCenter.shared.show("写入文件失败")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let raw = try Data(contentsOf: url)
                try store.importBackup(raw)
                backupURL = nil
                ToastCenter.shared.show("导入成功")
            } catch {
                ToastCenter.shared.show(error.localizedDescription)
            }
        case .failure:
            ToastCenter.shared.show("没选到文件")
        }
    }
}
