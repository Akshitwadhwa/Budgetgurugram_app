#!/usr/bin/env bash

# Renders a silent, original title sequence inspired by the broad device of a
# miniature city changing in time-lapse. It deliberately does not reuse any
# television footage, title artwork, music, or specific scene composition.
set -euo pipefail

workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plate="$workspace_dir/assets/video/gurugram-isometric-city-plate.png"
output_dir="$workspace_dir/exports"
output_file="$output_dir/gurugram-isometric-city-intro.mp4"
font_file="/System/Library/Fonts/Supplemental/Verdana.ttf"

mkdir -p "$output_dir"

ffmpeg -y -loop 1 -i "$plate" -t 10 \
  -vf "
zoompan=z='if(eq(on\\,0)\\,1.0\\,min(1.12\\,zoom+0.0004))':x='iw/2-(iw/zoom/2)+sin(on*0.015)*18':y='ih/2-(ih/zoom/2)+cos(on*0.012)*12':d=300:s=1920x1080:fps=30,
drawbox=x=0:y=0:w=1920:h=1080:color=0xF7EACE@0.06:t=fill,
drawbox=x=75:y=70:w=360:h=3:color=0xE2A72E@0.88:t=fill:enable='between(t\\,0.15\\,9.8)',
drawtext=fontfile='$font_file':text='GURUGRAM // INDIA':fontcolor=0x1D312C:fontsize=24:x=75:y=85:enable='gte(t\\,0.15)',
drawtext=fontfile='$font_file':text='THE CITY IS STILL SHIPPING.':fontcolor=0x315047:fontsize=19:x=75:y=119:enable='gte(t\\,0.45)',
drawbox=x=230:y='760-110*min(1\\,(t-0.7)/0.6)':w=22:h='110*min(1\\,(t-0.7)/0.6)':color=0xE0A62C@0.9:t=fill:enable='between(t\\,0.7\\,3.8)',
drawbox=x=202:y=653:w=84:h=7:color=0xE0A62C@0.9:t=fill:enable='between(t\\,1.1\\,3.8)',
drawbox=x=1380:y='650-135*min(1\\,(t-1.0)/0.7)':w=22:h='135*min(1\\,(t-1.0)/0.7)':color=0xE0A62C@0.9:t=fill:enable='between(t\\,1.0\\,4.1)',
drawbox=x=1345:y=514:w=112:h=7:color=0xE0A62C@0.9:t=fill:enable='between(t\\,1.45\\,4.1)',
drawbox=x=260:y='546-80*min(1\\,(t-1.35)/0.35)+80*min(1\\,max(0\\,(t-4.4)/0.35))':w=195:h=38:color=0x4EB3D3@0.94:t=fill:enable='between(t\\,1.35\\,4.75)',
drawtext=fontfile='$font_file':text='PAYTM':fontcolor=0x102019:fontsize=21:x=283:y='554-80*min(1\\,(t-1.35)/0.35)+80*min(1\\,max(0\\,(t-4.4)/0.35))':enable='between(t\\,1.35\\,4.75)',
drawbox=x=1240:y='463-80*min(1\\,(t-1.8)/0.35)+80*min(1\\,max(0\\,(t-4.55)/0.35))':w=236:h=40:color=0xEC9B30@0.95:t=fill:enable='between(t\\,1.8\\,4.95)',
drawtext=fontfile='$font_file':text='AMAZON':fontcolor=0x18231E:fontsize=22:x=1263:y='472-80*min(1\\,(t-1.8)/0.35)+80*min(1\\,max(0\\,(t-4.55)/0.35))':enable='between(t\\,1.8\\,4.95)',
drawbox=x=710:y='369-80*min(1\\,(t-2.15)/0.35)+80*min(1\\,max(0\\,(t-4.7)/0.35))':w=214:h=40:color=0x4D83DD@0.95:t=fill:enable='between(t\\,2.15\\,5.1)',
drawtext=fontfile='$font_file':text='GOOGLE':fontcolor=0x15221D:fontsize=22:x=735:y='378-80*min(1\\,(t-2.15)/0.35)+80*min(1\\,max(0\\,(t-4.7)/0.35))':enable='between(t\\,2.15\\,5.1)',
drawbox=x=970:y='615-80*min(1\\,(t-2.55)/0.35)+80*min(1\\,max(0\\,(t-4.85)/0.35))':w=225:h=39:color=0x6DBE77@0.95:t=fill:enable='between(t\\,2.55\\,5.4)',
drawtext=fontfile='$font_file':text='MICROSOFT':fontcolor=0x17231E:fontsize=19:x=991:y='624-80*min(1\\,(t-2.55)/0.35)+80*min(1\\,max(0\\,(t-4.85)/0.35))':enable='between(t\\,2.55\\,5.4)',
drawbox=x=330:y='645-80*min(1\\,(t-4.95)/0.35)':w=235:h=42:color=0x4B82D2@0.95:t=fill:enable='between(t\\,4.95\\,8.9)',
drawtext=fontfile='$font_file':text='RAZORPAY':fontcolor=0xF6F1E5:fontsize=21:x=352:y='655-80*min(1\\,(t-4.95)/0.35)':enable='between(t\\,4.95\\,8.9)',
drawbox=x=1240:y='463-80*min(1\\,(t-5.0)/0.35)':w=236:h=40:color=0xB284E4@0.97:t=fill:enable='between(t\\,5.0\\,8.9)',
drawtext=fontfile='$font_file':text='ZEPTO':fontcolor=0x1B2120:fontsize=22:x=1263:y='472-80*min(1\\,(t-5.0)/0.35)':enable='between(t\\,5.0\\,8.9)',
drawbox=x=710:y='369-80*min(1\\,(t-5.15)/0.35)':w=214:h=40:color=0xD7CE40@0.97:t=fill:enable='between(t\\,5.15\\,8.9)',
drawtext=fontfile='$font_file':text='BLINKIT':fontcolor=0x18231E:fontsize=21:x=735:y='379-80*min(1\\,(t-5.15)/0.35)':enable='between(t\\,5.15\\,8.9)',
drawbox=x=970:y='615-80*min(1\\,(t-5.35)/0.35)':w=225:h=39:color=0xA982F0@0.97:t=fill:enable='between(t\\,5.35\\,8.9)',
drawtext=fontfile='$font_file':text='THREADS':fontcolor=0x18231E:fontsize=19:x=992:y='624-80*min(1\\,(t-5.35)/0.35)':enable='between(t\\,5.35\\,8.9)',
drawbox=x=545:y=474:w=330:h=100:color=0x11362F@0.84:t=fill:enable='gte(t\\,6.1)',
drawbox=x=545:y=474:w=330:h=5:color=0xE2A72E@0.98:t=fill:enable='gte(t\\,6.1)',
drawtext=fontfile='$font_file':text='BUDGET':fontcolor=0xE2A72E:fontsize=22:x=572:y=490:enable='gte(t\\,6.25)',
drawtext=fontfile='$font_file':text='GURUGRAM':fontcolor=0xF8F5EA:fontsize=41:x=571:y=517:borderw=1:bordercolor=0x0E201B:enable='gte(t\\,6.38)',
drawtext=fontfile='$font_file':text='WHAT IS ACTUALLY HAPPENING IN THE CITY':fontcolor=0xDDE8DF:fontsize=13:x=572:y=560:enable='gte(t\\,6.65)',
drawbox=x='mod(180*t+70\\,1920)':y=810:w=24:h=8:color=0xF4C94E@0.9:t=fill:enable='between(t\\,0.5\\,9.8)',
drawbox=x='mod(210*t+650\\,1920)':y=846:w=28:h=8:color=0x4FB8DC@0.9:t=fill:enable='between(t\\,0.5\\,9.8)',
drawbox=x='mod(165*t+1260\\,1920)':y=827:w=20:h=8:color=0xA982F0@0.9:t=fill:enable='between(t\\,0.5\\,9.8)'
" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart \
  -an "$output_file"

echo "Wrote $output_file"
