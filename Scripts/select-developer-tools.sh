#!/bin/bash
# Select a compiler AND SDK that can actually type-check SwiftUI, in this process only.
luma_probe_swiftui() {
  local xcrun_path="$1" sdk_path="$2"
  local probe_dir
  probe_dir="$(mktemp -d)" || return 1
  cat > "$probe_dir/SwiftUIProbe.swift" <<'SWIFT'
import SwiftUI
import Observation
// Swift Testing is verified by SwiftPM test, with its proper framework search paths.
@Observable final class LumaProbeModel { var count = 0 }
@MainActor struct LumaSwiftUIProbe: View {
    @State private var count = 0
    @Environment(\.colorScheme) private var appearance
    var body: some View { Button("Check") { count += 1 } }
}
SWIFT
  if "$xcrun_path" swiftc -typecheck -sdk "$sdk_path" "$probe_dir/SwiftUIProbe.swift" > "$probe_dir/diagnostic.log" 2>&1; then
    rm -rf "$probe_dir"
    return 0
  fi
  if [[ -n "${LUMA_TOOLCHAIN_LOG:-}" ]]; then
    printf '\nSwiftUI probe failed: %s\n' "$sdk_path" >> "$LUMA_TOOLCHAIN_LOG"
    cat "$probe_dir/diagnostic.log" >> "$LUMA_TOOLCHAIN_LOG"
  fi
  rm -rf "$probe_dir"
  return 1
}

# SwiftUI existing in an SDK does not establish the deployment API floor.
luma_sdk_supported() {
  local version major
  version="$("$1" --sdk "$2" --show-sdk-version 2>/dev/null)" || return 1
  major="${version%%.*}"
  case "$major" in ''|*[!0-9]*) return 1 ;; esac
  if [[ "$major" -lt 26 ]]; then LUMA_TOOLS_STATUS=sdk-too-old; return 1; fi
}

luma_developer_tools_work() {
  local xcrun_path="$1" sdk_path
  "$xcrun_path" --find swift >/dev/null 2>&1 || return 1
  sdk_path="$("$xcrun_path" --sdk macosx --show-sdk-path 2>/dev/null)" || return 1
  [[ -d "$sdk_path" ]] || return 1
  luma_sdk_supported "$xcrun_path" "$sdk_path" || return 1
  if luma_probe_swiftui "$xcrun_path" "$sdk_path"; then
    export SDKROOT="$sdk_path"
    return 0
  fi
  LUMA_TOOLS_STATUS=swiftui-unavailable
  return 1
}

luma_try_sdk26() {
  local xcrun_path="$1" developer_root="$2" sdk_path
  [[ -d "$developer_root" ]] || return 1
  export DEVELOPER_DIR="$developer_root"
  "$xcrun_path" --find swift >/dev/null 2>&1 || return 1
  for sdk_path in "$developer_root"/SDKs/MacOSX26*.sdk "$developer_root"/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26*.sdk; do
    [[ -d "$sdk_path" ]] || continue
    luma_sdk_supported "$xcrun_path" "$sdk_path" || continue
    if luma_probe_swiftui "$xcrun_path" "$sdk_path"; then
      export SDKROOT="$sdk_path"
      return 0
    fi
  done
  return 1
}

luma_select_developer_tools() {
  local xcrun_path="${1:-/usr/bin/xcrun}"
  local applications_root="${2:-/Applications}"
  local clt_root="${3:-/Library/Developer/CommandLineTools}"
  local candidate previous_override="${DEVELOPER_DIR:-}"
  LUMA_TOOLS_STATUS=missing
  if luma_developer_tools_work "$xcrun_path"; then return 0; fi
  unset DEVELOPER_DIR SDKROOT
  if luma_developer_tools_work "$xcrun_path"; then return 0; fi
  # Full Xcode can supply the SwiftUI macro plugins absent from newer CLT releases.
  for candidate in "$applications_root"/Xcode.app/Contents/Developer "$applications_root"/Xcode_*.app/Contents/Developer "$clt_root"; do
    [[ -d "$candidate" ]] || continue
    export DEVELOPER_DIR="$candidate"
    if luma_developer_tools_work "$xcrun_path"; then return 0; fi
  done
  # A pre-macro SDK already installed locally may work with this compiler.
  # Every fallback is type-checked; merely finding an SDK directory is insufficient.
  for candidate in "$previous_override" "$applications_root"/Xcode.app/Contents/Developer "$applications_root"/Xcode_*.app/Contents/Developer "$clt_root"; do
    if luma_try_sdk26 "$xcrun_path" "$candidate"; then return 0; fi
  done
  unset DEVELOPER_DIR SDKROOT
  return 1
}
