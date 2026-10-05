extends SceneTree
## QA Round 2: extreme-resolution layout sweep. Round 1 found three
## layout bugs (slider width, list height, tab well) so this drives the
## window through tiny / standard / ultrawide and screenshots each, with
## the settings panel open (densest layout) in both skins.
## Run WITHOUT --headless: <engine> --path <project> -s res://tools/qa_r2_res.gd

var _frames: int = 0
var _stage: int = 0
var _main: Node = null
var _sizes: Array = [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(3840, 2160)]
var _i: int = 0

func _initialize() -> void:
	print("QA2-RES start")
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
	elif _stage == 1 and _frames >= 20:
		# Densest panel: settings, panel + rail open, mid-game numbers.
		var ge: Node = root.get_node("GameEngine")
		ge.set("realm_index", 12)
		ge.set("qi", 9.87e12)
		ge.set("karma", 12345)
		_main.call("_refresh_all")
		(_main.get_node("UI/Root/SidePanel") as PanelContainer).visible = true
		(_main.get_node("UI/Root/RailPanel") as PanelContainer).visible = true
		var tabs := _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
		tabs.current_tab = clampi(5, 0, tabs.get_tab_count() - 1)
		_main.call("_highlight_rail")
		_stage = 2
		_frames = 0
	elif _stage >= 2:
		var size: Vector2i = _sizes[_i]
		if _frames == 1:
			root.size = size
			print("QA2-RES size=", size)
		elif _frames == 40:
			# Overflow probe: does any control spill outside the window?
			_report(size)
			var img: Image = root.get_texture().get_image()
			img.save_png("user://qa2_res_%dx%d_%s.png" % [size.x, size.y, "ink" if _i % 2 == 0 else "parch"])
			print("QA2-RES snap err=", img.save_png("user://qa2_res_%dx%d.png" % [size.x, size.y]))
		elif _frames >= 70:
			_i += 1
			if _i >= _sizes.size():
				print("QA2-RES done")
				quit(0)
				return true
			if _i % 2 == 1:
				_main.get_node("UI").call("set_skin", "parchment")
			_frames = 0
	return false

func _report(size: Vector2i) -> void:
	## Anything extending past the canvas edge is a real clipping bug.
	## Measured against get_visible_rect(), NOT window pixels: stretch is
	## canvas_items+expand, so canvas size != window size (an 800x600
	## window yields a 1280x960 canvas). ScrollContainer descendants are
	## legitimately scrolled out of view, so they are excluded.
	var canvas: Vector2 = root.get_visible_rect().size
	var bad: Array = []
	for n in _walk(_main):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		if _in_scroll(n):
			continue
		var g := c.get_global_rect()
		if g.position.x < -1.0 or g.position.y < -1.0 or g.end.x > canvas.x + 1.0 or g.end.y > canvas.y + 1.0:
			bad.append("%s@%s+%s" % [str(c.name), str(g.position.round()), str(g.size.round())])
	if bad.is_empty():
		print("QA2-RES clip none win=", size, " canvas=", canvas)
	else:
		print("QA2-RES clip=", bad.size(), " win=", size, " canvas=", canvas, " ", bad.slice(0, 8))
	_panel_metrics(size, canvas)

func _panel_metrics(size: Vector2i, canvas: Vector2) -> void:
	## The side panel must stay inside the canvas and must scroll, not clip.
	var side := _main.get_node("UI/Root/SidePanel") as Control
	var scroll := _main.get_node("UI/Root/SidePanel/PanelScroll") as ScrollContainer
	var tabs := _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	var bar := scroll.get_v_scroll_bar()
	var tab := tabs.get_tab_control(tabs.current_tab)
	var fits: bool = side.size.y <= canvas.y + 1.0
	var scrollable: bool = bar.max_value > bar.page
	print("QA2-RES panel win=", size, " side=", side.size.round(), " viewport=", scroll.size.round(), " tab_min=", tab.get_combined_minimum_size().round(), " bar=", bar.max_value, "/", bar.page, " fits=", fits, " scrollable=", scrollable)

func _in_scroll(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != _main:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out