# Phase P2 Report — 2026-10-04 (idle-core hardening, no new systems)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Changes
- GameEngine: compiled-rate cache `_cached_qi_per_tick` recomputed only on
  rebirth / set_activity_rate / apply_state / ready (never per-tick).
  `set_time_scale()` + `effective_rate()` clamp to 1–1000x; low-power caps at
  100 tps. No threads (deliberate — keeps headless tests deterministic).
- SaveManager: explicit `engine_ref` (set by Main.gd, used by tests) replacing
  absolute-path `get_node("/root/...")` which is illegal in `-s` context.
  Real bug found by the new test, fixed. `_migrate()` now handles v0 fixtures
  (legacy `age` → `age_years`, fills defaults, stamps v1).
- Main.gd: uses `set_time_scale()`, wires `SaveManager.engine_ref`.
- soak_test.gd: extended to 210 in-game years, requires 2+ rebirths, includes
  mid-soak save/load roundtrip; fixed age-18-after-rebirth false failure by
  asserting tick count instead.

## Gates (all PASS, exit 0)
- `--headless --quit`: PASS.
- `self_test.gd`: 16/16 PASS (unchanged).
- `bench_test.gd` (new, 10 checks): 50k ticks in ~27ms (~1.85M ticks/sec, GDScript
  direct loop); low-power 100 vs normal 5000 steps at 1000x/1s; clamp 1–1000x;
  compiled-rate math. PASS.
- `save_robustness_test.gd` (new, 14 checks): roundtrip, backup rotation holds
  prior state, corrupt-primary falls back to backup, v0 fixture migrates.
  (One expected Godot JSON ERROR line = the deliberately corrupt primary.) PASS.
- `soak_test.gd` (extended): 2520 ticks, 5 rebirths, realm 3, mid-soak
  save/load OK. PASS.
- Live scene `--quit-after 200`: PASS, exit 0.
- Web export probe: fails as predicted — no `export_presets.cfg` and no export
  templates installed. Probe-only per plan; does not fail the phase. Creating
  presets + downloading 4.6.3 templates is a separate future task.

## No-drift check
Pinned engine path + version unchanged. No new content systems, no threads,
no borrowed names/text/code. P2 touched only: GameEngine, SaveManager, Main
wiring, tests, docs.
