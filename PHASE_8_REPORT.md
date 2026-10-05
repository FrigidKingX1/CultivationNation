# Phase P8 Report — 2026-10-04 (gates + guidance)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

Two gaps: travel accepted any grounds from life start (realms gated
nothing), and 40+ buttons greeted new players with zero guidance. P8 gives
progression teeth and a first-time voice. No schema change was planned, but
hints + visitation are new persisted state — save v5→v6 instead.

## Added (P8a→P8d, in order)
- P8a Zone gates: `min_realm` per beast (Dewfield 0 / Ashbarrow 2 /
  Gloamdeep 4), enforced in `travel_to`, surfaced as locked buttons and
  "wants realm N" log lines. ContentDB validation requires the key.
- P8b Tutorial hints: 8 original one-liners via `due_hints()`/`mark_hint()`,
  polled at UI cadence, once-ever, persisted. States covered: origin,
  bottleneck, pause setup, travel, sect, duties, forge, legacy.
- P8c Visitation + Wander: `nodes_visited` on travel; Wander picks richest
  unwalked walkable grounds, else unfinished-quarry grounds, else "". Gate
  bug in first Wander draft (ignored `min_realm`) caught in layout review,
  fixed before tests ran.
- P8d Both builds re-exported byte-fresh; README updated.
- Save v5→v6: `hints_seen`, `nodes_visited`.

## Gates (all PASS, exit 0)
- `--quit`, live `--quit-after 200`: clean.
- `self` 16/16, `bench` 11/11, `save` 35 (new v5→v6 case), `p3` 41/41,
  `p4` 48/48, `p5` 31/31, `p6` 37/37, `p7` 19/19, `soak` 210y,
  `p8` 33/33 (one test-setup miss on hunt order, fixed — engine was right).
- Web + Windows builds on disk.
- Banned-terms grep: zero hits in game files. Total: ~265 checks green.

## No-drift check
Pinned engine/version/paths unchanged. No new acts/beasts/gear, no alchemy,
no balance retune, no threads, no text entry, no borrowed names/text/code.
P8 touched: GameEngine (gates, hints, wander), SaveManager (v6), ContentDB
(validation), Main (hints, wander, locks), Main.tscn (WanderBtn), beasts data
(keys only), tests, README.
