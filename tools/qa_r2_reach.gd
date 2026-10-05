extends SceneTree
## QA Round 2: reachability proof. Any visible Control whose rect falls
## outside the canvas cannot be seen or clicked. Walks every tab, one
## per frame so layout settles before rects are read.

var _frames: int = 0
var _main: Node = null
var _grand_bad: int = 0

func _initialize() -> void:
	print("QA2-REACH start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(_main)
		return false
	if _frames == 25:
		var ge: Node = root.get_node("GameEngine")
		ge.set("realm_index", 12)
		ge.set("qi", 9.87e12)
		_main.call("_refresh_all")
		(_main.get_node("UI/Root/SidePanel") as PanelContainer).visible = true
		return false
	if _frames <= 26:
		return false
	var tabs := _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	var idx: int = _frames - 27
	if idx >= tabs.get_tab_count():
		print("QA2-REACH TOTAL off_screen=", _grand_bad, " canvas=", root.get_visible_rect().size)
		print("QA2-REACH done")
		quit(0)
		return true
	tabs.current_tab = idx
	if idx > 0:
		_scan_tabs(idx - 1)
	return false

func _scan_tabs(i: int) -> void:
	var canvas: Vector2 = root.get_visible_rect().size
	var tabs := _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	var sp := _main.get_node("UI/Root/SidePanel") as Control
	var bad: Array = []
	var shown: Array = []
	_walk(_main, canvas, bad, shown)
	_grand_bad += bad.size()
	print("QA2-REACH tab=", tabs.get_tab_title(i), " panel=", sp.size, " controls=", shown.size(), " off_screen=", bad.size(), " ", bad.slice(0, 6))

func _walk(n: Node, canvas: Vector2, bad: Array, shown: Array) -> void:
	for c in n.get_children():
		if c is Control:
			var ctl := c as Control
			if ctl.is_visible_in_tree():
				shown.append(ctl)
				var g := ctl.get_global_rect()
				if g.position.y < -1.0 or g.position.x < -1.0 or g.end.x > canvas.x + 1.0 or g.end.y > canvas.y + 1.0:
					bad.append("%s[y %d..%d]" % [str(ctl.name), int(g.position.y), int(g.end.y)])
		_walk(c, canvas, bad, shown)