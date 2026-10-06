extends SceneTree
## P23 screenshot probe (P23b gate). Display-required: boots the live scene
## and captures the island world across zones, seasons, and a tribulation.
## Frame-staged (no awaits in _process): each shot fires on its own stage
## after layout settles. Run WITHOUT --headless:
## <engine> --path <project> -s res://tools/p23_shots.gd

var _frames: int = 0
var _stage: int = 0
var _main: Node = null

func _world() -> Node:
	return _main.get_node("WorldViewport/World")

func _snap(tag: String) -> void:
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png("user://p23_" + tag + ".png")
	print("P23-SHOTS snap ", tag, " err=", err)

func _initialize() -> void:
	print("P23-SHOTS start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_main = packed.instantiate()
		root.add_child(_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 40:
		var ge: Node = root.get_node("GameEngine")
		ge.set("realm_index", 12)
		ge.set("qi", 9.87e12)
		_main.call("_refresh_all")
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 15:
		_snap("isle_dewfield")
		_world().set("_orbit_yaw", 2.4)
		_world().call("apply_zone", "Pyrefen")
		_stage = 3
		_frames = 0
	elif _stage == 3 and _frames >= 15:
		_snap("isle_pyrefen")
		var ge2: Node = root.get_node("GameEngine")
		ge2.set("_month_accum", 10)
		_world().call("_poll_engine")
		_world().set("_orbit_yaw", 4.2)
		_stage = 4
		_frames = 0
	elif _stage == 4 and _frames >= 15:
		_snap("isle_winter")
		_world().call("play_tribulation", "Radiant", 6)
		_stage = 5
		_frames = 0
	elif _stage == 5 and _frames >= 50:
		_snap("isle_tribulation")
		_world().call("apply_zone", "Dewfield")
		_stage = 6
		_frames = 0
	elif _stage == 6 and _frames >= 15:
		var row: Node = _world().get_node("BeastGrounds")
		(_world().get_node("Cultivator") as Node3D).global_position = (row.get_child(0) as Node3D).global_position
		Input.action_press("world_interact")
		_world().call("_poll_avatar", 0.25)
		Input.action_release("world_interact")
		_world().call("take_den_outcome")
		_world().call("avatar_fight", "beast_pebbleback")
		_world().call("avatar_strike", 1000000)
		_stage = 7
		_frames = 0
	elif _stage == 7 and _frames >= 10:
		_snap("arena_fight")
		print("P23-SHOTS done")
		quit(0)
		return true
	elif _frames > 3600:
		printerr("P23-SHOTS FAIL: timeout")
		quit(1)
		return true
	return false
