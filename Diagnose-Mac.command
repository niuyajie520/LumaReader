#!/bin/bash
# Read-only evidence collection. Does not kill processes, change login items or reset settings.
set -eu
OUT="$HOME/Downloads/LumaReader-Diagnostic-$(date +%Y%m%d-%H%M%S).txt"
/usr/bin/python3 - "$OUT" <<'PY'
import datetime, os, pathlib, plistlib, subprocess, sys
out=pathlib.Path(sys.argv[1])
lines=['LumaReader local runtime diagnostic', str(datetime.datetime.now())]
processes=subprocess.check_output(['/bin/ps','-axo','pid,ppid,etime,pcpu,rss,command'],text=True)
lines += ['\nRelevant processes (PID, parent PID, age, CPU, RSS):']
lines += [line for line in processes.splitlines() if any(x in line.lower() for x in ('lumareader','luma reader','kokoro_neural_daemon'))]
lines += ['\nRelevant launchd configuration:']
for root in (pathlib.Path.home()/'Library/LaunchAgents', pathlib.Path('/Library/LaunchAgents'), pathlib.Path('/Library/LaunchDaemons')):
    for path in root.glob('*.plist'):
        try: data=plistlib.loads(path.read_bytes())
        except Exception: continue
        relevant=str(data.get('Label',''))+' '+str(data.get('Program',''))+' '+str(data.get('ProgramArguments',[]))
        if any(term in relevant.lower() for term in ('luma','kokoro')):
            lines += [str(path), str({key:data[key] for key in ('Label','Program','ProgramArguments','KeepAlive','RunAtLoad') if key in data})]
lines += ['\nLogin/background-item matches:']
try:
    result=subprocess.run(['/usr/bin/sfltool','dumpbtm'],text=True,capture_output=True,timeout=15)
    lines += [line for line in result.stdout.splitlines() if any(term in line.lower() for term in ('luma','kokoro'))]
except Exception as error: lines += [str(error)]
out.write_text('\n'.join(lines)+'\n')
print(out)
PY
# Window titles are intentionally omitted; only owner, PID, bounds and level are recorded.
if /usr/bin/xcrun --find swift >/dev/null 2>&1; then
  TEMP_SWIFT="$(mktemp -t luma-windows).swift"
  trap 'rm -f "$TEMP_SWIFT"' EXIT
  cat > "$TEMP_SWIFT" <<'SWIFT'
import AppKit
import CoreGraphics
print("\nLumaReader visible window layers (no titles):")
if let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
    for window in list {
        let owner = window[kCGWindowOwnerName as String] as? String ?? ""
        guard owner.localizedCaseInsensitiveContains("Luma") else { continue }
        let keys = [kCGWindowOwnerName, kCGWindowOwnerPID, kCGWindowLayer, kCGWindowBounds, kCGWindowAlpha]
        for key in keys { print("\(key): \(window[key as String] ?? "unavailable")") }
    }
}
SWIFT
  /usr/bin/xcrun swift "$TEMP_SWIFT" >> "$OUT" 2>&1 || true
fi
printf '\n诊断已保存到：%s\n' "$OUT"
open -R "$OUT"
