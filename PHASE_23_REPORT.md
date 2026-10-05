# PHASE 23 — True-3D World (0.22.0, save v12 unchanged)

Replaces the ink-wash diorama internals with nine floating zone islands
under a player-driven perspective orbit rig. Zero simulation diff, no
save migration, input map untouched. Governs: docs/adr/P23_WORLD_ADR.md
(LOCKED) + docs/adr/P23_COUPLING_ADDENDUM.md (LOCKED, Amendment 1).

## What changed

- `scripts/WorldView.gd`: islands system (`Islands/Island_<zone>`,
  active + ring-neighbors resident), orbit rig (`CamRig/Yaw/Pitch/
  Camera3D`, drag-rotate, clamped wheel zoom, F12 debug fly, UI-gated
  input), deterministic terrain (`terrain_seed = hash(map_seed, zone)`,
  pure-math heightfield, md5 vertex prints), MultiMesh props, gate walls
  shown only while locked (presentation-only, R13), warden shrines +
  tier-7 sentinel, full zone palette dressing, repositioned weather/FX/
  cultivator/presentation anchors. Facade preserved member-for-member
  except the sanctioned batch churn (removed `_build_diorama`/`_place`;
  added island/camera/input members) — contract updated in the same
  commits per the churn protocol.
- `scenes/Main.tscn`: ink grade retired from WorldDisplay (Q25 ratified);
  `assets/shaders/ink_wash.gdshader` deleted (unreferenced). Modal blur
  and button shine untouched.
- `tools/gen_zones3d.py` (new) owns `data/zones3d.json` (9 zones;
  never hand-edit). ContentDB validates additively with cross-checks:
  zone-id set match + gate values equal to beasts.json.
- `tools/p23_worldview_inventory.gd` (v3): deterministic contract
  extraction → `docs/qa/p23_worldview_contract.txt`.
- `tests/p23_world_test.gd` (new, 24 checks): contract exact-diff,
  islands/zones/gates, determinism, budgets, weather/trib, rebuild.
- `tests/p14_test.gd`: C5 rule-11 migration (camera rig, islands,
  budgets comment, ink retirement) — one commit, per-assertion citations.
- `tools/p23_shots.gd`: display-required captures (dewfield, pyrefen,
  winter, tribulation).
- `export_presets.cfg`: `docs/*` excluded from the PCK (Q26).

## Caught during implementation

1. **Ground winding backwards.** The ArrayMesh heightfield was
   backface-culled and invisible (fog + objects rendered; island missing).
   Found by fog-off diagnostic screenshot + mesh AABB probe. Fix: cull
   disabled on the ground material (robust for a heightfield).
2. **Probe-vs-prose false positive.** A review claimed the contract showed
   `_zone_of_node() -> void`; raw-byte check proved `-> String` (wrapped
   display line misread). Standing rule recorded in the addendum: verify
   signatures against raw bytes, never wrapped display output.
3. **`match` is reserved.** Test variable renamed (parse error).
4. **Paren-count parse error** in a nested sprite call — found by open/
   close byte counting. Same lesson as the guardians release.
5. **In-`_process` awaits break SceneTree probes.** The shots probe now
   uses frame stages like every other probe.
6. **Phase-number collision.** The guardians release had taken P23 in
   DECISIONS/state/report; the locked roadmap assigns P23 to the world.
   Guardians renamed to M2–M5 everywhere (report file, DECISIONS,
   state.json). Lesson: roadmap numbers are locked vocabulary.

## Gates

- All 26 suites green, 1075 counted checks (CSV ground truth
  `docs/qa/p22/sweep_summary.csv`; hand-arithmetic totals quoted in
  earlier messages are superseded — CSV wins).
- Pacing bit-identical: 73038 ticks / 13 lives (unchanged by a
  view-only rework, as required).
- Bench within P11 bands.
- 480s plateau soak: delta(0→240s) +286, delta(240→480s) −39 —
  gate max(150, 25% × 286)=150: PASS with margin. Bounded growth proven.
- p17 ring-reuse extension: second-600-lines delta −3 (|Δ| ≤ 5).
- Screenshots reviewed (4 captures; no gray void, islands/trees/rings/
  snow/tribulation all visible).
- Export with `docs/*` exclusion; PCK delta recorded below; exe+pck+dll
  verified together.
- Report gate: Q21 guardian names APPROVED FINAL (originality review:
  banned-terms grep over data files returns zero hits; neutral
  gatewarden compounds, no third-party derivation). The `provisional`
  flags are removed from the generator and data.
- Rule-11 assertion-citation audit: every edited p14 assertion carries a
  P23/Q25 citation comment; p15 victory-live flow cites the gate rule.
- ADR-002B/ADR-004 remain DEFERRED.

## PCK note

0.21.0 PCK (with docs/qa evidence aboard): 45,627,748 bytes. 0.22.0 PCK
(docs/* excluded): 12,628,840 bytes — delta −32,998,908 bytes (−72%).
Evidence stays committed for audit; it no longer ships. Native DLL still
ships beside the executable; exe+pck+dll verified together.
