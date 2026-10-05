# AUDIT — Cultivation Nation P13 Phase A (2026-10-04)

Method: bare-engine measurement harness (`tests/audit_probe.gd`, deleted after
this report) + scripted UI playthrough via real button handlers (3+ lives) +
code inspection. Baseline green (gate 0, 14/14 suites, pacing 167,098/83).
All numbers below are measured, not estimated.

## BROKEN (punishes the player for playing)

### 1. Attempts fire without power sufficiency — 10,595 failed attempts per clear
Repro: run `tests/pacing.gd` policy (or idle past realm 1 in the live game).
The policy — and Main's autoplay, and the Attempt button — fire whenever Qi is
full, with no readiness check. Qi fills during train-focus ticks (0.5x rate),
so every realm produces dozens to hundreds of doomed attempts while technique
bonus catches up (measured `fails_by_realm`: 10 at realm 2, rising to ~350 per
realm past 40; 10,595 total across a 50-realm clear).
Each failure costs half Qi + purity −2 + **lifespan scars −5**.
Responsible: `Main._process` auto-tribulation + `_on_manual_breakthrough`
(`scripts/Main.gd`, fixed power 10, no readiness gate); pacing policy in
`tests/pacing.gd` / `p11_test.gd`; cost model in
`GameEngine.attempt_breakthrough`.

### 2. Every death is a scar-death — lifespan measures trauma, not age
Measured: 82 deaths in the paced clear, **82 scar-shortened** (tracked scars
at each rebirth). Fail-spam scars outpace every tier lifespan, so the
lifespan/age system never actually governs death; trauma does. The per-tier
lifespan table (110y → ageless) is decorative under fail-spam.
Responsible: `lifespan_scars` accumulation in `attempt_breakthrough` +
`_recompute_lifespan` (`scripts/GameEngine.gd`).

### 3. Idle death spiral past realm 2, and the way out is undiscoverable
Repro: boot the live game, never touch Drill focus. Power stays 10 vs need
`5+5r`: realm 2 (need 15) fails forever, each fail scarring −5y until early
death. UI playthrough confirmed: bot stuck at realm 2 for 3 lives with scars.
Nothing teaches the fix — there is **no drill/power hint** (HINTS covers
origin/bottleneck/pause/travel/sect/duties/gear/legacy only), and the Attempt
button shows no readiness beforehand (readiness % appears only in the failure
log line). A progression-critical action is invisible.
Responsible: `Main._auto_breakthrough_power` fixed 10.0, `HINTS`
(`scripts/Main.gd`); Attempt button UX.

## MISLEADING (exists but lies about its reach)

### 4. Steady quality never occurs — 0 of 50 successes in a full clear
Measured quality distribution: Radiant 8, Shaky 42, **Steady 0**. Bonuses land
in 10% level lumps and minds sit at extremes, so leak ratios cluster below
~0.15 (Radiant after overtrain) or above ~0.3 (Shaky after dantian collapse
from fail-spam). An entire named tier is unreachable in practice.
Responsible: `forecast_quality` bands (`scripts/GameEngine.gd`).

### 5. Environment sympathy and season effects are invisible
Zone matching adds up to ~+50% Qi and seasons rotate ±10% buffs, but the HUD
shows only names (realm label, season label). No readout of active
multipliers exists, so the player cannot know sympathy is working — or broken.
Measured env-sympathy uptime in the paced clear: **0 ticks** (wander only
fires on Strained, which never happens — see 8).
Responsible: `UIManager.refresh` (`scripts/UIManager.gd`).

### 6. Route planner is dead code with a save key
`set_route` is never called by Main and has no UI; `next_destination` fires
once from `_on_pause_for_death` with `[]` against an always-empty route.
State + migration + log line, zero gameplay.
Responsible: route block (`scripts/GameEngine.gd`), `_on_pause_for_death`
(`scripts/Main.gd`). Removal candidate (Phase B).

## SHALLOW (works, but earns no decision)

### 7. Mind never leaves Serene under any viable playstyle
Measured: 167,098/167,098 ticks Serene across a full clear. Decay (−1/30
cultivate-ticks) is outpaced by breakthrough refunds (+25 each ≈ 750 ticks)
plus rebirth resets (70), and the power wall forbids the pure-cultivate style
that would engage friction. The UI playthrough (always-cultivate) also stayed
Serene — short scar-driven lives reset faster than wear accumulates. A whole
friction system with no reachable friction.
Responsible: mind tuning (`scripts/GameEngine.gd`).

### 8. Soul weapon earns zero XP for all of Tier 1
`waves=0` for realms 0–7, and soul XP accrues per endured wave — so the
flagship persistent artifact does nothing for roughly the first 34k ticks
(~1h at 1x). A soul choice with no early feedback.
Responsible: tier wave table (`data/realms.json` via `tools/gen_realms.py`),
soul XP hook (`attempt_breakthrough`).

### 9. No voluntary rebirth — karma is gated behind death timing
There is no End-This-Life action; Samsara yield can only be realized by
waiting for old age (or scar-death). The prestige loop's timing decision does
not exist for the player.
Responsible: missing action (`scripts/Main.gd` + scene).

### 10. Hunt focus has no purpose once bestiary marks are done
Stalk halves Qi for kills that feed only completion marks and achievements.
No link to power, survival, alchemy, or breakthroughs. The focus "triangle"
is breathe-mandatory, drill-mandatory, stalk-optional-flavor.
Responsible: `hunt_at` / focus design (`scripts/GameEngine.gd`).

### 11. Bequest math is never surfaced
Sacrificing a perfected relic (34,100 Qi for riverband) for +0.02 legacy is
arguably rational mid-game, but cost vs benefit appears nowhere; the button
only shows the legacy side.
Responsible: `_rebuild_gear` text (`scripts/Main.gd`).

## Measured healthy (no action)

- Karma curve rewards depth sanely (realm-2: 21/fill → realm-49: ~300k);
  talent costs (10/40/…) reachable within a few lives. UI bot bought talents
  through real buttons successfully.
- Herb economy: 479 ticks to first pill untended, 53 with 2 gatherers —
  sect-gated but functional; brew/drink/ward/prep all verified via UI.
- Soul binding (one oath, second refused), bequest consume/refuse paths,
  v6→v7 migration, deep-state save/load round-trip: the 2 drifted keys
  (`lifespan_years`, `qi_bottleneck`) are by-design table recomputation in
  `apply_state`, not a bug.
- Origins choice, disciples allocation, gear refine, achievements (27),
  hints, pause-before-death, shortcuts: all exercised via UI, all work.
- UI log pipeline itself is fine (earlier empty-tail reading was a probe
  artifact: RichTextLabel `.text` omits `append_text` content; use
  `get_parsed_text()`).

## Proposed Phase B order (root causes first)

B1: readiness-gated attempts (no more doomed auto/manual attempts) +
proportional failure costs → re-measure fails/deaths/quality mix.
B2: scar/lifespan rebalance so age governs death again.
B3: drill discoverability (hint + readiness on the Attempt button) + idle-path survival.
B4: quality-band calibration (make Steady reachable), tooltip/readout pass
for sympathy + seasons + bequest math.
B5: per shallow system (7/8/9/10): deepen-or-cut with the player decision it
enables, recorded in DECISIONS.md. Route planner (6): cut unless Phase B
gives it a job.
Save schema v8 (single bump) rides with the first state-adding change; Web
preset removal rides with Phase D close.
