# Phase P12 Report — 2026-10-04 (cultivation systems rework)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

Human playtest verdict on P11: systems complete, but the core felt like a
generic idle with cultivation paint. The brief: research published
cultivation games, then make the LOOP itself ontological — roots, mind,
bottlenecks with teeth, lifespan pressure, karma. Eight subsystems selected
(roots, mind, waves, alchemy-lite, karma, calendar, soul weapons, heirlooms),
deterministic breakthroughs kept.

## Findings (measured, not assumed)

- P12-0 fixed a live NaN path first: uncapped `realm_index` reached 225 in
  the 210y soak; `120·4^n`/`qi_per_tick` overflow float64 at realm ~512, and
  `inf >= inf` passes the gate. Ladder cap + finite guards now; soak prints
  realm=18 with 3 new finiteness assertions.
- The spec's super-exponential capacity formula is mathematically
  incompatible with the P5/P9 exact-x4 assertions — kept x4, partitioned
  each realm into Early/Mid/Late layers (attempts open at 2/3 full).
- Godot's JSON parser rounds 3 of the 50 large `qi_required` entries by 1 ulp
  (proven by throwaway probe, since deleted). Parity assertions now use 1e-9
  relative tolerance — 7 orders above parser noise, far below any curve change.
- `set_realm_table` originally stomped `qi_bottleneck`, defeating P5's
  autoplay-freeze pattern. Wiring config must never mutate progress counters;
  derivation happens on breakthrough/apply_state instead.
- `-s` scripts do NOT get `_ready` during `_initialize` (proven by probe:
  `ready=false`, roots empty; ready by frame 1). P12 tests run frame-driven
  per the P5 convention.
- Full 50-realm clear: 167,098 ticks / 83 lives (~4.6h at 1x, ~28min at 10x).
  Mind hygiene (wander at Strained) beats the degenerate loop (was 203k/31
  without it). Sloppy-bot crossings scar years → lives run hot while aptitude
  compensates ticks; lives band re-derived to 150 (same ~1.8x headroom).

## Added

- 50-realm data-driven ladder (`tools/gen_realms.py`), 7 macro tiers, stage
  names, per-tier lifespans (110y → ageless), 3 layers/realm, realm labels.
- Roots (5 fated affinities, zone sympathy), mind (Serene 1.25 / Steady /
  Strained 0.8 + deviation risk), 4-season calendar with term labels.
- Deterministic tribulation waves (tier counts, regenerating shield, leak vs
  core → Radiant/Steady/Shaky), deviation flaws, lifespan scars, readiness %.
- Alchemy-lite (garden trickle, 4 instant-brew pills, toxicity to 0.5x floor).
- Samsara karma (depth-weighted yield, 3 talent tracks), soul weapon
  (3 paths, wave-tempered, death-proof), gear bequest (+0.02 legacy).
- 39 beasts / 9 zones (gates 0–40), display suffixes to 1e51 (~realm 85).
- Save schema v7 (one bump for all P12 keys), v6 fixture + 10 migration
  checks. `p12_test.gd`: ~130 checks.

## Gates (all PASS, exit 0)

- `--quit` clean. All 14 suites green: self 16, bench 11, save 45, p3 41,
  p4 48, p5 31, p6 37, p7 19, p8 33, p9 18, p10 14, p11 19 (167098/83),
  p12 ~130, soak (realm ≤ 18, finite chain), pacing diagnostic parity.
- Web + Windows builds on disk. Banned-terms grep clean in game files.
- Total: ~470 checks green.

## No-drift check

Pinned engine/version/paths unchanged. No file restructure (flat layout kept:
blast radius was 9 autoload refs + hardcoded scene paths + 15 test files), no
lint stage (gdtoolkit absent, offline policy holds), float retained behind a
data-derived ladder (BigNum stays display-only), no probabilistic gating, no
Ascension tier, no borrowed names/text/code. P12 touched: GameEngine (all six
slices), SaveManager (v7), ContentDB (validation), Main + UIManager + scene
(pill/soul/talent UI), data (realms 50, beasts 39 + elements), BigNumber
(suffixes), tools/gen_realms.py (new), all affected suites + p12_test (new),
README.
