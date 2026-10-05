# UI_SPEC — P17 locked design (reviewed against step0_*.png before building)

## Layout (1280x720 base, canvas_items + expand; verified 1920x1080, 3840x2160)
- Top bar (always on): realm + layer, age/lifespan, Qi glow progress bar
  (tweened fill), mind glyph, season token. Thin, 44px.
- Bottom action dock: Breathe / Drill / Stalk, Attempt (readiness % +
  forecast + ✓/!/✕ symbol), Travel/Wander. Hotkey hints on each (1/2/3 T W).
- Toast area above dock: max 3, auto-expire, categories (realm/karma/warn).
- Management panels: full-height right slide-overs with a tab bar — Sect,
  Alchemy, Arts (all 5 + attunement bars + focus select), Soul, Samsara
  (karma, talents, End This Life, mortality setting), Bestiary (39 entries),
  Achievements (43), Records. One panel open at a time; Esc closes.
- Log: collapsible, filterable by category (log_line gains defaulted category
  arg; all 50+ call sites keep working unchanged).
- Title overlay on boot: dim + panel (Continue if save exists else New
  Journey) + version label. Sim held until choice (no autoplay behind title).

## Type / spacing / color
- One OFL font pair max (display serif + UI sans, Latin-only), license file
  vendored; offline-policy exception recorded in DECISIONS.md.
- Scale: title 28 bold, headers 20, body 16, caption 13. Spacing grid 8px,
  panel padding 12, separations 8/4.
- Tokens (ink palette): paper #EEE8D8 text, ink #141416 panel @0.82,
  gold #D8A838 accent/ready, jade #66CC99 steady/success, cinder #E05545
  danger/strained, mist #8A93A6 secondary, focus ring white.
- One Theme resource owns everything (fonts, StyleBoxes incl. nine-slice
  rule, colors, spacing, button states normal/hover/pressed/disabled).

## Motion / feel
- Hover scale 1.03 (0.12s), press 0.95, panel slide 0.22s cubic, toast
  0.2s in / 3s hold / 0.3s out, number counting 0.4s on refresh-exempt
  labels (animated labels must live outside refresh()-rewritten text),
  banner FX unchanged (0.5s). Scale-only juice, never font size.
- Focus order top-down (dock → tabs → panel) via focus_neighbor chains;
  all 13 existing hotkeys kept + F1 help overlay listing them.
- SFX hooks through SfxSynth (new volume property, mute preserved).

## Components to build (each with headless tests)
panel, tab bar, stat row (+tooltip from data descs + computed formulas),
glow progress bar, button states, tooltip, toast queue, modal (blur backdrop
verified by screenshot against the P14 grey-output failure), pooled floating
numbers via Camera3D.unproject_position (capped pool, all signals declared),
help overlay, settings panel (volume, shader/glow toggle, mortality control,
save export/import via Documents round-trip + FileDialog).
