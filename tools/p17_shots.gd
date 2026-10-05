extends SceneTree
## P17 shot script (kept in tools/): boots Main, applies a named setup, saves
## screenshots to user:// (copy to tools/shots/ with bash; res:// is read-only
## at runtime). Run WITHOUT --headless, optionally with --resolution WxH.
## Usage: <engine> --path <project> -s res://tools/p17_shots.gd -- <setup>
## Setups: boot | mid | ready | trib

var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null
var _setup: String = "boot"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_setup = str(args[0])
	print("SHOTS setup=", _setup)
	if _setup == "polish":
		for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		var GE: GDScript = load("res://scripts/GameEngine.gd")
		var SM: GDScript = load("res://scripts/SaveManager.gd")
		var ge: Node = GE.new()
		ge.set("realm_index", 8)
		ge.set("qi", 8000000.0)
		ge.set("age_years", 30)
		ge.set("techniques", {"tech_stillwater": 100000})
		var sm: Node = SM.new()
		sm.set("engine_ref", ge)
		sm.call("save_game")
		ge.free()
		sm.free()

func _ge() -> Node:
	return root.get_node("GameEngine")

func _snap(tag: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png("user://p17_" + _setup + "_" + tag + ".png")
	print("SHOTS saved ", tag, " err=", err)

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 5:
		_apply_setup()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 120:
		_snap("s0")
		if _setup == "trib":
			_fire_tribulation()
			_stage = 3
			_frames = 0
		elif _setup == "polish":
			_stage = 4
			_frames = 0
		else:
			_finish()
	elif _stage == 4 and _frames == 1:
		(_scene_main.get_node("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleContinueBtn") as BaseButton).emit_signal("pressed")
	elif _stage == 4 and _frames == 45:
		_snap("s1")
	elif _stage == 4 and _frames >= 110:
		_snap("s2")
		for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		_finish()
	elif _stage == 3 and _frames == 25:
		_snap("s1")
	elif _stage == 3 and _frames >= 50:
		_snap("s2")
		_finish()
	elif _frames > 3600:
		print("SHOTS timeout")
		quit(1)
		return true
	return false

func _finish() -> void:
	print("SHOTS done")
	quit(0)

func _apply_setup() -> void:
	var ge: Node = _ge()
	if _setup == "boot" or _setup == "polish":
		return
	# Mid-game state: tier-3 exile with systems engaged.
	ge.set("realm_index", 20)
	ge.set("qi", 100000.0)
	ge.set("techniques", {"tech_stillwater": 10000, "tech_emberstep": 6400})
	ge.set("attunement", {"tech_stillwater": 80.0})
	ge.set("focus_technique", "tech_stillwater")
	ge.set("karma", 2500)
	ge.set("talents", {"talent_roots": 3, "talent_body": 2})
	ge.set("soulweapon", {"path": "soul_blade", "xp": 120})
	ge.set("gear", {"gear_riverband": 5, "gear_starcompass": 2})
	ge.set("herbs", 140.0)
	ge.set("pills", {"pill_prep": 2, "pill_heal": 1})
	ge.set("toxicity", 18.0)
	ge.set("deviation", 1)
	ge.set("disciples", [{"task": "gather"}, {"task": "hunt"}, {"task": "train"}])
	ge.call("found_sect", "Shot Society")
	ge.set("current_node", "")
	if _setup == "ready" or _setup == "trib" or _setup == "panels":
		ge.set("qi", 999999999.0)
	if _setup == "trib":
		ge.call("set_focus", "cultivate")
	if _setup == "panels":
		_scene_main.call("_rebuild_bestiary")
		_scene_main.call("_rebuild_achievements")
		_scene_main.call("_refresh_attune_if_stale")
		(_scene_main.get_node("UI/Root/SidePanel") as PanelContainer).visible = true
		(_scene_main.get_node("UI/Root/RailPanel") as PanelContainer).visible = true
		(_scene_main.get_node("UI/Root/SidePanel/PanelTabs") as TabContainer).current_tab = 2
		_scene_main.call("_highlight_rail")

func _fire_tribulation() -> void:
	var ge: Node = _ge()
	ge.call("attempt_breakthrough", 999.0, 1.0)
	_snap("fired")
