import SwiftUI

struct MeView: View {
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var page: String?
    @State private var showWage = false
    @State private var showImporter = false
    @State private var shareURL: URL?
    @State private var pendingBackup: [String: Any]?
    @State private var showImportConfirm = false
    @State private var showClear = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                GSHeaderBlock(title: "我的", subtitle: "工时记录 · 本地数据", contentHeight: 100)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        profile.padding(.horizontal, 18).offset(y: -8)
                        section("记录与薪资")
                        menu([
                        ("doc.text.fill", "记录设置", GSTheme.color(for: store.themeKey), { page = "record" }),
                        ("wallet.pass.fill", "薪资与项目", GSTheme.color(for: store.themeKey), { page = "salary" }),
                        ("function", "工资计算器", GSSuccessColor(), { showWage = true }),
                        ("square.grid.2x2.fill", "班次管理", GSColorHex("#6941C6"), { page = "classes" }),
                        ("clock.fill", "考勤周期", GSSuccessColor(), { page = "period" })
                        ])
                        section("个性化")
                        menu([("gearshape.fill", "软件设置", GSTheme.color(for: store.themeKey), { page = "software" })])
                        section("数据")
                        menu([
                        ("square.and.arrow.up.fill", "导出备份 .gsjilu", GSSuccessColor(), exportData),
                        ("square.and.arrow.down.fill", "导入 .gsjilu 备份", GSTheme.color(for: store.themeKey), { showImporter = true }),
                        ("trash.fill", "清空记录", GSDangerColor(), { showClear = true })
                        ])
                        Text("工时记录 \(GSAppInfo.version) · 数据只存在本机")
                        .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                        .frame(maxWidth: .infinity)
                        Color.clear.frame(height: 20)
                    }
                }
            }
            .background(GSPageBackground().ignoresSafeArea())
            .navigationBarHidden(true)
            .background(
                NavigationLink(destination: SettingsPage(page: page ?? "record"), isActive: Binding(
                    get: { page != nil },
                    set: { if !$0 { page = nil } }
                )) { EmptyView() }
            )
            .background(
                NavigationLink(destination: WageCalculatorView(), isActive: $showWage) { EmptyView() }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showImporter) {
            GSDocumentPicker { url in handleImport(url) }
        }
        .sheet(item: Binding(get: { shareURL.map { IdentifiedURL(url: $0) } }, set: { shareURL = $0?.url })) { item in
            GSShareSheet(items: [item.url])
        }
        .alert(isPresented: Binding(
            get: { showImportConfirm || showClear },
            set: { if !$0 { showImportConfirm = false; showClear = false } }
        )) {
            if showImportConfirm {
                return Alert(
                    title: Text("导入备份"),
                    message: Text("导入会覆盖当前的项目、班次、设置和全部工时记录。建议先导出当前备份。"),
                    primaryButton: .destructive(Text("覆盖导入")) {
                        if let b = pendingBackup {
                            if store.importBackupData(b) {
                                GSReminder.syncFromSettings()
                                toast.show("备份已导入")
                            } else {
                                toast.show("备份格式不对，未导入")
                            }
                        }
                        pendingBackup = nil
                    },
                    secondaryButton: .cancel(Text("取消")) { pendingBackup = nil }
                )
            }
            return Alert(
                title: Text("清空记录"),
                message: Text("清空全部工时和排班？项目、班次、设置会保留。"),
                primaryButton: .destructive(Text("清空")) {
                    store.clearAllRecords()
                    toast.show("记录已清空")
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var profile: some View {
        GSCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(GSTheme.color(for: store.themeKey))
                    Text("工").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("工时记录").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    Text("本地数据 · 未登录").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                }
                Spacer()
                Text("本地")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GSTheme.color(for: store.themeKey))
                    .frame(width: 38, height: 22)
                    .background(GSTheme.softColor(for: store.themeKey))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private func section(_ title: String) -> some View {
        Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(GSTextTertiary())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
    }

    private func menu(_ rows: [(String, String, Color, () -> Void)]) -> some View {
        GSCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    GSRowButton(icon: r.0, title: r.1, color: r.2, action: r.3)
                    if i < rows.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private func exportData() {
        do {
            shareURL = try GSBackup.exportData()
        } catch {
            toast.show("备份生成失败")
        }
    }

    private func handleImport(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { toast.show("读不到这个文件"); return }
        guard let obj = GSBackup.parse(data) else { toast.show("不是有效的 .gsjilu 备份"); return }
        pendingBackup = obj
        showImportConfirm = true
    }
}
