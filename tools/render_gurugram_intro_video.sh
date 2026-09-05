#!/usr/bin/env bash

# Renders the silent social cut of the in-app Gurugram title sequence.
# Add music separately against the timing notes in CityIntroScreen.audioCues.
set -euo pipefail

workspace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="$workspace_dir/exports"
output_file="$output_dir/gurugram-city-intro.mp4"
font_file="/System/Library/Fonts/Supplemental/Verdana.ttf"

mkdir -p "$output_dir"

ffmpeg -y \
  -f lavfi -i "color=c=0x0D1A17:s=1920x1080:r=30:d=10" \
  -vf "
drawgrid=w=160:h=120:t=1:c=0x4E786A@0.20,
drawbox=x=0:y=746:w=1920:h=112:color=0x07100D@1:t=fill,
drawbox=x=0:y=801:w=1920:h=2:color=0xBFA85F@0.55:t=fill,
drawbox=x='mod(270*t+80\\,1920)':y=786:w=20:h=7:color=0xF1D17A:t=fill:enable='between(t\\,0.3\\,9.4)',
drawbox=x='mod(270*t+590\\,1920)':y=825:w=24:h=7:color=0x78D0E8:t=fill:enable='between(t\\,0.3\\,9.4)',
drawbox=x='mod(270*t+1220\\,1920)':y=786:w=18:h=7:color=0xCA93F3:t=fill:enable='between(t\\,0.3\\,9.4)',
drawbox=x=175:y=348:w=265:h=344:color=0x172B26@0.98:t=fill:enable='gte(t\\,0.7)',
drawbox=x=175:y=382:w=265:h=34:color=0x4F86E8:t=fill:enable='gte(t\\,0.9)',
drawtext=fontfile='$font_file':text='GOOGLE':fontcolor=0x0D1A17:fontsize=21:x=196:y=388:enable='gte(t\\,0.9)',
drawbox=x=1238:y=240:w=354:h=452:color=0x172B26@0.98:t=fill:enable='gte(t\\,1.05)',
drawbox=x=1238:y=277:w=354:h=34:color=0xE69A32:t=fill:enable='gte(t\\,1.22)',
drawtext=fontfile='$font_file':text='AMAZON':fontcolor=0x0D1A17:fontsize=21:x=1260:y=283:enable='gte(t\\,1.22)',
drawbox=x=743:y=416:w=262:h=276:color=0x172B26@0.98:t=fill:enable='gte(t\\,1.36)',
drawbox=x=743:y=449:w=262:h=34:color=0x6CBF72:t=fill:enable='gte(t\\,1.51)',
drawtext=fontfile='$font_file':text='MICROSOFT':fontcolor=0x0D1A17:fontsize=18:x=759:y=456:enable='gte(t\\,1.51)',
drawbox=x=1422:y=501:w=262:h=191:color=0x172B26@0.98:t=fill:enable='gte(t\\,1.7)',
drawbox=x=1422:y=534:w=262:h=34:color=0xA982F0:t=fill:enable='gte(t\\,1.84)',
drawtext=fontfile='$font_file':text='THREADS':fontcolor=0x0D1A17:fontsize=19:x=1441:y=540:enable='gte(t\\,1.84)',
drawbox=x=180:y=589:w=270:h=103:color=0x172B26@0.98:t=fill:enable='gte(t\\,2.0)',
drawbox=x=180:y=619:w=270:h=34:color=0x4FB8DC:t=fill:enable='gte(t\\,2.13)',
drawtext=fontfile='$font_file':text='PAYTM':fontcolor=0x0D1A17:fontsize=21:x=202:y=625:enable='gte(t\\,2.13)',
drawbox=x=1030:y=505:w=332:h=187:color=0x172B26@0.98:t=fill:enable='gte(t\\,2.28)',
drawbox=x=1030:y=538:w=332:h=34:color=0x4B82D2:t=fill:enable='gte(t\\,2.41)',
drawtext=fontfile='$font_file':text='RAZORPAY':fontcolor=0x0D1A17:fontsize=20:x=1052:y=544:enable='gte(t\\,2.41)',
drawbox=x=478:y=608:w=238:h=84:color=0x172B26@0.98:t=fill:enable='gte(t\\,2.56)',
drawbox=x=478:y=633:w=238:h=34:color=0xB284E4:t=fill:enable='gte(t\\,2.68)',
drawtext=fontfile='$font_file':text='ZEPTO':fontcolor=0x0D1A17:fontsize=21:x=499:y=639:enable='gte(t\\,2.68)',
drawbox=x=1470:y=633:w=210:h=59:color=0x172B26@0.98:t=fill:enable='gte(t\\,2.82)',
drawbox=x=1470:y=650:w=210:h=34:color=0xDCC94A:t=fill:enable='gte(t\\,2.94)',
drawtext=fontfile='$font_file':text='BLINKIT':fontcolor=0x0D1A17:fontsize=19:x=1487:y=656:enable='gte(t\\,2.94)',
drawbox=x=520:y=234:w=212:h=458:color=0x172B26@0.98:t=fill:enable='gte(t\\,3.08)',
drawbox=x=520:y=270:w=212:h=34:color=0xE87470:t=fill:enable='gte(t\\,3.2)',
drawtext=fontfile='$font_file':text='AIRBNB':fontcolor=0x0D1A17:fontsize=19:x=540:y=276:enable='gte(t\\,3.2)',
drawbox=x='mod(65*t+310\\,1920)':y='mod(55*t+80\\,650)':w=3:h=3:color=0xC9E4D5@0.8:t=fill,
drawbox=x='mod(49*t+970\\,1920)':y='mod(47*t+200\\,650)':w=2:h=2:color=0xC9E4D5@0.7:t=fill,
drawbox=x='mod(73*t+1500\\,1920)':y='mod(39*t+350\\,650)':w=3:h=3:color=0xC9E4D5@0.65:t=fill,
drawbox=x=72:y=61:w=406:h=1:color=0xBFA85F@0.8:t=fill:enable='gte(t\\,5.95)',
drawtext=fontfile='$font_file':text='BUDGET':fontcolor=0xD7B568:fontsize=30:x=72:y=688:enable='gte(t\\,6.05)',
drawtext=fontfile='$font_file':text='Gurugram':fontcolor=0xF7F4ED:fontsize=98:x=72:y=723:enable='gte(t\\,6.22)',
drawtext=fontfile='$font_file':text='A CITY THAT NEVER CLOCKS OUT.':fontcolor=0xC9D8C9:fontsize=25:x=76:y=844:enable='gte(t\\,6.45)',
drawtext=fontfile='$font_file':text='NH-48  //  CYBER CITY':fontcolor=0xC9D8C9:fontsize=22:x=72:y=82:enable='gte(t\\,0.15)',
drawtext=fontfile='$font_file':text='GURUGRAM, INDIA':fontcolor=0xC9D8C9:fontsize=20:x=1550:y=100:enable='gte(t\\,3.1)'
" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart \
  -an "$output_file"

echo "Wrote $output_file"
