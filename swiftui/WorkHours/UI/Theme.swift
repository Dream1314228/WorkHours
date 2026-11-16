import SwiftUI
import UIKit

// MARK: - 颜色

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        } else {
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - 语义色（跟着深浅模式反色）

extension Color {
    /// 金额、加班的橙，浅色下压深，深色下提亮
    static let gsOrange = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.71, blue: 0.30, alpha: 1)
            : UIColor(red: 0.60, green: 0.29, blue: 0.00, alpha: 1)
    })
    static let gsGreen = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.86, blue: 0.55, alpha: 1)
            : UIColor(red: 0.10, green: 0.45, blue: 0.24, alpha: 1)
    })
    static let gsRed = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.48, blue: 0.45, alpha: 1)
            : UIColor(red: 0.70, green: 0.14, blue: 0.09, alpha: 1)
    })
    /// 次要文字：浅色 #5D6B82，深色提亮，保证对比度
    static let gsSecondary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.68, green: 0.72, blue: 0.80, alpha: 1)
            : UIColor(red: 0.365, green: 0.420, blue: 0.510, alpha: 1)
    })
}

// MARK: - 主题

struct Palette {
    let key: String
    let name: String
    let primary: Color
    let deep: Color
    let onPrimary: Color
}

enum Theme {
    static let all: [(key: String, name: String)] = [
        ("blue", "海蓝"), ("teal", "青绿"), ("green", "松绿"),
        ("purple", "黛紫"), ("orange", "赤橙"), ("red", "朱红"),
        ("graphite", "石墨")
    ]

    /// 压在某个底色上的可读文字色：浅底给深字，深底给白字
    static func readableOn(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count >= 6 else { return .white }
        var v: UInt64 = 0
        Scanner(string: String(s.prefix(6))).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let lum = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        return lum > 0.22 ? Color(hex: "#12161C") : .white
    }

    static func of(_ key: String) -> Palette {
        switch key {
        case "teal":
            return Palette(key: key, name: "青绿", primary: Color(hex: "#0E9F8E"),
                           deep: Color(hex: "#087267"), onPrimary: .white)
        case "green":
            return Palette(key: key, name: "松绿", primary: Color(hex: "#2E9E5B"),
                           deep: Color(hex: "#1F7A44"), onPrimary: .white)
        case "purple":
            return Palette(key: key, name: "黛紫", primary: Color(hex: "#7A4DFF"),
                           deep: Color(hex: "#5730CC"), onPrimary: .white)
        case "orange":
            return Palette(key: key, name: "赤橙", primary: Color(hex: "#E06A00"),
                           deep: Color(hex: "#B45309"), onPrimary: .white)
        case "red":
            return Palette(key: key, name: "朱红", primary: Color(hex: "#D93A3A"),
                           deep: Color(hex: "#A82626"), onPrimary: .white)
        case "graphite":
            return Palette(key: key, name: "石墨", primary: Color(hex: "#55606F"),
                           deep: Color(hex: "#333B47"), onPrimary: .white)
        default:
            return Palette(key: "blue", name: "墨蓝", primary: Color(hex: "#1F3A5F"),
                           deep: Color(hex: "#14263D"), onPrimary: .white)
        }
    }
}

// MARK: - 背景

struct AppBackdrop: View {
    var palette: Palette

    var body: some View {
        LedgerPaper()
    }
}

// MARK: - 玻璃卡片

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat
    var tint: Color
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Ledger.paper)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Ledger.rule, lineWidth: 0.8)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    /// 液态玻璃卡片。radius 传设置里的卡片圆角。
    func glassCard(radius: CGFloat = 22, tint: Color = .clear, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(radius: radius, tint: tint, padding: padding))
    }

    /// 玻璃胶囊（按钮、标签用）
    func glassCapsule(tint: Color = .clear) -> some View {
        background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ledger.ink.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
    }
}

