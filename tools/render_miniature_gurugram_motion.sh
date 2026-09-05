#!/usr/bin/env bash

# Creates a fully procedural miniature-city animation: every car, crane, and
# rising building is a separately animated scene element, not a morphed photo.
set -euo pipefail

workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$workspace_dir/exports"
output_file="$output_dir/gurugram-miniature-city-motion.mp4"
work_dir="$(mktemp -d /private/tmp/gurugram-miniature.XXXXXX)"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$output_dir"
node "$workspace_dir/tools/render_miniature_gurugram_motion.mjs" "$work_dir/frames"

for svg_file in "$work_dir"/frames/frame-*.svg; do
  rsvg-convert -w 1280 -h 720 "$svg_file" -o "${svg_file%.svg}.png"
done

ffmpeg -y -framerate 15 -start_number 1 -i "$work_dir/frames/frame-%04d.png" \
  -vf "minterpolate=fps=30:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,scale=1920:1080:flags=lanczos" \
  -r 30 -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p -movflags +faststart -an "$output_file"

echo "Wrote $output_file"
