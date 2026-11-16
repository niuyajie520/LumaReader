#!/usr/bin/env python3
"""检查 spec/ 里的跨平台合同与 LumaCore 源码是否还一致。

只做「能在几毫秒内发现漂移」的那部分检查：
  * JSON 能解析、关键字段齐全；
  * constants.json 里的数字在 Swift 源码里真的出现（改了代码忘了改规范会被拦）；
  * LumaCoreVersion.specification 与 behaviour.json 的 specification 相同。

用法：python3 Scripts/check-core-spec.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC_DIR = os.path.join(ROOT, "spec")
CORE_DIR = os.path.join(ROOT, "Packages", "LumaCore", "Sources", "LumaCore")


def load(name):
    with open(os.path.join(SPEC_DIR, name), encoding="utf-8") as handle:
        return json.load(handle)


def core_source():
    chunks = []
    for name in sorted(os.listdir(CORE_DIR)):
        if name.endswith(".swift"):
            with open(os.path.join(CORE_DIR, name), encoding="utf-8") as handle:
                chunks.append(handle.read())
    return "\n".join(chunks)


def main():
    problems = []

    constants = load("constants.json")
    behaviour = load("behaviour.json")
    source = core_source()

    for key in ("specification", "dictation", "review"):
        if key not in constants:
            problems.append(f"constants.json 缺少 {key}")

    dictation = constants.get("dictation", {})
    for name, expected in (
        ("newWordLadder", [5, 55, 155, 255]),
        ("economicRetryLadder", [10, 20, 35, 50]),
        ("relearnStep", 5),
    ):
        if dictation.get(name) != expected:
            problems.append(f"constants.json {name}={dictation.get(name)}，行为规范应为 {expected}")

    # 每个数字都应该能在源码里找到（至少一次），防止「规范改了代码没改」。
    numeric_values = []
    for value in dictation.values():
        for item in value if isinstance(value, list) else [value]:
            if isinstance(item, int):
                numeric_values.append(item)
    review = constants.get("review", {})
    for value in review.values():
        for item in value if isinstance(value, list) else [value]:
            if isinstance(item, int):
                numeric_values.append(item)

    for number in sorted(set(numeric_values)):
        if not re.search(r"\b%d\b" % number, source):
            problems.append(f"constants.json 里的 {number} 在 LumaCore 源码里找不到，可能已经改掉")

    behaviour_spec = str(behaviour.get("specification", ""))
    match = re.search(r'static let specification = "([^"]+)"', source)
    core_spec = match.group(1) if match else None
    if core_spec is None:
        problems.append("LumaCoreVersion.specification 读不到")
    elif core_spec != behaviour_spec:
        problems.append(f"内核 specification={core_spec}，behaviour.json={behaviour_spec}，两边要一起改")

    for key in ("judgement", "normalization", "entryKind", "minorSlip", "reviewSchedule", "session", "syncMerge"):
        if key not in behaviour:
            problems.append(f"behaviour.json 缺少 {key} 组用例")

    if problems:
        print("规范与内核不一致：", file=sys.stderr)
        for item in problems:
            print("  - " + item, file=sys.stderr)
        return 1

    print(f"spec 与内核一致：specification={core_spec}，"
          f"{len(behaviour)} 组用例，{len(set(numeric_values))} 个常量")
    return 0


if __name__ == "__main__":
    sys.exit(main())
