# PERCEPTION GAP AUDIT — "the owner played it; it feels bad"
Status: AUDITED — read-only + captures. No code, no tuning, no fixes.
Findings live in the register (§H); dispositions are auditor/owner-only.
Method: capture probes (22 PNGs + MANIFEST.md, all temp probes deleted),
two read-only inventories (cadence/juice, visual/UI), author synthesis
(translation layer here) + verification of load-bearing numbers.

## A — Evidence package
`docs/audit/captures/` (22 PNGs + MANIFEST.md with per-capture UI
moment per R-S22 + game state). Coverage: first-qi/breakthrough/death/
transition/rebirth/realm-2 (A1/A2), fight start/mid/win + parchment mid
(A3), title + Sect/Arts/Beasts/Settings/rebinds + parchment sweep (A4),
three biomes + node closeup + shrine + winter + flight at realm 24 (A5).
A6 motion deferred (noted). Probe failures retried clean (manifest).
Two capture findings (see §H R-P1, R-P2).

## B — Translation layer (auditor synthesis)

Genre conventions scored 0–2 (citations = captures):
| Convention | Score | Evidence |
|---|---|---|
| Visible animated character | 0 | static billboard, bob-only beasts; cultivator a speck at 1280 (a1/a5) |
| Immediate gain response | 1 | breakthrough full-kit; meditate/strikes/interact silent (D table) |
| One clear next action | 0 | ~35 callouts pre-input, 16 dock+bar actions vs target 1 (F2) |
| Breakthrough as EVENT | 2 | banner+floater+burst+shake+chime+modal (the only full-juice action) |
| Death as transition | 1 | FX+sound exist; text ledger MISSING ("A new life begins" is all, A2) |
| Readable numbers | 2 | hybrid formatting, rate-at-a-glance |
| Ambient idle visibility | 1 | weather/aura/affordances exist; night-void mood, static avatar |

Root causes ranked per complaint:
- C1 looks bad: missing presentation (no art direction; E3) + assets
  (no character/beast readability; E4). NOT tuning.
- C2 doesn't play well: missing feedback (D2 six "none" rows) +
  structural (auto plays breakthroughs; only 3 of ~10 verbs matter
  hour 1). NOT tuning.
- C3 aging wrong: CORE SIM CADENCE — 110.4s/life at 1x, ~11s at
  shipped 10x (~326 deaths/hour); T1 lifespans flat 110 across
  realms 1–8 so climbing never extends life. TUNING (P4 door).
- C4 UI sloppy: missing presentation review (F3 census: 10 items,
  4 code-cited + 6 capture-pending) + IA (9 tabs, 16 actions).
  NOT tuning.

## C — Cadence forensics (verified arithmetic)

- Lifespan ladder (data/realms.json): 110 (r1–8) → 250 → 650 →
  1500 → 4000 → 10000 → 1e9 (r49–50).
- Life expectancy (fresh, age 18, no bonuses): (110−18)×12 ticks ÷
  10 tps = 1104/10 = **110.4 wall-sec/life at 1x**; 3600/110.4 =
  **~32.6 deaths/hour**; at shipped 10x default: **~11.0s/life,
  ~326 deaths/hour**; at 1000x: ~0.11s/life (blurs past the 4Hz
  UI poll).
- Realm-1 fill ≈ 671 ticks ≈ 67 wall-sec at 1x (rate ~1.79):
  breakthrough mid-life, dead ~43s later anyway; T1 never extends
  life (flat 110 through realm 8).
- First-hour decisions: ~10 verbs exist, 3 matter (origin 1/life,
  focus lopsided, drill sub-choice), breakthroughs self-resolve
  (auto plays it), rest gated or invisible. Optimal hour 1:
  breathe + 1000x + walk away. (Full table in working notes.)
- Told-vs-happening: breakthroughs VISIBLE (6 surfaces); deaths
  thin (no cause/keep/lost ledger); seasons VISIBLE; mind
  word-only (numeric 0–100 invisible); roots HALF (robe tint,
  no text); sympathy INVISIBLE (applies silently, comment claims
  HUD naming that was never wired).

