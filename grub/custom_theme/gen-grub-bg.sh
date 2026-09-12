#!/bin/bash

SCRIPT_DIR="/usr/share/grub/themes/custom_theme"

# Configuration variables
INPUT_BG="$SCRIPT_DIR/background_original.jpg"
MASK="$SCRIPT_DIR/mask.png"
BOARD="$SCRIPT_DIR/window.png"
OUTPUT="$SCRIPT_DIR/background.jpg"

# 1. Safety Check: Ensure the background actually exists before processing
if [ ! -f "$INPUT_BG" ]; then
    echo "Error: $INPUT_BG not found. Exiting."
    exit 1
fi

echo "Generating $OUTPUT..."

# 2. Version Check: Support both ImageMagick v7 (magick) and v6 (convert)
if command -v magick >/dev/null 2>&1; then
    magick "$INPUT_BG" \
      \( -clone 0 -blur 0x15 -fill black -colorize 40% \) \
      "$MASK" -composite \
      "$BOARD" -composite \
      "$OUTPUT"
else
    convert "$INPUT_BG" \
      \( -clone 0 -blur 0x15 -fill black -colorize 40% \) \
      "$MASK" -composite \
      "$BOARD" -composite \
      "$OUTPUT"
fi
  
echo "$OUTPUT updated successfully."
update-grub