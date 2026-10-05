extends SceneTree
## P6 agency/audio test: focus, buttons, sfx, migration. Original code.
## Run: --headless -s res://tests/p6_test.gd (exit 0 = pass).

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
	print("P6-TEST start")
	# QA Round 1: fresh boot required (a leftover save holds the sim at
	# title and starves UI-driven asserts). Same guard as p10/p17.
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_test_focus_engine()
	_test_migration()
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 2:
		# Autoload _ready (SfxSynth tones) is only delivered once frames run.
		_test_audio()
		_test_buttons()
		_stage = 2
	elif _stage == 2:
		_finish()
	elif _frames > 3600:
		printerr("P6-TEST FAIL: frame timeout")
		quit(1)
	return false

func _finish() -> void:
	if _failures == 0:
		print("P6-TEST PASS")
	else:
		printerr("P6-TEST FAIL count=", _failures)
	quit(_failures)

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	return ge

func _test_focus_engine() -> void:
	var ge: Node = _new_engine()
	_check(not bool(ge.call("set_focus", "nap")), "bad focus rejected")
	_check(bool(ge.call("set_focus", "train")), "focus train ok")
	# P13-B5 keystone: drill yields xp but zero Qi (was half).
	_check(float(ge.get("focus_mult")) == 0.0, "drill yields zero Qi")
	ge.set("focus_technique", "tech_stillwater")
	ge.call("_player_tick")
	_check(int((ge.get("techniques") as Dictionary).get("tech_stillwater", 0)) == 1, "train focus xp per tick")
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_beast_pool", cdb.get("beasts"))
	ge.call("generate_map", 7)
	var node_id: String = str((ge.get("map_nodes") as Array)[0].get("id", ""))
	ge.call("travel_to", node_id)
	ge.call("set_focus", "hunt")
	# P13-B5 keystone: stalk yields kills but zero Qi (was half).
	_check(float(ge.get("focus_mult")) == 0.0, "stalk yields zero Qi")
	ge.call("_player_tick")
	var beast_id: String = str((ge.get("map_nodes") as Array)[0].get("beast_id", ""))
	_check(int((ge.get("beasts") as Dictionary).get(beast_id, 0)) >= 1, "hunt focus kills at node")
	ge.call("set_focus", "cultivate")
	_check(float(ge.get("focus_mult")) == 1.0, "cultivate full rate")
	_check(float(ge.call("best_technique_bonus")) == 1.0, "best bonus untrained = 1.0")
	ge.call("train_technique", "tech_stillwater", 400)
	_check(float(ge.call("best_technique_bonus")) == 1.2, "best bonus tracks top technique")
	_check(not bool(ge.call("assign_all", "dance")), "bad gang task rejected")
	ge.set("qi", 100000.0)
	ge.call("recruit_disciple")
	ge.call("recruit_disciple")
	_check(bool(ge.call("assign_all", "gather")), "gang assign ok")
	_check(float(ge.get("_gather_mult")) == 1.04, "gang of 2 gathers +4%")
	var st: Dictionary = ge.call("get_state")
	_check(str(st.get("player_focus", "")) == "cultivate", "focus in state")
	cdb.free()
	ge.queue_free()

func _test_audio() -> void:
	var sfx: Node = root.get_node("SfxSynth")
	_check(int(sfx.call("stream_frames", "click")) > 100, "click stream generated")
	_check(int(sfx.call("stream_frames", "breakthrough")) > int(sfx.call("stream_frames", "click")), "chime longer than blip")
	_check(int(sfx.call("stream_frames", "nope")) == 0, "unknown sfx = 0 frames")
	sfx.set("muted", false)
	_check(bool(sfx.call("play", "click")), "play ok unmuted")
	_check(not bool(sfx.call("play", "nope")), "play unknown fails")
	sfx.set("muted", true)
	_check(not bool(sfx.call("play", "click")), "muted suppresses play")
	sfx.set("muted", false)
	# P17-Step3: volume slider backend (mute preserved as hard switch).
	sfx.set("volume", 0.5)
	_check(float(sfx.get("volume")) == 0.5, "volume sets")
	_check(bool(sfx.call("play", "click")), "play ok at half volume")
	sfx.set("volume", 1.0)

