#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$ROOT_DIR/core"

cd "$CORE_DIR"
export PATH="$CORE_DIR/.build/debug:$PATH"

if [ ! -x "$CORE_DIR/.build/debug/revunk" ]; then
  echo "revunk binary not found; run ./test.sh first"
  exit 1
fi

SRC="$ROOT_DIR/secret-world.mp4"
if [ ! -f "$SRC" ]; then
  echo "Missing source video: $SRC"
  exit 1
fi

TEST_FILE="/tmp/test-reverse.revunk.txt"

cat > "$TEST_FILE" <<EOF
# Reverse-style sequencing test
# First play beats forward, then backward

video: ../secret-world.mp4
downbeat: 0
bpm: 120
export:
  1 2 3 4 5 6 7 8
  8 7 6 5 4 3 2 1
EOF

OUT_FILE="/tmp/test-reverse.revunk.out.mp4"
rm -f "$OUT_FILE"

echo "Running reverse-sequence export"
revunk export "$TEST_FILE"

if [ ! -f "$OUT_FILE" ]; then
  echo "Reverse export failed: output file not found"
  exit 1
fi

echo "✅ Reverse sequencing export succeeded: $OUT_FILE"
echo "Opening video for visual verification"
open "$OUT_FILE"
