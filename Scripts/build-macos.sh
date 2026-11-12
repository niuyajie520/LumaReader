#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "请在 Mac 上运行此脚本；需要 Apple Swift 6 或更新版本的工具链。" >&2
  exit 1
fi
source "$PWD/Scripts/select-developer-tools.sh"
luma_select_developer_tools || { echo "没有找到可用的 Apple Swift/macOS SDK。" >&2; exit 1; }
if command -v python3 >/dev/null; then python3 Scripts/check-ui-resources.py; fi
# Single source of truth for version/build metadata (release.json).
RELEASE_JSON="$PWD/release.json"
LUMA_APP_VERSION="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$RELEASE_JSON")"
LUMA_APP_BUILD="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["build"])' "$RELEASE_JSON")"
# Remap only this checkout's compiler-generated source paths. Literal user data
# and all other private paths remain subject to the unchanged privacy gate.
/usr/bin/xcrun swift build --sdk "$SDKROOT" -c release \
  -Xswiftc -file-prefix-map -Xswiftc "$PWD=/LumaReaderBuild" \
  -Xcc "-ffile-prefix-map=$PWD=/LumaReaderBuild"
BIN_DIR="$(/usr/bin/xcrun swift build --sdk "$SDKROOT" -c release --show-bin-path)"
# Assemble a fresh bundle: cp -R into an existing bundle can leave removed assets behind.
mkdir -p "$PWD/dist"
# Stage outside iCloud/OneDrive/File-Provider folders: those re-attach
# com.apple.FinderInfo to .app directories, which makes codesign fail with
# "resource fork, Finder information, or similar detritus not allowed".
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/luma-build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP_PATH="$STAGING/Luma Reader.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_DIR/LumaReader" "$APP_PATH/Contents/MacOS/LumaReader"
# Keep SPM resources and copy reader files into the application resource directory.
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP_PATH/Contents/Resources/" \;
if [[ -d "Deferred/StudyCenter/Resources/CoraVocabulary" ]]; then
  cp -R "Deferred/StudyCenter/Resources/CoraVocabulary" "$APP_PATH/Contents/Resources/"
fi
cp Sources/LumaReader/Resources/Reader.js Sources/LumaReader/Resources/Reader.css Sources/LumaReader/Resources/AIChat.{html,css,js} Sources/LumaReader/Resources/AIHealth.js Sources/LumaReader/Resources/AppStrings.{js,json} "$APP_PATH/Contents/Resources/"
cp Sources/LumaReader/Resources/{StPageFlip,PaperFlip}.js "$APP_PATH/Contents/Resources/"
cp -R Assets/KittenSpeech "$APP_PATH/Contents/Resources/"
cp Scripts/kokoro_neural_daemon.py Scripts/exclusive_tts.py Scripts/audio_priority_queue.py Scripts/audio_cache_budget.py Scripts/bounded_onnx.py Scripts/install-neural-voices.sh Scripts/setup_kitten.py "$APP_PATH/Contents/Resources/"
bash Scripts/build-icon.sh "$APP_PATH/Contents/Resources"
# SwiftPM release executables may still contain DWARF build paths. Strip debug
# symbols before signing; never patch strings or relax the privacy gate.
if [[ "${LUMA_CI_AUDIT:-0}" == 1 ]]; then
  python3 Scripts/binary-path-audit.py "$APP_PATH/Contents/MacOS/LumaReader" >ci-raw/binary-path-before-strip.log
fi
/usr/bin/xcrun strip -S "$APP_PATH/Contents/MacOS/LumaReader"
if [[ "${LUMA_CI_AUDIT:-0}" == 1 ]]; then
  python3 Scripts/binary-path-audit.py "$APP_PATH/Contents/MacOS/LumaReader" >ci-raw/binary-path-after-strip.log
fi
cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Luma Reader</string>
<key>CFBundleDisplayName</key><string>Luma Reader</string>
<key>CFBundleExecutable</key><string>LumaReader</string>
<key>CFBundleIdentifier</key><string>app.luma.personal-reader</string>
<key>CFBundleIconFile</key><string>LumaReader</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${LUMA_APP_VERSION}</string>
<key>CFBundleVersion</key><string>${LUMA_APP_BUILD}</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Finder/cloud copies may carry extended attributes that make ad-hoc signing fail.
# Only clean the generated bundle; the source folder and user's book library are untouched.
/usr/bin/xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
plutil -lint "$APP_PATH/Contents/Info.plist"
if command -v python3 >/dev/null; then python3 Scripts/check-app-bundle.py "$APP_PATH"; fi
FINAL_APP="$PWD/dist/Luma Reader.app"
# Back up only the previous generated app, never a user library or cloud folder.
if [[ -e "$FINAL_APP" ]]; then mv "$FINAL_APP" "$STAGING/previous.app"; fi
if ! mv "$APP_PATH" "$FINAL_APP"; then
  [[ ! -e "$STAGING/previous.app" ]] || mv "$STAGING/previous.app" "$FINAL_APP"
  exit 1
fi
echo "构建完成：$FINAL_APP"
if [[ "${LUMA_NO_OPEN:-0}" != "1" ]]; then open "$PWD/dist"; fi
