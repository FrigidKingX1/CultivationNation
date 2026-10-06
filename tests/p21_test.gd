extends SceneTree
## P21 — adopted-systems proofs. Run with:
## --headless -s res://tests/p21_test.gd (exit 0 = pass).
## Covers music direction + buses + persisted settings, input actions and
## options scenes, hard tab gates, coach derivation, veil, skins, and the
## v10->v11 coach migration. Native backend parity lives in bignum_test.

var _failures: int = 0
var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null
var _over_idx: int = -1
var _overflow_bad: int = 0
var _overflow_tabs: TabContainer = null
var _overflow_canvas: Vector2 = Vector2.ZERO
var _overflow_scroll: ScrollContainer = null
var _overflow_bad_names: Array = []
var _overflow_tall: int = 0
var _overflow_scrollable: int = 0
var _overflow_tab_mins: Array = []
var _overflow_side_y: float = 0.0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	ge.call("set_realm_table", JSON.parse_string(f.get_as_text()))
	f.close()
	var rf: FileAccess = FileAccess.open("res://data/reveal.json", FileAccess.READ)
	ge.call("set_reveal_rules", JSON.parse_string(rf.get_as_text()))
	rf.close()
	return ge

func _initialize() -> void:
	print("P21-TEST start")
	# QA Round 2: wipe before AND after. Wiping only at the end let a
	# leftover rebind from any earlier run (or a manual probe) leak in,
	# and this suite asserts default key bindings.
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_test_no_cpp_comments()
	_test_gates()
	_test_migration()

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		# QA Round 2: pin the viewport. Headless reports a square dummy
		# window, which hides exactly the 720p clipping this ratchet hunts.
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 2:
		_test_music_buses()
		_test_settings_input()
		_test_coach_veil_skin()
		_test_panel_overflow()
		_stage = 2
		_frames = 0
	elif _stage == 2:
		if _test_panel_overflow_step():
			if _failures == 0:
				print("P21-TEST PASS")
			else:
				printerr("P21-TEST FAIL count=", _failures)
			quit(_failures)
	elif _frames > 3600:
		printerr("P21-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_panel_overflow() -> void:
	## QA Round 2 ratchet. The side panel is anchored to the window, but
	## Godot clamps a Control up to its content minimum size — four tabs
	## (Soul/Samsara/Beasts/Settings) were far taller than the panel, so the
	## panel grew past the window bottom and 62 controls on Beasts became
	## unreachable at 1280x720 with no scroll parent. The fix wraps the tab
	## container in PanelScroll. This walks every tab, one per frame, and
	## asserts nothing spills past the window.
	var scroll: ScrollContainer = _scene_main.get_node_or_null("UI/Root/SidePanel/PanelScroll") as ScrollContainer
	var tabs: TabContainer = _scene_main.get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	if scroll == null or tabs == null:
		_check(false, "panel scroll wrapper present")
		return
	_check(true, "panel scroll wrapper present")
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 12)
	ge.set("qi", 9.87e12)
	_scene_main.call("_refresh_all")
	(_scene_main.get_node("UI/Root/SidePanel") as PanelContainer).visible = true
	_overflow_canvas = root.get_visible_rect().size
	_overflow_scroll = scroll
	_overflow_tabs = tabs
	_overflow_bad = 0
	_overflow_tall = 0
	_overflow_scrollable = 0
	_overflow_bad_names = []
	_over_idx = 0