func _test_migration() -> void:
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.set_name("GameEngine")
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	var v4eng: Dictionary = {"tick_count": 9, "age_years": 28, "lifespan_years": 60,
		"qi": 2.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": []}
	var slot := "user://cultivation_nation_save.json"
	var bak := "user://cultivation_nation_save.bak.json"
	var wf: FileAccess = FileAccess.open(slot, FileAccess.WRITE)
	wf.store_string(JSON.stringify({"save_version": 4, "engine": v4eng, "extra": {}}))
	wf.close()
	var loaded: Dictionary = sm.call("load_game")
	_check(int(loaded.get("save_version", 0)) == 11, "v4 fixture stamped to v11")
	_check(str(ge.get("player_focus")) == "cultivate", "v4->v5 focus default")
	_check(not bool(ge.get("muted")), "v4->v5 muted default false")
	for p in [slot, bak]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	ge.queue_free()
	sm.queue_free()

func _btn(path: String) -> BaseButton:
	## P17-Step2: dock/topbar rows. Names stable; only parent prefixes moved.
	var row1: Array = ["FocusCultivate", "FocusTrain", "FocusHunt", "BreakthroughBtn"]
	var top: Array = ["Time1", "Time10", "Time100", "Time1000", "PauseBtn", "MuteBtn"]
	var row2: Array = ["RecruitBtn", "GangGather", "GangHunt", "GangIdle"]
	var base: String = "UI/Root/BottomDock/DockRows/DockRow1/"
	if path in top:
		base = "UI/Root/TopBar/TopBarBox/"
	elif path in row2:
		base = "UI/Root/BottomDock/DockRows/DockRow2/"
	return _scene_main.get_node(base + path) as BaseButton

func _push(path: String) -> void:
	_btn(path).emit_signal("pressed")

func _test_buttons() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var auto: Node = root.get_node("GameEngine")
	auto.set("qi", 0.0)
	auto.set("qi_bottleneck", 120.0)
	_push("FocusTrain")
	_check(str(auto.get("player_focus")) == "train", "Focus Drill button")
	_push("FocusHunt")
	_check(str(auto.get("player_focus")) == "hunt", "Focus Stalk button")
	_push("FocusCultivate")
	_check(str(auto.get("player_focus")) == "cultivate", "Focus Breathe button")
	var r0: int = int(auto.get("realm_index"))
	auto.set("qi", 10000.0)
	_push("BreakthroughBtn")
	_check(int(auto.get("realm_index")) == r0 + 1, "tribulation button breakthroughs")
	_push("Time100")
	_check(float(auto.get("time_scale")) == 100.0, "speed button sets scale")
	auto.set("qi", 100000.0)
	_push("RecruitBtn")
	_check((auto.get("disciples") as Array).size() == 1, "recruit button hires")
	_push("GangHunt")
	_check(str((auto.get("disciples") as Array)[0].get("task", "")) == "hunt", "gang button assigns")
	_push("PauseBtn")
	_check(not bool(auto.get("running")), "pause button halts")
	_push("PauseBtn")
	_check(bool(auto.get("running")), "pause button resumes")
	_push("MuteBtn")
	_check(bool(auto.get("muted")), "mute button silences")
	_check(bool(root.get_node("SfxSynth").get("muted")), "sfx follows mute")
	_push("MuteBtn")
	var ui: Node = _scene_main.get_node("UI")
	ui.call("refresh")
	# P17-Step3: achievements header lives in the Deeds tab now.
	_check("Achievements" in str(ui.get_node("Root/SidePanel/PanelScroll/PanelTabs/Deeds/AchieveHeader").text), "achievements line shown")
	_check("First Follower" in str(ui.get_node("Root/SidePanel/PanelScroll/PanelTabs/Deeds/AchieveHeader").text), "latest achievement named (recruit unlocked after breakthrough)")
