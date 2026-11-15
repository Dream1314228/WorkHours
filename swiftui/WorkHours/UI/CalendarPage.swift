import SwiftUI

struct CalendarPage: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    @State private var year = Cal.year(Cal.todayKey())
    @State private var month = Cal.month(Cal.todayKey())
    @State private var selected = Cal.todayKey()
    @State private var confirmDelete = false
    /// 选中的日历格子位置，编辑页从这儿放大出来
    @State private var cellFrame: CGRect = .zero
    /// 删除时卡片横向擦除的进度：1 正常，0 全擦掉
    @State private var wipe: CGFloat = 1
    @State private var showBill = false

    private var today: String { Cal.todayKey() }

    private var selectedRecord: DayRecord? { store.record(selected) }

    private var monthStats: MonthStats { store.monthStats(year: year, month: month) }

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
                VStack(spacing: 10) {
                    header
                    overviewCard
                    calendarCard
                    dayCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task { await store.autoUpdateHoliday() }
        .alert("删除这天的记录？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                wipeThenRemove()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删这一天，排班和别的日期不受影响。")
        }
    }

    // MARK: 顶部

    private func openEditor() {
        store.openEditor(selected, from: cellFrame)
    }

    /// 删记录：卡片先从右往左擦掉，再删数据，最后从左展开成「这天还没记」
    private func wipeThenRemove() {
        let key = selected
        guard store.pageMotion else {
            store.removeRecord(key)
            ToastCenter.shared.show("已删除 \(Cal.shortDate(key)) 的记录")
            return
        }
        withAnimation(.easeIn(duration: 0.2)) { wipe = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            store.removeRecord(key)
            ToastCenter.shared.show("已删除 \(Cal.shortDate(key)) 的记录")
            withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) { wipe = 1 }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(year) 年 \(month) 月")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Ledger.ink)
                    .contentTransition(.numericText(countsDown: true))
                Text(monthStats.label)
                    .font(.system(size: 12))
                    .foregroundStyle(Ledger.inkSoft)
                    .monospacedDigit()
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                monthButton("chevron.left") { moveMonth(-1) }
                monthButton("chevron.right") { moveMonth(1) }
                Button {
                    jumpToday()
                } label: {
                    Text("今天")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Ledger.paper)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ledger.ink))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .animation(store.pageMotion ? .snappy(duration: 0.26) : nil, value: month)
    }

    private var overviewCard: some View {
        let prev = Cal.monthAdd(year, month, -1)
        let p = store.monthStats(year: prev.year, month: prev.month)
        let delta = monthStats.pay - p.pay
        let ratio = p.pay > 0 ? delta / p.pay * 100 : 0
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.26)) { showBill.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("本期账单")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(Ledger.inkSoft)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Cal.money(monthStats.pay))
                                .font(.system(size: 24, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Ledger.ink)
                                .contentTransition(.numericText())
                            Text("元")
                                .font(.system(size: 11))
                                .foregroundStyle(Ledger.inkSoft)
                        }
                        Text("\(monthStats.label) · 出勤 \(Cal.num(monthStats.days)) 天 · \(Cal.num(monthStats.hours)) H")
                            .font(.system(size: 10))
                            .foregroundStyle(Ledger.inkSoft)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Ledger.inkSoft)
                        .rotationEffect(.degrees(showBill ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .frame(height: 74)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.995))

            if showBill {
                VStack(alignment: .leading, spacing: 12) {
                    LedgerRule()
                    if p.pay > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(String(format: "%+.0f%%", ratio))
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                            Text("较上期")
                                .font(.system(size: 10))
                                .foregroundStyle(Ledger.inkSoft)
                            Spacer()
                        }
                        .foregroundStyle(delta >= 0 ? Color.gsGreen : Color.gsRed)
                    }
                    HStack(spacing: 0) {
                        overviewMetric("工时", "\(Cal.num(monthStats.hours))", "H")
                        overviewMetric("出勤", "\(Cal.num(monthStats.days))", "天")
                        overviewMetric("日均", Cal.num(monthStats.days > 0 ? monthStats.hours / monthStats.days : 0), "H")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ledger.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Ledger.rule, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(store.pageMotion ? .snappy(duration: 0.26) : nil, value: month)
    }

    private func overviewMetric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Ledger.ink)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(Ledger.inkSoft)
            }
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Ledger.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 38, height: 38)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
        }
        .buttonStyle(PressableStyle())
    }

    private func moveMonth(_ delta: Int, animated: Bool = true) {
        let next = Cal.monthAdd(year, month, delta)
        let apply = {
            year = next.year
            month = next.month
            selected = String(format: "%04d-%02d-01", next.year, next.month)
        }
        // 横滑翻页本身就有位移感，数据再补一段动画会跟 ScrollView 的复位打架，闪一下
        if animated { withAnimation(.snappy(duration: 0.26)) { apply() } } else { apply() }
    }

    private func jumpToday() {
        let t = Cal.todayKey()
        year = Cal.year(t)
        month = Cal.month(t)
        selected = t
    }

    // MARK: 月历

    private var calendarCard: some View {
        MonthCalendar(year: year, month: month, selected: selected,
                      palette: palette, preferRecordedShift: true,
                      onPick: { key in
                          withAnimation(.snappy(duration: 0.16)) { selected = key }
                      },
                      onStep: { delta in moveMonth(delta, animated: false) },
                      onCellFrame: { key, f in
                          guard key == selected else { return }
                          cellFrame = f
                          store.editingOrigin = f
                      })
    }

    @ViewBuilder
    private func shiftMark(_ shift: ShiftClass) -> some View {
        switch store.settings.classDisplay {
        case "hide":
            EmptyView()
        case "text":
            Text(shift.name)
                .font(.system(size: 9))
                .foregroundStyle(Color.gsSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        default:
            Image(systemName: shift.symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.primary)
        }
    }

    private func rightTag(_ key: String) -> (name: String, color: Color)? {
        if let holiday = Cal.holidayName(key) {
            return (holiday, Color.gsRed)
        }
        if Cal.isMakeupWorkday(key) {
            return ("班", Color.gsGreen)
        }
        if store.settings.payday > 0 && Cal.day(key) == store.settings.payday {
            return ("薪", Color.gsOrange)
        }
        if Cal.isWeekend(key) {
            return ("休", Color.secondary)
        }
        return nil
    }

    // MARK: 月统计

    private var summaryCard: some View {
        HStack(spacing: 8) {
            StatTile(value: "\(Cal.num(monthStats.hours))H", label: "总工时", color: Color.primary, palette: palette)
            StatTile(value: "\(Cal.num(monthStats.days))天", label: "出勤", palette: palette)
            StatTile(value: Cal.money(monthStats.pay), label: "实发工资",
                     color: Color.gsOrange, palette: palette)
        }
    }

    // MARK: 选中日详情

    private var dayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Cal.shortDate(selected))
                        .font(.system(size: 20, weight: .bold))
                        .contentTransition(.numericText(countsDown: true))
                    HStack(spacing: 6) {
                        Text(Cal.weekdayName(selected))
                        if selected == today { Text("· 今天") }
                        if store.settings.showLunar { Text("· " + Cal.lunarFull(selected)) }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
                }
                Spacer(minLength: 8)
                if let rec = selectedRecord {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Cal.money(store.dayPay(rec)))
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.gsOrange)
                            .contentTransition(.numericText())
                        Text("当天合计")
                            .font(.system(size: 9))
                            .foregroundStyle(Ledger.inkSoft)
                    }
                    Button {
                        openEditor()
                    } label: {
                        Text("编辑")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Ledger.ink.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            if let rec = selectedRecord {
                recordDetail(rec)
            } else {
                noRecordDetail
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: selected)
        .glassCard(radius: store.settings.cardRadius)
        // 擦除放在玻璃卡之后：连底色和边框一起擦，不是只擦字
        .mask(alignment: .leading) {
            Rectangle().scaleEffect(x: wipe, anchor: .leading)
        }
    }

    @ViewBuilder
    private func recordDetail(_ rec: DayRecord) -> some View {
        HStack(spacing: 6) {
            if let shift = store.shiftClass(rec.classId) {
                Label(shift.name, systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(palette.primary.opacity(0.12)))
            }
            Text(store.project(rec.projectId).name)
                .font(.system(size: 12))
                .foregroundStyle(Color.gsSecondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .glassCapsule()
            Spacer()
            Text(Cal.kindName(rec.type))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.gsSecondary)
        }

        HStack(spacing: 8) {
            hourBox("正班", rec.work.zb)
            hourBox("加班", rec.work.jb)
            hourBox("周末", rec.work.zm)
            hourBox("节假", rec.work.jj)
        }

        if let leave = rec.leave {
            detailRow("\(Cal.leaveName(leave.type))", "\(Cal.num(leave.hour)) 小时 · 倍率 \(Cal.num(leave.multiple))")
        }
        if rec.settle > 0 {
            detailRow("日结", Cal.money(rec.settle))
        }
        if !rec.bt.isEmpty {
            Text("补扣明细")
                .font(.system(size: 11))
                .foregroundStyle(Color.gsSecondary)
        }
        ForEach(rec.bt) { b in
            detailRow(b.name.isEmpty ? "补贴" : b.name,
                      b.money >= 0 ? Cal.money(b.money) : "-" + Cal.money(-b.money))
        }
        if !rec.note.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.gsSecondary)
                    .padding(.top, 1)
                Text(rec.note)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.primary.opacity(0.07))
            }
        }

    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            MagneticActionButton(
                title: selectedRecord == nil ? "记一笔 · \(Cal.shortDate(selected))" : "编辑这天",
                icon: selectedRecord == nil ? "plus" : "pencil",
                palette: palette,
                magnetic: store.pageMotion
            ) {
                openEditor()
            }

            if selectedRecord != nil {
                Button {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gsRed)
                        .frame(width: 52, height: 48)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Ledger.ink.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Ledger.rule, lineWidth: 0.8))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        // 底部条完全透明，不再垫毛玻璃或分隔线，页面背景一路透到底
        .background(Color.clear)
    }

    private var noRecordDetail: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.primary)
                Text(store.plan(selected).isEmpty ? "这天还没有记录" : "这天排了 \(store.shiftClass(store.plan(selected))?.name ?? "班")，还没记工时")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.gsSecondary)
                Spacer()
            }
        }
    }

    private func hourBox(_ title: String, _ value: Double) -> some View {
        VStack(spacing: 3) {
            Text(Cal.num(value))
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? Color.primary : Color.secondary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.gsSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.gsSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - 编辑页浮层

/// 从日历格子原地放大成整页：起始缩到格子大小并贴住它，spring 到满屏；关掉时反向缩回去。
/// 用浮层而不是 sheet —— sheet 是独立层级，做不了和格子的连贯放大。
struct DayEditorStage: View {
    var date: String
    var palette: Palette
    var origin: CGRect
    var onClose: () -> Void

    @EnvironmentObject private var store: Store
    @State private var open = false
    @State private var closing = false

    var body: some View {
        GeometryReader { geo in
            let full = geo.frame(in: .global)
            let startScale = origin.width > 4
                ? max(0.07, min(1, origin.width / max(1, full.width)))
                : 0.9

            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(open ? 0.32 : 0)
                    .ignoresSafeArea()
                    .onTapGesture { if store.pageMotion { close() } }

                DayEditor(date: date, palette: palette, onClose: close)
                    .frame(width: full.width, height: full.height)
                    .clipShape(RoundedRectangle(cornerRadius: open ? 26 : 12, style: .continuous))
                    .scaleEffect(open ? 1 : startScale, anchor: .topLeading)
                    .offset(x: open ? 0 : origin.minX - full.minX,
                            y: open ? 0 : origin.minY - full.minY)
                    .opacity(open ? 1 : 0.55)
            }
        }
        .onAppear {
            guard store.pageMotion else {
                open = true
                return
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { open = true }
        }
    }

    private func close() {
        guard !closing else { return }
        closing = true
        guard store.pageMotion else {
            onClose()
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) { open = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { onClose() }
    }
}
