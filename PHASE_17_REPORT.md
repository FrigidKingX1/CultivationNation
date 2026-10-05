# Phase P17 Report — 2026-10-04 (UI overhaul)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

P16 made the mechanics honest; the interface was still a 40-button scroll
column over five undifferentiated text lines, with 2 of 5 arts unreachable
and no title, settings, or version anywhere. P17 rebuilds the interface
around a thin HUD + tabbed panels, modern and sleek, with zero sim changes.

## Findings (measured)

- Audit via screenshots (tools/shots/step0_*): scroll-column burial, dense
  stats blob, text-only buttons with no tooltips/disabled states, no
  title/settings/version, unreachable Mistwalk/Stonebell (no buttons).
- UI_SPEC.md written first (layout/type/spacing/ink tokens/components/
  motion/focus rules) and reviewed against screenshots before building.
- Fonts vendored (Ma Shan Zheng display + Inter body, OFL, license filed);
  glyph coverage tested per font — no string replacements needed.
- Full clear still 70738/11 after the overhaul: zero sim changes proven.

## Added

- Code-built UITheme (diffable/testable over .tres) + UIComponents.stat_row;
  version 0.17.0; full re-skin in place, suites green as the control.
- Thin HUD: top bar (realm/age/animated Qi glow bar/mind/season/speeds/
  pause/sound/panels), two-row dock (focus/attempt/stalk/wander +
  recruit/gang) with hotkey hints, title overlay (save-gated boot hold;
  fresh boots unchanged), toasts (cap 3, auto-expire), collapsible
  filterable chronicle (defaulted category arg), animated Qi bar on
  refresh-exempt labels, readiness symbols (glyph-restricted »/!/x).
- Nine-tab SidePanel (Sect/Alchemy/Arts/Soul/Samsara/Beasts/Deeds/Records/
  Settings); all management moved, old Columns tree deleted; SfxSynth.volume;
  save export/import with backup rotation; FileDialog wiring; bestiary/
  achievement/attunement builders (tab-open + signature-gated refresh);
  tooltips on every stat and dynamic button (data descs); F1 help + Esc
  layers; p16 presses Continue through title.
- Step 4: pooled floating numbers via unproject (cap 12, tween-callback
  recycle, no custom signals); shine sweep as overlay child (a canvas
  material would replace the button draw); blur modal on title/help,
  screenshot-verified against the P14 grey failure; input contract test
  (panels STOP, world IGNORE); panel open fade.
- `p17_test.gd` (49 checks: theme/fonts/stat-row/coverage, census of ~40
  controls, title, topbar, toast cap/expiry, filter, animated bar, panels,
  tabs, Esc/F1, focus, signal toasts, input contract).

## Gates (all PASS, exit 0)

- `--quit` clean. All 19 suites green: path migration across 8 files in-step
  (p6/p7/p8/p10/p12/p13/p15/p16/p17), text asserts retargeted with substrings
  kept (records, denominator, log lines), p5 responsive redefined as compact
  labels. Caught live: duplicate PanelsBtn, orphaned SceneBox-less census
  paths, season-flaky readiness text (pinned Spring), log double-append
  (same class as the P13 .text lesson), title wire path (silent null-skip).
- Windows build on disk (re-exported after state.json). Banned-terms grep
  clean. Screenshots at 1280/1920/3840 in tools/shots/; FPS 60-90 holds.
- Total: ~720 checks green.

## No-drift check

Pinned engine/version/paths unchanged. Flat layout, no class_name, data-free
engine (UI reads state/signals only, owns nothing), migration history intact,
no borrowed names/text/code (all art + fonts original or OFL). P17 touched:
scenes/Main.tscn (HUD tree, tabs, title, help, float layer, font), scripts/
Main.gd (title flow, toasts, filter, builders, settings, help, shine, panels),
UIManager.gd (theme apply, dual log + filter, toasts, floats, topbar,
animated bar, records/achievements rows), UITheme.gd + UIComponents.gd (new),
SfxSynth.gd (volume), SaveManager.gd (export/import), fonts/ (new), tests
(p17 new + Step-2/3 migrations), README. No Ascension, companions, or sect
facilities. Visual taste remains yours to judge on the build.
