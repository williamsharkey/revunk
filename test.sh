#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$ROOT_DIR/core"
BIN="$CORE_DIR/.build/debug/revunk"


# -------------------------------
# 1. Build
# -------------------------------

echo "[1/5] Building revunk"
cd "$CORE_DIR"
swift build
export PATH="$CORE_DIR/.build/debug:$PATH"
cd "$ROOT_DIR"

if [ ! -x "$BIN" ]; then
  echo "revunk binary not found at $BIN"
  exit 1
fi


# -------------------------------
# 2. Basic export sanity test
# -------------------------------

echo "[2/5] Basic export test"

BASIC_FILE="/tmp/test-basic.revunk.txt"
BASIC_OUT="/tmp/test-basic.revunk.out.mp4"
rm -f "$BASIC_OUT"

cat > "$BASIC_FILE" <<EOF
video: secret-world.mp4
downbeat: 0
bpm: 120
export:
  1 2 3 4
EOF

revunk export "$BASIC_FILE"

if [ ! -f "$BASIC_OUT" ]; then
  echo "❌ Basic export failed"
  exit 1
fi


# -------------------------------
# 3. Reverse sequencing test
# -------------------------------

echo "[3/5] Reverse sequencing test"

REV_FILE="/tmp/test-reverse.revunk.txt"
REV_OUT="/tmp/test-reverse.revunk.out.mp4"
rm -f "$REV_OUT"

cat > "$REV_FILE" <<EOF
video: secret-world.mp4
downbeat: 0
bpm: 120
export:
  1 2 3 4
  4 3 2 1
EOF

revunk export "$REV_FILE"

if [ ! -f "$REV_OUT" ]; then
  echo "❌ Reverse export failed"
  exit 1
fi


# -------------------------------
# 4. Video crossfade test (1x2 syntax)
# -------------------------------

echo "[4/5] Video crossfade test (1x2 syntax)"

XFADE_FILE="/tmp/test-video-crossfade.revunk.txt"
XFADE_OUT="/tmp/test-video-crossfade.revunk.out.mp4"
rm -f "$XFADE_OUT"

cat > "$XFADE_FILE" <<EOF
video: secret-world.mp4
downbeat: 0
bpm: 120

crossfade:
  video 0.08

export:
  1x2 2x3 3x4
  4x3 3x2 2x1
EOF

revunk export "$XFADE_FILE"

if [ ! -f "$XFADE_OUT" ]; then
  echo "❌ Video crossfade export failed"
  exit 1
fi


# -------------------------------
# 5. Open final output for inspection
# -------------------------------

echo "[5/5] Opening final output"
open "$XFADE_OUT"

echo "✅ All tests completed"
