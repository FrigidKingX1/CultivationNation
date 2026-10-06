# Cultivation Nation

Clean-room cultivation idle incremental built in Godot 4.6.3 (GDScript).
Original code, text, names, and art. Mechanics-inspired only — no assets,
dialogue, or code taken from Cycle of the First Dawn, Path of the Idle
Cultivator, or Immortality Idle. See ATTRIBUTION.md.

## Run (autonomous, headless-capable)

Engine: `E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe`

```powershell
$E = "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$P = "E:\ClaudeATHome\Projects\Cultivation Nation"
& $E --headless --path $P --quit                                   # gate: loads clean
& $E --headless --path $P -s "res://tests/self_test.gd"            # core (16)
& $E --headless --path $P -s "res://tests/bench_test.gd"           # perf (11)
& $E --headless --path $P -s "res://tests/save_robustness_test.gd" # saves (78)
& $E --headless --path $P -s "res://tests/bignum_test.gd"              # big math (54)
& $E --headless --path $P -s "res://tests/prestige_test.gd"            # ascension (45)
& $E --headless --path $P -s "res://tests/p19c_test.gd"                # interface systems (38)
& $E --headless --path $P -s "res://tests/p3_test.gd"               # systems (36)
& $E --headless --path $P -s "res://tests/p4_test.gd"               # expansion (50)
& $E --headless --path $P -s "res://tests/p5_test.gd"               # polish (31)
& $E --headless --path $P -s "res://tests/p6_test.gd"               # controls (38)
& $E --headless --path $P -s "res://tests/p7_test.gd"               # wiring (19)
& $E --headless --path $P -s "res://tests/p8_test.gd"               # hints/map (32)
& $E --headless --path $P -s "res://tests/p9_test.gd"               # tiers (17)
& $E --headless --path $P -s "res://tests/p10_test.gd"              # bot/records (13)
& $E --headless --path $P -s "res://tests/p11_test.gd"              # pacing/bands (21)
& $E --headless --path $P -s "res://tests/p12_test.gd"              # cultivation systems (130)
& $E --headless --path $P -s "res://tests/p13_test.gd"              # rework (35)
& $E --headless --path $P -s "res://tests/p14_test.gd"              # presentation (73)
& $E --headless --path $P -s "res://tests/p15_test.gd"              # depth (64)
& $E --headless --path $P -s "res://tests/p16_test.gd"              # reliability (12)
& $E --headless --path $P -s "res://tests/p17_test.gd"              # interface (83)
& $E --headless --path $P -s "res://tests/p21_test.gd"              # adopted systems (68)
& $E --headless --path $P -s "res://tests/guardians_test.gd"         # wardens/duels (79)
& $E --headless --path $P -s "res://tests/save_v12_migration_test.gd" # save v12 (9)
& $E --headless --path $P -s "res://tests/p23_world_test.gd"          # island world (24)
& $E --headless --path $P -s "res://tests/p24_presence_test.gd"       # avatar/presence (59)
& $E --headless --path $P -s "res://tests/p25_arena_test.gd"          # manual arena (58)
& $E --headless --path $P -s "res://tests/p26_stakes_test.gd"         # risk pledges (56)
& $E --headless --path $P -s "res://tests/p27_leyline_test.gd"        # ley-line attunement (90)
& $E --headless --path $P -s "res://tests/soak_test.gd"             # 210y soak (exit code)
& $E --path "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path $P  # play
```
30 suites, 1342 counted checks at 0.26.0 (soak passes by exit code). Ground truth
per release: `docs/qa/p22/sweep_summary.csv`.

## Loop

Age/realm-scaled lifespan → cultivate Qi (roots/mind/season/toxicity modulate
the compiled rate) → Late-layer tribulation: deterministic multi-wave
lightning vs shield → Radiant/Steady/Shaky quality (deviation flaws, lifespan
scars) → age-death → Samsara rebirth with aptitude `1.0 + 0.25/rebirth` plus
depth-weighted karma for 3 talent tracks. Soul weapon and bequeathed legacy
persist across all lives. Autosave every 30s with backup rotation; away-time
resolves on load by real simulation (1 month/sec, 8h cap, gates never
skipped, welcome-back summary) under a choosable seclusion directive —
Vigil stalls at death's door, Unfettered lets death resolve unseen.
Hybrid number formatting to 1e51.

