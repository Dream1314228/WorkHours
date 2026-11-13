import SwiftUI

// MARK: - 项目编辑

struct ProjectEditor: View {
    var project: Project
    var isNew: Bool
    var palette: Palette

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Project
    @State private var confirmDelete = false

    init(project: Project, isNew: Bool, palette: Palette) {
        self.project = project
        self.isNew = isNew
        self.palette = palette
        _draft = State(initialValue: project)
    }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "项目名")
                        TextField("项目名", text: $draft.name)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(height: 40)
                        Divider().opacity(0.35)
                        HStack {
                            Text("计薪方式")
                                .font(.system(size: 14))
                            Spacer()
                            Picker("计薪方式", selection: $draft.mode) {
                                Text("底薪 + 时薪").tag("dxjs")
                                Text("固定单价").tag("gddx")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 190)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: store.settings.cardRadius)

                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle(title: "底薪", subtitle: "只影响工资计算器")
                        NumberRow(title: "月薪", unit: "元", value: $draft.base, palette: palette, range: 0...999999)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: store.settings.cardRadius)

                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle(title: "时薪", subtitle: "元 / 小时")
                        NumberRow(title: "正班", unit: "元", value: $draft.rates.zb, palette: palette, range: 0...9999)
                        NumberRow(title: "加班", unit: "元", value: $draft.rates.jb, palette: palette, range: 0...9999)
                        NumberRow(title: "周末", unit: "元", value: $draft.rates.zm, palette: palette, range: 0...9999)
                        NumberRow(title: "节假", unit: "元", value: $draft.rates.jj, palette: palette, range: 0...9999)
                        Text("加班一般是正班的 1.5 倍，周末 2 倍，法定节假日 3 倍。按你厂里的算法填就行。")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gsSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: store.settings.cardRadius)

                    if store.settings.projectId != draft.id {
                        Button {
                            store.data.settings.projectId = draft.id
                            ToastCenter.shared.show("已设为默认项目")
                        } label: {
                            Text("设为默认项目")
                        }
                        .buttonStyle(GlassActionButtonStyle(palette: palette, height: 46))
                    }

                    if !isNew && store.projects.count > 1 {
                        Button {
                            confirmDelete = true
                        } label: {
                            Text("删除这个项目")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.gsRed)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                save()
            } label: {
                Text("保存项目")
            }
            .buttonStyle(GlassActionButtonStyle(palette: palette, prominent: true, height: 48))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ledger.paper))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
            .padding(.horizontal, 12)
        }
        .alert("删除这个项目？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                store.data.projects.removeAll { $0.id == draft.id }
                if store.settings.projectId == draft.id {
                    store.data.settings.projectId = store.projects.first?.id ?? "default"
                }
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("以前记在这个项目下的工时不会删，工资按项目时薪重算。")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isNew ? "新增项目" : "编辑项目")
                    .font(.system(size: 24, weight: .bold))
                Text(draft.name.isEmpty ? "未命名" : draft.name)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .contentShape(Circle().inset(by: -5))
                    .background(Circle().fill(Color.primary.opacity(0.08)))
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func save() {
        var p = draft
        if p.name.trimmingCharacters(in: .whitespaces).isEmpty {
            p.name = "未命名项目"
        }
        if isNew {
            store.data.projects.append(p)
            store.data.settings.projectId = p.id
        } else if let i = store.data.projects.firstIndex(where: { $0.id == p.id }) {
            store.data.projects[i] = p
        }
        store.saveNow()
        ToastCenter.shared.show("项目已保存")
        dismiss()
    }
}

// MARK: - 手动考勤期

struct PeriodEditor: View {
    var palette: Palette
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var start: Date
    @State private var end: Date

