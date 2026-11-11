#!/usr/bin/env python3
"""Report counts only. This diagnostic never approves or suppresses a finding."""
import importlib.util
import json
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location('privacy_gate', Path(__file__).with_name('privacy-gate.py'))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
data = Path(sys.argv[1]).read_bytes()
root = str(Path.cwd().resolve()).encode() + b'/'
matches = list(gate.rules['private-path'].finditer(data))
workspace = sum(m.group().startswith(root) for m in matches)
print(json.dumps({'privatePathMatches': len(matches), 'currentBuildWorkspaceMatches': workspace,
                  'otherMatches': len(matches) - workspace, 'matchedValuesExported': False}))
