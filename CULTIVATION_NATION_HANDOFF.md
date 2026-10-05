# Cultivation Nation — Exhaustive Handoff

## 0. Handoff control

This is the complete starting-point document for continued work on **Cultivation Nation**.

- Project: `E:\ClaudeATHome\Projects\Cultivation Nation`
- Engine executable: `E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe`
- Engine version: `4.6.3.stable.official.7d41c59c4`
- Product version: `0.20.1`
- Save schema: `v11`
- Primary platform/rendering: Windows-only, Forward+
- Implementation language: GDScript
- Repository/version control: no Git repository was observed; do not assume commits, branches, diffs, or history are available
- Latest full automated sweep in the repository: **23 suites, 23 exits of 0, 955 counted checks**
- QA Round 1: complete and exported
- QA Round 2: in progress and interrupted before completion
- No Godot process was running when this handoff was prepared
- The proposed external TypeScript `sword-saint-idle` implementation was absent from the workspace and is therefore **not part of this baseline**

The user-selected baseline is to keep **Cultivation Nation** as the authoritative product. A second agent now has operating control and forthcoming instructions should be followed when received. This file preserves the technical starting point; it does not override later explicit user or second-agent instructions.

---

## 1. Current status snapshot

| Area | Status |
|---|---|
| Implementation | Complete through P0–P21; no standalone P20 phase |
| Product version | `0.20.1` |
| Save schema | `v11`, unchanged by QA Round 1 |
| Automated suites | 23/23 exit 0 |
| Counted checks | 955, excluding `soak_test.gd`, which passes by exit code |
| Permanent QA Round 2 checks in `p21_test.gd` | 66 |
| Round 1 export | Windows build present in `build/win` |
| Round 2 report | Not yet written |
| Round 2 version increment | Not yet made; `0.20.2` remains the expected closeout target |
| Active product defect | Unresolved soak object/memory growth |
| Incomplete investigation | `qa_r2_soak.gd -- save` isolation run |
| Local user state | Dirty: Round 2 save and rebind residue remain |
| Running Godot processes at handoff | None observed |

---

## 2. Pinned paths and operating procedures

### 2.1 Immutable paths

```text
Project:
E:\ClaudeATHome\Projects\Cultivation Nation

Godot console executable:
E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe

Main scene:
E:\ClaudeATHome\Projects\Cultivation Nation\scenes\Main.tscn

Project configuration:
E:\ClaudeATHome\Projects\Cultivation Nation\project.godot

Windows export:
E:\ClaudeATHome\Projects\Cultivation Nation\build\win\CultivationNation.exe
E:\ClaudeATHome\Projects\Cultivation Nation\build\win\CultivationNation.pck
E:\ClaudeATHome\Projects\Cultivation Nation\build\win\big_number.windows.template_release.x86_64.single.dll
```

The executable path contains spaces and must be quoted. Do not reinstall or replace the pinned engine without explicit approval.

### 2.2 Standard commands

Project gate:

```powershell
$E = "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$P = "E:\ClaudeATHome\Projects\Cultivation Nation"
& $E --headless --path $P --quit
```

Run one suite:

```powershell
$E = "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$P = "E:\ClaudeATHome\Projects\Cultivation Nation"
& $E --headless --path $P -s "res://tests/p21_test.gd"
```

A suite passes when its process exit code is `0`. Counted `PASS:` lines are useful, but exit codes are authoritative.

Repository runner:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run.ps1 gate
powershell -ExecutionPolicy Bypass -File tools\run.ps1 test
powershell -ExecutionPolicy Bypass -File tools\run.ps1 import
powershell -ExecutionPolicy Bypass -File tools\run.ps1 export-win
```

`tools/run.ps1` only runs gate, `self_test.gd`, import, or Windows export. It does not run Round 2 probes.

QA Round 2 display-required probes must run **without `--headless`**, for example:

```powershell
$E = "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$P = "E:\ClaudeATHome\Projects\Cultivation Nation"
& $E --path $P -s "res://tools/qa_r2_res.gd"
& $E --path $P -s "res://tools/qa_r2_soak.gd" -- save
```

The soak accepts one user argument:

- `all`
- `ui`
- `save`

### 2.3 PowerShell and file hazards

1. **PowerShell variables are case-insensitive.**
   - Do not use `$e` for an exit code while `$E` holds the engine path.
   - Use names such as `$exitCode`, `$enginePath`, or `$projectPath`.

2. **Do not use PowerShell text cmdlets to rewrite UTF-8 source files.**
   - A prior `Get-Content -Raw` plus `Set-Content -Encoding UTF8` operation corrupted UTF-8 in:
     - `scripts/Main.gd`
     - `tests/p17_test.gd`
   - The corruption was repaired by reversing the cp1252 round trip.
   - Use the dedicated file-editing workflow or byte-safe UTF-8 writes without a BOM.

3. **Headless layout uses a dummy viewport.**
   - Headless execution can report a square window rather than the target desktop geometry.
   - `tests/p21_test.gd` therefore explicitly pins:
     - `root.size = Vector2i(1280, 720)`
     - `root.content_scale_size = Vector2i(1280, 720)`
   - Do not remove that pinning without replacing it with an equally meaningful layout fixture.

4. **Canvas size is not necessarily window size.**
   - The project uses `canvas_items` stretch with `expand` aspect.
   - An 800×600 window can produce a 1280×960 canvas.
   - Layout assertions should generally use `get_visible_rect()` rather than assuming window pixels.

5. **QA residue contaminates later tests.**
   - Round 1 proved that leftover saves can hold a later suite at the title screen.
   - `p21_test.gd` wipes the following files before and after execution:
     - `user://cultivation_nation_save.json`
     - `user://cultivation_nation_save.bak.json`
     - `user://player_config.cfg`
   - Scene-booting suites self-protect by wiping saves at startup.
   - Despite this, Round 2 residue is currently present in the local user directory and must be handled before verification.

---

## 3. Product architecture

### 3.1 Boot and runtime flow

The main scene is:

```text
res://scenes/Main.tscn
```

Its root is `Main`, implemented by:

```text
scripts/Main.gd
```

Registered autoloads are:

```text
GameEngine="*res://scripts/GameEngine.gd"
SaveManager="*res://scripts/SaveManager.gd"
ContentDB="*res://scripts/ContentDB.gd"
SfxSynth="*res://scripts/SfxSynth.gd"
MaaackMusic="*res://addons/maaacks_music_controller/base/scenes/autoloads/project_music_controller.tscn"
MaaackUISound="*res://addons/maaacks_ui_sound_controller/base/scenes/autoloads/project_ui_sound_controller.tscn"
```

