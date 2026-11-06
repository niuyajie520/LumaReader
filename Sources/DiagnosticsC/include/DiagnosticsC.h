#ifndef LUMA_DIAGNOSTICS_C_H
#define LUMA_DIAGNOSTICS_C_H
#include <stdint.h>
typedef struct { uint64_t cpu_nanoseconds; uint64_t resident_bytes; uint64_t footprint_bytes; } LumaProcessCounters;
int luma_process_counters(LumaProcessCounters *result);
#endif
