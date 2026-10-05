extends SceneTree
## QA Round 2 long-run soak. Drives the game the way a session does — panel
## open on the tallest tab, focus cycling cultivate/train/hunt, tab switching,
## and periodic save/reload — while sampling frame time, node count and
## memory. The suspected Round 2 regression risk is UI rebuild cost (every
## realm/tick refresh rebuilds labels), so refresh pressure is the point.
## Run WITHOUT --headless: <engine> --path <project> -s res://tools/qa_r2_soak.gd

const RUN_SECONDS: float = 240.0
const SAMPLE_EVERY: int = 60

var _elapsed: float = 0.0
var _frames: int = 0
var _main: Node = null
var _tabs: TabContainer = null
var _samples: int = 0
var _ft_sum: float = 0.0
var _ft_max: float = 0.0
var _ft_worst_frame: int = 0
var _obj_start: int = 0
var _obj_end: int = 0
var _mem_start: float = 0.0
var _mem_end: float = 0.0
var _saves: int = 0
var _focuses: Array = ["cultivate", "train", "hunt"]
var _errors: Array = []
var _done: bool = false
var _mode: String = "all"

func _initialize() -> void:
	var ua: PackedStringArray = OS.get_cmdline_user_args()
	if ua.size() > 0:
		_mode = ua[0]
	print("QA2-SOAK start seconds=", RUN_SECONDS, " mode=", _mode)
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	if _done:
		return true
	if _main == null:
		return false
	_elapsed += delta
	_frames += 1
	if _frames == 20:
		_setup()
		_obj_start = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		_mem_start = Performance.get_monitor(Performance.MEMORY_STATIC)
		return false
	if _frames < 20:
		return false
	if _frames % SAMPLE_EVERY == 0:
		_sample(delta)
	if _frames % 7 == 0 and _mode in ["all", "ui"]:
		_cycle_focus()
	if _frames % 23 == 0 and _mode in ["all", "ui"]:
		_cycle_tab()
	if _frames % 600 == 0 and _mode in ["all", "save"]:
		_save_and_reload()
	if _elapsed >= RUN_SECONDS:
		_finish()
	return false

func _setup() -> void:
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 12)
	ge.set("qi", 9.87e12)
	ge.set("karma", 12345)
	_main.call("_refresh_all")
	(_main.get_node("UI/Root/SidePanel") as PanelContainer).visible = true
	(_main.get_node("UI/Root/RailPanel") as PanelContainer).visible = true
	_tabs = _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	_tabs.current_tab = 5
	_main.call("_highlight_rail")

func _sample(delta: float) -> void:
	var ft: float = delta * 1000.0
	_samples += 1
	_ft_sum += ft
	if ft > _ft_max:
		_ft_max = ft
		_ft_worst_frame = _frames

func _cycle_focus() -> void:
	var ge: Node = root.get_node("GameEngine")
	_main.call("_on_focus", str(_focuses[_frames / 7 % _focuses.size()]))

func _cycle_tab() -> void:
	if _tabs == null:
		return
	_tabs.current_tab = (_tabs.current_tab + 1) % _tabs.get_tab_count()

func _save_and_reload() -> void:
	var sm: Node = root.get_node_or_null("SaveManager")
	if sm == null:
		_errors.append("no SaveManager autoload")
		return
	sm.call("save_game")
	_saves += 1
	if _saves % 3 == 0:
		var loaded: Dictionary = sm.call("load_game")
		_main.call("_refresh_all")
		if loaded.is_empty():
			_errors.append("empty load at save " + str(_saves))

func _finish() -> void:
	_done = true
	_obj_end = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_mem_end = Performance.get_monitor(Performance.MEMORY_STATIC)
	var avg: float = _ft_sum / maxf(float(_samples), 1.0)
	var fps: float = 1000.0 / maxf(avg, 0.001)
	print("QA2-SOAK frames=", _frames, " avg_ms=", snappedf(avg, 0.01), " fps=", snappedf(fps, 0.1), " worst_ms=", snappedf(_ft_max, 0.01), " at_frame=", _ft_worst_frame)
	print("QA2-SOAK objects ", _obj_start, " -> ", _obj_end, " delta=", _obj_end - _obj_start, " static_mb ", snappedf(_mem_start / 1048576.0, 0.1), " -> ", snappedf(_mem_end / 1048576.0, 0.1))
	var ge: Node = root.get_node("GameEngine")
	print("QA2-SOAK ticks=", ge.get("tick_count"), " realm=", ge.get("realm_index"), " focus=", str(ge.get("player_focus")), " saves=", _saves)
	print("QA2-SOAK verdict frames_ok=", _frames >= 5000, " objects_ok=", (_obj_end - _obj_start) < 500, " ms_ok=", avg < 40.0)
	if not _errors.is_empty():
		print("QA2-SOAK errors=", _errors)
	quit(0)