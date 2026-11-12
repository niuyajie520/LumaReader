#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
runtime="${1:?需要语音数据目录}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$runtime"
python="$runtime/venv/bin/python3"
if [[ ! -x "$python" ]] || ! "$python" -c 'import sys; sys.exit(sys.version_info < (3,10))'; then
    bootstrap=""
    for candidate in python3 python3.13 python3.12 python3.11 python3.10; do
        if command -v "$candidate" >/dev/null && "$candidate" -c 'import ensurepip, sys; sys.exit(sys.version_info < (3,10))' 2>/dev/null; then
            bootstrap="$candidate"
            break
        fi
    done
    if [[ -z "$bootstrap" ]]; then
        echo "本地神经语音需要 Python 3.10 或更高版本。请安装后重试。" >&2
        exit 1
    fi
    "$bootstrap" -m venv "$runtime/venv"
fi
if ! "$python" -m pip --version >/dev/null 2>&1; then
    "$python" -m ensurepip --upgrade
fi
if ! "$python" -c 'from importlib.metadata import version; assert version("kittenml") == "0.9.7"; from kittenml import KittenTTS; import kittenml.kittentts_legacy.onnx_model'; then
    "$python" -m pip install --disable-pip-version-check numpy soundfile onnxruntime espeakng_loader phonemizer huggingface_hub kitten-text-processing
    "$python" -m pip install --disable-pip-version-check --no-deps 'kittenml==0.9.7'
    "$python" -c 'from kittenml import KittenTTS; import kittenml.kittentts_legacy.onnx_model'
fi
if [[ -n "${2:-}" ]]; then
    [[ -f "$2/manifest.json" ]] || { echo "缺少内嵌 Kitten 模型资源。" >&2; exit 1; }
else
    "$python" "$script_dir/setup_kitten.py" "$runtime"
fi
