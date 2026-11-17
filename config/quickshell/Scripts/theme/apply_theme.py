#!/usr/bin/env python3
"""DISABLED in mewline-qs.

pawlette owns all theming now, so the mewline applier chain (hypr colors,
kitty, gtk, qt, btop, ...) must never run. This stub logs every invocation
with its parent process so a forgotten caller shows up in the audit log
instead of silently rewriting the user's config.
"""

import json
import os
import sys
import time


def main() -> None:
    entry = {
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "argv": sys.argv[1:],
        "cwd": os.getcwd(),
        "ppid": os.getppid(),
    }
    try:
        with open(f"/proc/{os.getppid()}/cmdline") as f:
            entry["parent"] = f.read().replace("\0", " ").strip()
        ppid = os.getppid()
        with open(f"/proc/{ppid}/status") as f:
            for line in f:
                if line.startswith("PPid:"):
                    grand = int(line.split()[1])
                    with open(f"/proc/{grand}/cmdline") as g:
                        entry["grandparent"] = g.read().replace("\0", " ").strip()
                    break
    except Exception:
        pass
    cache = os.path.expanduser("~/.cache/quickshell")
    os.makedirs(cache, exist_ok=True)
    with open(os.path.join(cache, "apply_theme_audit.log"), "a") as f:
        f.write(json.dumps(entry) + "\n")


if __name__ == "__main__":
    main()
