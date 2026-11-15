#!/bin/bash
# OCR: select a screen region, extract the text and copy it to the clipboard.
# Pipeline: slurp (region) -> grim (screenshot to a /tmp temp file) ->
# tesseract (eng+rus) -> wl-copy -> notify-send.
#
# Usage: ocr.sh [region-geometry]   e.g. ocr.sh "100,100 400x200"
# When a geometry argument is given the interactive slurp selection is
# skipped (useful for testing). Languages can be overridden with OCR_LANGS.

# Export essential environment variables for Wayland/Hyprland
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
if [ -z "$WAYLAND_DISPLAY" ]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$sock" ]; then
      export WAYLAND_DISPLAY=$(basename "$sock")
      break
    fi
  done
  export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
fi
export XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-Hyprland}

OCR_LANGS="${OCR_LANGS:-eng+rus}"
TEMP_IMAGE="/tmp/ocr-region-$$.png"

notify() {
  if command -v notify-send &>/dev/null; then
    notify-send "$1" "$2" 2>/dev/null
  fi
}

fail() {
  notify "OCR" "$1"
  echo "ocr.sh: $1" >&2
  exit 1
}

# Degrade gracefully when a tool of the pipeline is missing.
missing=""
for tool in slurp grim tesseract wl-copy; do
  if ! command -v "$tool" &>/dev/null; then
    missing="${missing}${missing:+, }$tool"
  fi
done
if [ -n "$missing" ]; then
  fail "Missing required tool(s): $missing"
fi

cleanup() {
  rm -f "$TEMP_IMAGE"
}
trap cleanup EXIT

GEOM="${1:-}"
if [ -z "$GEOM" ]; then
  # Ensure any dangling slurp instance is terminated
  pkill -x slurp 2>/dev/null
  GEOM=$(slurp 2>/dev/null)
  if [ -z "$GEOM" ]; then
    # User aborted the selection — not an error, stay quiet.
    exit 0
  fi
fi

sleep 0.2

if ! grim -g "$GEOM" "$TEMP_IMAGE" 2>/dev/null || [ ! -s "$TEMP_IMAGE" ]; then
  fail "Failed to capture region $GEOM"
fi

TEXT=$(tesseract "$TEMP_IMAGE" - -l "$OCR_LANGS" 2>/dev/null)
# Trim leading/trailing whitespace (tesseract appends a trailing newline).
TEXT=$(printf '%s' "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -z "$TEXT" ]; then
  fail "No text found in the selected region"
fi

printf '%s' "$TEXT" | wl-copy

CHARS=$(printf '%s' "$TEXT" | wc -c)
notify "OCR" "Extracted $CHARS characters, copied to clipboard"

exit 0
