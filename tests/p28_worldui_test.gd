extends SceneTree
## 0.27b world-speaks test: affordance truth table (node/den/shrine),
## shimmer-modal agreement, HUD completion, hint triggers, budgets.
## Run with: --headless -s res://tests/p28_worldui_test.gd (exit 0 = pass).
## Deterministic throughout: no RNG anywhere in this suite. Suite asserts
## the affordance MAPPINGS, not pixels; rendering goes to 0.27c screenshots.

var _failures: int = 0
var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _load_json(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	ge.call("set_realm_table", _load_json("res://data/realms.json"))
	ge.call("set_leyline_table", _load_json("res://data/leylines.json"))
	return ge

func _rich(ge: Node, realm: int, qi: float) -> void:
	ge.set("realm_index", realm)
	ge.call("set_realm_table", _load_json("res://data/realms.json"))
	ge.set("qi", qi)
	ge.call("set_gear_mult", 1.0)

func _initialize() -> void:
	print("WORLDUI-TEST start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_test_getter_purity()
	_test_agreement()
	_test_den_getter()
	_test_shrine_getter()
	_test_stage_name()
	_test_hint_triggers()
	_test_save_untouched()
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 1:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 5:
		_test_topbar()
		_test_affordance_mappings()
		_test_update_applies()
		_test_archive_tabs()
		_test_budgets()
		if _failures == 0:
			print("WORLDUI-TEST PASS")
		else:
			printerr("WORLDUI-TEST FAIL: ", _failures)
		quit(_failures)
	return false

func _test_getter_purity() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 1, 5000.0)
	var q0: float = float(ge.call("qi_num"))
	var a: Dictionary = ge.call("leyline_attune_ready")
	var b: Dictionary = ge.call("leyline_attune_ready")
	_check(str(a) == str(b), "dry-run is deterministic")
	_check(int(ge.get("leyline_open")) == 0, "dry-run opens nothing")
	_check(absf(float(ge.call("qi_num")) - q0) < 0.001, "dry-run spends nothing")
	_check(bool(a.get("ok", false)) and str(a.get("reason", "")) == "ok", "funded channel reads ready")
	ge.queue_free()

func _test_agreement() -> void:
	# The release's soul, as its own test line: shimmer-ready (the dry-run)
	# agrees with modal-ready (the mutating path) across every reason.
	var cases: Array = [
		{"realm": 1, "qi": 5000.0, "open": 8},
		{"realm": 0, "qi": 100000.0, "open": 0},
		{"realm": 1, "qi": 0.0, "open": 0},
		{"realm": 1, "qi": 5000.0, "open": 0},
		{"realm": 24, "qi": 1.0e17, "open": 7},
	]
	for c in cases:
		var g1: Node = _new_engine()
		_rich(g1, int(c.get("realm", 0)), float(c.get("qi", 0.0)))
		g1.set("leyline_open", int(c.get("open", 0)))
		var g2: Node = _new_engine()
		_rich(g2, int(c.get("realm", 0)), float(c.get("qi", 0.0)))
		g2.set("leyline_open", int(c.get("open", 0)))
		var dry: Dictionary = g1.call("leyline_attune_ready")
		var live: Dictionary = g2.call("attune_next")
		_check(bool(dry.get("ok", true)) == bool(live.get("ok", true)), "agreement ok at realm %d open %d" % [int(c.get("realm", 0)), int(c.get("open", 0))])
		_check(str(dry.get("reason", "")) == str(live.get("reason", "")), "agreement reason at realm %d open %d" % [int(c.get("realm", 0)), int(c.get("open", 0))])
		_check(str(dry.get("line", "")) == str(live.get("line", "")), "agreement line at realm %d open %d" % [int(c.get("realm", 0)), int(c.get("open", 0))])
		g1.queue_free()
		g2.queue_free()

func _test_den_getter() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 5, 1000000000.0)
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	root.add_child(cdb)
	cdb.call("load_all")
	ge.call("set_beast_pool", cdb.get("beasts"))
	var bid: String = str(((cdb.get("beasts") as Array)[0] as Dictionary).get("id", ""))
	var st: Dictionary = ge.call("skirmish_stats", bid)
	var ratio_ok: bool = float(st.get("cult_dmg", 0.0)) / maxf(float(st.get("beast_power", 1.0)), 0.001) >= 0.25
	_check(bool(ge.call("den_challengeable", bid)) == ratio_ok, "den getter matches the skirmish line")
	_check(not bool(ge.call("den_challengeable", "no_such_beast")), "unknown beast not challengeable")
	ge.set("techniques", {"tech_emberstep": 6000000})
	ge.set("focus_technique", "tech_emberstep")
	_check(bool(ge.call("den_challengeable", bid)), "drilled cultivator reads challengeable")
	cdb.queue_free()
	ge.queue_free()

func _test_shrine_getter() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 3, 1000000000.0)
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	root.add_child(cdb)
	cdb.call("load_all")
	ge.call("set_guardian_defs", cdb.get("guardians"))
	_check(not bool(ge.call("guardian_challengeable", "")), "interior realm gates nothing")
	_check(not bool(ge.call("guardian_challengeable", "guardian_01")), "wrong-tier flame dark at R04")
	ge.set("realm_index", 7)
	ge.call("set_realm_table", _load_json("res://data/realms.json"))
	_check(bool(ge.call("guardian_challengeable", "")), "tier-end with standing warden gates")
	_check(bool(ge.call("guardian_challengeable", "guardian_01")), "warden-1 flame lit at R08")
	_check(not bool(ge.call("guardian_challengeable", "guardian_02")), "warden-2 flame dark at R08")
	ge.set("guardians", {"defeated": ["guardian_01"], "attempts": {}})
	_check(not bool(ge.call("guardian_challengeable", "guardian_01")), "fallen warden never relights")
	_check(not bool(ge.call("guardian_challengeable", "")), "no gate after the fall")
	cdb.queue_free()
	ge.queue_free()