`Main._ready()` performs approximately the following operations:

1. Shows the loading veil.
2. Binds the live 3D viewport texture to the world display.
3. Sets the demonstration time scale.
4. Connects death, achievement, rebirth, and pause signals.
5. Gives `SaveManager` an engine reference.
6. Wires world data, buttons, input actions, options, help, tooltips, modal blur, mute state, version label, settings, and UI sounds.
7. Uses an existing save to decide whether to hold at the title screen.
8. Selects title or game music.
9. Refreshes sect, map, gear, pills, soul, talents, and prestige displays.

The runtime loop:

- Always advances veil and music-pump work.
- Refreshes limited UI while held at title.
- Runs autoplay, tribulation readiness checks, periodic interface refreshes, hints, and autosaves during live play.
- Autosaves approximately every 30 seconds.

Title behavior:

- `_on_title_new()` starts a fresh run.
- `_on_title_continue()` wires the world, loads the save, rewires the world, applies offline gains, hides the title screen, and starts the simulation.

### 3.2 Script responsibilities

The project uses a flat `scripts/` directory. Own code intentionally avoids new `class_name` declarations.

| Script | Responsibility |
|---|---|
| `scripts/GameEngine.gd` | Complete simulation state, tick processing, realms, roots, mind, seasons, tribulations, techniques, hunting, map, sect, gear, alchemy, karma, soul, prestige, achievements, milestones, save-state serialization, and offline resolution. |
| `scripts/Main.gd` | Scene glue, UI construction and wiring, buttons, focus, tribulation flow, rebinding, settings, themes, music direction, saves, import/export, help, veil, toasts, floating numbers, and modal presentation. |
| `scripts/SaveManager.gd` | Versioned saves, backup rotation, migration, import/export, offline calculation, and load fallback. |
| `scripts/ContentDB.gd` | Loads and validates every JSON content table. The engine receives data through setters and does not read JSON directly. |
| `scripts/SfxSynth.gd` | Procedurally synthesized sound effects, SFX volume, mute handling, and UI sounds. |
| `scripts/UIManager.gd` | Top bar, chronicle/log, toasts, floating numbers, records, breakthrough effects, responsive behavior, and skin handling. |
| `scripts/UITheme.gd` | Code-built ink and parchment themes, fonts, colors, buttons, panels, tabs, sliders, dialogs, and tooltips. |
| `scripts/UIComponents.gd` | Reusable statistic rows. |
| `scripts/UpgradeRow.gd` | Uniform shop rows with title, cost, affordability state, bulk suffix, and press behavior. |
| `scripts/ModalManager.gd` | Lifecycle-managed confirmation and report dialogs. |
| `scripts/WorldView.gd` | View-only 3D diorama, camera, environment, cultivator, aura, weather, beasts, sect representation, tribulation effects, death/rebirth transitions, and node/particle budgets. |
| `scripts/SpriteFactory.gd` | Central cached procedural-sprite factory for cultivators, beasts, and glow effects. |
| `scripts/BigNumber.gd` | True mantissa-plus-exponent big-number implementation, coercion, comparison, formatting, persistence format, and optional native backend selection. |

### 3.3 Principal scene hierarchy

Important runtime paths include:

```text
UI/Root/TopBar
UI/Root/BottomDock
UI/Root/ChroniclePanel
UI/Root/CoachPanel
UI/Root/RailPanel
UI/Root/SidePanel
UI/Root/SidePanel/PanelScroll
UI/Root/SidePanel/PanelScroll/PanelTabs
UI/Root/TitleOverlay
UI/Root/HelpOverlay
UI/LoadingVeil
WorldViewport/World
WorldDisplay
```

The nine management tabs are:

```text
Sect
Alchemy
Arts
Soul
Samsara
Beasts
Deeds
Records
Settings
```

Their full post-fix path is:

```text
UI/Root/SidePanel/PanelScroll/PanelTabs/<TabName>
```

Any old reference of the form:

```text
UI/Root/SidePanel/PanelTabs/<TabName>
```

is stale unless the referenced file was intentionally left untouched.

### 3.4 Content data

All gameplay content tables live in:

```text
data/
```

| File | Contents |
|---|---|
| `data/realms.json` | 50 generated realms, macro tiers, lifespans, tribulation waves, and power requirements. |
| `data/origins.json` | Four origins and their Qi/lifespan modifiers. |
| `data/techniques.json` | Five cultivation arts, power curves, wear behavior, and attunement perks. |
| `data/beasts.json` | 39 beasts across nine zones, elements, power, and minimum realms. |
| `data/gear.json` | Seven soul-gear items, multipliers, maximum levels, and descriptions. |
| `data/achievements.json` | 43 achievements, statistics, thresholds, and display metadata. |
| `data/prestige.json` | Three Dao nodes, ranks, and effects. |
| `data/reveal.json` | Milestone-gated tab reveal rules. |

`data/realms.json` is generated by:

```text
tools/gen_realms.py
```

Never hand-edit `data/realms.json`. Change the generator and regenerate the file.

Pills, soul paths, and talent definitions are engine constants rather than separate JSON tables.

### 3.5 Save system

Current save version:

```text
SAVE_VERSION = 11
```

Primary save:

```text
user://cultivation_nation_save.json
```

Backup:

```text
user://cultivation_nation_save.bak.json
```

`SaveManager` behavior:

- Backs up the existing slot before each save or import.
- Tries the primary slot first.
- Falls back to the backup when the primary save is missing or invalid.
- Migrates old saves through chained fill-default migrations.
- Applies offline progress using real simulated ticks, subject to an eight-hour cap.
- Ignores periods shorter than 60 seconds.
- Supports Vigil and Unfettered seclusion behavior.
- Exports and imports JSON saves through file dialogs.

The migration chain covers versions 0 through 11. Important migrations include:

- Origins, techniques, routing, and pause behavior.
- Gear, sect, and map state.
- Achievements.
- Player focus and mute.
- Hints and visited nodes.
- Roots, mind, deviation, herbs, karma, soul, and legacy state.
- Attunement and victory state.
- Offline mortality behavior.
- Big-number `{m, e}` persistence.
- Coach completion state.

`GameEngine.get_state()` and `apply_state()` must remain in lockstep. Migration functions must only supply defaults for absent data, not alter gameplay semantics.

### 3.6 Input system

`Main.gd` registers 13 documented default actions:

```text
cult_breathe
cult_drill
cult_stalk
cult_tribulation
cult_speed1
cult_speed10
cult_speed100
cult_speed1000
cult_pause
cult_hunt
cult_wander
cult_mute
cult_help
```

