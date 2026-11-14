import Foundation
import Testing
@testable import WorkHours

// MARK: - 第 6 组：备份解包与导入

/// 注意：`importBackup` 走正常成功路径时会经 `commitImport` 落盘到宿主 App 容器的 Documents。
/// 所以凡走成功导入的用例都套 `withCleanStoreFiles`，跑完还原原文件；
/// 走报错分支的用例不会落盘，直接断言即可。
/// 本组串行执行，避免并行用例互相覆盖同一份文件。
@Suite(.serialized)
struct BackupTests {
    @Test func 八字节以下原样返回() {
        #expect(Store.unwrapBackup(Data()) == Data())
        let short = Data([0x62, 0x76, 0x78, 0x32])   // bvx2 头但只有 4 字节
        #expect(Store.unwrapBackup(short) == short)
    }

    @Test func 纯JSON原样通过() {
        let payload = Data(#"{"format":"gsjilu-backup","days":[]}"#.utf8)
        #expect(payload.count > 8)
        #expect(Store.unwrapBackup(payload) == payload)
    }

    @Test func 假bvx2头不崩且原样返回() {
        var raw = Data([0x62, 0x76, 0x78, 0x32])
        raw.append(contentsOf: [0, 1, 2, 3, 4, 5, 6, 7])
        #expect(Store.unwrapBackup(raw) == raw)
    }

    @Test func LZFSE压缩能解开() throws {
        let payload = Data(#"{"format":"gsjilu-backup","days":[{"d":"2026-03-02"}]}"#.utf8)
        let packedNS = try (payload as NSData).compressed(using: .lzfse)
        let packed = packedNS as Data
        #expect(packed.count > 8)
        #expect([UInt8](packed.prefix(4)) == [0x62, 0x76, 0x78, 0x32], "系统 LZFSE 输出应带 bvx2 头")
        #expect(Store.unwrapBackup(packed) == payload)
    }

    @Test func 空days拒绝导入且原数据不动() {
        // DEF-01：这份文件以前会把整库清空
        let s = FX.store(FX.payload(records: ["2026-03-02": FX.rec(zb: 8)]))
        let empty = Data(#"{"format":"gsjilu-backup","days":[]}"#.utf8)
        #expect(throws: Store.ImportError.self) {
            try s.importBackup(empty)
        }
        #expect(s.data.records.count == 1)
        expectClose(s.dayPay(s.record("2026-03-02")!), 102.56)
    }

    @Test func 坏文件报badFile() {
        let s = FX.store(FX.payload())
        #expect(throws: Store.ImportError.self) {
            try s.importBackup(Data("这不是 JSON".utf8))
        }
        #expect(throws: Store.ImportError.self) {
            // 有 format、没有 days、也没有 records
            try s.importBackup(Data(#"{"format":"gsjilu-backup"}"#.utf8))
        }
        #expect(s.data.records.isEmpty)
    }

    @Test func 导出再导入往返一致() throws {
        try withCleanStoreFiles {
            let source = FX.store(FX.payload(period: 26, records: [
                "2026-03-02": FX.rec(zb: 8, jb: 2),
                "2026-03-03": FX.rec(type: "xiu", leave: LeaveInfo(type: "xiu", hour: 8))
            ]))
            let raw = try #require(source.backupData())

            let target = FX.store(FX.payload())
            try target.importBackup(raw)

            #expect(target.data.records.count == 2)
            expectClose(target.dayPay(target.record("2026-03-02")!), 141.02)
            #expect(target.record("2026-03-03")?.type == "xiu")
            #expect(target.record("2026-03-03")?.leave?.hour == 8)
        }
    }

    @Test func 导入后留了可回滚快照() throws {
        // 老兵 D1 给 DEF-02 加的入口：导入后应能恢复导入前的数据
        try withCleanStoreFiles {
            let source = FX.store(FX.payload(period: 26, records: [
                "2026-03-02": FX.rec(zb: 8),
                "2026-03-03": FX.rec(zb: 8)
            ]))
            let raw = try #require(source.backupData())

            let target = FX.store(FX.payload(records: ["2026-04-01": FX.rec(zb: 8)]))
            try target.importBackup(raw)
            #expect(target.data.records.count == 2)
            #expect(target.hasImportSnapshot)

            try target.restoreImportSnapshot()
            #expect(target.data.records.count == 1)
            #expect(target.data.records["2026-04-01"] != nil)
            #expect(!target.hasImportSnapshot)
        }
    }

    @Test func 整库JSON只带records也能导入() throws {
        try withCleanStoreFiles {
            let raw = Data(#"{"records":{"2026-03-02":{"work":{"zb":8},"type":"zb","classId":"1","projectId":"default"}}}"#.utf8)
            let s = FX.store(FX.payload())
            try s.importBackup(raw)
            #expect(s.data.records.count == 1)
            expectClose(s.dayPay(s.record("2026-03-02")!), 102.56)
        }
    }

    @Test func 旧版w字段的整库JSON会丢工时() throws {
        // 已知问题：`AppData` 的解码器太宽松，`JSONDecoder().decode(AppData.self)` 永远成功，
        // 于是走不到「按 w 数组逐条读」的兜底分支，w=[8,0,0,0] 被解成 work 全 0。
        try withCleanStoreFiles {
            let raw = Data(#"{"records":{"2026-03-02":{"w":[8,0,0,0],"t":"zb"}}}"#.utf8)
            let s = FX.store(FX.payload())
            try s.importBackup(raw)
            #expect(s.data.records.count == 1)
            withKnownIssue("整库 JSON 带 w 字段时工时被静默丢成 0") {
                #expect(s.data.records["2026-03-02"]?.work.zb != 0)
            }
        }
    }
}
