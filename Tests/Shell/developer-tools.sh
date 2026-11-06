#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$project_root/Scripts/select-developer-tools.sh"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/sdk" "$fixture/apps/Xcode.app/Contents/Developer" "$fixture/broken-clt"
cat > "$fixture/xcrun" <<'MOCK'
#!/bin/bash
if [[ "${MOCK_ACCEPT_ALL:-0}" != 1 && "${DEVELOPER_DIR:-system}" != "$MOCK_WORKING_DIR" ]]; then exit 1; fi
if [[ "$*" == '--find swift' ]]; then echo /mock/swift; exit 0; fi
if [[ "$*" == '--sdk macosx --show-sdk-path' ]]; then echo "$MOCK_SDK"; exit 0; fi
if [[ "$*" == *'--show-sdk-version' ]]; then echo "${MOCK_SDK_VERSION:-26.0}"; exit 0; fi
if [[ "$1" == swiftc ]]; then
  if [[ "${MOCK_FORCE_MACRO_FAILURE:-0}" == 1 ]]; then echo 'SwiftUIMacros missing' >&2; exit 1; fi
  if [[ -n "${MOCK_ONLY_SWIFTUI_DIR:-}" && "${DEVELOPER_DIR:-system}" != "$MOCK_ONLY_SWIFTUI_DIR" ]]; then exit 1; fi
  if [[ -n "${MOCK_ONLY_SWIFTUI_SDK:-}" && "$4" != "$MOCK_ONLY_SWIFTUI_SDK" ]]; then exit 1; fi
  exit 0
fi
exit 1
MOCK
chmod +x "$fixture/xcrun"
export MOCK_SDK="$fixture/sdk"
(export MOCK_WORKING_DIR=valid DEVELOPER_DIR=valid; luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; [[ "$DEVELOPER_DIR" == valid && "$SDKROOT" == "$MOCK_SDK" ]])
(export MOCK_WORKING_DIR=system DEVELOPER_DIR=stale; luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; [[ -z "${DEVELOPER_DIR:-}" ]])
(export MOCK_WORKING_DIR="$fixture/apps/Xcode.app/Contents/Developer" DEVELOPER_DIR=stale; luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; [[ "$DEVELOPER_DIR" == "$MOCK_WORKING_DIR" ]])
(export MOCK_WORKING_DIR=none DEVELOPER_DIR=stale; if luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; then exit 1; fi; [[ -z "${DEVELOPER_DIR:-}" ]])
(export MOCK_WORKING_DIR=system MOCK_SDK="$fixture/missing-sdk"; unset DEVELOPER_DIR; if luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; then exit 1; fi)
# Detect SDK27's missing SwiftUI macros instead of accepting --version as success.
(export MOCK_WORKING_DIR=system MOCK_FORCE_MACRO_FAILURE=1; unset DEVELOPER_DIR; if luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; then exit 1; fi; [[ "$LUMA_TOOLS_STATUS" == swiftui-unavailable ]])
# A full Xcode candidate passes where CLT's Swift executable does not.
(export MOCK_WORKING_DIR=system MOCK_ACCEPT_ALL=1 MOCK_ONLY_SWIFTUI_DIR="$fixture/apps/Xcode.app/Contents/Developer"; unset DEVELOPER_DIR; luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; [[ "$DEVELOPER_DIR" == "$MOCK_ONLY_SWIFTUI_DIR" ]])
# Use a locally present SDK26 only after its own SwiftUI probe succeeds.
mkdir -p "$fixture/broken-clt/SDKs/MacOSX26.2.sdk"
(export MOCK_WORKING_DIR=system MOCK_ACCEPT_ALL=1 MOCK_ONLY_SWIFTUI_SDK="$fixture/broken-clt/SDKs/MacOSX26.2.sdk"; unset DEVELOPER_DIR; luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; [[ "$SDKROOT" == "$MOCK_ONLY_SWIFTUI_SDK" ]])
# Probe failure diagnostics are retained for the user rather than silently discarded.
(export MOCK_WORKING_DIR=system MOCK_FORCE_MACRO_FAILURE=1 LUMA_TOOLCHAIN_LOG="$fixture/probe.log"; unset DEVELOPER_DIR; if luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; then exit 1; fi; grep -q 'SwiftUIMacros missing' "$fixture/probe.log")
# A successful SwiftUI probe must not admit an SDK below macOS 26.
(export MOCK_WORKING_DIR=system MOCK_ACCEPT_ALL=1 MOCK_SDK_VERSION=15.5; unset DEVELOPER_DIR; if luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; then exit 1; fi)
(export MOCK_WORKING_DIR=system MOCK_SDK_VERSION=unknown; unset DEVELOPER_DIR; if luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt"; then exit 1; fi)
(export MOCK_WORKING_DIR=system MOCK_SDK_VERSION=27.2; unset DEVELOPER_DIR; luma_select_developer_tools "$fixture/xcrun" "$fixture/apps" "$fixture/broken-clt")
echo 'Developer tools selection: 12 checks PASS' 
