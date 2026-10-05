# Phase P11 Report — 2026-10-04 (pacing proof + shortcuts)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

Nobody had verified the campaign is finishable in sane time. The pacing
model (`tests/pacing.gd`, real engine formulas, train-then-cultivate bot)
found the game was NOT: hard stall past realm ~8, 19,842 fruitless lives —
lifespan-capped per-life Qi could never outrun x4 bottlenecks. Two knobs
were tuned (plan allowed one; both walls measured, both reported):

1. Foundation ×4 per breakthrough (was flat): matches the bottleneck curve,
   so per-realm effort holds steady instead of doubling. First tried ×2 —
   measured still-doubling — corrected to ×4 on the evidence.
2. Drill xp scales with depth (`1 + realm_index` per player tick):
   tribulation power (linear need vs sqrt levels) was the second wall.

## Findings (after tuning)

Full 18-realm clear in 55,433 ticks / 110 lives: ~1.5h at 1x sim, minutes
at 100–1000x, hours hands-off. Tier 1 ≈ 30k ticks. Per-realm cost is flat
(~4k ticks). Optimal-bot numbers; typical play runs several times slower.
No overflow risk (float range far exceeds post-18 values).

## Added

- `Main.handle_shortcut()`: 1/2/3 focus, T tribulation, 7/8/9/0 speeds,
  Space pause, H stalk, W wander, M mute — all routed to existing handlers.
- `p11_test.gd` (19 checks): pacing bands (realm 3 ≤ 5k ticks, clear ≤ 300k
  ticks and ≤ 500 lives — measured 1k/55k/110) + every shortcut mutating
  state identically to its button.

## Gates (all PASS, exit 0)

- `--quit`, live `--quit-after 200`: clean.
- All 12 existing suites green (engine behavior changed; nothing broke).
- `p11` 19/19 with exact diagnostic parity (55,433 ticks / 110 lives).
- Web + Windows builds on disk. Banned-terms grep clean in game files.
- Total: ~300 checks green.

## No-drift check

Pinned engine/version/paths unchanged. No content, schema, store, threads,
text entry, or borrowed names/text/code. P11 touched: GameEngine (2 pacing
knobs), Main (shortcuts), pacing.gd + p11_test (new), README.
