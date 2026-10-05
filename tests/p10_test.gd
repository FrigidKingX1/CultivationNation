extends SceneTree
## P10 records + autoplay bot: lifetime story + end-to-end UI-driven play.
## Run: --headless -s res://tests/p10_test.gd (exit 0 = pass).

var _failures: int = 0
var _stage: int = 0
var _frames: int = 0
var _scene_main: Node = null
var _start_life: int = 1

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _initialize() -> void:
	print("P10-TEST start")
	# QA Round 1: the bot needs a fresh boot (a leftover save holds the sim
	# at title and starves it). Same self-protection as p17.
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 2:
		_opening_moves()
		_stage = 2
		_frames = 0
	elif _stage == 2:
		_play_frame()
		if int(_auto().get("life_number")) >= _start_life + 3:
			_stage = 3
		elif _frames > 15000:
			printerr("P10-TEST FAIL: bot timed out before 3 rebirths")
			quit(1)
			return true
	elif _stage == 3:
		_test_records()
		_finish()
	elif _frames > 36000:
		printerr("P10-TEST FAIL: frame timeout")
		quit(1)
	return false

func _finish() -> void:
	if _failures == 0:
		print("P10-TEST PASS")
	else:
		printerr("P10-TEST FAIL count=", _failures)
	quit(_failures)

func _auto() -> Node:
	return root.get_node("GameEngine")

func _press(path: String) -> void:
	## P17-Step2: route moved controls to dock/topbar rows; the rest stays.
	var moved: Dictionary = {
		"ActionGrid/FocusCultivate": "UI/Root/BottomDock/DockRows/DockRow1/FocusCultivate",
		"ActionGrid/FocusTrain": "UI/Root/BottomDock/DockRows/DockRow1/FocusTrain",
		"ActionGrid/FocusHunt": "UI/Root/BottomDock/DockRows/DockRow1/FocusHunt",
		"ActionGrid/BreakthroughBtn": "UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn",
		"ActionGrid/Time1": "UI/Root/TopBar/TopBarBox/Time1",
		"ActionGrid/Time10": "UI/Root/TopBar/TopBarBox/Time10",
		"ActionGrid/Time100": "UI/Root/TopBar/TopBarBox/Time100",
		"ActionGrid/Time1000": "UI/Root/TopBar/TopBarBox/Time1000",
		"ActionGrid/PauseBtn": "UI/Root/TopBar/TopBarBox/PauseBtn",
		"ActionGrid/MuteBtn": "UI/Root/TopBar/TopBarBox/MuteBtn",
		"ActionGrid/RecruitBtn": "UI/Root/BottomDock/DockRows/DockRow2/RecruitBtn",
		"ActionGrid/GangGather": "UI/Root/BottomDock/DockRows/DockRow2/GangGather",
		"ActionGrid/GangHunt": "UI/Root/BottomDock/DockRows/DockRow2/GangHunt",
		"ActionGrid/GangIdle": "UI/Root/BottomDock/DockRows/DockRow2/GangIdle",
		"MapGrid/StalkBtn": "UI/Root/BottomDock/DockRows/DockRow1/StalkBtn",
		"MapGrid/WanderBtn": "UI/Root/BottomDock/DockRows/DockRow1/WanderBtn",
		"LifeGrid/OrgBeastkin": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/OrgBeastkin",
		"LifeGrid/TechStillwater": "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechStillwater",
		"SectGrid/FoundBtn": "UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/SectGrid/FoundBtn",
		"GearBox/Gear_gear_riverband": "UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/GearBox/RowGear_gear_riverband/Gear_gear_riverband",
	}
	var full: String = str(moved.get(path, "UI/Root/Columns/ActionPanel/ActionScroll/ActionBox/" + path))
	var b: BaseButton = _scene_main.get_node(full) as BaseButton
	b.emit_signal("pressed")

func _opening_moves() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var ge: Node = _auto()
	_start_life = int(ge.get("life_number"))
	ge.set("qi", 100000.0)
	_press("LifeGrid/OrgBeastkin")
	_press("LifeGrid/TechStillwater")
	_press("ActionGrid/FocusTrain")
	_press("SectGrid/FoundBtn")
	_press("ActionGrid/RecruitBtn")
	_press("ActionGrid/RecruitBtn")
	_press("ActionGrid/GangHunt")
	_press("ActionGrid/Time1000")
	_press("GearBox/Gear_gear_riverband")
	_check(str(ge.get("origin_id")) == "origin_beastkin", "bot picks origin")
	_check(not (ge.get("sect") as Dictionary).is_empty(), "bot founds sect")
	_check((ge.get("disciples") as Array).size() == 2, "bot recruits gang")
	_check(int((ge.get("gear") as Dictionary).get("gear_riverband", 0)) == 1, "bot refines heirloom")

func _play_frame() -> void:
	var ge: Node = _auto()
	# Walk on first chance (Node0 is always Dewfield: first zone in pool order).
	if str(ge.get("current_node")) == "":
		var nb: BaseButton = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox/Node0") as BaseButton
		if nb != null:
			nb.emit_signal("pressed")
	if ge.call("qi_num") >= ge.call("bottleneck_num"):
		_press("ActionGrid/BreakthroughBtn")

func _test_records() -> void:
	var ge: Node = _auto()
	_check(int(ge.get("life_number")) >= _start_life + 3, "bot lives 3+ lives")
	_check(int(ge.get("realm_index")) >= 1, "bot climbs realms")
	_check((ge.get("achievements") as Array).size() >= 3, "bot earns achievements")
	_check(not (ge.get("sect") as Dictionary).is_empty(), "sect survives deaths")
	var kills: int = 0
	for k in (ge.get("beasts") as Dictionary):
		kills += int((ge.get("beasts") as Dictionary)[k])
	_check(kills > 0, "bot gang hunts kills")
	# Records row against forced values (UI math only).
	ge.set("tick_count", 1200)
	ge.set("realm_index", 5)
	var ui: Node = _scene_main.get_node("UI")
	ui.call("refresh")
	# P17-Step3: records row lives in the Records tab now; substrings kept.
	var text: String = str(ui.get_node("Root/SidePanel/PanelScroll/PanelTabs/Records/RecordsLabel").text)
	_check(("Lives %d" % int(ge.get("life_number"))) in text, "records show lives")
	_check("Peak realm 5" in text, "records show peak realm")
	_check("Time 100Y" in text, "records show time from ticks")