func _test_panel_overflow_step() -> bool:
	## Returns true when the walk is finished. Two frames per tab: the first
	## activates the tab, the second measures it, because minimum sizes and
	## scroll ranges only settle after a sort pass. `current_tab` doubles as
	## the phase marker so no extra state member is needed.
	if _overflow_tabs == null:
		return true
	var tabs: TabContainer = _overflow_tabs
	if _over_idx >= tabs.get_tab_count():
		_check(_overflow_tall > 0, "at least one tab is taller than the panel (tall=" + str(_overflow_tall) + ")")
		_check(_overflow_tall == _overflow_scrollable, "every tall tab is scrollable (tall=" + str(_overflow_tall) + " scrollable=" + str(_overflow_scrollable) + ")")
		_check(_overflow_bad == 0, "no tab content spills past the window (worst=" + str(_overflow_bad) + " " + str(_overflow_bad_names) + ")")
		print("QA2-INFO tab_min=", str(_overflow_tab_mins), " tall=", str(_overflow_tall), " scrollable=", str(_overflow_scrollable), " side=", str(_overflow_side_y), " viewport=", str(_overflow_scroll.size), " canvas=", str(_overflow_canvas))
		_over_idx = -1
		return true
	if tabs.current_tab != _over_idx:
		tabs.current_tab = _over_idx
		return false
	var bar: VScrollBar = _overflow_scroll.get_v_scroll_bar()
	var tab: Control = tabs.get_tab_control(_over_idx)
	var viewport_y: float = _overflow_scroll.size.y
	if tab != null:
		var need: float = maxf(tab.get_combined_minimum_size().y, _overflow_tabs.size.y)
		_overflow_tab_mins.append(int(need))
		if need > viewport_y + 1.0:
			_overflow_tall += 1
			if bar.max_value > bar.page:
				_overflow_scrollable += 1
			else:
				_overflow_bad_names.append(str(_over_idx))
	_scan_overflow(_scene_main)
	_overflow_side_y = (_scene_main.get_node("UI/Root/SidePanel") as Control).size.y
	_over_idx += 1
	return false

func _scan_overflow(n: Node) -> void:
	for c in n.get_children():
		if c is ScrollContainer:
			continue
		if c is Control:
			var ctl := c as Control
			if ctl.is_visible_in_tree():
				var g: Rect2 = ctl.get_global_rect()
				if g.position.x < -1.0 or g.position.y < -1.0 or g.end.x > _overflow_canvas.x + 1.0 or g.end.y > _overflow_canvas.y + 1.0:
					_overflow_bad += 1
					if _overflow_bad_names.size() < 4:
						_overflow_bad_names.append(str(ctl.name))
		_scan_overflow(c)

func _test_no_cpp_comments() -> void:
	## QA Round 1 ratchet: GDScript uses `#`; `//` (except in URLs) is a
	## recurring authoring slip. Fails on the first offending line.
	var bad: Array = []
	var dir: DirAccess = DirAccess.open("res://scripts")
	for f in dir.get_files():
		if not str(f).ends_with(".gd"):
			continue
		var fh: FileAccess = FileAccess.open("res://scripts/" + str(f), FileAccess.READ)
		var ln: int = 0
		for line in fh.get_as_text().split("\n"):
			ln += 1
			# URLs carry :// legitimately; anything left is a C++ comment.
			if "//" in str(line).replace("://", ""):
				bad.append("%s:%d" % [str(f), ln])
		fh.close()
	_check(bad.is_empty(), "no C++ comments in scripts (first: %s)" % str(bad.slice(0, 1)))

func _test_gates() -> void:
	var GE0: GDScript = load("res://scripts/GameEngine.gd")
	var bare: Node = GE0.new()
	root.add_child(bare)
	_check(not bool(bare.call("reveal_wired")), "unwired engine reports unwired")
	_check((bare.call("tabs_unlocked") as Array).is_empty(), "unwired engine opens nothing (Main holds status quo)")
	bare.queue_free()
	var ge: Node = _new_engine()
	# Fresh exile: core loop only.
	ge.call("set_reveal_rules", [])
	ge.set("realm_index", 0)
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_reveal_rules", cdb.get("reveal"))
	cdb.free()
	var open0: Array = ge.call("tabs_unlocked")
	_check(open0.has("Arts") and open0.has("Records") and open0.has("Settings"), "fresh exile sees core tabs")
	_check(not open0.has("Samsara"), "samsara gated at start")
	_check(not open0.has("Sect"), "sect gated at start")
	ge.set("realm_index", 2)
	_check((ge.call("tabs_unlocked") as Array).has("Beasts"), "realm 2 opens beasts")
	_check(not (ge.call("tabs_unlocked") as Array).has("Sect"), "sect waits for realm 3")
	ge.set("realm_index", 3)
	_check((ge.call("tabs_unlocked") as Array).has("Sect"), "sect opens at realm 3")
	ge.set("herbs", 5.0)
	_check((ge.call("tabs_unlocked") as Array).has("Alchemy"), "first herbs open alchemy")
	ge.set("total_rebirths", 1)
	_check((ge.call("tabs_unlocked") as Array).has("Samsara"), "first rebirth opens samsara")
	_check("rail opens" in ge.call("reveal_line", "Samsara"), "dedication lines exist")
	# (Requirement naming lives in Main._reveal_need — covered by the p17
	# rail test asserting "rebirths" in the lock tooltip.)
	ge.set("achievements", ["ach_first_breath"])
	_check((ge.call("tabs_unlocked") as Array).has("Deeds"), "first deed opens deeds")
	ge.call("roll_roots", 7)
	ge.set("beasts", {"beast_mistralhare": 5000})
	_check((ge.call("tabs_unlocked") as Array).has("Soul"), "first mark opens soul")
	# Coach dismissal round-trips through state.
	_check(not bool(ge.get("coach_done")), "coach starts undone")
	ge.set("coach_done", true)
	var st: Dictionary = ge.call("get_state")
	_check(bool((st as Dictionary).get("coach_done", false)), "coach dismissal saved")
	var GE2: GDScript = load("res://scripts/GameEngine.gd")
	var ge2: Node = GE2.new()
	root.add_child(ge2)
	ge2.call("apply_state", st)
	_check(bool(ge2.get("coach_done")), "coach dismissal restored")
	ge.queue_free()
	ge2.queue_free()

