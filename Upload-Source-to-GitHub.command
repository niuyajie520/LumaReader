#!/bin/bash
# Publishes only this reviewed snapshot, through the user's own local Git authentication.
set -euo pipefail
cd "$(dirname "$0")"
luma_source="$PWD"
luma_repo_url='https://github.com/niuyajie520/LumaReader.git'
luma_expected='2446096a8e249e7d2a8ffcc345981758d9a18106'
luma_branch='verify/macos26-blockers'
finish() { local status=$?; if [[ "$status" -ne 0 ]]; then echo '上传未完成。不要把密码、访问令牌或钥匙串内容发送到聊天。'; fi; if [[ -t 0 ]]; then read -r -p '按回车关闭。' _response || true; fi; }
trap finish EXIT
[[ "$(uname -s)" == Darwin ]] || { echo '请在 Mac 上运行。';exit 1; }
command -v python3 >/dev/null || { echo '需要开发工具中的 Python 3，请先安装并打开 Xcode。';exit 1; }
python3 Scripts/privacy-gate.py .
echo '将把本目录经过筛查的源码上传到 Private 仓库的 verify/macos26-blockers 分支。'
echo '不会上传书库、旧日志、旧审计报告、凭据或当前电脑的用户数据。'
echo 'Git 可能要求你在本机完成 GitHub 身份验证；不要将凭据粘贴到聊天。'
read -r -p '确认上传这份源码，按回车继续；取消请按 Control-C。' _response
luma_work="$(mktemp -d "${TMPDIR:-/tmp}/luma-ci-upload.XXXXXX")"
# Keep this checkout on failure so the user can inspect it; never delete existing local projects.
/usr/bin/git clone --branch main --single-branch "$luma_repo_url" "$luma_work/repository"
luma_checkout="$luma_work/repository"
[[ "$(/usr/bin/git -C "$luma_checkout" rev-parse HEAD)" == "$luma_expected" ]] || { echo '远端 main 已变化，已停止，避免覆盖新的修改。请重新核对后再上传。';exit 1; }
for luma_folder in Sources Tests Scripts Vendor ThirdParty Assets .github; do
  /usr/bin/ditto "$luma_source/$luma_folder" "$luma_checkout/$luma_folder"
done
for luma_file in package.json Package.swift Package.resolved LICENSE ZIPFoundation-LICENSE.txt THIRD_PARTY_NOTICES.md README.md .gitignore Install-LumaReader.command Verify-LumaReader.command Upload-Source-to-GitHub.command SECOND-PASS-REPORT.txt PRIOR-PASS.csv PRIVACY-SOURCE.json PRIVACY-FILES.csv CI-PREP-TESTS.json; do
  cp "$luma_source/$luma_file" "$luma_checkout/$luma_file"
done
/usr/bin/git -C "$luma_checkout" checkout -b "$luma_branch"
# Remove only the two known misplaced workflow files from the reviewed base commit.
/usr/bin/git -C "$luma_checkout" rm -- LumaReader_macOS26_CI.yml lumareader-macos26.yml
(cd "$luma_checkout"; python3 Scripts/privacy-gate.py .)
/usr/bin/git -C "$luma_checkout" add --all
# Deliberately synthetic public commit identity; do not disclose the user's local Git email.
/usr/bin/git -C "$luma_checkout" -c user.name='LumaReader Contributors' -c user.email='contributors@example.invalid' commit -m 'Import reviewed reader source and enable macOS 26 verification'
/usr/bin/git -C "$luma_checkout" push origin "HEAD:refs/heads/$luma_branch"
echo '源码分支已上传。请在 Actions 页面查看真实构建结果；上传成功不表示测试通过。'
open 'https://github.com/niuyajie520/LumaReader/actions'
