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
    @State private var recordHours = false
    @State private var normal: Double = 8
    @State private var overtime: Double = 0
    @State private var skipWeekend = true
    @State private var projectId = "default"

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
                    apply()
                } label: {
                    Text("批量应用")
                }
                .buttonStyle(GlassActionButtonStyle(palette: palette, prominent: true, height: 48))
                .frame(width: 160)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ledger.paper))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
            .padding(.horizontal, 12)
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
                    .frame(width: 34, height: 34)
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
                    .fill(on ? palette.primary : Color.primary.opacity(0.04))
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

            Toggle(isOn: $recordHours) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("同时记工时")
                        .font(.system(size: 15))
                    Text("不勾就是只排班，日历上只显示班次，不记账")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                }
            }
            .tint(palette.primary)

            VStack(alignment: .leading, spacing: 10) {
                NumberRow(title: "正常工时", unit: "H", value: $normal, palette: palette, range: 0...24)
                NumberRow(title: "加班工时", unit: "H", value: $overtime, palette: palette, range: 0...24)

                Text("正常工时自动落到正班 / 周末 / 节假，加班统一记加班。")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gsSecondary)
            }
            .opacity(recordHours ? 1 : 0.4)
            .disabled(!recordHours)

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
        if recordHours {
            if normal + overtime <= 0 {
                ToastCenter.shared.show("工时不能都是 0")
                return
            }
            store.batchApply(dates: Array(selected).sorted(), classId: classId,
                             normal: normal, overtime: overtime,
                             projectId: projectId, skipWeekend: skipWeekend)
            ToastCenter.shared.show("已记录 \(selected.count) 天的工时")
        } else {
            store.setPlanBatch(dates: Array(selected).sorted(), classId: classId,
                               skipWeekend: skipWeekend)
            ToastCenter.shared.show("已排班 \(selected.count) 天，没记工时")
        }
        store.saveNow()
        dismiss()
    }
}