func _test_migration() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var ge: Node = GE.new()
	ge.set_name("GameEngine")
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	var slot := "user://cultivation_nation_save.json"
	if FileAccess.file_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot))
	var bak := "user://cultivation_nation_save.bak.json"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
	var eng: Dictionary = {"tick_count": 1, "coach_done": false}
	var f: FileAccess = FileAccess.open(slot, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 10, "engine": eng, "extra": {}}))
	f.close()
	var loaded: Dictionary = sm.call("load_game")
	_check(int(loaded.get("save_version", 0)) == 12, "v10 fixture stamped to v12")
	_check(bool((loaded.get("engine", {}) as Dictionary).has("coach_done")), "v10->v11 fills coach default")
	_check(not bool(ge.get("coach_done")), "old saves never saw the coach")
	ge.queue_free()
	sm.queue_free()
	if FileAccess.file_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot))
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))

func _test_music_buses() -> void:
	_check(AudioServer.get_bus_index("Music") >= 0, "music bus installed")
	_check(AudioServer.get_bus_index("SFX") >= 0, "sfx bus installed")
	var sfx: Node = root.get_node("SfxSynth")
	for k in ["click", "breakthrough", "rebirth", "achievement", "fail"]:
		var p: Node = sfx.get("_players").get(k)
		_check((p as AudioStreamPlayer).bus == &"SFX", "sfx routes to SFX bus")
	_check(sfx.call("ui_stream", "hover") != null, "hover stream exposed")
	_check(root.get_node_or_null("/root/MaaackMusic") != null, "music controller autoloaded")
	_check(root.get_node_or_null("/root/MaaackUISound") != null, "ui-sound controller autoloaded")
	# Direction: title on request, silence on missing, idempotent repeats.
	_scene_main.call("_music_play", "title")
	_scene_main.call("_pump_music")
	_check(str(_scene_main.get("_music_track")) == "title", "title theme requested")
	_scene_main.call("_music_play", "title")
	_scene_main.call("_pump_music")
	_check(str(_scene_main.get("_music_track")) == "title", "repeat requests idle")
	_scene_main.call("_music_play", "nope-missing")
	_scene_main.call("_pump_music")
	_check(str(_scene_main.get("_music_track")) == "", "missing tracks resolve to silence")
	var mc: Node = root.get_node_or_null("/root/MaaackMusic")
	_scene_main.call("_music_play", "game")
	_scene_main.call("_pump_music")
	_check(mc != null and mc.get("music_stream_player") != null, "controller holds the game stream")
	_check((_scene_main.get("_music_cache") as Dictionary).has("game"), "streams cache by id")

