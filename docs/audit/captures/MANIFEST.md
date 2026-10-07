# Audit captures — MANIFEST

Engine: `Godot_v4.6.3-stable_win64_console.exe`, run WITHOUT `--headless`
(`& $ENG --path $PRJ -s res://tools/<probe>.gd`). Viewport 1280x720.
R-S22: every settled snap fires >=20 frames after the last UI change
(tab/skin/scroll/zone/season/camera); the one transient snap is marked.

Probes (TEMP, deleted after): `tools/audit_a1a2.gd`, `tools/audit_a3.gd`,
`tools/audit_a4.gd`, `tools/audit_a5b.gd` (plus superseded `tools/audit_a5.gd`).
No game files changed (read-only; probes only added/deleted under `tools/`).

State per PNG: `realm / age / qi | skin | frames-since-last-UI-change`.
Qi values are `qi_num` floats at snap time. Long waits driven by
`set_time_scale` + frames with UI live (never `running=false`).

## A1 — fresh save progression (probe audit_a1a2, fresh wipe, 1x base)

| PNG | UI moment | State |
|---|---|---|
| `a1_first_qi_ink.png` | First Qi visible, fresh save at 1x. Panels closed. ALSO serves as A4 HUD closeup (TopBar + chronicle + world legible full-res). | realm 0, age 20/110, qi 57.85, life 1, ink, settle 70 |
| `a1_first_breakthrough_ink.png` | First breakthrough (auto-tribulation at 1000x, then back to 1x, settled). Banner FX decayed, chronicle shows crossing. | realm 1, age 94/110, qi 21.12, life 1, ink, settle 25 |
| `a2_death_moment_ink.png` | A1 first death (= A2 death moment). Last settled frame of life 1, Age 109/110. | realm 1, age 109/110, qi 35.64, life 1, ink, settle 25 |
| `a2_transition_ink.png` | **TRANSIENT** (R-S22 logged). 2 frames after life turned: death gloom + rebirth dawn-burst mid-tween, fog mid-lift. | realm 1, age 25/110, qi 817.57, life 2, ink, settle 2 (transient) |
| `a1_post_rebirth_ink.png` | Post-rebirth settled at 1x. | realm 1, age 26/110, qi 843.15, life 2, ink, settle 30 |
| `a1_realm2_ink.png` | Realm 2 arrival. Note: a second natural death (life 2→3) occurred during the 1000x drive; arrival lands in life 3. | realm 2, age 97/110, qi 88.44, life 3, ink, settle 25 |

## A2 — death text (probe audit_a1a2, chronicle + modal read)

Death-moment PNG: `a2_death_moment_ink.png` (Age 109/110, life 1).
Transition (transient): `a2_transition_ink.png` (settle 2, see above).
Post-rebirth: `a1_post_rebirth_ink.png` (settled 30f).

EXACT player-facing lines around the death (chronicle ring, in order):
- `A new life begins (life 2).` [info] — the only death/rebirth line (no cause-of-death line exists; `died("age")` is signal-only).
- `Achievement unlocked: Second Life.` [info]
- `The samsara rail opens: death kept what mattered.` [info] (tab-reveal dedication)
- `Death comes for every life. Set a pause before its years.` [info] (hint_pause)
- No modal dialog was presented for natural death (modal scan at each dump: none). Voluntary rebirth logs `This life is laid down willingly (life N).` (code path, not triggered here).
- What is kept vs lost is never stated as a death ledger in UI text; by code: karma += yield, aptitude up, sect/disciples/gear/talents/soul/guardians persist; age→18, qi→0, scars→0, meridians re-close. The closest player text is the hint `Death kept what mattered. The rest begins again.` (fires when `total_rebirths>=1` with prior progress; seen in later dumps, not in the death tick itself).
- Chronicle noise: `Driven back to the zone mouth. No shame in retreating.` [warn] repeats every ~0.25s UI poll even with no fight staged (empty `take_fight_outcome` voices a retreat). Present in all A1/A2 dumps; unrelated to death but pollutes the death narrative.

## A3 — manual fights (probe audit_a3, light drill 900xp ≈3-strike bouts)

| PNG | UI moment | State |
|---|---|---|
| `a3_fight_start_ink.png` | Fight start, HP bars full, ink, panels closed. | realm 0, age 24/110, qi 135.69, life 1, ink, fight `fighting`, settle 25 |
| `a3_fight_mid_ink.png` | Mid-fight ink after 1 landed strike (bars part-depleted, still `fighting`). | realm 0, age 24/110, qi 139.10, life 1, ink, fight `fighting`, settle 25 |
| `a3_fight_win_ink.png` | Win (`won`, HUD freed, rewards via hunt path). Win dict `{ok:true, win:true}`. | realm 0, age 25/110, qi 142.35, life 1, ink, fight `won`, settle 25 |
| `a3_fight_mid_parchment.png` | Mid-fight parchment (second den, skin switched, 1 strike in). | realm 0, age 25/110, qi 149.18, life 1, parchment, fight `fighting`, settle 25 |

## A4 — title / tabs / settings (probe audit_a4; seeded save then Continue)

