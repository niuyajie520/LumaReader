#!/usr/bin/env python3
"""Exercise the actual application window in an existing macOS GUI session."""
import json
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

def probe(inspect=False):
    token = str(uuid.uuid4()).upper()
    report = Path(tempfile.gettempdir()) / ('luma-window-controls-' + token + '.json')
    args = ['/usr/bin/open', '-n', '-a', str(Path(sys.argv[1]).resolve()), '--args', '--luma-window-controls-probe=' + token]
    if inspect:
        args.append('--luma-window-inspect-only')
    subprocess.run(args, check=True, capture_output=True, timeout=20)
    deadline = time.monotonic() + 100
    while time.monotonic() < deadline:
        if report.exists():
            value = json.loads(report.read_text())
            report.unlink()
            return value
        time.sleep(0.25)
    return {'status':'BLOCKED','reason':'No application window probe report in graphical session'}

first = probe()
print(json.dumps({'windowActions': first}))
time.sleep(1)
second = probe(inspect=True)
print(json.dumps({'reopenedWindow': second}))
sys.exit(0 if first.get('status') == second.get('status') == 'PASS' else 1)
