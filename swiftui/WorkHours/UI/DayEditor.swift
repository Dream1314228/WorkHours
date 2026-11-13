import SwiftUI

/// 记一笔 / 编辑一天。
struct DayEditor: View {
    var date: String
    var palette: Palette

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DayRecord()
    @State private var loaded = false
    @State private var showBonusAdd = false
    @State private var bonusName = ""
    @State private var bonusMoney = 0.0
    @State private var confirmDelete = false

    private let typeOptions: [(key: String, name: String)] = [
        ("zb", "正班"), ("zm", "周末"), ("jj", "节假"), ("xiu", "休假")
    ]

    private var isLeave: Bool { draft.leave != nil }

    /// 当天排班表里排的班次
    private var plannedShift: ShiftClass? {
        let plan = store.plan(date)
        return plan.isEmpty ? nil : store.shiftClass(plan)
    }

    private var total: Double { store.dayPay(draft) }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    typeCard
                    shiftCard
                    workCard
                    leaveCard
                    bonusCard
                    noteCard
                    if store.record(date) != nil {
                        Button {
                            confirmDelete = true
                        } label: {
                            Text("删除这天的记录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.gsRed)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .onAppear(perform: loadDraft)
        .alert("删除这天的记录？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                store.removeRecord(date)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Cal.shortDate(date))
                    .font(.system(size: 24, weight: .bold))
                Text(Cal.weekdayName(date) + (Cal.holidayName(date).map { " · \($0)" } ?? ""))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle().inset(by: -5))
                    .background(Circle().fill(Color.primary.opacity(0.08)))
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
            }
            .buttonStyle(PressableStyle())
        }
    }

