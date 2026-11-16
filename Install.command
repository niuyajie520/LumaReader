#!/bin/bash
# Builds locally with Apple's tools and installs the updated UI & Speech engine cleanly.
set -euo pipefail
cd "$(dirname "$0")"
# Version/build come from release.json only (single source of truth).
RELEASE_JSON="$PWD/release.json"
APP_VERSION="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$RELEASE_JSON")"
APP_BUILD="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["build"])' "$RELEASE_JSON")"
finish() {
  local code=$?
  if [[ "$code" -ne 0 ]]; then
    echo
    echo "❌ 没有完成安装。现有书籍、词库和学习记录未被删除。"
    echo "请把本目录 Logs 中最新的日志发给我继续处理。"
    [[ -d "$PWD/Logs" ]] && open "$PWD/Logs" || true
  fi
  if [[ -t 0 ]]; then
    echo
    read -r -p "按回车关闭此窗口。" _response || true
  fi
}
trap finish EXIT
if [[ "$(uname -s)" != Darwin ]]; then
  echo "此文件只能在 Mac 上双击运行。"
  exit 1
fi

# Strip quarantine attributes and clean any leftover backup files so SwiftPM builds with 0 warnings
/usr/bin/xattr -cr "$PWD" 2>/dev/null || true
find "$PWD/Sources" "$PWD/Deferred" -name "*.before-*" -delete 2>/dev/null || true
find "$PWD/Sources" "$PWD/Deferred" -name "* 2.swift" -delete 2>/dev/null || true

mkdir -p Logs
BUILD_LOG="$PWD/Logs/build-$(date +%Y%m%d-%H%M%S).log"
echo "=========================================================="
echo "🚀 Luma Reader V${APP_VERSION} · build ${APP_BUILD} · 正在编译（易混词 + 悬浮小窗练习 + 背词独立词库 + 15 套独立主题+主题专属布局+废土终端+特色错误反馈+三级分类+错词中心+红线保护）（暗莓听写UI + 阅读顶栏水平中心对齐 + 目录主题色 + Apple语音修复）"
echo "=========================================================="
export LUMA_TOOLCHAIN_LOG="$BUILD_LOG"
source "$PWD/Scripts/select-developer-tools.sh"
if ! luma_select_developer_tools; then
  if [[ "$LUMA_TOOLS_STATUS" == swiftui-unavailable ]]; then
    echo "已找到 Swift，但现有工具无法编译 SwiftUI。请打开完整 Xcode 完成初始化后再双击本文件。"
    open "macappstore://itunes.apple.com/app/id497799835" || true
  else
    echo "尚未找到可用的 Apple Swift/macOS SDK。"
    /usr/bin/xcode-select --install >> "$BUILD_LOG" 2>&1 || true
  fi
  exit 1
fi

echo "🔨 正在编译正式版 Luma Reader.app（约需 30–90 秒，请稍候）……"
rm -rf "$PWD/dist/Luma Reader.app"
if ! LUMA_NO_OPEN=1 bash Scripts/build-macos.sh >> "$BUILD_LOG" 2>&1; then
  echo "应用构建没有通过，具体错误已记录在 $BUILD_LOG"
  tail -n 30 "$BUILD_LOG" || true
  exit 1
fi

# Clear stale cached EPUB HTML files so updated Reader.css/Reader.js take effect immediately
find "$HOME/Library/Application Support/LumaReader" -name ".luma-*.html" -delete 2>/dev/null || true

# Quit any running Luma Reader instance cleanly
/usr/bin/osascript -e 'if application id "app.luma.personal-reader" is running then tell application id "app.luma.personal-reader" to quit' >> "$BUILD_LOG" 2>&1 || true
pkill -f "Luma Reader.app/Contents/MacOS/LumaReader" >/dev/null 2>&1 || true
killall "Luma Reader" >/dev/null 2>&1 || true
killall "LumaReader" >/dev/null 2>&1 || true
pkill -f kokoro_neural_daemon.py >/dev/null 2>&1 || true
/bin/sleep 1

# Remove old backup .app bundles that hijack macOS Dock / LaunchServices inode references!
rm -rf /Applications/LumaReader-before-* 2>/dev/null || true
rm -rf "$HOME/Applications/Luma Reader-backup-"*.app 2>/dev/null || true
rm -rf "$HOME/Applications/.LumaReader-install-"*.app 2>/dev/null || true