Escape is handled separately by raw keycode and is not a normal InputMap action.

Round 2 established these behavioral contracts:

- The currently bound action is authoritative.
- A released/rebound-away key must not continue firing.
- Rebinding replaces the previous binding; it is not additive.
- `_seed_input_defaults()` populates the vendor default snapshot with all 13 actions.
- Vendor Reset restores documented defaults rather than leaving the live rebind in place.
- `handle_shortcut()` remains the stable direct test and automation path.
- Escape still closes help first, then panels and rail.

Vendor settings persist through:

```text
user://player_config.cfg
```

That file currently contains Round 2 residue binding `cult_breathe` to physical keycode 66 (`KEY_B`).

### 3.7 Audio and music

Sound effects are procedurally synthesized by `SfxSynth`; no gameplay SFX assets are required.

Music uses three vendored lo-fi tracks:

```text
res://assets/music/title_lofi.ogg
res://assets/music/game_lofi.ogg
res://assets/music/triumph_lofi.ogg
```

Direction rules:

- Title music plays while held at the title screen.
- Game music plays for a new run, continued run, or rebirth.
- Triumph music plays for summit/ascension moments.
- Post-ascension play intentionally settles back to game music.

Music and SFX buses are installed at runtime so headless execution also has valid audio routing. UI hover/focus sounds use the UI-sound controller, while button presses use the explicit click path to avoid double playback.

### 3.8 Themes and skins

Available skins:

```text
ink
parchment
```

Themes are built in code by `UITheme.gd`, making styling diffable and testable. Fonts are loaded at runtime and include Ma Shan Zheng and Inter variants.

Theme coverage includes:

- Panels and cards
- Buttons and hover/pressed states
- Tab container wells
- Disabled text and controls
- Sliders
- Tooltips
- Dialogs
- Toasts

Round 1 proved that parchment disabled text and tab-well styling require explicit per-skin coverage.

### 3.9 Rendering and presentation

Project display configuration:

```text
viewport_width = 1280
viewport_height = 720
stretch mode = canvas_items
stretch aspect = expand
renderer = Forward+
```

The world uses:

- A dedicated 3D subviewport.
- A fixed orthographic 3/4 camera.
- A procedural ink-wash diorama.
- Seeded peaks and zone palettes.
- A robe-tinted cultivator billboard.
- Mind-colored aura.
- Soul, gear, readiness, and deviation indicators.
- Seasonal weather.
- Beast representations.
- Tribulation buildup, strikes, outcome effects, camera shake, death, and rebirth transitions.
- Ink post-processing on the world display.
- Blur on modal overlays.
- Shine effects on ready or milestone controls.

Test-enforced presentation budgets include limits on world nodes, particles, particle effects, floating numbers, toasts, and log history.

### 3.10 Export configuration

Current Windows preset:

```text
export_presets.cfg
```

Current settings include:

```text
name="Windows"
platform="Windows Desktop"
export_filter="all_resources"
exclude_filter="tests/*,tools/*,build/*,*.md,export_presets.cfg"
export_path="E:/ClaudeATHome/Projects/Cultivation Nation/build/win/CultivationNation.exe"
script_export_mode=2
binary_format/embed_pck=false
binary_format/architecture="x86_64"
```

The present repository contains:

```text
build/win/CultivationNation.exe
build/win/CultivationNation.pck
build/win/big_number.windows.template_release.x86_64.single.dll
```

Do not rely on the older P21 packaging observation without rechecking the current preset. The current preset explicitly excludes tests, tools, builds, Markdown files, and the export preset itself.

`tools/pins.txt` also contains a stale renderer entry:

```text
RENDERER=gl_compatibility
```

The live project configuration uses Forward+. Treat the pins renderer value as obsolete.

---

## 4. Completed implementation history

### 4.1 P0/P1 — Scaffold and core idle loop

Reports:

```text
PHASE_0_1_REPORT.md
```

Work completed:

- Created a runnable Godot idle game from an empty directory.
- Configured the 1280×720 canvas-items/expand display model.
- Added `GameEngine`, `SaveManager`, `ContentDB`, `BigNumber`, `UIManager`, and `Main` foundations.
- Implemented a 10 Hz base simulation tick, time scaling, low-power clamping, and catch-up limits.
- Implemented versioned JSON saves, backup rotation, and capped offline progress.
- Added content validation.
- Added automatic cultivation, tribulation, autosave, and periodic UI polling.
- Added the original 12 Tier-1 realms and four origins.
- Established the first self-contained headless tests and soak coverage.

Schema state: save v1.

### 4.2 P2 — Idle-core hardening

Report:

```text
PHASE_2_REPORT.md
```

Work completed:

- Cached the compiled Qi rate instead of recomputing it every tick.
- Added deterministic single-threaded tick scaling and clamps.
- Replaced absolute `/root` SaveManager lookups with an explicit engine reference.
- Preserved migration from legacy save fixtures.
- Extended soak coverage to 210 in-game years.
- Added performance and save-robustness tests.

No new gameplay systems were added. No worker threads were introduced, preserving deterministic headless behavior.

### 4.3 P3 — Origins, techniques, bestiary, routing, and pause

Report:

```text
PHASE_3_REPORT.md
```

Work completed:

- Added selectable, life-locked origins.
- Added dantian purity and its effect on the compiled rate.
- Added breakthrough success/failure purity effects.
- Added techniques with XP, levels, and power bonuses.
- Added beasts, zones, kills, marks, and unfinished-target seeking.
- Added route planning and automatic pause before death.
- Expanded UI coverage for origins, dantian, techniques, and marks.

Save schema moved from v1 to v2.

### 4.4 P4 — Gear, map, sect, and disciples

Report:

```text
PHASE_4_REPORT.md
```

Work completed:

- Added soul gear and multiplicative refining bonuses.
- Added a seeded hunt map with deterministic regeneration.
- Stored only map seed and current node in saves.
- Added player-named sects and recruitable disciples.
- Added gather, hunt, train, and idle disciple duties.
- Wired world data on boot and after loading saves.
- Used the best technique bonus for automatic tribulation.

Save schema moved from v2 to v3.

### 4.5 P5 — Achievements, responsive layout, effects, and balance

Report:

```text
PHASE_5_REPORT.md
```

Work completed:

- Added rule-driven achievements.
- Avoided per-tick achievement polling by checking only on relevant events.
- Made the layout responsive through container and width mappings.
- Added a breakthrough banner and fade effect.
- Established deterministic realm-curve checks.
- Rewrote the README.