    init(palette: Palette) {
        self.palette = palette
        let now = Date()
        let y = Cal.gregorian.component(.year, from: now)
        let m = Cal.gregorian.component(.month, from: now)
        var sc = DateComponents()
        sc.year = y; sc.month = m; sc.day = 26
        let s = Cal.gregorian.date(from: sc) ?? now
        let next = Cal.monthAdd(y, m, 1)
        var ec = DateComponents()
        ec.year = next.year; ec.month = next.month; ec.day = 25
        let e = Cal.gregorian.date(from: ec) ?? now
        _start = State(initialValue: s)
        _end = State(initialValue: e)
    }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("加一期考勤")
                                .font(.system(size: 24, weight: .bold))
                            Text("排班起止不固定时，直接填真实日期")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.gsSecondary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .contentShape(Circle().inset(by: -5))
                                .background(Circle().fill(Color.primary.opacity(0.08)))
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
                        }
                        .buttonStyle(PressableStyle())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "起始日")
                        DatePicker("", selection: $start, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                        Divider().opacity(0.35)
                        SectionTitle(title: "结束日")
                        DatePicker("", selection: $end, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: store.settings.cardRadius)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("这一期是 \(Cal.key(start)) 至 \(Cal.key(end))")
                            .font(.system(size: 13, weight: .medium))
                        Text("共 \(daysBetween) 天。")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.gsSecondary)
                        Text("一个自然月只能挂一期，同月再填会覆盖原来那一期。因为起始日落在哪个月，就用哪个月的格子来记。")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gsSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: store.settings.cardRadius)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                save()
            } label: {
                Text("保存这期")
            }
            .buttonStyle(GlassActionButtonStyle(palette: palette, prominent: true, height: 48))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ledger.paper))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
            .padding(.horizontal, 12)
        }
    }

    private var daysBetween: Int {
        let s = Cal.gregorian.startOfDay(for: start)
        let e = Cal.gregorian.startOfDay(for: end)
        let d = Cal.gregorian.dateComponents([.day], from: s, to: e).day ?? 0
        return max(0, d + 1)
    }

    private func save() {
        let sk = Cal.key(start)
        let ek = Cal.key(end)
        guard ek > sk else {
            ToastCenter.shared.show("结束日要晚于起始日")
            return
        }
        let prefix = String(sk.prefix(7))
        store.data.settings.customPeriods.removeAll { $0.start.hasPrefix(prefix) }
        store.data.settings.customPeriods.append(CustomPeriod(start: sk, end: ek))
        store.saveNow()
        ToastCenter.shared.show("这一期已保存")
        dismiss()
    }
}

// MARK: - 工资计算器

struct WagePage: View {
    var palette: Palette
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var projectId = ""
    @State private var base = 0.0
    @State private var zb = 0.0
    @State private var jb = 0.0
    @State private var zm = 0.0
    @State private var jj = 0.0
    @State private var bonus = 0.0
    @State private var deduct = 0.0

    private var project: Project { store.project(projectId) }
    private var total: Double {
        base + zb * project.rates.zb + jb * project.rates.jb
            + zm * project.rates.zm + jj * project.rates.jj + bonus - deduct
    }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("工资计算器")
                                .font(.system(size: 24, weight: .bold))
                            Text("临时算一笔，不写进记录")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.gsSecondary)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .contentShape(Circle().inset(by: -5))
                                .background(Circle().fill(Color.primary.opacity(0.08)))
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
                        }
                        .buttonStyle(PressableStyle())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "按哪个项目的费率")
                        Picker("项目", selection: $projectId) {
                            ForEach(store.projects) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: store.settings.cardRadius)

                    VStack(alignment: .leading, spacing: 2) {
                        SectionTitle(title: "填数")
                        NumberRow(title: "底薪", unit: "元", value: $base, palette: palette, range: 0...999999)
                        NumberRow(title: "正班时数", unit: "H", value: $zb, palette: palette, range: 0...999)
                        NumberRow(title: "加班时数", unit: "H", value: $jb, palette: palette, range: 0...999)
                        NumberRow(title: "周末时数", unit: "H", value: $zm, palette: palette, range: 0...999)
                        NumberRow(title: "节假时数", unit: "H", value: $jj, palette: palette, range: 0...999)
                        NumberRow(title: "补贴", unit: "元", value: $bonus, palette: palette, range: 0...99999)
                        NumberRow(title: "扣款", unit: "元", value: $deduct, palette: palette, range: 0...99999)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: store.settings.cardRadius)

                    VStack(spacing: 8) {
                        Text("预计工资")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.gsSecondary)
                        Text(Cal.money(total))
                            .font(.system(size: 38, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.gsOrange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(detail)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gsSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .glassCard(radius: store.settings.cardRadius)

                    Text("只做估算：按项目时薪算，不含社保、个税和其他扣款规则。")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if projectId.isEmpty {
                projectId = store.project(store.settings.projectId).id
                base = project.base
            }
        }
        .onChange(of: projectId) { _, _ in
            base = project.base
        }
    }

    private var detail: String {
        "底薪 \(Cal.money(base)) + 正班 \(Cal.money(zb * project.rates.zb)) + 加班 \(Cal.money(jb * project.rates.jb)) + 周末 \(Cal.money(zm * project.rates.zm)) + 节假 \(Cal.money(jj * project.rates.jj)) + 补贴 \(Cal.money(bonus)) - 扣款 \(Cal.money(deduct))"
    }
}
