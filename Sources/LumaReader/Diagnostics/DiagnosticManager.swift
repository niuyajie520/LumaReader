import SwiftUI
import Observation
import CoreData
import UniformTypeIdentifiers
import Pulse
import KSCrashRecording
import KSCrashMonitors

@MainActor @Observable
final class DiagnosticManager {
    static let shared = DiagnosticManager()
    var enabled = UserDefaults.standard.bool(forKey:"diagnostics.enabled") { didSet { persist("enabled",enabled); configure(); if enabled { record(.enabled) } } }
    var cpuMonitoring = UserDefaults.standard.object(forKey:"diagnostics.cpu") as? Bool ?? true { didSet { persist("cpu",cpuMonitoring); configure() } }
    var memoryMonitoring = UserDefaults.standard.object(forKey:"diagnostics.memory") as? Bool ?? true { didSet { persist("memory",memoryMonitoring); configure() } }
    var powerMonitoring = UserDefaults.standard.object(forKey:"diagnostics.power") as? Bool ?? true { didSet { persist("power",powerMonitoring); configure() } }
    var automaticDetection = UserDefaults.standard.object(forKey:"diagnostics.auto") as? Bool ?? true { didSet { persist("auto",automaticDetection) } }
    var backgroundRecording = UserDefaults.standard.bool(forKey:"diagnostics.background") { didSet { persist("background",backgroundRecording); configure() } }
    var crashCaptureEnabled = UserDefaults.standard.bool(forKey:"diagnostics.crash") { didSet { persist("crash",crashCaptureEnabled) } }
    var metricKitEnabled = UserDefaults.standard.bool(forKey:"diagnostics.metricKit") { didSet { persist("metricKit",metricKitEnabled) } }
    private(set) var samples: [DiagnosticSample] = []
    private(set) var events: [DiagnosticEvent] = []
    private(set) var latest: DiagnosticSample?
    private(set) var sampling = false
    private(set) var crashActive = false
    private(set) var crashReportCount: Int?
    private(set) var previousTerminationCode: Int?
    private(set) var status: String?
    private(set) var exporting = false
    @ObservationIgnored private var store: LoggerStore?
    @ObservationIgnored private let sampler = DiagnosticSampler()
    @ObservationIgnored private var samplingTask: Task<Void,Never>?
    @ObservationIgnored private var pressureSource: (any DispatchSourceMemoryPressure)?
    @ObservationIgnored private var pressure: Int?
    @ObservationIgnored private var visibleCount = 0
    @ObservationIgnored private var started = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pending: [DiagnosticOperation:(id:UUID,start:UInt64)] = [:]
    @ObservationIgnored private var deadlines: [DiagnosticOperation:Task<Void,Never>] = [:]
    @ObservationIgnored var aiHealthCheck: (() -> Void)?
    @ObservationIgnored private var lastError: [DiagnosticCode:Date] = [:]
    let root = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("LumaReader/Diagnostics",isDirectory:true)
    private var storeURL: URL { root.appendingPathComponent("Events.pulse-store",isDirectory:true) }
    enum DiagnosticOperation: Hashable { case aiBoot, bookLoad, viewport }

