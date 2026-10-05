extends CanvasLayer
## UIManager — responsive HUD shell. Original layout, no borrowed art/text.
## Desktop: 3-column (Stats | Actions | Log). Narrow (<700px): single column scroll.

const BN: GDScript = preload("res://scripts/BigNumber.gd")
const THEME_BUILDER: GDScript = preload("res://scripts/UITheme.gd")

@onready var _root: Control = $Root
@onready var _log: RichTextLabel = $Root/ChroniclePanel/ChronicleBox/LogText2
@onready var _banner: Label = $Root/Banner

var _narrow: bool = false
var _fx_tween: Tween = null
var ach_names: Dictionary = {}
# P17-Step2: chronicle ring buffer (cap 200, [category, text]), toast queue
# (cap 3, auto-expire), animated Qi bar target. The legacy StatsLabel/LogText
# keep updating untouched (hidden old tree still feeds every text assert).
var _log_ring: Array = []
var _log_filter: String = "all"
var _log_lines: int = 0
var _qi_bar_target: float = 0.0
var _qi_tween: Tween = null
# P17-Step4: pooled floating numbers (pre-allocated, capped, recycled via
# tween callbacks only — no custom signals to forget declaring).
const FLOAT_POOL: int = 12
var _float_pool: Array = []

func _float_layer() -> Node:
	return get_node_or_null("Root/FloatLayer")

func spawn_float(screen_pos: Vector2, text: String, color: Color) -> void:
	var layer: Node = _float_layer()
	if layer == null:
		return
	while _float_pool.size() < FLOAT_POOL:
		var pre := Label.new()
		pre.visible = false
		layer.add_child(pre)
		_float_pool.append(pre)
	var lab: Label = null
	for l in _float_pool:
		if not (l as Label).visible:
			lab = l
			break
	if lab == null:
		lab = _float_pool[0]
	lab.text = text
	lab.modulate = color
	lab.position = (screen_pos as Vector2) + Vector2(-40.0, -10.0)
	lab.scale = Vector2(0.6, 0.6)
	lab.pivot_offset = Vector2(40.0, 10.0)
	lab.visible = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(lab, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lab, "position:y", lab.position.y - 45.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(lab, "modulate:a", 0.0, 0.4).set_delay(0.25)
	tw.chain().tween_callback(func() -> void: lab.visible = false)
const TOAST_SECS: float = 3.0
# P19c ink-prestige: warn speaks seal-red (CINDER), milestones gold.
const TOAST_COLORS := {"info": Color(0.93, 0.91, 0.85, 1.0), "warn": Color(0.88, 0.33, 0.27, 1.0), "realm": Color(0.85, 0.66, 0.22, 1.0)}

func _ready() -> void:
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	# P17-Step1: the project Theme owns all panel styling (absorbs the old
	# _thin_overlay: same translucent ink values, now centralized).
	_root.theme = THEME_BUILDER.build()
	_skin = "ink"

var _skin: String = "ink"

func set_skin(skin: String) -> void:
	## P21: alternate skin ("parchment") application. Unknown names fall
	## back to ink; the call is idempotent and headless-safe.
	if skin != "parchment":
		skin = "ink"
	_skin = skin
	if _root != null:
		_root.theme = THEME_BUILDER.build(_skin)

func get_skin() -> String:
	return _skin

func _on_resize() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	apply_width(vp.get_visible_rect().size.x)

func apply_width(w: float) -> void:
	## Pure mapping: width -> narrow flag + compact HUD (secondary top-bar
	## labels hide under 700px). Same path live resize uses; directly
	## unit-testable without a display driver.
	_narrow = w < 700.0
	for n in ["MindLabel", "SeasonLabel"]:
		var lab: Label = get_node_or_null("Root/TopBar/TopBarBox/" + n) as Label
		if lab != null:
			lab.visible = not _narrow

func play_breakthrough_fx() -> void:
	## Center banner flash + fade. Headless-safe (plain Tween, no textures).
	if _banner == null:
		return
	if _fx_tween != null and _fx_tween.is_valid():
		_fx_tween.kill()
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 1)
	_fx_tween = create_tween()
	_fx_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_fx_tween.tween_callback(_banner.hide)

func fx_active() -> bool:
	return _banner != null and _banner.visible

func is_narrow_layout() -> bool:
	return _narrow

func _on_engine_update(_ticks: int) -> void:
	refresh()

