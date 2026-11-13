import SwiftUI
import UniformTypeIdentifiers

/// 直接用 UIDocumentPicker，避免 SwiftUI fileImporter 在 TabView 里偶发弹不出来、
/// 或者自定义扩展名 .gsjilu 被置灰选不了。asCopy 让文件先复制到沙盒临时目录，
/// 之后不需要再处理 security-scoped 资源。
struct DocumentPicker: UIViewControllerRepresentable {
    var types: [UTType] = [.item]
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // 取消就什么都不做，保留导入入口
        }
    }
}
