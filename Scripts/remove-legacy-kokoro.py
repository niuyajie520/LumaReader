#!/usr/bin/env python3
"""Remove the explicitly retired Kokoro 82M weights from LumaReader-owned locations."""
from pathlib import Path
import json
import sys

def cleanup(support):
    for name in ("KokoroEngine", "KokoroTTS"):
        base = support / name
        for directory in (base, base / "models"):
            for filename in ("kokoro-v1.0.onnx", "voices-v1.0.bin"):
                target = directory / filename
                if target.is_file() or target.is_symlink():
                    # Unlink the entry itself, never follow it for deletion.
                    target.unlink()
        config = base / "config/exclusive-engine.json"
        if config.is_file():
            data = json.loads(config.read_text())
            if data.get("model") == "kokoro":
                data["model"] = "kitten-micro"
            if isinstance(data.get("voices"), dict):
                data["voices"].pop("kokoro", None)
            temporary = config.with_suffix(".migration-tmp")
            temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2))
            temporary.replace(config)

if __name__ == "__main__":
    try:
        cleanup(Path.home() / "Library/Application Support/LumaReader")
    except (OSError, ValueError) as error:
        print("旧语音模型清理失败：" + str(error), file=sys.stderr)
        sys.exit(1)
