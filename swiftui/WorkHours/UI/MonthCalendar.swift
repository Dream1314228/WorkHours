import SwiftUI

/// 记录页与排班页共用的月历，视觉对齐 UIKit 版 GSCalendarView：
/// 固定 42 格、纸面底、顶上一条班次图标、日期固定 17pt、农历、工时、底部小横线。
/// 切月靠表头的左右箭头，不在日历上挂横向拖动手势 —— 那个会把纵向滚动抢掉。
/// 格子按行错开做进场动画。
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

    private var headers: [String] {
        store.settings.weekStart == 1
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    private var lead: Int {
        let first = String(format: "%04d-%02d-01", year, month)
        return (Cal.weekday(first) - 1 - store.settings.weekStart + 7) % 7
    }

    var body: some View {
        VStack(spacing: 3) {
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
                    slot(i)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .background(Ledger.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Ledger.rule, lineWidth: 0.6)
        }
    }

    @ViewBuilder
    private func slot(_ i: Int) -> some View {
        let days = Cal.daysInMonth(year, month)
        let dayNum = i - lead + 1

        if dayNum < 1 || dayNum > days {
            Color.clear.frame(height: 58)
        } else {
            let key = String(format: "%04d-%02d-%02d", year, month, dayNum)
            CalendarDayCell(
                key: key,
                dayNum: dayNum,
                index: i,
                selected: key == selected,
                palette: palette,
                showsHours: showsHours,
                preferRecordedShift: preferRecordedShift,
                isPayday: store.settings.payday > 0 && dayNum == min(store.settings.payday, days),
                onPick: onPick
            )
        }
    }
}

/// 单个日历格：固定行高，图标、日期、农历、工时各占固定高度，不会因为内容多少跳位。
private struct CalendarDayCell: View {
    let key: String
    let dayNum: Int
    let index: Int
    let selected: Bool
    let palette: Palette
    let showsHours: Bool
    let preferRecordedShift: Bool
    let isPayday: Bool
    let onPick: (String) -> Void

    @EnvironmentObject private var store: Store
    @State private var shown = false

    private var rec: DayRecord? { store.record(key) }

    private var shift: ShiftClass? {
        let planId = store.plan(key)
        var clsId = planId
        if preferRecordedShift, let r = rec, !r.classId.isEmpty {
            clsId = r.classId
        }
        return clsId.isEmpty ? nil : store.shiftClass(clsId)
    }

    private var kind: String { Cal.dayKind(key) }

    private var mark: String {
        if isPayday { return "薪" }
        if kind == "jj" { return "节" }
        if kind == "zm" { return "休" }
        if Cal.isMakeupWorkday(key) { return "班" }
        return ""
    }

    private var markColor: Color {
        if selected { return palette.onPrimary }
        if isPayday { return gold }
        if kind == "jj" { return Color.gsRed }
        if Cal.isMakeupWorkday(key) { return Color.gsGreen }
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
        if selected { return palette.onPrimary }
        if isPayday { return gold }
        return Ledger.ink
    }

    private var barColor: Color {
        if selected { return palette.onPrimary }
        if isPayday { return gold }
        return palette.primary
    }

    private var showsBar: Bool {
        key == Cal.todayKey() || rec != nil || isPayday
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

                Text(Cal.lunarCellText(key))
                    .font(.system(size: 9, weight: isPayday ? .semibold : .regular))
                    .foregroundStyle(selected ? palette.onPrimary.opacity(0.9)
                                     : (isPayday ? goldInk : Ledger.inkSoft))
                    .frame(height: 11)
                    .lineLimit(1)

                Group {
                    if showsHours, let r = rec {
                        Text(store.daySummary(r))
                            .font(.system(size: 9, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(selected ? palette.onPrimary : (isPayday ? gold : palette.primary))
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
                    .fill(selected ? palette.primary : Color.clear)
                    .shadow(color: selected ? palette.primary.opacity(0.30) : .clear,
                            radius: 8, x: 0, y: 4)
            }
            .overlay(alignment: .topTrailing) {
                if !mark.isEmpty {
                    Text(mark)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isPayday && !selected ? goldInk : markColor)
                        // 往里收，别压在选中态的圆角上
                        .padding(.top, 3)
                        .padding(.trailing, 5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.93))
        .onAppear {
            guard !shown else { return }
            guard store.calendarMotion else {
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
        if let shift = shift {
            let name = shift.name
            let dayShift = name.contains("白") || name.contains("早")
            let nightShift = name.contains("中") || name.contains("晚") || name.contains("夜")
            let tint: Color = selected ? palette.onPrimary
                : (dayShift ? Color.gsOrange : (nightShift ? nightTint : Ledger.inkSoft))

            if store.settings.classDisplay == "text" {
                Text(name)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 2)
            } else {
                Image(systemName: dayShift ? "sunrise.fill" : (nightShift ? "moon.stars.fill" : "briefcase.fill"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }
}
