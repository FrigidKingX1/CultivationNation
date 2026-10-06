extends SceneTree
## P8 gates/guidance test: travel gates, hints, wander, migration. Original code.
## Run: --headless -s res://tests/p8_test.gd (exit 0 = pass).

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
	print("P8-TEST start")
	# QA Round 1: fresh boot required (see p10/p17 guard).
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_test_gates_engine()
	_test_hints()
	_test_wander()
	_test_migration()
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 2:
		_fix_map()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 1:
		_test_gate_buttons()
		_test_wander_button()
		_stage = 3
	elif _stage == 3:
		_finish()
	elif _frames > 3600:
		printerr("P8-TEST FAIL: frame timeout")
		quit(1)
	return false

func _fix_map() -> void:
	# Fixed seed + rebuild on the NEXT frame, so button asserts below see it.
	var ge: Node = root.get_node("GameEngine")
	ge.call("generate_map", 4242)
	_scene_main.call("_refresh_map")

func _finish() -> void:
	if _failures == 0:
		print("P8-TEST PASS")
	else:
		printerr("P8-TEST FAIL count=", _failures)
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

func _node_in_zone(ge: Node, zone: String) -> String:
	for n in (ge.get("map_nodes") as Array):
		var pool: Array = ge.get("_beast_pool")
		for b in pool:
			if str((b as Dictionary).get("id", "")) == str((n as Dictionary).get("beast_id", "")) and str((b as Dictionary).get("zone", "")) == zone:
				return str((n as Dictionary).get("id", ""))
	return ""

func _test_gates_engine() -> void:
	var ge: Node = _new_engine()
	ge.call("set_beast_pool", _pool())
	ge.call("generate_map", 4242)
	_check(int(ge.call("zone_gate", "beast_mistralhare")) == 0, "dewfield gate 0")
	_check(int(ge.call("zone_gate", "beast_cinderfox")) == 2, "ashbarrow gate 2")
	_check(int(ge.call("zone_gate", "beast_mirrorserpent")) == 4, "gloamdeep gate 4")
	var ash: String = _node_in_zone(ge, "Ashbarrow")
	_check(ash != "", "ashbarrow node exists")
	_check(not bool(ge.call("travel_to", ash)), "gated travel refused at realm 0")
	ge.set("realm_index", 2)
	_check(bool(ge.call("travel_to", ash)), "travel opens at realm 2")
	var glo: String = _node_in_zone(ge, "Gloamdeep")
	_check(not bool(ge.call("travel_to", glo)), "gloamdeep refused at realm 2")
	ge.set("realm_index", 4)
	_check(bool(ge.call("travel_to", glo)), "gloamdeep opens at realm 4")
	ge.queue_free()

func _test_hints() -> void:
	var ge: Node = _new_engine()
	_check((ge.call("due_hints") as Array).has("hint_origin"), "origin hint at start")
	ge.call("choose_origin", "origin_wayfarer", 1.0, 0)
	_check(not (ge.call("due_hints") as Array).has("hint_origin"), "origin hint clears on choice")
	ge.set("qi", ge.call("bottleneck_num"))
	_check((ge.call("due_hints") as Array).has("hint_bottleneck"), "bottleneck hint when full")
	ge.call("mark_hint", "hint_bottleneck")
	_check(not (ge.call("due_hints") as Array).has("hint_bottleneck"), "seen hints never repeat")
	ge.set("total_rebirths", 1)
	_check((ge.call("due_hints") as Array).has("hint_pause"), "pause hint after a death")
	_check(not (ge.call("due_hints") as Array).has("hint_legacy"), "legacy hint needs carried progress")
	ge.call("train_technique", "tech_stillwater", 50)
	_check((ge.call("due_hints") as Array).has("hint_legacy"), "legacy hint with carried arts")
	ge.set("realm_index", 2)
	_check((ge.call("due_hints") as Array).has("hint_travel"), "travel hint at realm 2")
	ge.set("realm_index", 3)
	_check((ge.call("due_hints") as Array).has("hint_sect"), "sect hint at realm 3")
	ge.set("qi", 100000.0)
	ge.call("recruit_disciple")
	_check((ge.call("due_hints") as Array).has("hint_duties"), "duties hint with idle disciple")
	_check((ge.call("due_hints") as Array).has("hint_gear"), "gear hint with spare Qi")
	var st: Dictionary = ge.call("get_state")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(not (ge2.call("due_hints") as Array).has("hint_bottleneck"), "seen hints persist save/load")
	ge.queue_free()
	ge2.queue_free()

func _test_wander() -> void:
	var ge: Node = _new_engine()
	var pool: Array = _pool()
	ge.call("set_beast_pool", pool)
	var order: Array = []
	for b in pool:
		order.append(str((b as Dictionary).get("id", "")))
	ge.call("set_hunt_order", order)
	ge.call("generate_map", 4242)
	var first: String = str(ge.call("wander"))
	_check(first != "", "wander picks a ground")
	_check((ge.get("nodes_visited") as Array).has(first), "visitation recorded")
	# Open all gates, then drain; wander must keep finding new ones.
	ge.set("realm_index", 45)
	var seen: Array = [first]
	for i in range(36):
		var nxt: String = str(ge.call("wander"))
		if nxt != "" and not seen.has(nxt):
			seen.append(nxt)
	_check(seen.size() == 36, "wander covers all 36 grounds")
	# All walked: falls back to unfinished-beast grounds. Re-walks are
	# tolled (P15-Step5), so the engine carries fare like live play would.
	ge.set("qi", 100000.0)
	var fb: String = str(ge.call("wander"))
	_check(fb != "", "wander falls back to unfinished quarry")
	var ge2: Node = _new_engine()
	_check(str(ge2.call("wander")) == "", "wander safe on empty chart")
	ge.queue_free()
	ge2.queue_free()

func _test_migration() -> void:
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.set_name("GameEngine")
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	var v5eng: Dictionary = {"tick_count": 11, "age_years": 29, "lifespan_years": 60,
		"qi": 3.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": [], "player_focus": "cultivate", "muted": false}
	var slot := "user://cultivation_nation_save.json"
	var bak := "user://cultivation_nation_save.bak.json"
	var wf: FileAccess = FileAccess.open(slot, FileAccess.WRITE)
	wf.store_string(JSON.stringify({"save_version": 5, "engine": v5eng, "extra": {}}))
	wf.close()
	var loaded: Dictionary = sm.call("load_game")
	_check(int(loaded.get("save_version", 0)) == 14, "v5 fixture stamped to v14")
	_check((ge.get("hints_seen") as Array).is_empty(), "v5->v6 hints default empty")
	_check((ge.get("nodes_visited") as Array).is_empty(), "v5->v6 visited default empty")
	for p in [slot, bak]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	ge.queue_free()
	sm.queue_free()

func _test_gate_buttons() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var ge: Node = root.get_node("GameEngine")
	ge.call("generate_map", 4242)
	_scene_main.call("_refresh_map")
	# Find a locked Ashbarrow button and press it: must refuse.
	var locked_btn: BaseButton = null
	for c in _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox").get_children():
		if c is BaseButton and ("locked" in (c as BaseButton).text):
			locked_btn = c
	_check(locked_btn != null, "locked grounds marked")
	var before: String = str(ge.get("current_node"))
	locked_btn.emit_signal("pressed")
	_check(str(ge.get("current_node")) == before, "locked travel refused by button")

func _test_wander_button() -> void:
	var ge: Node = root.get_node("GameEngine")
	(_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/WanderBtn") as BaseButton).emit_signal("pressed")
	_check(str(ge.get("current_node")) != "", "wander button walks")
