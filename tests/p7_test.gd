extends SceneTree
## P7 wire-up test: every engine system reachable via buttons. Original code.
## Run: --headless -s res://tests/p7_test.gd (exit 0 = pass).

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
	print("P7-TEST start")
	# QA Round 1: fresh boot required (see p10/p17 guard).
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)
	# Deterministic map for travel asserts (Main already generated one;
	# regenerate with a fixed seed before buttons are built).
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 2:
		_fix_map_seed()
		_test_origins_focus()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 1:
		_test_sect_found()
		_stage = 3
		_frames = 0
	elif _stage == 3 and _frames >= 2:
		_test_sect_cycle()
		_test_map()
		_stage = 4
		_frames = 0
	elif _stage == 4 and _frames >= 1:
		_test_gear()
		_stage = 5
	elif _stage == 5:
		_finish()
	elif _frames > 3600:
		printerr("P7-TEST FAIL: frame timeout")
		quit(1)
	return false

func _finish() -> void:
	if _failures == 0:
		print("P7-TEST PASS")
	else:
		printerr("P7-TEST FAIL count=", _failures)
	quit(_failures)

func _auto() -> Node:
	return root.get_node("GameEngine")

func _press(path: String) -> void:
	## P17-Step3: tab homes. Names stable; only parent prefixes moved.
	var moved: Dictionary = {
		"LifeGrid/OrgWayfarer": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgWayfarer",
		"LifeGrid/OrgIronhide": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgIronhide",
		"LifeGrid/OrgCinder": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgCinder",
		"LifeGrid/OrgBeastkin": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgBeastkin",
		"LifeGrid/TechStillwater": "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechStillwater",
		"LifeGrid/TechEmberstep": "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechEmberstep",
		"LifeGrid/TechRootgrip": "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechRootgrip",
		"SectGrid/FoundBtn": "UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/SectGrid/FoundBtn",
		"DiscipleBox/Disciple0": "UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/DiscipleBox/Disciple0",
		"MapBox/Node0": "UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox/Node0",
		"GearBox/Gear_gear_dewflask": "UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/GearBox/RowGear_gear_dewflask/Gear_gear_dewflask",
	}
	var full: String = str(moved.get(path, path))
	var b: BaseButton = _scene_main.get_node(full) as BaseButton
	b.emit_signal("pressed")

func _fix_map_seed() -> void:
	var ge: Node = _auto()
	ge.call("generate_map", 4242)
	_scene_main.call("_refresh_map")

func _test_origins_focus() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var ge: Node = _auto()
	_push_life("OrgIronhide")
	_check(str(ge.get("origin_id")) == "origin_ironhide", "origin button chooses")
	# P12-1 scaled lifespan: tier-1 table value 110 + ironhide bonus 20.
	_check(int(ge.get("lifespan_years")) == 130, "ironhide years applied")
	_push_life("OrgCinder")
	_check(str(ge.get("origin_id")) == "origin_ironhide", "second origin refused (locked)")
	_push_life("TechEmberstep")
	_check(str(ge.get("focus_technique")) == "tech_emberstep", "drill focus button sets art")
	_push_grid("FocusTrain")
	ge.call("_step_tick")
	ge.call("_step_tick")
	_check(int((ge.get("techniques") as Dictionary).get("tech_emberstep", 0)) == 2, "drill focus accrues on art")

func _push_grid(n: String) -> void:
	## P17-Step2: Focus row lives in DockRow1, Recruit/Gang in DockRow2.
	var base: String = "UI/Root/BottomDock/DockRows/DockRow1/"
	if n == "RecruitBtn" or n.begins_with("Gang"):
		base = "UI/Root/BottomDock/DockRows/DockRow2/"
	(_scene_main.get_node(base + n) as BaseButton).emit_signal("pressed")

func _push_life(n: String) -> void:
	var base := {
		"OrgWayfarer": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgWayfarer",
		"OrgIronhide": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgIronhide",
		"OrgCinder": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgCinder",
		"OrgBeastkin": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgBeastkin",
		"TechStillwater": "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechStillwater",
		"TechEmberstep": "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechEmberstep",
		"TechRootgrip": "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechRootgrip",
	}
	(_scene_main.get_node(str(base.get(n, n))) as BaseButton).emit_signal("pressed")

func _test_sect_found() -> void:
	var ge: Node = _auto()
	ge.set("qi", 100000.0)
	_push_sect("FoundBtn")
	_check(not (ge.get("sect") as Dictionary).is_empty(), "found button founds")
	var nm: String = str((ge.get("sect") as Dictionary).get("name", ""))
	_check(nm != "", "generated sect name non-empty")
	_push_sect("FoundBtn")
	_check(str((ge.get("sect") as Dictionary).get("name", "")) == nm, "second founding refused")
	_push_grid("RecruitBtn")
	_push_grid("RecruitBtn")
	_check((ge.get("disciples") as Array).size() == 2, "recruit buttons hire two")

func _push_sect(n: String) -> void:
	(_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/SectGrid/" + n) as BaseButton).emit_signal("pressed")

func _test_sect_cycle() -> void:
	var ge: Node = _auto()
	var b0: BaseButton = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/DiscipleBox/Disciple0") as BaseButton
	_check(b0 != null, "roster buttons built")
	b0.emit_signal("pressed")
	_check(str((ge.get("disciples") as Array)[0].get("task", "")) == "gather", "duty cycles to gather")
	b0.emit_signal("pressed")
	b0.emit_signal("pressed")
	_check(str((ge.get("disciples") as Array)[0].get("task", "")) == "train", "duty cycles to train")

func _test_map() -> void:
	var ge: Node = _auto()
	var id0: String = str((ge.get("map_nodes") as Array)[0].get("id", ""))
	var beast0: String = str((ge.get("map_nodes") as Array)[0].get("beast_id", ""))
	var nb: BaseButton = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox/Node0") as BaseButton
	_check(nb != null and ("Dewfield" in nb.text), "node buttons list zone")
	nb.emit_signal("pressed")
	_check(str(ge.get("current_node")) == id0, "node button travels")
	var k0: int = int((ge.get("beasts") as Dictionary).get(beast0, 0))
	_push_mapgrid("StalkBtn")
	_check(int((ge.get("beasts") as Dictionary).get(beast0, 0)) > k0, "stalk button hunts current grounds")

func _push_mapgrid(n: String) -> void:
	(_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/" + n) as BaseButton).emit_signal("pressed")

func _test_gear() -> void:
	var ge: Node = _auto()
	ge.set("qi", 100000.0)
	var b: BaseButton = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/GearBox/RowGear_gear_dewflask/Gear_gear_dewflask") as BaseButton
	_check(b != null and ("Dew Flask" in b.text), "gear buttons list costs")
	b.emit_signal("pressed")
	_check(int((ge.get("gear") as Dictionary).get("gear_dewflask", 0)) == 1, "refine button upgrades")
	ge.set("qi", 0.0)
	b.emit_signal("pressed")
	_check(int((ge.get("gear") as Dictionary).get("gear_dewflask", 0)) == 1, "short-Qi refine refused")
