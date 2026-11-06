import Foundation
import DiagnosticsC

/// One actor owns all prior counters; one caller task drives the whole sampling session.
actor DiagnosticSampler {
    private var previousTicks: CPUTicks?
    private var previousProcess: (time:UInt64,cpu:UInt64)?
    func reset() { previousTicks = nil; previousProcess = nil }
    func sample(cpu:Bool,memory:Bool,power:Bool) -> DiagnosticSample {
        let started = DispatchTime.now().uptimeNanoseconds
        var result = DiagnosticSample()
        if cpu || memory {
            var counters = LumaProcessCounters()
            if luma_process_counters(&counters) == 0 {
                if cpu, let previous = previousProcess, started > previous.time, counters.cpu_nanoseconds >= previous.cpu {
                    result.processCPUPercent = Double(counters.cpu_nanoseconds-previous.cpu)/Double(started-previous.time)*100
                }
                previousProcess = (started,counters.cpu_nanoseconds)
                if memory { result.processResidentBytes = counters.resident_bytes; result.processFootprintBytes = counters.footprint_bytes }
            } else { previousProcess = nil }
        }
        if cpu {
            if let ticks = DiagnosticSystemReaders.cpuTicks() {
                if let previousTicks, ticks.user >= previousTicks.user, ticks.system >= previousTicks.system, ticks.idle >= previousTicks.idle, ticks.nice >= previousTicks.nice, ticks != previousTicks { result.systemCPUPercent = CPUCalculator.usage(from:previousTicks,to:ticks).total }
                previousTicks = ticks
            } else { previousTicks = nil }
        }
        if memory { result.systemUsedBytesEstimate = DiagnosticSystemReaders.memoryUsage()?.usedBytes }
        if power {
            result.thermal = ProcessInfo.processInfo.thermalState.rawValue
            result.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            result.batteryPercent = DiagnosticSystemReaders.batteryPercent()
        }
        result.samplerWallMs = Double(DispatchTime.now().uptimeNanoseconds-started)/1_000_000
        return result
    }
}
