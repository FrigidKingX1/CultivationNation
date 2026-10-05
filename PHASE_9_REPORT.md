# Phase P9 Report — 2026-10-04 (tier-2 expansion)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

Long-campaign players ran out of new things to find after realm 12. P9 adds
a second tier purely from existing engines: no new mechanics, no schema
change, no balance change.

## Added (P9a→P9d, in order)
- P9a Tier-2 data: realms 13–18 continuing the exact ×4 curve (test-proven
  `120×4^i` parity with the engine bottleneck chain, so progression math is
  untouched); Murkfen zone (4 beasts, gate 6, power 150–340); 2 arts;
  2 heirlooms; 6 achievements on existing stats only. Zones derive from pool
  order, so map generation, gates, wander, and seek absorbed Murkfen with
  zero engine edits.
- P9b Dynamic achievement denominator (`ach_names.size()`, fallback to
  unlocked count) — the hardcoded 21 would otherwise have lied.
- P9c Count updates (self 18, p3 5/14, p4 16/7, p5 27, p8 16) + `p9_test`
  (16 checks: parity, Murkfen derivation/gating, 4 unlock paths, live
  denominator).
- P9d Both builds re-exported byte-fresh; README updated.

## Gates (all PASS, exit 0)
- `--quit`, live `--quit-after 200`: clean.
- `self` 16/16, `bench` 11/11, `save` 35/35, `p3` 41/41, `p4` 48/48,
  `p5` 31/31, `p6` 37/37, `p7` 19/19, `p8` 33/33, `soak` 210y,
  `p9` 16/16.
- Web + Windows builds on disk.
- Banned-terms grep: zero hits in game files. Total: ~280 checks green.

## No-drift check
Pinned engine/version/paths unchanged. No mechanics, acts beyond data,
alchemy, retune, threads, text entry, or borrowed names/text/code. P9
touched: 5 data files, UIManager (denominator), count asserts, p9_test,
README.
