import Foundation

enum GSHTMLReport {
    private static let cssTail = #";--ink:#14213d;--muted:#667085;--line:#e6ebf5;--soft:#f2f6ff}*{box-sizing:border-box}body{margin:0;background:#eef3fb;color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.wrap{max-width:920px;margin:0 auto;padding:20px}.hero{background:linear-gradient(135deg,var(--accent),#123b8f);color:white;border-radius:28px;padding:26px;box-shadow:0 18px 45px rgba(18,59,143,.22)}.eyebrow{margin:0 0 8px;font-size:12px;letter-spacing:.12em;opacity:.8}.hero h1{margin:0;font-size:34px}.hero .pay{font-size:38px;font-weight:800;margin-top:8px}.hero p{margin:8px 0 0;color:rgba(255,255,255,.82);font-size:13px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-top:16px}.stat{background:white;border:1px solid var(--line);border-radius:16px;padding:13px}.stat b{display:block;font-size:18px}.stat span{display:block;color:var(--muted);font-size:11px;margin-top:3px}.card{background:white;border:1px solid var(--line);border-radius:22px;padding:18px;margin-top:14px}.card h2{font-size:16px;margin:0 0 14px}.chart{display:flex;align-items:flex-end;gap:7px;height:160px;padding-top:10px}.col{flex:1;text-align:center;display:flex;flex-direction:column;justify-content:flex-end;height:100%}.bar{min-height:4px;display:flex;flex-direction:column-reverse;border-radius:6px;overflow:hidden;background:var(--soft);margin:0 auto;width:16px}.bar span{display:block;width:100%}.col small{color:var(--muted);font-size:9px;margin-top:5px}.legend{display:flex;gap:16px;color:var(--muted);font-size:11px;margin-top:8px}.dot{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:4px;vertical-align:1px}.scroll{overflow-x:auto}table{width:100%;border-collapse:collapse;font-size:12px;min-width:680px}th,td{padding:9px 7px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}th:first-child,td:first-child{text-align:left}th{color:var(--muted);font-weight:500;font-size:10px}tr:last-child td{border-bottom:0}.money{font-weight:700}.green{color:#067647}.red{color:#b42318}.foot{color:var(--muted);font-size:10px;text-align:center;padding:18px 0 32px}.split{display:flex;gap:22px;align-items:center}.donut{width:158px;height:158px;border-radius:50%;position:relative;flex:0 0 158px}.donut .hole{position:absolute;inset:24px;background:#fff;border-radius:50%;display:flex;flex-direction:column;align-items:center;justify-content:center}.donut b{font-size:22px}.donut span{font-size:10px;color:var(--muted);margin-top:2px}.legend-list{display:grid;gap:10px;flex:1}.legend-list div{display:flex;justify-content:space-between;font-size:12px;color:var(--muted)}.legend-list b{color:var(--ink)}@media(max-width:640px){.wrap{padding:12px}.grid{grid-template-columns:repeat(2,1fr)}.hero{border-radius:22px;padding:20px}.hero h1{font-size:28px}.hero .pay{font-size:30px}.split{flex-direction:column}.donut{flex:none}}</style></head><body><div class="wrap">"#

