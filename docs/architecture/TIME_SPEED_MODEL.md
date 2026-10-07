# Time & Speed Model — document of record (post-1.0 audit)
Status: AUDITED — read-only review, no code changes. Bugs stop at the
Risk Register; disposition is auditor/human-only.
Method: three parallel read-only inventories (relay protocol) + author
verification of load-bearing lines + two live probes (W1 anchor, W4
walk-through). R-S8: CSV-style ground truth where countable; R-S9:
file:line on EVERY claim.

Core thesis, verified: the sim is a **tick-count machine**. Wall-clock
enters at exactly three doors (S1 frame accumulator, S4 unix stamp,
S5b strike timestamps). Everything else is tick math. The pacing
bot/pin reproduce live play because they drive the same `_step_tick`
with the same tables and seed — the ONLY differences are listed in
S1-Q7/S4-Q7/S5b-Q7 (frame-polled Main autos, UI staleness, visual-only
FX), none of which touch tick verdicts.

---

## S1 — Core sim tick

Canonical: `scripts/GameEngine.gd:2-3` ("1 tick = 1 in-game month.
12 ticks = 1 year. Time scale multiplies ticks per second."),
constants `TICKS_PER_YEAR=12, BASE_TICKS_PER_SECOND=10.0,
MIN/MAX_TIME_SCALE=1.0/1000.0, LOW_POWER_MAX_RATE=100.0`
(`GameEngine.gd:15-19`). Tick loop verified by author read
(`GameEngine.gd:456-468`):
`rate=effective_rate(); _accum+=delta*rate; steps=int(_accum);
if steps<=0: return; steps=mini(steps,5000); _accum-=steps;
for i in range(steps): _step_tick()`.

- Q1 Clock: live = wall `delta` via `GameEngine._process`;
  `Main._process` never steps ticks (UI/autos only). Tests/offline
  call `_step_tick` directly (no delta).
- Q2 Units/types: `delta:float` s, `rate:float` ticks/s,
  `_accum:float` fractional ticks, `steps:int=int(_accum)` truncates
  toward zero, remainder kept (`_accum-=steps`). `tick_count:int`.
  `time_scale:float` clamped [1,1000] on write AND read.
- Q3 Formula: `effective_rate()=10.0*clampf(time_scale,1,1000)`
  (`GameEngine.gd:257-261`), `min(rate,100)` in low-power. Ticks per
  wall-second nominal: 1x=10, 10x=100, 100x=1000, 1000x=10000;
  low-power 1000x→100. Speed buttons pass literals 1/10/100/1000
  (`Main.gd:417-420` via `_on_time`).
- Q4 Accumulator: `_accum` only (`GameEngine.gd:218`); threshold
  `steps<=0: return`.
- Q5 Clamps: `mini(steps,5000)` catch-up guard (`GameEngine.gd:465`);
  proven by bench (`bench_test.gd:55-56`: 1s frame at 1000x = 5000,
  low-power 1s frame = 100).
- Q6 Pause/headless: `if not running: return` before accumulation
  (`GameEngine.gd:457`); pause sources = pause button, title hold,
  death-pause. Headless suites bypass `_process` via direct ticks.
- Q7 Frame-rate dependence (FORK INVENTORY):
  F1. 5000-clamp discards excess on long frames/tab-out. Safe at
  60fps (1000x→~166/frame) and 20fps (~500/frame); a 1.0s stall at
  1000x truncates 10000→5000 (loses 5000 ticks = ~417 game-years).
  F2. `Main` auto-tribulation polls ONCE PER FRAME
  (`Main.gd:1789-1826`), not per tick: higher FPS attempts sooner
  after fill; lower FPS overfills longer. Engine emits
  `breakthrough_ready` per tick but Main does not consume it per tick.
  F3. UI 0.25s poll + 30s autosave staleness scales with FPS (sim does
  not, except F1/F2).
- Q8 Determinism: same (delta-series, rate) → same steps (pure
  `int()`+`mini`). Non-determinism: wall-delta jitter,
  `generate_map(-1)` wall-seeded (`GameEngine.gd:1600-1604`),
  sect-name `rng.randomize()`, terrain `randf_range`.
- Q9 Consumers: `_step_tick` loop, `apply_offline` per-second ticks,
  tests/bench/pacing direct calls, Main per-frame auto/manual paths,
  signals (ticked/aged/breakthrough_ready; Main connects
  paused/reborn/achievement, not per-tick).
- Q10 Risk: F1/F2 above (design + fork note, not defects).

## S2 — Game-time semantics

- 1 tick = 1 month (`_month_accum+=1`, `GameEngine.gd:517`); 12 ticks
  roll the year (`_month_accum=0; age_years+=1`,
  `GameEngine.gd:522-524`).
- Seasons = integer division: `season_index()=clampi(_month_accum/3,0,3)`
  → months 0-2 Spring, 3-5 Summer, 6-8 Autumn, 9-11 Winter
  (`GameEngine.gd:1157`); 12 solar terms 1:1 with tick-in-year
  (`GameEngine.gd:1163`).
- Season buffs (THREE separate 1.1x, different axes):
  Spring ×1.1 Qi (`_season_qi_mult`), Autumn ×1.1 gather
  (`_season_gather_mult`), Winter ×1.1 trib power
  (`season_power_bonus`), Summer ×1.1 technique power
  (`GameEngine.gd:913-914`).
- `_season_cached` change detector re-runs gather+rate on rotation
  (`GameEngine.gd:518-521`).
- Lifespan: `max(1,int((realm_lifespan+origin-scars+dao_years)*
  (1+0.1*breath_rank)))` (`GameEngine.gd:999-1000`); ladder reads
  110 (r1) → 1500 (r25) → 1000000000 (r50, ageless) from
  `data/realms.json` (measured). Death at `age>=lifespan`
  (`GameEngine.gd:528`); `death_looms` looks one tick ahead
  (`GameEngine.gd:205-209`).
- Rebirth resets age 18/month 0/scars, banks karma, aptitude
  `1.0+0.25*rebirths`, re-rolls roots from `life_number*7919+13`
  (`GameEngine.gd:828-864`).
- Pause-before-death parks `running=false` (`GameEngine.gd:530-532`).
- Q7: game-time per wall-second = `effective_rate()/12` years/s
  nominal (1x→10mo/s, 1000x→833mo/s), minus F1 clamp loss.
- Q8: calendar needs no RNG; roots seeded, map seeded-or-wall.
- NOT persisted: `_month_accum/_season_cached/_accum` absent from
  `get_state` (`GameEngine.gd:1986-2022`) — load resets intra-year
  phase; recomputes re-derive. (Risk R7.)

## S3 — Rate chain time dimension

- `_cached_qi_per_tick` = Qi PER TICK (per month), NOT per second.
  Proof: added once per `_step_tick` with no ×ticks factor
  (`GameEngine.gd:475`); ticks/sec handled by the S1 batch loop.
  Qi-per-second = cached × effective_rate().
- Full chain verified by author read (`GameEngine.gd:310-338`):
  base × aptitude × origin × dantian(`0.5+purity/100`) × gear × gather
  × focus(1/0) × mind(Serene 1.25/Steady 1.0/Strained 0.8) × env ×
  season_qi × (1-0.1×deviation) × (1-clamp(tox)/200) × legacy ×
  dao_flow [×1.5 presence] [×1.02^marks] [×(1+0.08×open)], finite
  guard falls back to `_last_good_rate`.
- Float truncation points: `BN.of(qi_per_tick).to_float()` collapses
  the base (`:316`); `BN.from_float` maps ≤0/non-finite→0 and small
  integers exactly; `BN.plus` DROPS the addend when exponent gap >15
  (late-game micro-gains vanish into Big stocks — silent, design,
  Risk R8); display/tests via `qi_num/rate_num→to_float()`.
- Bench pin: `3.0*2.0*1.0*(0.5+80/100)*1.25*1.0*1.1`
  (`bench_test.gd:77`).
- Default path: presence off, marks 0, leyline 0 — branches never
  fire (R-S13 comments at :317-333).

## S4 — Offline resolution

Formula verified against relayed lines (spot-checked save/load
ordering in-tree):
`away=max(0,now-saved); capped=min(away,28800);
if capped<60: return {skipped:true};
remaining=capped; while remaining>0:
{vigil&&death_looms→vigil=true,break; _step_tick(); remaining--};
months=capped-remaining; qi=qi_num(); deaths=Δlife; skipped=false`
(`SaveManager.gd:8,264-289`).
- 1 wall-second ≡ 1 tick ≡ 1 month; `months` counts TICKS (proven:
  30h away → months=28800, `save_robustness_test.gd:296-297).
- SAME `_step_tick` as live; zero `attempt_*` inside → bottlenecks
  and gates honored trivially (proven: pools past bottleneck at
  same realm, `save_robustness_test.gd:304-305`,
  `p16_test.gd:97-98`).
- Ordering (verified, not assumed): load→`apply_state` (presence
  CLEARED, `GameEngine.gd:2060-2062`; leyline LOADED,
  `GameEngine.gd:2095-2099`) BEFORE `apply_offline`
  (`Main.gd:164-176`); proven by `p24_presence_test.gd:140-148`
  AND, for ordering per se (offline-after-load as a sequence, not
  just endpoints), by the P24b real-flow test, which performs
  set_presence → apply_state → apply_offline in that order and
  asserts both the cleared presence and the resolved gains
  (`p24_presence_test.gd:140-148`: "load clears presence before
  offline", "offline still resolves gains"). The ordering proof is
  that test, cited here explicitly (amendment, sign-off review).
- Vigil (default) stalls at `death_looms`, discards remainder,
  reports `vigil:true`; unfettered ticks through death/rebirth
  unseen AND banks karma (`save_robustness_test.gd:323-327`).
- Offline ignores `running` (no check in the loop); live respects it.
- FPS-invariant (no delta anywhere in the path).
- Dead code: `compute_offline_gains` (analytic, ignores mortality/
  presence/leyline/gates) — live callers: ZERO (only
  `self_test.gd:64`). Risk R1.

## S5 — Combat clocks

- S5a guardian duel: synchronous pure computation, ZERO engine ticks
  (`for j in range(n)` waves, `tick_count` untouched):
  `s_j=G*(0.5+0.5*j/max(n-1,1))`, `blocked=min(s,D)`,
  `leak=Σ(s-blocked)`, `core=1.5G`,
  Radiant iff leak≤0, Steady iff leak/core<0.3, Shaky iff leak≤core,
  else Defeat (`GameEngine.gd:792-803`). Auto-trigger frame-polled
  (timing varies by FPS, verdict never does).
- S5b manual skirmish: wall-clock `get_ticks_msec()` per strike,
  injectable (`WorldView.gd:759`); `min_gap=int(1000/2.5)=400`ms;
  first strike always passes; exactly ONE combat tick per landed
  strike (both sides simultaneously, cultivator first — no
  simultaneous-death branch); panel-open suspends with zero HP
  change (proven `p25_arena_test.gd:323-327`).
- Duration derivation: `duration_s=(last-first)/1000=landed/tempo`;
  n-hit fight at max tempo 2.5/s lasts ≥(n-1)×0.4s.
- Bonus: `elapsed=max((last-first)/1000,0.001)`,
  `tempo=landed/elapsed`, pays +100 XP iff tempo≥2.0 AND art set
  (`WorldView.gd:837-842`). Wins route through existing
  `hunt_at/hunt_tick`; loss = knockback only, zero qi cost (proven).
- Outcome invariance: p25 three-tempo profiles → identical
  win/kills/qi, differing only bonus XP. FPS touches visuals only
  (bob/shake/poll throttle), never `avatar_strike` math.
- Dead scales (emitted, asserted present, NEVER read):
  `beast_cadence_ticks` (=4), `tempo_min` (=0.4). Risk R2.

## S6 — UI/polling clocks

All accumulators (`+=delta`), ZERO Timer nodes in scripts/.
- Main 4Hz block (`_ui_timer≥0.25`, both paused and live branches):
  8 refreshes + `_poll_hints` — ALL cosmetic/voicing; sim ticks
  independently (`Main.gd:1827-1839`).
- WorldView 4Hz pump (`_poll≥0.25 → _poll_engine`: seed, cultivator,
  world-state, tribulation, representation, affordances) — view-only.
- Autosave 30s accumulator (running-gated; writes slot, alters
  nothing).
- Toasts 3.0s+0.3s fade (cap 3); floaters rise 0.8s + fade 0.4s
  (delay 0.25) + 0.15 pop, pool 12, 1.0b tag-coalesce with tween
  kill; banner 0.5s kill-and-restart; QiBar 0.4s; shop squash
  0.05+0.12; panel fade 0.15. ALL cosmetic (tweens).
- Boot veil: 45 `_process` frames + 0.25s fade tween
  (`Main.gd:81,84-85,1771-1775,1909-1918`); show fade separate 0.2s.
  Ascension veil: SEPARATE path (SceneTreeTimer 0.5s + same hide).
  R-S22 mechanism: 45 frames + fades explain every probe capture.
- Music pump per-frame + 2.0s vendor fades (audio, cosmetic).

## S7 — Harnesses

- Pacing bot: NO FRAMES — `while` loop of direct `_step_tick`
  (seed 4242, tables wired, train-then-cultivate, no
  gear/disciples/offline, 1x). Hours = ticks/36000 (10tps×3600).
  Conservative by header comment. Pin twin asserts exact
  EXPECTED_PACING=(73038,13) + duels==7 + duel-ticks≤1%.
- Bench: wall-ms for 50k direct `_step_tick`s (no render) + exact
  count + clamp/compiled-rate lines. (See W6.)
- Logic soak: 2520 direct ticks (=210 game-years, no wall wait),
  mid-run save/load, asserts count/clear/rebirths/bounds/finite.
- Display soak: 240s wall windows, 60-frame sampling (avg/worst
  frame ms, fps), focus/tab/save drivers, object+memory deltas,
  verdict frames≥5000/Δobjects<500/avg<40ms.
- Equivalence argument (the bit-identity edifice): bot ticks ARE
  live ticks — same `_step_tick` body, same tables, same seed.
  The three documented divergences (F2 frame-polled autos,
  UI staleness, visual FX) touch no tick verdict. Wall-clock
  enters live play ONLY via the S1 accumulator; the bot replaces
  it with a counted loop. Same ticks, same math, same seals.

## S8 — World-layer timing

- `_update_affordances` confirmed on the C4 pump
  (`WorldView.gd:231-239` + def at :270-297): material swaps,
  sprite modulate, flame scale — no new nodes, no sim writes.
- Walk: `WALK_SPEED=8.0 u/s`, displacement
  `dir*8.0*_fly_mult*dt` per-frame (no fixed stride), clamped to
  90% island radius (`WorldView.gd:468,503-506`); stride keys
  polled per-frame (WASD); `FLY_MULT=2.5` (movement scale —
  distinct from PRESENCE_MULT 1.5 qi scale, R-S7 comment).
- `INTERACT_RADIUS=6.0` (`WorldView.gd:473`): near_node/den/shrine
  checks; DETECTION frame-polled (`_poll_avatar` every frame;
  interact key hold → `_try_interact` den→shrine→node); Main
  voices the queued one-shots at 4Hz. (This split is the G2
  modal-fork mechanism: frame-rate changes WHEN the queue fills,
  never WHAT it contains.)
- Combat reach is SEPARATE: `skirmish_stats.reach=6.0`
  (not INTERACT_RADIUS).

## Sweep appendix

Relayed inventories (S6/S8 task) classify every `scripts/` hit for:
`delta` (16), `_process` (7), `_physics_process` (0 — none exists;
all movement/sim on `_process`+accumulators), `get_ticks_msec`
(1: combat tempo), `unix_time` (3: map-seed fallback, save stamp,
offline now), `Timer` (0 nodes; 17 lowercase hits = accumulators +
SceneTreeTimers + trib cosmetic awaits), `create_tween` (17: all
cosmetic UI/FX), `await` (3: trib staging beats only),
`time_scale` (9: speed control + persistence), `msec` (8: combat
tempo only). Zero-hit files: BigNumber, ContentDB, SpriteFactory,
UIComponents, UITheme, UpgradeRow, ModalManager; SfxSynth envelopes
(out of scope, no game clock). Full per-hit table with (a)/(b)
marks: relayed verbatim in the working notes; headline result —
NO fourth wall-clock door exists. Cosmetic-only items (trib
staging, death/rebirth FX, shake/bob, music, sfx) never feed sim.

## Worked examples (auditor re-derives every one)

W1 — One wall-second at 60 FPS, speed 1x, virgin engine, realm 0.
Budget: 60 frames × (1/60 s × 10 tps) = 10 ticks, ~0-1/frame, no
clamp (≪5000). Rate breathes (measured probe, fresh engine):
months 1-2 Spring (qi×1.1 AND gather×1.0): 1.7875; months 3-5
Summer (1.0×1.0): 1.625; months 6-8 Autumn (1.0×1.1): 1.7875;
months 9-11 Winter: 1.625. Base 1.625 = 1.0×apt1×origin1×
dantian(0.5+80/100=1.3)×gear1×gather1×focus1×mind1×env1×legacy1×
dao1 (fresh-state values; mind 70 reads Steady 1.0).
Measured 10-tick total: qi 0 → 17.225 (avg 1.7225/tick).
Game-time: 10 months. Accrue-then-recompute ordering inside the
tick explains per-tick cache reads (open micro-question R9).

W2 — One wall-second at 20 FPS, speed 1000x, same engine.
Budget: 20 frames × (1/20 s × 10000 tps) = 10,000 ticks
(500/frame < 5000 clamp: NO loss). Game-time: 10,000 months vs
W1's 10 — NOT equal, BY DESIGN (speed multiplies ticks/sec; the
setting is the point). FPS comparison at 1000x: 20fps and 60fps
both deliver exactly 10,000 ticks (accumulator absorbs frame
size) — FPS-independent. Clamp case (design, not artifact): a
1.0s stall at 1000x offers 10,000, banks 5,000, LOSES 5,000
(~417 game-years) by the tab-out guard.

W3 — The 73,038-tick ladder. Wall-clock: 7303.8s = 2.03h at 1x;
12.2min at the 10x default (speeds divide wall time).
In-game years: 73038/12 = 6,086.5 game-years across 13 lives
(avg ~468y/life — consistent: lifespan ladder reads 110 (r1) →
1500 (r25) → 1000000000 (r50, ageless) from data/realms.json;
late lives span millennia).

W4 — Away 6h (21,600s), mid-game (realm 24, leyline_open=2),
MEASURED probe run: away=21600, capped=21600 (<28800 ✓),
threshold 21600≥60 ✓ → 21,600 tick budget. Vigil (default)
broke at death_looms (age 1499 vs realm-25 lifespan 1500 —
broke EXACTLY at death's door): months=17,783 resolved, 3,817
unspent (discarded, vigil:true), deaths=0, skipped=false.
qi: 1,000,000,000,000 − 82,000 (two attunes: 2000+80000, paid
pre-away) + ~34,919 (17,783 ticks × ~1.96/tick realm-24
attuned rate) = 999,999,952,918.96 (probe-measured).
Multipliers applying: leyline INCLUDED (open=2 retained through
load — inverse of presence); presence EXCLUDED (cleared on
load); season/deviation/mind as live tick state; no attempts
(realm unchanged); Big exact throughout, float only in the
report line.

W5 — Manual fight, identical stats + timestamps, 60 vs 144 FPS:
INVARIANT (refute fails). Timestamps are INPUT (wall-clock or
injected), never frame-derived; verdict = f(stats, stamps,
range, order) only. Duration = (last-first)/1000 = landed/tempo;
n-hit fight at max tempo ≥(n-1)×0.4s. Fork surfaces: NONE in
verdict (p25 three-tempo test: identical win/kills/qi, bonus
only differs); visual bob/shake/poll-throttle only.

W6 — "50k ticks < 5s" measures WALL MILLISECONDS for 50,000
direct `_step_tick` calls with zero rendering (`bench_test.gd:
31-37`), plus exact count and clamp/compiled-rate lines. Valid
as release gate because it is a SIM-THROUGHPUT tripwire (catches
accidental O(n²) in the hot loop), NOT a gameplay claim; local-
only because shared CI runners cannot honor idle-iron (R-S19).

## Risk register (post-1.0 protocol: report and STOP)

- R1 DEAD `compute_offline_gains` (SaveManager.gd:291-294): same
  cap, different units, ignores mortality/presence/leyline/gates;
  live callers ZERO. DISPOSITION (auditor ruling): DELETE in 1.0.1
  housekeeping, one commit — a dead analytic path that disagrees
  with the live one is a future-agent trap, not just dead weight.
- R2 DEAD `beast_cadence_ticks`/`tempo_min` (emitted + asserted
  present, never read): balancer tuning them moves nothing.
  DISPOSITION (auditor ruling): ANNOTATE dead (not wire) —
  emission/assertion costs nothing; a future system wires cadence
  deliberately or not at all.
- R3 Report `qi` lossy float (SaveManager.gd:286 → qi_num →
  Main.gd:232 `format_hybrid`): welcome-back text diverges from
  stored Big past float precision. Cosmetic; doc-only.
- R4 `months` misnomer (ticks, not calendar months; modal shows
  "3600 moons" for 25 game-years). Doc-only; rename is auditor call.
- R5 Vigil discards remainder silently (only `vigil:true` signals).
  By design; doc-only — auditors must not equate months with away.
- R6 Unfettered karma cascades offline (banked, unseen). Design;
  doc-only.
- R7 Load resets intra-year phase (`_month_accum/_season_cached/
  _accum` not persisted). Tiny seasonal phase jump on load;
  doc-only (persisting it is a save-key decision).
- R8 `BN.plus` exponent-gap drop (>15 → addend lost): late-game
  micro-gains vanish into Big stocks. Silent, trivialization-
  irrelevant; doc-only.
- R9 W1 single-tick phase offset (CLOSED, auditor mechanism): the
  "one tick early" dip is operator order in the accumulation itself
  — the budget accrues `delta × rate` with the rate path already
  admitting the new season's multiplier, but the season index rolls
  during the tick batch while `_season_cached` re-runs the rate only
  after the batch boundary. The season change is detected on the
  tick AFTER the calendar rolls, not on the roll itself. Totals wash
  out over the 12-tick year (lag amortizes symmetrically) — which is
  why only W1's single-second window exposed it. No recompute-trigger
  hunt needed, no touch. (Optional verify, not performed: log
  `_season_cached` vs `season_index()` across one boundary tick.)
- R10 `avatar_strike` robustness (RECLASSIFIED, sign-off review):
  `reach` re-queried live is CORRECT behavior, not risk — a fight
  that can suspend on panel-open must not fight from a stale
  snapshot. Remaining candidates, auditor-ranked: `-1` sentinel
  collision, missing `running` check. Backward-time tolerance
  noted as tolerant-by-construction, not a defect.
- R11 Nondeterminism inventory (documented, not defects):
  `generate_map(-1)` wall-seeded, sect-name `randomize()`,
  terrain `randf`, tests pin fixed seeds. No action.
- R12 F1/F2/F3 frame forks (S1-Q7): clamp loss, per-frame autos,
  UI staleness. Design + documented; the G2 modal-fork precedent
  generalizes to: frame-rate changes WHEN queues fill, never WHAT
  they contain — EXCEPT F1's tick loss, which is real game-time
  loss by the tab-out guard's explicit design.
