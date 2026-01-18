#!/usr/bin/env bash
set -euo pipefail

# Generates an 8-second, 30fps test video with 1-second solid color blocks
# and a burned-in timecode + index label for deterministic testing.

OUT="revunk-test-pattern.mp4"
FPS=30
DUR=1

COLORS=(red green blue yellow magenta cyan white black)

FILTERS=""
T=0
IDX=1

for C in "${COLORS[@]}"; do
  FILTERS+="color=c=${C}:s=640x360:d=${DUR},"
  FILTERS+="drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='${IDX} ${C}':x=20:y=20:fontsize=32:fontcolor=white,"
  FILTERS+="drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='%{pts\\:hms}':x=20:y=60:fontsize=24:fontcolor=white"
  FILTERS+="[v${IDX}];"
  ((IDX++))
  ((T+=DUR))
done

CONCAT=""
for i in {1..8}; do CONCAT+="[v${i}]"; done

ffmpeg -y \
  $(for C in "${COLORS[@]}"; do echo "-f lavfi -i color=c=${C}:s=640x360:d=${DUR}"; done) \
  -filter_complex "${FILTERS}${CONCAT}concat=n=8:v=1:a=0,format=yuv420p" \
  -r ${FPS} \
  ${OUT}

echo "Generated ${OUT}"