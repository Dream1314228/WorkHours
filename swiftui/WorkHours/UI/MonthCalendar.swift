import SwiftUI

/// 记录页与排班页共用的月历，视觉对齐 UIKit 版 GSCalendarView：
/// 固定 42 格、纸面底、顶上一条班次图标、日期固定 17pt、农历、工时、底部小横线。
///
/// 横滑切月用「横向分页 ScrollView」实现：三页（上月 / 本月 / 下月）各占容器满宽，
/// 靠 scrollTargetBehavior(.paging) 吸附。横向和纵向是两个正交方向的 ScrollView，
/// 系统各认各的，纵向滚动不会被抢 —— 之前用 DragGesture 时正是它把纵向拖动吃掉了。
struct MonthCalendar: View {
    let year: Int
    let month: Int
    let selected: String
    let palette: Palette
    var showsHours: Bool = true
    /// 记录页传 true：有记录时优先显示记录里的班次，而不是排班
    var preferRecordedShift: Bool = false
    var onPick: (String) -> Void
    var onStep: ((Int) -> Void)? = nil

    @EnvironmentObject private var store: Store
    /// 三页的滚动 id 就是 off：-1 上月 / 0 本月 / 1 下月，播放头停在 0
    @State private var page: Int? = 0
    /// 上一个翻页方向，用来决定新一个月从哪边滑进来
    @State private var lastDir: CGFloat = 1
    @State private var flipX: CGFloat = 0
    @State private var flipAlpha: Double = 1

    /// 表头 18 + 间距 3 + 6 行 × 58 + 5 个行距 2 + 底部 6
    private static let gridHeight: CGFloat = 386