    // MARK: 类型

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "这天算什么", subtitle: Cal.dayKind(date) == draft.type ? "按日历默认" : nil)
            HStack(spacing: 6) {
                ForEach(typeOptions, id: \.key) { opt in
                    Button {
                        setType(opt.key)
                    } label: {
                        ChipView(title: opt.name, selected: draft.type == opt.key, palette: palette)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func setType(_ type: String) {
        draft.type = type
        if type == "xiu" {
            draft.work = WorkHours()
            if draft.leave == nil {
                draft.leave = LeaveInfo(type: "xiu", hour: 8, multiple: 0)
            }
        } else {
            draft.leave = nil
            var w = draft.work
            if w.total == 0 {
                let def = store.defaultWork(forClass: draft.classId)
                switch type {
                case "zm": w = WorkHours(zb: 0, jb: def.jb, zm: def.zm, jj: 0)
                case "jj": w = WorkHours(zb: 0, jb: def.jb, zm: 0, jj: def.jj)
                default: w = WorkHours(zb: def.zb, jb: def.jb, zm: 0, jj: 0)
                }
                draft.work = w
            }
        }
    }

    // MARK: 班次

    private var shiftCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "班次")
                Spacer()
                Button {
                    draft.work = store.defaultWork(forClass: draft.classId)
                    ToastCenter.shared.show("已套用班次默认工时")
                } label: {
                    Text("套用默认工时")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
            }

            if let planned = plannedShift {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("排班表：\(planned.name)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Text(draft.classId == planned.id
                             ? "已自动套用这个班的工时，不用再挑"
                             : "点右边直接套用，省得再挑一次")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gsSecondary)
                    }
                    Spacer(minLength: 6)
                    Button {
                        draft.classId = planned.id
                        draft.work = store.defaultWork(forClass: planned.id)
                        ToastCenter.shared.show("已按排班套用 \(planned.name)")
                    } label: {
                        Text("套用")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.onPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(Capsule().fill(palette.primary))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.primary.opacity(0.07))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.classes) { c in
                        Button {
                            draft.classId = c.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: c.symbol)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(c.name)
                                    .font(.system(size: 13, weight: draft.classId == c.id ? .semibold : .regular))
                            }
                            .foregroundStyle(draft.classId == c.id ? Theme.readableOn(c.color) : Color.primary)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background {
                                Capsule().fill(draft.classId == c.id
                                               ? Color(hex: c.color)
                                               : Color.primary.opacity(0.06))
                            }
                            .overlay {
                                Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 1)
            }
            HStack {
                Text("项目")
                    .font(.system(size: 15))
                Spacer()
                Picker("项目", selection: $draft.projectId) {
                    ForEach(store.projects) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(palette.primary)
            }
            .frame(height: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 工时

    private var workCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(title: "工时", subtitle: isLeave ? "休假不记工时" : "小时")
            Group {
                NumberRow(title: "正班", unit: "H", value: $draft.work.zb, palette: palette, range: 0...24)
                NumberRow(title: "加班", unit: "H", value: $draft.work.jb, palette: palette, range: 0...24)
                NumberRow(title: "周末", unit: "H", value: $draft.work.zm, palette: palette, range: 0...24)
                NumberRow(title: "节假", unit: "H", value: $draft.work.jj, palette: palette, range: 0...24)
            }
            .disabled(isLeave)
            .opacity(isLeave ? 0.45 : 1)

            Divider().opacity(0.4).padding(.vertical, 2)

            HStack {
                Text("日结金额")
                    .font(.system(size: 15))
                Spacer()
                Text("填了就不按工时算")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gsSecondary)
            }
            NumberRow(title: "", unit: "元", value: $draft.settle, palette: palette, range: 0...99999)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 请假

    private var leaveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(title: "请假 / 调休")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { draft.leave != nil },
                    set: { on in
                        if on {
                            draft.type = "xiu"
                            draft.work = WorkHours()
                            draft.leave = LeaveInfo(type: "xiu", hour: 8, multiple: 0)
                        } else {
                            draft.leave = nil
                            if draft.type == "xiu" { draft.type = Cal.dayKind(date) }
                        }
                    }
                ))
                .labelsHidden()
                .tint(palette.primary)
            }

            if draft.leave != nil {
                let leave = draft.leave ?? LeaveInfo()

                HStack(spacing: 6) {
                    ForEach([("bing", "病假"), ("shi", "事假"), ("tiao", "调休"), ("xiu", "薪假")], id: \.0) { item in
                        Button {
                            draft.leave?.type = item.0
                        } label: {
                            ChipView(title: item.1, selected: draft.leave?.type == item.0, palette: palette)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    Spacer()
                }

                NumberRow(title: "请假小时", unit: "H",
                          value: Binding(get: { draft.leave?.hour ?? 0 },
                                         set: { draft.leave?.hour = $0 }),
                          palette: palette, range: 0...24)

                HStack {
                    Text("计薪倍率")
                        .font(.system(size: 15))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach([0.0, 0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { m in
                            Button {
                                draft.leave?.multiple = m
                                draft.leave?.rule = "hour"
                            } label: {
                                Text(m == 0 ? "不扣" : Cal.num(m) + "×")
                                    .font(.system(size: 12, weight: leave.multiple == m && leave.rule == "hour" ? .semibold : .regular))
                                    .foregroundStyle(leave.multiple == m && leave.rule == "hour" ? palette.onPrimary : Color.primary)
                                    .padding(.horizontal, 9)
                                    .frame(height: 30)
                                    .padding(.vertical, 7)
                                    .background {
                                        Capsule().fill(leave.multiple == m && leave.rule == "hour"
                                                       ? palette.primary
                                                       : Color.primary.opacity(0.06))
                                    }
                                    .overlay {
                                        Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
                                    }
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }

                HStack {
                    Text("改按固定金额")
                        .font(.system(size: 14))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { draft.leave?.rule == "money" },
                        set: { draft.leave?.rule = $0 ? "money" : "hour" }
                    ))
                    .labelsHidden()
                    .tint(palette.primary)
                }

                if draft.leave?.rule == "money" {
                    NumberRow(title: "请假工资", unit: "元",
                              value: Binding(get: { draft.leave?.money ?? 0 },
                                             set: { draft.leave?.money = $0 }),
                              palette: palette, range: 0...99999)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 补贴

    private var bonusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(title: "补贴 / 扣款", subtitle: "负数算扣款")
                Spacer()
                Button {
                    bonusName = ""
                    bonusMoney = 0
                    showBonusAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
                }
                .buttonStyle(PressableStyle())
            }

            if draft.bt.isEmpty {
                EmptyHint(text: "没有额外补贴")
            } else {
                ForEach($draft.bt) { $item in
                    HStack(spacing: 8) {
                        TextField("名称", text: $item.name)
                            .font(.system(size: 14))
                            .frame(maxWidth: 110, alignment: .leading)
                        Spacer()
                        TextField("0", value: $item.money, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .frame(width: 80)
                        Text("元")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gsSecondary)
                        Button {
                            draft.bt.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.gsSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
        .alert("加一笔补贴", isPresented: $showBonusAdd) {
            TextField("名称，例如 高温补贴", text: $bonusName)
            TextField("金额，扣款填负数", value: $bonusMoney, format: .number)
                .keyboardType(.numbersAndPunctuation)
            Button("加上") {
                let name = bonusName.isEmpty ? "补贴" : bonusName
                draft.bt.append(BonusItem(name: name, money: bonusMoney, note: "手动添加"))
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: 备注

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "备注")
            TextField("写点什么，例如 换线、代班", text: $draft.note, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(2...4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 底部

    private var bottomBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("当天合计")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gsSecondary)
                Text(Cal.money(total))
                    .font(.system(size: 21, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.gsOrange)
            }
            Spacer(minLength: 8)
            Button {
                save()
            } label: {
                Text("保存")
            }
            .buttonStyle(GlassActionButtonStyle(palette: palette, prominent: true, height: 48))
            .frame(width: 150)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ledger.paper))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: 数据

    private func loadDraft() {
        guard !loaded else { return }
        loaded = true
        if var r = store.record(date) {
            store.ensureAutoAllowance(&r)
            draft = r
            return
        }
        var r = DayRecord()
        let plan = store.plan(date)
        r.classId = (plan.isEmpty ? nil : store.shiftClass(plan)?.id) ?? store.settings.currentClass
        if store.shiftClass(r.classId) == nil { r.classId = store.classes.first?.id ?? "1" }
        r.projectId = store.project(store.settings.projectId).id
        r.type = Cal.dayKind(date)
        var def = store.defaultWork(forClass: r.classId)
        // 没设过这个班的默认工时，就拿最近一次同样班次的工时兜底
        if def.zb + def.jb + def.zm + def.jj <= 0,
           let last = store.lastWork(forClass: r.classId) {
            def = WorkHours(zb: last.zb, jb: last.jb, zm: last.zm, jj: last.jj)
        }
        switch r.type {
        case "zm": r.work = WorkHours(zb: 0, jb: def.jb, zm: def.zm, jj: 0)
        case "jj": r.work = WorkHours(zb: 0, jb: def.jb, zm: 0, jj: def.jj)
        default: r.work = WorkHours(zb: def.zb, jb: def.jb, zm: 0, jj: 0)
        }
        store.ensureAutoAllowance(&r)
        draft = r
    }

    private func save() {
        if draft.leave != nil {
            draft.type = "xiu"
        }
        if draft.work.total > 24 * 4 {
            ToastCenter.shared.show("工时看起来太大了，检查一下")
            return
        }
        store.setRecord(draft, for: date)
        store.saveNow()
        ToastCenter.shared.show("已保存 \(Cal.shortDate(date))")
        dismiss()
    }
}
