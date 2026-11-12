import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Helpers

func GSMotionEnabled(_ store: GSStore, reduceMotion: Bool) -> Bool {
    store.animations && !reduceMotion
}

struct GSPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    private var animatedOverride: Bool? = nil
    @EnvironmentObject var store: GSStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(animated: Bool, scale: CGFloat = 0.97) {
        self.animatedOverride = animated
        self.scale = scale
    }

    init(scale: CGFloat = 0.97) {
        self.animatedOverride = nil
        self.scale = scale
    }

    func makeBody(configuration: Configuration) -> some View {
        let on = animatedOverride ?? GSMotionEnabled(store, reduceMotion: reduceMotion)
        return configuration.label
            .scaleEffect(on && configuration.isPressed ? scale : 1)
            .animation(on ? .easeOut(duration: 0.16) : nil, value: configuration.isPressed)
    }
}

// MARK: - Existing Views

struct GSCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content
    @EnvironmentObject var store: GSStore

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: store.cardRadius, style: .continuous))
            .shadow(color: store.cardShadow ? Color.black.opacity(0.06) : .clear, radius: store.cardShadow ? 10 : 0, x: 0, y: 4)
    }
}

struct GSHeaderBlock<Content: View>: View {
    var contentHeight: CGFloat
    var content: Content
    @EnvironmentObject var store: GSStore

    init(contentHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.contentHeight = contentHeight
        self.content = content()
    }

    init(title: String, subtitle: String? = nil, trailing: AnyView? = nil, contentHeight: CGFloat = 170) where Content == GSHeaderTitleChrome {
        self.init(contentHeight: contentHeight) {
            GSHeaderTitleChrome(title: title, subtitle: subtitle, trailing: trailing)
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: contentHeight)
            .gsHeaderChrome(radius: store.headerRadius) {
                ZStack {
                    LinearGradient(
                        colors: [GSTheme.color(for: store.themeKey), GSTheme.darkColor(for: store.themeKey)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Circle().fill(Color.white.opacity(0.10)).frame(width: 160, height: 160).offset(x: 180, y: -40)
                    Circle().fill(Color.white.opacity(0.08)).frame(width: 90, height: 90).offset(x: 40, y: -50)
                }
            }
    }
}

struct GSHeaderTitleChrome: View {
    var title: String
    var subtitle: String?
    var trailing: AnyView?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title).font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(verbatim: subtitle).font(.system(size: 12, weight: .regular)).foregroundColor(Color.white.opacity(0.92))
                }
            }
            Spacer()
            if let trailing = trailing { trailing }
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct GSHeaderShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: radius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - radius), control: CGPoint(x: 0, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct GSStatBox: View {
    var value: String
    var label: String
    var color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundColor(GSTextSecondary())
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(GSColorHex("#F2F6FF"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct GSDonutChart: View {
    var values: [Double]
    var colors: [Color]
    var centerTitle: String
    var centerSubtitle: String
    var size: CGFloat = 112

    var body: some View {
        let total = max(values.reduce(0, +), 0.0001)
        ZStack {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                let start = values.prefix(i).reduce(0, +) / total
                CircSlice(start: start, fraction: v / total)
                    .fill(colors[min(i, colors.count - 1)])
            }
            Circle().fill(Color.white).frame(width: size * 0.62, height: size * 0.62)
            VStack(spacing: 2) {
                Text(centerTitle).font(.system(size: 14, weight: .bold)).foregroundColor(GSTextPrimary())
                Text(centerSubtitle).font(.system(size: 9)).foregroundColor(GSTextSecondary())
            }
        }
        .frame(width: size, height: size)
    }
}

struct CircSlice: Shape {
    var start: Double
    var fraction: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let s = Angle(degrees: -90 + start * 360)
        let e = Angle(degrees: -90 + (start + fraction) * 360)
        p.addArc(center: c, radius: r, startAngle: s, endAngle: e, clockwise: false)
        p.addLine(to: c)
        p.closeSubpath()
        return p
    }
}

struct GSTrendChart: View {
    var values: [Double]
    var labels: [String]
    var lineColor: Color

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 1)
            let w = geo.size.width
            let h = geo.size.height - 16
            let n = max(values.count - 1, 1)
            Path { path in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) / CGFloat(n) * w
                    let y = h - CGFloat(v / maxV) * (h - 8)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            ForEach(Array(labels.enumerated()), id: \.offset) { i, lab in
                let x = CGFloat(i) / CGFloat(n) * w
                Text(lab).font(.system(size: 9)).foregroundColor(GSTextSecondary())
                    .position(x: x, y: geo.size.height - 4)
            }
        }
    }
}

final class GSToastCenter: ObservableObject {
    @Published var message: String = ""
    @Published var visible: Bool = false
    private var work: DispatchWorkItem?

    func show(_ text: String) {
        work?.cancel()
        message = text
        withAnimation(.easeOut(duration: 0.2)) { visible = true }
        let item = DispatchWorkItem { [weak self] in
            withAnimation(.easeIn(duration: 0.22)) { self?.visible = false }
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3, execute: item)
    }
}

