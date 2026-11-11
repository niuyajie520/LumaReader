#!/usr/bin/env python3
"""Static integration/privacy guards. Does not replace native SDK, runtime or security tests."""
import json,re,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];src=root/'Sources/LumaReader';diag=src/'Diagnostics'
package=(root/'Package.swift').read_text();pins=json.loads((root/'Package.resolved').read_text())['pins'];pins={x['identity']:x for x in pins}
assert '.macOS("26.0")' in package
assert '<key>LSMinimumSystemVersion</key><string>26.0</string>' in (root/'Scripts/build-macos.sh').read_text()
for identity,version,revision in [('pulse','5.2.3','94b92731d370c129bb771e9c18f69b0a44ccca5c'),('kscrash','2.6.1','c3882b4db5e810a8ed4148b79cab29a173d4c5c5')]:
 assert pins[identity]['state']=={'revision':revision,'version':version}
assert 'name:"PulseUI"' not in package and 'name:"PulseProxy"' not in package
manager=(diag/'DiagnosticManager.swift').read_text();archive=(diag/'DiagnosticArchive.swift').read_text();c=(root/'Sources/DiagnosticsC/ProcessCounters.c').read_text()
assert 'RemoteLogger.shared.disable()' in manager
assert 'configuration.enableMemoryIntrospection = false' in manager
assert 'NSGetUncaughtExceptionHandler() == nil' in manager
assert 'fields:[DiagnosticField:Double]' in manager
assert 'error:nil,data:nil' in manager and 'https://diagnostics.invalid/luma-ai' in manager
assert 'file:"LumaReader",function:"diagnostic",line:0' in manager
assert 'samples.count > 600' in manager and 'events.count > 500' in manager
assert 'store.export(' not in manager+archive and 'copyItem' not in archive
assert 'proc_pid_rusage(getpid(),' in c
assert not any(x in c for x in ['IOReport','SMC','proc_listpids','task_for_pid','system('])
assert 'line' not in re.search(r'enum DiagnosticField.*?\n\}',(diag/'DiagnosticModels.swift').read_text(),re.S).group(0).lower()
for filename in ['BugReport.md','diagnostics.json','Performance.csv']:assert filename in archive
for file in (root/'ThirdParty/Diagnostics').glob('*LICENSE.txt'):
 text=file.read_text();assert 'Permission is hereby granted' in text and 'Copyright' in text
print('Diagnostic static guards: PASS (pins, macOS 26, bounded buffers, privacy paths, one crash handler, no raw SDK archive)')
