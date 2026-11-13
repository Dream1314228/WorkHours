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
                    calendarCard
                    summaryCard
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Cal.monthTitle(year: year, month: month))
                    .font(.system(size: 26, weight: .bold))
                Text("考勤期 \(monthStats.start) 至 \(monthStats.end)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            HStack(spacing: 8) {
                monthButton("chevron.left") { moveMonth(-1) }
                monthButton("chevron.right") { moveMonth(1) }
            }
            Button {
                jumpToday()
            } label: {
                Text("今天")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.onPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(palette.primary))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: store.settings.headerRadius, style: .continuous))
    }

    private func monthButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .glassEffect(.regular.interactive(), in: Circle())
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
                        .foregroundStyle(.secondary)
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
        let tag = rightTag(key)

        return Button {
            selected = key
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Text("\(d)")
                        .font(.system(size: 15, weight: isToday ? .bold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary)
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
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    if let rec = rec {
                        if let shift = store.shiftClass(rec.classId) {
                            Circle().fill(Color(hex: shift.color)).frame(width: 4, height: 4)
                        }
                        Text(store.daySummary(rec))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else if let shift = shift {
                        Circle().fill(Color(hex: shift.color)).frame(width: 4, height: 4)
                        Text(shift.name)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .frame(height: 62)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? palette.primary.opacity(0.16)
                          : (isToday ? palette.primary.opacity(0.07) : Color.clear))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? palette.primary : Color.clear, lineWidth: 1.4)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.95))
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
                    .foregroundStyle(.secondary)
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
                            .glassEffect(.regular.interactive(), in: Capsule())
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
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .glassCapsule()
            Spacer()
            Text(Cal.kindName(rec.type))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
                    .glassEffect(.regular.interactive(), in: Capsule())
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
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.trailing)
        }
    }
}
