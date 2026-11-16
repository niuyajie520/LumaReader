#!/usr/bin/env python3
"""把 version.json 同步进各平台的工程文件。

用法：
  python3 Scripts/sync-version.py            # 写入（release.json / iOS 工程生成脚本）
  python3 Scripts/sync-version.py --check    # 只检查是否一致，不一致退出码 1
  python3 Scripts/sync-version.py --print macos|ios|android  # 打印 version / build

`version.json` 是唯一版本源：改版本只改它，然后跑 release.sh（或本脚本 + 构建）。
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSION_FILE = os.path.join(ROOT, "version.json")
RELEASE_FILE = os.path.join(ROOT, "release.json")
IOS_GENERATOR = os.path.join(ROOT, "iOS", "generate_project.py")
ANDROID_GRADLE = os.path.join(ROOT, "android", "app", "build.gradle.kts")


def load():
    with open(VERSION_FILE, encoding="utf-8") as handle:
        return json.load(handle)


def read_release():
    with open(RELEASE_FILE, encoding="utf-8") as handle:
        return json.load(handle)


def ios_generator_value(text, key):
    match = re.search(r'"%s": "([^"]+)"' % key, text)
    return match.group(1) if match else None


def sync_message(prefix, macos, ios, android):
    parts = [f"macOS {macos['version']}({macos['build']})", f"iOS {ios['version']}({ios['build']})"]
    if android:
        parts.append(f"Android {android['version']}({android['build']})")
    return prefix + "：" + "，".join(parts)


def main(argv):
    data = load()
    macos = data["macos"]
    ios = data["ios"]
    android = data.get("android")

    if "--print" in argv:
        which = argv[argv.index("--print") + 1]
        meta = {"macos": macos, "ios": ios, "android": android}.get(which) or macos
        print(meta["version"])
        print(meta["build"])
        return 0

    check_only = "--check" in argv
    problems = []

    release = read_release()
    if release.get("version") != macos["version"]:
        problems.append(f"release.json version={release.get('version')} 应为 {macos['version']}")
    if release.get("build") != macos["build"]:
        problems.append(f"release.json build={release.get('build')} 应为 {macos['build']}")
    if "source_id" in macos and release.get("source_id") != macos["source_id"]:
        problems.append(f"release.json source_id={release.get('source_id')} 应为 {macos['source_id']}")

    with open(IOS_GENERATOR, encoding="utf-8") as handle:
        generator = handle.read()
    current_ios_version = ios_generator_value(generator, "MARKETING_VERSION")
    current_ios_build = ios_generator_value(generator, "CURRENT_PROJECT_VERSION")
    if current_ios_version != ios["version"]:
        problems.append(f"iOS MARKETING_VERSION={current_ios_version} 应为 {ios['version']}")
    if current_ios_build != ios["build"]:
        problems.append(f"iOS CURRENT_PROJECT_VERSION={current_ios_build} 应为 {ios['build']}")

    if android:
        with open(ANDROID_GRADLE, encoding="utf-8") as handle:
            gradle = handle.read()
        current_code = re.search(r"versionCode\s*=\s*(\d+)", gradle)
        current_name = re.search(r'versionName\s*=\s*"([^"]+)"', gradle)
        code = current_code.group(1) if current_code else None
        name = current_name.group(1) if current_name else None
        if name != android["version"]:
            problems.append(f"Android versionName={name} 应为 {android['version']}")
        if code != str(android["build"]):
            problems.append(f"Android versionCode={code} 应为 {android['build']}")

    if problems:
        if check_only:
            print("版本不一致：", file=sys.stderr)
            for item in problems:
                print("  - " + item, file=sys.stderr)
            print("跑 python3 Scripts/sync-version.py 修正。", file=sys.stderr)
            return 1
        release["version"] = macos["version"]
        release["build"] = macos["build"]
        if "source_id" in macos:
            release["source_id"] = macos["source_id"]
        with open(RELEASE_FILE, "w", encoding="utf-8") as handle:
            json.dump(release, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        generator = re.sub(r'"MARKETING_VERSION": "[^"]+"', f'"MARKETING_VERSION": "{ios["version"]}"', generator)
        generator = re.sub(r'"CURRENT_PROJECT_VERSION": "[^"]+"', f'"CURRENT_PROJECT_VERSION": "{ios["build"]}"', generator)
        with open(IOS_GENERATOR, "w", encoding="utf-8") as handle:
            handle.write(generator)
        if android:
            with open(ANDROID_GRADLE, "w", encoding="utf-8") as handle:
                gradle = re.sub(r"versionCode\s*=\s*\d+", f'versionCode = {android["build"]}', gradle)
                gradle = re.sub(r'versionName\s*=\s*"[^"]+"', f'versionName = "{android["version"]}"', gradle)
                handle.write(gradle)
        print(sync_message("已同步", macos, ios, android))
    else:
        print(sync_message("版本一致", macos, ios, android))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
