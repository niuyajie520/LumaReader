// Public-API subset adapted from Desktop-Overlay v2.0, SystemMetricsService.swift.
// Copyright (c) 2026 Al Hanashi, MIT; see ThirdParty/Diagnostics.
import Foundation
import Darwin
import IOKit.ps

enum DiagnosticSystemReaders {
    static func cpuTicks() -> CPUTicks? {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info_data_t()
        let host = mach_host_self(); defer { mach_port_deallocate(mach_task_self_,host) }
        let result = withUnsafeMutablePointer(to:&info) { pointer in
            pointer.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { host_statistics(host,HOST_CPU_LOAD_INFO,$0,&count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user:UInt64(info.cpu_ticks.0),system:UInt64(info.cpu_ticks.1),idle:UInt64(info.cpu_ticks.2),nice:UInt64(info.cpu_ticks.3))
    }
    static func memoryUsage() -> MemoryUsage? {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = vm_statistics64_data_t(), size:vm_size_t = 0
        let host = mach_host_self(); defer { mach_port_deallocate(mach_task_self_,host) }
        guard host_page_size(host,&size) == KERN_SUCCESS else { return nil }
        let result = withUnsafeMutablePointer(to:&info) { pointer in
            pointer.withMemoryRebound(to:integer_t.self,capacity:Int(count)) { host_statistics64(host,HOST_VM_INFO64,$0,&count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryCalculator.usage(sample:MemorySample(active:UInt64(info.active_count),wired:UInt64(info.wire_count),compressed:UInt64(info.compressor_page_count),free:UInt64(info.free_count),inactive:UInt64(info.inactive_count)),pageSize:UInt64(size),physical:ProcessInfo.processInfo.physicalMemory)
    }
    static func batteryPercent() -> Double? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot,source)?.takeUnretainedValue() as? [String:Any],
                  let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue,
                  let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue, maximum > 0 else { continue }
            return min(100,max(0,current/maximum*100))
        }
        return nil
    }
}
