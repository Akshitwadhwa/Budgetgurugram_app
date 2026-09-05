#!/usr/bin/env bash

# Builds a silent, continuous-motion time-lapse from matched aerial city plates.
# The construction beat uses four near-identical generated motion states and
# optical-flow interpolation at 48fps, creating in-between crane, vehicle, and
# traffic positions rather than crossfading the stills.
set -euo pipefail

workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets_dir="$workspace_dir/assets/video"
output_dir="$workspace_dir/exports"
output_file="$output_dir/gurugram-photoreal-city-timelapse.mp4"
font_file="/System/Library/Fonts/Supplemental/Verdana.ttf"

mkdir -p "$output_dir"
work_dir="$(mktemp -d /private/tmp/gurugram-photoreal.XXXXXX)"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

ffmpeg -y -loop 1 -framerate 24 -t 3.4 -i "$assets_dir/gurugram-city-empty-plaza.png" \
  -vf "scale=2080:1170,crop=1920:1080:x='80+10*sin(0.9*t)':y='45+6*cos(0.7*t)'" \
  -r 48 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p "$work_dir/empty.mp4"

cp "$assets_dir/gurugram-city-construction.png" "$work_dir/motion-01.png"
cp "$assets_dir/gurugram-city-construction-motion.png" "$work_dir/motion-02.png"
cp "$assets_dir/gurugram-city-construction-motion-01.png" "$work_dir/motion-03.png"
cp "$assets_dir/gurugram-city-construction-motion-02.png" "$work_dir/motion-04.png"

ffmpeg -y -framerate 1 -start_number 1 -i "$work_dir/motion-%02d.png" \
  -vf "minterpolate=fps=48:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,
    scale=2100:1181,
    crop=1920:1080:x='90-14*sin(0.8*t)':y='51+5*cos(0.8*t)'" \
  -r 48 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p "$work_dir/construction.mp4"

ffmpeg -y -loop 1 -framerate 24 -t 5.8 -i "$assets_dir/gurugram-city-finished-campus.png" \
  -vf "scale=2080:1170,crop=1920:1080:x='80+8*sin(0.6*t)':y='45-6*cos(0.5*t)'" \
  -r 48 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p "$work_dir/finished.mp4"

ffmpeg -y \
  -i "$work_dir/empty.mp4" -i "$work_dir/construction.mp4" -i "$work_dir/finished.mp4" \
  -filter_complex "
    [0:v][1:v]xfade=transition=fade:duration=0.8:offset=2.6[ab];
    [ab][2:v]xfade=transition=fade:duration=0.8:offset=4.2[city];
    [city]
      drawbox=x='530+44*t':y='470+25*t':w=12:h=6:color=0xF6BF3B@0.78:t=fill:enable='between(t\\,0.2\\,3.2)',
      drawbox=x='820+33*t':y='620+19*t':w=11:h=6:color=0xEA5D49@0.76:t=fill:enable='between(t\\,3.0\\,7.0)',
      drawbox=x='1570+13*t':y='245+44*t':w=10:h=6:color=0xF3F3E7@0.74:t=fill:enable='between(t\\,0.5\\,9.2)',
      drawbox=x='1640-11*t':y='700-41*t':w=10:h=6:color=0xDB9641@0.74:t=fill:enable='between(t\\,3.6\\,9.6)',
      drawbox=x='430+58*t':y='384+29*t':w=10:h=5:color=0xD5E1DD@0.70:t=fill:enable='between(t\\,0.6\\,3.8)',
      drawbox=x='1180-47*t':y='736-24*t':w=11:h=5:color=0x8EBDD3@0.72:t=fill:enable='between(t\\,1.3\\,7.0)',
      drawbox=x='1120+39*t':y='426+16*t':w=10:h=5:color=0xE5A137@0.72:t=fill:enable='between(t\\,3.1\\,7.1)',
      drawbox=x='1450+20*t':y='782-51*t':w=9:h=5:color=0xE8EBE8@0.70:t=fill:enable='between(t\\,3.8\\,9.4)',
      drawtext=fontfile='$font_file':text='BUDGET GURUGRAM':fontcolor=0xFFF8EA:fontsize=38:x=72:y=934:shadowcolor=0x17241E:shadowx=2:shadowy=3:enable='gte(t\\,8.1)',
      drawtext=fontfile='$font_file':text='A CITY UNDER CONSTRUCTION':fontcolor=0xE6D7A9:fontsize=17:x=76:y=970:shadowcolor=0x17241E:shadowx=1:shadowy=2:enable='gte(t\\,8.25)'
      [out]" \
  -map "[out]" -t 10 -r 48 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -movflags +faststart -an "$output_file"

echo "Wrote $output_file"
