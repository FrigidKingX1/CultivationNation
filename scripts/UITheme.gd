extends RefCounted
## UITheme — the single project-wide Theme, built in code (not .tres) so it
## stays diffable, headless-testable, and consistent with the flat-scripts +
## preload-const conventions. Ink-wash tokens per UI_SPEC.md.
## NOTE: no class_name; load via preload const THEME.

const PAPER := Color(0.93, 0.91, 0.85, 1.0)
const PAPER_DIM := Color(0.75, 0.73, 0.68, 1.0)
const INK := Color(0.05, 0.05, 0.07, 1.0)
# P19c ink-prestige: deeper shell (readable over the bright diorama),
# brush-line border on every card, seal-red finally at work (warn/danger).
const INK_PANEL := Color(0.05, 0.05, 0.07, 0.86)
const BRUSH_LINE := Color(0.93, 0.91, 0.85, 0.22)
const SEAL := Color(0.38, 0.16, 0.12, 0.98)
const GOLD := Color(0.85, 0.66, 0.22, 1.0)
const JADE := Color(0.40, 0.80, 0.60, 1.0)
const CINDER := Color(0.88, 0.33, 0.27, 1.0)
const MIST := Color(0.54, 0.58, 0.65, 1.0)
# 0.27b affordance tokens: the world announces what it offers. READY is
# lit jade-gold (actionable now); DORMANT is cold stone (not yet). Both
# skins read these tokens — no per-skin fork.
const AFFORD_READY := Color(0.62, 1.0, 0.72, 1.0)
const AFFORD_DORMANT := Color(0.38, 0.40, 0.46, 1.0)

const FONT_DISPLAY := "res://fonts/MaShanZheng-Regular.ttf"
const FONT_BODY := "res://fonts/Inter-Regular.ttf"
const FONT_BODY_BOLD := "res://fonts/Inter-Bold.ttf"

const SIZE_TITLE: int = 28
const SIZE_HEADER: int = 20
const SIZE_BODY: int = 16
const SIZE_CAPTION: int = 13

static func load_font(path: String) -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(path)
	return f

static func _panel_style(bg: Color = INK_PANEL, line: Color = BRUSH_LINE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = line
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb

static func _btn_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0)
	return sb

static func _focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.draw_center = false
	return sb

const SKINS := ["ink", "parchment"]

static func build(skin: String = "ink") -> Theme:
	## P21: second token set ("parchment") following the starter kit's
	## variant architecture (one structure, retinted roles): warm paper
	## cards, dark ink text, bronze buttons, seal + gold accents intact.
	var text: Color = PAPER
	var text_dim: Color = MIST
	var card: Color = INK_PANEL
	var line: Color = BRUSH_LINE
	var btn: Color = Color(0.13, 0.13, 0.16, 0.92)
	var btn_hov: Color = Color(0.20, 0.20, 0.24, 0.95)
	var btn_off: Color = Color(0.09, 0.09, 0.11, 0.85)
	var trough: Color = Color(0.08, 0.08, 0.10, 0.9)
	var btn_dis_text: Color = text_dim
	if skin == "parchment":
		text = Color(0.14, 0.11, 0.08, 1.0)
		text_dim = Color(0.42, 0.36, 0.28, 1.0)
		card = Color(0.87, 0.82, 0.70, 0.94)
		line = Color(0.30, 0.22, 0.12, 0.55)
		btn = Color(0.72, 0.62, 0.46, 0.96)
		btn_hov = Color(0.80, 0.70, 0.53, 0.98)
		btn_off = Color(0.65, 0.60, 0.50, 0.85)
		trough = Color(0.55, 0.48, 0.36, 0.9)
		# QA Round 1: MIST-on-tan is unreadable for locked rails —
		# disabled buttons get their own dark tone in this skin.
		btn_dis_text = Color(0.33, 0.27, 0.19, 1.0)
	var display: FontFile = load_font(FONT_DISPLAY)
	var body: FontFile = load_font(FONT_BODY)
	var bold: FontFile = load_font(FONT_BODY_BOLD)
	var th := Theme.new()
	th.default_font = body
	th.default_font_size = SIZE_BODY
	# Labels: body text; headers use the display face via overrides.
	th.set_color("font_color", "Label", text)
	th.set_color("font_disabled_color", "Label", text_dim)
	# Buttons: fills, text, gold brush-line on hover, seal
	# press, dimmer disabled.
	var hov := _btn_style(btn_hov)
	hov.set_border_width_all(1)
	hov.border_color = GOLD
	th.set_stylebox("normal", "Button", _btn_style(btn))
	th.set_stylebox("hover", "Button", hov)
	th.set_stylebox("pressed", "Button", _btn_style(SEAL))
	th.set_stylebox("disabled", "Button", _btn_style(btn_off))
	th.set_stylebox("focus", "Button", _focus_style())
	th.set_color("font_color", "Button", text)
	th.set_color("font_hover_color", "Button", GOLD)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", btn_dis_text)
	th.set_font("font", "Button", bold)
	th.set_font_size("font_size", "Button", SIZE_BODY)
	# Panels: the translucent shell (absorbs the old _thin_overlay).
	th.set_stylebox("panel", "PanelContainer", _panel_style(card, line))
	# Progress bars: trough, gold glow fill.
	var bg := StyleBoxFlat.new()
	bg.bg_color = trough
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(4)
	fill.shadow_color = Color(0.85, 0.66, 0.22, 0.55)
	fill.shadow_size = 4
	th.set_stylebox("background", "ProgressBar", bg)
	th.set_stylebox("fill", "ProgressBar", fill)
	# Tabs: dim inactive, gold active. The content well gets the card
	# fill too (QA Round 1: without it the well falls back to the default
	# grey panel, glaring in parchment). Borderless: the SidePanel card
	# already frames it.
	th.set_stylebox("tab_unselected", "TabContainer", _btn_style(btn_off))
	th.set_stylebox("tab_selected", "TabContainer", _btn_style(btn_hov))
	th.set_stylebox("panel", "TabContainer", _panel_style(card, card))
	th.set_color("font_unselected_color", "TabContainer", text_dim)
	th.set_color("font_selected_color", "TabContainer", GOLD)
	# Tooltips: card tones, body text.
	th.set_color("font_color", "TooltipLabel", text)
	th.set_stylebox("panel", "TooltipPanel", _panel_style(card, line))
	# Dialogs (P19c modal manager): display-face gold titles on the
	# card; bodies inherit the project voice.
	th.set_font("title_font", "Window", display)
	th.set_font_size("title_font_size", "Window", SIZE_HEADER)
	th.set_color("title_color", "Window", GOLD)
	return th
