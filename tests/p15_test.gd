extends SceneTree
## P15 depth-pass test: attunement, per-art curves/perks, soul paths.
## Run: --headless -s res://tests/p15_test.gd (exit 0 = pass).
## Extended per P15 step (sinks, endgame, vestigial, travel, achievements).

var _failures: int = 0

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

func _tech_defs() -> Array:
	var f: FileAccess = FileAccess.open("res://data/techniques.json", FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

func _initialize() -> void:
	print("P15-TEST start")
	# QA Round 1: fresh boot required (see p10/p17 guard).
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _log_text() -> String:
	var ui: Node = _scene_main.get_node("UI")
	return str(ui.get_node("Root/ChroniclePanel/ChronicleBox/LogText2").get_parsed_text())

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		_test_curves_fallback()
		_test_attunement()
		_test_perks()
		_test_soul_paths()
		_test_attunement_save()
		_test_sinks()
		_test_victory()
		_test_toll()
		_test_achievements()
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 2:
		_test_stalk_warning()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 1:
		_test_victory_live()
		if _failures == 0:
			print("P15-TEST PASS")
		else:
			printerr("P15-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P15-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_curves_fallback() -> void:
	# Per-art curves differ once defs are wired...
	var ge: Node = _new_engine()
	ge.call("set_technique_defs", _tech_defs())
	ge.call("train_technique", "tech_stillwater", 2500)
	ge.call("train_technique", "tech_emberstep", 2500)
	ge.call("train_technique", "tech_rootgrip", 2500)
	_check(float(ge.call("technique_power_bonus", "tech_stillwater")) == 1.5, "stillwater curve 1+0.10L")
	_check(float(ge.call("technique_power_bonus", "tech_emberstep")) == 1.8, "emberstep curve 1+0.16L")
	_check(absf(float(ge.call("technique_power_bonus", "tech_rootgrip")) - 1.35) < 1e-9, "rootgrip curve 1+0.07L")
	# ...and unknown ids reproduce the legacy formula exactly.
	var ge2: Node = _new_engine()
	_check(float(ge2.call("technique_power_bonus", "pace_art")) == 1.0, "fallback level-0 unity")
	ge2.call("train_technique", "pace_art", 400)
	_check(float(ge2.call("technique_power_bonus", "pace_art")) == 1.2, "fallback legacy curve")
	ge.queue_free()
	ge2.queue_free()

func _test_attunement() -> void:
	var ge: Node = _new_engine()
	ge.call("set_technique_defs", _tech_defs())
	ge.set("focus_technique", "tech_stillwater")
	ge.call("set_focus", "train")
	for i in range(12):
		ge.call("_step_tick")
	_check(absf(float((ge.get("attunement") as Dictionary).get("tech_stillwater", -1.0)) - 1.0) < 1e-9, "attunement rises while drilled")
	for i in range(1200):
		ge.call("_step_tick")
	_check(float((ge.get("attunement") as Dictionary).get("tech_stillwater", -1.0)) == 100.0, "attunement caps at 100")
	# The undrilled art cools while another is drilled.
	ge.set("attunement", {"tech_emberstep": 100.0})
	ge.set("focus_technique", "tech_stillwater")
	for i in range(48):
		ge.call("_step_tick")
	_check(absf(float((ge.get("attunement") as Dictionary).get("tech_emberstep", -1.0)) - 99.0) < 1e-9, "idle art cools")
	# Attunement scales power: capped ember out-pulls fresh stillwater.
	ge.call("train_technique", "tech_emberstep", 2500)
	ge.set("attunement", {"tech_emberstep": 100.0, "tech_stillwater": 0.0})
	ge.call("train_technique", "tech_stillwater", 2500)
	_check(absf(float(ge.call("best_technique_bonus")) - 2.7) < 1e-9, "best tracks attuned max")
	ge.queue_free()

func _test_perks() -> void:
	# Untiring: attuned stillwater drills without wearing the heart.
	var ge: Node = _new_engine()
	ge.call("set_technique_defs", _tech_defs())
	ge.set("attunement", {"tech_stillwater": 60.0})
	ge.set("focus_technique", "tech_stillwater")
	ge.call("set_focus", "train")
	for i in range(60):
		ge.call("_step_tick")
	_check(float(ge.get("mind")) == 70.0, "untiring drills wear nothing")
	# Emberstep always costs double: 30 ticks wear twice.
	var ge2: Node = _new_engine()
	ge2.call("set_technique_defs", _tech_defs())
	ge2.set("focus_technique", "tech_emberstep")
	ge2.call("set_focus", "train")
	for i in range(30):
		ge2.call("_step_tick")
	_check(float(ge2.get("mind")) == 68.0, "emberstep double strain")
	# Bulwark: attuned rootgrip focus braces the shield (smaller leak).
	var ge3: Node = _new_engine()
	ge3.call("set_technique_defs", _tech_defs())
	ge3.set("attunement", {"tech_rootgrip": 60.0})
	ge3.set("focus_technique", "tech_rootgrip")
	var guarded: Dictionary = ge3.call("forecast_quality", 45.0, 45.0, 1.0, 1.0)
	ge3.set("focus_technique", "tech_stillwater")
	var bare: Dictionary = ge3.call("forecast_quality", 45.0, 45.0, 1.0, 1.0)
	_check(float(guarded.get("leak", 999.0)) < float(bare.get("leak", -1.0)), "bulwark braces shield")
	# Settling: attuned stonebell breakthroughs settle +40, not +25.
	var ge4: Node = _new_engine()
	ge4.call("set_technique_defs", _tech_defs())
	ge4.set("attunement", {"tech_stonebell": 60.0})
	ge4.set("focus_technique", "tech_stonebell")
	ge4.set("mind", 50.0)
	ge4.set("qi", 200.0)
	ge4.set("qi_bottleneck", 120.0)
	ge4.call("attempt_breakthrough", 99.0, 1.0)
	_check(float(ge4.get("mind")) == 90.0, "settling restores extra")
	ge.queue_free()
	ge2.queue_free()
	ge3.queue_free()
	ge4.queue_free()

func _test_soul_paths() -> void:
	# Blade converts levels to power; bell wards; mirror tithes karma.
	var ge: Node = _new_engine()
	_check(float(ge.call("artifact_power_bonus")) == 0.0, "no soul no bonus")
	ge.set("soulweapon", {"path": "soul_blade", "xp": 40})
	_check(float(ge.call("artifact_power_bonus")) == 2.0, "blade +1 power per level")
	ge.set("soulweapon", {"path": "soul_bell", "xp": 40})
	_check(float(ge.call("artifact_power_bonus")) == 0.0, "bell grants no power")
	ge.set("realm_index", 8)
	var bell: Dictionary = ge.call("forecast_quality", 45.0, 45.0, 1.0, 1.0)
	ge.set("soulweapon", {})
	var bare: Dictionary = ge.call("forecast_quality", 45.0, 45.0, 1.0, 1.0)
	_check(float(bell.get("leak", 999.0)) < float(bare.get("leak", -1.0)), "bell wards the crossing")
	ge.set("realm_index", 5)
	ge.set("qi_earned_this_life", 1000000.0)
	ge.set("achievements", ["a", "b"])
	var plain: int = int(ge.call("karma_yield"))
	ge.set("soulweapon", {"path": "soul_mirror", "xp": 40})
	_check(int(ge.call("karma_yield")) > plain, "mirror tithes karma")
	ge.queue_free()

func _test_sinks() -> void:
	# Herb cauldron caps at 999 even through a +100 apex burst.
	var ge: Node = _new_engine()
	ge.set("herbs", 950.0)
	ge.call("hunt_tick", "beast_mistralhare", 20000)
	_check(float(ge.get("herbs")) == 999.0, "cauldron caps at 999")
	# Recruits never cost more than 8 fills; uncapped ranks scale forever.
	ge.set("qi_bottleneck", 120.0)
	ge.set("disciples", [{}, {}, {}, {}, {}])
	_check(float(ge.call("recruit_cost")) == 960.0, "recruit cost capped at 8 fills")
	ge.set("qi_bottleneck", 1000000000000.0)
	_check(float(ge.call("recruit_cost")) == 48600.0, "recruit curve intact when rich")
	ge.set("talents", {"talent_roots": 50})
	_check(int(ge.call("talent_cost", "talent_roots")) == 26010, "deep rank costs scale")
	ge.queue_free()

func _test_victory() -> void:
	# Clearing the ladder records victory once; the cap still refuses after.
	var ge: Node = _new_engine()
	_check(not bool(ge.get("victorious")), "victory starts false")
	ge.set("realm_index", 17)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	_check(bool(ge.call("attempt_breakthrough", 99.0, 1.0)), "final crossing passes")
	_check(int(ge.get("realm_index")) == 18, "ladder cleared")
	_check(bool(ge.get("victorious")), "victory recorded")
	_check("COMPLETE" in str(ge.call("realm_label")), "label records summit")
	ge.set("qi", 999999.0)
	_check(not bool(ge.call("attempt_breakthrough", 99.0, 1.0)), "cap still refuses past clear")
	_check(bool(ge.get("victorious")), "victory survives further attempts")
	ge.call("rebirth")
	_check(bool(ge.get("victorious")), "victory persists across rebirth")
	var st: Dictionary = ge.call("get_state")
	_check(bool(st.get("victorious", false)), "victory in state")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(bool(ge2.get("victorious")), "victory survives save/load")
	ge.queue_free()
	ge2.queue_free()

func _test_stalk_warning() -> void:
	# Weak stalker on deep grounds: halved signs + the drill fix named.
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 6)
	var murk: String = ""
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) == "Murkfen":
			murk = str((n as Dictionary).get("id", ""))
			break
	_check(murk != "" and bool(ge.call("travel_to", murk)), "walk murkfen grounds")
	(_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/StalkBtn") as BaseButton).emit_signal("pressed")
	_check("Outmatched" in _log_text(), "stalk names the drill fix")

func _test_victory_live() -> void:
	# The full live path: drill to gate power, cross the last gate, celebrate.
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 49)
	ge.set("techniques", {"tech_stillwater": 5760000})
	ge.set("qi", 1e32)
	(_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn") as BaseButton).emit_signal("pressed")
	_check(int(ge.get("realm_index")) == 50, "live crossing clears ladder")
	_check(bool(ge.get("victorious")), "live victory recorded")
	_check("fiftieth gate" in _log_text(), "celebration logged")

func _test_toll() -> void:
	# First walks are free; repeat journeys cost 5% and can refuse the poor.
	var ge: Node = _new_engine()
	var f: FileAccess = FileAccess.open("res://data/beasts.json", FileAccess.READ)
	ge.call("set_beast_pool", JSON.parse_string(f.get_as_text()))
	f.close()
	ge.call("generate_map", 4242)
	var dew: String = str((ge.get("map_nodes") as Array)[0].get("id", ""))
	ge.set("qi_bottleneck", 120.0)
	_check(float(ge.call("travel_toll", dew)) == 0.0, "first walk free")
	ge.set("qi", 10000.0)
	_check(bool(ge.call("travel_to", dew)), "free first walk")
	_check(float(ge.call("travel_toll", dew)) == 6.0, "repeat toll 5%")
	ge.set("qi", 10000.0)
	_check(bool(ge.call("travel_to", dew)), "funded repeat walks")
	_check(absf(ge.call("qi_num") - 9994.0) < 1e-9, "toll deducted")
	# Broke on walked grounds: refused with purse intact, breathing still legal.
	ge.set("qi", 0.0)
	_check(not bool(ge.call("travel_to", dew)), "poor repeat refused")
	_check(ge.call("qi_num") == 0.0, "refusal spends nothing")
	_check(bool(ge.call("set_focus", "cultivate")), "breathe-to-earn always legal")
	ge.call("_step_tick")
	_check(ge.call("qi_num") > 0.0, "legal move earns")
	# Broke wanderer still walks: first visits are always free.
	ge.set("qi", 0.0)
	var w: String = str(ge.call("wander"))
	_check(w != "", "poor wanderer walks new grounds free")
	ge.queue_free()

func _test_achievements() -> void:
	# New stats unlock their achievements through the normal poll path.
	var ge: Node = _new_engine()
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_achievement_rules", cdb.get("achievements"))
	_check((cdb.get("achievements") as Array).size() == 43, "43 achievements authored")
	cdb.free()
	ge.set("karma", 1000)
	ge.call("_poll_achievements")
	_check((ge.get("achievements") as Array).has("ach_karma_1000"), "karma weight unlocks")
	ge.set("talents", {"talent_roots": 3, "talent_body": 2})
	ge.call("_poll_achievements")
	_check((ge.get("achievements") as Array).has("ach_talent_5"), "fivefold path unlocks")
	_check(bool(ge.call("choose_soul_weapon", "soul_blade")), "soul binds")
	_check((ge.get("achievements") as Array).has("ach_soul_1"), "bound soul unlocks")
	ge.set("gear", {"gear_riverband": 5})
	_check(bool(ge.call("bequeath_gear", "gear_riverband", 5)), "relic given")
	_check((ge.get("achievements") as Array).has("ach_legacy_1"), "lineage begun unlocks")
	ge.set("pills", {"pill_prep": 1})
	ge.call("_poll_achievements")
	_check((ge.get("achievements") as Array).has("ach_pill_1"), "first draught unlocks")
	ge.set("attunement", {"tech_stillwater": 60.0})
	ge.call("_poll_achievements")
	_check((ge.get("achievements") as Array).has("ach_attune_60"), "single-pointed unlocks")
	ge.set("victorious", true)
	ge.call("_poll_achievements")
	_check((ge.get("achievements") as Array).has("ach_summit_1"), "summit cleared unlocks")
	ge.set("realm_index", 22)
	ge.call("_poll_achievements")
	_check((ge.get("achievements") as Array).has("ach_realm_22"), "deep realm unlocks")
	ge.queue_free()

func _test_attunement_save() -> void:
	var ge: Node = _new_engine()
	ge.set("attunement", {"tech_stillwater": 77.5})
	var st: Dictionary = ge.call("get_state")
	_check(float((st.get("attunement") as Dictionary).get("tech_stillwater", -1.0)) == 77.5, "attunement in state")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(float((ge2.get("attunement") as Dictionary).get("tech_stillwater", -1.0)) == 77.5, "attunement survives save/load")
	ge.queue_free()
	ge2.queue_free()
