# P23 Coupling Addendum — Semantic Contracts for Coupled Surfaces
Status: LOCKED. Companion to P23_WORLD_ADR.md (Q23–Q28 ratified).
Source: read-only verification pass + handoff §3/§4. The contract file
enforces EXISTENCE; this doc pins SEMANTICS. Internals may change freely;
externally observable behavior of these members must not change without a
rule-11 contract edit with justification.

## C1 — cultivator_screen()  [Main.gd .call() guard]
Purpose: project the cultivator's position into the coordinate space Main
uses to anchor floating numbers / toasts / indicators over the avatar.
- Same name, same signature (probe v3 captures args/return).
- Same RETURN SPACE. The view owns all coordinate translation
  (SubViewport -> canvas). Main's call sites must not need changes.
- Behavior while held at title / world hidden must match current behavior.

## C2 — set_glow(...)  [Main.gd .call() guards, x2 call sites]
Purpose: cultivator aura / mind-state glow (handoff §3.2).
- Same name, signature, and argument semantics; glow maps onto the new
  low-poly material's emission channel. Both call sites keep working.

## C3 — died / reborn reactions  [subscriptions; engine/Main emit]
- Same signals consumed, same visual beats (buildup -> strikes -> shake ->
  death fade -> rebirth transition). No new signals invented. Engine-side
  emission untouched (engine untouched, full stop).

## C4 — _poll_engine()  [13 test call sites]
The single pump of engine state into the view; tests invoke it directly.
- Name kept, argument shape kept, idempotent per call, same poll points
  (last_quality, realm/zone/current-node state).
- Polling must NOT become implicit/automatic-only — the manual pump is a
  test dependency. Keep it the single pump.

## C5 — p14 world-path probes  [test-side assertions]
P23a step 4 (generalized per R14): enumerate EVERY p14 assertion touching
World subtree paths or camera properties; update all in ONE rule-11 commit,
one justification comment each. Preserve the path or migrate the assertion
with citation. No silent path drift.

## C6 — rebuild on seed change  [R16]
apply_state with a different map_seed (ascension path) must rebuild islands
and free prior subtrees. p23_world_test asserts node count returns to
baseline after a seed change. Same post-leak discipline as everything else.

## Determinism margin notes
- terrain_seed = hash(map_seed, zone_id) — CONFIRMED sound by read-only
  verification (map_seed written only by generate_map/apply_state).
  In-code re-verification still runs in P23a step 2 before locking.
- Map-node world positions: deterministic golden-angle ring layout keyed to
  (terrain_seed, node index). Never randomized at runtime. Same state =>
  same positions across sessions (R12).
- Gate walls are PRESENTATION-ONLY in 0.22.0 (R13). Enforcement remains
  engine-side (P8 zone gates). Avatar-level enforcement is 0.23.0 scope.
  No duplicate enforcement logic may be added.

## Enforcement mapping
- C1/C2/C4 existence + signatures : contract file (probe v3, format 3)
- C1/C2 return-space semantics    : manual review at the contract-paste
                                    checkpoint (sign-off before internals)
- C3/C6                           : p23_world_test spawn/despawn + rebuild
- C5                              : p14 suite after the rule-11 commit

---

## Amendment 1 — Semantic extensions + churn protocol (post contract review, ba28606)

### C7 — Zone API trio  [has_zone_palette / current_zone / apply_zone / _zone_of_node]
- has_zone_palette(zone: String) -> bool: PURE query over the palette
  table (zones3d.json post-rework). Unknown zone -> false. No mutation.
- current_zone() -> String: query of stored zone. Deterministic initial
  value before first poll; MUST NOT error while held at title (world
  exists behind the title overlay — same as today).
- apply_zone(zone: String) -> void: the zone-switch entry point. IDEMPOTENT
  (re-applying the current zone is a no-op or a cheap refresh). Drives
  island dressing + beast-marker rebuild for that zone.
- _zone_of_node() -> void: UPDATER, not query (contract shows -> void).
  Derives zone purely from engine current-node state via _engine() plus
  static/generated zone tables. No side channels, no caching across
  apply_state. Verified against the committed contract, not prose.

### C8 — Tribulation API  [play_tribulation / tribulation_active]
- play_tribulation(quality: String, waves: int): presentation entry only;
  cadence and outcome resolution stay engine-side (untouched). quality
  strings expected Radiant / Steady / Shaky — VERIFIED from GameEngine
  (forecast_quality returns exactly these three; other last_quality states
  are Failed/Unready/Warded/Defeated and never reach presentation).
- tribulation_active() -> bool: true from play until presentation
  completion. Main/tests may poll it; keep the meaning exact.

### C9 — Budget introspection  [count_nodes / particle_budget]
- count_nodes() -> int: recursive world-subtree node count (MultiMesh
  counts as ONE node per ADR v2). This is the C6 rebuild-assertion
  primitive (baseline before/after seed change).
- particle_budget() -> Dictionary: the p14 budget surface. Key set is
  exactly {total, max_per_effect, effects} (verified in WorldView.gd);
  the rework must preserve the key set exactly.

### Churn protocol — internals may change; the contract tracks it
- The exact-diff test enforces "contract file == re-extraction at every
  commit boundary." Therefore: whenever a WorldView change alters the
  extraction, run the probe and commit the updated contract IN THE SAME
  COMMIT as the change. The contract diff becomes the facade changelog.
- SEMANTIC FACADE (the 9 public methods + _poll_engine + the C1–C9
  surfaces) is preserved member-for-member through 0.22.0.
- OLD-DIORAMA INTERNALS (_sprite_node, _unshaded, _flat_mat, _place,
  _build_diorama, _build_cultivator sprite paths, and kin) are expected
  to be REMOVED/REPLACED. That is one batch contract-update commit with a
  summary justification — not one rule-11 edit per helper. Rule-11
  formality is reserved for semantic-facade changes.
- C6 margin: rebuild test sketch — snapshot count_nodes(), apply_state
  with an altered map_seed (ascension path), assert count returns to
  baseline after rebuild completes.

### Margins — FILLED in P23a (record-then-lock)
- Season ordinal -> name: GameEngine SEASON_NAMES = [Spring, Summer,
  Autumn, Winter]; season_index() = clampi(_month_accum / 3, 0, 3), so
  0=Spring, 1=Summer, 2=Autumn, 3=Winter. SEASON_WEATHER is indexed
  identically. LOCKED.
- Tribulation quality literals: Radiant / Steady / Shaky (presentation
  set, from forecast_quality). LOCKED.
- particle_budget() key set: {total, max_per_effect, effects}. LOCKED.
- _tier_of_realm source: reads ContentDB realms macro_tier — the SAME
  generated table the engine uses — defaulting to 1 when content is
  unreachable. Already compliant (no independent re-derivation); keep the
  pattern for zones3d.json consumers. LOCKED.
