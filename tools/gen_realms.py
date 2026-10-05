#!/usr/bin/env python3
"""Generate data/realms.json — the single source of truth for the ladder.

50 realms at qi_required[i] = 120 * 4^i * FRONT_LOAD[i] (exact in float64
for the base term: 15 * 2^(2i+3)), grouped into 7 macro tiers. FRONT_LOAD
front-loads the climb: 10x at realm 1 decaying linearly to 1x by realm 9,
pure 4x past that — the early game takes time to lift off, then rebirth
compounding (aptitude/talents/legacy) accelerates the back half.
Re-run to extend: append names to NAMES and re-run; engine/tests derive
counts from the file, never from constants.
"""
import json
import os

NAMES = [
    # Tier 1 — Qi Refining (realms 1-8, kept from the original 18).
    "Dustroot Field", "Brookstone Hollow", "Ember Terrace", "Pale Reed Marsh",
    "Cinder Vale", "Hollow Pine Ascent", "Frostbell Pass", "Lantern Deep",
    # Tier 2 — Foundation Establishment (realms 9-16).
    "Ashen Observatory", "Thornbridge Expanse", "Quiet Thunder Gate",
    "First Light Summit", "Murkfen Crossing", "Stillwater Deep",
    "Vesper Hollow", "Gravenight Rise",
    # Tier 3 — Golden Core (realms 17-24).
    "Moonmoth Garden", "Second Dawn Gate", "Cinnabar Hollow",
    "Ninefold Rapids", "Vermilion Stair", "Hollowed Moon Ravine",
    "Paper Lantern Shoal", "Sable Pine Gate",
    # Tier 4 — Nascent Soul (realms 25-32).
    "Whitebrow Summit", "Inkstone Lake", "Copper Bell Pass",
    "Drifting Reed Expanse", "Starfall Terrace", "Mothwing Hollow",
    "Ironblossom Vale", "Quiet Furnace Deep",
    # Tier 5 — Deity Transformation (realms 33-40).
    "Cloudburial Ridge", "Frostfire Observatory", "Stone Lotus Ascent",
    "Howling Gale Gate", "Sunken Bell Marsh", "Amberlight Crossing",
    "Nightjar Hollow", "Thunderhead Vale",
    # Tier 6 — Tribulation Transcendence (realms 41-48).
    "Voidmirror Expanse", "Ashen Star Terrace", "Dreamerosion Gate",
    "Pale Eternity Summit", "Inkdark Abyss", "First Frost Observatory",
    "Silent Tempest Rise", "Gloaming Throne Pass",
    # Tier 7 — True Immortal (realms 49-50).
    "Dawnless Origin Field", "Everwhite Ascension Gate",
]

# macro_tier, macro_name, lifespan_years, tribulation waves per tier.
TIERS = [
    (1, "Qi Refining", 110, 0),
    (2, "Foundation Establishment", 250, 3),
    (3, "Golden Core", 650, 6),
    (4, "Nascent Soul", 1500, 9),
    (5, "Deity Transformation", 4000, 12),
    (6, "Tribulation Transcendence", 10000, 18),
    (7, "True Immortal", 1000000000, 24),
]
# Realm index ranges (0-based, inclusive) per tier row above.
TIER_SPANS = [(0, 7), (8, 15), (16, 23), (24, 31), (32, 39), (40, 47), (48, 49)]

assert len(NAMES) == 50, "ladder must hold 50 names"


def tier_for(i):
    for (lo, hi), (t, name, life, waves) in zip(TIER_SPANS, TIERS):
        if lo <= i <= hi:
            return t, name, life, waves
    raise AssertionError("realm index out of ladder")


def front_load(i):
    # P18: slow start that speeds up. 10x at realm 1 (i=0), linear decay to
    # 1x by realm 9 (i=8), unity past that. Late ladder is pure 4x.
    if i >= 8:
        return 1.0
    return 1.0 + 9.0 * (8 - i) / 8.0


def main():
    realms = []
    for i, nm in enumerate(NAMES):
        t, name, life, waves = tier_for(i)
        realms.append({
            "id": "realm_%02d" % (i + 1),
            "name": nm,
            "qi_required": float(120 * 4 ** i) * front_load(i),
            "macro_tier": t,
            "macro_name": name,
            "lifespan": life,
            "waves": waves,
            "trib_power": float(5 + 5 * i),
        })
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "data", "realms.json")
    out = os.path.normpath(out)
    with open(out, "w", encoding="utf-8") as f:
        lines = ["["]
        for n, r in enumerate(realms):
            comma = "," if n < len(realms) - 1 else ""
            lines.append(" " + json.dumps(r, ensure_ascii=False) + comma)
        lines.append("]")
        f.write("\n".join(lines) + "\n")
    print("wrote %s (%d realms)" % (out, len(realms)))


if __name__ == "__main__":
    main()
