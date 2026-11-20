#!/bin/bash

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

DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$DIR"

LOG="/tmp/quickshell-record.log"
# Authoritative recorder handle: the script writes the recorder PID here on
# start and removes it on exit. Detection (RecorderService) checks this
# file instead of matching process command lines, which is immune to
# false positives from any process that merely mentions the recorder.
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/quickshell_recording.pid"

cleanup() {
  rm -f "$PID_FILE"
}
trap cleanup EXIT
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
FILENAME="$DIR/Recording-${TIMESTAMP}.mkv"

# If already running, stop it cleanly. The PID file is authoritative;
# the pattern match is only a fallback for a lost file. The recorder
# depends on the session: wf-recorder (Wayland) or ffmpeg x11grab (X11).
if [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "recorder $(cat "$PID_FILE") is running, stopping it..." >>"$LOG"
  kill -INT "$(cat "$PID_FILE")"
  exit 0
fi
if [ "$SESSION_TYPE" = "x11" ]; then
  if pgrep -f "ffmpeg.* -f x11grab" >/dev/null 2>&1; then
    echo "ffmpeg (x11grab) is running, stopping it..." >>"$LOG"
    pkill -INT -f "ffmpeg.* -f x11grab"
    exit 0
  fi
elif pidof wf-recorder >/dev/null 2>&1; then
  echo "wf-recorder is running, stopping it..." >>"$LOG"
  killall -SIGINT wf-recorder
  exit 0
fi

echo "--- Record started at $(date) ---" >>"$LOG"

AUDIO_SOURCE=""
REGION=""

while getopts "sr" opt; do
  case "$opt" in
  s)
    if command -v pactl >/dev/null 2>&1; then
      default_sink=$(pactl get-default-sink 2>/dev/null)
      if [ -n "$default_sink" ]; then
        AUDIO_SOURCE="${default_sink}.monitor"
      fi
    fi
    ;;
  r)
    if [ "$SESSION_TYPE" = "x11" ]; then
      # slop prints "WxH+X+Y" — the same shape slurp produces.
      GEOM="$(slop -f '%wx%h+%x+%y' 2>/dev/null)"
    else
      GEOM=$(slurp 2>/dev/null)
    fi
    if [ -z "$GEOM" ]; then
      echo "Region selection canceled" >>"$LOG"
      exit 0
    fi
    REGION="$GEOM"
    ;;
  *)
    ;;
  esac
done

# ------------------------- X11: ffmpeg x11grab --------------------------
# The whole X display (or a slop region) is recorded by ffmpeg; wf-recorder
# is wlroots-only and does not exist on bspwm. Audio comes from the same
# pulse monitor source as on Wayland.
if [ "$SESSION_TYPE" = "x11" ]; then
  echo "--- Record started at $(date) (x11grab) ---" >>"$LOG"
  CMD=("ffmpeg" "-y" "-f" "x11grab" "-framerate" "30")
  if [ -n "$REGION" ]; then
    SIZE="${REGION%%+*}"
    REST="${REGION#*+}"
    OFFX="${REST%%+*}"
    OFFY="${REST##*+}"
    CMD+=("-video_size" "$SIZE" "-i" "${DISPLAY:-:0}+${OFFX},${OFFY}")
  else
    DIMS=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2; exit}')
    CMD+=("-video_size" "${DIMS:-1920x1080}" "-i" "${DISPLAY:-:0}")
  fi
  CMD+=("-c:v" "libx264" "-preset" "veryfast" "-pix_fmt" "yuv420p")
  if [ -n "$AUDIO_SOURCE" ]; then
    pactl set-source-mute "$AUDIO_SOURCE" false 2>/dev/null || true
    CMD+=("-f" "pulse" "-i" "$AUDIO_SOURCE")
  fi
  echo "Recording display: ${DISPLAY:-:0} | Region: $REGION | Audio: $AUDIO_SOURCE | Output: $FILENAME" >>"$LOG"
  "${CMD[@]}" "$FILENAME" >>"$LOG" 2>&1 &
  echo "$!" >"$PID_FILE"
  wait "$!"
  qs ipc call osd showMessage "Recording" "Saved" "record-icon" 2>/dev/null || true
  exit 0
fi

MONITOR=""
if [ -n "$NIRI_SOCKET" ]; then
  # niri has no hyprctl: focused output first, then any connected output
  MONITOR=$(niri msg --json focused-output 2>/dev/null | jq -r '.Ok.FocusedOutput.name // empty' 2>/dev/null)
  if [ -z "$MONITOR" ]; then
    MONITOR=$(niri msg --json outputs 2>/dev/null | jq -r '.Ok.Outputs | keys[0] // empty' 2>/dev/null)
  fi
fi
if [ -z "$MONITOR" ]; then
  MONITOR=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor' 2>/dev/null)
fi
if [ -z "$MONITOR" ] || [ "$MONITOR" = "null" ]; then
  MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null)
fi

echo "Recording monitor: $MONITOR | Region: $REGION | Audio: $AUDIO_SOURCE | Output: $FILENAME" >>"$LOG"

CMD=("wf-recorder" "-x" "yuv420p" "-p" "color_range=tv" "-p" "color_primaries=bt709" "-p" "color_trc=bt709" "-p" "colorspace=bt709" "-c" "libx264" "-f" "$FILENAME")

if [ -n "$REGION" ]; then
  CMD+=("-g" "$REGION")
elif [ -n "$MONITOR" ]; then
  CMD+=("-o" "$MONITOR")
fi

if [ -n "$AUDIO_SOURCE" ]; then
  pactl set-source-mute "$AUDIO_SOURCE" false 2>/dev/null || true
  CMD+=("--audio=$AUDIO_SOURCE")
fi

"${CMD[@]}" >>"$LOG" 2>&1 &
echo "$!" >"$PID_FILE"
wait "$!"

qs ipc call osd showMessage "Recording" "Saved" "record-icon" 2>/dev/null || true
