extends SceneTree
## P24 presence test (P24a scope: input N, movement, gating, avatar
## idle/walk, budgets, facade drift; presence/flight/unlock land in P24b).
## Run with: --headless -s res://tests/p24_presence_test.gd (exit 0 = pass).

var _failures: int = 0
var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _world() -> Node:
	return _scene_main.get_node("WorldViewport/World")

func _initialize() -> void:
	print("P24-TEST start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		# Viewport pinning per hazard 2.3.3 (headless dummy is square).
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 5:
		_test_input_contract()
		_test_avatar()
		_test_gating()
		_test_budgets()
		_test_presence_matrix()
		_test_flight_gate()
		_test_meditate()
		_test_gate_blocking()
		_test_node_marks()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 5:
		_test_follow()
		if _failures == 0:
			print("P24-TEST PASS")
		else:
			printerr("P24-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P24-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_input_contract() -> void:
	# P24 rule-11: 13 -> 19 intentional extension. Wander moved W -> V so
	# WASD movement is unambiguous; rebind-replacement semantics preserved.
	for a in ["cult_breathe", "cult_drill", "cult_stalk", "cult_tribulation", "cult_speed1", "cult_speed10", "cult_speed100", "cult_speed1000", "cult_pause", "cult_hunt", "cult_wander", "cult_mute", "cult_help", "world_move_forward", "world_move_back", "world_move_left", "world_move_right", "world_interact", "world_toggle_flight"]:
		_check(InputMap.has_action(str(a)), "action registered: " + str(a))
	_check(InputMap.action_get_events("world_move_forward").size() == 1, "move defaults present")
	var wcodes: Array = []
	for a in ["world_move_forward", "world_move_back", "world_move_left", "world_move_right", "world_interact", "world_toggle_flight"]:
		for e in InputMap.action_get_events(str(a)):
			wcodes.append(int((e as InputEventKey).physical_keycode))
	_check(wcodes == [KEY_W, KEY_S, KEY_A, KEY_D, KEY_E, KEY_F], "world defaults are WASD/E/F")

func _test_avatar() -> void:
	var w: Node = _world()
	_check(str(w.call("avatar_state")) == "idle", "avatar rests idle")
	var p0: Vector3 = (w.get_node("Cultivator") as Node3D).position
	w.call("avatar_move", Vector2(1, 0), 1.0)
	var p1: Vector3 = (w.get_node("Cultivator") as Node3D).position
	_check(str(w.call("avatar_state")) == "walk", "movement walks")
	_check(absf(p1.x - p0.x - 8.0) < 0.01 and absf(p1.z - p0.z) < 0.01, "walk covers speed x time")
	w.call("avatar_move", Vector2.ZERO, 1.0)
	_check(str(w.call("avatar_state")) == "idle", "rest returns to idle")
	# Island clamp: a marathon in one direction stops at 90% radius.
	for i in 200:
		w.call("avatar_move", Vector2(1, 0), 1.0)
	var p2: Vector3 = (w.get_node("Cultivator") as Node3D).position
	_check(absf(Vector2(p2.x - 1200.0, p2.z).length() - 180.0) < 1.0, "avatar clamped to island")

func _test_follow() -> void:
	# Follow camera tracks the avatar (C1 return space: floaters follow).
	# Checked a frame after the moves so the per-frame follow has run.
	var w: Node = _world()
	var p2: Vector3 = (w.get_node("Cultivator") as Node3D).position
	_check((w.get("_focus_target") as Vector3).distance_to(p2 + Vector3(0, 4, 0)) < 1.0, "follow camera tracks avatar")

func _test_gating() -> void:
	var w: Node = _world()
	_check(not bool(w.call("_ui_open")), "orbit input live with panels closed")
	(_scene_main.get_node("UI/Root/SidePanel") as Control).visible = true
	_check(bool(w.call("_ui_open")), "panels open suspends world input")
	(_scene_main.get_node("UI/Root/SidePanel") as Control).visible = false
	_check(not bool(w.call("_ui_open")), "closing panels resumes")

func _test_budgets() -> void:
	var w: Node = _world()
	_check(int(w.call("count_nodes")) <= 160, "world node budget holds with avatar")
	var b: Dictionary = w.call("particle_budget")
	_check(int(b.get("total", 9999)) <= 768, "total budget holds with avatar")

func _test_presence_matrix() -> void:
	# P24b: default OFF identical; ON exact x1.5; offline ignores; all four
	# resets land (apply_state is the sneaky one: load-during-presence).
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	_check(not bool(ge.call("is_presence_active")), "presence defaults off")
	ge.set("qi_per_tick", 10.0)
	ge.call("_recompute_rate")
	var off: float = ge.call("rate_num")
	ge.call("set_presence", true)
	_check(bool(ge.call("is_presence_active")), "presence engages")
	_check(absf(ge.call("rate_num") - off * 1.5) < 0.0001, "presence pays exact x1.5")
	ge.call("set_presence", true)
	_check(absf(ge.call("rate_num") - off * 1.5) < 0.0001, "re-engage idempotent")
	ge.call("set_presence", false)
	_check(absf(ge.call("rate_num") - off) < 0.0001, "release restores the rate")
	ge.call("set_presence", true)
	ge.call("apply_state", ge.call("get_state"))
	_check(not bool(ge.call("is_presence_active")), "load never resumes meditating")
	ge.call("set_presence", true)
	ge.call("rebirth")
	_check(not bool(ge.call("is_presence_active")), "rebirth lands the avatar")
	ge.set("qi_earned_total", 4000000.0)
	ge.call("set_presence", true)
	_check(int(ge.call("ascend")) > 0, "ascension pays out")
	_check(not bool(ge.call("is_presence_active")), "ascension lands the avatar")
	# Offline path ignores presence entirely: the real flow loads first
	# (apply_state resets presence), so away-ticks never see the premium.
	ge.call("set_presence", true)
	ge.call("apply_state", ge.call("get_state"))
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	var rep: Dictionary = sm.call("apply_offline", 0, 3600)
	_check(not bool(ge.call("is_presence_active")), "load clears presence before offline")
	_check(int(rep.get("months", 0)) > 0, "offline still resolves gains")
	ge.queue_free()
	sm.queue_free()

func _test_flight_gate() -> void:
	# P24b: flight unlock is data-driven (flight.json, Nascent Soul entry);
	# pre-unlock toggle refuses warded-style, post-unlock it flies.
	var ge: Node = root.get_node("GameEngine")
	_check(not bool(ge.call("flight_unlocked")), "flight locked at realm 0")
	_check(str(ge.call("flight_unlock_line")) != "", "unlock names the way")
	_scene_main.call("_on_flight")
	_check(str(_world().call("avatar_state")) != "fly", "pre-unlock toggle refused")
	ge.set("realm_index", 24)
	_check(bool(ge.call("flight_unlocked")), "flight opens at Nascent Soul")
	_scene_main.call("_on_flight")
	_check(str(_world().call("avatar_state")) == "fly", "post-unlock toggle flies")
	_scene_main.call("_on_flight")
	_check(str(_world().call("avatar_state")) != "fly", "toggle lands again")

func _test_meditate() -> void:
	# P24b: interact at a node marker meditates (presence on); any stride
	# breaks it (presence off). States are headless-drives.
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.call("generate_map", 4242)
	w.call("_poll_engine")
	var marks: Node = w.get_node_or_null("NodeMarks")
	_check(marks != null and marks.get_child_count() > 0, "node markers staged")
	var first: Node3D = marks.get_child(0) as Node3D
	(w.get_node("Cultivator") as Node3D).position = first.position
	w.call("_try_meditate")
	_check(str(w.call("avatar_state")) == "meditate", "interact at node meditates")
	_check(bool(ge.call("is_presence_active")), "meditation engages presence")
	w.call("avatar_move", Vector2(1, 0), 1.0)
	_check(str(w.call("avatar_state")) == "walk", "stride breaks meditation")
	_check(not bool(ge.call("is_presence_active")), "breaking releases presence")

func _test_gate_blocking() -> void:
	# P24b: avatar-side walls read engine zone rules (R13: no duplicate
	# logic). Dewfield admits everyone; Thornwake wants realm 40.
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 0)
	w.call("apply_zone", "Dewfield")
	_check(str(w.call("avatar_lock_reason")) == "", "home grounds walkable")
	w.call("apply_zone", "Thornwake")
	var reason: String = str(w.call("avatar_lock_reason"))
	_check(reason != "" and "40" in reason, "locked grounds name their price")
	var p0: Vector3 = (w.get_node("Cultivator") as Node3D).position
	w.call("_poll_avatar", 0.25)
	_check((w.get_node("Cultivator") as Node3D).position == p0, "locked grounds refuse strides")
	w.call("apply_zone", "Dewfield")

func _test_node_marks() -> void:
	# Markers are deterministic: same seed, same positions, every session.
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.call("generate_map", 4242)
	w.call("_poll_engine")
	var marks: Node = w.get_node_or_null("NodeMarks")
	var a: Array = []
	for m in marks.get_children():
		a.append((m as Node3D).position)
	ge.call("generate_map", 999001)
	w.call("_poll_engine")
	ge.call("generate_map", 4242)
	w.call("_poll_engine")
	var marks2: Node = w.get_node_or_null("NodeMarks")
	var b: Array = []
	for m in marks2.get_children():
		b.append((m as Node3D).position)
	_check(a.size() == b.size() and a.size() > 0, "markers staged on return")
	var same: bool = true
	for i in a.size():
		if (a[i] as Vector3).distance_to(b[i] as Vector3) > 0.01:
			same = false
	_check(same, "markers deterministic across regens")
