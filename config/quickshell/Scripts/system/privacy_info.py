#!/usr/bin/env python3
"""Privacy state probe for the mewline-qs shell.

Prints one JSON document:
{"cam": bool, "mic": bool, "screen": bool, "loc": bool,
 "mic_apps": [...], "cam_apps": [...], "screen_apps": [...], "loc_apps": [...]}

Detection logic is a port of the mewline privacy service (meowrch):
  - camera: any process holding an open /dev/video* fd
  - microphone: PipeWire Audio/Source running + Stream/Input/Audio consumers
  - screen share: xdph-streaming / gsr-default / game capture nodes or
    wf-recorder / wl-screenrec processes
  - location: geoclue running
"""

import json
import os
import subprocess
import sys


def get_process_name(pid: str) -> str:
    try:
        with open(f"/proc/{pid}/comm") as f:
            return f.read().strip()
    except Exception:
        return f"pid:{pid}"


def detect_camera() -> tuple[bool, list[str]]:
    cam = False
    apps: list[str] = []
    try:
        for pid in os.listdir("/proc"):
            if not pid.isdigit():
                continue
            fd_dir = f"/proc/{pid}/fd"
            if not os.access(fd_dir, os.R_OK):
                continue
            try:
                for fd in os.listdir(fd_dir):
                    try:
                        if os.readlink(f"{fd_dir}/{fd}").startswith("/dev/video"):
                            cam = True
                            name = get_process_name(pid)
                            if name not in apps:
                                apps.append(name)
                            break
                    except OSError:
                        continue
            except OSError:
                continue
    except Exception:
        pass
    return cam, apps


def detect_pw_nodes() -> tuple[bool, list[str], bool, list[str]]:
    mic = False
    mic_apps: list[str] = []
    screen = False
    screen_apps: list[str] = []
    try:
        out = subprocess.check_output(
            ["pw-dump"], stderr=subprocess.DEVNULL, text=True, timeout=2
        )
        nodes = json.loads(out)
    except Exception:
        return mic, mic_apps, screen, screen_apps

    # A microphone counts as in-use when any source is running.
    for node in nodes:
        if node.get("type") != "PipeWire:Interface:Node":
            continue
        info = node.get("info", {})
        state = info.get("state") or node.get("state")
        props = info.get("props", {})
        media_class = str(props.get("media.class", ""))
        if media_class in ("Audio/Source", "Audio/Source/Virtual") and state == "running":
            mic = True
            break

    if mic:
        for node in nodes:
            if node.get("type") != "PipeWire:Interface:Node":
                continue
            info = node.get("info", {})
            state = info.get("state") or node.get("state")
            props = info.get("props", {})
            media_class = str(props.get("media.class", ""))
            app_name = str(
                props.get("application.name", "") or props.get("node.name", "")
            ).strip()
            if (
                media_class == "Stream/Input/Audio"
                and state == "running"
                and app_name
                and app_name.lower() not in {"wireplumber", "pipewire"}
                and app_name not in mic_apps
            ):
                mic_apps.append(app_name)

    # Screen sharing nodes (xdg-desktop-portal-hyprland, gpu-screen-recorder, OBS game capture)
    for node in nodes:
        info = node.get("info", {})
        props = info.get("props", {})
        if not props:
            continue
        media_name = str(props.get("media.name", "")).lower()
        if (
            media_name.startswith("xdph-streaming")
            or media_name.startswith("gsr-default")
            or media_name.startswith("game capture")
        ):
            screen = True
            break

    if screen:
        for node in nodes:
            info = node.get("info", {})
            state = info.get("state") or node.get("state")
            props = info.get("props", {})
            if not props:
                continue
            media_class = str(props.get("media.class", ""))
            media_name = str(props.get("media.name", ""))
            if (
                media_class == "Stream/Input/Video"
                or media_name == "gsr-default_output"
                or media_name == "game capture"
            ) and state == "running":
                app_name = media_name or "Screen Share"
                if app_name not in screen_apps:
                    screen_apps.append(app_name)

    return mic, mic_apps, screen, screen_apps


def detect_recorders(screen_apps: list[str]) -> bool:
    for recorder_bin in ("wf-recorder", "wl-screenrec"):
        try:
            out = subprocess.check_output(
                ["pgrep", "-x", recorder_bin],
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=1,
            ).strip()
            if out:
                if recorder_bin not in screen_apps:
                    screen_apps.append(recorder_bin)
                return True
        except Exception:
            continue
    return False


def detect_location() -> tuple[bool, list[str]]:
    try:
        out = subprocess.check_output(
            ["pgrep", "-f", "geoclue"], stderr=subprocess.DEVNULL, text=True, timeout=1
        ).strip()
        if out:
            return True, ["geoclue"]
    except Exception:
        pass
    return False, []


def main() -> None:
    cam, cam_apps = detect_camera()
    mic, mic_apps, screen, screen_apps = detect_pw_nodes()
    if detect_recorders(screen_apps):
        screen = True
    loc, loc_apps = detect_location()

    print(
        json.dumps(
            {
                "cam": cam,
                "mic": mic,
                "screen": screen,
                "loc": loc,
                "mic_apps": mic_apps,
                "cam_apps": cam_apps,
                "screen_apps": screen_apps,
                "loc_apps": loc_apps,
            }
        )
    )
    sys.stdout.flush()


if __name__ == "__main__":
    main()
