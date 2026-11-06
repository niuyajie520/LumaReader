import Foundation
import ZIPFoundation

/// Blocking filesystem/ZIP work stays off the main actor. Raw SDK stores are never copied.
actor DiagnosticArchive {
    func writeMarkdown(_ report:DiagnosticReport,to destination:URL) throws { try report.markdown().write(to:destination,atomically:true,encoding:.utf8) }
    func write(_ report:DiagnosticReport,to destination:URL) throws {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("LumaDiagnostics-"+UUID().uuidString,isDirectory:true)
        let zip = staging.appendingPathExtension("zip")
        defer { try? FileManager.default.removeItem(at:staging); try? FileManager.default.removeItem(at:zip) }
        try FileManager.default.createDirectory(at:staging,withIntermediateDirectories:true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; encoder.dateEncodingStrategy = .millisecondsSince1970
        try encoder.encode(report).write(to:staging.appendingPathComponent("diagnostics.json"),options:.atomic)
        try report.markdown().write(to:staging.appendingPathComponent("BugReport.md"),atomically:true,encoding:.utf8)
        var csv = "time_epoch,luma_cpu_percent_one_core,luma_rss_bytes,luma_footprint_bytes,system_cpu_percent,system_used_bytes_estimate,battery_percent,thermal,memory_pressure,sampler_wall_ms\n"
        for row in report.samples {
            let values = [String(row.time.timeIntervalSince1970),row.processCPUPercent.map { String($0) } ?? "",row.processResidentBytes.map { String($0) } ?? "",row.processFootprintBytes.map { String($0) } ?? "",row.systemCPUPercent.map { String($0) } ?? "",row.systemUsedBytesEstimate.map { String($0) } ?? "",row.batteryPercent.map { String($0) } ?? "",row.thermal.map { String($0) } ?? "",row.memoryPressure.map { String($0) } ?? "",String(row.samplerWallMs)]
            csv += values.joined(separator:",")+"\n"
        }
        try csv.write(to:staging.appendingPathComponent("Performance.csv"),atomically:true,encoding:.utf8)
        try FileManager.default.zipItem(at:staging,to:zip,shouldKeepParent:false)
        // NSSavePanel has already obtained overwrite confirmation; atomic replacement keeps a prior report intact on failure.
        try Data(contentsOf:zip,options:.mappedIfSafe).write(to:destination,options:.atomic)
    }
}
