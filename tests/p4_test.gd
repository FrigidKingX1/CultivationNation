extends SceneTree
## P4 expansion test: gear, seeded map, sect/disciples, lifecycle. Original code.
## Run: --headless -s res://tests/p4_test.gd (exit 0 = pass).

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _initialize() -> void:
	print("P4-TEST start")
	_test_gear()
	_test_map()
	_test_sect()
	_test_lifecycle()
	_test_contentdb()
	if _failures == 0:
		print("P4-TEST PASS")
	else:
		printerr("P4-TEST FAIL count=", _failures)
	quit(_failures)

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	return ge

func _pool() -> Array:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	var pool: Array = (cdb.get("beasts") as Array).duplicate()
	cdb.free()
	return pool

func _order(pool: Array) -> Array:
	var ids: Array = []
	for b in pool:
		ids.append(str((b as Dictionary).get("id", "")))
	return ids

func _test_gear() -> void:
	var ge: Node = _new_engine()
	var defs: Dictionary = {"gear_riverband": {"base_mult": 0.05}, "gear_starcompass": {"base_mult": 0.12}}
	_check(float(ge.call("refine_cost", 0)) == 100.0, "refine cost L0 = 100")
	_check(float(ge.call("refine_cost", 1)) == 400.0, "refine cost L1 = 400")
	ge.set("qi", 50.0)
	_check(not bool(ge.call("refine_gear", "gear_riverband", 5)), "refine refused when Qi short")
	ge.set("qi", 1000.0)
	_check(bool(ge.call("refine_gear", "gear_riverband", 5)), "refine ok")
	_check(int((ge.get("gear") as Dictionary).get("gear_riverband", 0)) == 1, "gear level 1")
	_check(float(ge.call("gear_bonus_for", ge.get("gear"), defs)) == 1.05, "bonus 1.05 single item")
	ge.set("qi", 100000.0)
	for i in range(4):
		ge.call("refine_gear", "gear_riverband", 5)
	# P15-Step2: max_level is a perfected threshold, not a ceiling (funds
	# still gate: 102,400 > 66,000 left, so this one is refused short).
	_check(not bool(ge.call("refine_gear", "gear_riverband", 5)), "radiant overflow refused when Qi short")
	ge.call("refine_gear", "gear_starcompass", 2)
	var m: float = float(ge.call("gear_bonus_for", ge.get("gear"), defs))
	_check(absf(m - (1.25 * 1.12)) < 0.0001, "bonus product across items")
	ge.call("set_gear_mult", m)
	var cached: float = ge.call("rate_num")
	# P12-2: fresh mind Serene 1.25x, Spring 1.1x join the compiled product.
	_check(absf(cached - 1.0 * 1.0 * 1.0 * 1.3 * m * 1.25 * 1.1) < 0.0001, "gear in compiled rate")
	# P15-Step2: funded overflow past max records radiant levels.
	ge.set("qi", 10000000.0)
	_check(bool(ge.call("refine_gear", "gear_starcompass", 2)), "radiant overflow funded")
	_check(bool(ge.call("refine_gear", "gear_starcompass", 2)), "radiant overflow past max")
	_check(int((ge.get("gear") as Dictionary).get("gear_starcompass", 0)) == 3, "overflow level recorded")
	ge.call("rebirth")
	_check(int((ge.get("gear") as Dictionary).get("gear_riverband", 0)) == 5, "gear persists rebirth")
	ge.queue_free()

func _test_map() -> void:
	var pool: Array = _pool()
	var ge: Node = _new_engine()
	ge.call("set_beast_pool", pool)
	ge.call("generate_map", 1234)
	_check((ge.get("map_nodes") as Array).size() == 36, "36 nodes, 9 zones x 4")
	var snap: String = JSON.stringify(ge.get("map_nodes"))
	ge.call("regenerate_map")
	_check(JSON.stringify(ge.get("map_nodes")) == snap, "same seed regenerates identically")
	ge.call("generate_map", 9999)
	_check(JSON.stringify(ge.get("map_nodes")) != snap, "different seed differs")
	var first: Dictionary = (ge.get("map_nodes") as Array)[0]
	_check(bool(ge.call("travel_to", str(first.get("id", "")))), "travel to real node")
	_check(not bool(ge.call("travel_to", "nope_nowhere")), "travel to bad node fails")
	var before: int = int((ge.get("beasts") as Dictionary).get(str(first.get("beast_id", "")), 0))
	var got: int = int(ge.call("hunt_at", str(first.get("id", "")), 10))
	_check(got >= 10 and got <= 20, "yield mult 1.0-2.0 applied")
	var after: int = int((ge.get("beasts") as Dictionary).get(str(first.get("beast_id", "")), 0))
	_check(after - before == got, "hunt_at credits beast kills")
	_check(int(ge.call("hunt_at", "nope_nowhere", 10)) == 0, "hunt at bad node = 0")
	ge.queue_free()