Save schema moved from v3 to v4.

This phase established the important test lesson that `-s` scripts execute initialization before scene readiness, so scene assertions must be frame-driven.

### 4.6 P6 — Agency, procedural audio, and shippable exports

Report:

```text
PHASE_6_REPORT.md
```

Work completed:

- Added breathe, drill, and stalk focus modes.
- Added best-technique bonuses and disciple assignment.
- Added the 14-button action panel.
- Added tribulation, speed, pause, recruitment, gang, and mute controls.
- Added fully procedural synthesized sound effects.
- Added Web export templates and a working Web package.
- Added achievement display and control documentation.
- Added export automation.

Save schema moved from v4 to v5.

### 4.7 P7 — Missing-system wiring and Windows export

Report:

```text
PHASE_7_REPORT.md
```

Work completed:

- Wired six previously unreachable engine-complete systems to the UI.
- Added origin buttons.
- Added drill-art focus.
- Added generated sect names without free-text entry.
- Added per-disciple duty controls.
- Added hunt-map node buttons and stalking.
- Added per-item gear refining and failure feedback.
- Added the Windows x86_64 export target.
- Re-exported Web and Windows builds.

No save-schema change was required.

### 4.8 P8 — Zone gates, tutorial hints, visitation, and wandering

Report:

```text
PHASE_8_REPORT.md
```

Work completed:

- Enforced minimum-realm zone gates.
- Locked unreachable travel destinations.
- Added eight one-time tutorial hints.
- Added visited-node tracking.
- Made wandering prefer rich, walkable, unwalked destinations.
- Re-exported both builds.

Save schema moved from v5 to v6.

A first wandering implementation ignored realm gates and was corrected before tests were finalized.

### 4.9 P9 — Tier-2 expansion

Report:

```text
PHASE_9_REPORT.md
```

Work completed:

- Added realms 13–18 while preserving the exact progression curve.
- Added the Murkfen zone and associated beasts.
- Added two arts, two heirlooms, and six achievements using existing statistics.
- Derived new zones through the existing map, gate, wandering, and seeking systems without engine changes.
- Made achievement denominators dynamic.
- Updated all affected count assertions.
- Re-exported both builds.

No schema or balance changes were made.

### 4.10 P10 — Records and live playthrough proof

Report:

```text
PHASE_10_REPORT.md
```

Work completed:

- Added derived records for lives, peak realm, lifetime kills, and years.
- Added an autoplay bot that plays the live scene through buttons.
- Proved lives, realms, achievements, legacy persistence, kills, and records.
- Performed a warning sweep across all suites.
- Confirmed that the only JSON error came from a deliberately corrupt test fixture.
- Re-exported both builds.

Records are derived rather than separately saved state.

### 4.11 P11 — Pacing proof and keyboard shortcuts

Report:

```text
PHASE_11_REPORT.md
```

Work completed:

- Measured the complete 18-realm ladder.
- Found a hard stall past realm 8.
- Tuned foundation breakthrough scaling and depth-scaled drill XP.
- Achieved a full clear in 55,433 ticks and 110 lives.
- Added keyboard shortcuts routed to existing button handlers.
- Added pacing bands and shortcut-equivalence tests.
- Re-exported both builds.

The two-knob tuning change was an intentional, evidence-driven deviation from a one-knob plan.

### 4.12 P12 — Cultivation-systems rework

Report:

```text
PHASE_12_REPORT.md
```

Work completed:

- Expanded the ladder to 50 data-driven realms.
- Added seven macro tiers.
- Added realm lifespans from 110 years through agelessness.
- Partitioned each realm into Early, Middle, and Late layers.
- Added fated spiritual roots and zone sympathy.
- Added Serene, Steady, and Strained mind states.
- Added a four-season calendar.
- Added deterministic multi-wave tribulations.
- Added Radiant, Steady, and Shaky outcomes.
- Added deviation flaws and lifespan scars.
- Added garden-based alchemy, instant-brew pills, herbs, and toxicity.
- Added depth-weighted karma and three talent tracks.
- Added three soul-weapon paths.
- Added gear bequests and legacy bonuses.
- Added 39 beasts across nine zones.
- Extended compact number formatting.
- Added approximately 130 cultivation-system checks.

Save schema moved to v7.

Intentional deviations included retaining the flat file layout, omitting unavailable lint tooling, retaining floats where appropriate, and rejecting probabilistic gating and Ascension for that phase.

### 4.13 P13 — Mechanics audit and rework

Reports and records:

```text
PHASE_13_REPORT.md
AUDIT.md
HANDOFF.md
```

Work completed:

- Audited P12 through measurement before fixing it.
- Found thousands of doomed tribulation attempts.
- Found scar-caused deaths dominating lifespan mechanics.
- Found an absent Steady quality tier.
- Found invisible sympathy/season effects.
- Found a dead route planner.
- Found an ineffective mind system.
- Found zero soul XP in Tier 1.
- Found no voluntary rebirth.
- Found purposeless hunting after marks.
- Found unsurfacing bequest mathematics.

Fixes included:

- Shared readiness-gated tribulation attempts.
- Proportional failure costs.
- Removal of scars from Shaky successes.
- Restored age-driven death.
- Revived Steady outcomes.
- Made drill-versus-rest allocation economically meaningful.
- Added live readiness and forecast displays.
- Added sympathy and season readouts.
- Added voluntary reincarnation.
- Added early soul XP.
- Added hunting forage rewards.
- Added pill-shelf staleness guards.
- Named sacrificed bequest levels.
- Removed the dead route planner.
- Dropped the Web target and focused on Windows.
- Repaired the export runner’s false-failure output handling.

No save-schema change was required.

### 4.14 P14 — 2.5D presentation

Report:

```text
PHASE_14_REPORT.md
```

Work completed:

- Moved rendering from Compatibility to Forward+.
- Built a dedicated 3D viewport and ink-graded world display.
- Built a procedural diorama, peaks, palettes, weather, beasts, and sect representation.
- Built a cultivator rig with aura, soul, gear, readiness, and deviation effects.
- Built tribulation buildup, strikes, outcome effects, camera shake, death, and rebirth transitions.
- Created a centralized procedural sprite factory.
- Added ink, blur, and shine shaders.
- Added a frame-rate and screenshot probe.
- Repaired a live layout failure that had left dozens of buttons unreachable.
- Enforced world node and particle budgets through tests.

No simulation-state change was required.

Two live-render lessons were especially important:

