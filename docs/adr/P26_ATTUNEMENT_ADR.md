# 0.26.0 ADR — Ley-Line Attunement
Status: DRAFT → pending Q44–Q48.
Theme (single): ATTUNEMENT — the meridians, finally physical.
Cites: ADR-002 Option B (this IS the revisit); rules 1, 2, 5, 7, 8, 11;
R-S7/R-S8/R-S11/R-S12/R-S13/R-S16/R-S19.

## Scope lock
- Engine touch class: rate factor #4 (karma, presence, heaven_mark, now
  attunement) — ONE documented multiplicative factor on the compiled
  qi-rate scale, rule-5 compliant. Branch-guarded: `if leyline_open > 0:
  raw *= leyline_mult` (P24b pattern — default path byte-untouched).
  Naming (0.26a finding): `attunement` is TAKEN (P15 per-art drill dict +
  attunement_of + save key) — the meridian count uses the `leyline_`
  prefix throughout (`leyline_open`, `leyline_mult()`,
  `LEYLINE_STEP_MULT`, `data/leylines.json`, `p27_leylines_test.gd`).
  Insertion point pinned (0.26a): scripts/GameEngine.gd `_recompute_rate`
  after the heaven-marks branch (L317-318), before the finite guard
  (L319) — order irrelevant when inactive (x1.0 IEEE-exact).
- Save: v13 → v14. ONE field: `leyline_open: 0` (sequential channels
  make a count sufficient). Chained defaults-only migration; never v2.
- Persistence class (R-S11, stated): WORLD-CLASS — cleared on Samsara
  and ascension, same class as gear/techniques. NOT soul-class: karma/
  Dao own the cross-life axis, heaven_mark the cross-life micro axis;
  attunement is the this-life build axis. Axes stay orthogonal.
- Offline: attunement is SAVED state → applies to offline gains
  (gear-class), explicitly unlike presence (runtime-only). Tested.
- Input: NO new actions (node + ModalManager, stakes pattern). Map stays 20.
- No new class_name. GDScript. Headless-first. Forward+.

## The system
- 8 channels, sequential, the classical meridian sequence (Dantian Core
  → Governing Vessel → Conception Vessel → Heavenly Eye → Jade Pillow →
  Spirit Gate → Life Gate → Bubbling Spring — generic traditional
  vocabulary, consistent with the project's existing qi language).
- Generated table data/leylines.json via tools/gen_leylines.py (sibling
  discipline; never hand-edited): per-channel cost curve + realm floor.
  ContentDB validation: unknown fields reject; exactly 8 channels;
  sequence immutable; floors in realm range; costs positive + monotonic.
- Benefit: leyline_mult = 1 + LEYLINE_STEP_MULT × leyline_open
  (default step 0.08 → full ×1.64; Q45). Linear in count — simple bands,
  natural cap.
- Access: world_interact at a meditation node → modal (attune next /
  meditate / cancel) when the next channel's realm floor is met and qi
  covers the cost. Refusals warded-style, naming the gap (floor or qi).
- Reset semantics: Samsara/ascension → leyline_open = 0 (world-reset
  path); apply_state LOADS it (saved state — opposite of presence).

## Phases (release-qualified per R-S19)
- 0.26a: READ-ONLY verification — extract the compiled-rate composition
  site + factor chain order (karma/realm/presence/heaven_mark as found),
  pin insertion point; calibrate the cost curve base against the live
  economy (target: channel 1 early-realm affordable, channel 8 a mid-game
  sink); generator + validation; paste → auditor sign-off BEFORE internals.
  GATE: sign-off; generator green.
- 0.26b: engine factor + node UX + resets + v14 migration.
  GATE: default pacing bit-identical 73038/13; attunement matrix green.
- 0.26c: sweep 30/30; opt-in reference bands (bot attunes as affordable);
  480s plateau (same gate); export + PCK delta vs 12,644,208;
  report + DECISIONS + v14 evidence + version 0.26.0 in ONE commit
  (R-S16); tag + push [CONFIRM ×2].

## Tests
- NEW p27_leylines_test.gd (30th; runner +1): sequential enforcement;
  floor gating + warded refusals; cost curve; factor math
  (rate × (1 + step×n));   reset on Samsara/ascension; LOADED on
  apply_state; offline inclusion; orthogonality (composes with presence/
  heaven_mark/stakes, no interaction); default bit-identical pacing;
  v14 migration chained defaults-only; node flow; budgets; viewport pinned.
- 0.26a cost calibration (verified against data/realms.json qi_required;
  agent-proposed bases for R08/R16 corrected): floors/costs —
  ch1 R02 2,000 (req 4,260) · ch2 R05 80,000 (req 168,960) ·
  ch3 R08 2,000,000 (req 4,177,920) · ch4 R12 240,000,000 (req
  503,316,480) · ch5 R16 60,000,000,000 (req 128,849,018,880) ·
  ch6 R20 8,000,000,000,000 (req 32,985,348,833,280) ·
  ch7 R23 500,000,000,000,000 (req 2,111,062,325,329,920) ·
  ch8 R25 8,000,000,000,000,000 (req 33,776,997,205,278,720).
  Early channels ~0.5× floor requirement (affordable first-life);
  late channels ~0.24× (mid-game sink, purchasable within tens of
  floor-rate ticks).
- All 29 suites retained; touched assertions rule-11 cited (R-S12).
