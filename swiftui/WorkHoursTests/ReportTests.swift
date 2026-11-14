import Foundation
import Testing
@testable import WorkHours

// MARK: - 第 8 组：HTML / 纯文本报表

struct ReportTests {
    @Test func 备注里的脚本被转义() {
        let note = #"<script>x</script> & "q""#
        let s = FX.store(FX.payload(period: 1, records: ["2026-03-10": FX.rec(zb: 8, note: note)]))
        let html = s.htmlReport(year: 2026, month: 3)
        #expect(html.contains("&lt;script&gt;x&lt;/script&gt;"))
        #expect(!html.contains("<script>x</script>"))
        #expect(html.contains("&amp;"))
        #expect(html.contains("&quot;q&quot;"))
    }

    @Test func 补助名也被转义() {
        let rec = FX.rec(zb: 8, bt: [BonusItem(name: "<b>高危</b>", money: 10)])
        let s = FX.store(FX.payload(period: 1, records: ["2026-03-10": rec]))
        let html = s.htmlReport(year: 2026, month: 3)
        #expect(html.contains("&lt;b&gt;高危&lt;/b&gt;"))
        #expect(!html.contains("<b>高危</b>"))
    }

    @Test func 空周期给固定文案() {
        let s = FX.store(FX.payload(period: 1))
        let html = s.htmlReport(year: 2026, month: 5)
        #expect(html.contains("这个周期还没有记录"))
    }

    @Test func 报表明细与合计口径不一致被钉住() {
        // DEF-08：明细按自然月前缀筛，合计按考勤期
        // 2026-01-05 属于 2025 年 12 月期；2026-01-27 属于 2026 年 1 月期
        let s = FX.store(FX.payload(period: 26, records: [
            "2026-01-05": FX.rec(zb: 8),
            "2026-01-27": FX.rec(zb: 8)
        ]))
        let text = s.reportText(year: 2026, month: 1)

        // 明细行两天都在
        #expect(text.contains("2026-01-05"))
        #expect(text.contains("2026-01-27"))
        // 合计只算一天的钱
        #expect(text.contains("实发工资 ¥102.56"))
        // 月统计（按考勤期）也是 1 天
        #expect(s.monthStats(year: 2026, month: 1).days == 1)

        withKnownIssue("DEF-08：reportText 明细按自然月、合计按考勤期") {
            #expect(s.monthStats(year: 2026, month: 1).days == 2)
        }
    }

    @Test func 自然月模式下报表明细与合计一致() {
        // 反向用例：period=1 时明细 2 天、合计也应是 2 天两笔钱
        let s = FX.store(FX.payload(period: 1, records: [
            "2026-01-05": FX.rec(zb: 8),
            "2026-01-27": FX.rec(zb: 8)
        ]))
        let text = s.reportText(year: 2026, month: 1)
        #expect(text.contains("实发工资 ¥205.12"))
        #expect(s.monthStats(year: 2026, month: 1).days == 2)
    }

    @Test func 报表头部写清考勤期() {
        let s = FX.store(FX.payload(period: 26, records: ["2026-01-27": FX.rec(zb: 8)]))
        let text = s.reportText(year: 2026, month: 1)
        #expect(text.contains("考勤期：2026-01-26 至 2026-02-25"))
    }
}
