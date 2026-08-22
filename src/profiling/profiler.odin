package profiling

import "core:prof/spall"

PROFILE :: #config(PROFILE, false)
when PROFILE {
    profiler: spall.Context
    @(thread_local) prof_buffer: spall.Buffer
}