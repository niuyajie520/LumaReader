from pathlib import Path
import json
import sys
from huggingface_hub import hf_hub_download

base = Path(sys.argv[1])
cache = base / "kitten-cache"
manifest = base / "models-installed.json"
try:
    installed = json.loads(manifest.read_text())
except (OSError, ValueError):
    installed = {}
if not isinstance(installed, dict):
    installed = {}

def fetch(repo, filename, revision=None):
    options = dict(repo_id=repo, filename=filename, cache_dir=str(cache), revision=revision)
    try:
        return Path(hf_hub_download(**options, local_files_only=True))
    except (OSError, ValueError):
        return Path(hf_hub_download(**options))


def complete_model(directory):
    config = json.loads((directory / "config.json").read_text())
    return all((directory / config[key]).is_file() and (directory / config[key]).stat().st_size > 0
               for key in ("model_file", "voices"))


errors = []
for name, repo in (
    ("kitten-nano", "KittenML/kitten-tts-nano-0.8-int8"),
    ("kitten-micro", "KittenML/kitten-tts-micro-0.8"),
):
    print(f"检查或下载 {name}", flush=True)
    try:
        saved = installed.get(name)
        if isinstance(saved, str):
            try:
                if complete_model(Path(saved)):
                    continue
            except (OSError, ValueError, KeyError, TypeError):
                pass
        config_path = fetch(repo, "config.json")
        config = json.loads(config_path.read_text())
        for key in ("model_file", "voices"):
            fetch(repo, config[key], revision=config_path.parent.name)
        if not complete_model(config_path.parent):
            raise ValueError("模型权重或声线文件缺失")
        installed[name] = str(config_path.parent)
        temporary = manifest.with_suffix(".tmp")
        temporary.write_text(json.dumps(installed))
        temporary.replace(manifest)
    except Exception as error:
        errors.append(f"{name}: {error}")
        print(errors[-1], file=sys.stderr, flush=True)
if errors:
    sys.exit(1)
print("Kitten Nano 和 Micro 已准备好。", flush=True)
