extends SceneTree
## Frame-time probe (NOT a suite): run WITHOUT --headless where a display
## exists, prints FPS over 300 frames + saves a screenshot, then quits.
## Headless it reports impossibility and exits 0 (budget test covers CI).
## Run: <engine> --path <project> -s res://tools/frame_probe.gd

var _frames: int = 0
var _scene_main: Node = null
var _fps_sum: float = 0.0
var _fps_n: int = 0

func _initialize() -> void:
	print("FRAME-PROBE start display=", DisplayServer.get_name())
	if DisplayServer.get_name() == "headless":
		print("FRAME-PROBE skipped: no display server")
		quit(0)
		return
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)

func _process(_delta: float) -> bool:
	if _scene_main == null:
		return false
	_frames += 1
	if _frames >= 60:
		_fps_sum += Engine.get_frames_per_second()
		_fps_n += 1
	if _frames == 300:
		var avg: float = _fps_sum / maxf(float(_fps_n), 1.0)
		print("FRAME-PROBE avg_fps=", snappedf(avg, 0.1), " over ", _fps_n, " frames")
		var img: Image = root.get_texture().get_image()
		var path: String = "user://frame_probe.png"
		var err: int = img.save_png(path)
		print("FRAME-PROBE screenshot=", path, " err=", err)
		quit(0)
	elif _frames > 3600:
		print("FRAME-PROBE timeout")
		quit(1)
	return false
