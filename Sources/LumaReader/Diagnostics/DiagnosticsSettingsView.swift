import SwiftUI
import Charts

struct DiagnosticsSettingsView: View {
    @State private var manager = DiagnosticManager.shared
    @State private var errorsOnly = false
    @State private var logs: [DiagnosticEvent] = []
    @State private var metric = "processCPU"
    private func binding(_ key:ReferenceWritableKeyPath<DiagnosticManager,Bool>) -> Binding<Bool> {
        Binding(get:{ manager[keyPath:key] },set:{ manager[keyPath:key] = $0 })
    }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Toggle(L10n.text("Debug 模式"),isOn:binding(\.enabled))
            Text(L10n.text("详细日志与性能采样默认关闭。基础错误只保存在本次会话内存中，最多 128 条，不自动上传。"))
                .font(.caption).foregroundStyle(.secondary)
            Group {
                Toggle(L10n.text("CPU 监测"),isOn:binding(\.cpuMonitoring))
                Toggle(L10n.text("内存占用与内存压力"),isOn:binding(\.memoryMonitoring))
                Toggle(L10n.text("电池与热状态"),isOn:binding(\.powerMonitoring))
                Toggle(L10n.text("后台记录性能（可选）"),isOn:binding(\.backgroundRecording))
                Text(L10n.text("默认离开此页就暂停性能采样；后台记录开启后，仅在应用处于活跃状态时继续。热压力高时降低采样频率。"))
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(!manager.enabled)
            Toggle(L10n.text("自动错误检测"),isOn:binding(\.automaticDetection))
            Button(L10n.text("检查 AI 界面")) { manager.requestAIHealthCheck() }
            Toggle(L10n.text("GPU 监测（当前不可用）"),isOn:.constant(false)).disabled(true)
            Divider()
            Toggle(L10n.text("崩溃与卡死捕获（重启生效）"),isOn:binding(\.crashCaptureEnabled)).disabled(!manager.enabled)
            Toggle(L10n.text("MetricKit 延迟诊断（重启生效）"),isOn:binding(\.metricKitEnabled)).disabled(!manager.enabled || !manager.crashCaptureEnabled)
            Text(L10n.text("只使用 KSCrash。原始报告可能包含系统路径，内存内容探测关闭；原始报告不会加入导出文件。关闭已安装的捕获器需要重启。CPU 开关不控制 KSCrash 自身的资源跟踪器。"))
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent(L10n.text("本次捕获状态")) { Text(L10n.text(manager.crashActive ? "已安装，完全停用需重启":"未安装，更改下次启动生效")) }
            LabeledContent(L10n.text("本地崩溃报告")) { Text(manager.crashReportCount.map(String.init) ?? "Not Available") }
            LabeledContent(L10n.text("上次终止原因代码")) { Text(manager.previousTerminationCode.map(String.init) ?? "Not Available") }
            Button(L10n.text("刷新崩溃计数")) { manager.refreshCrashCount() }
            Divider()
            Text(L10n.text("LumaReader 进程（不含 WebKit）")).font(.headline)
            LabeledContent("CPU") { Text(percent(manager.latest?.processCPUPercent)) }
            LabeledContent("RSS") { Text(bytes(manager.latest?.processResidentBytes)) }
            LabeledContent(L10n.text("物理占用")) { Text(bytes(manager.latest?.processFootprintBytes)) }
            Text(L10n.text("进程 CPU 按单核 100% 计，可超过 100%；RSS 与物理占用是不同指标。"))
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent(L10n.text("LumaReader GPU")) { Text("Not Available") }
            LabeledContent(L10n.text("WebKit 辅助进程 CPU / 内存 / GPU")) { Text("Not Available") }
            Text(L10n.text("整机系统")).font(.headline)
            LabeledContent("CPU") { Text(percent(manager.latest?.systemCPUPercent)) }
            LabeledContent(L10n.text("已用内存（估计）")) { Text(bytes(manager.latest?.systemUsedBytesEstimate)) }
            LabeledContent(L10n.text("内存压力（系统通知）")) { Text(pressure(manager.latest?.memoryPressure)) }
            LabeledContent(L10n.text("电池电量")) { Text(percent(manager.latest?.batteryPercent)) }
            LabeledContent(L10n.text("热状态")) { Text(thermal(manager.latest?.thermal)) }
            LabeledContent(L10n.text("低电量模式")) { Text(manager.latest?.lowPowerMode.map { L10n.text($0 ? "开启":"关闭") } ?? "Not Available") }
            LabeledContent(L10n.text("GPU 利用率 / 功耗 W")) { Text("Not Available") }
            Text(L10n.text("不启用 IOReport、SMC 或特权助手。电池百分比与热状态不是瓦特数；不能可靠归属的 WebKit CPU、内存及 GPU 均为 Not Available。"))
                .font(.caption).foregroundStyle(.secondary)
            LabeledContent(L10n.text("采样状态")) { Text(L10n.text(manager.sampling ? "正在采样":"已暂停")) }
            LabeledContent(L10n.text("单次采样墙钟耗时")) { Text(manager.latest.map { String(format:"%.3f ms",$0.samplerWallMs) } ?? "Not Available") }
            Text(L10n.text("这不是 Debug 的 CPU 或内存开销测量；需要原生 A/B 性能测试。"))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text(L10n.text("性能历史（本次会话，最多 600 点）")).font(.headline)
            Picker(L10n.text("历史指标"),selection:$metric) {
                Text(L10n.text("进程 CPU %")).tag("processCPU")
                Text(L10n.text("整机 CPU %")).tag("systemCPU")
                Text(L10n.text("进程物理占用 MiB")).tag("processMemory")
                Text(L10n.text("整机内存估计 MiB")).tag("systemMemory")
            }
            if points.isEmpty { Text(L10n.text("尚无有效采样，缺失数据不会显示为零。")).font(.caption).foregroundStyle(.secondary) }
            else {
                Chart(points) { point in
                    LineMark(x:.value("Time",point.time),y:.value("Value",point.value),series:.value("Segment",point.segment))
                        .foregroundStyle(Color.accentColor)
                }.frame(height:140)
            }
            Divider()
            HStack {
                Text(L10n.text("Bug 日志（Pulse）")).font(.headline)
                Spacer()
                Button(L10n.text("刷新")) { refresh() }
            }
            Toggle(L10n.text("只看错误"),isOn:$errorsOnly)
            ForEach(Array(logs.prefix(60))) { event in
                VStack(alignment:.leading,spacing:3) {
                    HStack { Text(event.code.rawValue).font(.system(.caption,design:.monospaced)); Spacer(); Text(event.time,style:.time).font(.caption2) }
                    if !event.fields.isEmpty {
                        Text(event.fields.keys.sorted().map { "\($0)=\(event.fields[$0] ?? 0)" }.joined(separator:" · "))
                            .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
            if logs.isEmpty { Text(L10n.text("暂无诊断事件")).font(.caption).foregroundStyle(.secondary) }
            HStack {
                Button(L10n.text("导出诊断 ZIP")) { Task { await manager.exportReport() } }
                Button(L10n.text("导出 Markdown")) { Task { await manager.exportReport(markdownOnly:true) } }
                if manager.exporting { ProgressView().controlSize(.small) }
            }.disabled(manager.exporting)
            Text(L10n.text("导出只含白名单事件与数值，不含书籍正文、笔记、AI 对话、URL、密钥、路径、主机名、原始 Pulse 或原始崩溃报告。"))
                .font(.caption).foregroundStyle(.secondary)
            if let status = manager.status { Text(L10n.text(status)).font(.caption) }
        }
        .font(.callout)
        .onAppear { manager.viewAppeared(); refresh() }
        .onDisappear { manager.viewDisappeared() }
        .onChange(of:errorsOnly) { _,_ in refresh() }
        .onChange(of:manager.events.last?.id) { _,_ in refresh() }
    }
    private func refresh() { logs = manager.storedEvents(errorsOnly:errorsOnly) }
    private func percent(_ value:Double?) -> String { value.map { String(format:"%.1f%%",$0) } ?? "Not Available" }
    private func bytes(_ value:UInt64?) -> String { value.map { ByteCountFormatter.string(fromByteCount:Int64(clamping:$0),countStyle:.memory) } ?? "Not Available" }
    private func pressure(_ value:Int?) -> String { value.flatMap { MemoryPressure(rawValue:$0)?.label } ?? "Not Available" }
    private func thermal(_ value:Int?) -> String {
        guard let value, let state = ProcessInfo.ThermalState(rawValue:value) else { return "Not Available" }
        switch state { case .nominal:return "Nominal";case .fair:return "Fair";case .serious:return "Serious";case .critical:return "Critical";@unknown default:return "Not Available" }
    }
    private struct Point: Identifiable { var id:UUID; var time:Date; var value:Double; var segment:Int }
    private var points: [Point] {
        var result:[Point] = [], segment = 0, previous:Date?
        for sample in manager.samples {
            let value:Double?
            switch metric {
            case "systemCPU":value = sample.systemCPUPercent
            case "processMemory":value = sample.processFootprintBytes.map { Double($0)/1_048_576 }
            case "systemMemory":value = sample.systemUsedBytesEstimate.map { Double($0)/1_048_576 }
            default:value = sample.processCPUPercent
            }
            if let value {
                if let previous, sample.time.timeIntervalSince(previous) > 20 { segment += 1 }
                result.append(Point(id:sample.id,time:sample.time,value:value,segment:segment)); previous = sample.time
            } else { segment += 1; previous = nil }
        }
        return result
    }
}
