import SwiftUI

/// 设置页的分类折叠壳。
/// 收起时右边显示这组的关键值，不用点开也知道现在是什么状态。
struct FoldGroup<Content: View>: View {
    let id: String
    let title: String
    let summary: String
    let defaultOpen: Bool
    let content: Content

    @State private var open: Bool

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
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    open.toggle()
                }
                UserDefaults.standard.set(open, forKey: "gs.foldset.\(id)")
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 6)
                    if !open {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gsSecondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.gsSecondary)
                        .rotationEffect(.degrees(open ? 0 : -90))
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Ledger.paper))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Ledger.rule, lineWidth: 0.8))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 12) {
                    content
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// 单张卡片的折叠壳（设置页里只有「关于」这类长文用得上）
struct FoldCard<Content: View>: View {
    let id: String
    let title: String
    let summary: String
    let radius: CGFloat
    let content: Content

    @State private var open: Bool
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
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    open.toggle()
                }
                UserDefaults.standard.set(open, forKey: key)
            } label: {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 6)
                    if !open && !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gsSecondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.gsSecondary)
                        .rotationEffect(.degrees(open ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                content
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: radius)
    }
}
