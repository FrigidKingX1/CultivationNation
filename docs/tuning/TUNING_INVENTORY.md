# Tuning inventory — 0.28a mapping instrument (working document of record)
Relayed from the 0.28a read-only inventory (auditor-signed structure via
byte-exact citations). R-S9: chat prose summarizes; THIS FILE is truth.
Band shorthand: **D** = default 73,038/13 (six verifications).

| Constant | Current value | Code site | Band of record | Journal question |
|---|---|---|---|---|
| Pacing formula `qi_required` | `float(120 * 4^i) * front_load(i)` | tools/gen_realms.py:81 | D 73,038/13; pre-guardian 73,066/13 | pace WHERE / sunset |
| `front_load(i)` | 10x@r1 → 1x@r9 linear, 1.0 past | tools/gen_realms.py:71 | r1/r3 reshaped, late untouched | early lift feel |
| `qi_required` early | r1 1200.0, r2 4260.0, r3 14880.0 | data/realms.json:2 | D | pace |
| `qi_required` mid | r9 7,864,320; r16 128,849,018,880; r25 3.377e16 | data/realms.json:10 | D | pace |
| `qi_required` late | r49 9.507e30, r50 3.803e31 | data/realms.json:51 | D | sunset |
| Pacing gate (diagnostic) | cap 10M, quit(0) always | tests/pacing.gd:3 | D printed, never gated | re-anchor target |
| Pacing gate (asserting) | floors/ceilings, NOT exact | tests/p11_test.gd:101 | 30k–300k ticks, lives 5–150 | anchor |
| `EXPECTED_PACING` (P1 pin) | (73038, 13) | tests/pacing_pin_test.gd | exact, both sunset answers | mechanism, not prose |
| `LEYLINE_STEP_MULT` | 0.08 additive (full x1.64) | scripts/GameEngine.gd:125 | opt-in 72,844/13 (−0.27%) vs D | did attuning matter? |
| `leyline_mult()` | `1.0 + step*open` | scripts/GameEngine.gd:352 | x1.08/x1.64 asserted (p27) | — |
| Leyline branch | post-heaven-marks, pre-guard | scripts/GameEngine.gd:332 | D bit-identical | default must not wobble |
| `PRESENCE_MULT` | 1.5 | scripts/GameEngine.gd:94 | premium-on 71,704/12 | meditate payoff? |
| Presence branch | compiled qi-rate only | scripts/GameEngine.gd:319 | exact x1.5 asserted (p24) | — |
| `TEMPERED_RADIANT_FILL` | 0.999 | scripts/GameEngine.gd:1577 | tempered-greedy 73,008/13 | Tempered worth it? |
| `HEAVEN_RADIANT_FILL` + flawless | 0.999 AND deviation == 0 | scripts/GameEngine.gd:1582 | greedy: no clear @10M; switching 72,984/13 | pledge Heaven? |
| Steady+ head-start | 0.25 x crossed bottleneck | scripts/GameEngine.gd:641 | asserted (p26) | reward feel |
| Demotion terms | 2.0/3.0 Late-min; +2 scars; {from,to} | scripts/GameEngine.gd:660,665,667 | asserted (p26) | demotion sting |
| `HEAVEN_MARK_MULT` / CAP | 1.02 / 7 | scripts/GameEngine.gd:117,118 | overpowered 1,311,714/255 | mark chase |
| Heaven herb cache | +100 | scripts/GameEngine.gd:677 | — | — |
| Guardian `reward_mult` | 0.25 | tools/gen_guardians.py:39 | shaves 28 ticks (73,066→73,038) | duel payoff |
| Skirmish win/refuse | win iff ratio ≥0.5; refuse <0.25 | scripts/GameEngine.gd:1716 | bands asserted (p25) | fight fairness |
| `TEMPO_CLAMP_TPS` | 2.5 (400ms min gap) | scripts/WorldView.gd:703 | mash-reject asserted (p25) | busywork? |
| `BONUS_TEMPO_FRAC` | 0.8 | scripts/WorldView.gd:704 | bonus/none split (p25) | bonus earnable? |
| `BONUS_XP` | 100 via train_technique | scripts/WorldView.gd:705,842 | bounded (tolls+time) | XP swing? |
| Warden duel ticks | 0 (instant; ≤1% asserted) | scripts/GameEngine.gd:797 | ≤1% of ladder (P2 pin) | ceremony or tax? |
| `DEN_ACCEPT_RATIO` | 0.25 | scripts/GameEngine.gd:740,749 | refusal vs losable bands | pulse lied? |

## DATA-owned vs CODE-owned (P3)
- DATA (generator re-export + ContentDB validation + re-measure):
  realms qi_required (gen_realms.py), guardians power/reward_mult
  (gen_guardians.py), leylines costs/floors (gen_leylines.py), flight
  unlock r24.
- CODE (edit + re-verify + re-anchor P1): all consts above.

## Flags (auditor-signed dispositions)
1. 73,038 exact was claimed, never asserted → P1 pin (UNCONDITIONAL).
2. Warden ≤1% never measured → P2 assertion (mechanism).
3. Stale p11 comment (73,066) → corrected once, referencing the pin.
4. Fills identical (0.999); teeth differ by gate+demotion+scars → P5
   semantics + clarity lever (consequence lines, forecast glyphs).
