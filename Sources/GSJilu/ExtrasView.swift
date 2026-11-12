import SwiftUI

struct ExtrasView: View {
    let year: Int
    let month: Int
    var onClose: () -> Void
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var kind = "bonus"
    @State private var name = ""
    @State private var money = ""
    @State private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [GSTheme.color(for: store.themeKey), GSTheme.darkColor(for: store.themeKey)], startPoint: .top, endPoint: .bottom)
                HStack {
                    Text("补扣管理 · \(month)月").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark").foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.black.opacity(0.12)).clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
            }
            .frame(height: 88)
            .clipShape(GSHeaderShape(radius: store.headerRadius))
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 10) {
                    GSCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("新增类型").font(.system(size: 12, weight: .medium)).foregroundColor(GSTextSecondary())
                            Picker("", selection: $kind) {
                                Text("补贴").tag("bonus")
                                Text("扣款").tag("deduct")
                            }.pickerStyle(.segmented)
                        }
                    }
                    let bonusItems = store.extras(kind: "bonus", year: year, month: month)
                    let deductItems = store.extras(kind: "deduct", year: year, month: month)
                    let bonusSum = bonusItems.reduce(0.0) { $0 + GSJSONNumber($1["money"]) }
                    let deductSum = deductItems.reduce(0.0) { $0 + GSJSONNumber($1["money"]) }
                    GSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("本月补扣合计").font(.system(size: 13, weight: .medium)).foregroundColor(GSTextSecondary())
                            Text("补贴  +\(GSMoney(bonusSum))  ·  \(bonusItems.count) 笔").font(.system(size: 14, weight: .semibold)).foregroundColor(GSSuccessColor())
                            Text("扣款  -\(GSMoney(deductSum))  ·  \(deductItems.count) 笔").font(.system(size: 14, weight: .semibold)).foregroundColor(GSDangerColor())
                            Text("净额  \(GSMoney(bonusSum - deductSum))").font(.system(size: 14, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
                        }
                    }
                    GSCard {
                        VStack(alignment: .leading, spacing: 10) {
                            list(kindName: "补贴", items: bonusItems, isBonus: true)
                            Divider()
                            list(kindName: "扣款", items: deductItems, isBonus: false)
                        }
                    }
                    GSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("新增一项").font(.system(size: 13, weight: .medium)).foregroundColor(GSTextSecondary())
                            field($name, "名称，例如 社保 / 夜补")
                            field($money, "金额", keyboard: .decimalPad)
                            field($note, "备注（可选）")
                            Button("添加") { add() }
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 40)
                                .background(GSTheme.color(for: store.themeKey))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    GSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("导入上月补助和扣款") {
                                store.importLastMonthBoth(year: year, month: month)
                                toast.show("已导入上月补助和扣款")
                            }.font(.system(size: 14, weight: .semibold)).foregroundColor(GSTheme.color(for: store.themeKey))
                            Text("同时导入上月的补贴和扣款；新月份打开 App 时也会自动带入。")
                                .font(.system(size: 11)).foregroundColor(GSTextSecondary())
                        }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 18).padding(.top, 10)
            }
        }
        .background(GSPageBackground().ignoresSafeArea())
    }

    private func list(kindName: String, items: [[String: Any]], isBonus: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(kindName)明细 · \(items.count) 笔").font(.system(size: 14, weight: .bold)).foregroundColor(GSTextPrimary())
            if items.isEmpty {
                Text(isBonus ? "本月还没有补贴" : "本月还没有扣款").font(.system(size: 12)).foregroundColor(GSTextTertiary())
            }
            ForEach(Array(items.enumerated()), id: \.offset) { i, b in
                let bname = (b["name"] as? String) ?? kindName
                let noteValue = (b["note"] as? String) ?? ""
                let autoImport = GSJSONBool(b["auto"])
                let source = autoImport ? "上月自动导入" : (noteValue.isEmpty ? "手动添加" : noteValue)
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(bname).font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                        Text("\(isBonus ? "补助" : "扣款") · \(source)").font(.system(size: 10)).foregroundColor(GSTextSecondary())
                    }
                    Spacer()
                    Text("\(isBonus ? "+" : "-")\(GSMoney(abs(GSJSONNumber(b["money"]))))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isBonus ? GSSuccessColor() : GSDangerColor())
                    Button {
                        store.deleteExtra(kind: isBonus ? "bonus" : "deduct", year: year, month: month, index: i)
                    } label: {
                        Image(systemName: "trash").font(.system(size: 14)).foregroundColor(GSTextTertiary())
                    }
                }
            }
        }
    }

    private func field(_ text: Binding<String>, _ placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(GSSurfaceMuted())
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func add() {
        if name.isEmpty || (Double(money) ?? 0) <= 0 { toast.show("名称和金额要填"); return }
        store.addExtra(kind: kind, year: year, month: month, name: name, money: Double(money) ?? 0, note: note)
        toast.show("已添加")
        name = ""; money = ""; note = ""
    }
}