1. Runtime code must bind the live subviewport texture; a path-based `ViewportTexture` sub-resource can resolve to an empty texture.
2. Ink shaders on a `TextureRect` must sample the assigned texture and UV coordinates, not the empty main-viewport screen texture.

### 4.15 P15 — Depth, economy, victory, and achievements

Reports:

```text
PHASE_15_REPORT.md
P15_AUDIT.md
```

Work completed:

- Added art attunement from 0 to 100.
- Added per-art power curves, wear, and attunement-gated perks.
- Made build commitment economically meaningful.
- Made the pacing policy use the same engine bonus as live play.
- Added talent, herb, refining, and recruitment sinks.
- Added a permanent realm-50 victory state.
- Added post-clear sandbox behavior.
- Added toxicity backlash at deliberately reachable toxicity.
- Added beast-power-gated hunting.
- Added travel tolls only for repeat walks.
- Expanded achievements from 27 to 43.
- Added live victory and hunting tests.

Save schema moved to v8.

### 4.16 P16 — Offline progress, reliability, and representation

Reports:

```text
PHASE_16_REPORT.md
P16_AUDIT.md
```

Work completed:

- Implemented real-tick offline simulation.
- Capped offline progress at eight hours.
- Prevented offline attempts from skipping gates.
- Added Vigil and Unfettered seclusion directives.
- Added welcome-back reporting.
- Added lower pacing tripwires against silent trivialization.
- Added sect, cauldron, herb, deviation, and beast representation.
- Added live-boot offline tests and extensive save-robustness coverage.

Save schema moved from v8 to v9.

### 4.17 P17 — Interface overhaul

Reports and specifications:

```text
PHASE_17_REPORT.md
UI_AUDIT.md
UI_SPEC.md
```

Work completed:

- Replaced the old button-column UI with a thin HUD and tabbed management panels.
- Added a code-built theme system.
- Vendored display and body fonts.
- Added realm, age, Qi, mind, season, speed, pause, sound, panel, and bulk controls.
- Added focus, attempt, stalk, wander, recruit, and gang dock controls.
- Added a save-gated title overlay.
- Added toasts, floating numbers, collapsible filtered chronicle, animated Qi display, readiness symbols, tooltips, help, and Escape layers.
- Created nine management tabs.
- Added volume, glow, mortality, export, and import settings.
- Added save export/import with backup rotation.
- Added bestiary, achievement, and attunement builders.
- Added input-contract, panel, tab, focus, and signal tests.
- Verified screenshots at multiple resolutions.
- Preserved pacing exactly, proving zero simulation changes.

### 4.18 P18 — Gradual pacing

Report:

```text
PHASE_18_REPORT.md
```

Work completed:

- Front-loaded early-realm costs.
- Fixed realm-table wiring so the current bottleneck was actually used.
- Regenerated realm data through the realm generator.
- Re-measured pacing as 73,066 ticks and 13 lives.
- Rewrote parity tests to understand front-loaded progression.
- Preserved all pacing bands.

### 4.19 P19a — True big-number mathematics

Report:

```text
PHASE_19_REPORT.md
```

Work completed:

- Promoted `BigNumber` from display formatting to a real mantissa-plus-exponent value type.
- Added arithmetic, comparison, flooring, coercion, and save-compatible representations.
- Migrated Qi, rates, bottlenecks, and lifetime earnings to big-number state.
- Preserved compatibility with legacy float saves.
- Achieved pacing identical to the float era.
- Added big-number operation, coercion, persistence, parity, and engine-integration tests.
- Moved saves to v10.

### 4.20 P19b — Ascension prestige and Dao Marks

Report:

```text
PHASE_19_REPORT.md
```

Work completed:

- Added Dao Marks based on square-root-dampened all-time Qi.
- Added Qi-flow, lifespan, and karma-tithe Dao nodes.
- Added Dao ranks and costs.
- Implemented deep world reset while preserving soul, talents, karma, records, and lifetime earnings.
- Added Samsara ledger, forecast, confirmation, and data-driven tree rows.
- Added prestige and UI-flow tests.
- Left the save schema at v10 because it was part of the same unreleased phase.

### 4.21 P19c — Interface modernization

Report:

```text
PHASE_19_REPORT.md
```

Work completed:

- Added a lifecycle-managed modal system.
- Replaced two-press ascension confirmation with managed modals.
- Added offline welcome-back reports.
- Added once-per-tier macro dedications.
- Added bulk buying for gear, brews, talents, and Dao nodes.
- Added a top-bar bulk-quantity cycler.
- Added uniform upgrade rows.
- Added a left navigation rail with gold highlighting.
- Added an ink-prestige visual reskin.
- Added modal, milestone, bulk, row, rail, and reskin tests.
- Preserved pacing and frame-rate parity.
- Released version `0.19.0`.

### 4.22 P20 — Absorbed scope

There is no standalone:

```text
PHASE_20_REPORT.md
```

P20 scope was absorbed into P21 and was never executed as a separate phase.

### 4.23 P21 — Adopted systems, audio, interface, and lo-fi music

Report:

```text
PHASE_21_REPORT.md
```

Work completed:

- Vendored community and third-party systems with licenses and attribution.
- Added optional native big-number support while retaining GDScript as primary.
- Measured native execution as approximately 28% slower per tick because call overhead dominated.
- Preserved tick-identical pacing across backends.
- Added title, game, and triumph lo-fi music direction.
- Installed runtime Music and SFX buses.
- Added UI hover and focus sounds without double-triggering button presses.
- Added persisted volume, music, glow, and skin settings.
- Added runtime InputMap actions and embedded input/video options.
- Added hard milestone-gated tabs.
- Added shop-row press effects and bulk-purchase toasts.
- Added a first-session coach overlay.
- Added transition veils.
- Added a parchment alternate skin.
- Added adopted-systems tests.
- Moved saves to v11.
- Released version `0.20.0`.

Editor-only vendor plugins were not enabled because the project uses a headless-first pipeline.

---

## 5. QA Round 1

Full record:

```text
QA_ROUND1_REPORT.md
```

### 5.1 Method

Round 1 used:

- A full 23-suite sweep.
- Failure and script-error capture.
- Verbose leak tracing.
- A live rendered integration driver covering fresh boot, tier crossing, rebirth, ascension, skin switching, bulk purchases, and a long high-speed soak.
- Pixel-level screenshot review.

### 5.2 Confirmed and fixed defects

1. **Title-hold starvation.**
   - The boot veil and music pump were trapped behind the simulation-running gate.
   - A stale save held a probe at the title screen.
   - Fix: veil and music-pump work now run before the running gate.

