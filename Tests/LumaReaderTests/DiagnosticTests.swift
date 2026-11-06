import Foundation
import Testing
import ZIPFoundation
@testable import LumaReader

struct DiagnosticTests {
    @Test func basicErrorsRemainVisibleWithoutVerboseLogging() {
        #expect(DiagnosticCapturePolicy.shouldRecord(verbose:false,automatic:true,isError:true))
        #expect(!DiagnosticCapturePolicy.shouldRecord(verbose:false,automatic:true,isError:false))
        #expect(!DiagnosticCapturePolicy.shouldRecord(verbose:true,automatic:false,isError:true))
        #expect(DiagnosticCapturePolicy.shouldRecord(verbose:true,automatic:false,isError:false))
    }
    @Test func eventSchemaRejectsStringsAndDropsUnknownNumericFields() throws {
        let source = #"{"id":"00000000-0000-0000-0000-000000000001","time":0,"code":"aiBootFailed","isError":true,"fields":{"stylesReady":0,"title":2026,"url":123},"quote":"PRIVATE_BOOK","token":"sk-PRIVATE"}"#
        let event = try JSONDecoder().decode(DiagnosticEvent.self,from:Data(source.utf8))
        #expect(event.fields == ["stylesReady":0])
        let encoded = String(decoding:try JSONEncoder().encode(event),as:UTF8.self)
        #expect(!encoded.contains("PRIVATE")); #expect(!encoded.contains("title")); #expect(!encoded.contains("url"))
        let bad = source.replacingOccurrences(of:"\"stylesReady\":0",with:"\"stylesReady\":\"sk-PRIVATE\"")
        #expect(throws:(any Error).self) { try JSONDecoder().decode(DiagnosticEvent.self,from:Data(bad.utf8)) }
    }
    @Test func invalidMeasurementsAreNotSerializedAsNumbers() {
        let event = DiagnosticEvent(code:.networkComplete,fields:[.durationMs:.nan,.receivedBytes:42])
        #expect(event.fields["durationMs"] == nil); #expect(event.fields["receivedBytes"] == 42)
    }
    @Test func reusedCPUCalculatorHandlesIntervalAndReset() {
        let before = CPUTicks(user:100,system:100,idle:800,nice:0)
        let current = CPUTicks(user:130,system:120,idle:850,nice:0)
        #expect(CPUCalculator.usage(from:before,to:current).total == 50)
        #expect(RateCalculator.delta(previous:100,current:3) == 0)
        #expect(RateCalculator.bytesPerSecond(previous:2,current:6,interval:2) == 2)
    }
    @Test func reusedMemoryCalculatorReportsAnEstimate() {
        let value = MemoryCalculator.usage(sample:MemorySample(active:20,wired:10,compressed:5,free:50,inactive:15),pageSize:4096,physical:409600)
        #expect(value.usedBytes == 35*4096); #expect(value.usedPercent == 35)
    }
    @Test func markdownShowsUnknownScopesAndDoesNotPretendToMeasurePower() {
        let report = DiagnosticReport(appVersion:"test",osVersion:"26.0",samples:[],events:[DiagnosticEvent(code:.aiBootFailed)],crashReportsStored:nil,crashCaptureActive:false)
        #expect(report.markdown().contains("Not Available")); #expect(report.markdown().contains("aiBootFailed"))
        #expect(report.markdown().contains("not power in watts"))
        #expect(report.unavailable["systemPowerWatts"] != nil); #expect(report.unavailable["webkitAuxiliaryCPU"] != nil)
    }
    @Test func realArchiveWriterProducesOnlySanitizedNamedFiles() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".zip")
        let extracted = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer { try? FileManager.default.removeItem(at:url); try? FileManager.default.removeItem(at:extracted) }
        var sample = DiagnosticSample()
        sample.time = Date(timeIntervalSince1970:1234)
        sample.processCPUPercent = 12.5
        let report = DiagnosticReport(appVersion:"test",osVersion:"26.0",samples:[sample],events:[DiagnosticEvent(code:.aiScriptFailed)],crashReportsStored:nil,crashCaptureActive:false)
        try await DiagnosticArchive().write(report,to:url)
        try FileManager.default.unzipItem(at:url,to:extracted)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath:extracted.path)) == ["BugReport.md","diagnostics.json","Performance.csv"])
        #expect(try String(contentsOf:extracted.appendingPathComponent("BugReport.md"),encoding:.utf8).contains("aiScriptFailed"))
        let csv = try String(contentsOf:extracted.appendingPathComponent("Performance.csv"),encoding:.utf8)
        let records = csv.split(separator:"\n")
        try #require(records.count == 2)
        let columns = records[1].split(separator:",",omittingEmptySubsequences:false)
        try #require(columns.count == 10)
        #expect(columns[1] == "12.5")
        #expect(columns[2].isEmpty && columns[3].isEmpty)

    }
}
