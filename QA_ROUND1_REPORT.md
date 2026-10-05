# QA Round 1 Report — 2026-10-04 (bugfix round)

Engine: 4.6.3.stable.official.7d41c59c4. Version 0.20.1. Save schema v11 (unchanged).

## Method

Full 23-suite sweep capturing FAILs and script errors; verbose leak
tracing; live rendered integration driver (fresh boot, tier crossing,
rebirth, ascend+confirm, skin switch, bulk buys, 200s 1000x soak with
modal auto-dismiss); pixel-level screenshot review (boot, panels,
parchment, settings, soak, milestone).

## Bugs found and fixed (5)

1. **Title-hold starved veil + music pump.** `_process` early-returns
   while the sim is held, freezing the boot veil ("Attuning…" stuck
   behind title) and silencing the title theme. Fix: veil frames and the
   music pump run before the running gate. Caught because a stale save
   (from the soak's autosaves) held a probe boot at title.
2. **Parchment tab well fell back to default grey.** TabContainer
   `panel` stylebox was never themed — glaring against warm paper.
   Fix: card fill (borderless; the SidePanel frames it).
3. **Parchment disabled text unreadable.** MIST-on-tan for locked rails
   (~1.5:1). Fix: dedicated dark disabled tone for the parchment skin.
4. **HSlider vanishes near max.** Both volume sliders draw at 30/50/80/90
   but go fully blank approaching max (threshold ≈ panel content edge:
   400px slider in ~392px panel; grabber crossing the edge blanks the
   whole control). Fix: 300px shrink-centered sliders + CI width ratchet.
   Default SFX volume IS 100, so this hid the primary slider for every
   fresh player.
5. **Empty rebind list.** The vendor action list only shows its configured
   `input_action_names` (empty by default). Fix: set `show_all_actions`
   on instantiate (same-frame, before its deferred build) and claim 320px
   for the scroll container (built rows were squeezed to zero height).

## Cross-suite contamination (systemic fix)

p21's coach-dismiss save held the next suite's sim at title and timed p10
out — reproduced 3/3. Fixed at both ends: p21 wipes slot + player_config
at close, and every scene-booting suite (p6/p7/p8/p10/p12/p14/p15; p16/p17
already did) self-protects by wiping saves at start. Soak already cleaned
up after itself.

## Investigated, not bugs (evidence recorded)

- **Soak: 777 lives for 2 realms at 1000x, zero input.** Correct: live
  autoplay never drills (fixed power 10), so it idles at the realm-2
  power wall dying of age while the game instructs drilling. The pacing
  bot (which drills) still clears 50/13. Design, not defect; a future
  round may consider idle auto-training.
- **Ascend "loses" the triumph theme.** Correct: the next post-ascend
  breakthrough settles back to the game theme by design (verified via
  isolated probe: wanted=triumph, track follows on pump).
- **ObjectDB/resource warnings at exit.** Pre-existing engine teardown
  artifact class (verbose trace: audio + RefCounted held at process
  exit). No in-run growth, exit 0, present since P17-era sweeps.
- **Native BigNumber slower than GDScript.** Stands: ~28% per-tick cost
  from call overhead. GDScript remains primary; native stays available.

## Ratchets added

- `//`-comment scanner over `scripts/` (the author's recurring slip —
  caught two more live during this round).
- Slider-width CI assert; p17 theme asserts (tab panel, per-skin
  disabled tones); p21 music/settings/input/coach/veil/skin coverage.

## Gates

All 23 suites green (~930 checks: p21 55, p17 73). Pacing 73066/13 untouched. FPS 77.
Screenshots: coach + unlocks (boot), locked tabs (panels), parchment
(both skins verified live), rebind list populated, milestone flow.
Windows build re-exported at v0.20.1 with PCK content check.
