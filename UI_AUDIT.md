# UI_AUDIT — P17 Step 0 (2026-10-04, from tools/shots/step0_*.png)

## Cluttered
- One 40+ button scrolling column holds ALL management (sect, map, gear,
  pills, soul, talents). Core actions (focus, attempt, travel) compete for
  space with once-per-life buttons (origins, soul bind). Screenshots confirm
  most systems sit below the fold at 1280x720.
- Stats = 5 dense undifferentiated lines. No hierarchy, no emphasis, numbers
  never animate; new segments (Symp, Season tags) keep appending to the row.
- Log is unfiltered, uncollapsible, no categories; 50+ call sites share one
  RichTextLabel. Long sessions bury signal (teaching lines drown).
- Disciple dots (r=0.14) unreadable at 1280; herb bundles read fine.

## Inconsistent
- Buttons are text-only with no icons, tooltips, hover feedback, or disabled
  states. Unaffordable actions (brew at 0 herbs, talent at 0 karma) look
  identical to live ones; refusal is only discovered via log after pressing.
- Readiness is color-only on the world ring (red/green) plus bare % text —
  no shape/icon encoding anywhere.
- No title screen (boots straight into 10x autoplay), no settings (mute
  only), no version display, no save import/export UI.

## Unclear / unreachable
- Mistwalk and Stonebell have engine curves, perks, and attunement but NO
  buttons (only 3 fixed drill buttons exist) — 2 of 5 arts unreachable live.
  Input-coverage pass: every other engine action verified reachable.
- Numbers never explain themselves: no tooltips on any stat; Qi rate itself
  is never displayed (only Qi/bottleneck stocks).
- Narrow mode (<700px single column) never visually verified (only the
  width-mapping unit test).

## Working (keep)
- Readiness + forecast on the Attempt button; sympathy/season segments;
  hint + unready teaching lines fire naturally; banner FX; translucent panels;
  world/HUD compositing; 60-90 FPS with everything on.
