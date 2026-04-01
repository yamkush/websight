#!/bin/bash
# Generate diagonal-split and side-by-side comparison videos
# from raw_videos/{Scene}/ss.mp4 and raw_videos/{Scene}/combo.mp4
#
# Output:
#   ready_videos/{Scene_name}_Diagonal.mp4  — diagonal split with magenta line
#   ready_videos/{Scene_name}.mp4           — side-by-side

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VIDEOS_DIR="$(dirname "$SCRIPT_DIR")"
RAW_DIR="$VIDEOS_DIR/raw_videos"
OUT_DIR="$VIDEOS_DIR/ready_videos"

mkdir -p "$OUT_DIR"

FONT="fontsize=72:fontcolor=white:borderw=3:bordercolor=black"

# Generate mask and line overlay images (once per resolution)
generate_mask_and_line() {
    local w=$1 h=$2 mask_path=$3 line_path=$4
    python3 -c "
from PIL import Image, ImageDraw
import numpy as np
W, H = ${w}, ${h}
mask = np.zeros((H, W), dtype=np.uint8)
for y in range(H):
    for x in range(W):
        if x + y > W:
            mask[y, x] = 255
Image.fromarray(mask, 'L').save('${mask_path}')
line = Image.new('RGBA', (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(line)
draw.line([(W, 0), (0, H)], fill=(255, 0, 255, 255), width=4)
line.save('${line_path}')
"
}

for scene_dir in "$RAW_DIR"/*/; do
    [ -d "$scene_dir" ] || continue

    scene_name="$(basename "$scene_dir")"
    [ "$scene_name" = "test" ] && continue

    safe_name="${scene_name// /_}"

    ss="$scene_dir/ss.mp4"
    combo="$scene_dir/combo.mp4"

    if [ ! -f "$ss" ] || [ ! -f "$combo" ]; then
        echo "Skipping $scene_name — missing ss.mp4 or combo.mp4"
        continue
    fi

    echo "=== Processing: $scene_name ==="

    W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$ss")
    H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$ss")

    MASK_PATH="/tmp/diag_mask_${W}x${H}.png"
    LINE_PATH="/tmp/diag_line_${W}x${H}.png"
    if [ ! -f "$MASK_PATH" ] || [ ! -f "$LINE_PATH" ]; then
        echo "  Generating mask and line images (${W}x${H})..."
        generate_mask_and_line "$W" "$H" "$MASK_PATH" "$LINE_PATH"
    fi

    # --- 1. Diagonal split video ---
    # combo (Ours) above diagonal, ss (SplitSum) below diagonal
    echo "  Creating diagonal video..."
    ffmpeg -y -i "$combo" -i "$ss" -i "$MASK_PATH" -i "$LINE_PATH" -filter_complex "
        [2:v]format=gray[mask];
        [0:v][1:v][mask]maskedmerge[blended];
        [blended][3:v]overlay=format=auto,
        drawtext=text='Ours':x=20:y=20:${FONT},
        drawtext=text='SplitSum':x=w-20-tw:y=h-20-th:${FONT}
    " -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -an \
        "$OUT_DIR/${safe_name}_Diagonal.mp4"
    echo "  Diagonal done: ${safe_name}_Diagonal.mp4"

    # --- 2. Side-by-side video ---
    # combo (Ours) on left, ss (SplitSum) on right
    echo "  Creating side-by-side video..."
    ffmpeg -y -i "$combo" -i "$ss" -filter_complex "
        [0:v]drawtext=text='Ours':x=20:y=20:${FONT}[left];
        [1:v]drawtext=text='SplitSum':x=20:y=20:${FONT}[right];
        [left][right]hstack=inputs=2
    " -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -an \
        "$OUT_DIR/${safe_name}.mp4"
    echo "  Side-by-side done: ${safe_name}.mp4"
done

echo ""
echo "All videos generated in: $OUT_DIR"
