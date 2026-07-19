#!/bin/sh
# gen-splash.sh — regenerate src/about_splash_png.h from the Nordstjernen splash animation.
set -eu

SRC="${1:-../nordstjernen/src/about_splash_gif.h}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/src/about_splash_png.h"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

case "$SRC" in
  /*) : ;;
  *) SRC="$REPO/$SRC" ;;
esac

if [ "${SRC##*.}" = "h" ]; then
  python3 - "$SRC" <<'EOF'
import re, sys, base64
src = open(sys.argv[1]).read()
b64 = ''.join(re.findall(r'"([A-Za-z0-9+/=]+)"', src))
open('source.img', 'wb').write(base64.b64decode(b64))
EOF
else
  cp "$SRC" source.img
fi

magick 'source.img[0]' -coalesce frame.png

magick frame.png -fx "(b-r)<0.047?1:0" -colorspace gray notwater.png
magick -size 940x320 xc:black -fill white \
  -draw "rectangle 68,234 596,266 rectangle 68,264 520,296" \
  -fill black -draw "rectangle 205,282 236,300" rects.png
magick -size 940x320 xc:white -fill black -draw "rectangle 66,233 604,297" \
  -fill white -draw "rectangle 204,286 237,300" \
  -draw "rectangle 593,246 940,320" keepmask.png
magick frame.png keepmask.png -alpha off -compose CopyOpacity -composite hole.png
magick hole.png -crop '940x100+0+220' +repage band.png
magick band.png -channel RGBA -filter box -resize '47x5!' -filter triangle -resize '940x100!' fA.png
magick band.png -channel RGBA -filter box -resize '12x2!' -filter triangle -resize '940x100!' fB.png
magick band.png -channel RGBA -filter box -resize '3x1!' -filter triangle -resize '940x100!' fC.png
magick fC.png fB.png -compose over -composite f1.png
magick f1.png fA.png -compose over -composite bandfield.png
magick -size 940x320 xc:black \( bandfield.png -alpha off \) -geometry +0+220 -composite field.png

magick frame.png -crop 190x66+660+232 +repage tile.png
magick tile.png -blur 0x10 tile_low.png
magick tile.png tile_low.png -fx "u-v+0.5" tile_hp.png
magick tile_hp.png \( tile_hp.png -flop \) \( tile_hp.png \) +append \
  -crop '541x66+0+0' +repage hp_strip.png
magick -size 940x320 xc:'gray(50%)' hp_strip.png -geometry +66+233 \
  -compose over -composite hp_full.png
magick field.png hp_full.png -fx "u+v-0.5" textured.png
magick keepmask.png -negate -blur 0x1.5 holemask.png
magick frame.png textured.png holemask.png -composite nocaption.png

magick -size 940x320 xc:white -fill black -draw "rectangle 464,54 654,102" \
  -fill white -draw "rectangle 545,40 600,61" \
  -draw "rectangle 600,86 605,102" \
  -draw "rectangle 642,42 662,58" vkeep.png
magick nocaption.png -crop '3x49+459+54' +repage -resize '1x49!' colL.png
magick nocaption.png -crop '3x49+655+54' +repage -resize '1x49!' colR.png
magick colL.png colR.png +append -filter triangle -resize '191x49!' skylerp.png
magick -size 940x320 xc:none skylerp.png -geometry +464+54 -composite skylayer.png
magick vkeep.png -negate -blur 0x1.5 vholemask.png
magick nocaption.png skylayer.png vholemask.png -composite noversion.png

VW=$(magick -font DejaVu-Sans -pointsize 56 label:"1.0.2" -format "%w" info:)
VX=$((650 - VW))
magick noversion.png \
  \( -size 940x320 xc:none -font DejaVu-Sans -pointsize 56 -fill white \
     -annotate +$VX+98 "1.0.2" -blur 0x2 -channel A -evaluate multiply 1.2 +channel \) \
  -compose over -composite \
  \( -size 940x320 xc:none -font DejaVu-Sans -pointsize 56 \
     -fill 'rgb(196,104,8)' -annotate +$VX+98 "1.0.2" \) \
  -compose over -composite versioned.png

magick versioned.png \
  \( -size 940x320 xc:none -font DejaVu-Sans -pointsize 20 -fill white \
     -annotate +78+272 "Open source edition" -blur 0x2.2 \
     -channel A -evaluate multiply 2 +channel \) \
  -compose over -composite \
  \( -size 940x320 xc:none -font DejaVu-Sans -pointsize 20 -fill black \
     -annotate +78+272 "Open source edition" \) \
  -compose over -composite splash.png

magick splash.png -dither FloydSteinberg -colors 256 png8:splash_final.png

python3 - splash_final.png "$OUT" <<'EOF'
import sys, base64
data = base64.b64encode(open(sys.argv[1], 'rb').read()).decode()
lines = [data[i:i+100] for i in range(0, len(data), 100)]
body = '\n'.join('    "%s"' % l for l in lines)
open(sys.argv[2], 'w').write(
"""/* about_splash_png.h — the about:start splash image, embedded.
 * Copyright 2026 Andreas Røsdal
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
#ifndef NS_ABOUT_SPLASH_PNG_H
#define NS_ABOUT_SPLASH_PNG_H

static const char about_splash_png_b64[] =
""" + body + """;

#endif
""")
EOF

echo "wrote $OUT"
