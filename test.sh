#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$ROOT_DIR/core"

echo "[1/4] Building revunk"
cd "$CORE_DIR"
swift package clean
swift build

BIN="$CORE_DIR/.build/debug/revunk"
if [ ! -x "$BIN" ]; then
  echo "revunk binary not found at $BIN"
  exit 1
fi

export PATH="$CORE_DIR/.build/debug:$PATH"

echo "[2/4] Checking help output"
# revunk prints usage and exits non-zero when called with --help; allow this
revunk --help >/dev/null || true

echo "[3/4] Creating test revunk file"
TEST_FILE="/tmp/test.revunk.txt"
cat > "$TEST_FILE" <<EOF
video: ../secret-world.mp4
downbeat: 0
bpm: 120
export:
  1 2 3 4
EOF

if [ ! -f "$ROOT_DIR/secret-world.mp4" ]; then
  echo "Missing source video: $ROOT_DIR/secret-world.mp4"
  exit 1
fi

echo "[4/4] Running export"
revunk export "$TEST_FILE"

OUT_FILE="/tmp/test.revunk.out.mp4"
if [ ! -f "$OUT_FILE" ]; then
  echo "Export failed: output file not found"
  exit 1
fi

echo "✅ Export succeeded: $OUT_FILE"