2. **Parchment tab-well fallback.**
   - The tab-container content area used the default grey style.
   - Fix: theme the tab panel as a borderless card framed by the side panel.

3. **Unreadable parchment disabled text.**
   - Locked controls had approximately 1.5:1 contrast.
   - Fix: use a dedicated dark disabled tone for the parchment skin.

4. **Disappearing near-maximum sliders.**
   - A 400-pixel slider in a 392-pixel panel stopped drawing near maximum.
   - The grabber crossing the content boundary blanked the entire control.
   - This affected the default-100 SFX slider for every fresh player.
   - Fix: use 300-pixel shrink-centered sliders and add a permanent width regression check.

5. **Empty vendor rebind list.**
   - The vendor action list only displayed configured action names, which were empty by default.
   - Built rows were squeezed to zero height.
   - Fix: show all actions at instantiation and reserve 320 pixels of scroll-container height.

### 5.3 Systemic test contamination

Round 1 reproduced a persistent cross-suite failure:

- `p21`’s coach-dismiss save left the next suite held at the title screen.
- `p10` timed out three out of three times.

The fix was applied at both ends:

- `p21` wipes saves and player configuration after execution.
- Scene-booting suites wipe saves before execution.

### 5.4 Investigated non-defects

Round 1 investigated but did not change the following:

- A 777-life zero-input soak stall was correct idle behavior because live autoplay does not drill.
- Post-ascension music returning to the game theme was intentional.
- Exit-time ObjectDB and resource warnings were a pre-existing engine-teardown artifact with no observed in-run growth.
- Native big-number execution remaining slower than GDScript was an accepted measured result.

### 5.5 Round 1 gates and evidence

Round 1 finished with:

- 23 green suites.
- Approximately 930 checks.
- Pacing unchanged at 73,066 ticks and 13 lives.
- Frame rate around 77 FPS.
- Windows build re-exported as `0.20.1`.
- Package-content verification.
- Retained screenshots:
  - `tools/shots/qa1_milestone.png`
  - `tools/shots/qa1_parchment_fixed.png`
  - `tools/shots/qa1_rebind.png`
  - `tools/shots/qa1_soak.png`

---

## 6. QA Round 2

No Round 2 report has yet been written. This section reconstructs Round 2 from the permanent tests, probes, repository sweep log, and observed runtime logs.

### 6.1 Latest automated-suite status

The repository contains the hidden sweep record:

```text
tests/.r2_sweep.log
```

Every listed suite exits with code 0:

| Suite | Counted checks |
|---|---:|
| `bench_test.gd` | 11 |
| `bignum_test.gd` | 54 |
| `p10_test.gd` | 13 |
| `p11_test.gd` | 21 |
| `p12_test.gd` | 130 |
| `p13_test.gd` | 35 |
| `p14_test.gd` | 72 |
| `p15_test.gd` | 60 |
| `p16_test.gd` | 12 |
| `p17_test.gd` | 81 |
| `p19c_test.gd` | 38 |
| `p21_test.gd` | 66 |
| `p3_test.gd` | 37 |
| `p4_test.gd` | 50 |
| `p5_test.gd` | 31 |
| `p6_test.gd` | 38 |
| `p7_test.gd` | 19 |
| `p8_test.gd` | 32 |
| `p9_test.gd` | 17 |
| `prestige_test.gd` | 45 |
| `save_robustness_test.gd` | 78 |
| `self_test.gd` | 16 |
| `soak_test.gd` | 0 |
| **Total** | **955** |

`soak_test.gd` passes through its exit code and contributes no counted `PASS:` lines.

The `README.md` test counts are stale. For example, it does not match the current `p21`, `p17`, `self`, `bench`, or `p12` counts. Use `tests/.r2_sweep.log` and live suite output as ground truth.

### 6.2 Session persistence verification

Temporary probes:

```text
tools/qa_r2_write.gd
tools/qa_r2_read.gd
```

The writer boots the main scene and persists:

- `cult_breathe` rebound to `KEY_B`
- SFX volume `0.25`
- Music volume `0.75`
- Parchment skin

The reader runs in a fresh process and verifies that the rebind and settings survived on disk. This tests genuine file persistence rather than in-memory state.

### 6.3 Input defects and fixes

`p21_test.gd` permanently covers two Round 2 input regressions:

1. **Released-key firing.**
   - The old legacy-key fallback made rebinding additive.
   - After rebinding breathe from `KEY_1` to `KEY_B`, the old `KEY_1` could still fire.
   - The fallback was removed from `_unhandled_key_input`.
   - The permanent test verifies that the stale key leaves focus unchanged and the new key selects cultivation.

2. **Vendor Reset failing to restore defaults.**
   - Actions were registered directly without seeding the vendor default snapshot.
   - Reset could wipe configuration while leaving the live rebind in place.
   - `_seed_input_defaults()` now seeds all 13 documented actions.
   - The permanent test verifies that the default snapshot has size 13 and that Reset restores `KEY_1`.

Temporary probe:

```text
tools/qa_r2_input.gd
```

Its verified runtime output was:

```text
QA2-INPUT start
QA2-INPUT pre-reset events=[66]
QA2-INPUT defaults_dict_size=13
QA2-INPUT post-reset events=[49] cfg=0
QA2-INPUT config_section_present=false
QA2-INPUT rebound events=[66]
QA2-INPUT after legacy KEY_1 player_focus=
QA2-INPUT after rebound KEY_B player_focus=cultivate
QA2-INPUT conflict KEY_B focus=cultivate (first action in chain wins, no error)
QA2-INPUT unbound events=[49] cfg=0
QA2-INPUT unbound no-op focus=cultivate
QA2-INPUT reset after unbind events=[49]
QA2-INPUT escape after rebind panel_visible=false
```

In that log:

- `66` is `KEY_B`.
- `49` is `KEY_1`.
- Legacy `KEY_1` correctly does nothing after rebinding.
- Rebound `KEY_B` correctly selects cultivation.
- Escape still closes the panel after rebinding.

### 6.4 Side-panel overflow defect and fix

Round 2 found a severe layout defect:

- Four tabs were taller than the available side-panel area.
- Godot expanded the panel to fit content minimum size.
- The panel grew past the bottom of a 1280×720 window.
- Sixty-two Beasts controls were unreachable.
- Settings overflowed vertically and horizontally.

The fix wraps `PanelTabs` in a scroll container:

```text
UI/Root/SidePanel/PanelScroll
UI/Root/SidePanel/PanelScroll/PanelTabs
```

