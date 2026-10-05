extends SceneTree
## P5 polish test: achievements, responsive layout, VFX, balance. Original code.
## Run: --headless -s res://tests/p5_test.gd (exit 0 = pass).

var _failures: int = 0
var _unlocked: Array = []

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _on_ach(id: String) -> void:
	_unlocked.append(id)

var _stage: int = 0
var _frames: int = 0
var _fx_t0: int = 0
var _scene_main: Node = null

func _initialize() -> void:
	print("P5-TEST start")
	_test_achievements()
	_test_balance()
	_test_migration()
	_test_contentdb()
	# Scene-dependent checks (layout + VFX) need delivered _ready, which only
	# happens once frames run. Set up the scene; _process() drives the rest.
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)
	# Freeze autoplay breakthroughs: unreachable bottleneck on the autoload
	# engine, so Main's loop can never re-trigger the banner mid-test.
	var auto: Node = root.get_node("GameEngine")
	auto.set("qi_bottleneck", 1e18)
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 2:
		_test_layout_framed()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 1:
		_test_vfx_framed()
		_stage = 3
		_frames = 0
		_fx_t0 = Time.get_ticks_msec()
	elif _stage == 3 and Time.get_ticks_msec() - _fx_t0 > 1200:
		_test_vfx_done()
		if _failures == 0:
			print("P5-TEST PASS")
		else:
			printerr("P5-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P5-TEST FAIL: timed out waiting for frames")
		quit(1)
	return false

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	return ge

func _rules() -> Array:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	var r: Array = (cdb.get("achievements") as Array).duplicate()
	cdb.free()
	return r

func _test_achievements() -> void:
	var ge: Node = _new_engine()
	ge.call("set_achievement_rules", _rules())
	ge.connect("achievement_unlocked", _on_ach)
	ge.call("rebirth")
	_check((ge.get("achievements") as Array).has("ach_reborn_1"), "rebirth unlocks Second Life")
	_check(_unlocked.has("ach_reborn_1"), "unlock signal fires")
	ge.set("qi", 500.0)
	ge.set("qi_bottleneck", 120.0)
	ge.call("attempt_breakthrough", 99.0, 1.0)
	_check((ge.get("achievements") as Array).has("ach_first_breath"), "breakthrough unlocks First Breath")
	ge.call("hunt_tick", "beast_mistralhare", 5000)
	_check((ge.get("achievements") as Array).has("ach_mark_1"), "marked unlocks Margins")
	var n0: int = (ge.get("achievements") as Array).size()
	ge.call("hunt_tick", "beast_mistralhare", 100)
	_check((ge.get("achievements") as Array).size() == n0, "no duplicate unlocks")
	ge.call("found_sect", "Test Society")
	_check((ge.get("achievements") as Array).has("ach_sect_1"), "founding unlocks Founder")
	ge.set("qi", 100000.0)
	ge.call("recruit_disciple")
	_check((ge.get("achievements") as Array).has("ach_disciple_1"), "recruit unlocks Follower")
	ge.call("refine_gear", "gear_riverband", 5)
	_check((ge.get("achievements") as Array).has("ach_gear_1"), "refine unlocks Trinket")
	ge.call("train_technique", "tech_stillwater", 100)
	_check((ge.get("achievements") as Array).has("ach_tech_1"), "training unlocks First Form")
	ge.set("qi", 1000000.0)
	for i in range(10):
		ge.set("qi_bottleneck", 120.0)
		ge.set("qi", 500.0)
		ge.call("attempt_breakthrough", 99.0, 1.0)
	_check(float(ge.get("dantian_purity")) == 100.0, "purity reaches 100")
	_check((ge.get("achievements") as Array).has("ach_pure_100"), "purity unlocks Clear Vessel")
	var st: Dictionary = ge.call("get_state")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check((ge2.get("achievements") as Array).size() == (ge.get("achievements") as Array).size(), "achievements survive save/load")
	_unlocked.clear()
	ge.queue_free()
	ge2.queue_free()

