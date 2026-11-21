# Wireless device batteries

## Placement and appearance

A separate capsule **after the workspaces on the left** keeps peripheral state
out of the already crowded system-status group. It is not part of the workspace
buttons. The capsule also works in Gaming mode.

In **Settings → Bar → Wireless Device Batteries**:

- **Position**: Left (default), Right, Off. Off stops battery polling.
- **BatteryHub Backend**: enabled by default, but optional. If the executable
  is absent, native battery readings continue to work.

**Display** has three modes in Settings → Bar:

- **Auto** (default): one or two devices show the percentage next to the icon
  (the same size as the laptop battery percentage); three devices switch to
  compact icons with a proportional charge bar.
- **Percent**: the percentage next to the icon regardless of the count.
- **Bar**: compact icons with a proportional charge bar.

More than three devices show the first three and an overflow badge whose
tooltip lists every device. Hovering always shows the device name,
percentage, transport and reported state. Unknown levels (the transport
hides them, e.g. some JBL models) are shown last with a dash; they never
pretend to be 0%.

Mouse, keyboard, headset, earbuds, gamepad and phone have themed SVG icons.
Discharging batteries at 15% or less are red; charging uses the theme accent and
a lightning badge. Sleeping/last-known readings are dim. Unknown is not 0%.
0% really draws an empty level bar.

Up to three devices appear in the capsule. Low batteries are ordered first.
Other devices are listed in the `+N` hover tooltip. Space is capped at 128px
and reduced when the tray or center drawer needs room. On an extremely narrow
layout the capsule disappears rather than overlapping the center; percentages
need more room than icon-only mode and fall back to compact icons if needed.
It does not rearrange existing bar controls.

## Sources

`Core/Services/DeviceBatteryService.qml` shares one snapshot across bar instances.
The Python helper emits JSON and exits; no additional tray application, permanent
Python daemon, saved hardware identifiers or network requests are introduced.

1. **Linux HID battery**: `/sys/class/power_supply`, only supplies explicitly
   marked `scope=Device` and not `present=0`. The laptop battery stays in the
   existing laptop battery island. Kernel input capabilities classify generic
   mouse/keyboard/gamepad names where available.
2. **Bluetooth**: BlueZ `Device1` + `Battery1.Percentage`; only connected devices.
   Requires `python-dbus` on Arch. It does not pair, connect, discover or wake
   devices. A Bluetooth MAC matches duplicate HID/BlueZ readings.
3. **BatteryHub**: optional `wireless-battery --json`, a one-shot poll every 60s
   with a 15s timeout, no shell interpolation. It uses the stable JSON array from
   [Wireless-Device-Battery-Monitor](https://github.com/krisgfx9/Wireless-Device-Battery-Monitor).
   Explicitly disconnected entries are removed. Sleeping devices may reuse a
   previously awake sample in memory for the backend's `graceSec`; expired or
   unobserved levels are unknown. A failed poll clears that backend rather than
   keeping stale devices forever.

   Some upstream drivers omit devices on a missed response instead of returning an
   explicit sleeping entry. Those disappear for that poll: a missing entry alone
   cannot distinguish sleep from unplugging the receiver, so the shell does not
   invent receiver presence or keep a phantom battery. Only explicit connected /
   sleeping snapshots can safely retain a timestamped last-known level.

Native read-only telemetry is polled every 5s. It takes precedence over a matching
BatteryHub reading. Cross-source matches use MAC first, or an unambiguous same
name and kind. Two devices of the same kind are never collapsed just because
both are mice; ambiguous matches are preserved rather than guessed.

**Hardware limits:** if neither the kernel, BlueZ nor BatteryHub reports a level,
there is no honest percentage to show. Native power-supply readings may be cached
by the kernel; not all dongles report disconnects/presence. BatteryHub's Linux
backend is experimental and narrower than its Windows build: the inspected Linux
Makefile enables Logitech, Razer, SteelSeries, Corsair, HyperX, PlayStation,
Cooler Master, Glorious, Finalmouse and shared Kysona protocols. Do not assume the
entire Windows compatibility list works on Linux. A fresh launch with a sleeping
device cannot recover last-known readings from an earlier shell session.

## Optional BatteryHub installation on Arch

The shell never downloads or builds BatteryHub automatically. Its source is not
vendored; its Windows UI is not embedded. Build/install the upstream executable
separately if your receiver needs it:

```sh
sudo pacman -S --needed base-devel gtk4 cairo python python-dbus
git clone https://github.com/krisgfx9/Wireless-Device-Battery-Monitor.git
cd Wireless-Device-Battery-Monitor
./build-linux.sh
install -Dm755 wireless-battery "$HOME/.local/bin/wireless-battery"
./wireless-battery --json
```

Ensure `~/.local/bin` is on the **shell session's PATH**, not only your interactive
terminal's PATH. Restart Quickshell after changing PATH. BatteryHub is detected
on each enabled poll, so installing it on an already included PATH does not need
a shell restart. Do not additionally run its tray app/autostart: that duplicates
the UI and may make two processes query the receiver at once.

Reading vendor HID reports needs access to the matching `/dev/hidraw*` devices.
Upstream supplies `linux/99-wireless-battery.rules` with `TAG+="uaccess"` for all
hidraw devices. That grants the active local desktop session HID access, not just
battery access: review it before installing, or narrow it to your receiver's
vendor/product IDs. Do not run the shell as root and do not use `chmod 666`.
After installing an appropriate rule, reload udev and reconnect the receiver:

```sh
sudo udevadm control --reload-rules
```

Follow upstream's Linux documentation for troubleshooting:
`wireless-battery --list`, `wireless-battery --dump`, `wireless-battery --json`.

## Try it from a checkout

Run from a checkout rather than replacing the installed package:

```sh
quickshell -p config/quickshell
```

Stop the existing shell instance first through your normal session/autostart
management, so you do not have two bars. The feature ships in releases since
**2.4.0**.

Diagnostic reads, without opening a GUI:

```sh
python3 config/quickshell/Scripts/system/device_batteries.py --native
python3 config/quickshell/Scripts/system/device_batteries.py --batteryhub
```

At home check:

- Device icons/level bars appear; hover shows the correct name and percentage.
- Connect/disconnect Bluetooth (within 5s); dongles update on the next 60s poll.
- Charging, low level, two devices of the same kind, and unknown/sleeping states.
- Left/right/off, percent mode, Gaming mode, open tray and center drawer.
- Settings survive a restart; Off does not leave a phantom capsule.

No GUI/hardware validation was performed in the development container, at the
user's request. Helper invocation and source syntax checks are not evidence of
hardware support or a visual screenshot.