func refresh() -> void:
	if not has_node("/root/GameEngine"):
		return
	var ge: Node = get_node("/root/GameEngine")
	var st: Dictionary = ge.call("get_state")
	var tech_total: int = 0
	for k in (st.get("techniques", {}) as Dictionary):
		tech_total += 1
	var marked: int = 0
	for k in (st.get("beasts", {}) as Dictionary):
		if ge.call("completion_mark", str(k)) != "none":
			marked += 1
	var paused: String = "" if bool(ge.get("running")) else "  [PAUSED]"
	var sect_name: String = str((st.get("sect", {}) as Dictionary).get("name", "—"))
	var node: String = str(st.get("current_node", "—"))
	if node == "":
		node = "—"
	var achs: Array = st.get("achievements", [])
	var latest: String = "—"
	if not achs.is_empty():
		var last_id: String = str(achs[achs.size() - 1])
		latest = str(ach_names.get(last_id, last_id))
	var ach_total: int = ach_names.size()
	if ach_total == 0:
		ach_total = achs.size()
	# Records row: all derivable, no new persisted state (realm is monotonic,
	# kills/xp accumulate, time is tick count).
	var kills: int = 0
	for k in (st.get("beasts", {}) as Dictionary):
		kills += int((st.get("beasts") as Dictionary)[k])
	var years: int = int(st.get("tick_count", 0)) / 12
	# P17-Step3: the old 5-line stats blob is gone. Records + achievements
	# rows carry the same substrings (Lives/Peak/Kills/Time, x/43, names).
	var rectext: String = "Lives %d  Peak realm %d  Kills %s  Time %dY" % [
		int(st.get("life_number", 1)), int(st.get("realm_index", 0)),
		BN.format_hybrid(float(kills)), years,
	]
	if bool(st.get("victorious", false)):
		rectext += "\nSummit cleared · COMPLETE"
	var reclab: Label = get_node_or_null("Root/SidePanel/PanelScroll/PanelTabs/Records/RecordsLabel") as Label
	if reclab != null:
		reclab.text = rectext
		reclab.tooltip_text = "Lives lived, deepest realm reached, beasts recorded, years played. Derived, never stored."
	var achhead: Label = get_node_or_null("Root/SidePanel/PanelScroll/PanelTabs/Deeds/AchieveHeader") as Label
	if achhead != null:
		achhead.text = "Achievements %d/%d, latest: %s" % [achs.size(), ach_total, latest]
	_refresh_topbar(ge, st)

func _lbl(path: String, text: String) -> void:
	var lab: Label = get_node_or_null(path) as Label
	if lab != null:
		lab.text = text

func _refresh_topbar(ge: Node, st: Dictionary) -> void:
	## P17-Step2 thin HUD: realm/age/Qi/mind/season at a glance. QiBar fill
	## tweens toward the target (animated numbers live here, never inside
	## refresh()-rewritten text). All lookups guarded: tests may read state
	## without a full HUD pass.
	_lbl("Root/TopBar/TopBarBox/RealmLabel", str(ge.call("realm_short")))
	_lbl("Root/TopBar/TopBarBox/AgeLabel", "Age %d/%d" % [int(st.get("age_years", 18)), int(st.get("lifespan_years", 60))])
	# P19a: state Qi values are Big save-dicts — format_any coerces either form.
	_lbl("Root/TopBar/TopBarBox/QiLabel", "%s/%s" % [BN.format_any(st.get("qi", 0.0)), BN.format_any(st.get("qi_bottleneck", 120.0))])
	_lbl("Root/TopBar/TopBarBox/MindLabel", str(ge.call("mind_stage_name")))
	_lbl("Root/TopBar/TopBarBox/SeasonLabel", str(ge.call("season_label")))
	var bar: ProgressBar = get_node_or_null("Root/TopBar/TopBarBox/QiBar") as ProgressBar
	if bar != null:
		var bq = BN.of(st.get("qi_bottleneck", 120.0))
		var target: float = 0.0 if bq.is_zero() else clampf(BN.of(st.get("qi", 0.0)).div(bq).to_float() * 100.0, 0.0, 100.0)
		if absf(target - _qi_bar_target) > 0.5:
			_qi_bar_target = target
			if _qi_tween != null and _qi_tween.is_valid():
				_qi_tween.kill()
			_qi_tween = create_tween()
			_qi_tween.tween_property(bar, "value", target, 0.4)

func log_line(s: String, cat: String = "info") -> void:
	# P17-Step4 fix: single append. (_log now IS the chronicle label, so the
	# old dual-write printed every line twice — caught on screenshot.)
	# P22: the ring cap alone does NOT bound the visible document — every
	# append_text() permanently retains RichTextLabel item objects, so an
	# uncapped label leaks ~1 Object per log line over long sessions
	# (proven: +496 retained per 500 appends). Rebuild from the ring once
	# the visible line count passes 2x the ring cap.
	_log_ring.append([cat, s])
	while _log_ring.size() > 200:
		_log_ring.pop_front()
	if _log == null:
		return
	if _log_filter == "all" or cat == _log_filter:
		_log.append_text(s + "\n")
		_log_lines += 1
	if _log_lines > 400:
		_rebuild_log_text()

func _rebuild_log_text() -> void:
	if _log == null:
		return
	_log.text = ""
	_log_lines = 0
	for pair in _log_ring:
		if _log_filter == "all" or str(pair[0]) == _log_filter:
			_log.append_text(str(pair[1]) + "\n")
			_log_lines += 1

func set_filter(f: String) -> void:
	## Rebuilds the visible chronicle from the ring (filtering is a view).
	if not ["all", "info", "warn"].has(f):
		return
	_log_filter = f
	_rebuild_log_text()

func toast(msg: String, cat: String = "info") -> void:
	var box: Node = get_node_or_null("Root/ToastArea")
	if box == null:
		return
	var lab := Label.new()
	lab.text = msg
	lab.modulate = TOAST_COLORS.get(cat, TOAST_COLORS["info"])
	lab.autowrap_mode = 2
	box.add_child(lab)
	# remove_child detaches synchronously (queue_free alone would leave the
	# count frozen and spin forever — caught in P17-Step2 testing).
	while box.get_child_count() > 3:
		var oldest: Node = box.get_child(0)
		box.remove_child(oldest)
		oldest.queue_free()
	var tw: Tween = create_tween()
	tw.tween_interval(TOAST_SECS)
	tw.tween_property(lab, "modulate:a", 0.0, 0.3)
	tw.tween_callback(lab.queue_free)
