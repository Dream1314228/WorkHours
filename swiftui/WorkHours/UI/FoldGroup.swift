import SwiftUI

/// 量内容自然高度用的。frame 压到 0 时内容仍在按 fixedSize 排，
/// 所以收起状态下也能拿到真实高度，展开时高度从 0 连续长上去。
private struct FoldHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 设置页的分类折叠壳。
///
/// 动画要点：内容从标题栏下沿「撑开」，不是从屏幕上方滑进来。
/// 做法是固定顶部对齐 + 高度插值 + 裁剪，完全不用 move 位移。
struct FoldGroup<Content: View>: View {
    let id: String
    let title: String
    let summary: String
    let defaultOpen: Bool
    let content: Content

    @State private var open: Bool
    @State private var contentHeight: CGFloat = 0

    init(id: String, title: String, summary: String,
         defaultOpen: Bool = false, @ViewBuilder content: () -> Content) {
        self.id = id
        self.title = title
        self.summary = summary
        self.defaultOpen = defaultOpen
        self.content = content()
        let key = "gs.foldset.\(id)"
        let saved = UserDefaults.standard.object(forKey: key)
        _open = State(initialValue: saved == nil ? defaultOpen : UserDefaults.standard.bool(forKey: key))
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                    open.toggle()
                }
                UserDefaults.standard.set(open, forKey: "gs.foldset.\(id)")
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 6)
                    Text(summary)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                        .lineLimit(1)
                        .opacity(open ? 0 : 1)
                        .animation(.easeInOut(duration: 0.18), value: open)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.gsSecondary)
                        .rotationEffect(.degrees(open ? 0 : -90))
                        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: open)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Ledger.paper))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Ledger.rule, lineWidth: 0.8))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(FoldPressStyle())

            VStack(spacing: 12) {
                content
            }
            .padding(.top, 10)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: FoldHeightKey.self, value: g.size.height)
                }
            )
            .frame(height: targetHeight, alignment: .top)
            .clipped()
            .opacity(open ? 1 : 0)
        }
        .onPreferenceChange(FoldHeightKey.self) { contentHeight = $0 }
    }

    /// 量到高度才走插值；一帧都没量到就退回自然高度，至少不会显示成空白
    private var targetHeight: CGFloat? {
        if !open { return 0 }
        return contentHeight > 0 ? contentHeight : nil
    }
}

/// 单张卡片的折叠壳（长文设置项用）
struct FoldCard<Content: View>: View {
    let id: String
    let title: String
    let summary: String
    let radius: CGFloat
    let content: Content

    @State private var open: Bool
    @State private var contentHeight: CGFloat = 0
    private let key: String

    init(id: String, title: String, summary: String = "", radius: CGFloat = 22,
         defaultOpen: Bool = false, @ViewBuilder content: () -> Content) {
        self.id = id
        self.title = title
        self.summary = summary
        self.radius = radius
        self.content = content()
        self.key = "gs.foldcard.\(id)"
        let saved = UserDefaults.standard.object(forKey: key)
        _open = State(initialValue: saved == nil ? defaultOpen : UserDefaults.standard.bool(forKey: key))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                    open.toggle()
                }
                UserDefaults.standard.set(open, forKey: key)
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 6)
                    Text(summary)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gsSecondary)
                        .opacity(open ? 0 : 1)
                        .animation(.easeInOut(duration: 0.18), value: open)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.gsSecondary)
                        .rotationEffect(.degrees(open ? 0 : -90))
                        .animation(.spring(response: 0.42, dampingFraction: 0.9), value: open)
                }
                .contentShape(Rectangle())
                .frame(height: 22)
            }
            .buttonStyle(FoldPressStyle())

            content
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: FoldHeightKey.self, value: g.size.height)
                    }
                )
                .frame(height: targetHeight, alignment: .top)
                .clipped()
                .opacity(open ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: radius)
        .onPreferenceChange(FoldHeightKey.self) { contentHeight = $0 }
    }

    private var targetHeight: CGFloat? {
        if !open { return 0 }
        return contentHeight > 0 ? contentHeight : nil
    }
}

/// 标题行的按压反馈：轻轻缩一点 + 压一层墨色，松手弹回。
struct FoldPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Ledger.ink.opacity(configuration.isPressed ? 0.05 : 0))
                    .allowsHitTesting(false)
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