func _test_settings_input() -> void:
	# Persisted settings round-trip through the vendor ConfigFile.
	PlayerConfig.set_config("CultivationNation", "sfx_volume", 0.5)
	PlayerConfig.set_config("CultivationNation", "skin", "parchment")
	_check(float(PlayerConfig.get_config("CultivationNation", "sfx_volume", 1.0)) == 0.5, "settings persist")
	_scene_main.call("_apply_settings")
	var sfx: Node = root.get_node("SfxSynth")
	_check(float(sfx.get("volume")) == 0.5, "boot applies persisted volume")
	var ui: Node = _scene_main.get_node("UI")
	_check(str(ui.call("get_skin")) == "parchment", "boot applies persisted skin")
	PlayerConfig.set_config("CultivationNation", "sfx_volume", 1.0)
	PlayerConfig.set_config("CultivationNation", "skin", "ink")
	_scene_main.call("_apply_settings")
	# Input actions registered with legacy defaults; rebinds persist.
	_check(InputMap.has_action("cult_breathe"), "breathe action registered")
	var evs: Array = InputMap.action_get_events("cult_breathe")
	_check(not evs.is_empty() and int((evs[0] as InputEventKey).physical_keycode) == KEY_1, "defaults mirror legacy keys")
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_B
	AppSettings.set_config_input_events("cult_breathe", [custom])
	var back: Array = AppSettings.get_config_input_events("cult_breathe", [])
	_check(back.size() == 1 and int((back[0] as InputEventKey).physical_keycode) == KEY_B, "rebinds persist")
	AppSettings.set_config_input_events("cult_breathe", [])
	_scene_main.call("_register_input_actions")
	# QA Round 2: a released key must stop firing, and the vendor Reset
	# button must restore our documented defaults. Both regressed once:
	# the legacy keycode fallback in _unhandled_key_input made rebinding
	# additive-only, and AppSettings.default_action_events was never seeded
	# (we register actions directly), so Reset wiped config and left the
	# live rebind in place.
	var reb := InputEventKey.new()
	reb.physical_keycode = KEY_B
	AppSettings.set_config_input_events("cult_breathe", [reb])
	_scene_main.call("_register_input_actions")
	var ge2: Node = root.get_node("GameEngine")
	ge2.set("player_focus", "")
	var stale := InputEventKey.new()
	stale.physical_keycode = KEY_1
	stale.pressed = true
	_scene_main.call("_unhandled_key_input", stale)
	_check(str(ge2.get("player_focus")) == "", "released key no longer fires (rebind replaces)")
	ge2.set("player_focus", "")
	var fresh := InputEventKey.new()
	fresh.physical_keycode = KEY_B
	fresh.pressed = true
	_scene_main.call("_unhandled_key_input", fresh)
	_check(str(ge2.get("player_focus")) == "cultivate", "rebound key fires")
	_check(int(AppSettings.default_action_events.size()) == 20, "vendor reset snapshot seeded")
	AppSettings.reset_to_default_inputs()
	var after_reset: Array = InputMap.action_get_events("cult_breathe")
	_check(after_reset.size() == 1 and int((after_reset[0] as InputEventKey).physical_keycode) == KEY_1, "vendor reset restores defaults")
	# P25 rule-11: 19 -> 20 actions. The machine proof compares (type,
	# code) pairs — mouse-button events carry keycode NONE and must not
	# false-collide with keys (world_attack defaults to RIGHT mouse).
	var seen: Dictionary = {}
	var dup: bool = false
	for action in ["cult_breathe", "cult_drill", "cult_stalk", "cult_tribulation", "cult_speed1", "cult_speed10", "cult_speed100", "cult_speed1000", "cult_pause", "cult_hunt", "cult_wander", "cult_mute", "cult_help", "world_move_forward", "world_move_back", "world_move_left", "world_move_right", "world_interact", "world_toggle_flight", "world_attack"]:
		for e in InputMap.action_get_events(str(action)):
			var tag: String = "key:" + str((e as InputEventKey).physical_keycode) if e is InputEventKey else ("mouse:" + str((e as InputEventMouseButton).button_index) if e is InputEventMouseButton else "other")
			if seen.has(tag):
				dup = true
			seen[tag] = true
	_check(not dup and seen.size() == 20, "20 actions, collision-free defaults")
	var wevs: Array = InputMap.action_get_events("cult_wander")
	_check(wevs.size() == 1 and int((wevs[0] as InputEventKey).physical_keycode) == KEY_V, "wander default is V")
	var aevs: Array = InputMap.action_get_events("world_attack")
	_check(aevs.size() == 1 and (aevs[0] is InputEventMouseButton) and int((aevs[0] as InputEventMouseButton).button_index) == MOUSE_BUTTON_RIGHT, "attack defaults to right mouse")
	AppSettings.set_config_input_events("cult_breathe", [])
	_scene_main.call("_register_input_actions")
	# Options scenes instantiate (vendor UI gated from headless tree entry).
	var pin: PackedScene = load("res://addons/maaacks_game_template/base/nodes/menus/options_menu/input/input_options_menu.tscn")
	var pvid: PackedScene = load("res://addons/maaacks_game_template/base/nodes/menus/options_menu/video/video_options_menu.tscn")
	_check(pin != null and pin.can_instantiate(), "input options instantiate")
	_check(pvid != null and pvid.can_instantiate(), "video options instantiate")
	var adv: Node = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/AdvancedLabel")
	_check(adv != null, "advanced section staged")
	# QA Round 1: settings sliders stay narrower than the panel content
	# (an edge-to-edge slider stops drawing near max — grabber crosses
	# the content boundary and the whole control goes blank).
	var vol: HSlider = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/VolumeSlider") as HSlider
	_check(vol.custom_minimum_size.x <= 340.0 and vol.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "sliders fit inside the panel")
	# P25 rule-11: the rebind list height scales with the action count
	# (Round 1 defect #5 guard: max(320, 24xN) — 480px for 20 actions).
	var mockroot := VBoxContainer.new()
	var mocklist := ScrollContainer.new()
	mocklist.name = "InputActionsList"
	mockroot.add_child(mocklist)
	_scene_main.call("_give_list_height", mockroot)
	_check((mocklist as ScrollContainer).custom_minimum_size == Vector2(0, 480), "rebind list claims N-scaled height")
	mockroot.queue_free()