mkdir -p "$HOME/Applications"
USER_DEST="$HOME/Applications/Luma Reader.app"
rm -rf "$USER_DEST"
# ~/Applications may be managed by a file provider that re-attaches FinderInfo;
# copy without resource forks and treat a failed verification there as non-fatal.
/usr/bin/ditto --norsrc --noextattr "$PWD/dist/Luma Reader.app" "$USER_DEST"
PRIMARY_DEST=""
if /usr/bin/codesign --verify --deep --strict "$USER_DEST" >> "$BUILD_LOG" 2>&1; then
  PRIMARY_DEST="$USER_DEST"
else
  echo "⚠️ ~/Applications 副本签名校验未通过（文件提供器附加属性），已删除该副本，继续安装到 /Applications。"
  rm -rf "$USER_DEST"
fi

if [[ -w "/Applications" ]]; then
  SYS_DEST="/Applications/Luma Reader.app"
  rm -rf "$SYS_DEST"
  /usr/bin/ditto --norsrc --noextattr "$PWD/dist/Luma Reader.app" "$SYS_DEST"
  if ! /usr/bin/codesign --verify --deep --strict "$SYS_DEST" >> "$BUILD_LOG" 2>&1; then
    echo "❌ /Applications 副本签名校验失败，请查看日志：$BUILD_LOG"
    exit 1
  fi
  PRIMARY_DEST="$SYS_DEST"
fi
if [[ -z "$PRIMARY_DEST" ]]; then
  echo "❌ 两份安装副本均未通过签名校验，请查看日志：$BUILD_LOG"
  exit 1
fi

# Also update ~/LumaReader_CompileFix.B69ok3/source/dist/Luma Reader.app if present so Dock icons pointing there also open the new build
for old_repo in "$HOME/LumaReader_CompileFix.B69ok3/source" $(ls -dt "$HOME"/LumaReader_CompileFix.*/source 2>/dev/null || true); do
  if [[ -d "$old_repo/dist" && "$old_repo" != "$PWD" ]]; then
    rm -rf "$old_repo/dist/Luma Reader.app"
    /usr/bin/ditto "$PWD/dist/Luma Reader.app" "$old_repo/dist/Luma Reader.app" 2>/dev/null || true
  fi
done

# Register the primary app with LaunchServices so Spotlight & Dock open the new version
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$PRIMARY_DEST" >/dev/null 2>&1 || true
fi

# Keep the original Kitten synthesis runtime. Model weights are in the signed app.
/usr/bin/python3 "$PWD/Scripts/remove-legacy-kokoro.py"
VOICE_SUPPORT="$HOME/Library/Application Support/LumaReader"
VOICE_RUNTIME="$VOICE_SUPPORT/KokoroEngine"
if [[ ! -x "$VOICE_RUNTIME/venv/bin/python3" && -x "$VOICE_SUPPORT/KokoroTTS/venv/bin/python3" ]]; then
    VOICE_RUNTIME="$VOICE_SUPPORT/KokoroTTS"
fi
VOICE_SETUP_LOG="$PWD/neural-voice-install.log"
if ! /bin/bash "$PWD/Scripts/install-neural-voices.sh" "$VOICE_RUNTIME" "$PRIMARY_DEST/Contents/Resources/KittenSpeech" >"$VOICE_SETUP_LOG" 2>&1; then
    echo "Kitten 运行环境配置未完成。可在发音设置中重试。日志：$VOICE_SETUP_LOG"
    tail -n 12 "$VOICE_SETUP_LOG"
fi

# Also create a ready-to-upload GitHub Release zip on Desktop
DESKTOP_REL_DIR="$HOME/Desktop/LumaReader_GitHub_Release_v${APP_VERSION}"
mkdir -p "$DESKTOP_REL_DIR"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PRIMARY_DEST" "$DESKTOP_REL_DIR/LumaReader-v${APP_VERSION}-macOS-arm64.zip" 2>/dev/null || true
(cd "$DESKTOP_REL_DIR" && shasum -a 256 "LumaReader-v${APP_VERSION}-macOS-arm64.zip" > SHA256SUMS.txt 2>/dev/null || true)

echo "✅ 构建与安装全部完成！已更新至：$PRIMARY_DEST"
echo "✅ 同时已在桌面生成 GitHub Release 安装包：$DESKTOP_REL_DIR/LumaReader-v${APP_VERSION}-macOS-arm64.zip"
open "$PRIMARY_DEST"
