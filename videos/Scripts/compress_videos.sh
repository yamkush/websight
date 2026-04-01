#!/bin/bash
# Compress videos from ready_videos/ into compressed_videos/
# Targets web-friendly sizes with h264, crf 28, scaled to 1080p max

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIDEOS_DIR="$(dirname "$SCRIPT_DIR")"
IN_DIR="$VIDEOS_DIR/ready_videos"
OUT_DIR="$VIDEOS_DIR/compressed_videos"

mkdir -p "$OUT_DIR"

for video in "$IN_DIR"/*.mp4; do
    [ -f "$video" ] || continue

    name="$(basename "$video")"
    echo "=== Compressing: $name ==="

    ffmpeg -y -i "$video" \
        -vf "scale='min(1080,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease" \
        -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -an \
        "$OUT_DIR/$name"

    orig_size=$(stat -f%z "$video")
    comp_size=$(stat -f%z "$OUT_DIR/$name")
    ratio=$((100 * comp_size / orig_size))
    echo "  $name: $(( orig_size / 1048576 ))MB → $(( comp_size / 1048576 ))MB (${ratio}%)"
done

echo ""
echo "All compressed videos in: $OUT_DIR"
