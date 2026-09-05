#!/usr/bin/env bash

set -euo pipefail

workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
frames_dir="$(mktemp -d /private/tmp/gurugram-construction.XXXXXX)"
output_dir="$workspace_dir/exports"
output_file="$output_dir/gurugram-construction-city-intro.mp4"

cleanup() {
  rm -rf "$frames_dir"
}
trap cleanup EXIT

mkdir -p "$output_dir"
node "$workspace_dir/tools/render_construction_city_frames.mjs" "$frames_dir"

find "$frames_dir" -name '*.svg' -print0 | xargs -0 -P 8 -n 1 sh -c 'rsvg-convert "$0" --width 1920 --height 1080 --output "${0%.svg}.png"'

ffmpeg -y -framerate 24 -i "$frames_dir/frame-%03d.png" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart \
  -an "$output_file"

echo "Wrote $output_file"
