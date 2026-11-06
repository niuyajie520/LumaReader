#!/usr/bin/env python3
"""Package only the checked-out, tested commit. All output remains gated."""
import hashlib
import json
import os
import plistlib
import re
import subprocess
import tarfile
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

root = Path.cwd()
app = root / 'dist/Luma Reader.app'
version = plistlib.loads((app / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'Unexpected existing version'
sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
assert re.fullmatch(r'[0-9a-f]{40}', sha)
run('git', 'diff', '--exit-code', 'HEAD', '--')
assert json.loads(Path('ci-raw/launch.log').read_text())['status'] == 'PASS'
run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
out = root / 'release-assets'
out.mkdir(exist_ok=False)
prefix = f'LumaReader-{version}/'
tracked = set(subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', 'HEAD'], text=True).splitlines())
for required in ['Package.swift', 'Package.resolved', 'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
                 'Sources/LumaReader/LumaReaderApp.swift', 'Scripts/build-macos.sh',
                 'Tests/LumaReaderTests/DiagnosticTests.swift', 'Vendor/MaterialColorUtilities/Package.swift',
                 'Sources/LumaReader/Resources/Reader.js', '.github/workflows/macos26-blockers.yml']:
    assert required in tracked, 'Missing required source component'
assert not any(set(PurePosixPath(p).parts) & {'.git', '.build', 'ci-raw', 'ci-safe', 'release-assets'} for p in tracked)
for fmt, suffix in [('zip', 'zip'), ('tar.gz', 'tar.gz')]:
    archive = out / f'LumaReader-{version}-source.{suffix}'
    run('git', 'archive', f'--format={fmt}', f'--prefix={prefix}', f'--output={archive}', 'HEAD')
    if fmt == 'zip':
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            assert {n[len(prefix):] for n in z.namelist() if not n.endswith('/')} == tracked
            with tempfile.TemporaryDirectory() as temporary:
                # git archive comes from the verified commit; reject unexpected traversal/link entries.
                assert all(n.startswith(prefix) and '..' not in PurePosixPath(n).parts for n in z.namelist())
                assert not any((i.external_attr >> 16) & 0o170000 == 0o120000 for i in z.infolist())
                z.extractall(temporary)
                run('python3', 'Scripts/privacy-gate.py', temporary)
    else:
        with tarfile.open(archive) as t:
            files = [m for m in t.getmembers() if m.isfile()]
            assert {m.name[len(prefix):] for m in files} == tracked
            assert all(m.name.startswith(prefix) and '..' not in PurePosixPath(m.name).parts and
                       (m.isfile() or m.isdir()) for m in t.getmembers())
app_zip = out / f'LumaReader-{version}-macOS26-arm64.zip'
run('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(app_zip))
with zipfile.ZipFile(app_zip) as z:
    assert z.testzip() is None
    assert all((n.startswith('Luma Reader.app/') or n.startswith('__MACOSX/')) and
               '..' not in PurePosixPath(n).parts for n in z.namelist())
provenance = {'version': version, 'sourceCommit': sha, 'runID': os.environ['GITHUB_RUN_ID'],
              'repository': os.environ['GITHUB_REPOSITORY'], 'architecture': 'arm64',
              'minimumMacOS': '26.0', 'signature': 'ad-hoc', 'appleNotarized': False,
              'nativeGUI': 'NOT RUN', 'M4AirPerformance': 'NOT RUN'}
(out / 'build-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
notes = (f'# LumaReader {version}\n\nVerified source commit: `{sha}`.\n\n'
         f'CI: https://github.com/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{os.environ["GITHUB_RUN_ID"]}\n\n'
         'Requires macOS 26+ on Apple Silicon. Includes the application ZIP and complete source ZIP/TAR.GZ.\n\n'
         'Debug, Swift tests, Release, signature, ARM64 and real process launch were checked. '
         'The application is ad-hoc signed, not Apple-notarized. '
         'GUI interaction, WebKit fault injection, Instruments and M4 Air performance: NOT RUN.\n\n'
         'Release packaging removes debug symbols before signing; privacy and secret scans remain enabled.\n')
(out / 'RELEASE_NOTES.md').write_text(notes)
run('gitleaks', 'dir', str(out), '--max-archive-depth', '2', '--redact', '--no-banner',
    '--report-format', 'json', '--report-path', 'ci-raw/release-archives-gitleaks.json')
run('python3', 'Scripts/privacy-gate.py', str(out))
(out / 'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in sorted(out.iterdir()) if p.is_file()))
with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
    f.write(f'source_sha={sha}\nversion={version}\ntag=v{version}\n')
print('Release archives, source inventories and SHA-256 manifest: PASS')
