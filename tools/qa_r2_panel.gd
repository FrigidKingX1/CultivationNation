extends SceneTree
## QA Round 2: side-panel overflow probe. SidePanel is anchored to the
## window, but Godot clamps a Control up to its content minimum size. If
## a tab's content min height exceeds the panel, the panel grows past the
## window bottom and the lower content is unreachable (no scroll parent).
## Run WITHOUT --headless at 1280x720.

var _frames: int = 0
var _main: Node = null

func _initialize() -> void:
	print("QA2-PANEL start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(_main)
	elif _frames == 25:
		var ge: Node = root.get_node("GameEngine")
		ge.set("realm_index", 12)
		ge.set("qi", 9.87e12)
		_main.call("_refresh_map")
		(_main.get_node("UI/Root/SidePanel") as PanelContainer).visible = true
		(_main.get_node("UI/Root/RailPanel") as PanelContainer).visible = true
		var tabs := _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
		tabs.current_tab = clampi(2, 0, tabs.get_tab_count() - 1)
		_main.call("_highlight_rail")
	elif _frames == 60:
		var sp := _main.get_node("UI/Root/SidePanel") as Control
		var tabs := _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
		print("QA2-PANEL canvas=", root.get_visible_rect().size)
		print("QA2-PANEL sidepanel rect=", sp.get_global_rect(), " min=", sp.get_combined_minimum_size())
		print("QA2-PANEL tab_count=", tabs.get_tab_count(), " current=", tabs.current_tab, " name=", tabs.get_tab_title(tabs.current_tab))
		for i in tabs.get_tab_count():
			var t: Control = tabs.get_tab_control(i)
			print("QA2-PANEL tab ", i, " ", tabs.get_tab_title(i), " min_h=", (t as Control).get_combined_minimum_size().y)
		# Is any map node reachable?
		var mapbox := _main.get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox")
		if mapbox != null:
			print("QA2-PANEL mapbox rect=", (mapbox as Control).get_global_rect(), " children=", mapbox.get_child_count())
			var last := mapbox.get_child(mapbox.get_child_count() - 1) as Control
			print("QA2-PANEL last map node=", last.get_global_rect(), " ancestors=", _chain(last))
		var img: Image = root.get_texture().get_image()
		img.save_png("user://qa2_panel_beasts.png")
	elif _frames == 70:
		var tabs2 := _main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
		for i in tabs2.get_tab_count():
			if tabs2.get_tab_title(i) == "Settings":
				tabs2.current_tab = i
		_main.call("_highlight_rail")
	elif _frames == 80:
		var sp2 := _main.get_node("UI/Root/SidePanel") as Control
		print("QA2-PANEL settings sidepanel rect=", sp2.get_global_rect())
		for nm in ["VolumeSlider", "MusicSlider", "SkinBtn", "SeclusionBtn", "AdvancedLabel"]:
			var c := _main.get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/" + str(nm)) as Control
			if c != null:
				var g := c.get_global_rect()
				print("QA2-PANEL settings ", nm, " y=", g.position.y, "->", g.end.y, " reachable=", g.end.y <= 720.0)
		var img2: Image = root.get_texture().get_image()
		img2.save_png("user://qa2_panel_settings.png")
	elif _frames >= 100:
		print("QA2-PANEL done")
		quit(0)
		return true
	return false

func _chain(n: Node) -> String:
	var out: Array = []
	var p := n.get_parent()
	while p != null:
		out.append("%s(%s)" % [str(p.name), p.get_class()])
		p = p.get_parent()
	return " < ".join(out)