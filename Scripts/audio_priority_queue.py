"""Single synthesis worker with foreground priority and sliding background jobs."""
from collections import deque
from concurrent.futures import Future
import threading
import time

class AudioPriorityQueue:
    def __init__(self, generate, max_pending=32, request_timeout=60):
        self.generate = generate
        self.max_pending = max_pending
        self.request_timeout = request_timeout
        self.last_activity = time.monotonic()
        self.condition = threading.Condition()
        self.jobs = {}
        self.foreground = deque()
        self.background = deque()
        self.worker = threading.Thread(target=self._run, daemon=True)
        self.worker.start()

    def _submit(self, key, payload, urgent):
        job = self.jobs.get(key)
        if job is None:
            if len(self.jobs) >= self.max_pending:
                raise RuntimeError("语音队列已满，请稍后重试")
            job = dict(key=key, payload=payload, future=Future(), urgent=urgent, started=False)
            self.jobs[key] = job
            (self.foreground if urgent else self.background).append(job)
        elif urgent and not job['urgent']:
            job['urgent'] = True
            if not job['started']:
                self.foreground.append(job)
        self.last_activity = time.monotonic()
        self.condition.notify()
        return job['future']

    def request(self, key, payload):
        with self.condition:
            future = self._submit(key, payload, True)
        return future.result(timeout=self.request_timeout)

    def preload(self, items):
        # Drop queued background work outside the newest three-word window.
        with self.condition:
            wanted = {key for key, _ in items}
            for key, job in list(self.jobs.items()):
                if not job['started'] and not job['urgent'] and key not in wanted:
                    job['future'].cancel()
                    del self.jobs[key]
            self.background = deque(job for job in self.background if not job['future'].cancelled())
            for key, payload in items:
                self._submit(key, payload, False)

    def cancel_pending(self):
        with self.condition:
            for key, job in list(self.jobs.items()):
                if not job['started']:
                    job['future'].cancel()
                    del self.jobs[key]
            self.foreground.clear()
            self.background.clear()

    def idle_seconds(self):
        with self.condition:
            return 0.0 if self.jobs else max(0.0, time.monotonic() - self.last_activity)

    def _run(self):
        while True:
            with self.condition:
                while not self.foreground and not self.background:
                    self.condition.wait()
                job = (self.foreground if self.foreground else self.background).popleft()
                if job['started'] or job['future'].cancelled():
                    continue
                job['started'] = True
            try:
                result = self.generate(*job['payload'])
            except Exception as error:
                job['future'].set_exception(error)
            else:
                job['future'].set_result(result)
            finally:
                with self.condition:
                    if self.jobs.get(job['key']) is job:
                        del self.jobs[job['key']]
                    self.last_activity = time.monotonic()
