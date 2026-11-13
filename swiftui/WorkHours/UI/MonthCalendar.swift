import SwiftUI

/// 记录页与排班页共用的月历，视觉对齐 UIKit 版 GSCalendarView：
/// 固定 42 格、纸面底、顶上一条班次图标、日期固定 17pt、农历、工时、底部小横线。
/// 左右滑动切月，格子按行错开做进场动画。
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
    @State private var drag: CGFloat = 0
    @State private var axis = 0

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
        .offset(x: drag)
        .scaleEffect(1 - min(abs(drag), 150) / 2600, anchor: .center)
        .opacity(1 - min(abs(drag), 150) / 1100)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in
                    if axis == 0 {
                        axis = abs(v.translation.width) > abs(v.translation.height) ? 1 : 2
                    }
                    guard axis == 1 else { return }
                    let dx = v.translation.width
                    // 1:1 跟手，超出 110pt 后加阻尼，拖不出屏
                    if abs(dx) <= 110 {
                        drag = dx
                    } else {
                        let over = abs(dx) - 110
                        drag = (dx < 0 ? -1 : 1) * (110 + over * 0.22)
                    }
                }
                .onEnded { v in
                    let dx = v.translation.width
                    let horizontal = axis == 1
                    axis = 0
                    if horizontal, abs(drag) > 58 {
                        withAnimation(.snappy(duration: 0.24)) {
                            drag = dx < 0 ? -240 : 240
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            onStep?(dx < 0 ? 1 : -1)
                            drag = 0
                        }
                    } else {
                        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.8)) {
                            drag = 0
                        }
                    }
                }
        )
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

    /// 发薪日的金，亮色模式偏沉、暗色模式偏亮，都带一点发光。
    private var gold: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.82, blue: 0.36, alpha: 1)
                : UIColor(red: 0.72, green: 0.50, blue: 0.05, alpha: 1)
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
                    .shadow(color: isPayday && !selected ? gold.opacity(0.55) : .clear,
                            radius: 5)
                    .frame(height: 21)

                Text(Cal.lunarCellText(key))
                    .font(.system(size: 9))
                    .foregroundStyle(selected ? palette.onPrimary.opacity(0.9) : Ledger.inkSoft)
                    .frame(height: 11)
                    .lineLimit(1)

                Group {
                    if showsHours, let r = rec {
                        Text(store.daySummary(r))
                            .font(.system(size: 9, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(selected ? palette.onPrimary : (isPayday ? gold : palette.primary))
                            .shadow(color: isPayday && !selected ? gold.opacity(0.45) : .clear,
                                    radius: 4)
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
                        .foregroundStyle(markColor)
                        .shadow(color: isPayday && !selected ? gold.opacity(0.5) : .clear, radius: 4)
                        .padding(.top, 1)
                        .padding(.trailing, 3)
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