func _test_layout_framed() -> void:
	var ui: Node = _scene_main.get_node("UI")
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	_check(ui.get_node("Root/Banner") != null, "banner node exists")
	ui.call("apply_width", 1280.0)
	_check(not bool(ui.call("is_narrow_layout")), "wide layout not narrow")
	# P17-Step3: responsive = compact secondary top-bar labels, not columns.
	var mindlab: Label = ui.get_node("Root/TopBar/TopBarBox/MindLabel") as Label
	_check(mindlab.visible, "wide shows secondary labels")
	ui.call("apply_width", 400.0)
	_check(bool(ui.call("is_narrow_layout")), "narrow layout flagged")
	_check(not mindlab.visible, "narrow compacts secondary labels")
	ui.call("apply_width", 1280.0)
	_check(mindlab.visible, "wide restores secondary labels")

func _test_vfx_framed() -> void:
	var ui: Node = _scene_main.get_node("UI")
	_check(not bool(ui.call("fx_active")), "banner hidden initially")
	ui.call("play_breakthrough_fx")
	_check(bool(ui.call("fx_active")), "banner shows on breakthrough")
	_check(bool(ui.get_node("Root/Banner").get("visible")), "banner node visible")

func _test_vfx_done() -> void:
	var ui: Node = _scene_main.get_node("UI")
	_check(not bool(ui.call("fx_active")), "banner fades and hides")

func _test_balance() -> void:
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	var realms: Array = JSON.parse_string(f.get_as_text())
	f.close()
	# P18: strictly increasing, pure 4x from realm 9 on, front-loaded
	# before that (each early ratio sits between 4x and the next base
	# step — the slow start that speeds up).
	var mono: bool = true
	for i in range(1, realms.size()):
		var got: float = float(realms[i].get("qi_required", 0.0))
		var prev: float = float(realms[i - 1].get("qi_required", 0.0))
		if got <= prev:
			mono = false
		if i >= 9 and absf(got - prev * 4.0) > 1e-9 * prev * 4.0:
			mono = false
	_check(mono, "realm curve monotonic, pure 4x past realm 9")
	var base_rate: float = 1.0 * 1.0 * 1.0 * 1.3 * 10.0  # qi x apt x origin x dantian x 10tps
	var t0: float = float(realms[0].get("qi_required", 0.0)) / base_rate
	_check(t0 < 300.0, "realm 1 clearable <5min at base rate (onboarding)")
	var total: float = 0.0
	for r in realms:
		total += float(r.get("qi_required", 0.0))
	_check(total > 0.0 and is_finite(total), "total campaign Qi finite")
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(not ("e+" in str(BN.format_hybrid(total))), "total formats compact, no sci notation")

func _test_migration() -> void:
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.set_name("GameEngine")
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	var v3eng: Dictionary = {"tick_count": 3, "age_years": 25, "lifespan_years": 60,
		"qi": 1.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": ""}
	var slot := "user://cultivation_nation_save.json"
	var bak := "user://cultivation_nation_save.bak.json"
	var wf: FileAccess = FileAccess.open(slot, FileAccess.WRITE)
	wf.store_string(JSON.stringify({"save_version": 3, "engine": v3eng, "extra": {}}))
	wf.close()
	var loaded: Dictionary = sm.call("load_game")
	_check(int(loaded.get("save_version", 0)) == 12, "v3 fixture stamped to v12")
	_check((ge.get("achievements") as Array).is_empty(), "v3->v4 achievements default empty")
	for p in [slot, bak]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	ge.queue_free()
	sm.queue_free()

func _test_contentdb() -> void:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	_check(bool(cdb.call("load_all")), "content loads incl achievements")
	_check((cdb.get("achievements") as Array).size() == 43, "43 achievements")
	cdb.free()
