extends SceneTree
## P17 UI overhaul test: theme, fonts, components (extended per P17 step).
## Run: --headless -s res://tests/p17_test.gd (exit 0 = pass).

var _failures: int = 0

const THEME_BUILDER: GDScript = preload("res://scripts/UITheme.gd")
const UICOMP: GDScript = preload("res://scripts/UIComponents.gd")

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _font_covers(path: String, text: String) -> Array:
	## Returns [covered: bool, missing: Array of chars]. Headless-safe.
	var missing: Array = []
	var f := FontFile.new()
	f.load_dynamic_font(path)
	var ts: TextServer = TextServerManager.get_primary_interface()
	var rids: Array = f.get_rids()
	if rids.is_empty():
		return [false, ["<no rids>"]]
	for i in range(text.length()):
		var ch: int = text.unicode_at(i)
		var ok: bool = false
		for r in rids:
			if ts.font_has_char(r, ch):
				ok = true
				break
		if not ok:
			missing.append(text.substr(i, 1))
	return [missing.is_empty(), missing]

var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null
var _anim_t0: int = 0

func _initialize() -> void:
	print("P17-TEST start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _ui() -> Node:
	return _scene_main.get_node("UI")

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		_test_theme_builds()
		_test_body_coverage()
		_test_display_coverage()
		_test_stat_row()
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 2:
		_test_scene_integrity()
		_test_title_fresh()
		_test_topbar()
		# Freeze the sim AFTER live-state asserts: wall waits below must not
		# move game state (asserting running first would self-defeat).
		root.get_node("GameEngine").set("running", false)
		_test_toast_start()
		_test_step4()
		_test_step5_panels()
		_test_prestige_ui()
		_test_rail()
		_anim_setup()
		_stage = 2
		_frames = 0
		_anim_t0 = Time.get_ticks_msec()
	elif _stage == 2 and _frames >= 1:
		if Time.get_ticks_msec() - _anim_t0 < 5200:
			if _frames > 3600:
				printerr("P17-TEST FAIL: wall wait timeout")
				quit(1)
				return true
			return false
		_test_toast_settle()
		_test_filter()
		_test_animated_qi()
		if _failures == 0:
			print("P17-TEST PASS")
		else:
			printerr("P17-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P17-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_scene_integrity() -> void:
	# Every control Main wires (or tests press) must resolve. Orphaned scene
	# nodes fail silently at load, so this census is the tripwire.
	var paths: Array = [
		"UI/Root/TopBar/TopBarBox/RealmLabel", "UI/Root/TopBar/TopBarBox/AgeLabel",
		"UI/Root/TopBar/TopBarBox/QiBar", "UI/Root/TopBar/TopBarBox/QiLabel",
		"UI/Root/TopBar/TopBarBox/MindLabel", "UI/Root/TopBar/TopBarBox/SeasonLabel",
		"UI/Root/TopBar/TopBarBox/Time1", "UI/Root/TopBar/TopBarBox/Time10",
		"UI/Root/TopBar/TopBarBox/Time100", "UI/Root/TopBar/TopBarBox/Time1000",
		"UI/Root/TopBar/TopBarBox/PauseBtn", "UI/Root/TopBar/TopBarBox/MuteBtn",
		"UI/Root/TopBar/TopBarBox/BulkBtn",
		"UI/Root/RailPanel/Rail/RailSect", "UI/Root/RailPanel/Rail/RailAlchemy",
		"UI/Root/RailPanel/Rail/RailArts", "UI/Root/RailPanel/Rail/RailSoul",
		"UI/Root/RailPanel/Rail/RailSamsara", "UI/Root/RailPanel/Rail/RailBeasts",
		"UI/Root/RailPanel/Rail/RailDeeds", "UI/Root/RailPanel/Rail/RailRecords",
		"UI/Root/RailPanel/Rail/RailSettings",
		"UI/Root/BottomDock/DockRows/DockRow1/FocusCultivate",
		"UI/Root/BottomDock/DockRows/DockRow1/FocusTrain",
		"UI/Root/BottomDock/DockRows/DockRow1/FocusHunt",
		"UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn",
		"UI/Root/BottomDock/DockRows/DockRow1/StalkBtn",
		"UI/Root/BottomDock/DockRows/DockRow1/WanderBtn",
		"UI/Root/BottomDock/DockRows/DockRow2/RecruitBtn",
		"UI/Root/BottomDock/DockRows/DockRow2/GangGather",
		"UI/Root/BottomDock/DockRows/DockRow2/GangHunt",
		"UI/Root/BottomDock/DockRows/DockRow2/GangIdle",
		"UI/Root/ToastArea",
		"UI/Root/ChroniclePanel/ChronicleBox/FilterBox/FilterAllBtn",
		"UI/Root/ChroniclePanel/ChronicleBox/FilterBox/FilterInfoBtn",
		"UI/Root/ChroniclePanel/ChronicleBox/FilterBox/FilterWarnBtn",
		"UI/Root/ChroniclePanel/ChronicleBox/FilterBox/CollapseBtn",
		"UI/Root/ChroniclePanel/ChronicleBox/LogText2",
		"UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleNewBtn",
		"UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleContinueBtn",
		"UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/VersionLabel",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/SectLabel",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/DiscipleBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Alchemy/PillBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/AttuneBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechMistwalk",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/TechStonebell",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/SoulBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/GearBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/TalentBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/EndLifeBtn",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/DaoMarksLabel",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/AscendBtn",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/DaoTreeBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/BestiaryBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Deeds/AchieveHeader",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Deeds/AchieveScroll/AchieveBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Records/RecordsLabel",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SeclusionBtn",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/VolumeSlider",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/MusicSlider",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/AdvancedLabel",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/InputOptionsBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/VideoOptionsBox",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/GlowCheck",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/ExportBtn",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/ImportBtn",
		"UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SaveDialog",
		"UI/Root/ChroniclePanel/ChronicleBox/LogText2",
		"UI/HelpOverlay/HelpCenter/HelpCard/HelpBox",
		"UI/Root/Banner", "WorldViewport/World", "WorldDisplay",
	]
	var missing: Array = []
	for p in paths:
		if _scene_main.get_node_or_null(str(p)) == null:
			missing.append(p)
	_check(missing.is_empty(), "scene census resolves (missing: %s)" % str(missing))

func _test_title_fresh() -> void:
	# Fresh boot (no save): no title, sim running.
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	_check(not bool(_scene_main.get_node("UI/TitleOverlay").visible), "fresh boot skips title")
	_check(bool(root.get_node("GameEngine").get("running")), "fresh boot runs")
	(_scene_main.get_node("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleNewBtn") as BaseButton).emit_signal("pressed")
	_check(bool(root.get_node("GameEngine").get("running")), "new journey runs")
	_check(str(_scene_main.get_node("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/VersionLabel").text).begins_with("v"), "version labeled")

func _test_topbar() -> void:
	var ge: Node = root.get_node("GameEngine")
	# Pin clock + calendar: live boot ticks advance both before this read.
	ge.set("realm_index", 0)
	ge.set("age_years", 18)
	ge.set("_month_accum", 0)
	_ui().call("refresh")
	_check("Dustroot" in str(_scene_main.get_node("UI/Root/TopBar/TopBarBox/RealmLabel").text), "top bar names realm")
	# Table-wired lifespan is tier-1 110, not base 60 (P12-1 scaling).
	_check("Age 18/110" in str(_scene_main.get_node("UI/Root/TopBar/TopBarBox/AgeLabel").text), "top bar ages")
	_check("Serene" in str(_scene_main.get_node("UI/Root/TopBar/TopBarBox/MindLabel").text), "top bar minds")
	_check("Spring" in str(_scene_main.get_node("UI/Root/TopBar/TopBarBox/SeasonLabel").text), "top bar seasons")

func _test_step4() -> void:
	var ui: Node = _ui()
	# Floating numbers pool, cap, and show.
	ui.call("spawn_float", Vector2(640, 360), "f-probe", Color.WHITE)
	_check(_scene_main.get_node("UI/Root/FloatLayer").get_child_count() >= 1, "float spawns")
	for i in range(14):
		ui.call("spawn_float", Vector2(640, 360), "f%d" % i, Color.WHITE)
	_check(_scene_main.get_node("UI/Root/FloatLayer").get_child_count() == 12, "float pool caps")
	# Shine overlay toggles with readiness on the Attempt button.
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	_scene_main.call("_refresh_breakthrough_btn")
	var abtn: Button = _scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn") as Button
	_check(abtn.get_node_or_null("ShineOverlay") != null, "shine overlay built")
	# Blur materials sit on both full-screen overlays (pixels verified live).
	_check((_scene_main.get_node("UI/TitleOverlay") as ColorRect).material != null, "title blur assigned")
	_check((_scene_main.get_node("UI/HelpOverlay") as ColorRect).material != null, "help blur assigned")
	# Input contract: panels STOP clicks, world display IGNOREs them.
	for p in ["UI/Root/TopBar", "UI/Root/BottomDock", "UI/Root/SidePanel", "UI/Root/ChroniclePanel", "UI/TitleOverlay", "UI/HelpOverlay"]:
		var c: Control = _scene_main.get_node(p) as Control
		_check(int(c.mouse_filter) == 0, "panel stops clicks")
	_check(int((_scene_main.get_node("WorldDisplay") as Control).mouse_filter) == 2, "world ignores clicks")
	# Panels toggle opens and closes.
	(_scene_main.get_node("UI/Root/TopBar/TopBarBox/PanelsBtn") as BaseButton).emit_signal("pressed")
	_check(bool(_scene_main.get_node("UI/Root/SidePanel").visible), "panels open")
	(_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/FocusTrain") as BaseButton).emit_signal("pressed")
	_check(str(root.get_node("GameEngine").get("player_focus")) == "train", "dock works with panel open")

func _test_step5_panels() -> void:
	# Panels open/close, tabs switch, Esc closes topmost. (An earlier stage
	# may leave the panel open, so start from a set state.)
	var panel: PanelContainer = _scene_main.get_node("UI/Root/SidePanel") as PanelContainer
	panel.visible = false
	(_scene_main.get_node("UI/Root/TopBar/TopBarBox/PanelsBtn") as BaseButton).emit_signal("pressed")
	_check(bool(panel.visible), "panels button opens")
	var tabs: TabContainer = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	_check(tabs.get_tab_count() == 9, "nine tabs staged")
	for i in [0, 4, 8]:
		tabs.current_tab = int(i)
		_check(tabs.get_current_tab_control() != null, "tab switches")
	_check(bool(_scene_main.call("handle_shortcut", KEY_ESCAPE)), "esc handled while open")
	_check(not bool(panel.visible), "esc closes panels")
	(_scene_main.get_node("UI/Root/TopBar/TopBarBox/PanelsBtn") as BaseButton).emit_signal("pressed")
	# Help overlay via F1; focus order present on dock controls.
	_check(bool(_scene_main.call("handle_shortcut", KEY_F1)), "F1 opens help")
	_check(bool(_scene_main.get_node("UI/HelpOverlay").visible), "help visible")
	_check(bool(_scene_main.call("handle_shortcut", KEY_ESCAPE)), "esc handled with help")
	_check(not bool(_scene_main.get_node("UI/HelpOverlay").visible), "esc closes help")
	for path in ["UI/Root/BottomDock/DockRows/DockRow1/FocusCultivate", "UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn", "UI/Root/TopBar/TopBarBox/PauseBtn"]:
		_check(int((_scene_main.get_node(path) as Control).focus_mode) == int(Control.FOCUS_ALL), "keyboard focusable")
	# Signal-driven UI: breakthrough pops a toast immediately.
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	(_scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn") as BaseButton).emit_signal("pressed")
	_check(_scene_main.get_node("UI/Root/ToastArea").get_child_count() >= 1, "breakthrough toasts")

func _test_prestige_ui() -> void:
	# P19b: Dao Marks ledger, forecast, two-press ascension, tree rows.
	var ge: Node = root.get_node("GameEngine")
	var f: FileAccess = FileAccess.open("res://data/prestige.json", FileAccess.READ)
	ge.call("set_prestige_defs", JSON.parse_string(f.get_as_text()))
	f.close()
	ge.set("qi_earned_total", 4000000.0)
	_scene_main.call("_refresh_prestige")
	var lab: Label = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/DaoMarksLabel") as Label
	_check("+24" in lab.text, "ledger forecasts gain")
	var abtn: Button = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/AscendBtn") as Button
	_check("+24" in abtn.text, "ascend button forecasts gain")
	abtn.emit_signal("pressed")
	var ui: Node = _scene_main.get_node("UI")
	var dlg: ConfirmationDialog = null
	for c in ui.get_children():
		if c is ConfirmationDialog and str((c as ConfirmationDialog).title) == "Leave This World":
			dlg = c
	_check(dlg != null, "ascend opens a confirm modal")
	_check("+24" in str(dlg.dialog_text), "modal names the gain")
	dlg.emit_signal("confirmed")
	_check(int(ge.get("dao_marks")) == 24, "confirm banks marks")
	_check(int(ge.get("realm_index")) == 0, "ascension restarts the world")
	_scene_main.call("_rebuild_dao")
	var box: Node = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/DaoTreeBox")
	_check(box.get_child_count() == 3, "three dao rows built from data")
	# P21: row buttons carry legacy Dao_* names (BuyBtn is renamed at build).
	var dao_btn: Button = null
	for r in box.get_children():
		for n in r.get_children():
			if n is Button:
				dao_btn = n
	_check(dao_btn != null and dao_btn.tooltip_text != "", "dao rows explain themselves")

func _test_rail() -> void:
	# P19c: headerless tabs driven by the left rail; rail follows panels.
	# P21: hard gates — locked rails refuse with the requirement named.
	var ge: Node = root.get_node("GameEngine")
	var tabs: TabContainer = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	_check(not bool(tabs.tabs_visible), "tab headers hidden behind rail")
	var rail: Node = _scene_main.get_node("UI/Root/RailPanel")
	_check(bool(rail.visible), "rail docks with panels")
	(_scene_main.get_node("UI/Root/RailPanel/Rail/RailArts") as BaseButton).emit_signal("pressed")
	_check(tabs.current_tab == 2, "rail switches to Arts")
	var sam_btn: Button = _scene_main.get_node("UI/Root/RailPanel/Rail/RailSamsara") as Button
	ge.set("total_rebirths", 0)
	_scene_main.call("_refresh_rail")
	_check(bool(sam_btn.disabled), "samsara locks before first rebirth")
	_check("rebirths" in sam_btn.tooltip_text, "locks name the requirement")
	sam_btn.emit_signal("pressed")
	_check(tabs.current_tab == 2, "locked rails refuse")
	ge.set("total_rebirths", 1)
	_scene_main.call("_refresh_rail")
	_check(not bool(sam_btn.disabled), "rebirth unlocks samsara")
	sam_btn.emit_signal("pressed")
	_check(tabs.current_tab == 4, "rail switches to Samsara")
	var arts_btn: Button = _scene_main.get_node("UI/Root/RailPanel/Rail/RailArts") as Button
	_check(sam_btn.modulate.r >= sam_btn.modulate.g, "active rail tab highlighted")
	_check(arts_btn.tooltip_text != "", "rail tabs explain themselves")
	_check(bool(_scene_main.call("handle_shortcut", KEY_ESCAPE)), "esc handled while open")
	_check(not bool(rail.visible), "esc closes rail with panels")

func _test_toast_start() -> void:
	_ui().call("toast", "t1")
	_ui().call("toast", "t2")
	_ui().call("toast", "t3")
	_ui().call("toast", "t4")
	_check(_scene_main.get_node("UI/Root/ToastArea").get_child_count() == 3, "toast queue caps at 3")

func _test_toast_settle() -> void:
	_check(_scene_main.get_node("UI/Root/ToastArea").get_child_count() == 0, "toasts expire")

func _test_filter() -> void:
	var ui: Node = _ui()
	ui.call("log_line", "filter-probe-info", "info")
	ui.call("log_line", "filter-probe-warn", "warn")
	ui.call("set_filter", "warn")
	# P13 lesson: RichTextLabel.text omits appended content; parsed text sees it.
	var t: String = str((_scene_main.get_node("UI/Root/ChroniclePanel/ChronicleBox/LogText2") as RichTextLabel).get_parsed_text())
	_check("filter-probe-warn" in t, "warn filter shows warns")
	_check(not ("filter-probe-info" in t), "warn filter hides info")
	ui.call("set_filter", "all")
	t = str((_scene_main.get_node("UI/Root/ChroniclePanel/ChronicleBox/LogText2") as RichTextLabel).get_parsed_text())
	_check("filter-probe-info" in t, "all filter restores")
	# P22: the ring cap alone does not bound the visible document — every
	# append_text() permanently retains RichTextLabel item objects (+496 per
	# 500 appends measured), so long sessions grew objects without bound.
	# log_line must rebuild from the ring past 2x the cap.
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in 600:
		ui.call("log_line", "bound-probe", "info")
	var grew: int = int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before
	_check(grew < 450, "chronicle document stays bounded (grew=" + str(grew) + ")")
	# P23c ring-reuse proof (Q27): a second full ring must recycle, not pile.
	var mid: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in 600:
		ui.call("log_line", "reuse-probe", "info")
	var grew2: int = int(Performance.get_monitor(Performance.OBJECT_COUNT)) - mid
	_check(abs(grew2) <= 5, "chronicle ring recycles (delta=" + str(grew2) + ")")

func _anim_setup() -> void:
	# Arms the bar tween before the wall wait so it settles inside it.
	var ge: Node = root.get_node("GameEngine")
	ge.set("qi", 60.0)
	ge.set("qi_bottleneck", 120.0)
	_ui().call("refresh")

func _test_animated_qi() -> void:
	var bar: ProgressBar = _scene_main.get_node("UI/Root/TopBar/TopBarBox/QiBar") as ProgressBar
	_check(absf(float(bar.value) - 50.0) <= 2.0, "qi bar animates to fill")

func _test_theme_builds() -> void:
	var th: Theme = THEME_BUILDER.build()
	_check(th != null, "theme builds")
	_check(th.default_font != null, "theme has default font")
	_check(th.default_font_size == 16, "theme body size 16")
	_check(th.has_stylebox("normal", "Button"), "theme styles buttons")
	_check(th.has_stylebox("panel", "PanelContainer"), "theme styles panels")
	_check(th.has_stylebox("fill", "ProgressBar"), "theme styles progress")
	_check(th.has_stylebox("tab_selected", "TabContainer"), "theme styles tabs")
	# P19c ink-prestige: brush-line cards, seal press, display dialog titles.
	_check((th.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).border_width_left == 1, "cards carry brush-line")
	_check(th.has_font("title_font", "Window"), "dialogs title in display face")
	# QA Round 1: tab content well themed (no default-grey fallback), and
	# parchment disabled text keeps contrast on tan.
	_check(th.has_stylebox("panel", "TabContainer"), "tab well themed")
	var par: Theme = THEME_BUILDER.build("parchment")
	var ink_dis: Color = th.get_color("font_disabled_color", "Button")
	var par_dis: Color = par.get_color("font_disabled_color", "Button")
	_check(ink_dis != par_dis, "disabled tone differs per skin")

func _test_body_coverage() -> void:
	# Every glyph the sim can emit through HUD text (ASCII printable + the
	# ink punctuation used in labels, logs, and hints).
	var probe: String = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~·—×»"
	var res: Array = _font_covers("res://fonts/Inter-Regular.ttf", probe)
	_check(bool(res[0]), "inter covers HUD glyphs (missing: %s)" % str(res[1]))

func _test_display_coverage() -> void:
	# Display face only ever sets short ASCII headers (spec rule).
	var probe: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,!%()-"
	var res: Array = _font_covers("res://fonts/MaShanZheng-Regular.ttf", probe)
	_check(bool(res[0]), "display covers header glyphs (missing: %s)" % str(res[1]))

func _test_stat_row() -> void:
	var row: HBoxContainer = UICOMP.stat_row("Qi", "1.24M")
	_check(row.get_node_or_null("StatName") != null, "stat row has name")
	_check(row.get_node_or_null("StatValue") != null, "stat row has value")
	_check(str((row.get_node("StatValue") as Label).text) == "1.24M", "stat value passes through")
	row.free()
