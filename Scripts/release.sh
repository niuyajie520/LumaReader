#!/bin/bash
# 一条命令出包：读 version.json，同步各平台工程，构建，打源码包。
#
#   bash Scripts/release.sh --target macos      # 只出 macOS：编译 + 校验 + 源码 ZIP
#   bash Scripts/release.sh --target ios        # 只出 iPhone：重新生成工程 + 编译 + 源码 ZIP
#   bash Scripts/release.sh --target android    # 只出安卓：跑内核测试 + 编 APK + 源码 ZIP
#   bash Scripts/release.sh --target both       # macOS + iPhone
#   bash Scripts/release.sh --target all        # 三个平台都出
#   bash Scripts/release.sh --target ios --test # 额外跑 iPhone 的 6 个 UI 用例
#   bash Scripts/release.sh --target macos --install  # 额外替换 /Applications（会弹窗启动，默认不做）
#
# 约定：版本号只改 version.json；本脚本会把它同步进 release.json 与 iOS 工程生成脚本。
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET=""
RUN_TESTS=0
DO_INSTALL=0
SKIP_BUILD=0
OUT_DIR="$HOME/Desktop"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --test) RUN_TESTS=1; shift ;;
    --install) DO_INSTALL=1; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --out) OUT_DIR="${2:-}"; shift 2 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

if [[ "$TARGET" != "macos" && "$TARGET" != "ios" && "$TARGET" != "android" && "$TARGET" != "both" && "$TARGET" != "all" ]]; then
  echo "用法：bash Scripts/release.sh --target macos|ios|android|both|all [--test] [--install]" >&2
  exit 2
fi

PY="/usr/bin/python3"
MACOS_VERSION="$($PY Scripts/sync-version.py --print macos | sed -n 1p)"
MACOS_BUILD="$($PY Scripts/sync-version.py --print macos | sed -n 2p)"
IOS_VERSION="$($PY Scripts/sync-version.py --print ios | sed -n 1p)"
IOS_BUILD="$($PY Scripts/sync-version.py --print ios | sed -n 2p)"
ANDROID_VERSION="$($PY Scripts/sync-version.py --print android | sed -n 1p)"
ANDROID_BUILD="$($PY Scripts/sync-version.py --print android | sed -n 2p)"

echo "== 版本源 version.json：macOS ${MACOS_VERSION}(${MACOS_BUILD})，iOS ${IOS_VERSION}(${IOS_BUILD})，Android ${ANDROID_VERSION}(${ANDROID_BUILD})"
$PY Scripts/sync-version.py
echo "== 检查 spec 与 LumaCore 是否一致"
$PY Scripts/check-core-spec.py

stage_zip() {
  local name="$1" root="$2" extra_note="$3"
  local out="$OUT_DIR/${name}.zip"
  rm -f "$out"
  ( cd "$root/.." && zip -r -q -X "$out" "$(basename "$root")" )
  echo "   源码包：$out"
  echo "   sha256：$(shasum -a 256 "$out" | cut -d' ' -f1)"
  echo "   $extra_note"
}

build_macos() {
  if [[ $SKIP_BUILD -eq 1 ]]; then
    echo "== macOS：跳过编译，直接用 dist/Luma Reader.app"
  else
    echo "== macOS：编译 Release"
    bash Scripts/build-macos.sh
  fi
  $PY Scripts/check-app-bundle.py "dist/Luma Reader.app"
  local stage="/tmp/luma-release-macos-$MACOS_BUILD"
  rm -rf "$stage" && mkdir -p "$stage/LumaReader-macOS-${MACOS_VERSION}-${MACOS_BUILD}"
  local root="$stage/LumaReader-macOS-${MACOS_VERSION}-${MACOS_BUILD}"
  rsync -a --exclude '.build' --exclude 'dist' --exclude '.git' \
        --exclude 'DerivedData' --exclude '.swiftpm' \
        --exclude '*.zip' --exclude '*.xcarchive' ./ "$root/"
  stage_zip "LumaReader-macOS-${MACOS_VERSION}-B${MACOS_BUILD}-Source" "$root" "产物：dist/Luma Reader.app"
  if [[ $DO_INSTALL -eq 1 ]]; then
    echo "== macOS：替换 /Applications（会启动应用）"
    rsync -a --delete "dist/Luma Reader.app/" "/Applications/Luma Reader.app/"
    codesign --verify --deep --strict "/Applications/Luma Reader.app" && echo "   安装完成，签名校验通过"
  fi
}

