import SwiftUI

/// 记录页与排班页共用的月历，视觉对齐 UIKit 版 GSCalendarView：
/// 固定 42 格、白底无边框、顶上一条班次图标、日期 17pt、农历、工时、右下小横线，选中是主题色实心块。
struct MonthCalendar: View {
    let year: Int
    let month: Int
    let selected: String
    let palette: Palette
    var showsHours: Bool = true
    var onPick: (String) -> Void

    @EnvironmentObject private var store: Store

    private let cellHeight: CGFloat = 64

    private var headers: [String] {
        store.settings.weekStart == 1
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    /// 本月 1 号前面要空几格
    private var lead: Int {
        let first = String(format: "%04d-%02d-01", year, month)
        return (Cal.weekday(first) - 1 - store.settings.weekStart + 7) % 7
    }

    private var nightColor: Color {
        Color(uiColor: UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.46, green: 0.60, blue: 1.00, alpha: 1)
                : UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 1)
        })
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(headers, id: \.self) { w in
                    Text(w)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Ledger.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                      spacing: 2) {
                ForEach(0..<42, id: \.self) { i in
                    cell(i)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .background(Ledger.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func cell(_ i: Int) -> some View {
        let days = Cal.daysInMonth(year, month)
        let dayNum = i - lead + 1

        if dayNum < 1 || dayNum > days {
            Color.clear.frame(height: cellHeight)
        } else {
            let key = String(format: "%04d-%02d-%02d", year, month, dayNum)
            let isSelected = key == selected
            let isToday = key == Cal.todayKey()
            let rec = store.record(key)
            let planId = store.plan(key)
            let shift = planId.isEmpty ? nil : store.shiftClass(planId)
            let kind = Cal.dayKind(key)
            let payday = store.settings.payday
            let isPayday = payday > 0 && dayNum == min(payday, days)
            let mark = isPayday ? "薪" : (kind == "jj" ? "节" : (kind == "zm" ? "休" : ""))
            let markColor = isSelected ? palette.onPrimary
                : (isPayday ? Color.gsOrange : (kind == "jj" ? Color.gsRed : Color.gsOrange))

            Button { onPick(key) } label: {
                VStack(spacing: 0) {
                    shiftTop(shift, isSelected: isSelected)
                        .frame(height: 13)

                    Text("\(dayNum)")
                        .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? palette.onPrimary : Ledger.ink)
                        .frame(height: 21)

                    Text(Cal.lunarCellText(key))
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? palette.onPrimary.opacity(0.88) : Ledger.inkSoft)
                        .frame(height: 11)

                    Group {
                        if showsHours, let rec {
                            Text(store.daySummary(rec))
                                .font(.system(size: 9, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? palette.onPrimary : palette.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(height: 11)

                    Spacer(minLength: 0)

                    Capsule()
                        .fill(isSelected ? palette.onPrimary : (isPayday ? Color.gsOrange : palette.primary))
                        .frame(width: 16, height: 2.5)
                        .opacity((isToday || rec != nil || isPayday) ? 1 : 0)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .frame(height: cellHeight)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isSelected ? palette.primary : Color.clear)
                        .shadow(color: isSelected ? palette.primary.opacity(0.28) : .clear,
                                radius: 8, x: 0, y: 4)
                }
                .overlay(alignment: .topTrailing) {
                    if !mark.isEmpty {
                        Text(mark)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(markColor)
                            .padding(.top, 1)
                            .padding(.trailing, 3)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(PressableStyle(scale: 0.94))
        }
    }

    @ViewBuilder
    private func shiftTop(_ shift: ShiftClass?, isSelected: Bool) -> some View {
        if let shift = shift {
            let name = shift.name
            let dayShift = name.contains("白") || name.contains("早")
            let nightShift = name.contains("中") || name.contains("晚") || name.contains("夜")
            let tint: Color = isSelected ? palette.onPrimary
                : (dayShift ? Color.gsOrange : (nightShift ? nightColor : Ledger.inkSoft))

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
