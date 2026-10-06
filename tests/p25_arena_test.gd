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
		_test_invariance()
		_test_loss()
		_test_tempo_clamp()
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

func _fight_at(w: Node, zone: String, beast_id: String = "") -> String:
	## Walk to a zone, stand on the chosen den (first marker by default),
	## interact, and open the skirmish. Rich coffers: repeat visits toll.
	## Returns the challenged beast id ("" when refused).
	_walk_to(w, zone)
	var ge: Node = root.get_node("GameEngine")
	ge.set("qi", 1.0e12)
	var row: Node = w.get_node("BeastGrounds")
	var target: Node3D = null
	for m in row.get_children():
		if beast_id == "" or str(m.get_meta("beast_id", "")) == beast_id:
			target = m as Node3D
			break
	_check(target != null, "den staged for " + zone)
	_stand_on(w, target.global_position)
	Input.action_press("world_interact")
	w.call("_poll_avatar", 0.25)
	Input.action_release("world_interact")
	w.call("take_den_outcome")
	var bid: String = str(w.call("avatar_challenge"))
	if bid == "":
		return ""
	var res: Dictionary = w.call("avatar_fight", bid)
	if not bool(res.get("ok", false)):
		return ""
	return bid

func _run_trace(w: Node, gaps: Array) -> Dictionary:
	## Scripted input trace: strikes spaced by gap milliseconds.
	## Deterministic by construction (synthetic timestamps). Returns the
	## resolution result (win or loss), not the post-resolution tail.
	var t: int = 1000000
	var outcome: Dictionary = {}
	for g in gaps:
		t += int(g)
		var r: Dictionary = w.call("avatar_strike", t)
		if r.has("win"):
			outcome = r
	if outcome.is_empty():
		outcome = w.call("avatar_strike", t + 100000)
	return outcome

func _test_invariance() -> void:
	# P25b: same stats + same trace shape -> identical verdict and
	# post-state; tempo shapes duration and the Q35 bonus ONLY. Fresh arts
	# keep the fight multi-tick (one-shot fights can't separate tempos);
	# qi is snapshotted AFTER setup so travel tolls can't confound it.
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 0)
	ge.set("techniques", {})
	ge.set("focus_technique", "tech_stillwater")
	var results: Array = []
	for gaps in [
		[400, 400, 400, 400, 400, 400, 400, 400],
		[800, 800, 800, 800, 800, 800, 800, 800],
		[2000, 2000, 400, 400, 400, 400, 400, 400],
	]:
		_fight_at(w, "Dewfield", "beast_reedlurker")
		var q0: float = ge.call("qi_num")
		var k0: int = int((ge.get("beasts") as Dictionary).get("beast_reedlurker", 0))
		var x0: int = int((ge.get("techniques") as Dictionary).get("tech_stillwater", 0))
		var last: Dictionary = _run_trace(w, gaps)
		w.call("take_fight_outcome")
		results.append({
			"win": bool(last.get("win", false)),
			"dkills": int((ge.get("beasts") as Dictionary).get("beast_reedlurker", 0)) - k0,
			"dxp": int((ge.get("techniques") as Dictionary).get("tech_stillwater", 0)) - x0,
			"dqi": ge.call("qi_num") - q0,
		})
	_check(bool(results[0].get("win", false)) and bool(results[1].get("win", false)) and bool(results[2].get("win", false)), "all tempo profiles win the parity fight")
	_check(int(results[0].get("dkills", -1)) == int(results[1].get("dkills", -2)) and int(results[1].get("dkills", -2)) == int(results[2].get("dkills", -3)) and int(results[0].get("dkills", 0)) >= 1, "identical kill rewards across profiles")
	_check(absf(float(results[0].get("dqi", 0.0))) < 0.001 and absf(float(results[1].get("dqi", 0.0))) < 0.001 and absf(float(results[2].get("dqi", 0.0))) < 0.001, "fights mint no qi in any profile")
	_check(int(results[0].get("dxp", 0)) == 100, "max tempo earns the bonus")
	_check(int(results[1].get("dxp", 0)) == 0 and int(results[2].get("dxp", 0)) == 0, "sloppy tempo earns no bonus")

func _test_loss() -> void:
	# Below-beast stats lose under EVERY profile; knockback to the zone
	# entrance, no qi cost, no spiral. slagwing at fresh power sits in
	# the losable band (ratio ~0.45: accepted, doomed).
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 8)
	ge.set("techniques", {})
	ge.set("focus_technique", "")
	var slow24: Array = []
	for i in 24:
		slow24.append(400)
	var slowish: Array = []
	for i in 24:
		slowish.append(2000)
	for gaps in [slow24, slowish]:
		var q0: float = ge.call("qi_num")
		var bid: String = _fight_at(w, "Ashbarrow", "beast_slagwing")
		_check(bid == "beast_slagwing", "underdog challenge stages")
		var last: Dictionary = _run_trace(w, gaps)
		_check(not bool(last.get("win", true)), "underdog loses at any tempo")
		_check(absf(ge.call("qi_num") - q0) < 0.001, "loss costs no qi")
		w.call("take_fight_outcome")
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	var spawn := Vector3.ZERO
	for z in (cdb.get("zones3d") as Array):
		if str((z as Dictionary).get("id", "")) == "Ashbarrow":
			var pos: Array = ((z as Dictionary).get("spawn", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0])
			spawn = Vector3(float(pos[0]), 0.0, float(pos[2]))
	cdb.free()
	var ap: Vector3 = (w.get_node("Cultivator") as Node3D).position
	_check(Vector2(ap.x - spawn.x, ap.z - spawn.z).length() < 5.0, "knockback returns to the zone mouth")

func _test_tempo_clamp() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 0)
	_fight_at(w, "Dewfield")
	var r1: Dictionary = w.call("avatar_strike", 1000000)
	_check(bool(r1.get("ok", false)), "first strike lands")
	var r2: Dictionary = w.call("avatar_strike", 1000100)
	_check(not bool(r2.get("ok", true)) and str(r2.get("reason", "")) == "tempo", "mash inside the clamp rejected")
	w.call("avatar_strike", 1001000)
	w.call("avatar_strike", 1002000)
	w.call("take_fight_outcome")
