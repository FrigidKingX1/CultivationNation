# P25 Arena ADR — Manual Combat & Shrines (0.24.0)
Status: LOCKED (Q34–Q38 answered; Q34-C design approved via P25_COMBAT_DESIGN.md).
Theme (single): AGENCY — your hands on the hunt.
Deferred (out of theme): ley-line attunement (ADR-002B), stakes (R-1),
UI evolution (P26). 0.25.0 ordering decided at the 0.24.0 gate.
Cites: rules 1, 2, 4, 5, 7, 8, 11; STANDING_RULES R-S7/R-S11/R-S12/R-S13/
R-S16; Q14=A (move + attack, one enemy at a time, no dodge/abilities v1);
Q32 (shrine interaction lands here).

## Scope lock
- HUNTING/BATTLE RESOLUTION: engine math UNTOUCHED except the Q35
  technique-XP bonus via the EXISTING XP API (opt-in-only) — the single
  permitted engine write. Manual combat is a real-time PRESENTATION of
  the same deterministic exchange the auto path resolves (Q34-C design:
  docs/adr/P25_COMBAT_DESIGN.md).
- RULE 4 WALL, restated: manual arena is for BEASTS (codex hunting).
  Guardians remain engine-resolved duels; shrines are UI entry points
  ONLY (Q32 wiring). No beast/duel conflation, no in-world guardian
  combat logic.
- Zone gates, beast-power gates: both remain engine-authoritative.
  Manual mode refuses below-gate fights with the warded-style note —
  the same refusal the auto path gives. Skill cannot bypass the math.
- Save schema: v12 UNCHANGED (technique XP is existing state; the Q35
  bonus needs no new keys).
- Input: 19 → 20 INTENTIONAL extension (world_attack, RIGHT mouse —
  Q38; LEFT is orbit-drag). p21 size assertion 19→20, collision-free
  machine-proof over (type, code) pairs, list height formula re-checked.
  Rule-11 citations.
- No new class_name. GDScript. Headless-first. Forward+.

## Manual fight model (Q34-C as approved)
- Fight = the SAME deterministic per-tick exchange the auto hunt
  resolves, run LIVE: player attacks gate the CADENCE of the
  cultivator's damage ticks (clamped at TEMPO_CLAMP_TPS); beast damage
  continues on the shared gated clock. The HP bars ARE the engine's math.
- Shared gated clock (Amendment 1): one combat tick per landed attack,
  both sides frozen without attacks. Tempo gates delivery speed only.
  Total ticks, per-tick damage, HP remaining, rewards = functions of
  (stats, seed) ONLY. Wall-clock duration = ticks / achieved tempo.
- Player influence = tempo within the math's ceiling + Q35 bonus
  conditional on tempo quality (avg landed tempo >= BONUS_TEMPO_FRAC
  of clamp). Outcome (win/loss) invariant for identical stats.
- On win: rewards flow through the EXISTING hunt path (marks, forage,
  technique XP as the engine already grants) + Q35 bonus.
- On loss (player HP zero = the math's verdict): knockback to zone
  entrance. No death, no lifespan hit, no spiral (Q37 knockback-only).
- Auto-hunt button: UNCHANGED. The bot and idle players never touch
  manual mode (R-S13 default-off).

## Encounters (Q36)
- Dens at deterministic positions: golden-angle ring per zone keyed to
  (terrain_seed, den index) — the R12 pattern, same as node markers.
  Den = existing beast marker elevated to interactable.
- One enemy at a time (Q14=A). Below-gate refusal names the gap,
  warded-style. Refusal floor: power ratio < 0.25 (intentional
  divergence from auto parity refusal, so the loss path exists; the
  [0.25, 0.5) band is an always-loses band by the math — documented).

## Shrines (Q32 landed)
- world_interact at a guardian landmark opens the EXISTING duel UI/flow.
  Presentation/UX wiring only. No new resolution code (rule 4).

## Phases
- P25a: input +1; dens + interaction + refusals; shrine wiring; contract
  churn (additive). GATE: p21 (N=20, distinct, reset, escape, height);
  contract drift green; headless boot pinned 1280x720.
- P25b: fight flow (combat actor, live HP bars from engine math, tempo
  clamp, knockback, win → existing reward path + Q35 bonus via EXISTING
  engine XP API). GATE: default pacing bit-identical 73038/13;
  outcome-invariance tests green; screenshot probes (r2 pattern).
- P25c: sweep 28/28; manual-opt-in reference bands (hunt-segment timing
  with/without bonus); 480s plateau (same gate); export + PCK delta;
  report (rule-11 audit: p21 19→20, p14 if touched; R-S16 one-commit
  ledger: report + DECISIONS + version) → 0.24.0 → tag → push [CONFIRM ×2].

## Tests
- NEW p25_arena_test.gd (28th suite; runner +1): input contract (N=20,
  distinct, replacement semantics); den placement determinism (same seed
  → same positions); below-gate refusal; OUTCOME INVARIANCE (same stats
  → same win/loss as auto resolution, across tempo patterns); tempo
  bounds; defeat knockback to zone entrance; shrine opens duel flow;
  panel-freeze (panels open mid-fight → zero HP change); budgets;
  facade contract drift; viewport pinned.
- UPDATED p21 (size, height formula) — rule-11 citations.
- P16 wires: defaults only; manual-opt-in gets its own bands (R-S13,
  written into the report verbatim — same sentence as 0.23.0).

## Amendment 2 — Tuning model, refusal divergence, semantics pins (post P25b)
- TUNING COUPLING (R-S7 extension): under symmetric HP multipliers the
  manual-fight win threshold is DERIVED: threshold = sqrt(beast_tick_frac),
  independent of HP multipliers (they cancel). Beast HP mult tunes duration
  only; beast tick frac is the sole win-threshold knob. Refusal floor (0.25)
  is an independent chosen constant. Record both in DECISIONS with the
  implied model (HP = 10x own power both sides; player deals full power;
  simultaneous tick resolution).
- REFUSAL DIVERGENCE: manual refusal (ratio < 0.25) intentionally differs
  from the auto path's parity refusal so the loss path exists. Beast-power
  ZONE gates remain engine-authoritative (R13 unaffected). The [0.25, 0.5)
  band is an always-loses band by the math — documented as intended.
- SINGLE-TICK FIGHTS: grant max tempo by definition (cannot be fought
  faster). Intended, not incidental. XP farming is bounded by existing
  hunt/respawn rules (travel tolls + wall time per fight; same XP
  available by drilling the bona fide path).
- PANEL-FREEZE: panels open mid-fight freezes combat (gated clock + input
  gating + avatar_strike suspension). Intended UX; asserted in the p25 suite.
- ADR §"manual fight model" and §"same refusal" wording are superseded by
  this amendment; the shared gated clock (Amendment 1) stands.
