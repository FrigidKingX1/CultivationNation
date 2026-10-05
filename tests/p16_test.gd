extends SceneTree
## P16 reliability test: offline application through live boot + seclusion UI.
## Run: --headless -s res://tests/p16_test.gd (exit 0 = pass).

var _failures: int = 0
var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

const SLOT := "user://cultivation_nation_save.json"
const BAK := "user://cultivation_nation_save.bak.json"

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _wipe() -> void:
	for p in [SLOT, BAK]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _log_text() -> String:
	var ui: Node = _scene_main.get_node("UI")
	return str(ui.get_node("Root/ChroniclePanel/ChronicleBox/LogText2").get_parsed_text())

func _initialize() -> void:
	print("P16-TEST start")
	# Pre-write a save one hour old: young exile, unfillable bottleneck (so
	# no live autoplay can attempt during the test), vigil directive.
	_wipe()
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var ge: Node = GE.new()
	# Deep exile, unreachable gate: realm 49 (need 250 vs bare power 10) so
	# live autoplay can never attempt during the test. One hour back.
	ge.set("realm_index", 49)
	ge.set("qi", 5.0)
	ge.set("age_years", 30)
	ge.set("lifespan_years", 110)
	var sm: Node = SM.new()
	sm.set("engine_ref", ge)
	sm.call("save_game")
	ge.free()
	sm.free()
	var f: FileAccess = FileAccess.open(SLOT, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d["saved_unix"] = int(Time.get_unix_time_from_system()) - 3600
	var w: FileAccess = FileAccess.open(SLOT, FileAccess.WRITE)
	w.store_string(JSON.stringify(d))
	w.close()

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 2:
		# P17-Step2: pre-written save boots to the title; Continue through it.
		var title: Node = _scene_main.get_node("UI/TitleOverlay")
		_check(bool(title.visible), "save boot shows title")
		(_scene_main.get_node("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleContinueBtn") as BaseButton).emit_signal("pressed")
		_check(not bool(title.visible), "continue dismisses title")
		_test_offline_boot()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 1:
		_test_seclusion_toggle()
		_wipe()
		if _failures == 0:
			print("P16-TEST PASS")
		else:
			printerr("P16-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P16-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_offline_boot() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	# P17-Step2: pre-written save boots to the title; Continue through it.
	(_scene_main.get_node("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleContinueBtn") as BaseButton).emit_signal("pressed")
	_check(not bool(_scene_main.get_node("UI/TitleOverlay").visible), "continue dismisses title")
	var ge: Node = root.get_node("GameEngine")
	ge.set("running", false)
	# One hour away = 3600 ticks (25 years: age 30 -> 55) under an ageless
	# tier-7 sky, so no death looms here (both mortality modes agree; the
	# vigil/unfettered split is covered in save_robustness). Qi pools far
	# past anything live frames could explain; no gate is skipped.
	_check(ge.call("qi_num") > 1000.0, "offline Qi pooled on load")
	_check(int(ge.get("realm_index")) == 49, "offline never skips a gate")
	# Floor, not exact: live boot frames add ticks before the freeze.
	_check(int(ge.get("age_years")) >= 55, "offline calendar advanced")
	_check("While you were away" in _log_text(), "welcome-back summary logged")

func _test_seclusion_toggle() -> void:
	var ge: Node = root.get_node("GameEngine")
	_check(str(ge.get("offline_mortality")) == "vigil", "directive starts vigil")
	(_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SeclusionBtn") as BaseButton).emit_signal("pressed")
	_check(str(ge.get("offline_mortality")) == "unfettered", "button cycles to unfettered")
	_check("Unfettered" in str((_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SeclusionBtn") as BaseButton).text), "button shows state")
	(_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SeclusionBtn") as BaseButton).emit_signal("pressed")
	_check(str(ge.get("offline_mortality")) == "vigil", "button cycles back to vigil")
