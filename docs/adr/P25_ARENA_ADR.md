# P25 Arena ADR — Manual Combat & Shrines (0.24.0)
Status: DRAFT → pending Q34–Q38.
Theme (single): AGENCY — your hands on the hunt.
Deferred (out of theme): ley-line attunement (ADR-002B), stakes (R-1),
UI evolution (P26). 0.25.0 ordering decided at the 0.24.0 gate.
Cites: rules 1, 2, 4, 5, 7, 8, 11; STANDING_RULES R-S7/R-S11/R-S12/R-S13/
R-S16; Q14=A (move + attack, one enemy at a time, no dodge/abilities v1);
Q32 (shrine interaction lands here).

## Scope lock
- HUNTING/BATTLE RESOLUTION: engine math UNTOUCHED (or opt-in-only touch
  per Q35). Manual combat is a real-time PRESENTATION of the same
  deterministic exchange the auto path resolves — see Q34-A.
- RULE 4 WALL, restated: manual arena is for BEASTS (codex hunting).
  Guardians remain engine-resolved duels; shrines are UI entry points
  ONLY (Q32 wiring). No beast/duel conflation, no in-world guardian
  combat logic.
- Zone gates, beast-power gates: both remain engine-authoritative.
  Manual mode refuses below-gate fights with the warded-style note —
  the same refusal the auto path gives. Skill cannot bypass the math.
- Save schema: v12 UNCHANGED (Q35-B) or v13 with one additive field
  (Q35-A, if the bonus needs persistence — it should not; technique XP
  is existing state).
- Input: 19 → 20 INTENTIONAL extension (world_attack; default key per
  Q38). p21 size assertion 19→20, collision-free machine-proof, list
  height formula re-checked. Rule-11 citations.
- No new class_name. GDScript. Headless-first. Forward+.

## Manual fight model (Q34-A architecture)
- Fight = the SAME deterministic per-tick exchange the auto hunt
  resolves, run LIVE: player attacks gate the CADENCE of the
  cultivator's damage ticks (clamped), beast damage continues on its
  own cadence. The HP bars ARE the engine's math.
- Player influence = tempo within the math's ceiling. Outcome (win/loss)
  is invariant for identical stats — testable. Duration is human-shaped.
- On win: rewards flow through the EXISTING hunt path (marks, forage,
  technique XP as the engine already grants) + optional Q35 bonus.
- On loss (player HP zero = the math's verdict): knockback to zone
  entrance. No death, no lifespan hit, no spiral (Q37 for the cost dial).
- Auto-hunt button: UNCHANGED. The bot and idle players never touch
  manual mode (R-S13 default-off).

## Encounters (Q36)
- Dens at deterministic positions: golden-angle ring per zone keyed to
  (terrain_seed, den index) — the R12 pattern, same as node markers.
  Den = existing beast marker elevated to interactable.
- One enemy at a time (Q14=A). Below-gate refusal names the gap,
  warded-style.

## Shrines (Q32 landed)
- world_interact at a guardian landmark opens the EXISTING duel UI/flow.
  Presentation/UX wiring only. No new resolution code (rule 4).

## Phases
- P25a: input +1; dens + interaction + refusals; shrine wiring; contract
  churn (additive). GATE: p21 (N=20, distinct, reset, escape, height);
  contract drift green; headless boot pinned 1280x720.
- P25b: fight flow (combat actor, live HP bars from engine math, tempo
  clamp, knockback, win → existing reward path [+ Q35 bonus via EXISTING
  engine XP API — the only permitted engine touch, opt-in-only]).
  GATE: default pacing bit-identical 73038/13; outcome-invariance tests
  green; screenshot probes (r2 pattern).
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
  budgets; facade contract drift; viewport pinned.
- UPDATED p21 (size, height formula) — rule-11 citations.
- P16 wires: defaults only; manual-opt-in gets its own bands (R-S13,
  written into the report verbatim — same sentence as 0.23.0).
