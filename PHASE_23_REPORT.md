# PHASE 23 — Macro-Tier Guardians (0.21.0, save v12)

Implements the locked M1 ADR-001: seven macro-tier wardens as a new,
separate, additive system. Deterministic duels, no RNG. Victories persist
rebirth AND ascend. Meridians deferred (ADR-002), stakes tabled (R-1),
Legacy Echo deferred (R-2) — none of that scope is in this phase.

## Design (locked, see docs/adr/M1_MIGRATION_ADR.md)

- One guardian per macro tier; each bars the breakthrough LEAVING its tier.
  Guardians 1-6 gate the six tier crossings; guardian 7 gates the final
  ladder-clearing breakthrough (realm 49 -> victory).
- Duel model: N-wave (3+tier) power comparison reusing the tribulation
  resolution family. Defense is the same combined number as `is_ready`;
  guardian power is the boundary tribulation power (generator-computed),
  so a cultivator ready to cross blocks every strike and wins Radiant by
  construction. Outcomes mirror Radiant / Steady / Shaky / Defeat.
- Failure: proportional Qi cost only — no death, no stage loss, no scars.
- Reward (first win only): proportional Qi cache (0.25x boundary
  requirement) + 100 technique XP on the focus art + record entry.
- Duel entities are disjoint from the beast codex (no id reuse, kill
  counts untouched).

## Caught during implementation

1. **Power-scale mismatch (design bug, fixed before shipping).** The first
   cut set guardian power to 0.8x the boundary *Qi requirement* (millions)
   while duel defense runs on the *tribulation-power* scale (tens). The
   pacing bot stalled forever at the realm 7->8 crossing, losing unwinnable
   duels. Fix: generator reads `trib_power` from realms.json (40..250), the
   exact scale the defense uses. Lesson: any power comparison must state
   its scale explicitly; the ADR now does.
2. **Paren-count parse error** in the reward line (7 opens, 8 closes) —
   caught by `--check-only` bisection, fixed before any suite ran.
3. **`//` comment slips** (2x, author's recurring slip) — caught by the
   author's own habit of re-reading diffs; the p21 `//` scanner stands guard.

## Changes

- `tools/gen_guardians.py` (new): generates `data/guardians.json` from
  `data/realms.json`. Never hand-edit the data file.
- `data/guardians.json` (new): 7 wardens, provisional names flagged
  (Q21 naming approval deferred to the 0.21.0 report — this report:
  names stay provisional).
- `scripts/ContentDB.gd`: loads + validates the guardians table
  (required keys + `guardian_` id prefix).
- `scripts/GameEngine.gd`: `set_guardian_defs`, `guardian_gate()`,
  `attempt_guardian()`, `guardian_roster()`, `guardian_defeated()`,
  gate check in `attempt_breakthrough` (refusal marked `Warded`),
  `guardians` state with validated `apply_state`, explicit persistence
  through rebirth and ascend.
- `scripts/SaveManager.gd`: `SAVE_VERSION` 11 -> 12 + v11->v12
  fill-defaults migration.
- `scripts/Main.gd`: def wiring, Beasts-tab `GuardianLabel`/`GuardianBox`
  roster with Challenge buttons, `_on_guardian` duel handler, Attempt
  button `· Warded` suffix + warden tooltip, manual refusal naming the
  warden, auto-duel in the live loop with once-per-fill loss notes.
- `scenes/Main.tscn`: `GuardianLabel` + `GuardianBox` under Beasts.
- `tests/pacing.gd`: policy duels when warded.
- `tests/guardians_test.gd` (new, 79 checks): roster, gates, duel
  win/defeat/proportionality, persistence, save shapes, unwired safety,
  live-scene roster + UI challenge flow.
- `tests/save_v12_migration_test.gd` (new, 9 checks): version, v11
  defaults, progress preservation, roundtrip.
- Updated for v12 stamps: save_robustness (10), p5, p6, p8, p21 migration.
- Updated for the gate: p15 live victory now refuses, duels via the roster
  UI, then clears (4 checks added).

## Gates

- All 25 suites green (1049 counted lines; guardians 79, save_v12 9).
- Pacing re-measured with gates + duels: full clear **73038 ticks /
  13 lives** vs 73066/13 baseline (rewards shave 28 ticks; bands hold,
  no wall added).
- Windows build re-exported at 0.21.0 with PCK content check.
