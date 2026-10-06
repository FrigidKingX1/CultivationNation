# P24 Presence ADR — Avatar & Presence (0.23.0)
Status: LOCKED (Q29–Q33 ratified by the human directly, all recommended options).
Governs: first ENGINE touch since the migration + input 13→N + ADR-004 execution.
Cites: locked plan rules 1, 5, 7, 8, 11; P23 ADR v2; coupling addendum;
STANDING_RULES R-S7/R-S11/R-S12/R-S13/R-S16.

## Theme (single): PRESENCE — the world is the menu; standing in it beats idling in it.
Deferred (out of theme): ley-line attunement (ADR-002B), stakes (R-1),
manual arena (P25/0.24.0), UI evolution (P26).

## Scope lock
- GameEngine: ONE surgical addition — presence factor API (rule-5-compliant
  documented factor). Save schema v12 UNCHANGED; presence is runtime-only
  view-driven state: not saved, reset to OFF on apply_state / new run /
  Samsara / ascension. get_state/apply_state otherwise untouched.
  [FIRST ENGINE TOUCH — full M5 discipline: pacing re-measured, all suites]
- SaveManager, BigNumber: untouched. Scene: PanelScroll/PanelTabs untouched.
- Input: 13 → 19 INTENTIONAL extension (rule 11): world_move_forward /
  world_move_back / world_move_left / world_move_right (WASD),
  world_interact (E), world_toggle_flight (F). Rebind-REPLACEMENT semantics,
  vendor reset, Escape layering all preserved. p21 size assertion 13→19;
  vendor rebind list height scales with N (Round 1 defect #5 guard).
  Defaults verified collision-free against the existing 13 (Q29 resolution:
  cult_wander default moves W→V so WASD movement is unambiguous; §7.3
  first-action-wins behavior stands, documented).
- No jump in 0.23.0 (verticality belongs to flight; keeps physics minimal).
- No new class_name. GDScript. Headless-first. Forward+.

## Avatar
- Procedural low-poly mesh built in-code (Q28 clean-room ratification
  subsumes Q9=A: no third-party rigs/assets). Robe tint + aura from
  existing cultivator presentation; set_glow maps to the new material's
  emission (C2 exact). cultivator_screen() projects the MOVING avatar —
  C1 return-space unchanged, floaters follow.
- State machine: idle / walk / meditate / fly. Transitions headless-testable.
  (P24a: idle + walk + movement; P24b: meditate + fly alongside presence/flight.)

## Camera
- Follow camera during play; P23 orbit auto-engages while panels/modals
  open (same UIManager gating source as P23 input gating — one rule, two
  cameras). Movement input gated while panels/modals open. F12 debug
  free-fly retained, clamped.

## Presence premium (ADR-004 EXECUTED in P24b)
- Engine API: set_presence(active: bool) / is_presence_active() -> bool.
  Compiled rate gains ONE factor when active: rate × presence_mult
  (×1.5 default, tunable constant, recorded in DECISIONS).
- Conditions: avatar at a map-node meditation point + meditate state +
  not paused. Any movement input breaks meditation → presence OFF.
  Meditate = standing still: premium qi vs wandering/hunting is the
  intended tension.
- R-S13: default OFF. Autoplay/pacing bot never walks → pacing MUST remain
  bit-identical 73038/13. Premium-on full-ladder reference measured at
  P24c, bands set there; P16 trivialization tripwires re-verified.
- Offline: presence ignored (8h real-tick path untouched).

## Flight
- world_toggle_flight refused with warded-style message before the unlock
  milestone; after: sword-mount pose + higher speed constant. Unlock is
  DATA-DRIVEN via the reveal.json pattern (no hardcode); agent selects the
  realm from the tier structure — Q31, approved in the 0.23.0 report.
- Gate enforcement (R13 lands here): zone walls block the AVATAR regardless
  of flight, reading existing engine zone rules — view-side enforcement of
  engine authority; no duplicate rule logic.

## Meditation nodes
- Map-node positions (golden-angle ring, R12) host node markers + an
  interaction radius; world_interact at a node → meditate state → presence.
- Shrine interaction (duel UI entry at guardian landmarks) = DEFERRED to
  P25 unless Q32 says otherwise (Q32 ratified: defer); never blocks release.

## Phases
- P24a: input extension + avatar rig + follow cam + movement/gating +
  contract updates (facade grows; churn protocol). GATE: p21 updated
  intentionally green (size N, collision-free defaults, rebind semantics,
  Escape, list height); budgets green; headless boot pinned 1280x720.
- P24b: presence API + node markers + premium wiring + flight + avatar-side
  gate blocking. GATE: default-off pacing bit-identical; premium-on
  reference recorded; screenshot probes (r2 pattern).
- P24c: sweep 27/27; 480s plateau (same gate); premium-on bands set;
  export + PCK delta; report (Q31 realm, budget deltas, rule-11 citations)
  → 0.23.0 → verify exe+pck+dll → tag → push [CONFIRM ×2].

## Tests
- NEW p24_presence_test.gd (27th suite; runner list +1): input contract
  (N actions, no default collisions, replacement semantics); presence API
  matrix (off → rate identical / on → exact factor / offline ignores /
  reset on apply_state); flight gating pre/post unlock; gate blocking;
  avatar state machine; budgets; facade contract drift; viewport pinned.
  (Presence/flight/unlock assertions land in P24b; P24a covers input,
  movement, gating, avatar idle/walk, budgets, drift.)
- UPDATED p21 (size, list height, vendor reset for N) — rule-11 citations.
- p14 budgets re-baseline for avatar/camera/node markers — intentional,
  old values in comments.
