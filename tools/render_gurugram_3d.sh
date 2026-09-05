#!/usr/bin/env bash

# Renders the Gurugram miniature city with actual Blender mesh geometry,
# animated cranes, vehicle paths, rising construction, and a moving camera.
set -euo pipefail

workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
blender_bin="/Applications/Blender.app/Contents/MacOS/Blender"
output_dir="$workspace_dir/exports"
output_file="$output_dir/gurugram-3d-miniature-city.mp4"

mkdir -p "$output_dir"
"$blender_bin" -b -P "$workspace_dir/tools/render_gurugram_3d.py" -o "$output_file" -a
echo "Wrote $output_file"
