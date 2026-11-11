#!/bin/bash
# LumaReader 一键发布脚本（可无人值守）
# 流程：隐私/密钥扫描 → Release 编译 → 生成 DMG 与源码包 → SHA256 →（可选）GitHub Release
#
# 用法：
#   bash Scripts/release-dmg.sh                 # 只检查+编译+打包，不联网发布
#   bash Scripts/release-dmg.sh --publish       # 额外创建/更新 GitHub Release
#   bash Scripts/release-dmg.sh --check-only    # 只做隐私扫描
#   bash Scripts/release-dmg.sh --publish --draft --tag v1.0.0
#
# 依赖：macOS + Xcode，python3；发布时需要已登录的 gh（GitHub CLI）。
# 注意：本脚本不会打印任何密钥值，只报告 文件:规则。
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

REPO_DEFAULT="niuyajie520/LumaReader"
APP_NAME="Luma Reader"
VERSION=""
OUT="$ROOT/dist/release"
PUBLISH=0
DRAFT=0
CHECK_ONLY=0
TAG=""
REPO="$REPO_DEFAULT"
TARGET="main"
NOTES=""
STAGE=""
LOG=""

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish) PUBLISH=1 ;;
    --draft) DRAFT=1 ;;
    --check-only) CHECK_ONLY=1 ;;
    --version) VERSION="${2:?}"; shift ;;
    --tag) TAG="${2:?}"; shift ;;
    --repo) REPO="${2:?}"; shift ;;
    --target) TARGET="${2:?}"; shift ;;
    --notes) NOTES="${2:?}"; shift ;;
    --out) OUT="${2:?}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

step() { printf '\n==> %s\n' "$*"; }
die()  { printf '\n[失败] %s\n' "$*" >&2; exit 1; }
cleanup() { [[ -n "$STAGE" && -d "$STAGE" ]] && rm -rf "$STAGE" || true; }
trap cleanup EXIT

[[ "$(uname -s)" == Darwin ]] || die "必须在 macOS 上运行。"
command -v python3 >/dev/null || die "缺少 python3（请安装 Xcode 命令行工具）。"

mkdir -p "$OUT"
LOG="$OUT/release-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's:.*<key>CFBundleShortVersionString</key><string>\([^<]*\)</string>.*:\1:p' Scripts/build-macos.sh | head -1)"
fi
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "无法确定版本号（得到：${VERSION:-空}）。用 --version 指定。"
[[ -n "$TAG" ]] || TAG="v$VERSION"
[[ -z "$NOTES" && -f "$ROOT/RELEASE_NOTES.md" ]] && NOTES="$ROOT/RELEASE_NOTES.md"

step "版本 $VERSION / 标签 $TAG / 仓库 $REPO"
echo "日志：$LOG"

# ---------------------------------------------------------------- 隐私检查
privacy_scan() {
  step "隐私检查：项目规则（路径、邮箱、私钥、常见 token）"
  python3 Scripts/privacy-gate.py "$ROOT" || die "privacy-gate 未通过，已停止。"
  python3 - "$ROOT" <<'PY' || die "额外密钥扫描未通过，已停止。"
import re, sys
from pathlib import Path

root = Path(sys.argv[1])
skip_dirs = {'.git', '.build', '.swiftpm', 'dist', 'node_modules', '__pycache__', 'ci-raw'}
skip_suffix = {'.zip', '.dmg', '.png', '.jpg', '.jpeg', '.icns', '.pdf', '.app'}
rules = {
    'google-api-key': re.compile(rb'AIza[0-9A-Za-z_-]{35}'),
    'slack-token': re.compile(rb'xox[abprs]-[A-Za-z0-9-]{10,}'),
    'openai-key': re.compile(rb'sk-(?:proj-|ant-)?[A-Za-z0-9_-]{25,}'),
    'github-token': re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})'),
    'aws-key': re.compile(rb'(?:AKIA|ASIA)[A-Z0-9]{16}'),
    'jwt': re.compile(rb'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
    'private-key': re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----'),
}
findings = []
checked = 0
for p in sorted(root.rglob('*')):
    rel = p.relative_to(root)
    if not p.is_file() or set(rel.parts) & skip_dirs:
        continue
    if p.suffix.lower() in skip_suffix:
        continue
    checked += 1
    data = p.read_bytes()
    for name, rx in rules.items():
        if rx.search(data):
            findings.append((rel.as_posix(), name))
if findings:
    print('密钥扫描：FAIL（只列文件与规则，不显示匹配值）')
    for path, name in findings:
        print(f'  {path}: {name}')
    sys.exit(1)
print(f'密钥扫描：PASS（检查 {checked} 个文本文件，未命中高置信度密钥模式）')
PY
}

# ---------------------------------------------------------------- 编译
build_app() {
  step "Release 编译（输出在 $ROOT/dist）"
  LUMA_NO_OPEN=1 bash Scripts/build-macos.sh
  [[ -d "dist/$APP_NAME.app" ]] || die "编译后没有找到 dist/$APP_NAME.app"
}

