import WidgetKit
import SwiftUI
import ActivityKit

@main
struct WorkHoursWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkIslandWidget()
    }
}

struct WorkIslandWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkIslandAttributes.self) { context in
            LockScreenCard(state: context.state, dateKey: context.attributes.dateKey)
                .activityBackgroundTint(IslandPalette.bg(context.state.style))
                .activitySystemActionForegroundColor(IslandPalette.ink(context.state.style))
        } dynamicIsland: { context in
            let s = context.state
            let accent = IslandPalette.accent(s.style)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Circle().fill(accent).frame(width: 6, height: 6)
                        Text(s.shift.isEmpty ? "工时" : s.shift)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(percentText(s))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(IslandPalette.ink(s.style).opacity(0.6))
                }
                DynamicIslandExpandedRegion(.center) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(money(s.todayPay))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("今日")
                            .font(.system(size: 9))
                            .foregroundStyle(IslandPalette.ink(s.style).opacity(0.45))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: progressValue(s))
                            .tint(accent)
                        HStack(spacing: 0) {
                            ForEach(Array(rows(s).prefix(4).enumerated()), id: \.offset) { _, item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.0.name)
                                        .font(.system(size: 9))
                                        .foregroundStyle(IslandPalette.ink(s.style).opacity(0.45))
                                    Text(item.1)
                                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(IslandPalette.ink(s.style).opacity(0.92))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(accent)
                    Text(compactText(s, s.compactLeading))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
            } compactTrailing: {
                Text(compactText(s, s.compactTrailing))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(IslandPalette.ink(s.style))
                    .lineLimit(1)
            } minimal: {
                Text(percentText(s))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}

// MARK: - 锁屏卡片

struct LockScreenCard: View {
    var state: WorkIslandAttributes.ContentState
    var dateKey: String

    private var accent: Color { IslandPalette.accent(state.style) }
    private var ink: Color { IslandPalette.ink(state.style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(shortDate(dateKey))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.7))
                Spacer(minLength: 6)
                Text(percentText(state))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(ink.opacity(0.5))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(money(state.todayPay))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(hours(state.todayHours)) / \(hours(state.need)) 小时")
                    .font(.system(size: 12))
                    .foregroundStyle(ink.opacity(0.6))
                Spacer(minLength: 0)
            }

            ProgressView(value: progressValue(state))
                .tint(accent)

            HStack(spacing: 0) {
                ForEach(Array(rows(state).prefix(4).enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0.name)
                            .font(.system(size: 10))
                            .foregroundStyle(ink.opacity(0.45))
                        Text(item.1)
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(ink.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - 配色

enum IslandPalette {
    static func accent(_ style: String) -> Color {
        switch style {
        case "gold": return Color(red: 0.95, green: 0.76, blue: 0.31)
        case "green": return Color(red: 0.36, green: 0.83, blue: 0.53)
        case "blue": return Color(red: 0.47, green: 0.62, blue: 1.0)
        case "pink": return Color(red: 0.98, green: 0.55, blue: 0.68)
        default: return Color(red: 0.98, green: 0.72, blue: 0.25)
        }
    }

    static func ink(_ style: String) -> Color {
        style == "light" ? Color.black : Color.white
    }

    static func bg(_ style: String) -> Color {
        style == "light" ? Color(white: 0.97) : Color.black
    }
}

// MARK: - 取数

func money(_ v: Double) -> String {
    let r = (v * 100).rounded() / 100
    if r == r.rounded() { return "¥" + String(Int(r)) }
    return "¥" + String(format: "%.2f", r)
}

func hours(_ v: Double) -> String {
    let r = (v * 100).rounded() / 100
    if r == r.rounded() { return String(Int(r)) }
    return String(format: "%.1f", r)
}

func shortDate(_ key: String) -> String {
    guard key.count >= 10 else { return key }
    let m = Int(key.dropFirst(5).prefix(2)) ?? 0
    let d = Int(key.suffix(2)) ?? 0
    return "\(m) 月 \(d) 日"
}

func progressValue(_ s: WorkIslandAttributes.ContentState) -> Double {
    guard s.need > 0 else { return 0 }
    return min(1, max(0, s.todayHours / s.need))
}

func percentText(_ s: WorkIslandAttributes.ContentState) -> String {
    "\(Int((progressValue(s) * 100).rounded()))%"
}

func fieldValue(_ s: WorkIslandAttributes.ContentState, _ f: IslandField) -> String {
    switch f {
    case .todayHours: return hours(s.todayHours) + "H"
    case .todayPay: return money(s.todayPay)
    case .need: return hours(s.need) + "H"
    case .progress: return percentText(s)
    case .periodPay: return money(s.periodPay)
    case .monthHours: return hours(s.monthHours) + "H"
    case .monthPay: return money(s.monthPay)
    case .streak: return "\(s.streak) 天"
    case .paydayLeft: return s.paydayLeft < 0 ? "已过" : "\(s.paydayLeft) 天"
    case .shift: return s.shift.isEmpty ? "—" : s.shift
    case .project: return s.project.isEmpty ? "—" : s.project
    case .leaveLeft: return hours(s.leaveLeft) + " 天"
    }
}

func compactText(_ s: WorkIslandAttributes.ContentState, _ key: String) -> String {
    guard let f = IslandField(rawValue: key) else { return "" }
    switch f {
    case .todayHours: return hours(s.todayHours) + "H"
    case .todayPay: return money(s.todayPay)
    case .periodPay: return money(s.periodPay)
    case .monthPay: return money(s.monthPay)
    case .monthHours: return hours(s.monthHours) + "H"
    case .streak: return "\(s.streak)"
    case .paydayLeft: return "\(s.paydayLeft)"
    case .leaveLeft: return hours(s.leaveLeft)
    default: return fieldValue(s, f)
    }
}

func rows(_ s: WorkIslandAttributes.ContentState) -> [(IslandField, String)] {
    s.expanded.compactMap { raw in
        guard let f = IslandField(rawValue: raw) else { return nil }
        return (f, fieldValue(s, f))
    }
}
