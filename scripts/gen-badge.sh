#!/bin/sh
# gen-badge.sh — regenerate docs/best-viewed-in-northstar.gif from the Nordstjernen badge.
set -eu

SRC="${1:-../nordstjernen/docs/best-viewed-in-nordstjernen.gif}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/docs/best-viewed-in-northstar.gif"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

case "$SRC" in
  /*) : ;;
  *) SRC="$REPO/$SRC" ;;
esac

cd "$WORK"
magick "$SRC" -coalesce frame_%02d.png

magick -size 180x63 xc:white -fill black -draw "rectangle 56,36 172,53" keep.png
magick frame_00.png -crop '117x1+56+35' +repage -blur 0x1.5 refT.png
magick frame_00.png -crop '117x1+56+54' +repage -blur 0x1.5 refB.png
magick refT.png refB.png -append -filter triangle -resize '117x18!' -blur 0x0.8 core.png
magick -size 180x63 xc:black core.png -geometry +56+36 -composite fill.png
magick keep.png -negate -blur 0x2 mask.png

TW=$(magick -font DejaVu-Sans-Condensed-Bold -pointsize 15 label:"NORTHSTAR" -format %w info:)
TX=$(( (56 + 172 - TW) / 2 ))

for f in frame_*.png; do
  magick "$f" fill.png mask.png -composite \
    -font DejaVu-Sans-Condensed-Bold -pointsize 15 \
    -fill 'rgb(215,182,105)' -annotate +$TX+50 "NORTHSTAR" "$f"
done

magick -delay 10 -loop 0 frame_*.png -colors 64 -layers Optimize "$OUT"
echo "wrote $OUT"
