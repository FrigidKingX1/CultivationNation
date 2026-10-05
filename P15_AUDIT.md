# P15_AUDIT — Step 0 measurements (2026-10-04)

Method: temp headless probe (`tests/probe_tmp.gd`, deleted after this report)
over a gated-policy 50-realm clear + a manual-style pill-using run, plus
code reading (offline path, beast-power consumers). All numbers measured.

## M0 — economy verdicts

- Qi surplus: max stockpile 1.05× bottleneck at attempt time. No accumulation
  because the policy attempts at fill — but nothing CAPS or SPENDS surplus
  Qi either (refine/recruit both cap out). A player sitting full accrues
  unboundedly. VERDICT: KEEP Qi-sink item (no late sink exists).
- Karma: funding-all-talents costs 11,550 total. Realm-5 life yields 343
  (33.7 lives to fund); realm-15 yields 7,827 (1.5 lives); realm 25+ funds
  everything in under one life, then bank 100k+/life with nothing to buy.
  VERDICT: KEEP karma-sink item (uncap ranks; repeatable sink only if surplus
  persists after uncapping).
- Recruit ROI (marginal gather +2% vs cost 200×3^n): at realm-5 rates,
  n0 pays back in 182 ticks, n1 in 546, n2+ never within a life (1639+
  vs ~1300-tick lives). At realm 20+ rates explode and everything pays back
  instantly. VERDICT: KEEP, narrowed — early n2+ is the only negative case.
  Fix: cap recruit cost at 8× current bottleneck (binds only early; relaxes
  as you grow). Hunters/trainers/forage carry the rest regardless.
- Herbs: untended trickle banks 3,500 over a clear (168k/48, math checks);
  no cap, no spoilage, pill costs 10–25. VERDICT: KEEP herb cap (999).

## M1 — offline gains: never applied (missing feature, not a bug)

`SaveManager.compute_offline_gains` is tested math, but Main never calls it
on load (`saved_unix` is recorded and then unused for gains; the engine
catch-up clamp covers tab-outs only). There is no bottleneck question to
answer because there is no offline application. VERDICT: DROP from P15
(not in the brief's steps); P16 candidate (offline fast-forward that
respects bottlenecks/layers/insight).

## M2 — live rates: scars/Failed ~0, beast power unused (both confirmed)

P13 already proved UI paths never fail post-gating (p13 auto-skip/manual
tests); scars occur only via engine-direct calls. Beast `power` has zero
consumers outside ContentDB validation (grep). VERDICT: KEEP Step 4 as
planned (tox-backlash gives scars a live role; power gates hunts).

## Added requirement — toxicity ≥ 75 reachability

Measured ticks with toxicity ≥ 36/48/60/75: ZERO in both the paced run and
a manual-style run that brews+quaffs a prep pill before every one of 48
attempts (natural max 12.0 = exactly one drink, decayed before the next).
75 is unreachable in natural play: it needs ~7 stacked pills. VERDICT:
tune to data — backlash threshold 24 (two stacked pills: prep+ward before
one tribulation, or double-heal; deliberate, never ambient). Avoidability:
purge (−40), rest (−1/12t), travel (−20), or simply spacing pills. Pacing
policy uses no pills (tox ≡ 0), so scarred-deaths stay 0 by construction.

## Travel frequency note

Probe travels=0 is an instrumentation artifact (no map wired in the probe;
wander needs grounds). P13 data stands instead: wander-on-Strained visits
~16 first-visit grounds per clear plus fallbacks. Toll sizing follows the
must-afford invariant, not frequency.

## Dropped: nothing this round. Every briefed item measured real.
