# Phase P3 Report — 2026-10-04 (reference systems, all original content)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Added (P3a→P3d, in order)
- P3a Origins + Dantian: `choose_origin()` locked per life, `lifespan_bonus`
  wired (Ironhide 80y, Cinder 55y), dantian purity 0–100 (default 80) folds
  into compiled rate as `origin_mult x (0.5 + purity/100)`; breakthrough
  success +2 / failure −2; rebirth resets origin, keeps purity.
- P3b Techniques: `data/techniques.json` (3 original), xp/level
  `floor(sqrt(xp/100))`, +10%/level power bonus via new optional
  `attempt_breakthrough(..., power_mult)` param (old 2-arg calls unaffected).
- P3c Bestiary: `data/beasts.json` (10 original, 3 zones), kills tracking,
  marks none/marked@5000/apex@20000, `seek_unfinished(order)` automation.
- P3d Route + pause: `route`/`next_destination(completed)`/`advance_route`,
  `pause_before_death_years` auto-pauses with `paused_for_death` signal;
  Main honors pause (UI poll only) and logs route; UI shows Origin/Dantian/
  Techniques/Beasts-marked + [PAUSED].
- Save v1→v2: 8 new engine keys defaulted, v0→v1 path intact.

## Gates (all PASS, exit 0)
- `--quit`, live `--quit-after 200`: clean.
- `self_test`: 16/16 (unchanged). `bench`: 10/10 — one stale P2 expectation
  updated to P3 rate formula (test bug, not engine bug; ~1.5M ticks/s).
- `save_robustness`: 23 checks incl. new v1-fixture→v2 (old keys preserved,
  P3 keys defaulted). `soak` 210y: 5 rebirths + mid-soak save/load.
- `p3_test` (new): 41/41 (origins 13, techniques 8, bestiary 7, route/pause 8, content 6).
- Banned-terms grep (17 CoFD-specific terms incl. Sovereign/Paragon/Miasma/
  Returning Cave): zero hits. Total: 90+ checks green.

## No-drift check
Pinned engine/version/paths unchanged. No threads, no sect/map/alchemy (P4),
no borrowed names/text/code. P3 touched: GameEngine, SaveManager (v2),
ContentDB, Main, UIManager, data x3, tests.