The scene, scripts, tests, and probes using the old path were migrated to the new path. `PanelTabs` must not use expand/fill size flags inside the scroll container; those flags caused the tab container to be sized to the viewport instead of its tall content, defeating scrolling.

### 6.5 Permanent panel regression checks

`tests/p21_test.gd` now:

- Verifies that the scroll wrapper and tab container exist.
- Wipes saves and player configuration before and after the suite.
- Pins the layout to 1280×720.
- Visits every tab over two frames per tab.
- Allows layout and scroll ranges to settle after each tab change.
- Asserts that at least one tab is genuinely taller than the panel.
- Asserts that every tall tab is actually scrollable.
- Asserts that non-scroll content does not spill outside the canvas.
- Records tab minimum heights, tall-tab count, scrollable-tab count, panel size, viewport size, and canvas size.

Its overflow scanner intentionally skips `ScrollContainer` descendants because scrolled-out content is legitimate and reachable through scrolling.

### 6.6 Extreme-resolution verification

Temporary probe:

```text
tools/qa_r2_res.gd
```

Verified runtime results:

```text
QA2-RES start
QA2-RES size=(800, 600)
QA2-RES clip none win=(800, 600) canvas=(1280.0, 960.0)
QA2-RES panel win=(800, 600) side=(392.0, 796.0) viewport=(368.0, 780.0) tab_min=(321.0, 2106.0) bar=2122.0/780.0 fits=true scrollable=true
QA2-RES snap err=0
QA2-RES size=(1280, 720)
QA2-RES clip none win=(1280, 720) canvas=(1280.0, 720.0)
QA2-RES panel win=(1280, 720) side=(392.0, 556.0) viewport=(368.0, 540.0) tab_min=(321.0, 2106.0) bar=2122.0/540.0 fits=true scrollable=true
QA2-RES size=(2560, 1080)
QA2-RES clip none win=(2560, 1080) canvas=(1706.0, 720.0)
QA2-RES panel win=(2560, 1080) side=(392.0, 556.0) viewport=(368.0, 540.0) tab_min=(321.0, 2106.0) bar=2122.0/540.0 fits=true scrollable=true
QA2-RES size=(3840, 2160)
QA2-RES clip none win=(3840, 2160) canvas=(1280.0, 720.0)
QA2-RES panel win=(3840, 2160) side=(392.0, 556.0) viewport=(368.0, 540.0) tab_min=(321.0, 2106.0) bar=2122.0/540.0 fits=true scrollable=true
QA2-RES snap err=0
QA2-RES done
```

All four tested resolutions had:

- No non-scroll clipping.
- A fitting side panel.
- A scrollable tall tab.
- Successful screenshot saves.

The 800×600 case again demonstrates that window pixels and canvas dimensions differ under the project’s stretch behavior.

Round 2 screenshots currently staged in the repository include:

```text
tools/shots/r2_beasts_1280.png
tools/shots/r2_settings_1280.png
```

### 6.7 Long-run soak results

Temporary probe:

```text
tools/qa_r2_soak.gd
```

The soak runs for 240 seconds, opens the panel on a tall tab, cycles cultivation focus, switches tabs, and can perform periodic save/reload cycles. It samples frame time, object count, and static memory.

Complete `all` run:

```text
QA2-SOAK start seconds=240.0
QA2-SOAK frames=28445 avg_ms=8.44 fps=118.5 worst_ms=23.08 at_frame=25440
QA2-SOAK objects 3539 -> 7554 delta=4015 static_mb 71.2 -> 100.8
QA2-SOAK ticks=23999 realm=12 focus=train saves=47
QA2-SOAK verdict frames_ok=true objects_ok=false ms_ok=true
```

Complete UI-only run:

```text
QA2-SOAK start seconds=240.0 mode=ui
QA2-SOAK frames=15386 avg_ms=15.62 fps=64.0 worst_ms=25.86 at_frame=14280
QA2-SOAK objects 3539 -> 5694 delta=2155 static_mb 71.2 -> 88.7
QA2-SOAK ticks=23999 realm=12 focus=hunt saves=0
QA2-SOAK verdict frames_ok=true objects_ok=false ms_ok=true
```

Incomplete save-only run:

```text
QA2-SOAK start seconds=240.0 mode=save
```

No completion, frame, object, verdict, or `done` lines were produced by that run.

Therefore:

- Frame performance passed in both complete runs.
- Object growth failed the soak’s `<500` threshold in both complete runs.
- UI-only growth occurred without any save/load operations.
- Memory also grew in both complete runs.
- Save-only attribution remains unproven because its isolation run did not finish.

The leading hypothesis is UI or refresh-path object accumulation, but the required save-only completion and object-level leak tracing have not been performed.

---

## 7. Open work and known anomalies

### 7.1 Must-complete soak triage

1. Re-run the full save-only soak:

```powershell
$E = "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$P = "E:\ClaudeATHome\Projects\Cultivation Nation"
& $E --path $P -s "res://tools/qa_r2_soak.gd" -- save
```

2. Allow the full 240 seconds plus process shutdown.
3. Preserve the complete log.
4. If save-only object growth passes while UI-only growth fails, the UI-refresh hypothesis becomes substantially stronger.
5. If save-only growth also fails, isolate the save/load path separately.
6. Perform verbose ObjectDB, reference, node, and resource tracing using the Round 1 method.
7. Determine whether growth is:
   - A genuine leak;
   - Deferred cleanup that stabilizes over a longer run;
   - Expected accumulation in logs, toasts, floats, history, caches, or pools;
   - Or an artifact of the artificial focus/tab/save cycling.

### 7.2 Unbound-input anomaly

After explicitly clearing breathe and drill bindings, the probe observed:

```text
QA2-INPUT unbound events=[49] cfg=0
QA2-INPUT unbound no-op focus=cultivate
```

The action retained `KEY_1`, so the subsequent key press was not actually testing an unbound action.

The current vendor UI only appends a captured key and does not expose an unbind operation. Falling back to defaults is therefore reasonable resilience for missing configuration. Nevertheless, the semantics of an explicitly stored empty event list remain unconfirmed.

Do not claim that action clearing is supported until:

1. The intended empty-list behavior is defined.
2. A permanent assertion covers it.
3. The behavior is tested through the actual vendor UI path if applicable.

### 7.3 Binding-conflict behavior

Binding the same physical key to two actions does not produce an error. The first matching action in `Main._unhandled_key_input` wins. The probe documented `KEY_B` on both breathe and drill selecting cultivation.

This is currently documented behavior, not a confirmed defect. If concurrent bindings must be rejected, warned about, or prioritized differently, that rule must be specified and tested.

