# PHASE 24 — Avatar & Presence (0.23.0, save v12 unchanged)

First GameEngine touch since the migration, executed under full M5
discipline. Theme: PRESENCE — standing in the world beats idling in it.
Governs: docs/adr/P24_PRESENCE_ADR.md (LOCKED, Q29–Q33 ratified).

## What changed

- Input 13 → 19 (rule 11, intentional): six `world_*` actions (WASD/E/F,
  no jump), rebind-replacement semantics, vendor reset, Escape layering
  preserved. `cult_wander` default moved W → V so WASD is unambiguous
  (five rule-11 citations: defaults table, help, tooltip,
  handle_shortcut, p11 assertion). Rebind list height scales with N
  (`max(320, 24×N)`). p21 asserts 19 distinct defaults + wander-is-V.
- Avatar: the Cultivator rig IS the avatar (C1/C2 carry over); states
  idle/walk/meditate/fly; island-clamped movement; follow camera in play,
  orbit framing while panels open (same gating source).
- Presence API: `set_presence()` / `is_presence_active()`; the ×1.5
  premium enters the COMPILED QI RATE by branch (R-S13 auditable).
  Runtime-only: default OFF, reset on apply_state/rebirth/ascension;
  offline path ignores it (load clears first — real-flow tested).
- Flight: `data/flight.json` (Nascent Soul entry, realm 24 — Q31 FINAL,
  pre-blessed as sensible: mid-ladder reward, grounded exploration
  first); `flight_unlocked()` stat-gated rule; toggle refused
  warded-style pre-unlock; sword-mount pose + 2.5× avatar-movement speed
  (R-S7: named as movement scale, distinct from qi-rate PRESENCE_MULT).
- Node markers on a terrain-seed golden ring; interact meditates;
  strides break meditation; avatar-side walls read engine zone rules
  (R13, no duplicate logic) with once-per-lock warded-style notes.
- ContentDB validates flight (schema + ladder-range anchor).
- `tests/p24_presence_test.gd` (59 checks): input contract, avatar,
  gating, budgets, presence matrix, flight gate, meditate, gate
  blocking, node determinism.

## Pacing (the two numbers, side by side)

- Default (presence off): **73038 ticks / 13 lives** — bit-identical.
- Premium-on reference: **71704 ticks / 12 lives** (identical bot
  policy + meditate-while-cultivating).
- Sub-linear as predicted: ×1.5 rate ≠ ÷1.5 ladder — tribulation
  readiness, power gates, and guardian duels dominate stretches rate
  never touches. Bands set around the measurement; no tuning toward
  a prediction was performed.
- P16 trivialization tripwires are evaluated against DEFAULT runs only.
  A tripwire firing on a premium-on run is not a defect and must not
  weaken the wire — premium-on is opt-in with its own recorded bands.

## Gates

- 27/27 exit 0 (CSV ground truth; total in README/sweep file).
- Bench within P11 bands.
- 480s plateau: delta(0→240s) +384, delta(240→480s) −182 vs gate
  max(150, 25% × 384)=150: PASS. (One 142ms hitch, autosave-class;
  verdict uses averages per the probe's own thresholds.)
- p17 ring-reuse still green (|Δ| ≤ 5).
- Export with docs/* exclusion; PCK delta recorded below; exe+pck+dll
  verified together.
- Q31 FINAL: flight unlock realm 24, Nascent Soul.
- Known edge (one line, documented): players who explicitly rebound
  wander to W keep the collision (first-action-wins §7.3); population
  ≈ zero. Fresh-default and never-touched players unaffected.
- Rule-11 citation audit: p21 13→19, p11 shortcut-equivalence, p14/p23
  budget comments all carry citations.
- ADR-002B/ADR-004-status: ADR-004 EXECUTED here; ADR-002B still deferred.

## PCK note

0.22.0 PCK: 12,628,840 bytes. 0.23.0 PCK: 12,631,136 bytes (delta +2,296 —
world/avatar/input additions, negligible). Evidence stays committed;
docs/* remains excluded. Exe+pck+dll verified together.
