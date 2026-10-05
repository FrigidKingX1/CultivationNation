#!/usr/bin/env python3
"""Generate data/zones3d.json — true-3D island dressing per zone (P23).

Ingests data/beasts.json (zone order, min_realm gates, elements): the zone
id SET must match exactly, and gate min_realm values are copied through
(ContentDB cross-checks them against the original tables at load).
Palettes derive from the retired diorama ZONE_PALETTES (same hues, mapped
to low/mid/high/accent/fog/sky_tint). Everything else is a deterministic
function of zone index — no hand-tuning, no external assets.

Never hand-edit the generated file; extend this generator instead.
"""
import hashlib
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BEASTS_PATH = os.path.normpath(os.path.join(HERE, "..", "data", "beasts.json"))
OUT_PATH = os.path.normpath(os.path.join(HERE, "..", "data", "zones3d.json"))

# Retired-diorama hues, keyed by zone (WorldView.gd ZONE_PALETTES).
SOURCE_HUES = {
    "Dewfield": {"ground": (0.16, 0.24, 0.23), "rock": (0.23, 0.33, 0.38), "fog": (0.45, 0.55, 0.58), "sun": (1.0, 0.96, 0.88)},
    "Ashbarrow": {"ground": (0.25, 0.15, 0.13), "rock": (0.32, 0.20, 0.18), "fog": (0.55, 0.42, 0.38), "sun": (1.0, 0.82, 0.66)},
    "Gloamdeep": {"ground": (0.15, 0.15, 0.20), "rock": (0.30, 0.30, 0.38), "fog": (0.42, 0.42, 0.52), "sun": (0.82, 0.85, 1.0)},
    "Murkfen": {"ground": (0.14, 0.22, 0.14), "rock": (0.22, 0.30, 0.22), "fog": (0.45, 0.55, 0.42), "sun": (0.92, 1.0, 0.85)},
    "Stonehollow": {"ground": (0.26, 0.22, 0.16), "rock": (0.42, 0.36, 0.26), "fog": (0.60, 0.55, 0.45), "sun": (1.0, 0.94, 0.80)},
    "Stillmere": {"ground": (0.18, 0.24, 0.30), "rock": (0.45, 0.52, 0.60), "fog": (0.62, 0.68, 0.75), "sun": (0.92, 0.96, 1.0)},
    "Pyrefen": {"ground": (0.28, 0.14, 0.10), "rock": (0.45, 0.22, 0.14), "fog": (0.62, 0.40, 0.30), "sun": (1.0, 0.72, 0.52)},
    "Whitefoundry": {"ground": (0.30, 0.30, 0.32), "rock": (0.55, 0.55, 0.60), "fog": (0.65, 0.65, 0.70), "sun": (1.0, 0.98, 0.95)},
    "Thornwake": {"ground": (0.13, 0.18, 0.13), "rock": (0.25, 0.20, 0.30), "fog": (0.40, 0.48, 0.40), "sun": (0.85, 0.95, 0.80)},
}

WEATHER = {"spring": "petal", "summer": "clear", "autumn": "ash", "winter": "snow"}
TREE_STYLES = ["pine", "bamboo", "deadwood"]
ROCK_STYLES = ["crag", "slab", "spire"]
GOLDEN_ANGLE = math.pi * (3.0 - math.sqrt(5.0))


def darkened(c, amount):
    return tuple(round(v * (1.0 - amount), 3) for v in c)


def lightened(c, amount):
    return tuple(round(v + (1.0 - v) * amount, 3) for v in c)


def audit_seed(zone_id):
    # Stable reference hash (audit only). Runtime terrain uses
    # hash(map_seed, zone_id) instead — see ADR determinism notes.
    return hashlib.md5(zone_id.encode("utf-8")).hexdigest()[:16]


def wall_type(min_realm):
    if min_realm < 8:
        return "mist"
    if min_realm < 24:
        return "wind"
    return "lightning"


def main():
    with open(BEASTS_PATH, encoding="utf-8") as f:
        beasts = json.load(f)
    zones = []
    seen = set()
    for b in beasts:
        z = b["zone"]
        if z not in seen:
            seen.add(z)
            zones.append(z)
    assert len(zones) == 9, "nine zones expected, one island each"
    out = []
    for i, zone in enumerate(zones):
        zone_beasts = [b for b in beasts if b["zone"] == zone]
        min_realm = min(int(b["min_realm"]) for b in zone_beasts)
        hues = SOURCE_HUES[zone]
        angle = i * GOLDEN_ANGLE
        out.append({
            "id": zone,
            "island_seed": audit_seed(zone),
            "size_radius": round(200.0 + (min_realm / 40.0) * 600.0, 1),
            "height_amp": 20 + (i % 3) * 15,
            "palette": {
                "low": darkened(hues["ground"], 0.3),
                "mid": hues["ground"],
                "high": lightened(hues["rock"], 0.25),
                "accent": hues["sun"],
                "fog": hues["fog"],
                "sky_tint": lightened(hues["sun"], 0.3),
            },
            "gate": {"min_realm": min_realm, "wall_type": wall_type(min_realm)},
            "spawn": {
                "pos": [round(1200.0 * math.cos(angle), 1), 0.0, round(1200.0 * math.sin(angle), 1)],
                "facing": round(angle + math.pi, 4),
            },
            "weather": dict(WEATHER),
            "props": {
                "density": 20 + i * 5,
                "tree_style": TREE_STYLES[i % 3],
                "rock_style": ROCK_STYLES[i % 3],
                "herb_nodes": 3 + (i % 3),
            },
        })
    lines = ["["]
    for i, z in enumerate(out):
        comma = "," if i < len(out) - 1 else ""
        lines.append(" " + json.dumps(z, ensure_ascii=False) + comma)
    lines.append("]")
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote %s (%d zones)" % (OUT_PATH, len(out)))


if __name__ == "__main__":
    main()
