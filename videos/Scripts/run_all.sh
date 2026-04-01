#!/bin/bash
# Run the full video pipeline: generate comparison videos, then compress them
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========== Step 1: Generating videos =========="
bash "$SCRIPT_DIR/make_videos.sh"

echo ""
echo "========== Step 2: Compressing videos =========="
bash "$SCRIPT_DIR/compress_videos.sh"

echo ""
echo "========== Done =========="
