extends SceneTree
## P3 systems test: origins/dantian, techniques, bestiary, pause. Original code.
## (Route planner cut in P13-B5; its 4 checks removed, pause checks kept.)
## Run: --headless -s res://tests/p3_test.gd (exit 0 = pass).

var _failures: int = 0
var _paused_at: Array = []

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _on_paused(age: int) -> void:
	_paused_at.append(age)

func _initialize() -> void:
	print("P3-TEST start")
	_test_origins_dantian()
	_test_techniques()
	_test_bestiary()
	_test_route_pause()
	_test_contentdb()
	if _failures == 0:
		print("P3-TEST PASS")
	else:
		printerr("P3-TEST FAIL count=", _failures)
	quit(_failures)

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	return ge

func _test_origins_dantian() -> void:
	var ge: Node = _new_engine()
	_check(bool(ge.call("choose_origin", "origin_ironhide", 0.9, 20)), "choose origin first time")
	_check(int(ge.get("lifespan_years")) == 80, "ironhide lifespan 60+20")
	_check(not bool(ge.call("choose_origin", "origin_cinder", 1.25, -5)), "origin locked mid-life")
	_check(str(ge.get("origin_id")) == "origin_ironhide", "locked origin unchanged")
	var cached: float = ge.call("rate_num")
	# P12-2: fresh mind Serene 1.25x, Spring 1.1x join the compiled product.
	_check(absf(cached - 0.9 * 1.3 * 1.25 * 1.1) < 0.0001, "compiled rate has origin+dantian (0.9 x 1.3)")
	ge.set("qi", 500.0)
	ge.set("qi_bottleneck", 120.0)
	_check(bool(ge.call("attempt_breakthrough", 99.0, 1.0)), "breakthrough ok")
	_check(float(ge.get("dantian_purity")) == 82.0, "success purity +2")
	ge.set("qi", 500.0)
	ge.set("qi_bottleneck", 120.0)
	_check(not bool(ge.call("attempt_breakthrough", 1.0, 999.0)), "weak power fails")
	# P13-B1 proportional costs: hopeless fail takes ~full -2 (tolerance).
	_check(absf(float(ge.get("dantian_purity")) - 80.0) < 0.01, "failure purity -2")
	ge.call("rebirth")
	_check(str(ge.get("origin_id")) == "origin_wayfarer", "rebirth resets origin")
	_check(bool(ge.call("choose_origin", "origin_cinder", 1.25, -5)), "new life can choose again")
	_check(int(ge.get("lifespan_years")) == 55, "cinder lifespan 60-5")
	_check(absf(float(ge.get("dantian_purity")) - 80.0) < 0.01, "purity persists across rebirth")
	ge.queue_free()

func _test_techniques() -> void:
	var ge: Node = _new_engine()
	ge.call("train_technique", "tech_stillwater", 100)
	_check(int(ge.call("technique_level", "tech_stillwater")) == 1, "100xp = level 1")
	ge.call("train_technique", "tech_stillwater", 300)
	_check(int(ge.call("technique_level", "tech_stillwater")) == 2, "400xp = level 2")
	_check(float(ge.call("technique_power_bonus", "tech_stillwater")) == 1.2, "level 2 bonus x1.2")
	_check(int(ge.call("technique_level", "tech_unknown")) == 0, "untrained = level 0")
	ge.set("qi", 500.0)
	ge.set("qi_bottleneck", 120.0)
	# Power 10 < need 11, but x1.2 technique bonus carries it: 12 >= 11.
	_check(bool(ge.call("attempt_breakthrough", 10.0, 11.0, float(ge.call("technique_power_bonus", "tech_stillwater")))), "technique bonus decides tribulation")
	var st: Dictionary = ge.call("get_state")
	_check(int((st["techniques"] as Dictionary).get("tech_stillwater", 0)) == 400, "techniques persist in state")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(int(ge2.call("technique_level", "tech_stillwater")) == 2, "techniques survive save/load")
	ge.queue_free()
	ge2.queue_free()

func _test_bestiary() -> void:
	var ge: Node = _new_engine()
	ge.call("hunt_tick", "beast_cinderfox", 4999)
	_check(str(ge.call("completion_mark", "beast_cinderfox")) == "none", "4999 = none")
	ge.call("hunt_tick", "beast_cinderfox", 1)
	_check(str(ge.call("completion_mark", "beast_cinderfox")) == "marked", "5000 = marked")
	ge.call("hunt_tick", "beast_cinderfox", 15000)
	_check(str(ge.call("completion_mark", "beast_cinderfox")) == "apex", "20000 = apex")
	var order: Array = ["beast_cinderfox", "beast_mistralhare"]
	_check(str(ge.call("seek_unfinished", order)) == "beast_mistralhare", "seek skips completed")
	ge.call("hunt_tick", "beast_mistralhare", 6000)
	_check(str(ge.call("seek_unfinished", order)) == "", "seek empty when all marked+")
	var st: Dictionary = ge.call("get_state")
	_check(int((st["beasts"] as Dictionary).get("beast_cinderfox", 0)) == 20000, "beasts persist in state")
	ge.queue_free()

func _test_route_pause() -> void:
	# P13-B5: route planner cut (dead: no setter, no UI). Pause kept.
	var ge: Node = _new_engine()
	# Pause-before-death.
	ge.set("lifespan_years", 60)
	ge.set("pause_before_death_years", 5)
	ge.set("age_years", 55)
	ge.set("running", true)
	ge.connect("paused_for_death", _on_paused)
	ge.call("_step_tick")
	_check(not bool(ge.get("running")), "auto-pause at lifespan-5")
	_check(_paused_at == [56] or _paused_at == [55], "pause signal emitted")
	ge.call("resume")
	_check(bool(ge.get("running")), "resume restarts")
	_paused_at.clear()
	ge.queue_free()

func _test_contentdb() -> void:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	_check(bool(cdb.call("load_all")), "content loads")
	_check((cdb.get("origins") as Array).size() == 4, "4 origins")
	_check((cdb.get("techniques") as Array).size() == 5, "5 techniques")
	_check((cdb.get("beasts") as Array).size() == 39, "39 beasts")
	_check(not (cdb.call("origin_by_id", "origin_ironhide") as Dictionary).is_empty(), "origin lookup")
	_check(int((cdb.call("origin_by_id", "origin_ironhide") as Dictionary).get("lifespan_bonus", -999)) == 20, "lifespan_bonus present")
	_check((cdb.call("beast_ids_in_order") as Array).size() == 39, "beast order helper")
	cdb.free()