func _test_coach_veil_skin() -> void:
	var ge: Node = root.get_node("GameEngine")
	ge.set("coach_done", false)
	ge.set("realm_index", 0)
	ge.set("techniques", {})
	ge.set("qi", 0.0)
	_scene_main.call("_refresh_coach")
	var panel: PanelContainer = _scene_main.get_node("UI/Root/CoachPanel") as PanelContainer
	_check(bool(panel.visible), "coach shows for fresh exiles")
	var s0: Label = _scene_main.get_node("UI/Root/CoachPanel/CoachBox/CoachStep0") as Label
	_check(s0.text.begins_with("·"), "undone steps unmarked")
	(_scene_main.get_node("UI/Root/CoachPanel/CoachBox/CoachDismissBtn") as BaseButton).emit_signal("pressed")
	_check(bool(ge.get("coach_done")), "dismiss persists")
	_check(not bool(panel.visible), "dismiss hides coach")
	# Veil shows/hides on demand.
	_scene_main.call("_show_veil", "Proving…")
	var veil: ColorRect = _scene_main.get_node("UI/LoadingVeil") as ColorRect
	_check(bool(veil.visible), "veil shows")
	# Juice runs headless without errors.
	var jb := Button.new()
	_scene_main.add_child(jb)
	_scene_main.call("_juice_btn", jb)
	_check(is_instance_valid(jb), "press squash survives")
	jb.queue_free()
	# Ascension cues the triumph theme.
	ge.set("qi_earned_total", 4000000.0)
	_scene_main.call("_on_ascend")
	var uinode: Node = _scene_main.get_node("UI")
	for c in uinode.get_children():
		if c is ConfirmationDialog:
			c.emit_signal("confirmed")
	# The confirm queues triumph; the pump starts it (same frame split as live).
	_check(str(_scene_main.get("_music_wanted")) == "triumph", "ascension cues triumph")
	_scene_main.call("_pump_music")
	_check(str(_scene_main.get("_music_track")) == "triumph", "pump starts triumph")
	# Skins: both build, differ on the card, share the voice.
	var TH: GDScript = load("res://scripts/UITheme.gd")
	var ink: Theme = TH.build("ink")
	var par: Theme = TH.build("parchment")
	_check(ink.default_font != null and par.default_font != null and ink.default_font_size == par.default_font_size, "skins share the voice")
	var inksb: StyleBoxFlat = ink.get_stylebox("panel", "PanelContainer")
	var parsb: StyleBoxFlat = par.get_stylebox("panel", "PanelContainer")
	_check(inksb.bg_color != parsb.bg_color, "skins differ on the card")
	_check(TH.build("nope").default_font_size == 16, "unknown skins fall back")
	var ui: Node = _scene_main.get_node("UI")
	ui.call("set_skin", "parchment")
	_check(str(ui.call("get_skin")) == "parchment", "skin switches live")
	ui.call("set_skin", "ink")
	# QA Round 1: the coach dismiss path saves to the live slot and the
	# settings path writes player_config.cfg — both must be wiped so later
	# suites boot pristine (a leftover save holds the sim at title and
	# starves bots). This exact contamination timed p10 out.
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_check(not FileAccess.file_exists("user://cultivation_nation_save.json"), "suite leaves no save behind")
