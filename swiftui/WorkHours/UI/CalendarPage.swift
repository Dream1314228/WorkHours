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
        .accessibilityLabel(icon == "chevron.left" ? "上个月" : "下个月")
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
                          // 只记在本地：滚动时这个回调每帧都来，
                          // 写 store 会整页重算，那就是卡顿的来源
                          guard key == selected else { return }
                          cellFrame = f
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
                        Text(Cal.signedMoney(store.dayPay(rec)))
                            .font(.system(size: 20, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(store.dayPay(rec) < 0 ? Color.gsRed : Color.gsOrange)
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

extension Palette: Equatable {
    /// Color 没法直接比，主题 key 是唯一的，按它判就够了
    static func == (a: Palette, b: Palette) -> Bool { a.key == b.key }
}

/// 把 DayEditor 挡在拖动重算之外：
/// 父视图每帧都在重算，而 onClose 闭包每次都是新实例，直接放进 body 会让整棵编辑器子树跟着重建，
/// 手指一拖就掉帧。这里显式声明相等条件（忽略闭包），拖动时不再进 body。
private struct EditorBox: View, Equatable {
    var date: String
    var palette: Palette
    var onClose: () -> Void
    var bottomInset: CGFloat
    var dragging: Bool

    static func == (a: EditorBox, b: EditorBox) -> Bool {
        a.date == b.date && a.bottomInset == b.bottomInset
            && a.palette == b.palette && a.dragging == b.dragging
    }

    var body: some View {
        DayEditor(date: date, palette: palette, onClose: onClose,
                  bottomInset: bottomInset, dragging: dragging)
    }
}

/// 从底部弹上来的半屏编辑页。
/// 进来：整块从屏幕外滑上来，spring 收尾带一点回弹，遮罩同时淡进来。
/// 出去：easeIn 快收，遮罩跟着淡掉；跟手拖动时两者一起走。
struct DayEditorStage: View {
    var date: String
    var palette: Palette
    var onClose: () -> Void

    @EnvironmentObject private var store: Store
    @State private var shown = false
    @State private var closing = false
    /// 实时位移放系统层：每帧重建视图时手势不会被打断，慢慢拉也不会跳
    @GestureState private var dragY: CGFloat = 0
    /// 松手后接住当前位移，再动画归位
    @State private var settle: CGFloat = 0
    /// 拖动的时候要按住里面的滚动列表，否则两边一起动，画面就在抖
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let full = geo.frame(in: .global)
            // 底部安全区要算进去，不然 sheet 停在家居条上方，底下会漏一条缝
            let bottomInset = geo.safeAreaInsets.bottom
            let sheetH = min(full.height - 56, max(420, full.height * 0.76)) + bottomInset
            let pull = max(0, dragY + settle)
            let sheetShape = UnevenRoundedRectangle(topLeadingRadius: 30,
                                                    topTrailingRadius: 30,
                                                    style: .continuous)

            ZStack(alignment: .bottom) {
                Color.black
                    .opacity(shown ? 0.36 * max(0, 1 - pull / (sheetH * 0.8)) : 0)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                // 拖的时候只留描边：阴影 + 每次重算圆角路径会把整屏重绘一遍，手感全被吃掉
                EditorBox(date: date, palette: palette, onClose: close,
                          bottomInset: bottomInset, dragging: dragging)
                    .equatable()
                    .frame(width: full.width, height: sheetH)
                    .background(sheetShape.fill(Ledger.paper))
                    .clipShape(sheetShape)
                    .overlay(alignment: .top) {
                        sheetShape.strokeBorder(Ledger.rule, lineWidth: 0.8)
                    }
                    .offset(y: shown ? pull : sheetH + 48)

                if shown && !closing {
                    dragZone(height: sheetH)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            guard store.pageMotion else {
                shown = true
                return
            }
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) { shown = true }
        }
    }

    /// 透明的接指区：固定不动，所以拖动时它不会被重建，手势也就不会断。
    /// 做得够高，手指一路往下拉到关闭阈值都还在范围内。
    /// 顶部整条都能拖：左边一直铺到边，右边 88 让给叉键。
    ///
    /// 参考 lucaszischka/BottomSheet：它把拖拽手势挂在有填充的 Capsule 上，
    /// 靠 padding 撑大命中区。透明层（Color.clear）是画不出像素的，
    /// 手势经常挂不上去 —— 这里用近乎透明的实心矩形代替，彻底避开这个坑。
    private func dragZone(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.001))
                    .frame(maxWidth: .infinity)
                    // 28 以下就是标题行：再高就把标题盖住、列表也没法从上往下滑
                    .frame(height: 28)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .updating($dragY) { v, state, _ in
                                state = max(0, v.translation.height)
                            }
                            .onChanged { _ in
                                if !dragging { dragging = true }
                            }
                            .onEnded { v in
                                let far = v.translation.height > 150
                                let fling = v.predictedEndTranslation.height > 430
                                if far || fling {
                                    settle = max(0, v.translation.height)
                                    close()
                                } else {
                                    settle = max(0, v.translation.height)
                                    DispatchQueue.main.async {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                            settle = 0
                                        }
                                    }
                                }
                                dragging = false
                            }
                    )
                Color.clear.frame(width: 88)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
    }

    private func close() {
        guard !closing else { return }
        closing = true
        guard store.pageMotion else {
            onClose()
            return
        }
        // 关的时候不再回弹，直接往下压，手感比进的时候更利落
        withAnimation(.easeIn(duration: 0.24)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onClose() }
    }
}