## Systems

- 50-realm ladder (`120x4^i`, data-driven via `tools/gen_realms.py`), 7 macro
  tiers with stage names, per-tier lifespans (110y → ageless), 3 layers/realm
- Spiritual roots (5 elements, fated per life, zone sympathy, UI tint by glyph)
- State of mind (Serene 1.25x / Steady / Strained 0.8x; drill strains,
  breathing/travel/stalk rest — rest is a visible rate decision)
- Four-season calendar with solar-term labels (Qi/drill/gather/ward rotation)
- Tribulation waves (tier-scaled strikes, regenerating shield, leak vs core),
  readiness-gated attempts (doomed crossings refused cost-free, proportional
  failure costs), failure teeth (proportional Qi/scars/purity loss), Strained
  crossings leave flaws; live readiness + forecast on the Attempt button
- Alchemy-lite (herb garden + gather disciples, 4 instant-brew pills, toxicity
  to a 0.5x floor, purge by cleansing/travel/rest)
- Samsara karma (`kmax^2 x log Qi`, 3 talent tracks uncapped with scaling
  costs, voluntary reincarnation button), soul weapon (3 paths with distinct
  bonuses — blade power, bell wards, mirror tithes karma; wave-tempered incl.
  +2 per T1 crossing, persists death), gear bequest (+0.02 legacy each;
  refining never caps, overflow feeds the late Qi sink)
- Toxicity backlash: crossing triumphant at toxicity 24+ scars despite
  victory (purge, rest, or travel first); weak stalkings yield less and rattle
- Hunt milestones forage herbs (marked +25, apex +100) into the cauldron
- Origins (4, locked per life) + dantian purity in compiled tick rate
- Techniques (5 arts with distinct curves, wear, and attunement-gated perks;
  attunement 0-100 rises while drilled, decays otherwise; commitment builds)
- Bestiary (39 beasts, 9 zones; marked@5k, apex@20k; seek-unfinished automation)
- Seeded hunt map (36 nodes, seed + current node stored, regenerates identically)
- Soul-gear (7 items, refine at `100x4^lvl` Qi, multiplicative legacy bonus)
- Sect + disciples (cap `2+realm`, gather/hunt/train/idle tasks)
- Pause-before-death, 43 achievements (realms to 50, systems, True Bestiary).
  Old 3-column UI replaced in P17 (route planner cut in P13: dead with no
  setter or UI).
- Macro-tier wardens (M2–M5): 7 generated guardians, one per tier, bar the
  breakthrough leaving their tier (including the final ladder-clearing
  crossing). Deterministic N-wave duels on the tribulation-power scale;
  proportional defeat costs, first-win rewards, victories persist rebirth
  and ascension. Roster + Challenge buttons live in the Beasts tab.
- Avatar presence (P24): walkable cultivator on the active island (WASD,
  19 rebindable actions; wander default V), follow camera, meditate at map
  nodes for x1.5 Qi, sword-flight from Nascent Soul, avatar-side zone walls.
- Procedural sound (synthesized chimes, zero assets, mute + volume slider)

## Interface (P17 overhaul, P19c modernization, P21 adoption)

