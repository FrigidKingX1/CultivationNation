extends SceneTree
## QA Round 2: prove the side-panel scroll fix is real — tab content is
## still present, and long tabs now scroll instead of overflowing.

var _frames: int = 0
var _main: Node = null
var _idx: int = 0

func _initialize() -> void:
	print("QA2-SCROLL start")
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
	if _frames == 27:
		print("QA2-SCROLL tab_count=", tabs.get_tab_count())
	if _idx >= tabs.get_tab_count():
		print("QA2-SCROLL done")
		quit(0)
		return true
	tabs.current_tab = _idx
	if _idx > 0:
		_verify(tabs, _idx - 1)
	_idx += 1
	_frames += 1
	return false

func _verify(tabs: TabContainer, i: int) -> void:
	var scroll := _main.get_node("UI/Root/SidePanel/PanelScroll") as ScrollContainer
	var tab: Control = tabs.get_tab_control(i)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	print("QA2-SCROLL tab=", tabs.get_tab_title(i), " content_h=", int(tab.get_combined_minimum_size().y), " scroll_max=", int(bar.max_value), " scroll_page=", int(bar.page), " scrollable=", bar.max_value > bar.page)
	# Confirm a known deep control still resolves by its original path.
	if tabs.get_tab_title(i) == "Beasts":
		var mapbox := _main.get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox")
		print("QA2-SCROLL mapbox children=", (mapbox.get_child_count() if mapbox != null else -1))
		var skin := _main.get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SkinBtn")
		print("QA2-SCROLL SkinBtn resolvable=", skin != null)
	if tabs.get_tab_title(i) == "Settings":
		var vid := _main.get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/VideoOptionsBox")
		print("QA2-SCROLL VideoOptionsBox children=", (vid.get_child_count() if vid != null else -1))