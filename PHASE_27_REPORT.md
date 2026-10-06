# PHASE_27 REPORT — 0.26.0 Ley-Line Attunement (0.26a/b/c)

Release: 0.26.0. Save v13 → v14 (one field: `leyline_open`, chained
defaults-only; never v2). Theme: ATTUNEMENT — ADR-002 Option B kept,
the oldest outstanding promise in the ledger (deferred at Q17,
re-deferred at the 0.24.0 gate, physical at last).

## Gates

- Sweep: 30/30 exit 0, CSV ground truth **1342 = 1252 + 90** (closes
  exactly: 0.25.0 baseline + p27 count; CSV wins per R-S9).
- Bench (R19): green at 11 checks, sweep-caught on idle iron.
- Pacing: **73038/13 bit-identical** — five verifications across four
  shipped releases (0.22.0→0.25.0) plus this phase close. The default
  path performs no leyline multiply (branch-guarded, R-S13).
- Plateau (480s, same gate): objects 3765 → 3993 (mid) → 3943.
  Δ(0→240) = +228; Δ(240→480) = **−50** vs gate max(150, 25%×228=57).
  PASS. Second half negative (ring-reuse signature); soak bot never
  attunes and the modal never instantiates, so the trajectory is the
  expected default-inert determinism signature (fresh run confirmed).
- PCK: 12,644,208 (0.25.0) → **12,649,564** (delta +5,356 — leyline
  engine, node modal, channels table; tests/tools/docs excluded).
  Trio verified (exe+pck+dll). Docs/* remains excluded.
- R-S16: report + DECISIONS + v14 evidence + version 0.26.0 in ONE
  commit; tag + push on confirms.

## Engine-touch class (per P2 insertion contract)

Rate factor #4 (karma chain, presence, heaven_mark, now leyline) — ONE
documented multiplicative factor on the compiled qi-rate scale
(R-S7: `leyline_mult = 1 + LEYLINE_STEP_MULT × leyline_open`, step
0.08 → full ×1.64). Branch `if leyline_open > 0` post-heaven-marks
(L317-318), pre-finite-guard (L319) — the guard covers the new factor.
Inactive path performs no multiply (IEEE-exact ×1.0 never executes).

## Opt-in reference band (policy stated verbatim)

"Bot attunes the next channel whenever its realm floor is met and qi ≥
cost, checked at the generator-buy cadence; never delays breakthroughs
to attune." Result: **72,844 ticks / 13 lives / open=8** vs default
73,038/13 — delta −194 ticks (−0.27%), near-flat AS PREDICTED at the
0.26c authorization (the ladder's walls are readiness/power/duel-bound,
not rate-bound). All 8 channels open under the sane policy. Not a
defect; recorded. Tuning (LEYLINE_STEP_MULT) belongs to the 0.27.0+
window — no mid-release adjustment made.

## Q47 floors + approval

Agent-selected from the tier structure (0.26a calibration, bases
verified against realms.json generator truth): ch1 R02 · ch2 R05 ·
ch3 R08 · ch4 R12 · ch5 R16 · ch6 R20 · ch7 R23 · ch8 R25 (Nascent
Soul entry = flight unlock). Auditor-approved at 0.26a sign-off;
full list in docs/adr/P26_ATTUNEMENT_ADR.md + tools/gen_leylines.py.
APPROVED.

## Mechanism note (0.25.0 54-tick verdict — what measured)

CONFIRMED by tree, not hypothesis: standard Shaky adds +1 deviation
(permanent 10% rate bleed, GameEngine.gd L552-558) while Heaven-Shaky
REPLACES it with the demotion cycle (no double punishment, L584) and
restores deviation from snapshot (L595). HC is deviation insurance at
favored crossings. Recorded in DECISIONS.

## Offline-load one-liner

Loaded attuned save (open=2 survives `apply_state`) → 300 away-months
resolve +589.25 qi at the attuned rate: the retain-don't-clear ordering
(the inverse of P24b's presence case) verified as an explicit sequence,
not only by structural argument. Reference-setup ratio ×1.16 = 2
channels × 8% additive (Q45 formula), self-explanatory.

## v14 migration evidence

p27 migration (6 checks): SAVE_VERSION 14; v13 fixture stamped to v14
with sealed channels; existing keys preserved; v14 opening round-trips
save/load. Seven suites' stamp assertions moved 13→14 (R-S12:
save_robustness, p5, p6, p8, p21, save_v12, p26 — version bump touches,
cited here).

## Contract mechanism, second life

C5 exact-diff fired once on additive growth (+3 WorldView facade
members: take_leyline_request, meditate_at_node, _try_node_or_leyline),
re-extracted same-commit, reviewed, zero removals. The churn protocol
working at routine scale.

## Measurement note (in-suite, R-S20 home)

Virgin compiled-rate caches read 1.0 until the first recompute; ratios
against unsettled baselines are meaningless. Suites settle via the
public no-op `set_gear_mult(1.0)` (default value, unconditional
recompute), documented in p27. Real paths only: channels open via
`attune_next`, never direct var sets under measurement.

## Self-caught this release

Stray-tab SaveManager parse break (cascaded to scene stage); stale-cache
ratios; freed-twin dialog check; two obfuscated literals rewritten
plain; agent-proposed R08/R16 cost bases corrected against realms.json.
Each caught by a mechanism, each recorded.
