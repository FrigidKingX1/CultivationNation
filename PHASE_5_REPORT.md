# Phase P5 Report — 2026-10-04 (polish: achievements, layout, VFX, balance)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Added (P5a→P5d, in order)
- P5a Achievements: `data/achievements.json` (21 original), rule-driven unlocks
  polled only on events (rebirth, breakthrough, mark/level transitions,
  sect/recruit/refine) via caller-supplied rules — no per-tick evaluation.
  Save v3→v4 (`achievements: []`); v0→v3 chain intact.
- P5b Responsive layout: `Columns` HBox→GridContainer (3 cols desktop);
  `apply_width()` mapping (<700px → 1 col) shared by live resize and tests.
- P5c Breakthrough banner: hidden Label + 0.5s fade Tween, fired by Main on
  auto-tribulation success.
- P5d Balance + docs: monotonic-4x curve, <5min realm-1 onboarding, finite
  tier-1 total with compact formatting — all as deterministic math checks.
  README rewritten (all suites, systems, honest pacing note).

## Gates (all PASS, exit 0)
- `--quit`, live `--quit-after 200`: clean.
- `self` 16/16, `bench` 10/10, `save` 29 (v0/v1/v2→v4), `p3` 41/41,
  `p4` 48/48, `soak` 210y, `p5` 31/31.
- Banned-terms grep: zero hits in game files (only prior report prose
  documenting the check). Total: ~175 checks green.

## Test lessons (kept for future phases)
- `-s` scripts run `_initialize` before delivered `_ready`: scene-dependent
  asserts must run from `_process` frames (p5_test stage machine pattern).
- Live autoplay scenes interfere with UI assertions (Main re-triggered the
  banner via a real breakthrough) — freeze autoplay state in VFX tests.
- Headless dummy display may ignore resizes: test `apply_width()` mapping
  directly instead of real viewport changes.

## No-drift check
Pinned engine/version/paths unchanged. No new content systems beyond the
approved 21 achievements, no threads, no export changes (still probe-only),
no borrowed names/text/code.
