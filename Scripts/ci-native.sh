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
phase tests /usr/bin/xcrun swift test --sdk "$SDKROOT"
phase release env LUMA_NO_OPEN=1 bash Scripts/build-macos.sh
phase signature codesign --verify --deep --strict 'dist/Luma Reader.app'
phase architecture bash -c 'file "dist/Luma Reader.app/Contents/MacOS/LumaReader"; lipo -archs "dist/Luma Reader.app/Contents/MacOS/LumaReader" | grep -qw arm64'
phase package /usr/bin/ditto -c -k --sequesterRsrc --keepParent 'dist/Luma Reader.app' ci-raw/LumaReader-macOS26-arm64.zip
# GUI and target-hardware testing are separate; no fake launch or FPS claims here.
echo 'Native build phases completed; GUI, fault injection and M4 performance require a Mac graphical session.'
