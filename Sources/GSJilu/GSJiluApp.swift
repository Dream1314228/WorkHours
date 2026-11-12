import SwiftUI

@main
struct GSJiluApp: App {
    @StateObject private var store = GSStore.shared
    @StateObject private var toast = GSToastCenter()
    @State private var importBackup: [String: Any]?
    @State private var showImportConfirm = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(toast)
                .preferredColorScheme(.light)
                .onAppear { GSReminder.syncFromSettings() }
                .onOpenURL { url in handleIncoming(url) }
                .alert("导入备份", isPresented: $showImportConfirm) {
                    Button("取消", role: .cancel) { importBackup = nil }
                    Button("覆盖导入", role: .destructive) {
                        if let backup = importBackup {
                            if GSStore.shared.importBackupData(backup) {
                                GSReminder.syncFromSettings()
                                toast.show("备份已导入")
                            } else {
                                toast.show("备份格式不对，未导入")
                            }
                        }
                        importBackup = nil
                    }
                } message: {
                    Text("导入会覆盖当前的项目、班次、设置和全部工时记录。建议先导出当前备份。")
                }
        }
    }

    private func handleIncoming(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            toast.show("读不到这个文件"); return
        }
        guard let obj = GSBackup.parse(data) else {
            toast.show("不是有效的 .gsjilu 备份"); return
        }
        importBackup = obj
        showImportConfirm = true
    }
}