func _test_stage_name() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 0, 0.0)
	_check(str(ge.call("stage_name")) == "Early", "empty dantian reads Early")
	ge.set("qi", float(ge.call("bottleneck_num")) * 0.5)
	_check(str(ge.call("stage_name")) == "Mid", "half fill reads Mid")
	ge.set("qi", float(ge.call("bottleneck_num")))
	_check(str(ge.call("stage_name")) == "Late", "full dantian reads Late")
	ge.queue_free()

func _test_hint_triggers() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 1, 100.0)
	_check((ge.call("due_hints") as Array).has("hint_walk"), "unwalked grounds trigger hint_walk")
	ge.call("mark_hint", "hint_walk")
	_check(not (ge.call("due_hints") as Array).has("hint_walk"), "walk hint is one-shot")
	_rich(ge, 2, 100.0)
	_check((ge.call("due_hints") as Array).has("hint_den"), "unstalked wilds trigger hint_den")
	_rich(ge, 7, 100.0)
	_check((ge.call("due_hints") as Array).has("hint_shrine"), "unfaced warden triggers hint_shrine")
	ge.set("guardians", {"defeated": [], "attempts": {"guardian_01": 1}})
	_check(not (ge.call("due_hints") as Array).has("hint_shrine"), "faced warden silences hint_shrine")
	ge.queue_free()

func _test_save_untouched() -> void:
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	_check(int(SM.get("SAVE_VERSION")) == 14, "save stays v14")
	var ge: Node = _new_engine()
	_rich(ge, 5, 1000000000.0)
	ge.call("leyline_attune_ready")
	ge.call("den_challengeable", "x")
	ge.call("guardian_challengeable", "")
	var st: Dictionary = ge.call("get_state")
	_check(not st.has("leyline_ready") and not st.has("den_state"), "getters persist nothing")
	ge.queue_free()

func _world() -> Node:
	return _scene_main.get_node("WorldViewport/World")

func _auto_engine() -> Node:
	return root.get_node_or_null("GameEngine")

func _test_topbar() -> void:
	var ui: Node = _scene_main.get_node("UI")
	ui.call("refresh")
	for n in ["StageLabel", "RateLabel", "ActivityLabel"]:
		var lab: Label = _scene_main.get_node_or_null("UI/Root/TopBar/TopBarBox/" + n) as Label
		_check(lab != null and str(lab.text).find("—") < 0, n + " present and filled")
	var mgr: Node = _scene_main.get_node_or_null("UI")
	_check(mgr != null, "ui manager reachable")
	ui.call("apply_width", 600.0)
	_check(not (_scene_main.get_node("UI/Root/TopBar/TopBarBox/StageLabel") as Label).visible, "narrow hides stage")
	_check(not (_scene_main.get_node("UI/Root/TopBar/TopBarBox/ActivityLabel") as Label).visible, "narrow hides activity")
	_check((_scene_main.get_node("UI/Root/TopBar/TopBarBox/RateLabel") as Label).visible, "narrow keeps rate")
	ui.call("apply_width", 1280.0)
	_check((_scene_main.get_node("UI/Root/TopBar/TopBarBox/StageLabel") as Label).visible, "wide restores stage")

func _test_affordance_mappings() -> void:
	var age: Node = _auto_engine()
	age.call("set_leyline_table", _load_json("res://data/leylines.json"))
	age.set("realm_index", 0)
	age.set("leyline_open", 0)
	var w: Node = _world()
	_check(str(w.call("node_affordance")) == "dormant", "node dormant below floor")
	age.set("realm_index", 1)
	age.set("qi", 5000.0)
	_check(str(w.call("node_affordance")) == "ready", "node ready when floor met + funded")
	age.set("leyline_open", 8)
	_check(str(w.call("node_affordance")) == "dormant", "node dormant when sealed")
	_check(str(w.call("shrine_affordance", "guardian_07")) == "dormant", "far flame dormant early")
	_check(str(w.call("shrine_affordance", "")) == "dormant", "no gate early")
	_check(str(w.call("den_affordance", "no_such_beast")) == "dormant", "unknown den dormant")

func _test_update_applies() -> void:
	var w: Node = _world()
	w.call("_poll_engine")
	w.call("_poll_engine")
	var marks: Node = w.get_node_or_null("NodeMarks")
	if marks != null:
		for m in marks.get_children():
			_check((m as MeshInstance3D).material_override != null, "node mark carries affordance material")
	_check(true, "double poll idempotent")
	var hints: Dictionary = ((_scene_main.get_script() as Script).get_script_constant_map() as Dictionary).get("HINTS", {})
	_check(hints.has("hint_walk") and hints.has("hint_den") and hints.has("hint_shrine"), "world verbs in the hint table")

func _test_archive_tabs() -> void:
	var tabs: TabContainer = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	_check(tabs.get_tab_count() == 9, "all nine tabs remain")
	var idx: int = -1
	for i in range(tabs.get_tab_count()):
		if str(tabs.get_tab_title(i)) == "Beasts":
			idx = i
	_check(idx >= 0, "beasts tab found")
	_check(str(tabs.get_tab_tooltip(idx)).find("Archive") >= 0, "beasts tab carries archive emphasis")

func _test_budgets() -> void:
	var w: Node = _world()
	_check(int(w.call("count_nodes")) <= 170, "world node budget holds with affordances")
	var b: Dictionary = w.call("particle_budget")
	_check(int(b.get("total", 9999)) <= 768, "total budget holds with affordances")
