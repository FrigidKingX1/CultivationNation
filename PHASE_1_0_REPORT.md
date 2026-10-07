# PHASE_1_0 REPORT — 1.0.0 Readiness (1.0a/b/c)

Release: 1.0.0. No versioned release between 0.27.0 and here except the
sunset decision (rides as docs, per Q59). Save stays v14. Freeze (G3)
held across 1.0a/b/c: one defect-class fix total (floater coalesce).

## Gates

- Sweep (G1, post-fix tree): 32/32 exit 0, CSV **1414 = 1411 + 3**
  (p28 floater checks; raw bytes, closes exactly).
- Pacing pin: EXPECTED_PACING=(73038, 13) green in-sweep (six prose
  verifications + mechanism, zero violations, era closed unbroken).
- G2 first-session driver: 0 stumbles pre- and post-fix (modal fork
  handled both ways); presence, den win, shrine dormant, ley-line ok,
  flight refusal evidenced with per-step timings + both-skins captures.
- Plateau: +180 / +62 vs gate 150 (first half in the 139–228 churn
  band; single run justified, no re-run).
- Leak trace: flat (baseline 2 exit-resource lines; scene suites as
  before; p28 newest scene suite: 2).
- PCK: 12,652,812 (0.27.0) → **12,653,196** (delta +384 — floater
  coalesce, help row, version string). Exported AFTER the 1.0.0 stamp
  (0.26c lesson, applied pre-commit twice now). Trio verified.
- CI: `gate.yml` landed + YAML-validated; first green run links from
  the release push (maiden voyage on the 1.0.0 tree).
- R-S16: this report + DECISIONS + 1.0.0 in ONE commit; tag + push on
  confirms.

## G5 envelope (declared tested envelope)

- Bench (final idle-iron, R-S19 — the only bench gate of record):
  9.0% load prior, 50k ticks in 4150ms (12,048 ticks/sec), PASS.
- Soak: 144fps avg (6.94ms), worst 7.41ms; objects +180/+62;
  static 75 → 81MB. Verdict lines green (frames/objects/ms).
- Envelope: ≥60fps on RTX 2080-class hardware at 1280x720; object
  growth bounded per the plateau gate; memory stable across 480s.

## G6 platform statement

Windows-only · Forward+ · pinned Godot 4.6.3
(4.6.3.stable.official.7d41c59c4) · GDScript · save v14 ·
no new class_name. In README and here.

## G4 freshness

README: CI badge (new), 32 suites / 1414 checks, world-play section,
arena/stakes/ley-line/affordance systems, schema v14, G6 statement.
CHANGELOG through 1.0.0 (8 shipped tags + this release).

## U-ledger dispositions (honest close)

- (a) "menu with a screensaver": ANSWERED — every core verb has world
  presence (nodes, shrines, dens, flight); the world is the default
  surface (0.22–0.23 evidence: captures, affordance suite).
- (b) no moment-to-moment agency: ANSWERED — 20-action map, movement,
  interaction, presence premium for being there (0.23 + G2 path).
- (c) combat absent/toy: ANSWERED — arena (gated clock, invariance,
  tempo bonus) + warden duels (0.24 + G2 den win).
- (d) pacing/economy feel: RESOLVED BY DECISION ON DATA, not by play
  experience — sunset SHIP THE CURVE (Amendment 2); journal door open
  post-1.0; P4 runbook armed. 1.0 does not overclaim this.
- (e) visuals/art: ANSWERED — low-poly ratified (Q25); capture record
  through 1.0b both-skins shots; final call was owner satisfaction.

## What ships

Fifty generator-owned realms; deterministic readiness-gated
breakthroughs; nine-island world (walk/fly/meditate); seven ceremonial
warden duels; gated-clock arena; chosen stakes; ley-lines at nodes
(x1.08 each); v1→v14 save chain; 1,414 checks; pacing pin on every
push; audit ledger fully disposed. The curve we measured, the world
that tells the truth, and a version number that says it's done.
