import SwiftUI

struct RecordView: View {
    @EnvironmentObject var store: GSStore
    @EnvironmentObject var toast: GSToastCenter
    @State private var year: Int
    @State private var month: Int
    @State private var selectedDate: String
    @State private var showEditor = false
    @State private var showBatch = false
    @State private var confirmDelete = false

    init() {
        var d = Date()
        if GSStore.shared.boolSetting("nightMode", default: true) {
            if GSDate.gregorian.component(.hour, from: d) < 6 {
                d = d.addingTimeInterval(-86400)
            }
        }
        let key = GSDate.key(from: d)
        _selectedDate = State(initialValue: key)
        let c = GSDate.components(from: key)
        _year = State(initialValue: c.year)
        _month = State(initialValue: c.month)
    }

    var monthStats: [String: Any] {
        store.monthStats(year: year, month: month, usePeriod: false)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                header
                calendarCard
                dayCard
                timelineCard
                Color.clear.frame(height: 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $showEditor) {
            EditorView(date: selectedDate) { showEditor = false }
                .environmentObject(store)
                .environmentObject(toast)
        }
        .fullScreenCover(isPresented: $showBatch) {
            NavigationView {
                BatchView(initialKey: selectedDate) { _ in
                    showBatch = false
                }
                .environmentObject(store)
                .environmentObject(toast)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .alert(isPresented: $confirmDelete) {
            Alert(
                title: Text("删除 \(selectedDate) 的工时？"),
                message: Text("删除后这条记录和补贴/扣款都会移除。"),
                primaryButton: .destructive(Text("删除")) {
                    store.removeRecord(for: selectedDate)
                    toast.show("已删除当前工时")
                    GSReminder.syncFromSettings()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var header: some View {
        let st = monthStats
        return ZStack(alignment: .bottom) {
            GSHeaderBlock(
                title: "\(year)年",
                subtitle: GSDate.relativeDay(selectedDate),
                trailing: AnyView(
                    Text("\(month)月")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                )
            )
            .frame(height: 150)
            HStack(spacing: 8) {
                headerMetric(GSNum(GSJSONNumber(st["days"])), "出勤")
                headerMetric(GSNum(GSJSONNumber(st["hours"])), "工时")
                headerMetric(GSMoney(GSJSONNumber(st["pay"])), "工资")
            }
            .padding(.horizontal, 18)
            .offset(y: 18)
        }
        .padding(.bottom, 18)
    }

    private func headerMetric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundColor(GSTextSecondary())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: store.cardShadow ? Color.black.opacity(0.06) : .clear, radius: 8, x: 0, y: 3)
    }

    private var calendarCard: some View {
        GSCard(padding: 10) {
            VStack(spacing: 8) {
                HStack {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left").foregroundColor(GSTheme.color(for: store.themeKey)).frame(width: 30, height: 30)
                    }
                    Spacer()
                    Text("\(year)年\(month)月").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    Spacer()
                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right").foregroundColor(GSTheme.color(for: store.themeKey)).frame(width: 30, height: 30)
                    }
                }
                GSMonthCalendar(year: year, month: month, selectedDate: $selectedDate) { key in
                    selectedDate = key
                    let c = GSDate.components(from: key)
                    year = c.year; month = c.month
                }
                HStack {
                    Button("批量设置工时") { showBatch = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(GSTheme.color(for: store.themeKey))
                    Spacer()
                    Button("删除当前工时") { if store.record(for: selectedDate) != nil { confirmDelete = true } }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(store.record(for: selectedDate) != nil ? GSDangerColor() : GSTextTertiary())
                        .opacity(store.record(for: selectedDate) != nil ? 1 : 0.38)
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 18)
    }

    private var dayCard: some View {
        let rec = store.record(for: selectedDate)
        let d = GSDate.date(from: selectedDate)
        let c = GSDate.components(from: selectedDate)
        return Button { showEditor = true } label: {
            GSCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%02ld-%02ld", c.month, c.day))
                            .font(.system(size: 19, weight: .bold)).foregroundColor(GSTextPrimary())
                        if store.showLunar {
                            Text("农 " + GSLunar.full(d)).font(.system(size: 11)).foregroundColor(GSColorHex("#5D6B82"))
                        }
                        Spacer()
                        Text(GSMoney(store.dayPay(rec))).font(.system(size: 22, weight: .bold)).foregroundColor(GSMoneyColor())
                    }
                    if let rec = rec {
                        dayCardFilled(rec)
                    } else {
                        let plan = store.plan(for: selectedDate)
                        let planName = store.classItem(id: plan)?["name"] as? String
                        Text(planName?.isEmpty == false ? "排班 · \(planName!)\n点这里或右下角记一笔" : "未记录工时\n点这里或右下角记一笔")
                            .font(.system(size: 13))
                            .foregroundColor(GSColorHex("#5D6B82"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    HStack {
                        if rec == nil {
                            fab("记一笔", "plus") { showEditor = true }
                        } else if selectedDate != GSDate.todayKey() {
                            fab("回今天", "arrow.uturn.backward") { goToday() }
                        }
                        if selectedDate != GSDate.todayKey() && rec == nil {
                            Button("回到今天") { goToday() }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(GSTheme.color(for: store.themeKey))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    private func dayCardFilled(_ rec: [String: Any]) -> some View {
        let cls = store.classItem(id: rec["classId"] as? String)
        let kind = (rec["type"] as? String) ?? GSDayKind(selectedDate)
        let projectName = store.project(id: rec["projectId"] as? String)?["name"] as? String ?? ""
        let className = cls?["name"] as? String ?? "未选班次"
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(className)   \(GSKindName(kind))   \(projectName)")
                .font(.system(size: 13, weight: .medium)).foregroundColor(GSColorHex("#667085"))
            let w = GSJSONDict(rec["work"])
            HStack(spacing: 10) {
                ForEach([("正班","zb"),("加班","jb"),("周末","zm"),("节假","jj")], id: \.1) { name, k in
                    let v = GSJSONNumber(w[k])
                    if v > 0 {
                        Text("\(name) \(GSNum(v))H").font(.system(size: 11, weight: .medium)).foregroundColor(GSTextStrong())
                    }
                }
            }
        }
    }

    private func fab(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(GSTheme.color(for: store.themeKey))
            .clipShape(Capsule())
        }
    }

    private var timelineCard: some View {
        GSCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当天工时").font(.system(size: 16, weight: .bold)).foregroundColor(GSTextPrimary())
                    Text("按已记录的分类统计，不推算上下班时间").font(.system(size: 11)).foregroundColor(GSTextTertiary())
                }
                let rec = store.record(for: selectedDate)
                if rec == nil {
                    Text("当天还没有记录").font(.system(size: 14)).foregroundColor(GSTextTertiary())
                } else {
                    timeline(rec!)
                }
            }
        }
        .padding(.horizontal, 18)
    }

    private func timeline(_ rec: [String: Any]) -> some View {
        let work = GSJSONDict(rec["work"])
        let keys = ["zb", "jb", "zm", "jj"]
        let names = ["正班", "加班", "周末", "节假"]
        let colors: [Color] = [GSTheme.color(for: store.themeKey), GSDangerColor(), GSWarningColor(), GSColorHex("#6941C6")]
        let values = keys.map { GSJSONNumber(work[$0]) }
        let leave = rec["leave"] is [String: Any] ? GSJSONNumber(GSJSONDict(rec["leave"])["hour"]) : 0
        let total = values.reduce(0, +) + leave
        if total <= 0 {
            return AnyView(Text("当天没有可展示的工时").font(.system(size: 14)).foregroundColor(GSTextTertiary()))
        }
        return AnyView(VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        if values[i] > 0 {
                            colors[i].frame(width: geo.size.width * CGFloat(values[i] / total))
                        }
                    }
                    if leave > 0 {
                        GSSuccessColor().frame(width: geo.size.width * CGFloat(leave / total))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background(GSColorHex("#EEF2F7"))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            HStack {
                Text("已记录时长").font(.system(size: 12)).foregroundColor(GSTextSecondary())
                Spacer()
                Text("合计 \(GSNum(total))H").font(.system(size: 16, weight: .bold)).foregroundColor(GSTheme.color(for: store.themeKey))
            }
            ForEach(0..<4, id: \.self) { i in
                if values[i] > 0 {
                    HStack(spacing: 8) {
                        Circle().fill(colors[i]).frame(width: 6, height: 6)
                        Text(names[i]).font(.system(size: 13)).foregroundColor(GSTextStrong())
                        Spacer()
                        Text("\(GSNum(values[i]))H").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                    }
                }
            }
            if leave > 0 {
                HStack(spacing: 8) {
                    Circle().fill(GSSuccessColor()).frame(width: 6, height: 6)
                    Text("休假").font(.system(size: 13)).foregroundColor(GSTextStrong())
                    Spacer()
                    Text("\(GSNum(leave))H").font(.system(size: 14, weight: .semibold)).foregroundColor(GSTextPrimary())
                }
            }
        })
    }

    private func changeMonth(_ delta: Int) {
        let c = GSDate.monthAdd(year: year, month: month, delta: delta)
        year = c.year; month = c.month
        selectedDate = GSDate.dayKey(year, month, 1)
        GSHaptic()
    }

    private func goToday() {
        let now = Date()
        selectedDate = GSDate.key(from: now)
        year = GSDate.gregorian.component(.year, from: now)
        month = GSDate.gregorian.component(.month, from: now)
        GSHaptic()
    }
}

struct GSMonthCalendar: View {
    var year: Int
    var month: Int
    @Binding var selectedDate: String
    var onSelect: (String) -> Void
    @EnvironmentObject var store: GSStore

    var body: some View {
        let weekStart = store.weekStart
        let names = weekStart == 0 ? ["日","一","二","三","四","五","六"] : ["一","二","三","四","五","六","日"]
        let total = GSDate.daysInMonth(year: year, month: month)
        var first = DateComponents(); first.year = year; first.month = month; first.day = 1
        let firstDate = GSDate.gregorian.date(from: first) ?? Date()
        let weekday = GSDate.gregorian.component(.weekday, from: firstDate)
        let lead = (weekday - 1 - weekStart + 7) % 7
        var payday = store.intSetting("payday")
        if payday < 0 || payday > 31 { payday = 0 }
        let paydayDay = payday > 0 ? min(payday, total) : 0
        let today = GSDate.todayKey()
        let classDisplay = store.stringSetting("classDisplay", default: "icon")

        return VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(names, id: \.self) { n in
                    Text(n).font(.system(size: 11, weight: .medium)).foregroundColor(GSColorHex("#5D6B82")).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(0..<42, id: \.self) { i in
                    let dayNum = i - lead + 1
                    let inMonth = dayNum >= 1 && dayNum <= total
                    if inMonth {
                        cell(day: dayNum, paydayDay: paydayDay, today: today, classDisplay: classDisplay)
                    } else {
                        Color.clear.frame(height: 58)
                    }
                }
            }
        }
    }

    private func cell(day: Int, paydayDay: Int, today: String, classDisplay: String) -> some View {
        let key = GSDate.dayKey(year, month, day)
        let rec = store.record(for: key)
        let plan = store.plan(for: key)
        let clsId = (rec?["classId"] as? String) ?? (plan.isEmpty ? nil : plan)
        let cls = store.classItem(id: clsId)
        let kind = GSDayKind(key)
        let paydayCell = day == paydayDay
        let sel = key == selectedDate
        let className = (cls?["name"] as? String) ?? ""
        let dayShift = className.contains("白") || className.contains("早")
        let nightShift = className.contains("中") || className.contains("晚") || className.contains("夜")
        let showShift = cls != nil && classDisplay != "hide"
        let kindText: String = paydayCell ? "薪" : (kind == "jj" ? "节" : (kind == "zm" ? "休" : ""))
        let d = GSDate.date(from: key)

        return Button {
            GSHaptic()
            onSelect(key)
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        if showShift {
                            if classDisplay == "text" {
                                Text(className).font(.system(size: 8, weight: .bold))
                                    .foregroundColor(sel ? .white : shiftColor(dayShift, nightShift))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            } else {
                                Image(systemName: dayShift ? "sunrise.fill" : (nightShift ? "moon.stars.fill" : "briefcase.fill"))
                                    .font(.system(size: nightShift ? 7 : 8))
                                    .foregroundColor(sel ? .white : shiftColor(dayShift, nightShift))
                            }
                        } else {
                            Color.clear.frame(height: 9)
                        }
                        Text("\(day)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(dayColor(sel: sel, payday: paydayCell))
                        if store.showLunar {
                            Text(GSLunar.day(d)).font(.system(size: 9))
                                .foregroundColor(lunarColor(sel: sel, payday: paydayCell))
                        }
                        if rec != nil {
                            Text(store.daySummary(rec)).font(.system(size: 9, weight: .bold))
                                .foregroundColor(badgeColor(sel: sel, payday: paydayCell))
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if !kindText.isEmpty {
                        Text(kindText).font(.system(size: 8, weight: .bold))
                            .foregroundColor(kindColor(sel: sel, payday: paydayCell, kind: kind))
                            .padding(.trailing, 2).padding(.top, 1)
                    }
                }
                if rec != nil || paydayCell || key == today {
                    Capsule().fill(lineColor(sel: sel, payday: paydayCell))
                        .frame(width: 16, height: 2.5)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
            .frame(minHeight: 58)
            .background(sel ? GSTheme.color(for: store.themeKey) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: sel ? GSTheme.color(for: store.themeKey).opacity(0.28) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func shiftColor(_ day: Bool, _ night: Bool) -> Color {
        day ? GSColorHex("#B45309") : (night ? GSColorHex("#1E3B8A") : GSColorHex("#475467"))
    }
    private func dayColor(sel: Bool, payday: Bool) -> Color {
        if sel { return payday ? GSColorHex("#FFE08A") : .white }
        return payday ? GSColorHex("#D99A00") : GSColorHex("#101828")
    }
    private func lunarColor(sel: Bool, payday: Bool) -> Color {
        if sel { return payday ? GSColorHex("#FFE08A") : Color.white.opacity(0.92) }
        return payday ? GSColorHex("#D99A00") : GSColorHex("#5D6B82")
    }
    private func badgeColor(sel: Bool, payday: Bool) -> Color {
        if sel { return payday ? GSColorHex("#FFE08A") : .white }
        return payday ? GSColorHex("#D99A00") : GSTheme.color(for: store.themeKey)
    }
    private func kindColor(sel: Bool, payday: Bool, kind: String) -> Color {
        if sel { return payday ? GSColorHex("#FFE08A") : .white }
        if payday { return GSColorHex("#B06A00") }
        return kind == "jj" ? GSColorHex("#B42318") : GSColorHex("#B45309")
    }
    private func lineColor(sel: Bool, payday: Bool) -> Color {
        if sel { return payday ? GSColorHex("#FFE08A") : .white }
        return payday ? GSColorHex("#D99A00") : GSTheme.color(for: store.themeKey)
    }
}
