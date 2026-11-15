#!/usr/bin/env python3
"""Collect pawlette theme information for the mewline-qs shell.

Prints a single JSON document on stdout:
{
  "installed": true,
  "mode": "dark",
  "themes": [
    {
      "name": "catppuccin-mocha",
      "logo": "/home/u/.local/share/pawlette/themes/catppuccin-mocha/logo.png",
      "variants": {"default": "#cba6f7", "blue": "#89b4fa", ...}
    }
  ]
}

Variant colors come from each theme's colors.toml. Variants reported by
`pawlette list` but missing from colors.toml are listed with a null color so
the UI can still show them without a color dot.
"""

import json
import os
import re
import subprocess
import sys
import tomllib
from pathlib import Path

sys.dont_write_bytecode = True

THEMES_DIR = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "pawlette" / "themes"
CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "pawlette" / "pawlette.toml"

VARIANT_COLOR_KEYS = ("color_primary", "color_border_active", "color_cursor")


def variant_color(section: dict) -> str | None:
    for key in VARIANT_COLOR_KEYS:
        value = section.get(key)
        if isinstance(value, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            return value.lower()
    return None


def parse_theme_colors(theme_dir: Path) -> dict[str, str | None]:
    """Parse colors.toml -> {variant: hex color}. Empty dict when missing."""
    toml_path = theme_dir / "colors.toml"
    if not toml_path.is_file():
        return {}

    try:
        with open(toml_path, "rb") as f:
            data = tomllib.load(f)
    except Exception:
        return {}

    result: dict[str, str | None] = {}
    colors = data.get("colors", {})
    if isinstance(colors, dict):
        result["default"] = variant_color(colors)

    variants = data.get("variants", {})
    if isinstance(variants, dict):
        for name, section in variants.items():
            if isinstance(section, dict):
                result[name] = variant_color(section)
    return result


def read_mode() -> str:
    try:
        text = CONFIG_PATH.read_text(encoding="utf-8")
    except Exception:
        return "dark"
    # Only look before the first TOML section header so plugin keys are ignored.
    header = text.split("[", 1)[0]
    match = re.search(r'^\s*mode\s*=\s*"([^"]+)"', header, re.MULTILINE)
    return match.group(1) if match else "dark"


def collect_themes() -> list[dict]:
    try:
        output = subprocess.run(
            ["pawlette", "list"], capture_output=True, text=True, check=True
        ).stdout
    except Exception:
        return []

    themes: list[dict] = []
    for line in output.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        # "catppuccin-mocha (blue, flamingo, green)"
        match = re.fullmatch(r"(\S+)\s*(?:\(([^)]*)\))?", line)
        if not match:
            continue
        name = match.group(1)
        variants_raw = match.group(2)
        variants = (
            [v.strip() for v in variants_raw.split(",") if v.strip()]
            if variants_raw
            else []
        )

        theme_dir = THEMES_DIR / name
        color_map = parse_theme_colors(theme_dir)
        # Keep the CLI variant order and flag the ones without a known color.
        variant_colors: dict[str, str | None] = {}
        if not variants and color_map:
            variant_colors.update(color_map)
        else:
            for v in variants:
                variant_colors[v] = color_map.get(v)

        logo = theme_dir / "logo.png"
        themes.append(
            {
                "name": name,
                "logo": str(logo) if logo.is_file() else None,
                "variants": variant_colors,
            }
        )
    return themes


def main() -> None:
    doc = {
        "installed": False,
        "mode": read_mode(),
        "themes": [],
    }
    try:
        doc["themes"] = collect_themes()
        doc["installed"] = bool(doc["themes"])
    except Exception:
        pass
    print(json.dumps(doc))


if __name__ == "__main__":
    main()
