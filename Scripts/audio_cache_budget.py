"""Budget only regenerable, hash-named WAVs in explicitly supplied cache folders."""
import os
from pathlib import Path
import re
import time

_HASH_WAV = re.compile(r'^[0-9a-f]{32}\.wav$')

class AudioCacheBudget:
    def __init__(self, directories, max_bytes=256*1024*1024, max_age=30*86400, grace=300):
        self.directories = tuple(Path(p) for p in directories)
        self.max_bytes = max_bytes
        self.max_age = max_age
        self.grace = grace

    @staticmethod
    def touch(path, now=None):
        now = time.time() if now is None else now
        try:
            # Throttle metadata writes for rapid repeated playback.
            if now - Path(path).stat().st_mtime > 3600:
                os.utime(path, (now, now), follow_symlinks=False)
        except OSError:
            pass

    def prune(self, now=None):
        now = time.time() if now is None else now
        records = []
        for directory in self.directories:
            if directory.is_symlink():
                continue
            try:
                with os.scandir(directory) as entries:
                    for entry in entries:
                        if not _HASH_WAV.fullmatch(entry.name) or not entry.is_file(follow_symlinks=False):
                            continue
                        stat = entry.stat(follow_symlinks=False)
                        records.append((stat.st_mtime, stat.st_size, Path(entry.path)))
            except OSError:
                continue
        total = sum(size for _, size, _ in records)
        removed = 0
        for modified, size, path in sorted(records):
            if now - modified < self.grace:
                continue
            if total <= self.max_bytes and now - modified <= self.max_age:
                continue
            try:
                if path.is_symlink() or path.stat().st_mtime != modified:
                    continue
                path.unlink()
                total -= size; removed += 1
            except OSError:
                pass
        return dict(remaining_bytes=total, removed_files=removed)
