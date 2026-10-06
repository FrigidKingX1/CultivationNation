# 0.26.0 ADR — Ley-Line Attunement
Status: DRAFT → pending Q44–Q48.
Theme (single): ATTUNEMENT — the meridians, finally physical.
Cites: ADR-002 Option B (this IS the revisit); rules 1, 2, 5, 7, 8, 11;
R-S7/R-S8/R-S11/R-S12/R-S13/R-S16/R-S19.

## Scope lock
- Engine touch class: rate factor #4 (karma, presence, heaven_mark, now
  attunement) — ONE documented multiplicative factor on the compiled
  qi-rate scale, rule-5 compliant. Branch-guarded: `if open > 0:
  raw *= attunement_mult` (P24b pattern — default path byte-untouched).
  Factor insertion point in the composed chain pinned at 0.26a (order
  is irrelevant when inactive — ×1.0 is IEEE-exact — and pinned for
  active determinism).
- Save: v13 → v14. ONE field: `attunement_open: 0` (sequential channels
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
- Benefit: attunement_mult = 1 + attunement_step_mult × open_count
  (default step 0.08 → full ×1.64; Q45). Linear in count — simple bands,
  natural cap.
- Access: world_interact at a meditation node → modal (attune next /
  meditate / cancel) when the next channel's realm floor is met and qi
  covers the cost. Refusals warded-style, naming the gap (floor or qi).
- Reset semantics: Samsara/ascension → attunement_open = 0 (world-reset
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
- NEW p27_attunement_test.gd (30th; runner +1): sequential enforcement;
  floor gating + warded refusals; cost curve; factor math
  (rate × (1 + step×n)); reset on Samsara/ascension; LOADED on
  apply_state; offline inclusion; orthogonality (composes with presence/
  heaven_mark/stakes, no interaction); default bit-identical pacing;
  v14 migration chained defaults-only; node flow; budgets; viewport pinned.
- All 29 suites retained; touched assertions rule-11 cited (R-S12).