    func applicationDidStart() {
        guard !started else { return }; started = true
        for name in [NSApplication.didBecomeActiveNotification,NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                MainActor.assumeIsolated { self?.configure() }
            })
        }
        configure(); record(.appStarted)
        if enabled && crashCaptureEnabled { installCrashReporter() }
    }
    private func persist(_ key:String,_ value:Bool) { UserDefaults.standard.set(value,forKey:"diagnostics."+key) }
    private func openStore(readonly:Bool = false) throws -> LoggerStore {
        // Remote logging is never enabled by this application, including a persisted SDK flag.
        UserDefaults.standard.set(false,forKey:"com-github-kean-pulse-is-remote-logger-enabled")
        RemoteLogger.shared.disable()
        if !readonly { try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true) }
        var configuration = LoggerStore.Configuration(sizeLimit:25*1_000_000)
        configuration.maxAge = 7*86400; configuration.responseBodySizeLimit = 0
        return try LoggerStore(storeURL:storeURL,options:readonly ? [.readonly]:[.create,.sweep],configuration:configuration)
    }
    private func configure() {
        samplingTask?.cancel(); samplingTask = nil; sampling = false; latest = nil
        if enabled, store == nil {
            do { store = try openStore() } catch { status = "日志存储不可用"; record(.logStoreFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)]) }
        }
        if !enabled {
            deadlines.values.forEach { $0.cancel() }; deadlines = [:]; pending = [:]
            pressureSource?.cancel(); pressureSource = nil; pressure = nil
            try? store?.close(); store = nil
            return
        }
        if memoryMonitoring && pressureSource == nil {
            let source = DispatchSource.makeMemoryPressureSource(eventMask:[.normal,.warning,.critical],queue:.main)
            pressureSource = source
            source.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.consumePressure() } }
            source.resume()
        } else if !memoryMonitoring { pressureSource?.cancel(); pressureSource = nil; pressure = nil }
        guard (cpuMonitoring || memoryMonitoring || powerMonitoring), (visibleCount > 0 || backgroundRecording), NSApp.isActive else { return }
        sampling = true
        samplingTask = Task { [weak self] in
            guard let self else { return }; await sampler.reset()
            while !Task.isCancelled {
                var sample = await sampler.sample(cpu:cpuMonitoring,memory:memoryMonitoring,power:powerMonitoring)
                guard !Task.isCancelled, enabled else { break }
                sample.memoryPressure = memoryMonitoring ? pressure:nil
                latest = sample; samples.append(sample)
                if samples.count > 600 { samples.removeFirst(samples.count-600) }
                let thermal = ProcessInfo.processInfo.thermalState
                var interval = thermal == .critical ? 8.0:thermal == .serious ? 4.0:2.0
                if ProcessInfo.processInfo.isLowPowerModeEnabled { interval *= 2 }
                do { try await Task.sleep(for:.seconds(interval)) } catch { break }
            }
        }
    }
    func viewAppeared() { visibleCount += 1; configure(); refreshCrashCount() }
    func viewDisappeared() { visibleCount = max(0,visibleCount-1); configure() }
    private func consumePressure() {
        guard enabled, let source = pressureSource else { return }
        let data = source.data
        guard !data.intersection([.normal,.warning,.critical]).isEmpty else { return }
        let value = data.contains(.critical) ? 4:data.contains(.warning) ? 2:1
        if value != pressure { pressure = value; record(.memoryPressure,isError:value == 4,fields:[.pressure:Double(value)]) }
    }
    func record(_ code:DiagnosticCode,isError:Bool = false,fields:[DiagnosticField:Double] = [:]) {
        guard DiagnosticCapturePolicy.shouldRecord(verbose:enabled,automatic:automaticDetection,isError:isError) else { return }
        if isError, let previous = lastError[code], Date().timeIntervalSince(previous) < 1 { return }
        if isError { lastError[code] = Date() }
        let event = DiagnosticEvent(code:code,isError:isError,fields:fields)
        events.append(event); if events.count > 500 { events.removeFirst(events.count-500) }
        guard enabled else { if events.count > 128 { events.removeFirst(events.count-128) }; return }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(event), let message = String(data:data,encoding:.utf8) else { return }
        store?.storeMessage(label:isError ? "LumaReader.error":"LumaReader.event",level:isError ? .error:.info,message:message,file:"LumaReader",function:"diagnostic",line:0)
    }
    func begin(_ operation:DiagnosticOperation) {
        guard enabled, pending[operation] == nil else { return }
        let id = UUID(); pending[operation] = (id,DispatchTime.now().uptimeNanoseconds)
        record(operation == .aiBoot ? .aiBootStart:operation == .bookLoad ? .bookLoadStart:.viewportStart)
        if automaticDetection {
            deadlines[operation] = Task { [weak self] in
                do { try await Task.sleep(for:.seconds(operation == .bookLoad ? 20:10)) } catch { return }
                guard let self, pending[operation]?.id == id else { return }
                record(operation == .aiBoot ? .aiTimeout:operation == .bookLoad ? .bookTimeout:.viewportTimeout,isError:true)
                pending.removeValue(forKey:operation); deadlines.removeValue(forKey:operation)
            }
        }
    }
    func finish(_ operation:DiagnosticOperation) {
        guard enabled, let value = pending.removeValue(forKey:operation) else { return }
        deadlines.removeValue(forKey:operation)?.cancel()
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds-value.start)/1_000_000
        record(operation == .aiBoot ? .aiReady:operation == .bookLoad ? .bookReady:.viewportSettled,fields:[.durationMs:elapsed])
    }
    func cancel(_ operation:DiagnosticOperation) { deadlines.removeValue(forKey:operation)?.cancel(); pending.removeValue(forKey:operation) }
    func aiVisibility(_ visible:Bool) { record(visible ? .aiOpen:.aiClose) }
    func network(statusCode:Int?,receivedBytes:Int,errorCode:Int?,durationMs:Double) {
        guard enabled || automaticDetection else { return }
        var fields:[DiagnosticField:Double] = [.durationMs:durationMs,.receivedBytes:Double(receivedBytes)]
        if let statusCode { fields[.statusCode] = Double(statusCode) }
        if let errorCode { fields[.errorCode] = Double(errorCode) }
        let failed = errorCode != nil || (statusCode ?? 200) >= 400
        record(errorCode == NSURLErrorCancelled ? .networkCancelled:failed ? .networkFailed:.networkComplete,isError:failed && errorCode != NSURLErrorCancelled,fields:fields)
        guard enabled else { return }
        // Pulse receives a synthetic diagnostic URL and no original headers, errors or bodies.
        let url = URL(string:"https://diagnostics.invalid/luma-ai")!
        var request = URLRequest(url:url); request.httpMethod = "POST"
        let response = statusCode.flatMap { HTTPURLResponse(url:url,statusCode:$0,httpVersion:nil,headerFields:nil) }
        store?.storeRequest(request,response:response,error:nil,data:nil,label:"LumaReader.network",taskDescription:"Metadata only; original URL and content excluded")
    }
    func requestAIHealthCheck() {
        guard let aiHealthCheck else { status = "AI 界面尚未加载，无法检查"; return }
        status = "正在检查 AI 界面"; aiHealthCheck()
    }
    func receiveAIHealth(_ fields:[DiagnosticField:Double]) -> Bool {
        let healthy = fields[.bridgeReady] == 1 && fields[.stylesReady] == 1 && fields[.missingNodes] == 0 && fields[.oversizedIcons] == 0 && fields[.overflow] == 0
        record(healthy ? .aiHealthPassed:.aiHealthFailed,isError:!healthy,fields:fields)
        status = healthy ? "AI 界面结构与样式检查通过":"AI 界面结构或样式异常"
        return healthy
    }
    func validatePagination(_ value:[String:Any]) {
        guard automaticDetection else { return }
        guard let columns = value["columns"] as? Int, let count = value["count"] as? Int, let index = value["index"] as? Int else { record(.invalidPagination,isError:true); return }
        if !(1...2).contains(columns) || count < 1 || index < 0 || index >= count || index % max(1,columns) != 0 {
            record(.invalidPagination,isError:true,fields:[.columns:Double(columns),.pages:Double(count),.index:Double(index)])
        }
    }
    private func installCrashReporter() {
        guard NSGetUncaughtExceptionHandler() == nil else { record(.crashHandlerConflict,isError:true); status = "已有异常处理器，未安装第二个崩溃处理器"; return }
        let configuration = KSCrashConfiguration()
        configuration.installPath = root.appendingPathComponent("Crashes").path
        configuration.enableMemoryIntrospection = false; configuration.enableQueueNameSearch = false
        configuration.enableHangReporting = true; configuration.enableCPUExceptionReporting = false
        configuration.enableCompactBinaryImages = true; configuration.reportStoreConfiguration.maxReportCount = 5
        if metricKitEnabled { configuration.plugins = [MetricKitMonitor()] }
        do { try KSCrash.shared.install(with:configuration); crashActive = true; record(.crashInstalled); refreshCrashCount() }
        catch { record(.crashInstallFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)]) }
    }
    func refreshCrashCount() { if crashActive { crashReportCount = KSCrash.shared.reportStore?.reportCount; previousTerminationCode = Int(KSCrash.shared.previousTerminationReason.rawValue) } }
    func storedEvents(errorsOnly:Bool = false) -> [DiagnosticEvent] {
        var temporary: LoggerStore?
        var combined = events.filter { !errorsOnly || $0.isError }
        do {
            let active: LoggerStore
            if let store { active = store }
            else if FileManager.default.fileExists(atPath:storeURL.path) { let opened = try openStore(readonly:true); temporary = opened; active = opened }
            else { return combined.sorted { $0.time > $1.time } }
            defer { try? temporary?.close() }
            let request = NSFetchRequest<LoggerMessageEntity>(entityName:"LoggerMessageEntity")
            request.fetchLimit = 500; request.sortDescriptors = [NSSortDescriptor(key:"createdAt",ascending:false)]
            request.predicate = NSPredicate(format:errorsOnly ? "label == %@":"label BEGINSWITH %@",errorsOnly ? "LumaReader.error":"LumaReader.")
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
            for entity in try active.viewContext.fetch(request) {
                if let data = entity.text.data(using:.utf8), let event = try? decoder.decode(DiagnosticEvent.self,from:data) { combined.append(event) }
            }
        } catch { status = "读取日志失败" }
        var ids = Set<UUID>()
        return combined.sorted { $0.time > $1.time }.filter { ids.insert($0.id).inserted }.prefix(500).map { $0 }
    }
    func exportReport(markdownOnly:Bool = false) async {
        let panel = NSSavePanel(); panel.allowedContentTypes = markdownOnly ? [.plainText]:[.zip]
        panel.nameFieldStringValue = "LumaReader-Diagnostics-\(Int(Date().timeIntervalSince1970))."+(markdownOnly ? "md":"zip")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exporting = true; defer { exporting = false }
        refreshCrashCount()
        let version = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "development"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let report = DiagnosticReport(appVersion:version,osVersion:"\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",samples:samples,events:Array(storedEvents().reversed()),crashReportsStored:crashReportCount,crashCaptureActive:crashActive,previousTerminationCode:previousTerminationCode)
        do { if markdownOnly { try await DiagnosticArchive().writeMarkdown(report,to:url) } else { try await DiagnosticArchive().write(report,to:url) }; record(.exportComplete); status = "诊断报告已导出" }
        catch { status = "诊断报告导出失败"; record(.exportFailed,isError:true,fields:[.errorCode:Double((error as NSError).code)]) }
    }
}
