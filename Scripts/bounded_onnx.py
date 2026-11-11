"""Scoped adapter for pinned kittenml 0.9.7's ONNX-only loader.

It does not modify the installed package or the global onnxruntime module.
ONNX thread/spin settings: https://onnxruntime.ai/docs/performance/tune-performance/threading.html
The legacy loader has no SessionOptions argument; replace only its local module
reference during construction, then restore it even if loading fails.
"""
from contextlib import contextmanager
import threading

_LOAD_LOCK = threading.RLock()

@contextmanager
def bounded_sessions(legacy_module=None):
    if legacy_module is None:
        import kittenml.kittentts_legacy.onnx_model as legacy_module
    with _LOAD_LOCK:
        runtime = legacy_module.ort
        options = runtime.SessionOptions()
        options.intra_op_num_threads = 2
        options.inter_op_num_threads = 1
        options.execution_mode = runtime.ExecutionMode.ORT_SEQUENTIAL
        options.enable_mem_pattern = False
        options.enable_cpu_mem_arena = False
        options.add_session_config_entry('session.intra_op.allow_spinning', '0')
        options.add_session_config_entry('session.inter_op.allow_spinning', '0')
        class ScopedRuntime:
            def __getattr__(self, name):
                return getattr(runtime, name)
            def InferenceSession(self, *args, **kwargs):
                kwargs['sess_options'] = options
                kwargs['providers'] = ['CPUExecutionProvider']
                return runtime.InferenceSession(*args, **kwargs)
        legacy_module.ort = ScopedRuntime()
        try:
            yield
        finally:
            legacy_module.ort = runtime
