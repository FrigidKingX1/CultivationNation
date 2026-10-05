extends SceneTree
## P13 mechanics-rework test: readiness gating + proportional failure costs.
## Run: --headless -s res://tests/p13_test.gd (exit 0 = pass).
## Extended per P13-B slice (one suite for the whole rework).

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

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	return ge

func _initialize() -> void:
	print("P13-TEST start")

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		_test_readiness()
		_test_proportional_costs()
		_test_drill_hint()
		_test_readout()
		_test_b5c()
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 2:
		_test_auto_skips_unready()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 5:
		_test_manual_refuses()
		if _failures == 0:
			print("P13-TEST PASS")
		else:
			printerr("P13-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P13-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_readiness() -> void:
	var ge: Node = _new_engine()
	# Readiness mirrors the gate exactly: ready ⟺ the attempt would pass it.
	_check(bool(ge.call("is_ready", 10.0, 5.0, 1.0)), "strong ready")
	_check(not bool(ge.call("is_ready", 1.0, 999.0, 1.0)), "hopeless unready")
	_check(not bool(ge.call("is_ready", 10.0, 15.0, 1.0)), "thin unready")
	ge.set("qi", 200.0)
	ge.set("qi_bottleneck", 120.0)
	_check(bool(ge.call("attempt_breakthrough", 10.0, 5.0, 1.0)), "ready attempt passes gate")
	# Winter favors the defender: same power reads readier in month 10.
	ge.set("_month_accum", 10)
	_check(float(ge.call("readiness_pct", 10.0, 11.0, 1.0)) >= 100.0, "winter covers thin margin")
	ge.set("_month_accum", 0)
	_check(not bool(ge.call("is_ready", 10.0, 11.0, 1.0)), "spring exposes thin margin")
	ge.queue_free()

func _test_proportional_costs() -> void:
	var ge: Node = _new_engine()
	# Hopeless (r=0): the old full price is preserved exactly.
	ge.set("qi", 200.0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("dantian_purity", 80.0)
	ge.call("attempt_breakthrough", 0.0, 999.0)
	_check(ge.call("qi_num") == 100.0, "hopeless halves Qi")
	_check(int(ge.get("lifespan_scars")) == 5, "hopeless full scars")
	_check(float(ge.get("dantian_purity")) == 78.0, "hopeless full purity loss")
	# Near-miss (r=0.8): Qi x0.9, 1 scar, purity -0.4.
	ge.set("qi", 200.0)
	ge.set("dantian_purity", 80.0)
	ge.set("lifespan_scars", 0)
	ge.call("attempt_breakthrough", 8.0, 10.0)
	_check(absf(ge.call("qi_num") - 180.0) < 1e-9, "nearmiss keeps 90% Qi")
	_check(int(ge.get("lifespan_scars")) == 1, "nearmiss one scar")
	_check(absf(float(ge.get("dantian_purity")) - 79.6) < 1e-9, "nearmiss fractional purity")
	# Grazing miss (r=0.99): Qi ~intact, zero scars.
	ge.set("qi", 200.0)
	ge.set("dantian_purity", 80.0)
	ge.set("lifespan_scars", 0)
	ge.call("attempt_breakthrough", 9.9, 10.0)
	_check(absf(ge.call("qi_num") - 199.0) < 1e-9, "graze keeps 99.5% Qi")
	_check(int(ge.get("lifespan_scars")) == 0, "graze zero scars")
	ge.queue_free()

func _test_drill_hint() -> void:
	var ge: Node = _new_engine()
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	ge.call("set_realm_table", JSON.parse_string(f.get_as_text()))
	f.close()
	# Realm 2 needs 15; bare hands read 10. Brimming but weak → hint owed.
	ge.set("realm_index", 2)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	_check("hint_drill" in ge.call("due_hints"), "drill hint owed when weak")
	# Drill to sufficiency (level 5 → bonus 1.5 → 15 meets 15): hint retires.
	ge.call("train_technique", "pace_art", 2500)
	_check(not ("hint_drill" in ge.call("due_hints")), "drill hint retires when ready")
	# Table-less fallback uses the legacy formula identically.
	var ge2: Node = _new_engine()
	ge2.set("realm_index", 2)
	ge2.set("qi_bottleneck", 120.0)
	ge2.set("qi", 120.0)
	_check("hint_drill" in ge2.call("due_hints"), "drill hint table-less")
	_check(float(ge2.call("trib_power_for", 7)) == 40.0, "legacy trib formula")
	ge.queue_free()
	ge2.queue_free()

func _test_readout() -> void:
	var ge: Node = _new_engine()
	# Sympathy names the answering element, or nothing when grounds are cold.
	_check(str(ge.call("sympathy_glyph")) == "—", "no grounds no sympathy")
	var f: FileAccess = FileAccess.open("res://data/beasts.json", FileAccess.READ)
	ge.call("set_beast_pool", JSON.parse_string(f.get_as_text()))
	f.close()
	ge.call("generate_map", 7)
	ge.set("roots", {"water": 0.5})
	var dew: String = ""
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) == "Dewfield":
			dew = str((n as Dictionary).get("id", ""))
			break
	ge.call("travel_to", dew)
	_check(str(ge.call("sympathy_glyph")) == "water", "sympathy names water")
	# Season labels carry their effect tags.
	ge.set("_month_accum", 0)
	_check("(+Qi)" in str(ge.call("season_label")), "spring tags Qi")
	ge.set("_month_accum", 10)
	_check("(+ward)" in str(ge.call("season_label")), "winter tags ward")
	ge.queue_free()

func _test_b5c() -> void:
	# Soul witnesses T1 crossings (+2) instead of idling through the tier.
	var ge: Node = _new_engine()
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	ge.call("set_realm_table", JSON.parse_string(f.get_as_text()))
	f.close()
	ge.call("choose_soul_weapon", "soul_blade")
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	ge.call("attempt_breakthrough", 99.0, 5.0)
	_check(int((ge.get("soulweapon") as Dictionary).get("xp", -1)) == 2, "T1 crossing tempers soul")
	# Milestone kills fund the cauldron: +25 marked, +100 apex.
	ge.set("herbs", 0.0)
	ge.call("hunt_tick", "beast_mistralhare", 5000)
	_check(float(ge.get("herbs")) == 25.0, "marked nest holds herbs")
	ge.call("hunt_tick", "beast_mistralhare", 15000)
	_check(float(ge.get("herbs")) == 125.0, "apex lair holds cache")
	ge.queue_free()

func _test_auto_skips_unready() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var ge: Node = root.get_node("GameEngine")
	# Realm 2 needs 15; bare-handed power 10 cannot pass. Autoplay must hold
	# position: Qi intact (unhalved), no scars, no realm change.
	ge.set("realm_index", 2)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	ge.set("lifespan_scars", 0)

func _test_manual_refuses() -> void:
	var ge: Node = root.get_node("GameEngine")
	# The Attempt button advertises readiness + forecast before committing.
	# Pin Spring first: readiness is season-sensitive (Summer reads 73%),
	# and slow headless frames can drift months before this read.
	ge.set("_month_accum", 0)
	_scene_main.call("_refresh_breakthrough_btn")
	var txt: String = str((_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn") as BaseButton).text)
	_check("66%" in txt, "button shows thin readiness")
	_check("Radiant" in txt, "button forecasts quality")
	_check(int(ge.get("realm_index")) == 2, "autoplay held at realm 2")
	_check(ge.call("qi_num") >= 120.0, "autoplay left Qi intact")
	_check(int(ge.get("lifespan_scars")) == 0, "autoplay scarred nothing")
	(_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn") as BaseButton).emit_signal("pressed")
	_check(int(ge.get("realm_index")) == 2, "manual refuses doomed crossing")
	_check(ge.call("qi_num") >= 120.0, "manual keeps Qi on refusal")
	_check(int(ge.get("lifespan_scars")) == 0, "manual scars nothing on refusal")
	# Voluntary reincarnation through the real button banks the life.
	var life0: int = int(ge.get("life_number"))
	(_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/EndLifeBtn") as BaseButton).emit_signal("pressed")
	_check(int(ge.get("life_number")) == life0 + 1, "rebirth button ends life")
