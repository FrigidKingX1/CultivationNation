# Attribution

Cultivation Nation's story text, area/character names (e.g. Dustroot Field,
Wayfarer, Ironhide), art, and save data are original inventions, inspired by
the *mechanics* of cultivation idle games as a genre (including ideas studied
from public descriptions of Cycle of the First Dawn, Path of the Idle
Cultivator, and the open-source Immortality Idle — no code or text copied
from any of them).

Since P20 the project directly reuses the following open-source works
(personal build; licenses and notices preserved per their terms):

## Code libraries (MIT)

- ChronoDK GodotBigNumberClass (`third_party/ChronoDK-Big/`, MIT) —
  big-number core reference; its optimized descendant below is the live path.
- shoyguer big-number v1.1 (`addons/big_number/`, MIT, Windows bins only) —
  native big-number core behind the `BN` adapter (bench-decided primary).
- Maaack Godot-Game-Template v1.7.1 (`addons/maaacks_*`, MIT © Marek Belski;
  full text in `third_party/Maaack-LICENSE.txt`) — options framework, music
  controller, scene loader, UI-sound controller (runtime parts integrated
  manually for the headless-first pipeline; no editor wizard used).
- Kingsmai kenney-ui-pack-starter-kit (`third_party/KenneyStarter/`, MIT per
  its README; ships Kenney UI Pack art under CC0, kenney.nl) — variant
  architecture reference for the alternate skin (kit textures themselves
  clash with the ink look and are not applied).

## Music (free, attribution required)

- Eric Matyas, soundimage.org — `assets/music/title_lofi.ogg` (Game Menu
  Looping LoFi), `game_lofi.ogg` (Mind Bender LoFi), `triumph_lofi.ogg`
  (Treasure Cave LoFi). Free for use with attribution; OGG format loops
  cleanly in-engine.

## Bundled fonts (P17, SIL Open Font License 1.1)

- Ma Shan Zheng Regular (display face) — Google Fonts, OFL-1.1. Latin subset
  vendored as `fonts/MaShanZheng-Regular.ttf`. Full text in `fonts/OFL.txt`.
- Inter Regular + Bold (UI body) — Google Fonts, OFL-1.1, vendored as
  `fonts/Inter-Regular.ttf` and `fonts/Inter-Bold.ttf`.
Downloaded once from public font CDNs; no network use at runtime. The
offline-capable policy holds: these files ship in the repo and the build.
