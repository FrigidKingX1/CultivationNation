# Phase P16 Report — 2026-10-04 (reliability and polish)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

The biggest P15 finding was a missing core promise: the saved timestamp was
never used — an idle game with no idle progress. P16 delivers offline gains
first, then guards pacing against silent trivialization, then makes sect,
alchemy, and deviation visible in the world.

## Findings (measured)

- Pacing baseline re-confirmed: 70,738 ticks / 11 lives (P15 numbers hold).
- Play evidence via real UI handlers (temp probe, deleted after): 4 lives,
  soul bound, talents bought, 10/43 achievements, per-life screenshots.
  Probe policy stalls at realm 1 (never breathes — stale pre-keystone
  policy, artifact not bug).
- Lower bands set from baseline with ~2.4x headroom: clear ≥ 30k ticks,
  lives ≥ 5 (uppers + fails==0 untouched).

## Added

- Offline gains by real-tick simulation (1 month/sec, 8h cap): no attempts
  fire (gates never skipped, Qi pools), deaths follow choosable
  offline_mortality — Vigil stalls at death's door (default), Unfettered
  resolves death/rebirth/karma unseen. Welcome-back summary via log lines;
  Main connects signals before load. Seclusion cycle button (P17 relocates
  to settings). Save schema v8→v9 (directive defaults vigil).
- `p16_test.gd` (10 checks: offline through live boot + toggle) and a
  save_robustness offline section (zero/cap/pool/vigil/unfettered/
  validation/fixture/gap-soak).
- Representation: sect duty dots (8 shown), cauldron + herb bundles (25
  each, 5 max), deviation red pulse, 4 beast silhouettes by hash through
  the existing factory. No new particle systems; budget test green.

## Gates (all PASS, exit 0)

- `--quit` clean. All 18 suites green: pacing bands inside on both sides
  (70738/11, fails 0), save stamps v9, p14 representation + budget green.
- Windows build on disk (re-exported after state.json). Banned-terms grep
  clean. Screenshot probe after the HUD change (SeclusionBtn): world + HUD
  correct, ~60 FPS.
- Total: ~660 checks green.

## No-drift check

Pinned engine/version/paths unchanged. Flat layout, no class_name, data-free
engine (offline runner lives in SaveManager, calls engine ticks), defaulted
attempt args, migration history intact, no borrowed names/text/code. P16
touched: GameEngine (mortality directive, death_looms, state), SaveManager
(apply_offline, v9), Main + scene (connect order, offline call, summary,
Seclusion button), WorldView + SpriteFactory (representation, silhouettes),
tests (p16 new, save/p11/p14 extensions), README. No P17/Ascension,
companions, or sect facilities.