    private static func esc(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func generate(year: Int) -> URL? {
        let st = GSStore.shared.yearStats(year: year)
        let months = (st["months"] as? [[String: Any]]) ?? []
        var maxH: Double = 1
        var activeMonths = 0
        for m in months {
            maxH = max(maxH, GSJSONNumber(m["hours"]))
            if GSJSONNumber(m["hours"]) > 0 { activeMonths += 1 }
        }
        let avgMonthPay = activeMonths > 0 ? GSJSONNumber(st["pay"]) / Double(activeMonths) : 0
        let workIncome = max(0, GSJSONNumber(st["workPay"]))
        let bonusIncome = max(0, GSJSONNumber(st["bonus"]))
        let incomeTotal = workIncome + bonusIncome
        let workShare = incomeTotal > 0 ? workIncome / incomeTotal * 100 : 50
        let accent = GSTheme.hex(for: GSStore.shared.themeKey)

        var html = "<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>工时记录年度看板</title><style>"
        html += ":root{--accent:"
        html += accent
        html += cssTail
        html += String(format: "<header class=\"hero\"><p class=\"eyebrow\">工时记录 · 年度看板</p><h1>%ld 年</h1><div class=\"pay\">%@</div><p>%@ 天出勤 · %@ 小时 · 平均时薪 %.0f 元</p></header>",
                       year, esc(GSMoney(GSJSONNumber(st["pay"]))), GSNum(GSJSONNumber(st["days"])), GSNum(GSJSONNumber(st["hours"])), GSJSONNumber(st["avg"]))
        html += "<div class=\"grid\">"
        let dailyAvg = GSJSONNumber(st["days"]) > 0 ? GSJSONNumber(st["hours"]) / GSJSONNumber(st["days"]) : 0
        html += String(format: "<div class=\"stat\"><b>%@H</b><span>总工时</span></div><div class=\"stat\"><b>%@天</b><span>出勤</span></div><div class=\"stat\"><b>%@H</b><span>加班/周末/节假</span></div><div class=\"stat\"><b>%@</b><span>补贴</span></div><div class=\"stat\"><b>%@</b><span>扣款</span></div><div class=\"stat\"><b>%@</b><span>实发工资</span></div><div class=\"stat\"><b>%@H</b><span>日均工时</span></div><div class=\"stat\"><b>%@</b><span>月均工资</span></div>",
                       GSNum(GSJSONNumber(st["hours"])), GSNum(GSJSONNumber(st["days"])), GSNum(GSJSONNumber(st["ot"])),
                       esc(GSMoney(GSJSONNumber(st["bonus"]))), esc(GSMoney(GSJSONNumber(st["deduct"]))),
                       esc(GSMoney(GSJSONNumber(st["pay"]))), GSNum(dailyAvg), esc(GSMoney(avgMonthPay)))
        html += "</div>"
        html += String(format: "<section class=\"card split\"><div class=\"donut\" style=\"background:conic-gradient(#1859D9 0 %.1f%%, #12B76A %.1f%% 100%%)\"><div class=\"hole\"><b>%.0f%%</b><span>工时工资</span></div></div><div class=\"legend-list\"><div><span>工时工资</span><b>%@</b></div><div><span>补贴</span><b>+%@</b></div><div><span>扣款</span><b>-%@</b></div><div><span>实发工资</span><b>%@</b></div><div><span>月均工资</span><b>%@</b></div></div></section>",
                       workShare, workShare, workShare,
                       esc(GSMoney(workIncome)), esc(GSMoney(bonusIncome)),
                       esc(GSMoney(GSJSONNumber(st["deduct"]))), esc(GSMoney(GSJSONNumber(st["pay"]))), esc(GSMoney(avgMonthPay)))
        html += "<section class=\"card\"><h2>十二个月工时结构</h2><div class=\"chart\">"
        for i in 0..<12 {
            let m = i < months.count ? months[i] : [:]
            let total = GSJSONNumber(m["hours"])
            let normal = GSJSONNumber(m["zb"])
            let other = max(0, total - normal)
            let full = total > 0 ? 4 + total / maxH * 108 : 4
            let nh = total > 0 ? full * normal / total : 0
            let oh = total > 0 ? full * other / total : 0
            html += String(format: "<div class=\"col\"><div class=\"bar\" style=\"height:%.0fpx\"><span style=\"height:%.0fpx;background:#1859D9\"></span><span style=\"height:%.0fpx;background:#D92D20\"></span></div><small>%ld</small></div>", full, nh, oh, i + 1)
        }
        html += "</div><div class=\"legend\"><span><i class=\"dot\" style=\"background:#1859D9\"></i>正班</span><span><i class=\"dot\" style=\"background:#D92D20\"></i>加班/周末/节假</span></div></section>"
        html += "<section class=\"card\"><h2>月度明细</h2><div class=\"scroll\"><table><thead><tr><th>月份</th><th>出勤</th><th>总工时</th><th>正班</th><th>加班</th><th>周末</th><th>节假</th><th>补贴</th><th>扣款</th><th>实发</th></tr></thead><tbody>"
        for i in 0..<12 {
            let m = i < months.count ? months[i] : [:]
            html += String(format: "<tr><td>%ld月</td><td>%@天</td><td>%@H</td><td>%@H</td><td>%@H</td><td>%@H</td><td>%@H</td><td class=\"green\">+%@</td><td class=\"red\">-%@</td><td class=\"money\">%@</td></tr>",
                           i + 1, GSNum(GSJSONNumber(m["days"])), GSNum(GSJSONNumber(m["hours"])),
                           GSNum(GSJSONNumber(m["zb"])), GSNum(GSJSONNumber(m["jb"])),
                           GSNum(GSJSONNumber(m["zm"])), GSNum(GSJSONNumber(m["jj"])),
                           esc(GSMoney(GSJSONNumber(m["bonus"]))), esc(GSMoney(GSJSONNumber(m["deduct"]))),
                           esc(GSMoney(GSJSONNumber(m["pay"]))))
        }
        html += "</tbody></table></div></section>"
        html += String(format: "<div class=\"foot\">由工时记录生成 · %@</div></div></body></html>", GSDate.key(from: Date()))
        let name = String(format: "工时记录-%ld-看板.html", year)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        do {
            try html.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