func _test_sect() -> void:
	var ge: Node = _new_engine()
	_check(not bool(ge.call("found_sect", "   ")), "empty sect name refused")
	_check(bool(ge.call("found_sect", "Pale Lantern Society")), "found sect")
	_check(not bool(ge.call("found_sect", "Second Try")), "found-once rule")
	_check(int(ge.call("disciple_cap")) == 2, "cap 2 + realm 0")
	ge.set("qi", 50.0)
	_check(not bool(ge.call("recruit_disciple")), "recruit refused when Qi short")
	ge.set("qi", 100000.0)
	_check(bool(ge.call("recruit_disciple")), "recruit 1")
	_check(bool(ge.call("recruit_disciple")), "recruit 2")
	_check(not bool(ge.call("recruit_disciple")), "cap blocks third")
	_check(not bool(ge.call("assign_disciple", 7, "gather")), "bad index refused")
	_check(not bool(ge.call("assign_disciple", 0, "dance")), "bad task refused")
	_check(bool(ge.call("assign_disciple", 0, "gather")), "assign gather")
	_check(bool(ge.call("assign_disciple", 1, "hunt")), "assign hunt")
	ge.call("set_hunt_order", _order(_pool()))
	var q0: float = ge.call("qi_num")
	for i in range(12):
		ge.call("_step_tick")
	_check(float(ge.get("_gather_mult")) == 1.02, "one gatherer = +2%")
	_check(ge.call("qi_num") > q0, "gather output accrues")
	var kills: int = 0
	for k in (ge.get("beasts") as Dictionary):
		kills += int((ge.get("beasts") as Dictionary)[k])
	_check(kills == 12, "hunter adds 1 kill/tick")
	ge.call("assign_disciple", 1, "train")
	ge.set("focus_technique", "tech_stillwater")
	for i in range(100):
		ge.call("_step_tick")
	_check(int(ge.call("technique_level", "tech_stillwater")) == 1, "trainer xp -> level 1")
	var dcount: int = (ge.get("disciples") as Array).size()
	ge.call("rebirth")
	_check((ge.get("disciples") as Array).size() == dcount, "disciples persist rebirth")
	_check(str((ge.get("sect") as Dictionary).get("name", "")) == "Pale Lantern Society", "sect persists rebirth")
	ge.queue_free()

func _test_lifecycle() -> void:
	## Two full lives fast-forward exercising gear + map + sect together.
	var pool: Array = _pool()
	var ge: Node = _new_engine()
	ge.call("set_beast_pool", pool)
	ge.call("set_hunt_order", _order(pool))
	ge.call("generate_map", 4242)
	ge.call("set_activity_rate", 5.0)
	ge.call("choose_origin", "origin_beastkin", 1.1, 5)
	ge.call("found_sect", "Dewroot Compact")
	ge.set("qi", 50000.0)
	ge.call("refine_gear", "gear_riverband", 5)
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_gear_mult", ge.call("gear_bonus_for", ge.get("gear"), cdb.call("gear_defs")))
	cdb.free()
	var start_life: int = int(ge.get("life_number"))
	var saw_pause: bool = false
	ge.set("pause_before_death_years", 3)
	for i in range(12 * 130):
		ge.call("_step_tick")
		if ge.call("qi_num") >= ge.call("bottleneck_num"):
			ge.call("attempt_breakthrough", 99999.0, 1.0)
		if not bool(ge.get("running")):
			saw_pause = true
			ge.call("resume")
	_check(int(ge.get("life_number")) > start_life + 1, "two lives lived")
	_check(int((ge.get("gear") as Dictionary).size()) > 0, "gear carried across lives")
	_check(not (ge.get("sect") as Dictionary).is_empty(), "sect carried across lives")
	_check(saw_pause, "pause-before-death fired during lifecycle")
	# Save/load roundtrip preserves P4 fields.
	var st: Dictionary = ge.call("get_state")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(int((ge2.get("gear") as Dictionary).size()) == int((ge.get("gear") as Dictionary).size()), "gear survives save/load")
	_check(str((ge2.get("sect") as Dictionary).get("name", "")) == "Dewroot Compact", "sect survives save/load")
	_check(int(ge2.get("map_seed")) == 4242, "map seed survives save/load")
	ge.queue_free()
	ge2.queue_free()

func _test_contentdb() -> void:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	_check(bool(cdb.call("load_all")), "content loads")
	_check((cdb.get("gear") as Array).size() == 7, "7 gear items")
	_check(not (cdb.call("gear_entry", "gear_starcompass") as Dictionary).is_empty(), "gear lookup")
	_check((cdb.call("gear_defs") as Dictionary).size() == 7, "gear defs helper")
	cdb.free()
