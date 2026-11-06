#!/bin/bash
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p Diagnostics
luma_check_log="$PWD/Diagnostics/verify-$(date +%Y%m%d-%H%M%S).log"
{
  echo "Luma Reader 0.9.17 · Mac 原生验证"
  /usr/bin/sw_vers
  /usr/bin/xcode-select -p
  /usr/bin/xcodebuild -version
  bash Scripts/verify-macos.sh
} 2>&1 | tee "$luma_check_log"
luma_check_status=${PIPESTATUS[0]}
echo ""
echo "验证日志：$luma_check_log"
if [[ "$luma_check_status" -eq 0 ]]; then
  echo "原生测试与编译通过。"
else
  echo "验证未通过，请查看日志中的首个错误。"
fi
read -r -p "按回车键关闭…"
exit "$luma_check_status"
