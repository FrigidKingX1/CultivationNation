# Phase P14 Report — 2026-10-04 (2.5D presentation)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

P13 made the mechanics honest; the game still presented as a text wall with
one column of buttons. P14 puts the cultivator in a visible world: fixed
orthographic 3/4 camera, ink-wash low-poly diorama, procedural billboards,
post-process ink grading — with the sim contract untouched (visuals read
state, own nothing) and every headless suite still green.

## Findings (measured, incl. two live-render bugs suites could never catch)

- Renderer gl_compatibility → Forward+: zero suite impact (re-ran all 15).
- First-ever screenshot proved the live layout was ALWAYS broken: unwrapped
  stats hogged the row (log crushed to 59px), 40+ action buttons sat below
  the 720 fold with no scroll — every post-LifeGrid system (sect, map, gear,
  pills, soul, talents) was unreachable in live play. Fixed with an
  ActionScroll wrapper (mechanical 8-file path migration) + stats autowrap.
- ViewportTexture path sub-resources never resolve (0x0, flat grey): bind
  `svp.get_texture()` at runtime. Ink shaders on TextureRects must sample
  TEXTURE/UV (assigned texture), never screen_texture/SCREEN_UV (captures the
  empty main viewport). Both proven by screenshot before/after.
- Live render verified by screenshot: diorama, cultivator, red readiness
  ring at 66%, aura motes, weather, graded palette, teaching log lines.
  Frame probe: 60–90 FPS on RTX 2080 SUPER. Budgets measured (59 nodes,
  334 particles) and test-enforced (caps 160 / 384-per-effect / 768 total;
  verified the test fails when tightened).

## Added

- `scripts/SpriteFactory.gd` (single factory: cultivator/beast/glow,
  cached, headless-safe), `scripts/WorldView.gd` (camera, env, diorama,
  cultivator rig, weather, tiers, beasts, tribulation sequences,
  death/rebirth, readiness ring, budget helpers),
  `assets/shaders/ink_wash.gdshader` (edge/grain/bleed/vignette),
  `tools/frame_probe.gd` (FPS + screenshot probe).
- Main.tscn: WorldViewport (own 3D world) + WorldDisplay (ink-graded
  TextureRect) + ActionScroll + stats autowrap + translucent HUD panels.
- `p14_test.gd` (55 checks: factory, shell, diorama, palettes, cultivator,
  weather, tiers, beasts, budget, tribulation lifecycle, layout repair).

## Gates (all PASS, exit 0)

- `--quit` clean. All 16 suites green (15 + p14): pacing untouched
  (167712/28), save schema stays v7 (no sim-state change in P14).
- Windows build on disk (re-exported after state.json). Banned-terms grep
  clean in game files (new names: zones, beasts, pills, talents, soul paths
  all original compounds).
- Total: ~555 checks green.

## No-drift check

Pinned engine/version/paths unchanged. Flat layout, no class_name, data-free
engine (WorldView reads ContentDB display data only), defaulted attempt args,
migration history intact, no borrowed names/text/code (all art procedural at
runtime). P14 touched: project.godot (renderer), Main.tscn (world dock,
scroll, autowrap), Main.gd (texture bind, pill-refresh signature), UIManager
(translucency), new scripts/shader/probe above, path migration across 8
files, README. No Ascension, companions, or sect facilities (per brief).
