#!/usr/bin/env python3
"""Verify an ACTUAL generated .app before installation; never a launch/UI test."""
import sys,plistlib,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1];app=Path(sys.argv[1])
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['LSMinimumSystemVersion']=='26.0'
assert info['CFBundleShortVersionString']=='0.9.17'
exe=app/'Contents/MacOS'/info['CFBundleExecutable']; assert exe.is_file() and exe.stat().st_size>0
for name in ['Reader.js','Reader.css','AIChat.html','AIChat.css','AIChat.js','AIHealth.js','AppStrings.js','AppStrings.json']:
    source=root/'Sources/LumaReader/Resources'/name; installed=app/'Contents/Resources'/name
    assert installed.is_file(), 'Missing installed asset '+name
    assert hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256(installed.read_bytes()).digest(), 'Stale installed asset '+name
assert (app/'Contents/Resources/LumaReader_LumaReader.bundle').is_dir(), 'SwiftPM resource bundle missing'
print('Generated app bundle metadata/assets: PASS (does not prove GUI startup)')