verify_app() {
  local app="$1"
  step "校验 app：版本、签名、架构、资源"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$VERSION" ]] \
    || die "app 版本与 $VERSION 不一致。"
  codesign --verify --deep --strict "$app" || die "codesign 校验失败。"
  file "$app/Contents/MacOS/LumaReader" | grep -q 'arm64' || die "可执行文件不是 arm64。"
  [[ -d "$app/Contents/Resources/LumaReader_LumaReader.bundle" ]] || die "缺少 SwiftPM 资源包。"
  [[ -f "$app/Contents/Resources/Reader.js" ]] || die "缺少阅读器资源。"
}

# ---------------------------------------------------------------- 打包
package_dmg() {
  step "生成 DMG"
  local src="$ROOT/dist/$APP_NAME.app"
  STAGE="$(mktemp -d "${TMPDIR:-/tmp}/luma-release.XXXXXX")"
  # 在 /tmp 组装，避免 iCloud/OneDrive/File Provider 重新附加 FinderInfo 破坏签名。
  /usr/bin/ditto --noextattr --noqtn "$src" "$STAGE/$APP_NAME.app"
  ln -s /Applications "$STAGE/Applications"
  local dmg="$OUT/LumaReader-$VERSION-macOS-arm64.dmg"
  rm -f "$dmg"
  hdiutil create -quiet -volname "Luma Reader $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$dmg"
  hdiutil verify -quiet "$dmg" || die "DMG 校验失败。"
  /usr/bin/xattr -cr "$dmg" 2>/dev/null || true
  echo "DMG：$dmg"
}

package_source() {
  step "生成源码包"
  local zip="$OUT/LumaReader-$VERSION-Source.zip"
  rm -f "$zip"
  ( cd "$ROOT" && zip -rqX "$zip" . \
      -x '.build/*' 'dist/*' '.git/*' '__MACOSX/*' '*.DS_Store' '*.zip' ) \
    || die "源码打包失败。"
  unzip -tq "$zip" >/dev/null || die "源码 zip 完整性检查失败。"
  echo "源码：$zip"
}

checksums() {
  step "生成 SHA256"
  ( cd "$OUT" && shasum -a 256 "LumaReader-$VERSION-macOS-arm64.dmg" "LumaReader-$VERSION-Source.zip" > SHA256SUMS )
  cat "$OUT/SHA256SUMS"
}

# ---------------------------------------------------------------- 发布
publish_release() {
  step "发布 GitHub Release"
  local gh_bin
  gh_bin="$(command -v gh || true)"
  [[ -n "$gh_bin" ]] || die "未找到 gh。请先安装 GitHub CLI 并 gh auth login；产物已保留在 $OUT。"
  "$gh_bin" auth status >/dev/null 2>&1 || die "gh 未登录。请先运行 gh auth login；产物已保留在 $OUT。"

  if [[ -z "$NOTES" || ! -f "$NOTES" ]]; then
    die "缺少发布说明文件（默认 RELEASE_NOTES.md，可用 --notes 指定）。"
  fi

  if "$gh_bin" release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    local is_draft
    is_draft="$("$gh_bin" release view "$TAG" --repo "$REPO" --json isDraft --jq .isDraft)"
    [[ "$is_draft" == "true" ]] || die "Release $TAG 已正式发布，拒绝覆盖。请换 --tag。"
    echo "检测到草稿 Release $TAG，更新资产。"
  else
    local args=(release create "$TAG" --repo "$REPO" --target "$TARGET"
                --title "LumaReader $VERSION" --notes-file "$NOTES")
    [[ "$DRAFT" == "1" ]] && args+=(--draft)
    "$gh_bin" "${args[@]}"
  fi

  "$gh_bin" release upload "$TAG" --repo "$REPO" --clobber \
    "$OUT/LumaReader-$VERSION-macOS-arm64.dmg" \
    "$OUT/LumaReader-$VERSION-Source.zip" \
    "$OUT/SHA256SUMS"

  step "回读校验"
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/luma-verify.XXXXXX")"
  "$gh_bin" release download "$TAG" --repo "$REPO" --dir "$tmp"
  ( cd "$tmp" && shasum -a 256 -c SHA256SUMS )
  rm -rf "$tmp"

  if [[ "$DRAFT" == "0" ]]; then
    "$gh_bin" release edit "$TAG" --repo "$REPO" --draft=false >/dev/null
  fi
  "$gh_bin" release view "$TAG" --repo "$REPO" --json url,isDraft,assets \
    --jq '"Release: \(.url)\ndraft: \(.isDraft)\n" + (.assets[] | "  \(.name)  \(.size) bytes")'
}

# ---------------------------------------------------------------- 主流程
privacy_scan
[[ "$CHECK_ONLY" == "1" ]] && { step "仅检查模式，结束"; exit 0; }

build_app
verify_app "$ROOT/dist/$APP_NAME.app"

# 编译后再扫一次二进制里的本机路径，防止把用户主目录路径带进发布物。
step "二进制路径审计"
audit="$(cd "$ROOT" && python3 Scripts/binary-path-audit.py "$ROOT/dist/$APP_NAME.app/Contents/MacOS/LumaReader")"
echo "$audit"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d.get("otherMatches",0)==0 else 1)' "$audit" \
  || die "可执行文件包含本机路径，已停止。"

package_dmg
package_source
checksums

if [[ "$PUBLISH" == "1" ]]; then
  publish_release
else
  step "完成（未发布）"
  echo "产物目录：$OUT"
  echo "确认无误后运行：bash Scripts/release-dmg.sh --publish"
fi
