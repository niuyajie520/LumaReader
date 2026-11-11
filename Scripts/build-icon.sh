#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="${1:?需要输出目录}"
mkdir -p "$output_dir"
icon_work="$(mktemp -d "${TMPDIR:-/tmp}/luma-icons.XXXXXX")"
trap 'rm -rf "$icon_work"' EXIT
for style in Glass Light Dark; do
  source_icon="$PWD/Assets/AppIcon/LumaReader-$style.png"
  icon_set="$icon_work/$style.iconset"
  mkdir -p "$icon_set"
  for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" "$source_icon" --out "$icon_set/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    /usr/bin/sips -z "$double_size" "$double_size" "$source_icon" --out "$icon_set/icon_${size}x${size}@2x.png" >/dev/null
  done
  /usr/bin/iconutil -c icns "$icon_set" -o "$output_dir/LumaReader-$style.icns"
  cp "$source_icon" "$output_dir/"
done
cp "$output_dir/LumaReader-Glass.icns" "$output_dir/LumaReader.icns"
