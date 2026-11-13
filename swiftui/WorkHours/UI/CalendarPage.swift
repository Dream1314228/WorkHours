import SwiftUI

struct CalendarPage: View {
    var palette: Palette
    @EnvironmentObject var store: Store

    @State private var year = Cal.year(Cal.todayKey())
    @State private var month = Cal.month(Cal.todayKey())
    @State private var selected = Cal.todayKey()
    @State private var editorDate = Cal.todayKey()
    @State private var showEditor = false
    @State private var confirmDelete = false

    private var today: String { Cal.todayKey() }

    private var selectedRecord: DayRecord? { store.record(selected) }

    private var monthStats: MonthStats { store.monthStats(year: year, month: month) }

    private var firstOffset: Int {
        let key = String(format: "%04d-%02d-01", year, month)
        let w = Cal.weekday(key)
        return store.settings.weekStart == 1 ? (w + 5) % 7 : (w - 1)
    }

    private var weekdayHeaders: [String] {
        store.settings.weekStart == 1
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    var body: some View {
        ZStack {
            AppBackdrop(palette: palette)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    stackCards
                    calendarCard
                    dayCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showEditor) {
            DayEditor(date: editorDate, palette: palette)
                .environmentObject(store)
        }
        .alert("删除这天的记录？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                store.removeRecord(selected)
                ToastCenter.shared.show("已删除 \(Cal.shortDate(selected)) 的记录")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删这一天，排班和别的日期不受影响。")
        }
    }

    // MARK: 顶部

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                LedgerCaption(text: "工时账本")
                Spacer()
                Text("NO. \(String(format: "%04d-%02d", year, month))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Ledger.inkSoft)
            }
            LedgerRule(strong: true)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(year) 年 \(month) 月")
                        .font(.system(size: 30, weight: .medium, design: .serif))
                        .foregroundStyle(Ledger.ink)
                    Text(monthStats.label)
                        .font(.system(size: 12))
                        .foregroundStyle(Ledger.inkSoft)
                        .monospacedDigit()
                }
                Spacer()
                HStack(spacing: 6) {
                    monthButton("chevron.left") { moveMonth(-1) }
                    monthButton("chevron.right") { moveMonth(1) }
                    Button {
                        jumpToday()
                    } label: {
                        Text("今天")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Ledger.paper)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Ledger.ink))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var stackCards: some View {
        let prev = Cal.monthAdd(year, month, -1)
        let next = Cal.monthAdd(year, month, 1)
        let p = store.monthStats(year: prev.0, month: prev.1)
        let n = store.monthStats(year: next.0, month: next.1)
        return LedgerStack(items: [
            .init(title: "本期账单", caption: "\(year)-\(String(format: "%02d", month))",
                  big: Cal.money(monthStats.pay),
                  foot: "出勤 \(Cal.num(monthStats.days)) 天 · \(Cal.num(monthStats.hours)) H",
                  tint: Ledger.ink),
            .init(title: "上期", caption: "\(prev.0)-\(String(format: "%02d", prev.1))",
                  big: Cal.money(p.pay),
                  foot: "出勤 \(Cal.num(p.days)) 天 · \(Cal.num(p.hours)) H",
                  tint: Ledger.inkSoft),
            .init(title: "下期", caption: "\(next.0)-\(String(format: "%02d", next.1))",
                  big: Cal.money(n.pay),
                  foot: "出勤 \(Cal.num(n.days)) 天 · \(Cal.num(n.hours)) H",
                  tint: Ledger.inkSoft)
        ])
    }

    private func monthButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .contentShape(Circle().inset(by: -5))
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8))
        }
        .buttonStyle(PressableStyle())
    }

    private func moveMonth(_ delta: Int) {
        let next = Cal.monthAdd(year, month, delta)
        year = next.year
        month = next.month
        selected = String(format: "%04d-%02d-01", next.year, next.month)
    }

    private func jumpToday() {
        let t = Cal.todayKey()
        year = Cal.year(t)
        month = Cal.month(t)
        selected = t
    }

    // MARK: 月历

    private var calendarCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { w in
                    Text(w)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.gsSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 5) {
                ForEach(0..<firstOffset, id: \.self) { _ in
                    Color.clear.frame(height: 62)
                }
                ForEach(1...Cal.daysInMonth(year, month), id: \.self) { d in
                    dayCell(d)
                }
            }

            if store.settings.payday > 0 && store.settings.payday <= Cal.daysInMonth(year, month) {
                Capsule()
                    .fill(Color.gsOrange)
                    .frame(height: 3)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
        .glassCard(radius: store.settings.cardRadius, padding: 10)
    }

    private func dayCell(_ d: Int) -> some View {
        let key = String(format: "%04d-%02d-%02d", year, month, d)
        let rec = store.record(key)
        let planId = store.plan(key)
        let shift = planId.isEmpty ? nil : store.shiftClass(planId)
        let isToday = key == today
        let isSelected = key == selected
        let isPayday = store.settings.payday > 0 && d == store.settings.payday
        let tag = rightTag(key)

        return Button {
            selected = key
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text("\(d)")
                        .font(.system(size: 15, weight: isToday ? .bold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(isPayday ? Color.gsOrange : Color.primary)
                    Spacer(minLength: 0)
                    if let tag = tag {
                        Text(tag.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(tag.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                Text(store.settings.showLunar ? Cal.lunarCellText(key) : "")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.gsSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    if let rec = rec {
                        if store.settings.classDisplay != "hide",
                           let shift = store.shiftClass(rec.classId) {
                            shiftMark(shift)
                        }
                        Text(store.daySummary(rec))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else if let shift = shift {
                        shiftMark(shift)
                    }
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .frame(height: 62)
            .background {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? Ledger.ink.opacity(0.06)
                          : (isToday ? Ledger.ink.opacity(0.03) : Color.clear))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(isSelected ? Ledger.ruleStrong
                                  : (isToday ? Ledger.ruleStrong.opacity(0.5) : Color.clear),
                                  lineWidth: isSelected ? 1.2 : 0.8)
            }
            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.95))
    }

    @ViewBuilder
    private func shiftMark(_ shift: ShiftClass) -> some View {
        switch store.settings.classDisplay {
        case "hide":
            EmptyView()
        case "text":
            Text(shift.name)
                .font(.system(size: 9))
                .foregroundStyle(Color.gsSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        default:
            Image(systemName: shift.symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.primary)
        }
    }

    private func rightTag(_ key: String) -> (name: String, color: Color)? {
        if let holiday = Cal.holidayName(key) {
            return (holiday, Color.gsRed)
        }
        if Cal.isMakeupWorkday(key) {
            return ("班", Color.gsGreen)
        }
        if store.settings.payday > 0 && Cal.day(key) == store.settings.payday {
            return ("薪", Color.gsOrange)
        }
        if Cal.isWeekend(key) {
            return ("休", Color.secondary)
        }
        return nil
    }

    // MARK: 月统计

    private var summaryCard: some View {
        HStack(spacing: 8) {
            StatTile(value: "\(Cal.num(monthStats.hours))H", label: "总工时", color: Color.primary, palette: palette)
            StatTile(value: "\(Cal.num(monthStats.days))天", label: "出勤", palette: palette)
            StatTile(value: Cal.money(monthStats.pay), label: "实发工资",
                     color: Color.gsOrange, palette: palette)
        }
    }

    // MARK: 选中日详情

    private var dayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Cal.shortDate(selected))
                        .font(.system(size: 20, weight: .bold))
                    HStack(spacing: 6) {
                        Text(Cal.weekdayName(selected))
                        if selected == today { Text("· 今天") }
                        if store.settings.showLunar { Text("· " + Cal.lunarFull(selected)) }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gsSecondary)
                }
                Spacer()
                if selectedRecord != nil {
                    Button {
                        editorDate = selected
                        showEditor = true
                    } label: {
                        Text("编辑")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Ledger.ink.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            if let rec = selectedRecord {
                recordDetail(rec)
            } else {
                noRecordDetail
            }
        }
        .glassCard(radius: store.settings.cardRadius)
    }

    @ViewBuilder
    private func recordDetail(_ rec: DayRecord) -> some View {
        HStack(spacing: 6) {
            if let shift = store.shiftClass(rec.classId) {
                Label(shift.name, systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(palette.primary.opacity(0.12)))
            }
            Text(store.project(rec.projectId).name)
                .font(.system(size: 12))
                .foregroundStyle(Color.gsSecondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .glassCapsule()
            Spacer()
            Text(Cal.kindName(rec.type))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.gsSecondary)
        }

        HStack(spacing: 8) {
            hourBox("正班", rec.work.zb)
            hourBox("加班", rec.work.jb)
            hourBox("周末", rec.work.zm)
            hourBox("节假", rec.work.jj)
        }

        if let leave = rec.leave {
            detailRow("\(Cal.leaveName(leave.type))", "\(Cal.num(leave.hour)) 小时 · 倍率 \(Cal.num(leave.multiple))")
        }
        if rec.settle > 0 {
            detailRow("日结", Cal.money(rec.settle))
        }
        if !rec.bt.isEmpty {
            Text("补扣明细")
                .font(.system(size: 11))
                .foregroundStyle(Color.gsSecondary)
        }
        ForEach(rec.bt) { b in
            detailRow(b.name.isEmpty ? "补贴" : b.name,
                      b.money >= 0 ? Cal.money(b.money) : "-" + Cal.money(-b.money))
        }
        if !rec.note.isEmpty {
            detailRow("备注", rec.note)
        }

        Divider().opacity(0.4)

        HStack {
            Text("当天合计")
                .font(.system(size: 13))
                .foregroundStyle(Color.gsSecondary)
            Spacer()
            Text(Cal.money(store.dayPay(rec)))
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.gsOrange)
        }

        HStack(spacing: 10) {
            Button {
                editorDate = selected
                showEditor = true
            } label: {
                Text("编辑记录")
            }
            .buttonStyle(GlassActionButtonStyle(palette: palette, prominent: true, height: 46))

            Button {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.gsRed)
                    .frame(width: 52, height: 46)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Ledger.ink.opacity(0.05)))
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Ledger.rule, lineWidth: 0.8))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.top, 2)
    }

    private var noRecordDetail: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.primary)
                Text(store.plan(selected).isEmpty ? "这天还没有记录" : "这天排了 \(store.shiftClass(store.plan(selected))?.name ?? "班")，还没记工时")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.gsSecondary)
                Spacer()
            }
            Button {
                editorDate = selected
                showEditor = true
            } label: {
                Label("记一笔", systemImage: "plus")
            }
            .buttonStyle(GlassActionButtonStyle(palette: palette, prominent: true, height: 48))
        }
    }

    private func hourBox(_ title: String, _ value: Double) -> some View {
        VStack(spacing: 3) {
            Text(Cal.num(value))
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? Color.primary : Color.secondary)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color.gsSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.gsSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
    }
}
