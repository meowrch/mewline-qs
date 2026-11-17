#!/bin/bash
# OCR: select a screen region, extract the text and copy it to the clipboard.
# Wayland pipeline: slurp (region) -> grim -> tesseract -> wl-copy.
# X11 pipeline: slop (region) -> maim -> tesseract -> xclip.
# Both pipelines feed the same tesseract step, so there are no user-visible
# differences between the sessions.
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

SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
if [ -z "$XDG_SESSION_TYPE" ]; then
  if [ -n "$WAYLAND_DISPLAY" ]; then
    SESSION_TYPE="wayland"
  elif [ -n "$DISPLAY" ]; then
    SESSION_TYPE="x11"
  fi
fi

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
if [ "$SESSION_TYPE" = "x11" ]; then
  SELECT_TOOL="slop"
  CAPTURE_TOOL="maim"
  COPY_TOOL="xclip"
else
  SELECT_TOOL="slurp"
  CAPTURE_TOOL="grim"
  COPY_TOOL="wl-copy"
fi
missing=""
for tool in "$SELECT_TOOL" "$CAPTURE_TOOL" tesseract "$COPY_TOOL"; do
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
  if [ "$SESSION_TYPE" = "x11" ]; then
    # slop prints "WxH+X+Y" — exactly the geometry maim -g expects.
    GEOM="$(slop -f '%wx%h+%x+%y' 2>/dev/null)"
  else
    # Ensure any dangling slurp instance is terminated
    pkill -x slurp 2>/dev/null
    GEOM=$(slurp 2>/dev/null)
  fi
  if [ -z "$GEOM" ]; then
    # User aborted the selection — not an error, stay quiet.
    exit 0
  fi
fi

sleep 0.2

if [ "$SESSION_TYPE" = "x11" ]; then
  if ! maim -g "$GEOM" "$TEMP_IMAGE" 2>/dev/null || [ ! -s "$TEMP_IMAGE" ]; then
    fail "Failed to capture region $GEOM"
  fi
else
  if ! grim -g "$GEOM" "$TEMP_IMAGE" 2>/dev/null || [ ! -s "$TEMP_IMAGE" ]; then
    fail "Failed to capture region $GEOM"
  fi
fi

TEXT=$(tesseract "$TEMP_IMAGE" - -l "$OCR_LANGS" 2>/dev/null)
# Trim leading/trailing whitespace (tesseract appends a trailing newline).
TEXT=$(printf '%s' "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -z "$TEXT" ]; then
  fail "No text found in the selected region"
fi

if [ "$SESSION_TYPE" = "x11" ]; then
  printf '%s' "$TEXT" | xclip -selection clipboard
else
  printf '%s' "$TEXT" | wl-copy
fi

CHARS=$(printf '%s' "$TEXT" | wc -c)
notify "OCR" "Extracted $CHARS characters, copied to clipboard"

exit 0