## D — Juice inventory (headline)

SfxSynth: 6 streams (click .06 / hover .03 / breakthrough .36 /
rebirth .40 / achievement .20 / fail .15); only 5 played via
play() — no per-strike, per-tick, per-meditate, per-travel sound.
Per-action: breakthrough = the ONLY full-juice action; meditate,
per-strike, interact-press, speed/pause (not even in HUD), drink
= NONE rows (the fix list); attune/buy/talent = cosmetic-only;
rebirth/ascension = partial (no banner/floater/shake). Full
matrix in working notes.

## E — Visual inventory (headline)

Renderer: 1 directional sun (1.1) + flat ambient; ACES + glow;
fog; zero post beyond. Palette: full table extracted (UITheme 30+
tokens, WorldView ~60 literals, 9 zone palettes) — night-void
base (bg ≤0.09) throughout. Cast: static billboard cultivator
(64×96, zero pose change except tilt/slump), hash-blob beasts
(bob only), box/cone/sphere primitives everywhere, wardens =
0.35-radius emissive balls with NO body. Self-critique: mood,
silhouette, animation, and character readability all fail the
"pleasant low-poly idle" bar; details in working notes. Asset
memo: (a) procedural+direction, (b) CC0 (vendored KenneyStarter
is UI-nine-slice ONLY — zero 3D, no island/character path
without new packs), (c) hybrid — RECOMMEND (c), first step (a)
palette/lighting.

## F — UI inventory (headline)

Shell: 18-control 48px topbar (ratchet-fixed), 10-action dock,
104px rail driving 9 headerless tabs, 392px side panel, 420px
chronicle, coach, toasts, banner. Fonts 28/20/16/13. IA: only
Beasts is truly world-duplicated (Deeds/Records are pure
archives; Sect/Cauldron/Arts duplicates unmarked). One-screen:
~35 callouts, 16 actions vs target 1 — FAIL. Sloppiness census:
10 items (overflow history, scroll dependence, slider tightness,
no-wrap buttons, modal margins, chronicle truncation, veil
capture hygiene, dual dim systems, Label3D scale, narrow mode
unverified).

## G — Decision sheet
`docs/audit/DECISION_SHEET.md` — 9 checkbox groups (D1–D9),
experience-described, effort/risk-tagged, recommendations marked.
Picks map to: asset pivot, curated opening, death-cadence number
(P4), UI/visual/juice scopes, P4 door, death ledger, spam fix.

## H — Register (post-1.0 protocol: report and STOP)

- R-P1 Spurious retreat spam (BUG-SHAPED): chronicle shows "Driven
  back to the zone mouth" with no fight staged (a1_first_qi: twice
  pre-first-input). Suspect: empty `take_fight_outcome` voiced as
  retreat. A log that lies is worse than silence. → D9.
- R-P2 "Attuning..." in a1_first_qi capture: same veil-fade-timing
  signature as the 1.0b phantom (fresh-boot snap inside the
  45-frame+fade window). Consistent with closed mechanism, NOT a
  new datum. No action.
- R-P3 Sympathy bonus applies with zero display + comment claiming
  HUD naming that was never wired (code comment vs tree truth
  mismatch). Doc-or-wire decision for 1.1.0.
- R-P4 Nine-tab IA/marking gaps (Deeds/Records mislabeled as
  duplicates; Sect/Cauldron/Arts live-duplicates unmarked).
  Design input for UI scope.
- R-P5 First-hour optimal play is breathe+1000x+walk-away; auto
  plays breakthroughs; 326 deaths/hour at default pace. The
  numbers behind "doesn't play well". P4's justification bundle.

Working notes (full C/D/E/F tables): relayed subagent outputs;
load-bearing numbers verified by author (C1 arithmetic recomputed:
92×12=1104, /10=110.4s, 3600/110.4≈32.6 ✓; fill 1200/1.79≈671
ticks ≈67s ✓). Captures: 22 PNGs + MANIFEST.md committed.
