# Phase P15 Report — 2026-10-04 (depth pass)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

P13 made the loop honest; P15 was asked for depth: build identity, economy
sinks, a real ending, vestigial cleanup, travel stakes, achievement coverage.
Measure-first guardrails throughout (P15_AUDIT.md, temp probe deleted after):
Qi max stockpile 1.05x with no sink, karma funds everything by realm ~15,
early recruit n2+ negative, 3,500 banked herbs, toxicity ≥ 75 zero ticks in
both paced and pill-using runs, offline gains never applied live (recorded
timestamp unused — P16 candidate), scars/Failed ~0 live, beast power unused.

## Findings (measured)

- Attunement 0–100 (drilled +1/12, others cool −1/48) scales power to +50%
  and gates perks at 60; pacing policy was blind to it (manual bonus formula),
  so the policy now uses the engine bonus like live Main: clear 167,712/28
  → 70,738/11, bands hold untouched. Best-tracks-max verified; switching arts
  costs rebuild (commitment design documented).
- Toxicity backlash tuned to data: 75 unreachable (single drink peaks 12),
  so the threshold is 24 (deliberate double-dose, never ambient) — avoidable
  via purge/rest/travel/spacing; pacing uses no pills so scarred deaths stay
  0 by construction.
- Travel tolls only re-walks (first visits free): exploration/mind loops and
  pacing unperturbed (70738/11 identical); wander tries richest-first.
- Quality spread held (Radiant 8/Steady 16/Shaky 26); full clear now ~2h at
  1x (~12min at 10x default).

## Added

- Per-art curves/wear/perks in data (ContentDB-validated, injected defs,
  legacy fallback exact); soul paths split (blade power, bell wards, mirror
  tithes); `is_ready`/`trib_power_for`/`hunt_yield_mult`/`travel_toll` APIs.
- Talent ranks uncapped; herb choke 999; radiant refine overflow past max;
  recruit cost capped at 8 fills.
- Victory flag on realm-50 clear (persists rebirth/saves) + celebration log
  + banner + Summit-cleared label. Post-clear sandbox, no Ascension.
- Hunt gating on beast power (full/0.75/0.5 tiers + mind −1 when weak, stalk
  button names the drill fix); milestone forage unchanged.
- Achievements 27 → 43 (realm band 22–50, 7 systems via 7 new live-state
  stats, True Bestiary 39 + Beast Scholar rename); brew/drink/buy_talent poll.
- Save schema v8 (attunement + victorious, one bump); v7→v8 fixture.
- `p15_test.gd` (61 checks: attunement, perks, soul paths, sinks, victory,
  toll, achievements + live victory/stalk scene paths).

## Gates (all PASS, exit 0)

- `--quit` clean. All 17 suites green: pacing bands inside (70738/11, fails
  0), save stamps v8, p3 −4 route checks (P13) + tolerance updates, p4/p12
  cap checks replaced per brief (recorded above), p8 funded fallback wander.
- Windows build on disk (re-exported after state.json). Banned-terms grep
  clean (new names all original compounds). Screenshot probe: HUD changes
  verified visually (denominator 1/43 live), 61 FPS.
- Total: ~620 checks green.

## No-drift check

Pinned engine/version/paths unchanged. Flat layout, no class_name, data-free
engine (defs injected like beast pools), defaulted attempt args, migration
history intact, no borrowed names/text/code. P15 touched: GameEngine
(attunement, perks, soul paths, sinks, victory, backlash, hunt gating,
tolls, achievement stats/polls), Main + scene (celebration, rebirth button,
toll display/failure text, refining-always UI), data (techniques params,
16 achievements + rename), SaveManager (v8), all affected suites + p15 new,
README. No P16/Ascension, companions, or sect facilities.
