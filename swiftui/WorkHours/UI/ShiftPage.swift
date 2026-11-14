import SwiftUI

struct ShiftPage: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    @State private var year = Cal.year(Cal.todayKey())
    @State private var month = Cal.month(Cal.todayKey())
    @State private var pendingDate: String?
    @State private var showPicker = false
    @State private var showBatch = false
    @State private var showManager = false

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
                    calendarCard
                    legendCard
                    manageCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog("这天排什么班", isPresented: $showPicker, titleVisibility: .visible) {
            ForEach(store.classes) { c in
                Button(c.name) {
                    if let d = pendingDate { store.setPlan(c.id, for: d) }
                }
            }
            Button("清除排班", role: .destructive) {
                if let d = pendingDate { store.setPlan("", for: d) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let d = pendingDate { Text(Cal.shortDate(d)) }
        }
        .sheet(isPresented: $showBatch) {
            BatchSheet(year: year, month: month, palette: palette)
                .environmentObject(store)
        }
        .sheet(isPresented: $showManager) {
            ShiftManager(palette: palette)
                .environmentObject(store)
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Cal.monthTitle(year: year, month: month))
                    .font(.system(size: 26, weight: .bold))
                Text("点日期排班，批量一次设好一周")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
            }
            Spacer()
            menuButton("chevron.left") { move(-1) }
            menuButton("chevron.right") { move(1) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ledger.paper))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
    }

    private func menuButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle().inset(by: -5))
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
        }
        .buttonStyle(PressableStyle())
    }

    private func move(_ delta: Int, animated: Bool = true) {
        let next = Cal.monthAdd(year, month, delta)
        let apply = {
            year = next.year
            month = next.month
        }
        if animated { withAnimation(.snappy(duration: 0.26)) { apply() } } else { apply() }
    }

    // MARK: 月历

    private var calendarCard: some View {
        MonthCalendar(year: year, month: month, selected: pendingDate ?? "",
                      palette: palette, showsHours: false,
                      onPick: { key in
                          pendingDate = key
                          showPicker = true
                      },
                      onStep: { delta in move(delta, animated: false) })
    }

    // MARK: 图例 + 本月

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "班次", subtitle: "本月排班")
            HStack(spacing: 8) {
                ForEach(store.classes) { c in
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: c.color)).frame(width: 7, height: 7)
                            Text("\(count(of: c.id))")
                                .font(.system(size: 16, weight: .semibold))
                                .monospacedDigit()
                        }
                        Text(c.name)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gsSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: c.color).opacity(0.10))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: store.settings.cardRadius)
    }

    private func count(of classId: String) -> Int {
        let prefix = String(format: "%04d-%02d-", year, month)
        return store.data.plans.filter { $0.key.hasPrefix(prefix) && $0.value == classId }.count
    }

    // MARK: 批量 / 管理

    private var manageCard: some View {
        VStack(spacing: 10) {
            Button {
                showBatch = true
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("批量设置")
                            .font(.system(size: 15, weight: .semibold))
                        Text("多选日期，统一设班次和工时")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gsSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.gsSecondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PressableStyle(scale: 0.985))

            Divider().opacity(0.4)

            Button {
                showManager = true
            } label: {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("班次管理")
                            .font(.system(size: 15, weight: .semibold))
                        Text("名称、颜色、默认工时")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gsSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.gsSecondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PressableStyle(scale: 0.985))
        }
        .glassCard(radius: store.settings.cardRadius)
    }
}

// MARK: - 班次管理

struct ShiftManager: View {
    var palette: Palette
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let colors = ["#FCB819", "#33A0FF", "#FF9900", "#224799",
                          "#2E9E5B", "#D93A3A", "#7A4DFF", "#0E9F8E", "#55606F"]

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("班次管理")
                                .font(.system(size: 24, weight: .bold))
                            Text("名字带「夜 / 中 / 晚」发夜班补助，带「白 / 早」发白班补助")
                                .font(.system(size: 11))
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
                    .padding(.bottom, 2)

                    ForEach($store.data.classes) { $c in
                        shiftEditor($c)
                    }

                    Button {
                        let id = UUID().uuidString
                        store.data.classes.append(ShiftClass(id: id, name: "新班次", color: "#33A0FF"))
                    } label: {
                        Label("加一个班次", systemImage: "plus")
                    }
                    .buttonStyle(GlassActionButtonStyle(palette: palette, height: 46))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func shiftEditor(_ c: Binding<ShiftClass>) -> some View {
        let id = c.wrappedValue.id
        let def: Binding<ClassDefault> = Binding(
            get: { store.data.settings.classDefaults[id] ?? ClassDefault() },
            set: { store.data.settings.classDefaults[id] = $0 }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(Color(hex: c.wrappedValue.color))
                    .frame(width: 14, height: 14)
                TextField("班次名", text: c.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if store.classes.count > 1 {
                    Button {
                        store.data.classes.removeAll { $0.id == id }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gsRed)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(colors, id: \.self) { hex in
                    Button {
                        c.wrappedValue.color = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 22, height: 22)
                            .overlay {
                                if c.wrappedValue.color == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            Divider().opacity(0.4)

            HStack(spacing: 6) {
                defaultField("正班", def.zb)
                defaultField("加班", def.jb)
                defaultField("周末", def.zm)
                defaultField("节假", def.jj)
                defaultField("日结", def.rjgz)
            }

            if store.classes.count > 1 {
                Text("默认工时：新人记这个班次时自动带出")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.gsSecondary)
            }
        }
        .glassCard(radius: store.settings.cardRadius)
    }

    private func defaultField(_ title: String, _ value: Binding<Double>) -> some View {
        VStack(spacing: 2) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .frame(height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Color.gsSecondary)
        }
    }
}
