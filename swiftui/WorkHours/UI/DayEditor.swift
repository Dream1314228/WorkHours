import SwiftUI

/// 记一笔 / 编辑一天。
struct DayEditor: View {
    var date: String
    var palette: Palette
    /// 从全屏浮层（日历格子放大）进来时用这个关；走 sheet 时留空，退回 dismiss。
    var onClose: (() -> Void)? = nil
    /// 半屏弹层盖住底部安全区时，底栏要自己躲开家居条
    var bottomInset: CGFloat = 0
    /// 正在被下拉：先把列表滚动锁住，不然两手抢位移，画面会抖
    var dragging: Bool = false

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
    /// 整天不在岗：班次、项目、工时、补贴都不占地方。
    /// 是否上班由请假区那个开关说了算，跟请几小时无关。
    private var fullLeave: Bool { draft.leave != nil && !(draft.leave?.alsoWork ?? false) }
    private var leaveHour: Double { draft.leave?.hour ?? 0 }

    /// 当天排班表里排的班次
    private var plannedShift: ShiftClass? {
        let plan = store.plan(date)
        return plan.isEmpty ? nil : store.shiftClass(plan)
    }

    private var total: Double { store.dayPay(draft) }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 12) {
                    header
                    summary
                    mainCard
                    workCard
                    extrasCard
                    if store.record(date) != nil {
                        Button {
                            confirmDelete = true
                        } label: {
                            Text("删除这天的记录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.gsRed)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.gsRed.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.gsRed.opacity(0.18), lineWidth: 0.8))
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)   // 顶上给抓手和圆角留位置，日期别贴着边
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollDisabled(dragging)

            // 抓手画在编辑器里，跟着整块一起走；按下时变宽变深，给一点反馈
            Capsule()
                .fill(Color.primary.opacity(dragging ? 0.52 : 0.28))
                .frame(width: dragging ? 68 : 56, height: dragging ? 7 : 6)
                .padding(.top, dragging ? 8 : 9)
                .animation(store.pageMotion ? .spring(response: 0.28, dampingFraction: 0.7) : nil,
                           value: dragging)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            bottomBar
        }
        .onAppear(perform: loadDraft)
        .alert("删除这天的记录？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                store.removeRecord(date)
                close()
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
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.record(date) != nil ? Color.gsGreen : Color.gsSecondary.opacity(0.45))
                        .frame(width: 5, height: 5)
                    Text(Cal.weekdayName(date) + (Cal.holidayName(date).map { " · \($0)" } ?? ""))
                    if store.record(date) != nil {
                        Text("· 已记录")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.gsSecondary)
            }
            Spacer()
            Button {
                close()
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

    // MARK: 摘要

    /// 顶上这行给焦点：现在能拿多少、几小时、哪个班，不用滚到底看
    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(Cal.signedMoney(total))
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(total < 0 ? Color.gsRed : Color.gsOrange)
                .contentTransition(.numericText())
                .animation(store.pageMotion ? .snappy(duration: 0.2) : nil, value: total)
            Spacer(minLength: 8)
            Text(summaryDetail)
                .font(.system(size: 12))
                .foregroundStyle(Color.gsSecondary)
                .lineLimit(1)
        }
        .padding(.top, -2)
    }

    private var summaryDetail: String {
        var parts: [String] = []
        if fullLeave {
            parts.append("整天请假 \(Cal.num(leaveHour)) 小时")
        } else {
            if draft.work.total > 0 { parts.append("\(Cal.num(draft.work.total)) 小时") }
            if let l = draft.leave { parts.append("请假 \(Cal.num(l.hour)) 小时") }
        }
        if let c = store.classes.first(where: { $0.id == draft.classId }) {
            parts.append(c.name)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: 类型

    /// 类型、班次、项目合成一张卡：三块原来各占一张，光卡片间隙就吃掉大半屏
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            // 全天休假不上班，班次和项目都收起来
            if !fullLeave {
                HStack(spacing: 8) {
                    SectionTitle(title: "班次")
                    Spacer(minLength: 6)
                    Button {
                        draft.work = store.defaultWork(forClass: draft.classId)
                        ToastCenter.shared.show("已套用班次默认工时")
                    } label: {
                        Text("套用默认工时")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
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
                    .padding(8)
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
                                .frame(height: 42)
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

                Divider().opacity(0.4)

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
                .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius, padding: 14)
    }

    /// 换类型 = 换成这个类型在设置里配好的工时，不用再手动改一遍数字。
    /// 只有请假是个例外：请半天时还得照常上班，工时不能清。
    private func setType(_ type: String) {
        draft.type = type
        let def = store.defaultWork(forClass: draft.classId)
        if type == "xiu" {
            if draft.leave == nil {
                draft.leave = LeaveInfo(type: "xiu", hour: 8, multiple: 0)
            }
            if draft.leave?.alsoWork == false {
                draft.work = WorkHours()
            } else if draft.work.total == 0 {
                draft.work = Store.workForType("zb", from: def)
            }
        } else {
            draft.leave = nil
            draft.work = Store.workForType(type, from: def)
        }
    }

    // MARK: 班次

    // MARK: 工时

    @ViewBuilder
    private var workCard: some View {
        if !fullLeave {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(title: "工时")
                Spacer()
                Text(fullLeave ? "休假不记工时" : "小时")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gsSecondary)
            }

            // 四行竖排太占地方，两列两行：一屏就能看完，不用来回滚
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)], spacing: 8) {
                HourBox(title: "正班", color: palette.primary,
                        value: $draft.work.zb, palette: palette)
                HourBox(title: "加班", color: Color.gsOrange,
                        value: $draft.work.jb, palette: palette)
                HourBox(title: "周末", color: Color.gsGreen,
                        value: $draft.work.zm, palette: palette)
                HourBox(title: "节假", color: Color.gsRed,
                        value: $draft.work.jj, palette: palette)
            }
            .disabled(fullLeave)
            .opacity(fullLeave ? 0.45 : 1)

            Divider().opacity(0.4).padding(.top, 2)

            HStack {
                Text("日结金额")
                    .font(.system(size: 14))
                Spacer()
                Text("填了就不按工时算")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.gsSecondary)
            }
            NumberRow(title: "", unit: "元", value: $draft.settle, palette: palette, range: 0...99999)
                .frame(height: 38)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius, padding: 14)
        }
    }

    // MARK: 请假

    private var leaveSection: some View {
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
                            if draft.work.total == 0 {
                                draft.work = Store.workForType(draft.type, from: store.defaultWork(forClass: draft.classId))
                            }
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

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("当天仍上班")
                            .font(.system(size: 15))
                        Text("整天请假又回来加班时打开")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gsSecondary)
                    }
                    Spacer(minLength: 6)
                    Toggle("", isOn: Binding(
                        get: { draft.leave?.alsoWork ?? false },
                        set: { on in
                            draft.leave?.alsoWork = on
                            if on && draft.work.total == 0 {
                                draft.work = Store.workForType("zb", from: store.defaultWork(forClass: draft.classId))
                            }
                            if !on { draft.work = WorkHours() }
                        }
                    ))
                    .labelsHidden()
                    .tint(palette.primary)
                }

                NumberRow(title: "请假小时", unit: "H",
                          value: Binding(get: { draft.leave?.hour ?? 0 },
                                         set: { draft.leave?.hour = $0 }),
                          palette: palette, range: 0...24)

                if !fullLeave {
                    Text("这天仍来上班，上班时长填在下面「工时」里")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gsSecondary)
                } else {
                    Text("整天不在岗，班次、工时、补贴都已收起；要是还来加班，打开上面「当天仍上班」")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gsSecondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("请假扣款倍率")
                        .font(.system(size: 15))
                    Text("请假小时 × 正班单价 × 倍率，从当天工资里扣")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gsSecondary)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                          spacing: 8) {
                    ForEach([0.0, 0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { m in
                        let on = leave.multiple == m && leave.rule == "hour"
                        Button {
                            draft.leave?.multiple = m
                            draft.leave?.rule = "hour"
                        } label: {
                            Text(m == 0 ? "不扣" : Cal.num(m) + "×")
                                .font(.system(size: 13, weight: on ? .semibold : .regular))
                                .foregroundStyle(on ? palette.onPrimary : Color.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(on ? palette.primary : Color.primary.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(on ? 0 : 0.10), lineWidth: 0.8))
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
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
    }

    // MARK: 补贴

    private var bonusSection: some View {
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
    }

    // MARK: 备注

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "备注")
            TextField("写点什么，例如 换线、代班", text: $draft.note, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(2...4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 补贴、请假、备注合成一张卡：原来各占一张，三张卡的边距和间隙比内容还占地方
    private var extrasCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !fullLeave {
                bonusSection
                Divider().opacity(0.4)
            }
            leaveSection
            Divider().opacity(0.4)
            noteSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius, padding: 14)
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

    // MARK: 底部

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                save()
            } label: {
                Text("保存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.deep.opacity(0.58)))
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressableStyle())

            Button {
                close()
            } label: {
                Text("关闭")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 96, height: 50)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.primary.opacity(0.06)))
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(8)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
        .padding(.bottom, 6 + bottomInset)
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
        r.work = Store.workForType(r.type, from: def)
        store.ensureAutoAllowance(&r)
        draft = r
    }

    private func save() {
        // 整天不在岗才算休假类型；请了假还来上班的，类型留着他选的班/周末/节假
        if let l = draft.leave, !l.alsoWork {
            draft.type = "xiu"
        }
        if draft.work.total > 24 * 4 {
            ToastCenter.shared.show("工时看起来太大了，检查一下")
            return
        }
        store.setRecord(draft, for: date)
        store.saveNow()
        ToastCenter.shared.show("已保存 \(Cal.shortDate(date))")
        close()
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

/// 工时输入格：标题一行、数字一行，两个一行排成 2×2。
private struct HourBox: View {
    var title: String
    var color: Color
    @Binding var value: Double
    var palette: Palette

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Capsule().fill(color).frame(width: 3, height: 10)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.gsSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 21, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(focused ? color : Color.primary)
                    .focused($focused)
                Text("H")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Ledger.inkSoft)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(focused ? 0.5 : 0.14), lineWidth: focused ? 1.2 : 0.8)
        }
        .onAppear { text = Cal.num(value) }
        .onChange(of: text) { _, v in
            let d = Double(v.replacingOccurrences(of: ",", with: ".")) ?? 0
            value = min(24, max(0, d))
        }
        .onChange(of: value) { _, v in
            if !focused { text = Cal.num(v) }
        }
    }
}
