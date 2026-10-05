#!/usr/bin/env python3
"""Generate data/guardians.json — the single source of truth for macro-tier
guardians (P22 guardian migration, ADR-001).

One guardian per macro tier (7 total). Each guards the breakthrough that
LEAVES its tier: guardians 1-6 gate the tier-to-tier crossings, guardian 7
gates the final breakthrough that clears the ladder.

Guardian power derives from the tribulation power already present at each
macro-tier boundary (read from data/realms.json): power = trib_power, the
exact scale the duel defense uses (same combined number as is_ready). A
cultivator ready to cross the tier therefore blocks every strike and wins
Radiant by construction; the duel is ceremony, stakes, and story, not a
new wall. Waves = 3 + tier, mirroring the tribulation resolution family.

Names are PROVISIONAL (Q21 deferred to the 0.21.0 report): neutral
gatewarden titles only, flagged here and in the data. Never hand-edit the
generated file; extend this generator instead.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REALMS_PATH = os.path.normpath(os.path.join(HERE, "..", "data", "realms.json"))
OUT_PATH = os.path.normpath(os.path.join(HERE, "..", "data", "guardians.json"))

# (tier, guard_realm_index, provisional name). Spans mirror gen_realms.py
# TIER_SPANS; guard_realm is the last realm index of the tier.
GUARDIANS = [
    (1, 7, "Stone Gatewarden"),
    (2, 15, "Verdant Gatewarden"),
    (3, 23, "Deep Tide Gatewarden"),
    (4, 31, "Ninefold Storm Gatewarden"),
    (5, 39, "Hollow Void Gatewarden"),
    (6, 47, "Falling Star Gatewarden"),
    (7, 49, "Heavenmark Sentinel"),
]

REWARD_MULT = 0.25


def main():
    with open(REALMS_PATH, encoding="utf-8") as f:
        realms = json.load(f)
    assert len(realms) == 50, "guardians derive from the 50-realm ladder"
    out = []
    for n, (tier, guard_realm, name) in enumerate(GUARDIANS, start=1):
        power = float(realms[guard_realm]["trib_power"])
        assert int(realms[guard_realm]["macro_tier"]) == tier, \
            "guardian tier must match its boundary realm tier"
        out.append({
            "id": "guardian_%02d" % n,
            "name": name,
            "tier": tier,
            "guard_realm": guard_realm,
            "power": power,
            "waves": 3 + tier,
            "reward_mult": REWARD_MULT,
            "provisional": True,
        })
    lines = ["["]
    for i, g in enumerate(out):
        comma = "," if i < len(out) - 1 else ""
        lines.append(" " + json.dumps(g, ensure_ascii=False) + comma)
    lines.append("]")
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote %s (%d guardians)" % (OUT_PATH, len(out)))


if __name__ == "__main__":
    main()
