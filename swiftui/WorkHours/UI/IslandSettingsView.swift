import SwiftUI

/// 灵动岛配置：开关、配色、两侧放什么、展开显示哪几项。
/// 这里是 App 侧的编辑界面；真正画在岛上的代码在 WorkHoursWidget 里。
struct IslandSettingsView: View {
    var palette: Palette
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private var cfg: IslandConfig { store.data.settings.island }

    private func binding<Value>(_ kp: WritableKeyPath<IslandConfig, Value>) -> Binding<Value> {
        Binding(
            get: { store.data.settings.island[keyPath: kp] },
            set: { store.data.settings.island[keyPath: kp] = $0 }
        )
    }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 12) {
                    header
                    switchCard
                    styleCard
                    compactCard
                    expandedCard
                    previewCard
                    noteCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: cfg) { _, _ in
            // 配置一改就同步过去，不用退出页面
            IslandManager.shared.sync(store: store)
        }
    }

    // MARK: 顶栏

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("灵动岛")
                    .font(.system(size: 24, weight: .bold))
                Text("锁屏和岛上的实时工时")
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

    // MARK: 开关

    private var switchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "开关")
            row(title: "启用灵动岛", note: "关掉就彻底不挂，锁屏也不会留") {
                Toggle("", isOn: binding(\.enabled)).labelsHidden().tint(palette.primary)
            }
            Divider().opacity(0.4)
            row(title: "没记录也显示", note: "今天还没记时，岛上显示 0H") {
                Toggle("", isOn: binding(\.showEmpty)).labelsHidden().tint(palette.primary)
            }
            Divider().opacity(0.4)
            row(title: "锁屏也显示", note: "锁屏那张卡和岛用同一份数据") {
                Toggle("", isOn: binding(\.lockScreen)).labelsHidden().tint(palette.primary)
            }
            Divider().opacity(0.4)
            row(title: "工时进度条", note: "今日工时 ÷ 应上工时") {
                Toggle("", isOn: binding(\.progress)).labelsHidden().tint(palette.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func row<C: View>(title: String, note: String, @ViewBuilder trailing: () -> C) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15))
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gsSecondary)
            }
            Spacer(minLength: 6)
            trailing()
        }
    }

    // MARK: 配色

    private let styles: [(key: String, name: String, color: Color)] = [
        ("dark", "墨黑", Color(red: 0.98, green: 0.72, blue: 0.25)),
        ("gold", "发薪金", Color(red: 0.95, green: 0.76, blue: 0.31)),
        ("green", "青绿", Color(red: 0.36, green: 0.83, blue: 0.53)),
        ("blue", "夜蓝", Color(red: 0.47, green: 0.62, blue: 1.0)),
        ("pink", "粉桃", Color(red: 0.98, green: 0.55, blue: 0.68)),
        ("light", "浅色", Color(red: 0.25, green: 0.25, blue: 0.28))
    ]

    private var styleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "配色", subtitle: "数字和进度条的颜色")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(styles, id: \.key) { s in
                    Button {
                        store.data.settings.island.style = s.key
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(s.color)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().strokeBorder(
                                        cfg.style == s.key ? Color.primary.opacity(0.6) : Color.clear,
                                        lineWidth: 2)
                                )
                            Text(s.name)
                                .font(.system(size: 11, weight: cfg.style == s.key ? .semibold : .regular))
                                .foregroundStyle(Color.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cfg.style == s.key ? palette.primary.opacity(0.10) : Color.primary.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(cfg.style == s.key ? palette.primary.opacity(0.35) : Color.clear,
                                          lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    // MARK: 紧凑区

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "紧凑区", subtitle: "岛平时露出的左右两块")
            fieldPicker(title: "左边", key: \.compactLeading)
            Divider().opacity(0.4)
            fieldPicker(title: "右边", key: \.compactTrailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func fieldPicker(title: String, key: WritableKeyPath<IslandConfig, String>) -> some View {
        HStack {
            Text(title).font(.system(size: 15))
            Spacer()
            Picker(title, selection: binding(key)) {
                ForEach(IslandField.allCases) { f in
                    Text(f.name).tag(f.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(palette.deep)
        }
    }

    // MARK: 展开区

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "展开区", subtitle: "点开岛时显示，最多 4 项")

            if cfg.expanded.isEmpty {
                Text("还没选，展开时只显示今日金额")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
            } else {
                ForEach(Array(cfg.expanded.enumerated()), id: \.offset) { idx, raw in
                    HStack(spacing: 8) {
                        Text("\(idx + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.gsSecondary)
                            .frame(width: 16, alignment: .leading)
                        Text(IslandField(rawValue: raw)?.name ?? raw)
                            .font(.system(size: 14))
                        Spacer()
                        Button { move(idx, -1) } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(idx == 0 ? 0.25 : 0.8)
                        .disabled(idx == 0)

                        Button { move(idx, 1) } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(idx == cfg.expanded.count - 1 ? 0.25 : 0.8)
                        .disabled(idx == cfg.expanded.count - 1)

                        Button { remove(raw) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.gsRed.opacity(0.85))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 36)
                }
            }

            Divider().opacity(0.4)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                      spacing: 6) {
                ForEach(IslandField.allCases.filter { !cfg.expanded.contains($0.rawValue) }) { f in
                    Button { add(f) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text(f.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05)))
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(cfg.expanded.count >= 4)
                    .opacity(cfg.expanded.count >= 4 ? 0.35 : 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func add(_ f: IslandField) {
        guard cfg.expanded.count < 4, !cfg.expanded.contains(f.rawValue) else { return }
        store.data.settings.island.expanded.append(f.rawValue)
    }

    private func remove(_ raw: String) {
        store.data.settings.island.expanded.removeAll { $0 == raw }
    }

    private func move(_ idx: Int, _ delta: Int) {
        var list = cfg.expanded
        let to = idx + delta
        guard list.indices.contains(idx), list.indices.contains(to) else { return }
        list.swapAt(idx, to)
        store.data.settings.island.expanded = list
    }

    // MARK: 预览

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "预览", subtitle: "实际样式以系统为准")

            // 收起：岛的两侧
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill").font(.system(size: 9))
                    Text(compactPreview(cfg.compactLeading))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(accentColor)
                Spacer(minLength: 24)
                Text(compactPreview(cfg.compactTrailing))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(cfg.style == "light" ? .black : .white)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Capsule().fill(cfg.style == "light" ? Color(white: 0.95) : Color.black))

            // 展开：几项并排
            HStack(spacing: 0) {
                ForEach(Array(previewRows.prefix(4).enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.45))
                        Text(item.1)
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cfg.style == "light" ? Color(white: 0.95) : Color.black))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private var accentColor: Color {
        switch cfg.style {
        case "gold": return Color(red: 0.95, green: 0.76, blue: 0.31)
        case "green": return Color(red: 0.36, green: 0.83, blue: 0.53)
        case "blue": return Color(red: 0.47, green: 0.62, blue: 1.0)
        case "pink": return Color(red: 0.98, green: 0.55, blue: 0.68)
        case "light": return Color(red: 0.98, green: 0.72, blue: 0.25)
        default: return Color(red: 0.98, green: 0.72, blue: 0.25)
        }
    }

    private var todayRecord: DayRecord? { store.record(Cal.todayKey()) }

    private func compactPreview(_ raw: String) -> String {
        guard let f = IslandField(rawValue: raw) else { return "" }
        return previewValue(f, tight: true)
    }

    private var previewRows: [(String, String)] {
        cfg.expanded.compactMap { raw in
            guard let f = IslandField(rawValue: raw) else { return nil }
            return (f.name, previewValue(f, tight: false))
        }
    }

    private func previewValue(_ f: IslandField, tight: Bool) -> String {
        let r = todayRecord
        let hours = r?.work.total ?? 0
        let pay = r.map { store.dayPay($0) } ?? 0
        let period = store.currentPeriodKey()
        switch f {
        case .todayHours: return "\(Cal.num(hours))H"
        case .todayPay: return "¥" + Cal.num(pay)
        case .need: return Cal.num(store.defaultWork(forClass: r?.classId ?? store.settings.currentClass).total) + "H"
        case .progress:
            let need = store.defaultWork(forClass: r?.classId ?? store.settings.currentClass).total
            return "\(Int((need > 0 ? hours / need : 0) * 100))%"
        case .periodPay: return "¥" + Cal.num(store.monthStats(year: period.year, month: period.month).pay)
        case .monthHours:
            return Cal.num(store.monthStats(year: Cal.year(Cal.todayKey()), month: Cal.month(Cal.todayKey()), usePeriod: false).hours) + "H"
        case .monthPay:
            return "¥" + Cal.num(store.monthStats(year: Cal.year(Cal.todayKey()), month: Cal.month(Cal.todayKey()), usePeriod: false).pay)
        case .streak: return "—"
        case .paydayLeft:
            let p = store.settings.payday
            return p > 0 ? "\(max(0, p - Cal.day(Cal.todayKey()))) 天" : "—"
        case .shift:
            return r.flatMap { store.shiftClass($0.classId) }?.name ?? "—"
        case .project:
            return store.project(r?.projectId ?? store.settings.projectId).name
        case .leaveLeft:
            return Cal.num(store.annualLeaveRemaining(year: Cal.year(Cal.todayKey()))) + " 天"
        }
    }

    // MARK: 说明

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("几个说明")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.gsSecondary)
            bullet("数据只在 App 里改动时刷新。锁屏放几小时，数字不会自己变，这是系统的限制，不是没生效。")
            bullet("系统设置 → 工时记录 → 实时活动 要打开，否则岛上什么都不显示。")
            bullet("紧凑区只能放很短的内容，名字长的项会自动用短名。")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(Color.gsSecondary.opacity(0.5))
                .frame(width: 3, height: 3)
                .padding(.top, 7)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Color.gsSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
