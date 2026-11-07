#!/bin/bash
set -euo pipefail
[[ $# == 2 ]] || { echo 'Expected Debug product directory and new probe app path'; exit 1; }
probe_bin="$1"
probe_app="$2"
[[ -x "$probe_bin/LumaReader" && ! -e "$probe_app" ]] || { echo 'Missing Debug product or probe app already exists'; exit 1; }
mkdir -p "$probe_app/Contents/MacOS" "$probe_app/Contents/Resources"
cp "$probe_bin/LumaReader" "$probe_app/Contents/MacOS/LumaReader"
cp -R "$probe_bin/LumaReader_LumaReader.bundle" "$probe_app/Contents/Resources/"
cat > "$probe_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.lumareader.native-acceptance</string>
<key>CFBundleName</key><string>LumaReader Acceptance</string>
<key>CFBundleExecutable</key><string>LumaReader</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$probe_app"
codesign --verify --deep --strict "$probe_app"
echo 'Isolated Debug application bundle prepared'
