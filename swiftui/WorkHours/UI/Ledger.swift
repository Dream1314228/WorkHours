import SwiftUI
import UIKit

// MARK: - 账本色板
//
// 不用渐变和玻璃，走纸面 + 墨线 + 红蓝记账色。
// 数字一律等宽，金额右对齐，像真的账页。

enum Ledger {
    static let paper = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.082, blue: 0.09, alpha: 1)
            : UIColor(red: 0.988, green: 0.976, blue: 0.945, alpha: 1)
    })
    static let paperDeep = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.118, blue: 0.128, alpha: 1)
            : UIColor(red: 0.965, green: 0.949, blue: 0.910, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.89, blue: 0.85, alpha: 1)
            : UIColor(red: 0.105, green: 0.098, blue: 0.086, alpha: 1)
    })
    static let inkSoft = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.61, blue: 0.57, alpha: 1)
            : UIColor(red: 0.42, green: 0.40, blue: 0.36, alpha: 1)
    })
    static let rule = ink.opacity(0.13)
    static let ruleStrong = ink.opacity(0.42)

    /// 补贴、加班：账本红字
    static let red = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.50, blue: 0.44, alpha: 1)
            : UIColor(red: 0.60, green: 0.16, blue: 0.13, alpha: 1)
    })
    /// 扣款、请假：墨绿
    static let green = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.78, blue: 0.62, alpha: 1)
            : UIColor(red: 0.13, green: 0.36, blue: 0.26, alpha: 1)
    })
    /// 主色：墨蓝
    static let blue = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.74, blue: 0.88, alpha: 1)
            : UIColor(red: 0.12, green: 0.22, blue: 0.36, alpha: 1)
    })
}

// MARK: - 纸面背景

struct LedgerPaper: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Ledger.paper
            // 每 28pt 一条极淡的横线，像账本的行
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    ctx.stroke(path, with: .color(Ledger.ink.opacity(scheme == .dark ? 0.045 : 0.035)),
                               lineWidth: 0.5)
                    y += 28
                }
            }
            // 左侧装订阴影
            LinearGradient(colors: [Ledger.ink.opacity(0.06), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 18)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 基础件

struct LedgerRule: View {
    var strong = false
    var body: some View {
        Rectangle()
            .fill(strong ? Ledger.ruleStrong : Ledger.rule)
            .frame(height: strong ? 1 : 0.6)
    }
}

/// 账页卡：4pt 小圆角、墨线描边、纸面，不用玻璃
struct LedgerCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Ledger.paper)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Ledger.rule, lineWidth: 0.8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 等宽金额
struct AmountText: View {
    var text: String
    var size: CGFloat = 17
    var color: Color = Ledger.ink
    var weight: Font.Weight = .semibold

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText())
    }
}

/// 账页表头：小字 + 右对齐
struct LedgerCaption: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(Ledger.inkSoft)
    }
}

// MARK: - 大卡片堆叠

struct LedgerStackItem: Identifiable {
    let id = UUID()
    var title: String
    var caption: String
    var big: String
    var foot: String
    var tint: Color
}

/// 叠着的大卡片，点一下展开成三张，再点收回。
struct LedgerStack: View {
    var items: [LedgerStackItem]
    @State private var expanded = false

    private let cardHeight: CGFloat = 148

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(items.enumerated().reversed()), id: \.element.id) { index, item in
                card(item)
                    .scaleEffect(expanded ? 1 : 1 - CGFloat(index) * 0.035, anchor: .top)
                    .offset(y: expanded ? CGFloat(index) * (cardHeight + 12) : CGFloat(index) * 11)
                    .opacity(expanded ? 1 : (index == 0 ? 1 : 0.6))
                    .zIndex(Double(items.count - index))
                    .rotation3DEffect(.degrees(expanded ? 0 : Double(index) * -1.2),
                                      axis: (x: 1, y: 0, z: 0), anchor: .top)
            }
        }
        .frame(height: expanded ? CGFloat(items.count) * (cardHeight + 12) - 12 : cardHeight,
               alignment: .top)
        .onTapGesture {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                expanded.toggle()
            }
        }
    }

    private func card(_ item: LedgerStackItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LedgerCaption(text: item.title)
                Spacer()
                LedgerCaption(text: item.caption)
            }
            LedgerRule(strong: true)

            Text(item.big)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(item.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())

            HStack {
                Text(item.foot)
                    .font(.system(size: 12))
                    .foregroundStyle(Ledger.inkSoft)
                Spacer()
                Text(expanded ? "收起" : "展开")
                    .font(.system(size: 11))
                    .foregroundStyle(Ledger.inkSoft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cardHeight)
        .background(Ledger.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Ledger.rule, lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}

// MARK: - 账目行

struct LedgerRow: View {
    var date: String
    var weekday: String
    var title: String
    var detail: String
    var amount: String
    var amountColor: Color = Ledger.ink
    var selected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 2) {
                    Text(date)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(Ledger.ink)
                    Text(weekday)
                        .font(.system(size: 10))
                        .foregroundStyle(Ledger.inkSoft)
                }
                .frame(width: 46, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Ledger.ink)
                        .lineLimit(1)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(Ledger.inkSoft)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                AmountText(text: amount, size: 14, color: amountColor)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(selected ? Ledger.ink.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.99))
    }
}
