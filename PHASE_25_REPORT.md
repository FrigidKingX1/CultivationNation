# PHASE 25 — Manual Arena (0.24.0, save v12 unchanged)

Theme: AGENCY — hands on the hunt. Governs: docs/adr/P25_ARENA_ADR.md
(LOCKED) + Amendment 2 + docs/adr/P25_COMBAT_DESIGN.md (approved).
Q34-C skill combat: same stats + same input trace → identical outcome.

## What changed

- Input 19 → 20 (rule 11, intentional): `world_attack` on RIGHT mouse
  (LEFT is orbit-drag). `_default_event` builds key/mouse events for
  registration, seeding, and vendor reset alike. p21 asserts size 20,
  (type, code) collision pairs, attack-is-right-mouse, reset, Escape,
  and the N-scaled list height via mock tree (480px for 20).
- `skirmish_stats` (additive read-only getter, P25a) extended with the
  tick-model keys: beast_hp (10× power), beast_tick (25% power),
  unchanged cadence/reach/tempo keys. No existing key changed meaning.
- Fight loop (view-side, runtime-only): one combat tick per landed
  attack (400ms clamp), both sides frozen otherwise; cultivator strikes
  first; HP bars + numbers live from skirmish_stats; knockback to zone
  entrance on loss (nothing else); win rewards through EXISTING hunt
  path (node yield when a map node carries the beast, else hunt_tick)
  + Q35 technique-XP bonus (+100, focus art) conditional on tempo ≥ 0.8
  of clamp; Main voices wins/losses via one-shot outcome polls.
- Dens elevated to interactable (beast-id metadata, golden-ring
  determinism proven); below-ratio-0.25 refusals warded-style (R13:
  reads skirmish ratio, no duplicate logic); shrines queue guardians
  into the EXISTING duel flow (rule 4 wall held).
- Right-press strikes route through `_unhandled_input` (gated with
  panels open); panels open mid-fight suspend combat (zero HP change,
  asserted).
- `tests/p25_arena_test.gd` (58 checks): input N, skirmish shape,
  den determinism, refusals, challenge entry, shrine flow, invariance
  matrix, loss matrix, tempo clamp, panel-freeze, budgets.
- Contract: +7 P25a members, +13 fight members, nothing removed —
  same-commit updates per the churn protocol.

## Tuning model (pinned)

Symmetric HP multipliers cancel: win threshold = sqrt(beast_tick_frac)
= sqrt(0.25) = 0.5 exactly. HP mult tunes duration only; tick frac is
the sole threshold knob. Refusal floor 0.25 is independent. Resolution
order is simultaneous-with-cultivator-first (a killing blow lands before
the answer — matches the exact-0.5 boundary). Single-tick fights grant
max tempo by definition (cannot be fought faster) — intended. XP
farming is bounded by existing hunt/respawn rules: every manual fight
costs travel tolls + wall-clock time, and the same XP is available by
drilling the bona fide path.

## Invariance matrix (the design, delivered)

Same stats, three tempo profiles (max-tempo / half-tempo / slow-then-max):
identical wins, identical kill deltas, identical (zero) qi deltas —
only the XP bonus differs (max-tempo +100, slower +0). Loss profiles
lose at every tempo with zero qi cost and knockback to the zone mouth.
The verdict is math; tempo buys duration and bonus.

## Manual-opt-in reference bands (R-S13)

Reference setup (Dewfield reedlurker, fresh arts): 8 ticks to resolve;
max-tempo (≥2.0 attacks/sec) clears with +100 XP; slower clears without.
P16 trivialization tripwires are evaluated against DEFAULT runs only.
A tripwire firing on a manual-opt-in run is not a defect and must not
weaken the wire — manual-opt-in is opt-in with its own recorded bands.

## Gates

- 27/28 suites green (1195 counted checks, CSV ground truth
  `docs/qa/p22/sweep_summary.csv`; reconciled: 1190 + 5 panel-freeze).
  Sole red: bench 5s timing under sustained ~55% machine load —
  environmental-presumptive per the amended policy (same-tree PASS on
  record, zero tick-path mechanism). SHIP REQUIRES bench green on
  verified-idle iron; recorded below before tag.
- Bench on verified-idle iron: 28.9% load recorded immediately prior, 50k ticks complete <5s PASS, exit 0. Ship gate satisfied; tag applied.
- 480s plateau: delta(0→240s) +139, delta(240→480s) −270, verdict
  green; gate max(150, 25% × 139)=150. Bounded plateaus now three
  releases running (0.23.0: +286/−39).
- Pacing default bit-identical 73038/13 (re-verified this release).
- Export with docs/* exclusion; PCK delta recorded below; trio verified.
- Q31 FINAL: flight unlock realm 24, Nascent Soul (carried from 0.23.0).
- Known edge carried: explicit wander=W rebinders keep the collision
  (first-action-wins §7.3); population ≈ zero.
- Rule-11 citation audit: p21 19→20, p25 refusal-divergence + invariance,
  p14/p23 budget comments all carry citations.
- Engine-touch ledger: P24b factor (compiled-rate branch) / P25a getter
  (skirmish_stats, read-only) / P25b `train_technique` WRITE via
  existing XP API (Q35, opt-in-only). Three touches, three classes.
- Rebind capture: mouse buttons SUPPORTED by the vendor capture path
  (key_assignment_window records InputEventMouseButton; confirm flow
  correctly excludes mice). No limitation to record.
- skirmish_stats cited as additive read-only introspection (+P25b
  tick-model keys, same class).
- ADR-002B/R-1 still deferred; 0.25.0 theme recommended below.

## PCK note

0.23.0 PCK: 12,628,840 bytes. 0.24.0 PCK: 12,639,872 bytes (delta
+11,032 — arena code, den metadata, one suite; negligible). Evidence
stays committed; docs/* remains excluded. Exe+pck+dll verified together.

## 0.25.0 theme recommendation

R-1 STAKES AT SHRINES. Shrines are interactive as of P25a, the arena
gives risk a physical feel, and the stakes design (deterministic
threshold shifts, opt-in, own bands) slots into the shrine/guardian
context without new systems. Ley-line attunement is the larger economy
track — better placed after the risk loop beds in. UI evolution last,
as always. Decision stays with the product owner.
