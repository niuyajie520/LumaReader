import Foundation

enum DiagnosticCode: String, Codable, Sendable {
    case aiHealthPassed, aiHealthFailed
    case enabled, appStarted, aiOpen, aiClose, aiBootStart, aiReady, aiBootFailed, aiScriptFailed, aiPromiseFailed, aiContentPolicyFailed, aiResponseInvalid, aiRequestInvalid, aiNavigationFailed, aiProcessTerminated, aiTimeout
    case bookImportFailed, cloudSyncFailed
    case bookLoadStart, bookReady, bookClose, bookLoadFailed, bookTimeout, viewportStart, viewportSettled, viewportTimeout, invalidPagination
    case networkComplete, networkFailed, networkCancelled, crashInstalled, crashInstallFailed, crashHandlerConflict, memoryPressure, logStoreFailed, exportFailed, exportComplete
}
enum DiagnosticField: String, Sendable {
    case missingNodes, oversizedIcons, overflow, layoutReady
    case terminationReason, bridgeReady, stylesReady, durationMs, statusCode, errorCode, receivedBytes, width, height, columns, pages, index, epoch, pressure, thermal, format
}
struct DiagnosticEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let time: Date
    let code: DiagnosticCode
    let isError: Bool
    let fields: [String:Double]
    init(code:DiagnosticCode,isError:Bool = false,fields:[DiagnosticField:Double] = [:]) {
        id = UUID(); time = Date(); self.code = code; self.isError = isError
        self.fields = Dictionary(uniqueKeysWithValues:fields.compactMap { $0.value.isFinite ? ($0.key.rawValue,$0.value):nil })
    }
    enum CodingKeys:String,CodingKey { case id,time,code,isError,fields }
    init(from decoder:Decoder) throws {
        let values = try decoder.container(keyedBy:CodingKeys.self)
        id = try values.decode(UUID.self,forKey:.id); time = try values.decode(Date.self,forKey:.time)
        code = try values.decode(DiagnosticCode.self,forKey:.code); isError = try values.decode(Bool.self,forKey:.isError)
        let incoming = try values.decode([String:Double].self,forKey:.fields)
        fields = incoming.filter { DiagnosticField(rawValue:$0.key) != nil && $0.value.isFinite }
    }
}
struct DiagnosticSample: Codable, Identifiable, Sendable {
    var id = UUID()
    var time = Date()
    var processCPUPercent: Double?
    var processResidentBytes: UInt64?
    var processFootprintBytes: UInt64?
    var systemCPUPercent: Double?
    var systemUsedBytesEstimate: UInt64?
    var batteryPercent: Double?
    var thermal: Int?
    var lowPowerMode: Bool?
    var memoryPressure: Int?
    var samplerWallMs: Double = 0
}
struct DiagnosticReport: Codable, Sendable {
    var schemaVersion = 1
    var generatedAt = Date()
    var appVersion: String
    var osVersion: String
    var samples: [DiagnosticSample]
    var events: [DiagnosticEvent]
    var crashReportsStored: Int?
    var crashCaptureActive: Bool
    var previousTerminationCode: Int? = nil
    var unavailable = ["webkitAuxiliaryCPU":"Not Available: no reliable ownership attribution; Safari/other apps are not aggregated.","webkitAuxiliaryMemory":"Not Available: no reliable ownership attribution.","processGPUPercent":"Not Available: no private GPU counters enabled.","systemGPUPercent":"Not Available: no private GPU counters enabled.","systemPowerWatts":"Not Available: no IOReport/SMC or privileged helper.","debugCPUOverhead":"Not measured: requires native A/B profiling.","debugMemoryOverhead":"Not measured: requires native A/B profiling."]
    var privacy = "Allowlisted event codes and numeric fields only. No book text, title, paths, queries, notes, conversations, URLs, headers, keys, request/response bodies, host name or raw crash/Pulse files."
    func markdown() -> String {
        var text = "# LumaReader Diagnostic Report\n\nApp: \(appVersion)\nmacOS: \(osVersion)\nSamples: \(samples.count)\nStored crash reports: \(crashReportsStored.map(String.init) ?? "Not Available")\n\n## Scope\n\nLumaReader CPU is percent of one core and can exceed 100%. RSS and physical footprint are separate process metrics; WebKit is excluded. System memory is an active+wired+compressed estimate, not Activity Monitor's exact accounting. Battery charge and thermal state are not power in watts. Missing readings are Not Available.\n\n## Privacy\n\n\(privacy)\n\n## Unavailable\n\n"
        for key in unavailable.keys.sorted() { text += "- \(key): \(unavailable[key] ?? "Not Available")\n" }
        text += "\n## Observed samples (not continuous peaks)\n\n"
        if let cpu = samples.compactMap(\.processCPUPercent).max() { text += "- LumaReader maximum observed CPU (one core = 100%): \(cpu)%\n" }
        if let memory = samples.compactMap(\.processFootprintBytes).max() { text += "- LumaReader maximum observed footprint: \(memory) bytes\n" }
        text += "- Previous termination code: \(previousTerminationCode.map(String.init) ?? "Not Available")\n"
        text += "\n## Timeline\n\n| Time (UTC) | Event | Error | Numeric context |\n| --- | --- | --- | --- |\n"
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
        for event in events {
            let values = event.fields.keys.sorted().map { "\($0)=\(event.fields[$0] ?? 0)" }.joined(separator:", ")
            text += "| \(formatter.string(from:event.time)) | \(event.code.rawValue) | \(event.isError) | \(values) |\n"
        }
        return text
    }
}

/// Basic errors are a bounded in-memory ring; verbose logging is opt-in.
enum DiagnosticCapturePolicy {
    static func shouldRecord(verbose:Bool,automatic:Bool,isError:Bool) -> Bool {
        isError ? automatic:verbose
    }
}
