import SwiftUI
import UniformTypeIdentifiers
import UIKit

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

struct GSHeaderBlock: View {
    var title: String
    var subtitle: String?
    var trailing: AnyView? = nil
    @EnvironmentObject var store: GSStore

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [GSTheme.color(for: store.themeKey), GSTheme.darkColor(for: store.themeKey)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(Color.white.opacity(0.10)).frame(width: 160, height: 160).offset(x: 180, y: -40)
            Circle().fill(Color.white.opacity(0.08)).frame(width: 90, height: 90).offset(x: 40, y: -50)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                    if let subtitle = subtitle {
                        Text(subtitle).font(.system(size: 12, weight: .regular)).foregroundColor(Color.white.opacity(0.92))
                    }
                }
                Spacer()
                if let trailing = trailing { trailing }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .clipShape(GSHeaderShape(radius: store.headerRadius))
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

struct GSGlassTabBar: View {
    @Binding var selected: Int
    @EnvironmentObject var store: GSStore
    private let titles = ["记录", "统计", "排班", "我的"]
    private let icons = ["calendar", "chart.bar.fill", "square.grid.2x2", "person.fill"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                Button {
                    GSHaptic()
                    withAnimation(.easeOut(duration: 0.26)) { selected = i }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icons[i])
                            .font(.system(size: 18, weight: .semibold))
                        Text(titles[i]).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(selected == i ? GSTheme.color(for: store.themeKey) : GSTextSecondary())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 64)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

struct GSRowButton: View {
    var icon: String
    var title: String
    var color: Color
    var action: () -> Void
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
        .buttonStyle(.plain)
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
