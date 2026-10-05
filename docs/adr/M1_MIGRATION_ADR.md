# M1 Architecture Decision Record — Cultivation Nation Migration

Status: LOCKED on Q17-Q22 as decided by the human's build agent (creative call
delegated 2026-10-05). Governs the 0.21.0 guardian migration release.
Supersedes all SSI prototype mechanics for the canonical tree.

Locked plan constraints (from the governing migration plan):

1. Preserve the 50-realm ladder, data, milestones, achievements, pacing.
2. Preserve deterministic readiness-gated breakthroughs and proportional costs.
3. Preserve karma, soul, gear, sect, alchemy, mind, season, technique, map,
   achievement, and offline systems.
4. Guardians are a new, separate, additive system (never reuse the beast codex).
5. Meridians enter only if approved, as additive/refactored with full spec.
6. Saves migrate v11 -> v12 forward; version 2 is unusable (collision).
7. Preserve scene architecture and `PanelScroll/PanelTabs` paths.
8. Preserve the no-new-`class_name` convention unless explicitly changed.
9. Preserve GDScript-first; no TypeScript mirror or parity gate.
10. Preserve the Windows/Forward+ export pipeline.
11. Preserve all 23 suites; update assertions intentionally, never delete.

## ADR-001 — Guardians: new, separate, additive system [LOCKED]

- Duel entities entirely disjoint from the beast codex.
- New generated table `data/guardians.json` via `tools/gen_guardians.py`
  (sibling of `gen_realms.py`). Never hand-edited. ContentDB validation
  extended: unknown fields rejected, ids prefixed `guardian_`, no beast-id
  reuse, realm anchors on macro-tier boundaries.
- Roster: 7 guardians, one per macro tier. Names deferred to the 0.21.0
  report (Q21: naming approval deferred; all names must pass the project's
  originality/clean-room review before landing).
- Duel model: deterministic, no RNG. N-wave power comparison reusing the
  tribulation resolution family (waves = 3 + tier). Cultivator effective
  power vs guardian per-wave power; outcomes mirror
  Radiant / Steady / Shaky / Defeat. Guardian power is the boundary
  tribulation power (generator-computed from realms.json) — the exact scale
  the duel defense uses — so a cultivator ready to cross blocks every strike
  and wins Radiant by construction: ceremony, stakes, and story, not a wall.
- Gating: the breakthrough crossing a macro-tier boundary additionally
  requires the previous tier's guardian defeated. Interior breakthroughs
  unchanged.
- Failure: proportional cost philosophy, no death, no stage loss, unlimited
  costed retries.
- Reward: proportional qi cache + technique XP + permanent record entry.
  Defeat status (not reward) is what persists.
- Persistence (Q18: YES): defeated status persists through Samsara. The
  Samsara reset must not clear `guardians.defeated`.
- Pacing: full-ladder re-measurement required. Guardian duels contribute
  bounded ticks; bands hold with duels included (budget: <=1% of ladder
  ticks across all seven duels at ready-state power) or bands are re-derived
  without weakening trivialization tripwires.

## ADR-002 — Meridian generators [Q17: DEFER]

Decision: **deferred to P24/P25** as ley-line attunement, when the 3D world
gives the system physical meaning. M1 locks scope as deferred.

Rationale: the game already carries techniques, gear, soul, talents,
alchemy, karma, and sect sinks. A generator track pre-3D risks redundant
complexity; the flavor lands better attached to world presence.

Options recorded: (A) additive multiplier track now — not taken;
(B) defer — TAKEN; (C) reject entirely — not taken.

## ADR-003 — Breakthrough model: determinism reaffirmed [LOCKED]

Readiness-gated deterministic resolution, multi-wave tribulations,
Radiant/Steady/Shaky outcomes, proportional failure costs: all unchanged.
The SSI probabilistic model is withdrawn. See R-1 for the only sanctioned
path by which stakes could ever modify outcomes.

## ADR-004 — Active-play premium [DEFERRED]

Presence-based meditation multiplier: decide with ADR-002 at P25, when
presence exists. Idle parity remains the default until then.

## Redesign Proposal R-1 — Deterministic Stakes Ladder [Q19: TABLED]

Tabled until post-M6. May not be implemented without explicit approval.
Mechanism sketch (thresholds, never RNG): Composed = current behavior;
Tempered = raised Radiant threshold, Steady+ rewards +25%, Shaky demotes one
stage instead of proportional cost; Heaven-Challenging = further raised
thresholds, rare material + micro-multiplier on Radiant, Shaky demotes even
at Early plus scar risk per existing rules. Deterministic and matrix-testable.
Save field if ever approved: `stakes_preference` (default "composed").
Landing: NOT in 0.21.0; single-theme releases (guardians first).

## Redesign Proposal R-2 — Legacy Echo [Q20: DEFERRED]

Withdrawn from migration scope. May resubmit post-M6 with a full pacing
study. No code, no save fields until then.

## Q21 — Guardian names and flavor [DEFERRED]

No names are locked by this ADR. The seven proposed gatewarden names remain
proposals only. Final names and duel flavor require originality review and
approval in the 0.21.0 report.

## Save Migration Manifest — v11 -> v12 [SHAPE LOCKED]

- version: 12.
- added: `guardians.defeated` (array of guardian ids; NOT reset by Samsara),
  `guardians.attempts` (id -> attempt count, records/statistics).
- contingent fields only if their proposals are later approved:
  `stakes_preference`, `meridians.open`, `meridians.attunement`.
- rules: chained migration supplies defaults only; legacy float and `{m, e}`
  BigNumber persistence untouched; `get_state()`/`apply_state()` extended in
  lockstep; backup rotation and primary->backup fallback unchanged;
  import/export revalidated against v12.

## Test Plan Delta

- new: `tests/guardians_test.gd` (roster, gating, deterministic duel matrix,
  Samsara persistence, rewards, id-collision guards),
  `tests/save_v12_migration_test.gd` (v11 fixture -> v12 defaults,
  round-trip, backup fallback, legacy bignum cases).
- contingent: `tests/stakes_test.gd`, `tests/meridians_test.gd`.
- retained: all 23 suites; assertions updated intentionally, never deleted.
- pacing re-measured on every mechanics change; Round 2 reporting closed
  before migration QA.

## Q22 — M0 execution [AUTHORIZED AND COMPLETE]

M0 was executed with verified scripts (not the vapor Batch 4R kit): local
baseline commit + tag, evidence archive, residue cleanup, full sweep,
save-only soak completion, leak triage and fix, regression test, Round 2
report, version bump, re-export. Push to any remote was NOT performed;
remote/push/force-push require separate explicit confirmation with
credentials and a verified remote.
