# PHASE 26 — Stakes at Shrines (0.25.0, save v12 → v13)

Theme: RISK — chosen stakes on the climb. Governs: docs/adr/P25_ARENA_ADR.md
(Amendments 1–2), docs/adr/P25_COMBAT_DESIGN.md (approved), M1 R-1 (executed
with one documented deviation). Q39–Q43 all took recommended options.

## What changed

- Stakes preference (Composed default) pledged at warden-shrine modals;
  shrines also keep their P25 duel entry (chooser + Face-the-Warden).
- Thresholds: Tempered demands brim-full Radiant; Heaven demands fullness
  AND flawless channels. Steady/Shaky bands never move; combine untouched.
- Tempered/Heaven Steady+ head-start: 25% of the crossed requirement.
- Heaven-Shaky demotion: selective state restoration (snapshot at attempt
  start; realm/bottleneck/rate/preps/deviation restored, qi to Late-band
  minimum). Flat +2 scars (the proportional formula reads r>=1 on every
  successful attempt, so it would yield zero — documented deviation).
  Realm-0 fallback: proportional scars, success stands. Victory persists
  through spatial demotion (record-class).
- Heaven-Radiant: +100 herb cache always; tier-crossing marks, cap 7
  (interior Radiants pay material, never marks — negative case tested).
- Heaven marks: ×1.02/stack on the compiled qi rate (branch-gated,
  default path never holds marks). Soul-class persistence: Samsara AND
  ascension; saved/loaded; v13 migration defaults composed/zero.
- Save v12 → v13 (never v2): chained fill-defaults; all stamp assertions
  updated (save_robustness, p5, p6, p8, p21, save_v12 suite).
- `set_stake()`/`get_stake()` API (unknown pledges refused silently);
  `last_demotion` transient record; Attempt button stake glyph (ASCII).
- `tests/p26_stakes_test.gd` (56 checks): stake matrix, demotion
  rollback (rate-source revert — the exploit killer), realm-0 fallback,
  final-crossing victory persistence, rewards/marks/cap, persistence,
  orthogonality, v12→v13 migration, pledge flow, glyph.
- Pledge modal: header + 3 stake buttons + warden challenge; presses set
  and dismiss; Main poll consumes shrine requests into it.

## Tuning model (pinned)

Symmetric HP multipliers cancel: manual-fight win threshold =
sqrt(beast_tick_frac) = 0.5 exactly (verified by independent audit).
HP mult tunes duration only; tick frac is the sole threshold knob.
Refusal floor 0.25 independent. Resolution order simultaneous with
cultivator striking first (matches the exact-0.5 boundary).

## Demotion loop (documented behavior, not a defect)

Heaven-Shaky at the final crossing demotes with +2 scars; late-ladder
exponential rates refill in ~2 ticks, so a stubborn bot cycles:
greedy-heaven bot stalls (no clear @10M ticks, escapable free via
stake switch — stated in the pledge modal). Overpowered-heaven bot
(400% readiness) clears in 1,311,714 ticks / 255 lives. Prepared play
is fair; greedy play pays. No cooldown, no cap: the escape hatch is
the design.

## Manual-opt-in reference bands (R-S13)

- Default (Composed): 73038 ticks / 13 lives (bit-identical, fourth release).
- Tempered greedy: 73008 ticks / 13 lives.
- Heaven greedy: no clear within 10M ticks (demotion loop, escapable).
- Heaven overpowered (400% readiness): 1,311,714 ticks / 255 lives.
- P16 trivialization tripwires are evaluated against DEFAULT runs only.
  A tripwire firing on an opt-in run is not a defect and must not weaken
  the wire — opt-in runs carry their own recorded bands.

## Gates

- 29/29 exit 0 (1252 counted checks, CSV ground truth; reconciled:
  1195 + 1 bench-green + 56 p26. Prior hand-quoted totals are
  superseded — CSV wins, including over my own messages).
- Bench green on verified-idle iron (below).
- 480s plateau: delta(0→240s) +282, delta(240→480s) −41, verdict green;
  gate max(150, 70.5)=150.
- Pacing default bit-identical 73038/13 (re-verified this release).
- Export with docs/* exclusion; PCK delta recorded below; trio verified.
- Q31 carried: flight realm 24. Known edges carried: wander=W rebinders;
  single-tick max tempo (intended); XP farming bounded by tolls+time.
- Rule-11 citation audit: p21 19→20, p25 refusal-divergence + invariance,
  p26 matrix pins, p14/p23 budget comments all carry citations.
- Engine-touch ledger: P24b factor / P25a getter / P25b train_technique
  write / P26b thresholds + demotion + marks + migration (resolution
  surfaces — the most invasive touch yet, full M5 discipline).
- Rebind capture: mouse buttons SUPPORTED (vendor records them; confirm
  flow excludes mice). skirmish_stats: additive read-only (+P25b/P26b
  tick keys, same class).

## PCK note

0.24.0 PCK: 12,639,872 bytes. 0.25.0 PCK: 12,644,208 bytes (delta
+4,336 — stakes code, pledge modal, shrine wiring; negligible).
Evidence stays committed; docs/* remains excluded. Exe+pck+dll
verified together.
