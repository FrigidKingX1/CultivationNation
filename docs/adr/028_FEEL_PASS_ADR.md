# 0.28.0 ADR — The Feel Pass
Status: DRAFT — fills as the play journal accumulates.
Theme: the game is fun to PLAY, not merely correct to test.
Q55: owner dumps existing impressions as entry one; sessions accumulate
after. Q56: one-time rebalance ON THE TABLE if the journal says so.
Q57: both sunset answers legitimate; history preserves whatever replaced.

## Instruments
1. Owner play journal (`docs/play/PLAY_JOURNAL.md`) — PRIMARY. The
   agent never edits it.
2. Re-measured bands for every opt-in system, stated policies.
3. Tuning inventory — each named constant, current value, band, feel note.

## Constants in scope
LEYLINE_STEP_MULT (0.08) · PRESENCE_MULT (1.5) · stake thresholds ·
arena tempo clamp (2.5) + bonus_tempo_frac (0.8) · warden duel tick
budget · pacing curve itself (the sunset).

## Deliverable — THE SUNSET DECISION, one of two legitimate answers
- A) SHIP THE CURVE: the 73038-class baseline stands; bands re-affirmed;
  the proof-of-innocence retires having never been broken.
- B) ONE-TIME REBALANCE: old baseline archived in history; new baseline
  pinned; ALL bands re-derived; trivialization tripwires kept; pacing
  gate re-anchored — the bit-identity era ends deliberately, with data.

No new features. No new systems. Tuning constants + the decision record.

## Amendment 2 — SUNSET DECISION: SHIP THE CURVE (final, Q58/Q59 ratified)
Decided on measured band data; owner ratified conditionality at Q56
(rebalance only if the journal said so); journal declined; condition
never fired. The only forbidden outcome was tuning without data —
this decision is the alternative, not a violation.

### Evidence of record (all previously measured, cited)
- Default ladder: 73038/13 — pinned (EXPECTED_PACING),
  mechanism-enforced.
- Presence premium: 71,704/12 — sub-linear by design (walls are
  readiness/power-bound); opt-in, own bands.
- Ley-line at FULL attunement (open=8, x1.64): 72,844/13 — −0.27%.
  Near-flat is a STRUCTURAL property of a wall-bound ladder, not a
  tuning defect. "Fixing" it means redesigning walls = post-1.0
  decision, not a feel pass.
- Stakes: selective-HC nets 72,984/13 (−54); greedy stall is policy
  failure; switching-bot clears. Design intent confirmed in
  play-scale data.
- Wardens: 0 duel-ticks (O(1) ceremony) — "tax" is zero by
  architecture.
- Arena: manual-only, opt-in, bonus bounded by hunt/respawn rules;
  no defect signal in any band.

### Dispositions
- U-ledger (d) pacing feel: resolved by DECISION on data, not by play
  experience — recorded as such so 1.0 does not overclaim.
- Clarity levers (P5): remain available post-1.0 if the owner ever
  reports confusion; no evidence-driven wording changes now.
- P4 rebalance runbook: STAYS ARMED. Any future retune executes it:
  journal-justified, signed-off, one commit, EXPECTED_PACING re-anchored,
  bands re-derived, tripwires kept.
- Bit-identity era closes having never been broken: six prose
  verifications, one mechanism, zero violations.

### Release disposition
No 0.28.0 release: the decision rides as docs into 1.0.0 readiness.
Version train: 0.27.0 → 1.0.0 (readiness phases 1.0a/b/c per R-S19).

## Amendment 1 — 0.28a tree-truth pins (auditor-signed)
Tree sources: LEYLINE_STEP_MULT:125, DEN_ACCEPT_RATIO:740,
TEMPERED_RADIANT_FILL:1577, TEMPO_CLAMP_TPS:703, BONUS_TEMPO_FRAC:704,
BONUS_XP:705, p11 tripwires :101/:102/:104, gen_realms.py:81.

### P1 — Pacing pin (UNCONDITIONAL, both sunset answers)
New assertion: seed-frozen default-path bot run asserts EXACT (ticks,
lives) against EXPECTED_PACING = (73038, 13). The constant changes ONLY
via a deliberate journal-justified signed-off commit (the rebalance
re-anchor). Bit-identity converts from prose convention to mechanism.
Stale p11 comment corrected in the same commit, referencing the constant.

### P2 — Warden budget assertion (closes ADR-001's last unmeasured clause)
Bot accumulates duel ticks; assert sum <= 1% of ladder total. First hard
number for the "ceremony or tax" question.

### P3 — DATA vs CODE implementation classes (ratified)
DATA-owned (realms/guardians/leylines/flight): tune via generator
re-export + ContentDB validation + re-measure. CODE consts: edit +
re-verify. Both paths re-anchor P1 deliberately and re-derive all bands.

### P4 — Rebalance runbook (pre-written; executes only on Q56=B)
gen_realms.py edit -> re-export realms.json -> re-anchor EXPECTED_PACING
(one commit, old value preserved in history) -> re-derive ALL bands ->
re-evaluate p11 tripwires -> full sweep -> new baseline tagged. Any
retune without this sequence is a violation, not a tuning.

### P5 — Stake semantics (tree truth, recorded for journal reading)
Fills identical (0.999) for Tempered and Heaven-Challenging.
Differentiation: Heaven adds deviation==0 Radiant gate + realm demotion
+ scar risk; Tempered is quality exposure + Steady+ rewards.
Selective-HC = deviation insurance (tree-confirmed L552-558/L584/595).
Feel question: insurance-priced-as-terror reads fair? CLARITY LEVER:
pledge-modal consequence lines and forecast glyphs are in-scope feel
surfaces — some friction resolves in words, not constants.

### P6 — Inventory lands in-tree
The full table commits as docs/tuning/TUNING_INVENTORY.md (relay
protocol: the mapping instrument survives chat). R-S9 note: sign-off
covers structure via citations; the table file is the working document
of record.
