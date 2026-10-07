# QA ROUND 3 REPORT — 1.0b, post-banner-fix tree (G1)

Method: Round 1 method on the frozen tree — full sweep, display-required
probes (G2 re-run + floater captures), leak trace via exit-resource lines,
pixel review, 480s soak. Freeze holds (defect-class fix only).

## Sweep
- 32/32 exit 0, CSV ground truth **1414 = 1411 + 3** (p28 floater
  coalesce checks; closes exactly against raw bytes).
- Pacing pin re-verified inside the sweep (5/5, EXPECTED_PACING holds).

## Display probes
- G2 first-session re-run post-fix: 0 stumbles. Modal fork again
  (frame-rate-dependent qi state); both branches handled. Presence,
  den win, shrine dormant, ley-line ok, flight refusal all evidenced.
- Floater coalesce captures: exactly one legible "Realm 4 (Radiant)"
  in ink AND parchment (two rapid spawns in). Budgets cited: pool
  stays 12 pre-allocated labels; no new nodes (writes only).
- Pixel review: affordance states, HUD completion, hint verbs, both
  skins — reviewed in 0.27c/1.0b captures.

## Leak trace
- Exit-resource lines stable suite-over-suite: baseline 2 (harness-level
  SceneTree teardown noise, constant across pre- and post-fix suites);
  scene-bearing suites 4–6 as in prior releases (p21: 6, unchanged).
  p28 (newest scene suite): 2. No growth attributable to 1.0b changes.
- 480s soak: objects 3762 → 3942 → 4004 (+180 / +62 vs gate 150).
  PASS, single run (first half in the 139–228 churn band).

## Findings disposition
1. Banner overlap at 1000x (G2, real, cosmetic) → FIXED in 1.0b:
   tagged coalesce (`spawn_float` tag param, breakthrough passes
   "realm"; live-label reuse with tween kill). Tested (p28 +3),
   captured both skins. Defect-class, freeze-legal.
2. Veil phantom (0.27c watch item) → CLOSED as capture hygiene with
   mechanism (45-frame auto-hide + 0.25s fade + modal-blur; +20-frame
   snaps clean without exception). No product defect. R-S22 names the
   capture rule going forward.
3. No new findings: sweep green, soak PASS, G2 clean, leak trace flat.

## CI
- `.github/workflows/gate.yml` landed (YAML-validated): gate + import +
  FAST_SUITES (self/bignum/save_robustness/pacing_pin) on push to main.
  Bench/soak excluded (R-S19 idle-iron stays local-only). `.github/*`
  added to the export exclude_filter. First green run links after push.
