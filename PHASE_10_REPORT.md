# Phase P10 Report — 2026-10-04 (records + playthrough proof)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

Engine soak proved the sim; button tests proved single wirings. Nothing had
played the actual game. P10 closes that gap with a bot that plays the live
scene like a player, plus a lifetime records row. No schema change — every
record figure derives from existing keys.

## Added (P10a→P10d, in order)
- P10a Records row: lives, peak realm (= monotonic realm_index), lifetime
  kills (sum), years (ticks/12). Pure `refresh()` math.
- P10b Autoplay bot (`bot_test.gd`): picks origin/art/focus, travels,
  founds sect, recruits gang, refines, attempts tribulations at 1000x until
  3 rebirths. First run: 14/14 (lives, realms, achievements, legacy
  persistence, kills, all three records figures).
- P10c Warning sweep: full outputs of all 12 suites captured to a log and
  grepped — zero `SCRIPT ERROR` lines. (The one JSON error in
  save_robustness is the deliberate corrupt fixture, allow-listed.)
- P10d Both builds re-exported byte-fresh; README updated.

## Gates (all PASS, exit 0)
- `--quit`, live `--quit-after 200`: clean.
- `self` 16/16, `bench` 11/11, `save` 35/35, `p3` 41/41, `p4` 48/48,
  `p5` 31/31, `p6` 37/37, `p7` 19/19, `p8` 33/33, `p9` 16/16,
  `soak` 210y, `p10/bot` 14/14.
- Web + Windows builds on disk.
- Banned-terms grep: zero hits in game files. Total: ~295 checks green.

## No-drift check
Pinned engine/version/paths unchanged. No mechanics, content, balance,
threads, text entry, or borrowed names/text/code. P10 touched: UIManager
(records row), bot_test (new), README.