Title needed a present save: probe wrote one (realm 5) before boot, so boot
held on the title (`title_visible=true, running=false`). The title PNG reads
pre-Continue engine defaults; post-Continue state is realm 5.

| PNG | UI moment | State |
|---|---|---|
| `a4_title_ink.png` | Title screen (overlay + Begin Anew / Continue Journey + version). | pre-Continue: realm 0, age 18, qi 0.0, ink, tab 0, settle 70. Save on disk: realm 5 / qi 5000 / age 30. |
| `a4_tab_sect_ink.png` | Sect tab + left rail (all nine rail names visible: Sect Alchemy Arts Soul Samsara Beasts Deeds Records Settings). Covers the "nine tabs legible" requirement alongside the three deep tabs below. | realm 5, age 30, qi 5006.99, ink, tab 0, settle 25 |
| `a4_tab_arts_ink.png` | Arts tab (drills + attunement). | realm 5, age 30, qi 5010.24, ink, tab 2, settle 25 |
| `a4_tab_beasts_ink.png` | Beasts tab (grounds + wardens + bestiary). | realm 5, age 30, qi 5013.81, ink, tab 5, settle 25 |
| `a4_tab_settings_ink.png` | Settings top (sound/music sliders, glow, skin, export/import, seclusion). | realm 5, age 30, qi 5018.85, ink, tab 8, settle 25 |
| `a4_tab_rebinds_ink.png` | Settings scrolled (scroll_vertical=900) to vendor rebind list (Maaack input options; ~20 actions). | realm 5, age 31, qi 5022.10, ink, tab 8, settle 25 |
| `a4_sweep_parchment.png` | Full UI sweep in parchment (Arts tab, panels + rail open). | realm 5, age 31, qi 5025.68, parchment, tab 2, settle 25 |

HUD closeup: no separate PNG; `a1_first_qi_ink.png` (panels closed, TopBar Realm/Age/Qi/Mind/Season/Stage/Rate/Activity + chronicle + world) is the HUD closeup and is legible at full-res.
Tabs not individually captured (tightness): Alchemy, Soul, Samsara, Deeds, Records — rail names + reveal lines cover their existence; Sect/Arts/Beasts are the three deep shots per the brief's fallback.

## A5 — islands / light (probe audit_a5b; zones via current_node, seasons pinned live)

| PNG | UI moment | State |
|---|---|---|
| `a5_dewfield_spring_node_ink.png` | Dewfield + affordance-ready node closeup (orbit dist 10, `node_affordance=ready`, avatar on marker). | realm 2, age 23, qi 20.55, ink, zone Dewfield, season 0 Spring (+Qi) Meltwater, settle 25 |
| `a5_ashbarrow_ink.png` | Ashbarrow biome (ember palette). | realm 2, age 23, qi 44.16, ink, zone Ashbarrow, season 1 Summer (+drill) Grain Fill, settle 25 |
| `a5_murkfen_shrine_ink.png` | Murkfen + shrine flame ready (`shrine_affordance(guardian_01)=ready` at tier-1-end realm 7). | realm 7, age 23, qi 63.66, ink, zone Murkfen, season 2 Autumn (+gather) Heat Haze, settle 25 |
| `a5_dewfield_winter_ink.png` | Dewfield winter lighting vs spring (same framing as spring shot). | realm 1, age 23, qi 84.21, ink, zone Dewfield, season 3 Winter (+ward) Frostfall, settle 25 |
| `a5_flight_ink.png` | Sword-flight view (realm 24 unlock per flight.json; `avatar_state=fly`). | realm 24, age 24, qi 103.78, ink, zone Dewfield, season 0 Spring Thawbreak, settle 25 |

Flight: REACHABLE (set realm 24 → `flight_unlocked=true`, "Sword-flight answers at Nascent Soul."). No refusal note needed.
Winter vs spring: `a5_dewfield_winter_ink.png` (Winter Frostfall) vs `a5_dewfield_spring_node_ink.png` (Spring Meltwater).

## A6 — motion sequence

SKIPPED as instructed (time-box; deferred). No PNGs.

## Probe failures / retries (all final runs quit 0)

- `audit_a1a2` r1: parked 1 month before death at 10x — the life turned within 1 frame, so `a2_death_moment_ink` never fired (only transition). Fixed: park 12 months out at 1x, snap the settled death-moment, then accelerate. Reran; all 6 PNGs captured.
- `audit_a3` r1: 40000xp buff one-shot every bout — `mid` snaps showed `won`, win dict empty. Fixed: light drill (900xp, ~3 strikes). Reran; start/mid=`fighting`, win=`won`.
- `audit_a5` r1: manual `apply_zone` was overwritten by the view's own `_poll_world_state` (zone derives from `current_node`), and seasons drifted at 1x — all snaps read Dewfield/spring. Superseded by `audit_a5b` (zones via `current_node` node ids, seasons repinned live each frame, running stays true). Reran; zones/seasons read correctly.
- No final probe failed. Two benign notes: Godot prints `ObjectDB instances leaked at exit` on some quits (probe teardown, not game code); A1's realm-2 drive passed through a second natural death (life 3, logged above).
