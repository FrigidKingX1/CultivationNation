# Phase P18 Report — 2026-10-04 (gradual pacing)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

The ladder cleared too fast to feel like cultivation: realm 1 fell in 72
ticks (under a second at the 10x default). P18 front-loads the climb so
the early game takes sessions to lift off, then rebirth compounding
accelerates the back half.

## Findings (measured)

- Baseline (pacing.gd): 70738 ticks / 11 lives; realm 1 at 72, realm 3
  at 584; per-realm effort flat ~1300–1700 (steady by P11a design).
- Root cause of instant onboarding: `set_realm_table` never wired the
  current bottleneck, so realm 1 always cost the 120.0 default. Any cost
  change would have been dead without the fix.

## Added

- `front_load()` in tools/gen_realms.py: 10x at realm 1 decaying
  linearly to 1x by realm 9, pure 4x after. data/realms.json regenerated
  (realm 1: 120 → 1200; campaign total ~5.07e31, still compact).
- Engine wires the table bottleneck on `set_realm_table` (load path
  already recomputed the same derived value — order-safe both ways).

## Gates (all PASS, exit 0)

- Re-measured: 73066 ticks / 13 lives (realm 1: 72→705, realm 3:
  584→2562, late per-realm untouched at ~1700). All p11 bands hold
  unchanged; comment updated to the new measurement.
- p5/p9 parity rewritten front-load-aware (monotonic + pure 4x past
  realm 9); p12 label test reads the wired bottleneck. Full sweep green.

## No-drift check

Pinned engine/version/paths unchanged. Data owns costs (gen script +
JSON), engine only reads. No Ascension, companions, or sect facilities.
