#!/usr/bin/env python3
"""Emit the emoji picker catalogue as JSON: [{"char", "name", "group"}].

Pure stdlib (unicodedata) — no network, no cache files, no font queries.
Skin-tone modifiers and ZWJ sequences are intentionally skipped: the picker
shows one base glyph per name, so search stays predictable. Groups follow
the Unicode block the glyph lives in — codepoint order inside a group is
the same flow the standard emoji tables use.
"""
import json
import sys
import unicodedata

# Ordered blocks: the picker lists them in this order, each block becomes a
# section header. Block boundaries are Unicode blocks, so some CLDR
# categories share a section (e.g. food inside the 1F330-1F37F range).
RANGES = (
    ("Smileys & Emotion", ((0x1F600, 0x1F64F),)),
    ("People, Hands & Animals", ((0x1F900, 0x1F9FF),)),
    ("People & Body", ((0x1F440, 0x1F4AA),)),
    ("Animals & Nature", ((0x1F300, 0x1F321), (0x1F400, 0x1F43F), (0x1F490, 0x1F490), (0x1F980, 0x1F9AA))),
    ("Food & Drink", ((0x1F330, 0x1F37F), (0x1F940, 0x1F96F))),
    ("Sports & Activity", ((0x1F380, 0x1F39F), (0x1F3C0, 0x1F3D0), (0x1F93A, 0x1F93F))),
    ("Travel & Places", ((0x1F680, 0x1F6FF), (0x1F3E0, 0x1F3F0), (0x1F5FA, 0x1F5FF), (0x1F6D0, 0x1F6DF), (0x1F6DD, 0x1F6DF))),
    ("Objects", ((0x1F4A0, 0x1F4FF), (0x1F460, 0x1F480), (0x1F5A0, 0x1F5FA), (0x1F9C0, 0x1F9CF), (0x1FA70, 0x1FAFF), (0x1F560, 0x1F57F))),
    ("Symbols & Signs", ((0x2600, 0x27BF), (0x2190, 0x21FF), (0x2300, 0x23FF), (0x25A0, 0x25FF), (0x2B00, 0x2BFF), (0x2900, 0x297F), (0x1F500, 0x1F53F), (0x1F540, 0x1F55F), (0x1F570, 0x1F59F), (0x1F000, 0x1F1FF), (0x1F200, 0x1F2FF))),
)

# Chars that only render as color emoji with an explicit presentation
# selector appended.
FE0F_BLOCKS = tuple(
    (lo, hi) for name, blocks in RANGES for lo, hi in blocks if lo >= 0x2100 and hi <= 0x2BFF
)
SKIP_SUBSTRINGS = ("VARIATION", "COMBINING", "REGIONAL INDICATOR")


def is_emoji_presentation(cp):
    return any(lo <= cp <= hi for lo, hi in FE0F_BLOCKS)


def collect():
    rows = []
    seen_names = set()
    for group_index, (group_name, blocks) in enumerate(RANGES):
        for lo, hi in blocks:
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
                rows.append({"char": char, "name": label,
                             "group": group_name, "order": (group_index, cp)})
    rows.sort(key=lambda item: item["order"])
    for item in rows:
        del item["order"]
    return rows


if __name__ == "__main__":
    print(json.dumps(collect(), ensure_ascii=False))
