extends SceneTree
## P9 tier-2 test: curve parity, Murkfen zone, new unlocks, live denominator.
## Run: --headless -s res://tests/p9_test.gd (exit 0 = pass).

var _failures: int = 0
var _stage: int = 0
var _frames: int = 0
var _scene_main: Node = null

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _initialize() -> void:
	print("P9-TEST start")
	_test_curve()
	_test_murkfen()
	_test_unlocks()
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 2:
		_test_denominator()
		_stage = 2
	elif _stage == 2:
		_finish()
	elif _frames > 3600:
		printerr("P9-TEST FAIL: frame timeout")
		quit(1)
	return false

func _finish() -> void:
	if _failures == 0:
		print("P9-TEST PASS")
	else:
		printerr("P9-TEST FAIL count=", _failures)
	quit(_failures)

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	return ge

func _data(name: String) -> Array:
	var f: FileAccess = FileAccess.open("res://data/" + name, FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _test_curve() -> void:
	var realms: Array = _data("realms.json")
	_check(realms.size() == 50, "50 realms total")
	var tiers: Dictionary = {}
	for r in realms:
		var t: int = int(r.get("macro_tier", 0))
		tiers[t] = int(tiers.get(t, 0)) + 1
	_check(int(tiers.get(1, 0)) == 8 and int(tiers.get(2, 0)) == 8 and int(tiers.get(3, 0)) == 8 and int(tiers.get(4, 0)) == 8 and int(tiers.get(5, 0)) == 8 and int(tiers.get(6, 0)) == 8 and int(tiers.get(7, 0)) == 2, "8/realm tiers 1-6 + 2 true-immortal")
	# Tolerance, not exactness: Godot's JSON parser rounds 3 of the 50 large
	# entries by 1 ulp (proven by probe 2026-10-04). 1e-9 relative sits 7
	# orders above parser noise and far below any genuine curve change.
	# P18: front-loaded curve — 120x4^i times 10x@realm1 decaying to 1x by
	# realm 9, pure 4x past that (mirrors front_load() in gen_realms.py).
	var parity: bool = true
	var want: float = 120.0
	for i in range(realms.size()):
		var mult: float = 1.0
		if i < 8:
			mult = 1.0 + 9.0 * float(8 - i) / 8.0
		var got: float = float(realms[i].get("qi_required", 0.0))
		if absf(got - want * mult) > 1e-9 * want * mult:
			parity = false
		want *= 4.0
	_check(parity, "curve parity front-loaded 120x4^i across all 50")
	var lives: Array = [110, 250, 650, 1500, 4000, 10000, 1000000000]
	var waves: Array = [0, 3, 6, 9, 12, 18, 24]
	var meta_ok: bool = true
	for i in range(realms.size()):
		var t: int = int(realms[i].get("macro_tier", 0))
		if t < 1 or t > 7:
			meta_ok = false
		if int(realms[i].get("lifespan", 0)) != int(lives[t - 1]):
			meta_ok = false
		if int(realms[i].get("waves", -1)) != int(waves[t - 1]):
			meta_ok = false
		if float(realms[i].get("trib_power", 0.0)) != 5.0 + 5.0 * float(i):
			meta_ok = false
	_check(meta_ok, "lifespan/waves/trib_power follow tier table")

func _test_murkfen() -> void:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	_check(bool(cdb.call("load_all")), "content loads with tier-2")
	var murk: int = 0
	for b in (cdb.get("beasts") as Array):
		if str((b as Dictionary).get("zone", "")) == "Murkfen":
			murk += 1
	_check(murk == 4, "4 murkfen beasts")
	var ge: Node = _new_engine()
	ge.call("set_beast_pool", cdb.get("beasts"))
	ge.call("generate_map", 4242)
	_check((ge.get("map_nodes") as Array).size() == 36, "9 zones x 4 nodes")
	_check(int(ge.call("zone_gate", "beast_siltmaw")) == 6, "murkfen gate 6")
	ge.set("realm_index", 5)
	var mnode: String = ""
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) == "Murkfen":
			mnode = str((n as Dictionary).get("id", ""))
			break
	_check(mnode != "", "murkfen node generated")
	_check(not bool(ge.call("travel_to", mnode)), "murkfen refused at realm 5")
	ge.set("realm_index", 6)
	_check(bool(ge.call("travel_to", mnode)), "murkfen opens at realm 6")
	cdb.free()
	ge.queue_free()

func _test_unlocks() -> void:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	var ge: Node = _new_engine()
	ge.call("set_achievement_rules", cdb.get("achievements"))
	ge.set("realm_index", 13)
	ge.set("qi", 500.0)
	ge.set("qi_bottleneck", 120.0)
	ge.call("attempt_breakthrough", 999.0, 1.0)
	_check((ge.get("achievements") as Array).has("ach_realm_14"), "realm 14 unlocks Farther Shore")
	(ge.get("gear") as Dictionary)["x"] = 5
	(ge.get("gear") as Dictionary)["y"] = 5
	(ge.get("gear") as Dictionary)["z"] = 5
	ge.call("_poll_achievements")
	_check((ge.get("achievements") as Array).has("ach_gear_15"), "15 gear levels unlock Workbench")
	ge.call("train_technique", "tech_mistwalk", 2500)
	_check((ge.get("achievements") as Array).has("ach_tech_5"), "level 5 unlocks Living Form")
	var pool: Array = (cdb.get("beasts") as Array).duplicate()
	var order: Array = []
	for b in pool:
		order.append(str((b as Dictionary).get("id", "")))
	ge.call("set_hunt_order", order)
	for i in range(3):
		ge.call("hunt_tick", str(order[i]), 20000)
	_check((ge.get("achievements") as Array).has("ach_apex_3"), "3 apex unlock Triple Apex")
	cdb.free()
	ge.queue_free()

func _test_denominator() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var ui: Node = _scene_main.get_node("UI")
	ui.call("refresh")
	var text: String = str(ui.get_node("Root/SidePanel/PanelScroll/PanelTabs/Deeds/AchieveHeader").text)
	_check("0/43" in text, "live denominator follows 43 achievements")