Thin top bar (realm, age, animated Qi glow bar, mind, season, speeds, pause,
sound, panels toggle, bulk-quantity cycler) over the world; bottom action
dock (Breathe/Drill/Stalk with hotkey hints, Attempt with live readiness +
forecast + symbol, Stalk, Wander, Recruit, gang duties). Only breathing
cultivates Qi: drill yields xp plus heart-strain, stalk yields kills plus
ease. A left-nav rail drives the nine headerless management panels (Sect,
Alchemy, Arts incl. all 5 drills + attunement bars, Soul & Relics, Samsara
incl. origins/talents/rebirth/ascension, Beasts incl. grounds, Deeds incl.
43 achievements, Records, Settings): tabs unlock by milestones with named
requirements, active tab lit gold. Repeatable shops (forge, brews, talents,
dao) are uniform rows with live costs, dim-when-broke states, press squash,
and bulk buying (x1/x10/MAX from the top bar). Destructive and story moments
arrive as modals: ascension confirm, welcome-back offline report, macro-tier
dedications (once each). A first-session coach tracks breathe/drill/attempt
until dismissed. Lofi direction (title/journey/triumph themes, Eric Matyas
via soundimage) with per-bus volume, persisted settings, rebindable keys,
and display options. Ink or parchment skins. Title screen (New/Continue +
version) gates runs with saves; F1 help overlay; Esc closes help/panels/rail;
toast notifications; collapsible filterable chronicle; pooled floating
numbers off the cultivator; shine sweeps on ready/milestone controls; blur
modal backdrops. Shortcuts: 1/2/3 focus, T tribulation, 7/8/9/0 speed,
Space pause, H stalk, W wander, M mute, F1 help, Esc close (all rebindable).
Records (lives, peak realm, kills, years) derived.

## Pacing (measured, `tests/pacing.gd` + `p11_test`)

Readiness-gated play (train to ready, breathe to fill, attempt) clears all
50 realms in ~73k ticks (13 lives): ~2h at 1x, ~12min at the 10x default.
The ladder is front-loaded (10x cost at realm 1 decaying to parity by
realm 9): the early game takes sessions to lift off, then rebirth
compounding accelerates the back half. Realm 3 lands ~2.5k ticks.
Attunement (up to +50% power when fully drilled) compounds with drill curves.
Zero doomed attempts fire; all deaths are natural age deaths. Per-realm effort
holds ~steady (x4 foundation against x4 bottlenecks); drill xp scales with
depth. Typical (non-optimal) play runs several times slower. Clearing the
ladder records a permanent victory (Summit Cleared). Lower bands (clear ≥
30k ticks, lives ≥ 5) tripwire against silent trivialization.

## Presentation (true-3D islands, P23)

Nine floating zone islands in a cloud sea under a player-driven perspective
orbit rig (drag-rotate, clamped wheel zoom, F12 debug fly; input suspends
while panels are open). Islands generate deterministically from the hunt-map
seed; active island plus ring-neighbors resident; zone gates stand as
presentation-only walls (enforcement stays engine-side). The cultivator
billboard (robe tinted by dominant root) rides the active island with its
mind-colored aura, soul charm, gear ring, and green/amber/red readiness
ring. Tribulations strike over the cultivator with outcome-scaled bursts
and shake; death slumps grey, rebirth dawn-relights. Seasonal weather,
tier light grades, beast markers, sect dots, cauldron/herb stock, deviation
glow, and warden shrines (gold flame on tier-threshold isles, white
sentinel at the ladder's end) complete the scene. Ink grade retired in
favor of pure low-poly; modal blur and button shine retained. Node and
particle budgets remain test-enforced. Headless suites unaffected.

## Builds

- Windows: `build/win/CultivationNation.exe` (x86_64, Forward+ renderer).
  Web target dropped in P13.
Rebuild: `tools/run.ps1 export-win`. Presets exclude tests, tools, docs,
and prior builds from packages.



## Balance note (verified by p5_test math checks)

Realm curve is monotonic, pure 4x past realm 9 with a front-load
(10x→1x) over realms 1–8 (1-ulp JSON-parser tolerance at 3 of 50 entries,
proven by probe); realm 1 takes ~700 ticks at base rate (slow onboarding);
the 50-realm total (~5e31) formats compactly. End-to-end pacing across
lives/aptitude/gear/sect/karma compounds multiplicatively by design —
long-campaign timing is documented here as an estimate, not a test promise.
Qi runs on true big math (mantissa+exponent, exact past float range;
pacing tick-identical to the float era). Ascension prestige: all-time Qi
feeds sqrt-dampened Dao Marks (first yield at 1M lifetime), spent on a
3-node tree (Qi flow, lifespan, karma tithe); ascending resets the world
but never soul, talents, karma, or records. Save schema v10 (Qi economy
as {m, e} dicts + dao ledger); v9 and older migrate with fill-defaults.
