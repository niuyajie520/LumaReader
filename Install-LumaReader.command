#!/bin/bash
# Builds locally with Apple's tools. This is not a precompiled application.
set -euo pipefail
cd "$(dirname "$0")"
finish() {
  local code=$?
  if [[ "$code" -ne 0 ]]; then
    echo
    echo "没有完成安装。现有书籍和批注未被删除。"
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
mkdir -p Logs
BUILD_LOG="$PWD/Logs/build-$(date +%Y%m%d-%H%M%S).log"
echo "Luma Reader · 自动构建安装"
echo "将使用 Apple 的开发工具在此 Mac 上编译，不要求你输入编程命令。"
echo "首次需要网络下载开发工具与开源依赖。不会修改你的书库数据。"
export LUMA_TOOLCHAIN_LOG="$BUILD_LOG"
source "$PWD/Scripts/select-developer-tools.sh"
if ! luma_select_developer_tools; then
  if [[ "$LUMA_TOOLS_STATUS" == swiftui-unavailable ]]; then
    echo "已找到 Swift，但现有工具无法编译 SwiftUI。"
    echo "如果提示缺少 SwiftUIMacros，需要完整 Xcode；重复安装命令行工具不能补齐它。"
    echo "将打开 Apple 的 Xcode 页面。安装并启动 Xcode 完成初始化后，再双击本文件。"
    echo "没有改动系统默认开发工具设置。"
    open "macappstore://itunes.apple.com/app/id497799835" || true
  else
    echo "尚未找到可用的 Apple Swift/macOS SDK。"
    /usr/bin/xcode-select --install >> "$BUILD_LOG" 2>&1 || true
    echo "如果系统出现安装提示，请安装完成后重新双击本文件。"
  fi
  echo "工具检查未通过，尚未开始构建应用。" >> "$BUILD_LOG"
  exit 1
fi
if ! /usr/bin/xcrun swift --version >> "$BUILD_LOG" 2>&1; then
  echo "Apple 工具尚未准备好，请等系统完成安装后再打开。"
  exit 1
fi
{
  echo "Luma Reader package: 0.9.17"
  echo "Developer directory: ${DEVELOPER_DIR:-system default}"
  echo "macOS SDK: $SDKROOT"
} >> "$BUILD_LOG"
echo "正在检查并构建，首次可能需要几分钟……"
if ! /usr/bin/xcrun swift test --sdk "$SDKROOT" >> "$BUILD_LOG" 2>&1; then
  echo "测试/编译没有通过，具体错误已记录。"
  exit 1
fi
if ! LUMA_NO_OPEN=1 bash Scripts/build-macos.sh >> "$BUILD_LOG" 2>&1; then
  echo "应用构建没有通过，具体错误已记录。"
  exit 1
fi
DESTINATION="$HOME/Applications/Luma Reader.app"
mkdir -p "$HOME/Applications"
STAGED_APP="$HOME/Applications/.LumaReader-install-$$.app"
/usr/bin/ditto "$PWD/dist/Luma Reader.app" "$STAGED_APP"
/usr/bin/codesign --verify --deep --strict "$STAGED_APP" >> "$BUILD_LOG" 2>&1
# Preserve an existing installation instead of deleting it.
if [[ -e "$DESTINATION" ]]; then
  BACKUP_PATH="$HOME/Applications/Luma Reader-backup-$(date +%Y%m%d-%H%M%S).app"
  mv "$DESTINATION" "$BACKUP_PATH"
fi
mv "$STAGED_APP" "$DESTINATION"
echo "构建完成，正在打开 Luma Reader。"
open "$DESTINATION"
