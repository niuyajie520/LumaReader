#!/bin/bash
# Raw compiler output stays unshared. Console emits only fixed phase names/status.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-raw ci-safe
phase() {
  local name="$1"; shift
  echo "Starting $name"
  if "$@" > "ci-raw/$name.log" 2>&1; then echo "$name: PASS"; else
    local status=$?
    echo "$name: FAIL (sanitized log will be prepared)"
    return "$status"
  fi
}
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'Required macOS ARM64 runner unavailable';exit 1; }
[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ]] || { echo 'Required macOS 26+ runner unavailable';exit 1; }
phase environment bash -c 'sw_vers; uname -m; xcodebuild -version; xcrun swift --version'
source Scripts/select-developer-tools.sh
export LUMA_TOOLCHAIN_LOG="$PWD/ci-raw/toolchain-probe.log"
# The hosted image already has full Xcode selected. Preserve its actual failure,
# rather than retrying every installed toolchain before a useful diagnostic exists.
if ! luma_developer_tools_work /usr/bin/xcrun >ci-raw/toolchain.log 2>&1; then echo 'Toolchain/SDK probe: FAIL';exit 1; fi
phase resolve /usr/bin/xcrun swift package resolve
phase debug /usr/bin/xcrun swift build --sdk "$SDKROOT" -c debug
phase tests env LUMA_SYNTHETIC_UI_EVIDENCE="$PWD/ci-ui" /usr/bin/xcrun swift test --sdk "$SDKROOT"
phase test-completion python3 Scripts/check-native-test-completion.py ci-raw/tests.log ci-ui
phase release env LUMA_NO_OPEN=1 LUMA_CI_AUDIT=1 bash Scripts/build-macos.sh
phase signature codesign --verify --deep --strict 'dist/Luma Reader.app'
phase architecture bash -c 'file "dist/Luma Reader.app/Contents/MacOS/LumaReader"; lipo -archs "dist/Luma Reader.app/Contents/MacOS/LumaReader" | grep -qw arm64'
# LaunchServices is attempted only in an existing graphical user session.
# A live launched process does not prove a visible window or correct UI behavior.
if /bin/launchctl print "gui/$(id -u)" >/dev/null 2>&1; then
  phase launch /usr/bin/xcrun swift -sdk "$SDKROOT" Scripts/launch-smoke.swift "$PWD/dist/Luma Reader.app"
  phase window-ui python3 Scripts/window-ui-smoke.py "$PWD/dist/Luma Reader.app"
else
  printf '%s\n' '{"status":"BLOCKED","reason":"No graphical user session","mainWindowVerified":false}' >ci-raw/launch.log
  echo 'Application launch: BLOCKED (no graphical session)'
  exit 1
fi
echo 'Native build phases completed; UI, fault injection and M4 performance require separate evidence.'