### 7.4 Dirty local user state

The local user directory contains Round 2 residue, including a `cult_breathe = KEY_B` configuration and Round 2 save files.

Before the next authoritative verification:

1. Ensure no needed evidence will be lost.
2. Remove or archive:
   - `user://cultivation_nation_save.json`
   - `user://cultivation_nation_save.bak.json`
   - `user://player_config.cfg`
3. Re-run the affected suites and probes from a clean state.

### 7.5 Repository-cleanup items

The following do not block the shipped game but should be resolved before final closeout:

- Remove or restore the orphan:
  - `tools/p21_probe.gd.uid`
- Repair the stale pre-`PanelScroll` path at:
  - `tools/p17_shots.gd:122`
- Update stale test counts in:
  - `README.md`
- Treat the P12-era:
  - `HANDOFF.md`
  as obsolete reference material.
- Decide whether to retain or prune temporary Round 2 probes and screenshots.
- Decide whether repository screenshots or external user-directory screenshots constitute permanent QA evidence.

---

## 8. Important non-defects and false positives

1. Full-sweep output filters must distinguish real failures from expected text.
   - Legitimate passing assertions can contain words such as “fails.”
   - The save-robustness suite intentionally uses malformed JSON fixtures.
   - Use process exit codes and `FAIL:`/script-error diagnostics, not bare substring matches.

2. Exit-time ObjectDB and resource warnings are a known engine-teardown artifact.
   - They do not by themselves establish an in-run leak.

3. Post-ascension music returning to the game theme is intentional.

4. Zero-input autoplay stalling at an early power wall is expected because live autoplay does not drill.

5. A window size and canvas size can legitimately differ under `canvas_items/expand`.

6. Content inside an active `ScrollContainer` can legitimately extend outside the visible viewport.

7. An absent input-configuration section is not necessarily an error; defaults may correctly apply.

---

## 9. Suggested starting sequence for the next agent

1. Read this handoff completely.
2. Follow any newer explicit user or second-agent instructions.
3. Verify that no unexpected Godot process is running.
4. Preserve or archive needed QA evidence.
5. Clean Round 2 save and configuration residue.
6. Run the project gate.
7. Run `p21_test.gd`.
8. Run the complete 23-suite sweep.
9. Compare the result with `tests/.r2_sweep.log`.
10. Re-run layout and input probes only if their areas are touched.
11. Do not run long soak modes concurrently with suites.
12. Complete the interrupted `qa_r2_soak.gd -- save` run.
13. Perform object-level leak isolation if growth is confirmed.
14. Resolve the empty-rebind semantic question.
15. Clean temporary probes and screenshots according to the selected release policy.
16. Write `QA_ROUND2_REPORT.md` when Round 2 is genuinely complete.
17. Update `DECISIONS.md` and applicable counts.
18. Increment the project version only after the associated work is complete.
19. Re-export Windows after updating `state.json`.
20. Verify the exported executable, PCK, and native DLL together.

---

## 10. Source and evidence index

### 10.1 Canonical implementation

```text
project.godot
scenes/Main.tscn
scripts/GameEngine.gd
scripts/Main.gd
scripts/SaveManager.gd
scripts/ContentDB.gd
scripts/SfxSynth.gd
scripts/UIManager.gd
scripts/UITheme.gd
scripts/UIComponents.gd
scripts/UpgradeRow.gd
scripts/ModalManager.gd
scripts/WorldView.gd
scripts/SpriteFactory.gd
scripts/BigNumber.gd
```

### 10.2 Content and generation

```text
data/realms.json
data/origins.json
data/techniques.json
data/beasts.json
data/gear.json
data/achievements.json
data/prestige.json
data/reveal.json
tools/gen_realms.py
```

### 10.3 Automated tests

```text
tests/self_test.gd
tests/bench_test.gd
tests/save_robustness_test.gd
tests/bignum_test.gd
tests/prestige_test.gd
tests/p19c_test.gd
tests/p3_test.gd
tests/p4_test.gd
tests/p5_test.gd
tests/p6_test.gd
tests/p7_test.gd
tests/p8_test.gd
tests/p9_test.gd
tests/p10_test.gd
tests/p11_test.gd
tests/p12_test.gd
tests/p13_test.gd
tests/p14_test.gd
tests/p15_test.gd
tests/p16_test.gd
tests/p17_test.gd
tests/p21_test.gd
tests/soak_test.gd
tests/pacing.gd
tests/.r2_sweep.log
```

### 10.4 QA probes and temporary tools

```text
tools/qa_r2_write.gd
tools/qa_r2_read.gd
tools/qa_r2_input.gd
tools/qa_r2_panel.gd
tools/qa_r2_scroll.gd
tools/qa_r2_reach.gd
tools/qa_r2_res.gd
tools/qa_r2_soak.gd
tools/frame_probe.gd
tools/p17_shots.gd
```

### 10.5 Permanent records

```text
QA_ROUND1_REPORT.md
PHASE_0_1_REPORT.md
PHASE_2_REPORT.md
PHASE_3_REPORT.md
PHASE_4_REPORT.md
PHASE_5_REPORT.md
PHASE_6_REPORT.md
PHASE_7_REPORT.md
PHASE_8_REPORT.md
PHASE_9_REPORT.md
PHASE_10_REPORT.md
PHASE_11_REPORT.md
PHASE_12_REPORT.md
PHASE_13_REPORT.md
PHASE_14_REPORT.md
PHASE_15_REPORT.md
PHASE_16_REPORT.md
PHASE_17_REPORT.md
PHASE_18_REPORT.md
PHASE_19_REPORT.md
PHASE_21_REPORT.md
DECISIONS.md
ATTRIBUTION.md
AUDIT.md
P15_AUDIT.md
P16_AUDIT.md
UI_AUDIT.md
UI_SPEC.md
README.md
state.json
HANDOFF.md
```

### 10.6 Builds and runtime outputs

```text
export_presets.cfg
tools/run.ps1
build/win/CultivationNation.exe
build/win/CultivationNation.pck
build/win/big_number.windows.template_release.x86_64.single.dll
tools/shots/qa1_milestone.png
tools/shots/qa1_parchment_fixed.png
tools/shots/qa1_rebind.png
tools/shots/qa1_soak.png
tools/shots/r2_beasts_1280.png
tools/shots/r2_settings_1280.png
```

External runtime evidence is also present under:

```text
C:\Users\dgc12\AppData\Roaming\Godot\app_userdata\Cultivation Nation\
```

including Round 2 logs, resolution screenshots, panel screenshots, saves, player configuration, and older audit screenshots.