// MARK: - 按钮样式

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct GlassActionButtonStyle: ButtonStyle {
    var palette: Palette
    var prominent: Bool = false
    var height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if prominent {
                configuration.label
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(palette.deep)
                    )
            } else {
                configuration.label
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Ledger.ink.opacity(0.05))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Ledger.rule, lineWidth: 0.8)
                    }
            }
        }
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.spring(response: 0.26, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - 磁吸按钮

/// 按下时整块朝手指方向轻微偏移（最多 7pt），松手弹回并触发。
/// 系统 Button 拿不到触点，所以用 DragGesture(minimumDistance: 0) 自己接；
/// 视觉沿用「记一笔」原来那套深色胶囊，只是不再走 ButtonStyle。
struct MagneticActionButton: View {
    var title: String
    var icon: String
    var palette: Palette
    /// 关掉动效开关时照样能点，只是不做磁吸位移
    var magnetic: Bool = true
    var action: () -> Void

    @State private var pull: CGSize = .zero
    @State private var down = false

    private let maxX: CGFloat = 7
    private let maxY: CGFloat = 5

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(palette.onPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.deep)
        }
        .scaleEffect(down ? 0.972 : 1)
        .offset(pull)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pull)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: down)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !down { down = true }
                    guard magnetic else { return }
                    pull = CGSize(width: clamp(v.translation.width * 0.2, maxX),
                                  height: clamp(v.translation.height * 0.2, maxY))
                }
                .onEnded { _ in
                    down = false
                    pull = .zero
                    action()
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityAction { action() }
    }

    private func clamp(_ v: CGFloat, _ limit: CGFloat) -> CGFloat {
        min(limit, max(-limit, v))
    }
}

// MARK: - 小部件

struct ChipView: View {
    var title: String
    var selected: Bool
    var palette: Palette
    var color: Color? = nil
    var hex: String? = nil

    private var selectedText: Color {
        if let hex = hex { return Theme.readableOn(hex) }
        return palette.onPrimary
    }

    var body: some View {
        Group {
            if selected {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selectedText)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    // 选中态压深一档：青绿/松绿/赤橙的白字压在 primary 上只有 3.3:1，
                    // 换成 deep 后 5.0–5.8:1，主按钮也是这个色阶
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color ?? palette.deep))
            } else {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ledger.ink.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct StatTile: View {
    var value: String
    var label: String
    var color: Color = .primary
    var palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 21, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText(countsDown: true))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.gsSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ledger.paper))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
    }
}

struct SectionTitle: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.gsSecondary)
            Spacer()
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct EmptyHint: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.gsSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 22)
    }
}

/// 数字输入行
struct NumberRow: View {
    var title: String
    var unit: String = ""
    @Binding var value: Double
    var palette: Palette
    var range: ClosedRange<Double> = 0...999
    /// 数值着色（默认时长按项上色，其余行留空沿用系统色）
    var valueColor: Color? = nil

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor ?? Color.primary)
                .frame(width: 88)
                .focused($focused)
                .onAppear { text = Cal.num(value) }
                .onChange(of: text) { _, newValue in
                    let v = Double(newValue.replacingOccurrences(of: ",", with: ".")) ?? 0
                    value = min(range.upperBound, max(range.lowerBound, v))
                }
                .onChange(of: value) { _, newValue in
                    if !focused { text = Cal.num(newValue) }
                }
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
                    .frame(width: 18, alignment: .leading)
            }
        }
        .frame(height: 42)
    }
}

// MARK: - Toast

final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    enum Kind { case success, error }

    @Published var message: String?
    @Published var isError = false

    func show(_ text: String) { show(text, kind: .success) }

    /// 成功自己走，错误必须留到用户点掉：不然低头一看提示就没了，也截不到图
    func show(_ text: String, kind: Kind) {
        message = text
        isError = kind == .error
        UIAccessibility.post(notification: .announcement, argument: text)
        guard kind == .success else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { [weak self] in
            if self?.message == text {
                self?.message = nil
                self?.isError = false
            }
        }
    }

    func dismiss() {
        message = nil
        isError = false
    }
}

struct ToastOverlay: View {
    @ObservedObject var center = ToastCenter.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack {
            Spacer()
            if let m = center.message {
                VStack(alignment: .leading, spacing: 10) {
                    Text(m)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(scheme == .dark ? Color.black : Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if center.isError {
                        Button {
                            center.dismiss()
                        } label: {
                            Text("知道了")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(
                                    Capsule().fill(scheme == .dark
                                                   ? Color.black.opacity(0.10)
                                                   : Color.white.opacity(0.18))
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(scheme == .dark ? Color.black : Color.white)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: center.isError ? 16 : 22, style: .continuous)
                        .fill(scheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.86))
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 110)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: center.message)
        .allowsHitTesting(center.isError)
    }
}
