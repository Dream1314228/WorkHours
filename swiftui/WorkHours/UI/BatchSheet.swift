import SwiftUI

/// 多选日期，统一设班次和工时。
struct BatchSheet: View {
    var year: Int
    var month: Int
    var palette: Palette

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []
    @State private var classId = ""

    @State private var skipWeekend = true
    @State private var projectId = "default"
    @State private var showClearConfirm = false

    private var firstOffset: Int {
        let key = String(format: "%04d-%02d-01", year, month)
        let w = Cal.weekday(key)
        return store.settings.weekStart == 1 ? (w + 5) % 7 : (w - 1)
    }

    private var weekdayHeaders: [String] {
        store.settings.weekStart == 1
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    pickCard
                    formCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已选 \(selected.count) 天")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gsSecondary)
                    Text(classId.isEmpty ? "未选班次" : (store.shiftClass(classId)?.name ?? ""))
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "eraser")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gsRed)
                        .frame(width: 52, height: 48)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gsRed.opacity(0.08)))
                }
                .buttonStyle(PressableStyle())
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.4 : 1)

                Button {
                    apply()
                } label: {
                    Text("批量应用")
                }
                .buttonStyle(GlassActionButtonStyle(palette: palette, prominent: true, height: 48))
                .frame(width: 128)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ledger.paper))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
            .padding(.horizontal, 12)
        }
        .confirmationDialog("把选中的\(selected.count) 天排班清空？", isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("清空排班", role: .destructive) { clearPlans() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只清班次，不动已经记好的工时。")
        }
        .onAppear {
            if classId.isEmpty {
                classId = store.classes.first?.id ?? ""
                projectId = store.project(store.settings.projectId).id
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("批量设置")
                    .font(.system(size: 24, weight: .bold))
                Text("\(Cal.monthTitle(year: year, month: month)) · 点日期多选")
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

    private var pickCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { w in
                    Text(w)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.gsSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 4) {
                ForEach(0..<firstOffset, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }
                ForEach(1...Cal.daysInMonth(year, month), id: \.self) { d in
                    batchCell(d)
                }
            }

            Divider().opacity(0.4).padding(.vertical, 2)

            HStack(spacing: 6) {
                quickButton("工作日") { selectWorkdays() }
                quickButton("这一周") { selectWeek() }
                quickButton("全选") { selectAll() }
                quickButton("清空") { selected.removeAll() }
            }
        }
        .glassCard(radius: store.settings.cardRadius, padding: 10)
    }

    private func batchCell(_ d: Int) -> some View {
        let key = String(format: "%04d-%02d-%02d", year, month, d)
        let on = selected.contains(key)
        let weekend = Cal.isWeekend(key) && Cal.holidayName(key) == nil
        return Button {
            if on { selected.remove(key) } else { selected.insert(key) }
        } label: {
            VStack(spacing: 1) {
                Text("\(d)")
                    .font(.system(size: 13, weight: on ? .bold : .regular))
                    .monospacedDigit()
                if weekend {
                    Text("休").font(.system(size: 8)).foregroundStyle(Color.gsSecondary)
                }
            }
            .foregroundStyle(on ? palette.onPrimary : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on ? palette.deep : Color.primary.opacity(0.04))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(palette.primary.opacity(0.08)))
                .overlay(Capsule().strokeBorder(palette.primary.opacity(0.12), lineWidth: 0.8))
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "设成什么班")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.classes) { c in
                        Button {
                            classId = c.id
                        } label: {
                            ChipView(title: c.name, selected: classId == c.id,
                                     palette: palette, color: Color(hex: c.color), hex: c.color)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 1)
            }

            Divider().opacity(0.4)

            Text("只写班次，不生成工时记录。工时请在记录页单天填。")
                .font(.system(size: 11))
                .foregroundStyle(Color.gsSecondary)

            Divider().opacity(0.4)

            Toggle(isOn: $skipWeekend) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("跳过周末")
                        .font(.system(size: 15))
                    Text("勾上以后，选中的周末日期不会被改")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                }
            }
            .tint(palette.primary)

            HStack {
                Text("项目")
                    .font(.system(size: 15))
                Spacer()
                Picker("项目", selection: $projectId) {
                    ForEach(store.projects) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(palette.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func selectAll() {
        selected = Set((1...Cal.daysInMonth(year, month)).map {
            String(format: "%04d-%02d-%02d", year, month, $0)
        })
    }

    /// 选中「某一周」：以已选的最早一天为准，没选就用今天（不在本月就用 1 号）
    private func selectWeek() {
        let prefix = String(format: "%04d-%02d-", year, month)
        let anchor: String
        if let first = selected.min() {
            anchor = first
        } else {
            let today = Cal.todayKey()
            anchor = today.hasPrefix(prefix) ? today : prefix + "01"
        }
        let w = Cal.weekday(anchor)
        let lead = store.settings.weekStart == 1 ? (w + 5) % 7 : (w - 1)
        guard let start = Cal.gregorian.date(byAdding: .day, value: -lead, to: Cal.date(anchor)) else { return }
        var list = Set<String>()
        for i in 0..<7 {
            guard let d = Cal.gregorian.date(byAdding: .day, value: i, to: start) else { continue }
            let key = Cal.key(d)
            if key.hasPrefix(prefix) { list.insert(key) }
        }
        withAnimation(store.pageMotion ? .snappy(duration: 0.2) : nil) { selected = list }
    }

    private func clearPlans() {
        guard !selected.isEmpty else { return }
        var dates = Array(selected).sorted()
        if skipWeekend { dates = dates.filter { !Cal.isWeekend($0) } }
        for key in dates { store.setPlan("", for: key) }
        store.saveNow()
        ToastCenter.shared.show("已清空 \(dates.count) 天排班")
        dismiss()
    }

    private func selectWorkdays() {
        var list = Set<String>()
        for d in 1...Cal.daysInMonth(year, month) {
            let key = String(format: "%04d-%02d-%02d", year, month, d)
            if Cal.isWeekend(key) && Cal.holidayName(key) == nil && !Cal.isMakeupWorkday(key) { continue }
            list.insert(key)
        }
        selected = list
    }

    private func apply() {
        guard !selected.isEmpty else {
            ToastCenter.shared.show("先选几天")
            return
        }
        guard !classId.isEmpty else {
            ToastCenter.shared.show("先选班次")
            return
        }
        store.setPlanBatch(dates: Array(selected).sorted(), classId: classId,
                           skipWeekend: skipWeekend)
        ToastCenter.shared.show("已排班 \(selected.count) 天")
        store.saveNow()
        dismiss()
    }
}