    private var headers: [String] {
        store.settings.weekStart == 1
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(-1...1, id: \.self) { off in
                    pageGrid(off)
                        .containerRelativeFrame(.horizontal)
                        .offset(x: flipX)
                        .opacity(flipAlpha)
                        .id(off)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page, anchor: .center)
        .defaultScrollAnchor(.center)
        .scrollIndicators(.hidden)
        .frame(height: Self.gridHeight)
        .background(Ledger.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Ledger.rule, lineWidth: 0.6)
        }
        .onChange(of: page) { _, now in
            guard let now, now != 0 else { return }
            lastDir = now < 0 ? -1 : 1
            onStep?(now < 0 ? -1 : 1)
            // 月份已经换了，把播放头无声地推回中间那页
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { page = 0 }
        }
        .onChange(of: month) { _, _ in
            page = 0
            guard store.calendarMotion else { return }
            // 新一个月按刚才的翻页方向轻轻推入，替掉直接换字
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                flipX = lastDir * 13
                flipAlpha = 0.42
            }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                flipX = 0
                flipAlpha = 1
            }
        }
    }

    // MARK: 单页

    private func pageGrid(_ off: Int) -> some View {
        let m = Cal.monthAdd(year, month, off)
        let cells = buildCells(year: m.year, month: m.month)
        return VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(headers, id: \.self) { w in
                    Text(w)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Ledger.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                      spacing: 2) {
                ForEach(0..<42, id: \.self) { i in
                    if let cell = cells[i] {
                        CalendarDayCell(data: cell, index: i, selected: cell.key == selected,
                                        palette: palette, motion: store.calendarMotion,
                                        onPick: onPick)
                    } else {
                        Color.clear.frame(height: 58)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    /// 一页 42 格的数据在这里算一次。格子不再读 store，一次编辑也不会重算 126 格。
    /// 这一层只产出数据，行高/字号/超大字号降级归布局层（像素）。
    private func buildCells(year y: Int, month mo: Int) -> [DayCellData?] {
        let lead = Cal.weekStartOffset(year: y, month: mo, weekStart: store.settings.weekStart)
        let days = Cal.daysInMonth(y, mo)
        let today = Cal.todayKey()
        var out: [DayCellData?] = []
        out.reserveCapacity(42)
        for i in 0..<42 {
            let dayNum = i - lead + 1
            guard dayNum >= 1, dayNum <= days else {
                out.append(nil)
                continue
            }
            let key = String(format: "%04d-%02d-%02d", y, mo, dayNum)
            out.append(makeCell(key, dayNum, days, today))
        }
        return out
    }

    private func makeCell(_ key: String, _ dayNum: Int, _ days: Int, _ today: String) -> DayCellData {
        let rec = store.record(key)
        let isPayday = store.settings.payday > 0 && dayNum == min(store.settings.payday, days)

        // 班次：记录页优先用记录里的班次，排班页只看排班
        var clsId = store.plan(key)
        if preferRecordedShift, let r = rec, !r.classId.isEmpty { clsId = r.classId }
        let clsName = clsId.isEmpty ? nil : store.shiftClass(clsId)?.name
        let isDay = clsName.map { $0.contains("白") || $0.contains("早") } ?? false
        let isNight = clsName.map { $0.contains("中") || $0.contains("晚") || $0.contains("夜") } ?? false
        let icon: String? = clsName == nil ? nil
            : (isDay ? "sunrise.fill" : (isNight ? "moon.stars.fill" : "briefcase.fill"))

        let holidayName = Cal.holidayName(key)
        let kind = Cal.dayKind(key)
        let makeup = Cal.isMakeupWorkday(key)

        var mark = ""
        if isPayday { mark = "薪" }
        else if kind == "jj" { mark = "节" }
        else if kind == "zm" { mark = "休" }
        else if makeup { mark = "班" }

        var hours: String?
        if showsHours, let r = rec { hours = store.daySummary(r) }

        // 农历跟着"日历显示农历"开关走；关掉只留节假日名（原来这一格不看开关）
        let sub = holidayName ?? (store.settings.showLunar ? Cal.lunarCellText(key) : "")

        return DayCellData(key: key, dayNum: dayNum,
                           shiftIcon: icon, shiftName: clsName,
                           isDayShift: isDay, isNightShift: isNight,
                           subText: sub, hoursText: hours, mark: mark,
                           isPayday: isPayday, isToday: key == today,
                           useTextClass: store.settings.classDisplay == "text",
                           hasRecord: rec != nil,
                           isHoliday: holidayName != nil, isMakeupWorkday: makeup)
    }
}

/// 一格要显示的全部数据，父层算好一次，格子只负责画。
/// 四个内容字段（shiftIcon / dayNum / subText / hoursText）刻意分开给，
/// 超大字号下布局可以单独丢掉某一段而不碰计算。
/// selected 是交互态、不进这里：它一变就该只有那一格重画。
struct DayCellData: Identifiable, Hashable {
    let key: String
    let dayNum: Int
    let shiftIcon: String?
    let shiftName: String?
    let isDayShift: Bool
    let isNightShift: Bool
    let subText: String
    let hoursText: String?
    let mark: String
    let isPayday: Bool
    let isToday: Bool
    let useTextClass: Bool
    let hasRecord: Bool
    let isHoliday: Bool
    let isMakeupWorkday: Bool

    var id: String { key }
}

/// 单个日历格：固定行高，图标、日期、农历、工时各占固定高度，不会因为内容多少跳位。
private struct CalendarDayCell: View {
    /// 数据全部由父层算好；格子不读 store，也不再自己解析日期。
    let data: DayCellData
    let index: Int
    let selected: Bool
    let palette: Palette
    let motion: Bool
    let onPick: (String) -> Void

    @State private var shown = false

    private var key: String { data.key }
    private var dayNum: Int { data.dayNum }
    private var isPayday: Bool { data.isPayday }
    private var mark: String { data.mark }

    /// 选中态下的字色：发薪日不许被刷成白色，仍然是金
    private var onSelectedInk: Color { isPayday ? goldInk : palette.onPrimary }

    private var markColor: Color {
        if selected { return onSelectedInk }
        if isPayday { return gold }
        if data.isHoliday { return Color.gsRed }
        if data.isMakeupWorkday { return Color.gsGreen }
        return Ledger.inkSoft
    }

    /// 发薪日的金：亮模式取纯金（少一点褐，才不发脏），暗模式提亮
    private var gold: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.84, blue: 0.42, alpha: 1)
                : UIColor(red: 0.78, green: 0.55, blue: 0.03, alpha: 1)
        })
    }

    /// 9pt 小字用的深金：纯金压在白底上只有 2.5:1，小字会糊，这里保住金色相又把对比拉到 4.6:1
    private var goldInk: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.86, blue: 0.50, alpha: 1)
                : UIColor(red: 0.58, green: 0.40, blue: 0.02, alpha: 1)
        })
    }

    private var dayColor: Color {
        if selected { return onSelectedInk }
        if isPayday { return gold }
        return Ledger.ink
    }

    private var barColor: Color {
        if selected { return onSelectedInk }
        if isPayday { return gold }
        return palette.primary
    }

    private var showsBar: Bool {
        data.isToday || data.hasRecord || isPayday
    }

    /// 日期下面那一行：有节假日就顶掉农历，直接写节日名（父层算好）
    private var subText: String { data.subText }

    private var subColor: Color {
        if selected { return isPayday ? onSelectedInk : palette.onPrimary.opacity(0.9) }
        if isPayday { return goldInk }
        if data.isHoliday { return Color.gsRed }
        return Ledger.inkSoft
    }

    private var nightTint: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.46, green: 0.60, blue: 1.00, alpha: 1)
                : UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 1)
        })
    }

    var body: some View {
        Button {
            onPick(key)
        } label: {
            VStack(spacing: 0) {
                ZStack { shiftTop }
                    .frame(height: 13)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.5)

                Text("\(dayNum)")
                    .font(.system(size: 17, weight: selected ? .bold : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(dayColor)
                    .shadow(color: isPayday && !selected ? gold.opacity(0.28) : .clear,
                            radius: 2.5)
                    .frame(height: 21)

                Text(subText)
                    .font(.system(size: 9, weight: isPayday ? .semibold : .regular))
                    .foregroundStyle(subColor)
                    .frame(height: 11)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Group {
                    if let hours = data.hoursText {
                        Text(hours)
                            .font(.system(size: 9, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(selected ? onSelectedInk : (isPayday ? gold : palette.primary))
                            .shadow(color: isPayday && !selected ? gold.opacity(0.22) : .clear,
                                    radius: 2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(height: 11)

                Spacer(minLength: 0)

                Capsule()
                    .fill(barColor)
                    .frame(width: isPayday ? 20 : 16, height: isPayday ? 3 : 2.5)
                    .shadow(color: isPayday && !selected ? gold.opacity(0.6) : .clear, radius: 4)
                    .opacity(showsBar ? 1 : 0)
                    .padding(.bottom, 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    // 发薪日选中时改成主题色浅底：实心色块上金字看不清，浅底才留得住金色
                    .fill(selected ? (isPayday ? palette.primary.opacity(0.16) : palette.primary)
                                   : Color.clear)
                    .overlay {
                        if selected && isPayday {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(palette.primary.opacity(0.55), lineWidth: 1.2)
                        }
                    }
                    .shadow(color: selected ? palette.primary.opacity(isPayday ? 0.12 : 0.30) : .clear,
                            radius: 8, x: 0, y: 4)
            }
            .overlay(alignment: .topTrailing) {
                if !mark.isEmpty {
                    Text(mark)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(markColor)
                        // 往里收，别压在选中态的圆角上
                        .padding(.top, 3)
                        .padding(.trailing, 5)
                }
            }
            // 选中时整格轻弹一下（背景和内容一起走，不然边缘会错开）
            .scaleEffect(selected ? 1.025 : 1)
            .animation(motion ? .spring(response: 0.3, dampingFraction: 0.66) : nil,
                       value: selected)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.93))
        .onAppear {
            guard !shown else { return }
            guard motion else {
                shown = true
                return
            }
            let delay = Double(index % 7) * 0.012 + Double(index / 7) * 0.022
            withAnimation(.spring(response: 0.42, dampingFraction: 0.7).delay(delay)) {
                shown = true
            }
        }
        .onDisappear { shown = false }
    }

    @ViewBuilder
    private var shiftTop: some View {
        if let name = data.shiftName {
            // 发薪日优先金：那天的班次图标也一律按金走，不再按白班/夜班上色
            let tint: Color = selected ? onSelectedInk
                : (isPayday ? gold : (data.isDayShift ? Color.gsOrange
                                     : (data.isNightShift ? nightTint : Ledger.inkSoft)))

            if data.useTextClass {
                Text(name)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 2)
            } else {
                Image(systemName: data.shiftIcon ?? "briefcase.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
                    .shadow(color: isPayday && !selected ? gold.opacity(0.35) : .clear, radius: 3)
            }
        } else if isPayday {
            // 发薪日没排班也留一枚金色钱币，别让这天光秃秃
            Image(systemName: "yensign.circle.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(selected ? onSelectedInk : gold)
                .shadow(color: selected ? .clear : gold.opacity(0.35), radius: 3)
        }
    }
}
