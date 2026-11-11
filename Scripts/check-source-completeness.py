from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "Review/BASE_SOURCE_INVENTORY.json").read_text())
missing = [entry["path"] for entry in manifest["files"] if not (root / entry["path"]).is_file()]
if missing:
    raise SystemExit("Source package is incomplete: " + ", ".join(missing))
print("Base source inventory: all", len(manifest["files"]), "files present; not a compile result")
