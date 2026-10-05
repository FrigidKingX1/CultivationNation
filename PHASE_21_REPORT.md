# Phase P21 Report — 2026-10-04 (adopted systems + lofi)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation
Version: 0.20.0. Save schema v11. P20 scope absorbed (never executed standalone).

## Motivation

With the clean-room rule lifted for this personal build, adopt community
systems directly — modified to fit — and give the game real music. Every
adoption is measured against the proven systems it touches; evidence, not
assumption, decides what ships as primary.

## Step 0 — vendor drops + music (autonomous)

- Byte-identical drops + licenses: ChronoDK Big.gd (Godot 4.1.x) in
  `third_party/ChronoDK-Big/`; shoyguer big-number v1.1 (Windows bins only,
  compatibility_minimum 4.6) in `addons/big_number/`; four Maaack runtime
  plugin dirs (577 files) in `addons/` (plugin_updater/clean_copy_examples
  skipped: installer helpers, no runtime value); Kingsmai starter-kit
  `themes/` in `third_party/KenneyStarter/` (texture-gloss variants clash
  with ink-prestige — architecture reference only). Editor plugins are NOT
  enabled (headless-first pipeline; runtime parts wired manually).
- Lofi, acquired autonomously: Pixabay blocks scrapers and itch packs need
  interactive purchase, but soundimage.org serves direct OGG links —
  `title_lofi.ogg` (Game Menu Looping), `game_lofi.ogg` (Mind Bender),
  `triumph_lofi.ogg` (Treasure Cave), ~10.5MB total, attribution filed.
  OGG loops cleanly in-engine; headless `load()` proven.
- Export ships everything (directory `exclude_filter` globs are dead in
  this preset — proven: tests/tools/vendor all present in the 11.6MB PCK,
  same as every prior release; file-extension globs like `*.md` do work).
  DLLs, OGGs, and addon runtimes verified present. ATTRIBUTION rewritten
  (clean-room paragraph retired), project.godot header updated.

## Step 1 — Big backends, verdict: GDScript stays

- Adapter delegates arithmetic kernels to native behind `use_backend()`;
  guards, comparisons, display, and save shape are backend-independent.
- Probed native quirks, all guarded: setters normalize mantissa in place
  leaving exponent stale; native `normalize()` drops the shift; `minus()`
  mis-signs true underflow; div-zero pushes an engine error.
- VERDICT (measured): native ~28% SLOWER per tick (20.9s vs 16.4s per
  200k ticks — call overhead dominates at this op size), pacing
  tick-identical 73066/13, values bit-identical. GDScript stays primary;
  native stays vendored, wired, and CI-proven (bignum native-parity, 55).
  ChronoDK remains reference-only: the native core descends from it, so
  its lineage is adopted optimized; a literal third backend was rejected
  as doubled verification cost for zero gameplay gain.

## Step 2 — music + buses + persisted settings

- Maaack music controller as autoload (renamed MaaackMusic: vendor
  `class_name` collision) with title/game/triumph direction, idempotent
  requests, teardown-safe pump + `_exit_tree` detach (vendor clones
  exiting players — caught live). SFX bus routing + runtime Music/SFX
  bus install (their installer is editor-only; headless never runs it).
- Hover/focus whispers via the UI-sound controller (pressed deliberately
  empty — the explicit click path would double).
- Settings persist via vendor player_config (volume, music, glow, skin);
  SfxSynth.volume + VolumeSlider path preserved; mute stays save-backed.
- Rebindable keys via runtime InputMap actions + embedded Maaack
  input/video options (display-guarded: key-name lookup needs a display
  server; headless skips vendor UI, actions register everywhere).
  Audio options scene cut (would duplicate our sliders).

## Step 3 — fitted interface systems

- Hard tab gates from `data/reveal.json` (derived, never stored; locks
  gate rail navigation only — scene suites bypass via direct paths;
  first poll baselines silently). Screenshot shows locked Soul/Samsara.
- Press squash on shop rows (+ existing bulk toasts; pool reserved).
- First-session coach overlay (derived steps, `coach_done` persists).
- Transition veil for boot/import/export/ascend (scene-loader pattern
  fitted single-scene — the vendor autoload stays out as an idle
  tree-wide watcher with zero runtime value).
- Parchment alt skin (code-driven variant architecture a la starter kit;
  OFL fonts protected from theme overrides).

## Gates (all PASS, exit 0)

- Gate clean. All 23 suites green (~920 checks; new p21_test 52).
  Pacing 73066/13 untouched (both backends). FPS 77 (band parity).
  Screenshots: coach + unlock lines (boot), locked tabs (panels).
  Save v10→v11 migration proven by fixture. Windows build re-exported;
  PCK content verified (DLLs, OGGs, addon runtimes).

## No-drift check

Pinned engine/version/paths unchanged. Flat scripts (no new
`class_name` in our code; vendored globals documented), data-free engine
(reveal rules injected; tab names never hardcoded in engine), chained
fill-defaults migrations, DECISIONS.md line per change, headless-first
(all vendor display dependencies guarded). 43 achievements, 50 realms,
9 tabs preserved. Visual taste remains yours to judge on the build.
