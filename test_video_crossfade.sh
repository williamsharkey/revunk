#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$ROOT_DIR/core"
BIN="$CORE_DIR/.build/debug/revunk"

if [ ! -x "$BIN" ]; then
  echo "revunk binary not found. Run ./test.sh first."
  exit 1
fi

export PATH="$CORE_DIR/.build/debug:$PATH"

SRC="$ROOT_DIR/secret-world.mp4"
if [ ! -f "$SRC" ]; then
  echo "Missing source video: $SRC"
  exit 1
fi

TEST_FILE="/tmp/test-video-crossfade.revunk.txt"
OUT_FILE="/tmp/test-video-crossfade.revunk.out.mp4"
rm -f "$OUT_FILE"

cat > "$TEST_FILE" <<EOF
# Video crossfade test
# Expect visible dissolves between beats

video: ../secret-world.mp4
downbeat: 0
bpm: 120

audio-crossfade:
  audio 0.06

crossfade:
  video 0.08

export:
  1x2 2x3 3x4
  4x3 3x2 2x1
EOF

echo "Running video crossfade export"
revunk export "$TEST_FILE"

if [ ! -f "$OUT_FILE" ]; then
  echo "❌ Video crossfade export failed"
  exit 1
fi

echo "✅ Video crossfade export succeeded"
echo "Opening output for visual inspection"
open "$OUT_FILE"
