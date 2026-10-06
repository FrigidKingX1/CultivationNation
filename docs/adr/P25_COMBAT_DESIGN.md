# P25 Skill-Combat Design — Q34-C Redesign Proposal
Status: PROPOSED — requires human approval before P25a code is cut.
(Q34-C cannot proceed as routine implementation: it redefines what
"deterministic" means for combat. This doc is the redefinition.)
Cites: P25 Arena ADR; STANDING_RULES R-S7/R-S11/R-S12/R-S13/R-S16;
Q14=A; Q35/Q36/Q37/Q38 as answered.

## Ruling principle

Determinism is preserved CONDITIONAL on inputs: identical stats +
identical input trace → bit-identical outcome. Tests drive scripted
traces (perfect / mash / idle / mistimed); the pacing bot uses a fixed
documented skill policy on the DEFAULT path only (it never touches
manual mode, so default pacing revalidation is re-running 73038/13,
not a new model). No RNG anywhere. No hidden state.

## Authority split

- ENGINE owns: stat-derived per-tick numbers, gate legality, reward/loss
  application through EXISTING paths. No new resolution code.
- New engine API (additive, READ-ONLY, no state, no save impact):
  `skirmish_stats(beast_id) -> {cult_dmg, beast_dmg, beast_cadence_ticks,
  player_hp, reach}` — pure function of current stats. The fight stepper
  consumes it; nothing writes through it.
- VIEW owns: input trace → timing/position classification, HP bars,
  tempo clamp, knockback displacement, shrine/panel wiring.
- Fight state is runtime-only (idle/challenge/fighting/won/lost);
  nothing serialized; v12 UNCHANGED.

## The exchange (Q34-C, bounded by Q14=A: move + attack only)

- The beast attacks on its cadence for engine-mathed damage, every
  `beast_cadence_ticks`. No dodge exists in v1 — incoming damage is
  unavoidable; skill lives entirely in the OFFENSE.
- The cultivator strikes ONLY on player attack presses (no auto-damage).
  Tempo clamp: presses closer than 0.4s are ignored (mash DPS bounded).
- TIMING: each beast attack opens a recovery window of R ticks. Strikes
  inside the window deal ×2; outside, ×1. (R recorded in DECISIONS;
  proposed R = beast_cadence_ticks.)
- RANGE: strikes land only within weapon reach of the den (avatar
  position matters). Out-of-range presses whiff — no damage, no penalty
  beyond lost tempo.
- LUNGE: every Kth beast attack displaces the avatar X units in a
  telegraphed direction (deterministic). The player walks back
  (movement). Time off-range is lost DPS — this is what feet are FOR
  in v1, given no dodge.
- WIN (beast HP → 0): rewards through the EXISTING hunt path —
  `hunt_at(beast_id, 1)` (marks, forage, yields exactly as one auto-kill)
  + Q35 technique-XP bonus via EXISTING `train_technique` API.
- LOSS (player HP → 0 = the math's verdict): knockback to zone entrance
  (Q37: nothing else — no death, no lifespan hit, no spiral).
- Below-gate fights: refused with the warded-style note, same as auto.
  Skill cannot bypass the math (gates stay engine-authoritative).
- One enemy at a time: engaging a second den while fighting → busy
  refusal. Dens = existing beast markers elevated to interactable
  (Q36: fixed dens, golden-angle ring, R12 positions).

## Outcome invariance (the test that replaces auto-parity)

Same stats + same scripted input trace (press timings, positions) →
same win/loss, same HP remainder, bit-identical. Traces: PERFECT
(all strikes in-window, in range) wins every gate-legal fight the auto
path wins; MASH (clamp-limited, random-phase) wins-or-loses per the
math, invariant per trace; IDLE (no presses) always loses (beast ticks
unanswered). Perfect-play invariance against auto outcomes is asserted
per gate-legal beast: auto-win ⟺ perfect-manual-win.

## Pacing standing

- DEFAULT path untouched (bot never presses attack, never walks to dens)
  → revalidation = re-run 73038/13. Any wobble = manual code touched
  default flows: stop, report.
- Premium-on reference (71704/12) untouched by combat work.
- Manual-opt-in gets its own bands at P25c: hunt-segment timings
  (perfect-trace vs mash-trace clear times for a reference beast).

## Input (Q38): RIGHT mouse button

The answer said "mouse button". Implementation: RIGHT button
(`MOUSE_BUTTON_RIGHT`). Rationale recorded: LEFT is the orbit-drag
button — press-and-hold orbits, so LEFT cannot cleanly attack without a
click-vs-drag disambiguator that would cheapen both feels. RIGHT has no
existing binding. The p21 distinctness machine-proof is extended to
(type, code) pairs: mouse events carry keycode NONE and must not false
collide. Vendor rebind UI mouse-button support is verified by test; if
the vendor list cannot display mouse buttons, that is recorded as a
known limitation (rebind still works for the 19 keys).

## Shrines (Q32)

world_interact at a guardian landmark returns the tier's guardian id
through a polled view API; Main opens the EXISTING duel flow
(`_on_guardian`) for it. Presentation/UX wiring only. No guardian
combat logic anywhere (rule 4 wall holds).

## Save / persistence class (R-S11)

Manual fight state: runtime-only, never serialized, reset on
apply_state/rebirth/ascend (same class as presence). Technique XP from
the Q35 bonus persists only because technique XP itself is existing
saved state — no new keys, v12 UNCHANGED either way (Q35-A needs no
persistence beyond what exists).

## What P25a may cut ONLY after this proposal is approved

Input +1 (world_attack, RIGHT default); dens + interaction + refusals;
shrine wiring; contract churn (additive: skirmish_stats engine getter
is ADDITIVE and read-only — the one permitted engine addition).
P25b fight flow per this doc. P25c bands + report + 0.24.0.
