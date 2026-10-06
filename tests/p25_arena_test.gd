extends SceneTree
## P25 arena test (P25a scope: input N, den determinism, refusals,
## challenge entry, shrine flow, budgets. The exchange loop + outcome
## invariance land in P25b).
## Run with: --headless -s res://tests/p25_arena_test.gd (exit 0 = pass).

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
	print("P25-TEST start")
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
		_test_skirmish_stats()
		_test_den_determinism()
		_test_refusal()
		_test_challenge_entry()
		_test_shrine_flow()
		_test_budgets()
		if _failures == 0:
			print("P25-TEST PASS")
		else:
			printerr("P25-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P25-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_input_contract() -> void:
	# P25 rule-11: 19 -> 20 intentional extension. Attack rides the RIGHT
	# mouse button (LEFT is the orbit-drag button); replacement semantics
	# and vendor reset cover all twenty.
	_check(InputMap.has_action("world_attack"), "attack action registered")
	var evs: Array = InputMap.action_get_events("world_attack")
	_check(evs.size() == 1 and (evs[0] is InputEventMouseButton) and int((evs[0] as InputEventMouseButton).button_index) == MOUSE_BUTTON_RIGHT, "attack defaults to right mouse")

func _test_skirmish_stats() -> void:
	# P25a: additive read-only getter. Shape + determinism now; the fight
	# loop consumes it in P25b.
	var ge: Node = root.get_node("GameEngine")
	var s1: Dictionary = ge.call("skirmish_stats", "beast_cinderfox")
	_check(bool(s1.get("ok", false)), "known beast yields stats")
	for k in ["beast_power", "cult_dmg", "beast_cadence_ticks", "player_hp", "reach", "tempo_min"]:
		_check(s1.has(k) and float(s1.get(k, 0.0)) > 0.0, "stat present and positive: " + str(k))
	var s2: Dictionary = ge.call("skirmish_stats", "beast_cinderfox")
	_check(str(s1) == str(s2), "stats deterministic per call")
	var bad: Dictionary = ge.call("skirmish_stats", "beast_nope")
	_check(not bool(bad.get("ok", true)), "unknown beast declines")

func _den_positions(w: Node) -> Array:
	var out: Array = []
	var row: Node = w.get_node_or_null("BeastGrounds")
	if row == null:
		return out
	for m in row.get_children():
		out.append((m as Node3D).global_position)
	return out

func _test_den_determinism() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.call("generate_map", 4242)
	w.call("_poll_engine")
	w.call("apply_zone", "Murkfen")
	var a: Array = _den_positions(w)
	_check(a.size() > 0, "murkfen dens staged")
	w.call("apply_zone", "Dewfield")
	w.call("apply_zone", "Murkfen")
	var b: Array = _den_positions(w)
	var same: bool = a.size() == b.size() and a.size() > 0
	for i in a.size():
		if (a[i] as Vector3).distance_to(b[i] as Vector3) > 0.01:
			same = false
	_check(same, "dens deterministic across zone visits")

func _stand_on(w: Node, target: Vector3) -> void:
	(w.get_node("Cultivator") as Node3D).global_position = target

func _walk_to(w: Node, zone: String) -> void:
	## Travel through the engine (gates honored) then pump the view, so
	## zone-change plumbing (apply + marker rebuilds) runs as live.
	## Rich coffers: repeat visits toll 5% of bottleneck, and these boots
	## carry no Qi — a poor exile walks nowhere (caught live: refused
	## travel silently skipped every check after it).
	var ge: Node = root.get_node("GameEngine")
	ge.set("qi", 1.0e12)
	ge.call("generate_map", 4242)
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) == zone:
			_check(bool(ge.call("travel_to", str((n as Dictionary).get("id", "")))), "travel reaches " + zone)
			break
	w.call("_poll_engine")

func _test_refusal() -> void:
	# Below-strength dens refuse warded-style (same hunt_yield_mult rule
	# the stalk path reads — R13, no duplicate logic).
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	# Realm 6: Murkfen grounds admit walking (min_realm 6) but its beasts
	# outmatch a fresh hunter — refusal by weakness, not by lock.
	ge.set("realm_index", 6)
	_walk_to(w, "Murkfen")
	var row: Node = w.get_node("BeastGrounds")
	_check(row.get_child_count() > 0, "murkfen den markers exist")
	_stand_on(w, (row.get_child(0) as Node3D).global_position)
	Input.action_press("world_interact")
	w.call("_poll_avatar", 0.25)
	Input.action_release("world_interact")
	var res: Dictionary = w.call("take_den_outcome")
	_check(not res.is_empty() and not bool(res.get("accepted", true)), "weak den refused")
	_check(str(w.call("avatar_challenge")) == "", "refusal stages no challenge")

func _test_challenge_entry() -> void:
	# Parity den: challenge stages the beast id. P25a entry state only —
	# the exchange loop lands in P25b (no HP resolution asserted here).
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 0)
	_walk_to(w, "Dewfield")
	var row: Node = w.get_node("BeastGrounds")
	_check(row.get_child_count() > 0, "dewfield den markers exist")
	_stand_on(w, (row.get_child(0) as Node3D).global_position)
	Input.action_press("world_interact")
	w.call("_poll_avatar", 0.25)
	Input.action_release("world_interact")
	var res: Dictionary = w.call("take_den_outcome")
	_check(not res.is_empty() and bool(res.get("accepted", false)), "parity den accepts")
	_check(str(w.call("avatar_challenge")) != "", "challenge stages its beast")

func _test_shrine_flow() -> void:
	# Shrine interact queues the tier guardian; Main's poll opens the
	# EXISTING duel flow for it (presentation/UX wiring only, rule 4).
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 6)
	_walk_to(w, "Murkfen")
	var flame: MeshInstance3D = w.get_node_or_null("Islands/Island_Murkfen/ShrineFlame") as MeshInstance3D
	_check(flame != null, "warden flame staged")
	_stand_on(w, flame.global_position)
	Input.action_press("world_interact")
	w.call("_poll_avatar", 0.25)
	Input.action_release("world_interact")
	_check(str(w.call("take_shrine_request")) == "guardian_01", "shrine queues its warden")
	_check(str(w.call("take_shrine_request")) == "", "request is one-shot")
	w.call("apply_zone", "Dewfield")

func _test_budgets() -> void:
	var w: Node = _world()
	_check(int(w.call("count_nodes")) <= 160, "world node budget holds with arena")
	var b: Dictionary = w.call("particle_budget")
	_check(int(b.get("total", 9999)) <= 768, "total budget holds with arena")
