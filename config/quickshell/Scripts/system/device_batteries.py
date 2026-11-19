#!/usr/bin/env python3
"""Read peripheral batteries without starting a tray app or changing hardware.

--native: Linux power_supply + BlueZ Battery1 (optional dbus-python).
--batteryhub: BatteryHub's optional wireless-battery --json backend.
Each invocation emits one JSON object and exits. No persistent daemon/cache.
"""
import argparse
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True


def percentage(value):
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return -1
    if isinstance(value, bool) or not math.isfinite(number) or not 0 <= number <= 100:
        return -1
    return round(number)


def device_kind(icon, name=""):
    text = (icon + " " + name).lower()
    for kind, words in (
        ("mouse", ("mouse", "trackball", "touchpad")),
        ("keyboard", ("keyboard",)),
        ("headset", ("headset", "headphone", "earbud", "airpods", "buds")),
        ("gamepad", ("gamepad", "gaming-input", "controller", "dualsense", "dualshock")),
        ("phone", ("phone",)),
    ):
        if any(word in text for word in words):
            return kind
    return "other"


def address_in(value):
    match = re.search(r"(?:[0-9a-f]{2}:){5}[0-9a-f]{2}", value, re.I)
    return match.group(0).upper() if match else ""


def read_text(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return ""


def input_kind(supply, name):
    """Use kernel input capabilities when product names omit the device type."""
    kind = device_kind("", name)
    if kind != "other":
        return kind
    inputs = sorted((supply / "device/input").glob("input*"))
    # Input capability files contain high-to-low native-word hex bitmaps.
    def bitmap(path):
        words = read_text(path).split()
        bits = 64 if sys.maxsize > 2**32 else 32
        try:
            return sum(int(word, 16) << (index * bits)
                       for index, word in enumerate(reversed(words)))
        except ValueError:
            return 0
    for input_device in inputs:
        keys = bitmap(input_device / "capabilities/key")
        if keys & (1 << 0x130):  # BTN_GAMEPAD
            return "gamepad"
    for input_device in inputs:
        if bitmap(input_device / "capabilities/rel") & 3 == 3:  # REL_X and REL_Y
            return "mouse"
    for input_device in inputs:
        if bitmap(input_device / "capabilities/key") & (1 << 30):  # KEY_A
            return "keyboard"
    return kind


def bluez_devices():
    """Read connection state even without Battery1; never discover or connect."""
    try:
        import dbus
        bus = dbus.SystemBus()
        manager = dbus.Interface(bus.get_object("org.bluez", "/"),
                                 "org.freedesktop.DBus.ObjectManager")
        objects = manager.GetManagedObjects(timeout=3)
    except Exception:
        return []
    devices = []
    for path, interfaces in objects.items():
        props = interfaces.get("org.bluez.Device1", {})
        battery = interfaces.get("org.bluez.Battery1", {})
        if not props:
            continue
        level = percentage(battery.get("Percentage"))
        address = str(props.get("Address", "")).upper()
        name = str(props.get("Alias") or props.get("Name") or address or "Bluetooth device")
        devices.append({"key": "bluez:" + str(path), "name": name,
                        "kind": device_kind(str(props.get("Icon", "")), name),
                        "percent": level, "charging": False, "asleep": False,
                        "connected": bool(props.get("Connected")), "via": "Bluetooth", "detail": "",
                        "address": address, "source": "bluez"})
    return devices


def sysfs_devices(root=Path("/sys/class/power_supply")):
    devices = []
    try:
        supplies = sorted(root.iterdir())
    except OSError:
        return devices
    for supply in supplies:
        # Scope=Device explicitly excludes the laptop battery and AC adapters.
        if read_text(supply / "scope") != "Device":
            continue
        if read_text(supply / "present") == "0":
            continue
        level = percentage(read_text(supply / "capacity"))
        coarse_level = read_text(supply / "capacity_level")
        if level < 0 and not coarse_level:
            continue
        name = (read_text(supply / "model_name") or read_text(supply / "device/name")
                or read_text(supply / "device/model_name") or supply.name)
        serial = read_text(supply / "serial_number")
        devices.append({"key": "sysfs:" + supply.name, "name": name,
                        "kind": input_kind(supply, name), "percent": level,
                        "charging": read_text(supply / "status") == "Charging",
                        "asleep": False, "connected": True, "via": "Linux HID",
                        "detail": coarse_level if level < 0 else "", "address": address_in(serial or supply.name),
                        "source": "sysfs"})
    return devices


def native_devices():
    bluetooth = bluez_devices()
    disconnected = {device["address"] for device in bluetooth
                    if device["address"] and not device["connected"]}
    devices = sysfs_devices()
    # HID capacity can remain cached after Bluetooth has disconnected.
    devices = [device for device in devices if device["address"] not in disconnected]
    for device in bluetooth:
        if not device["connected"]:
            continue
        # One physical Bluetooth battery may also be exposed by the HID driver.
        existing = next((item for item in devices if device["address"]
                         and item["address"] == device["address"]), None)
        if existing is not None:
            existing["name"] = device["name"]
            existing["via"] = "Bluetooth"
            if existing["kind"] == "other":
                existing["kind"] = device["kind"]
        elif device["percent"] >= 0:
            devices.append(device)
    return devices


def batteryhub_devices():
    executable = shutil.which("wireless-battery")
    if not executable:
        return {"devices": [], "available": False, "error": ""}
    try:
        result = subprocess.run([executable, "--json"], capture_output=True,
                                text=True, timeout=15, check=True)
        payload = json.loads(result.stdout)
        if not isinstance(payload, list):
            raise ValueError("expected a JSON array")
        devices = []
        seen = set()
        for item in payload:
            if not isinstance(item, dict) or item.get("connected") is not True:
                continue
            key = item.get("key")
            if not isinstance(key, str) or not key or key in seen:
                continue
            seen.add(key)
            name = str(item.get("name") or "Wireless device")
            kind = item.get("kind", "other")
            if kind not in ("mouse", "headset", "keyboard", "gamepad", "phone", "other"):
                kind = device_kind("", name)
            devices.append({"key": "batteryhub:" + key, "name": name, "kind": kind,
                            "percent": percentage(item.get("percent")),
                            "charging": item.get("charging") is True,
                            "asleep": item.get("asleep") is True, "connected": True,
                            "via": str(item.get("via") or "BatteryHub"),
                            "detail": str(item.get("detail") or item.get("level") or ""),
                            "graceSec": grace_seconds(item.get("graceSec")),
                            "address": address_in(key), "source": "batteryhub"})
        return {"devices": devices, "available": True, "error": ""}
    except (OSError, subprocess.SubprocessError, ValueError, UnicodeError) as error:
        return {"devices": [], "available": True, "error": str(error)[:240]}


def grace_seconds(value):
    try:
        return max(0, min(86400, int(value)))
    except (TypeError, ValueError, OverflowError):
        return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--native", action="store_true")
    group.add_argument("--batteryhub", action="store_true")
    args = parser.parse_args()
    data = ({"devices": native_devices(), "available": True, "error": ""}
            if args.native else batteryhub_devices())
    print(json.dumps(data, ensure_ascii=False))
