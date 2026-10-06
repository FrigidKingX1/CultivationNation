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
