#!/usr/bin/env python3
"""Generate data/leylines.json — the single source of truth for ley-line
attunement channels (0.26.0 ley-line attunement, P26_ATTUNEMENT_ADR.md).

Eight channels, sequential, the classical meridian sequence in generic
traditional vocabulary (consistent with the project's existing qi
language). Each channel gates on a realm floor (0-based realm index into
data/realms.json) and costs qi to open. Costs track ~0.5x the floor
realm's qi_required early (affordable first-life) and ~0.24x late
(mid-game sink); floors sit on early-tier realms, ending at R25
Whitebrow Summit (Nascent Soul entry = flight unlock).

Cost bases verified against data/realms.json at 0.26a (R08 req
4,177,920; R16 req 128,849,018,880). Never hand-edit the generated
file; extend this generator instead.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REALMS_PATH = os.path.normpath(os.path.join(HERE, "..", "data", "realms.json"))
OUT_PATH = os.path.normpath(os.path.join(HERE, "..", "data", "leylines.json"))

# (id, name, floor realm index, qi cost). Floors avoid warden-crossing
# realms where the sink would compete with guardian duels, except ch3
# which sits just ahead of warden 1 by design (spend-or-duel tension).
CHANNELS = [
    ("dantian_core", "Dantian Core", 1, 2000),
    ("governing_vessel", "Governing Vessel", 4, 80000),
    ("conception_vessel", "Conception Vessel", 7, 2000000),
    ("heavenly_eye", "Heavenly Eye", 11, 240000000),
    ("jade_pillow", "Jade Pillow", 15, 60000000000),
    ("spirit_gate", "Spirit Gate", 19, 8000000000000),
    ("life_gate", "Life Gate", 22, 500000000000000),
    ("bubbling_spring", "Bubbling Spring", 24, 8000000000000000),
]


def main():
    with open(REALMS_PATH, encoding="utf-8") as f:
        realms = json.load(f)
    assert len(realms) == 50, "channels derive from the 50-realm ladder"
    out = []
    prev_cost = 0
    for n, (cid, name, floor, cost) in enumerate(CHANNELS, start=1):
        assert 0 <= floor < len(realms), "floor must sit on the ladder"
        assert cost > 0 and cost > prev_cost, "costs positive + monotonic"
        prev_cost = cost
        out.append({
            "id": "leyline_%02d" % n,
            "channel": cid,
            "name": name,
            "floor": floor,
            "floor_realm": realms[floor]["name"],
            "cost": float(cost),
        })
    lines = ["["]
    for i, c in enumerate(out):
        comma = "," if i < len(out) - 1 else ""
        lines.append(" " + json.dumps(c, ensure_ascii=False) + comma)
    lines.append("]")
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote %s (%d channels)" % (OUT_PATH, len(out)))


if __name__ == "__main__":
    main()
