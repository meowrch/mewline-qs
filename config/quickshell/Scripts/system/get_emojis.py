#!/usr/bin/env python3
"""Emit the emoji picker catalogue as JSON: [{"char": ..., "name": ...}].

Pure stdlib (unicodedata) — no network, no cache files, no font queries.
Skin-tone modifiers and ZWJ sequences are intentionally skipped: the picker
shows one base glyph per name, so search stays predictable.
"""
import json
import sys
import unicodedata

# Blocks that carry the pictographs people actually pick. Flags (regional
# indicator pairs) and keycap sequences are excluded on purpose.
RANGES = (
    (0x1F400, 0x1F64F),  # emoticons, people & gestures, animals & food
    (0x1F680, 0x1F6FF),  # transport & places
    (0x1F900, 0x1F9FF),  # supplemental symbols
    (0x1FA70, 0x1FAFF),  # extended-A symbols
    (0x1F300, 0x1F3FF),  # misc pictographs (sky & weather)
    (0x1F000, 0x1F2FF),  # mahjong / dominoes / cards
    (0x2600, 0x27BF),    # misc symbols + dingbats (get FE0F below)
    (0x2B00, 0x2BFF),    # arrows and stars (FE0F)
    (0x2190, 0x21FF),    # arrows (FE0F)
    (0x2300, 0x23FF),    # misc technical (FE0F)
    (0x25A0, 0x25FF),    # geometric shapes (FE0F)
)
# Chars that only render as color emoji with an explicit presentation
# selector appended.
FE0F_BLOCKS = tuple(
    (lo, hi) for lo, hi in RANGES if lo >= 0x2100 and hi <= 0x2BFF
)
SKIP_SUBSTRINGS = ("VARIATION", "COMBINING", "REGIONAL INDICATOR")


def is_emoji_presentation(cp):
    return any(lo <= cp <= hi for lo, hi in FE0F_BLOCKS)


def collect():
    out = []
    seen_names = set()
    for lo, hi in RANGES:
        for cp in range(lo, hi + 1):
            ch = chr(cp)
            if unicodedata.category(ch) not in ("So", "Sk"):
                continue
            name = unicodedata.name(ch, "")
            if not name or any(s in name for s in SKIP_SUBSTRINGS):
                continue
            char = ch + ("\uFE0F" if is_emoji_presentation(cp) else "")
            label = name.replace("_", " ").title()
            if label in seen_names:
                continue
            seen_names.add(label)
            out.append({"char": char, "name": label})
    out.sort(key=lambda item: item["name"].lower())
    return out


if __name__ == "__main__":
    print(json.dumps(collect(), ensure_ascii=False))
