#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_ASSETS="$ROOT_DIR/test_assets"
OUT_TXT="/tmp/revunk-blocks-test.revunk.txt"
OUT_MP4="/tmp/revunk-blocks-test.revunk.out.mp4"

# -------------------------------
# 1. Generate deterministic test video
# -------------------------------

echo "[1/4] Generating deterministic color-block test video"
cd "$TEST_ASSETS"
./generate_test_video.sh
cd "$ROOT_DIR"

# -------------------------------
# 2. Write revunk test file
# -------------------------------

echo "[2/4] Writing revunk crossfade test file"
cat > "$OUT_TXT" <<EOF
video: test_assets/revunk-test-pattern.mp4
downbeat: 0
bpm: 60

crossfade:
  video 0.5

export:
  1x2 2x3 3x4 4x5
EOF

# -------------------------------
# 3. Run revunk export
# -------------------------------

echo "[3/4] Running revunk export"
"$ROOT_DIR/core/.build/debug/revunk" export "$OUT_TXT"

if [ ! -f "$OUT_MP4" ]; then
  echo "❌ Export failed: output file not found"
  exit 1
fi

# -------------------------------
# 4. Open result for inspection
# -------------------------------

echo "[4/4] Opening output video"
open "$OUT_MP4"

echo "✅ Blocks crossfade test complete"