build_ios() {
  echo "== iPhone：重新生成工程"
  ( cd iOS && $PY generate_project.py )
  if [[ $SKIP_BUILD -eq 1 ]]; then
    echo "   跳过编译"
  else
  ( cd iOS && xcodebuild -project LumaReaderIOS.xcodeproj -scheme LumaReader \
      -sdk iphoneos -configuration Release -destination 'generic/platform=iOS' \
      CODE_SIGNING_ALLOWED=NO build | tail -3 )
  fi
  if [[ $RUN_TESTS -eq 1 ]]; then
    echo "== iPhone：跑 6 个 UI 用例"
    ( cd iOS && xcodebuild test -project LumaReaderIOS.xcodeproj -scheme LumaReader \
        -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO \
        | grep -E "Executed [0-9]+ test" | tail -2 )
  fi
  local stage="/tmp/luma-release-ios-$IOS_BUILD"
  rm -rf "$stage" && mkdir -p "$stage/LumaReader-iPhone"
  local root="$stage/LumaReader-iPhone"
  mkdir -p "$root/iOS" "$root/Packages" "$root/spec"
  rsync -a --exclude '.DS_Store' --exclude '*.xcuserdatad' --exclude 'build' iOS/ "$root/iOS/"
  rsync -a --exclude '.DS_Store' --exclude '.build' Packages/LumaCore/ "$root/Packages/LumaCore/"
  rsync -a spec/ "$root/spec/"
  cp version.json "$root/version.json"
  stage_zip "LumaReader-iPhone-${IOS_VERSION}-B${IOS_BUILD}-Source" "$root" "工程：LumaReader-iPhone/iOS/LumaReaderIOS.xcodeproj（签名后可直接装真机）"
}


build_android() {
  local java_home="${JAVA_HOME:-$(cat /tmp/javahome.txt 2>/dev/null || true)}"
  local gradle="${GRADLE_BIN:-/tmp/gradledist/gradle-8.10.2/bin/gradle}"
  local sdk="${ANDROID_HOME:-/tmp/android-sdk}"
  if [[ -z "$java_home" || ! -x "$gradle" ]]; then
    echo "== Android：找不到 JDK 或 Gradle（设 JAVA_HOME / GRADLE_BIN）" >&2
    return 1
  fi
  echo "== Android：跑内核测试 + 编 Debug APK"
  ( cd android && JAVA_HOME="$java_home" ANDROID_HOME="$sdk" "$gradle" :core:test :app:assembleDebug -q )
  local apk="android/app/build/outputs/apk/debug/app-debug.apk"
  [[ -f "$apk" ]] || { echo "   没找到 APK" >&2; return 1; }
  local stage="/tmp/luma-release-android-$ANDROID_BUILD"
  rm -rf "$stage" && mkdir -p "$stage/LumaReader-Android"
  local root="$stage/LumaReader-Android"
  rsync -a --exclude '.gradle' --exclude 'build' --exclude '.idea' --exclude 'local.properties' \
        android/ "$root/android/"
  rsync -a spec/ "$root/spec/"
  cp version.json "$root/version.json"
  cp "$apk" "$root/LumaReader-Android-${ANDROID_VERSION}-B${ANDROID_BUILD}-debug.apk"
  stage_zip "LumaReader-Android-${ANDROID_VERSION}-B${ANDROID_BUILD}-Source" "$root" "APK 在包内（debug 签名，可直接 adb install）"
}

case "$TARGET" in
  macos) build_macos ;;
  ios) build_ios ;;
  android) build_android ;;
  both) build_macos; build_ios ;;
  all) build_macos; build_ios; build_android ;;
esac

echo "== 完成（版本源：version.json）"
