#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import subprocess

# Only the values the shell mirrors for its own rendering. Everything
# else (blur, gaps, input, ...) belongs to the user's hyprland.lua.
OPTIONS = [
    "decoration:shadow:enabled",
    "decoration:shadow:range",
    "decoration:shadow:render_power",
    "animations:enabled",
]


def main():
    res = {}
    for opt in OPTIONS:
        try:
            out = subprocess.check_output(
                ["hyprctl", "getoption", opt, "-j"],
                stderr=subprocess.DEVNULL,
            ).decode("utf-8")
            data = json.loads(out)
            if "int" in data:
                res[opt] = data["int"]
            elif "float" in data:
                res[opt] = data["float"]
            elif "bool" in data:
                res[opt] = data["bool"]
            elif "str" in data:
                res[opt] = data["str"]
            elif "custom" in data:
                res[opt] = data["custom"]
            elif "css" in data:
                parts = str(data["css"]).split()
                if parts:
                    res[opt] = int(parts[0])
        except Exception:
            continue

    print(json.dumps(res))


if __name__ == "__main__":
    main()
