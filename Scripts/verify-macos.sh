#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "需要在 Mac 上运行，才能检查 SwiftUI / AppKit / PDFKit / WebKit。" >&2
  exit 1
fi
source "$PWD/Scripts/select-developer-tools.sh"
luma_select_developer_tools
/usr/bin/xcrun swift --version
/usr/bin/xcrun --sdk "$SDKROOT" --show-sdk-version
/usr/bin/xcrun swift package resolve
/usr/bin/xcrun swift build --sdk "$SDKROOT" -c debug
/usr/bin/xcrun swift test --sdk "$SDKROOT"
LUMA_NO_OPEN=1 bash Scripts/build-macos.sh
