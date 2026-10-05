extends SceneTree
## P22 guardians — macro-tier warden gates + deterministic duels (ADR-001).
## Run with: --headless -s res://tests/guardians_test.gd (exit 0 = pass).
## Duel entities are disjoint from the beast codex; victories persist
## rebirth AND ascend. No RNG anywhere in this suite.

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

func _load_json(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	ge.call("set_realm_table", _load_json("res://data/realms.json"))
	ge.call("set_guardian_defs", _load_json("res://data/guardians.json"))
	return ge

func _trib_need(ge: Node) -> float:
	return float(ge.call("trib_power_for", int(ge.get("realm_index"))))

func _initialize() -> void:
	print("GUARDIANS-TEST start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_test_roster()
	_test_gates()
	_test_duel_win()
	_test_duel_defeat()
	_test_persistence()
	_test_save_shapes()
	_test_unwired()
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 1:
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 5:
		_test_scene_roster()
		if _failures == 0:
			print("GUARDIANS-TEST PASS")
		else:
			printerr("GUARDIANS-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("GUARDIANS-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_scene_roster() -> void:
	## Live-scene proof: the Beasts tab stages the warden roster with a
	## challenge button on the active gate.
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 7)
	_scene_main.call("_refresh_all")
	_scene_main.call("_rebuild_guardians")
	var label: Label = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/GuardianLabel") as Label
	_check(label != null and "0 of 7 fallen" in label.text, "roster label counts the fallen")
	var box: Node = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/GuardianBox")
	_check(box.get_child_count() == 7, "seven warden rows built")
	var challenge: Button = box.get_node_or_null("Guardian_guardian_01") as Button
	_check(challenge != null and not challenge.disabled and "Challenge" in challenge.text, "active gate offers a challenge")
	var sleeper: Button = box.get_node_or_null("Guardian_guardian_07") as Button
	_check(sleeper != null and sleeper.disabled, "deep wardens sleep until reached")
	# Winning through the UI handler clears the gate and refreshes rows.
	# (Base power 10 needs a trained art first — same readiness rule as
	# the crossing itself.)
	ge.set("qi", 1.0e12)
	ge.set("techniques", {"tech_emberstep": 6000000})
	ge.set("focus_technique", "tech_emberstep")
	_scene_main.call("_on_guardian", "guardian_01")
	_check(bool(ge.call("guardian_defeated", "guardian_01")), "UI challenge defeats the warden")
	var fallen_row: Button = box.get_node_or_null("Guardian_guardian_01") as Button
	_check(fallen_row != null and fallen_row.disabled and "fallen" in fallen_row.text, "fallen row retires")

func _test_roster() -> void:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	_check(bool(cdb.call("load_all")), "content loads with guardians table")
	var defs: Array = cdb.get("guardians")
	_check(defs.size() == 7, "seven wardens, one per macro tier")
	var tiers: Array = []
	var ends: Array = [7, 15, 23, 31, 39, 47, 49]
	for i in defs.size():
		var g: Dictionary = defs[i]
		_check(str(g.get("id", "")) == "guardian_%02d" % (i + 1), "warden ids ordered guardian_01..07")
		tiers.append(int(g.get("tier", 0)))
		_check(int(g.get("guard_realm", -1)) == int(ends[i]), "warden guards its tier end")
		_check(float(g.get("power", 0.0)) > 0.0, "warden power positive")
		_check(int(g.get("waves", 0)) == 3 + int(g.get("tier", 0)), "waves mirror 3+tier")
		_check(str(g.get("name", "")) != "", "warden named")
	_check(tiers == [1, 2, 3, 4, 5, 6, 7], "tiers ascend 1..7")
	var beasts: Array = cdb.get("beasts")
	var bset: Dictionary = {}
	for b in beasts:
		bset[str((b as Dictionary).get("id", ""))] = true
	var collision: bool = false
	for g in defs:
		if bset.has(str((g as Dictionary).get("id", ""))):
			collision = true
	_check(not collision, "no warden id reuses a beast id")
	var ge: Node = _new_engine()
	_check((ge.call("guardian_ids_in_order") as Array).size() == 7, "engine roster holds seven")
	_check((ge.call("guardian_roster") as Array).size() == 7, "UI roster holds seven")
	ge.queue_free()
	cdb.free()

func _test_gates() -> void:
	var ge: Node = _new_engine()
	ge.set("realm_index", 0)
	_check((ge.call("guardian_gate") as Dictionary).is_empty(), "no gate inside tier 1")
	ge.set("realm_index", 6)
	_check((ge.call("guardian_gate") as Dictionary).is_empty(), "no gate before tier end")
	ge.set("realm_index", 7)
	var gate: Dictionary = ge.call("guardian_gate")
	_check(bool(gate.get("blocked", false)) and str(gate.get("id", "")) == "guardian_01", "tier-1 end warded by guardian_01")
	ge.set("realm_index", 8)
	_check((ge.call("guardian_gate") as Dictionary).is_empty(), "gate clears past the crossing")
	ge.set("realm_index", 15)
	_check(str((ge.call("guardian_gate") as Dictionary).get("id", "")) == "guardian_02", "tier-2 end warded by guardian_02")
	ge.set("realm_index", 49)
	_check(str((ge.call("guardian_gate") as Dictionary).get("id", "")) == "guardian_07", "final crossing warded by guardian_07")
	# A warded breakthrough refuses cost-free with the Warded mark.
	ge.set("realm_index", 7)
	ge.set("qi", 1.0e12)
	var r0: int = int(ge.get("realm_index"))
	var ok: bool = bool(ge.call("attempt_breakthrough", 10.0, _trib_need(ge), 1.0))
	_check(not ok and int(ge.get("realm_index")) == r0, "warded crossing refused")
	_check(str(ge.get("last_quality")) == "Warded", "refusal marked Warded")
	ge.queue_free()

func _test_duel_win() -> void:
	var ge: Node = _new_engine()
	ge.set("realm_index", 7)
	var q0: float = ge.call("qi_num")
	var res: Dictionary = ge.call("attempt_guardian", 1.0e9, 1.0)
	_check(bool(res.get("win", false)), "overwhelming power wins the duel")
	_check(str(res.get("quality", "")) == "Radiant", "overwhelming win is Radiant")
	_check((ge.get("guardians") as Dictionary).get("defeated", []).has("guardian_01"), "victory recorded")
	_check(int((ge.get("guardians") as Dictionary).get("attempts", {}).get("guardian_01", 0)) == 1, "attempt counted")
	_check(float(res.get("reward", 0.0)) > 0.0, "first win pays a reward")
	_check(ge.call("qi_num") > q0, "reward qi lands in the pool")
	# The crossing now proceeds: gate cleared, duel reports no guardian.
	_check((ge.call("guardian_gate") as Dictionary).is_empty(), "gate clears after victory")
	var again: Dictionary = ge.call("attempt_guardian", 1.0e9, 1.0)
	_check(not bool(again.get("win", false)) and str(again.get("reason", "")) == "no_guardian", "no rematch against the fallen")
	ge.queue_free()

func _test_duel_defeat() -> void:
	var ge: Node = _new_engine()
	ge.set("realm_index", 7)
	ge.set("qi", 1.0e9)
	var q0: float = ge.call("qi_num")
	var res: Dictionary = ge.call("attempt_guardian", 1.0, 1.0)
	_check(not bool(res.get("win", false)), "feeble power loses the duel")
	_check(str(res.get("quality", "")) == "Defeat", "loss marked Defeat")
	_check(not ((ge.get("guardians") as Dictionary).get("defeated", []) as Array).has("guardian_01"), "defeat records nothing fallen")
	_check(ge.call("qi_num") < q0, "defeat costs qi proportionally")
	# A nearer miss pays less than a hopeless one (duel defense and warden
	# power share the tribulation scale: guardian_01 power is 40).
	var ga: Node = _new_engine()
	ga.set("realm_index", 7)
	ga.set("qi", 1.0e9)
	ga.call("attempt_guardian", 8.0, 1.0)
	var gb: Node = _new_engine()
	gb.set("realm_index", 7)
	gb.set("qi", 1.0e9)
	gb.call("attempt_guardian", 0.8, 1.0)
	_check(ga.call("qi_num") > gb.call("qi_num"), "near miss keeps more than rout")
	ge.queue_free()
	ga.queue_free()
	gb.queue_free()

func _test_persistence() -> void:
	var ge: Node = _new_engine()
	ge.set("realm_index", 7)
	ge.call("attempt_guardian", 1.0e9, 1.0)
	_check(bool(ge.call("guardian_defeated", "guardian_01")), "warden fallen before rebirth")
	ge.call("rebirth")
	_check(bool(ge.call("guardian_defeated", "guardian_01")), "victory survives rebirth")
	ge.set("qi_earned_total", 4000000.0)
	_check(int(ge.call("ascend")) > 0, "ascension pays out")
	_check(bool(ge.call("guardian_defeated", "guardian_01")), "victory survives ascension")
	_check(int(ge.get("realm_index")) == 0, "ascension still resets the ladder")
	ge.queue_free()

func _test_save_shapes() -> void:
	var ge: Node = _new_engine()
	ge.set("realm_index", 7)
	ge.call("attempt_guardian", 1.0e9, 1.0)
	var st: Dictionary = ge.call("get_state")
	_check((st.get("guardians", {}) as Dictionary).get("defeated", []).has("guardian_01"), "state carries victories")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(bool(ge2.call("guardian_defeated", "guardian_01")), "victory survives save roundtrip")
	var ge3: Node = _new_engine()
	ge3.call("apply_state", {})
	_check(((ge3.get("guardians") as Dictionary).get("defeated", ["x"]) as Array).is_empty(), "missing guardians default empty")
	var ge4: Node = _new_engine()
	ge4.call("apply_state", {"guardians": {"defeated": "oops", "attempts": [1, 2]}})
	_check(((ge4.get("guardians") as Dictionary).get("defeated", ["x"]) as Array).is_empty(), "malformed victories reset safely")
	ge.queue_free()
	ge2.queue_free()
	ge3.queue_free()
	ge4.queue_free()

func _test_unwired() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var bare: Node = GE.new()
	root.add_child(bare)
	_check((bare.call("guardian_gate") as Dictionary).is_empty(), "unwired engine wards nothing")
	var res: Dictionary = bare.call("attempt_guardian", 10.0, 1.0)
	_check(not bool(res.get("win", false)) and str(res.get("reason", "")) == "no_guardian", "unwired duel declines")
	bare.queue_free()