struct GSToastBanner: View {
    @EnvironmentObject var toast: GSToastCenter
    var body: some View {
        VStack {
            Spacer()
            if toast.visible && !toast.message.isEmpty {
                Text(toast.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.06, opacity: 0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                    .padding(.bottom, 106)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}

struct GSShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct GSDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .json], asCopy: true)
        p.allowsMultipleSelection = false
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}

// MARK: - Glass Tab Bar

struct GSGlassBarBackground: View {
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 26, style: .continuous) }

    var body: some View {
        // Liquid Glass is iOS 26+. Prefer `.regular.interactive()`; if an SDK build
        // rejects `.interactive()`, switch the iOS 26 branch to `.glassEffect(.regular, in: shape)`.
        if #available(iOS 26.0, *) {
            shape.fill(Color.clear)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }
}

struct GSGlassTabBar: View {
    @Binding var selected: Int
    @EnvironmentObject var store: GSStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let titles = ["记录", "统计", "排班", "我的"]
    private let icons = ["calendar", "chart.bar.fill", "square.grid.2x2", "person.fill"]

    @State private var dragging = false
    @State private var dragIndex = 0
    @State private var dragX: CGFloat?
    @State private var bouncingIcon: Int?
    @State private var bounceWork: DispatchWorkItem?

    private var motionOn: Bool { GSMotionEnabled(store, reduceMotion: reduceMotion) }
    private var highlightIndex: Int { dragging ? dragIndex : selected }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let tabWidth = width / 4

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GSTheme.softColor(for: store.themeKey))
                    .frame(width: tabWidth - 12, height: geo.size.height - 12)
                    .offset(x: CGFloat(selected) * tabWidth + 6, y: 6)
                    .opacity(dragging ? 0 : 1)
                    .animation(motionOn ? .spring(response: 0.26, dampingFraction: 0.84) : nil, value: selected)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GSTheme.softColor(for: store.themeKey))
                    .frame(width: tabWidth - 12, height: geo.size.height - 12)
                    .offset(x: dragPillOffset(tabWidth: tabWidth), y: 6)
                    .opacity(dragging ? 1 : 0)

                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        Button {
                            selectTab(i, hapticIfChanged: true)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: icons[i])
                                    .font(.system(size: 20, weight: .semibold))
                                    .scaleEffect(bouncingIcon == i ? 0.86 : 1)
                                Text(titles[i])
                                    .font(.system(size: 11, weight: highlightIndex == i ? .semibold : .medium))
                            }
                            .foregroundColor(highlightIndex == i ? GSTheme.color(for: store.themeKey) : GSTextSecondary())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let idx = tabIndex(at: value.location.x, width: width)
                        if !dragging {
                            dragging = true
                            dragIndex = idx
                            dragX = clampDragX(value.location.x, tabWidth: tabWidth, width: width)
                            return
                        }
                        dragX = clampDragX(value.location.x, tabWidth: tabWidth, width: width)
                        if idx != dragIndex {
                            dragIndex = idx
                            GSHaptic()
                        }
                    }
                    .onEnded { value in
                        let idx = tabIndex(at: value.location.x, width: width)
                        dragging = false
                        dragX = nil
                        selectTab(idx, hapticIfChanged: false)
                    }
            )
        }
        .frame(height: 64)
        .background(GSGlassBarBackground())
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func tabIndex(at x: CGFloat, width: CGFloat) -> Int {
        let w = max(1, width / 4)
        return min(3, max(0, Int(floor(max(0, min(width - 0.001, x)) / w))))
    }

    private func selectTab(_ i: Int, hapticIfChanged: Bool) {
        if hapticIfChanged && i != selected { GSHaptic() }
        if motionOn {
            bounceWork?.cancel()
            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                bouncingIcon = i
            }
            selected = i
            let work = DispatchWorkItem {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
                    self.bouncingIcon = nil
                }
            }
            bounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: work)
        } else {
            bounceWork?.cancel()
            bouncingIcon = nil
            selected = i
        }
    }

    private func dragPillOffset(tabWidth: CGFloat) -> CGFloat {
        if let dragX = dragX {
            return dragX - (tabWidth - 12) / 2
        }
        return CGFloat(selected) * tabWidth + 6
    }

    private func clampDragX(_ x: CGFloat, tabWidth: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, tabWidth / 2), width - tabWidth / 2)
    }
}

// MARK: - Row Button & Field Row

struct GSRowButton: View {
    var icon: String
    var title: String
    var color: Color
    var action: () -> Void
    @EnvironmentObject var store: GSStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.12))
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(color)
                }
                .frame(width: 30, height: 30)
                Text(title).font(.system(size: 16)).foregroundColor(GSTextPrimary())
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(GSTextSecondary())
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(GSPressButtonStyle(animated: GSMotionEnabled(store, reduceMotion: reduceMotion)))
    }
}

struct GSFieldRow: View {
    var title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad
    var body: some View {
        HStack {
            Text(title).font(.system(size: 14)).foregroundColor(GSTextStrong())
            TextField("", text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(GSTextPrimary())
        }
        .frame(height: 44)
    }
}
