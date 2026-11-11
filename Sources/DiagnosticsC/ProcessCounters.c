/* Adapted from Zesty0wl/mac-performance-monitor v2.6.0.306, shim.c cmacperfmonitor_rusage.
 * Copyright (c) 2026 Mac Performance Monitor contributors. MIT.
 * See ThirdParty/Diagnostics/Zesty0wl_mac-performance-monitor-LICENSE.txt.
 * Restricted to our own PID; v2 fields only, no energy estimate or privileged process enumeration. */
#include "DiagnosticsC.h"
#include <libproc.h>
#include <sys/resource.h>
#include <string.h>
#include <unistd.h>
int luma_process_counters(LumaProcessCounters *result) {
    struct rusage_info_v2 ru;
    memset(&ru,0,sizeof(ru));
    if (!result || proc_pid_rusage(getpid(),RUSAGE_INFO_V2,(rusage_info_t *)&ru) != 0) return -1;
    result->cpu_nanoseconds = ru.ri_user_time + ru.ri_system_time;
    result->resident_bytes = ru.ri_resident_size;
    result->footprint_bytes = ru.ri_phys_footprint;
    return 0;
}
