# DECISION SHEET — Perception Gap Audit (owner ticks boxes, no writing needed)
Each pick described by EXPERIENCE. Effort: S/M/L. Risk: names the gate
it touches (pin/budgets/freeze) or "none". ⭐ = agent recommendation
(marked as recommendation per task spec).

## D1 Asset policy (E4 memo)
- [ ] A: Procedural + art direction (palette/lighting/silhouette/animation
  passes, code-owned). Effort M. Risk: none (visuals only). ⭐
  First step palette/lighting (S constants) fixes "night-void" cheapest;
  silhouette/animation follow if D1-boxes demand more.
- [ ] B: CC0 packs for character/beasts/nature (nothing suitable vendored
  today — new packs needed). Effort M-L. Risk: none sim-side; license
  diligence required. vendored KenneyStarter is UI-nine-slice ONLY.
- [ ] C: Hybrid (CC0 character/beasts via the make_sprite seam + procedural
  islands + palette pass). Effort M. Risk: none. ⭐ if A proves insufficient.

## D2 Default speed + first-session arc (C1/C2 numbers)
- [ ] A: Curated opening — first life at 1x until first breakthrough,
  speeds unlock after (the game teaches its own pace). Effort S.
  Risk: none (speed never touches tick verdicts). ⭐
- [ ] B: Keep 10x boot (12-minute ladder, 11-second lives). Effort zero.
  Risk: none. Keeps the "die every 11 seconds" first impression.

## D3 Death cadence (C1 table: 110s/life at 1x, ~11s at shipped 10x)
Pick the FEEL number (sim consequence noted, P4 executes):
- [ ] A: First death no earlier than ~15 minutes (T1 lifespans ×8 or
  base-rate rework — P4 re-anchor required). Effort M. Risk: PIN.
- [ ] B: First death no earlier than ~5 minutes (×3 T1 lifespans).
  Effort S-M. Risk: PIN. ⭐ (smallest change that kills "die every
  11 seconds" as a first impression)
- [ ] C: Keep current cadence. Effort zero. Risk: none.

## D4 UI scope (F1/F3)
- [ ] A: Reskin-in-place (hierarchy + typography + spacing pass on the
  existing nine tabs; fix the census items). Effort M. Risk: budgets
  re-checked. ⭐
- [ ] B: Rebuild (fewer surfaces, restructured IA). Effort L.
  Risk: budgets + contract churn.

## D5 Visual scope (E3)
- [ ] A: Palette + lighting only (lift the night-void, warm the sun).
  Effort S. Risk: none. ⭐ first.
- [ ] B: A + silhouette + animation (bevels, bob/breathe/lunge/flame
  flicker). Effort M. Risk: none.
- [ ] C: Full asset pivot (see D1-B). Effort L. Risk: pipeline.

## D6 Juice scope (D2 fix list: meditate/strike/interact/speed/drink/rebirth)
- [ ] A: Cover the six "none" rows (breath sound + aura swell, impact
  tick + shake, press blip, speed indicator + pause beat, quaff gulp,
  rebirth/banner promotion). Effort M. Risk: budgets re-checked. ⭐
- [ ] B: Cover meditate + strikes only (the two minute-one verbs).
  Effort S. Risk: none. ⭐ if D6-A feels big — these two carry C2.

## D7 P4 rebalance door
- [ ] A: OPEN NOW — owner complaint is the journal-justification P4
  required (Q56 condition fired by complaint, not journal). Effort:
  runbooked. Risk: PIN re-anchor, bands re-derived. ⭐
- [ ] B: Stay shut (visuals/UI/juice only; curve untouched). Effort zero.
  Risk: none.

## D8 Death text (A2 finding: "A new life begins" is the whole ledger)
- [ ] A: Death ledger ("died of age at 109 — kept karma/talents, lost
  stocked qi/herbs"). Effort S. Risk: none. ⭐ (cheapest clarity lever
  in the audit)
- [ ] B: Leave as-is.

## D9 Spurious retreat spam (capture finding: "Driven back to the zone
mouth" with no fight staged — REGISTERED, see PERCEPTION_GAP.md R-P1)
- [ ] A: Fix as 1.1.0 defect (guard the empty-outcome voice).
  Effort S. Risk: none. ⭐ (a log that lies is worse than silence)
- [ ] B: Leave (accepted-with-rationale).
