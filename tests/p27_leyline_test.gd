extends SceneTree
## 0.26b ley-line attunement test: generated table, sequential matrix,
## warded refusals, factor math, resets, load-vs-presence, offline
## inclusion, orthogonality, v14 migration, node modal flow.
## Run with: --headless -s res://tests/p27_leyline_test.gd (exit 0 = pass).
## Deterministic throughout: no RNG anywhere in this suite.

var _failures: int = 0
var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

const BN: GDScript = preload("res://scripts/BigNumber.gd")

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

func _initialize() -> void:
	print("LEYLINE-TEST start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_test_table()
	_test_contentdb()
	_test_matrix()
	_test_factor_math()
	_test_resets()
	_test_load()
	_test_offline_inclusion()
	_test_orthogonality()
	_test_migration()
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
		_test_modal_flow()
		_test_budgets()
		if _failures == 0:
			print("LEYLINE-TEST PASS")
		else:
			printerr("LEYLINE-TEST FAIL: ", _failures)
		quit(_failures)
	return false

func _test_table() -> void:
	var t: Array = _load_json("res://data/leylines.json")
	_check(t.size() == 8, "exactly 8 channels")
	var want_floors: Array = [1, 4, 7, 11, 15, 19, 22, 24]
	var prev: float = 0.0
	var realms: Array = _load_json("res://data/realms.json")
	for i in range(t.size()):
		var c: Dictionary = t[i]
		_check(str(c.get("id", "")) == "leyline_%02d" % (i + 1), "channel %d id in immutable order" % (i + 1))
		_check(int(c.get("floor", -1)) == int(want_floors[i]), "channel %d floor agent-selected" % (i + 1))
		_check(str(c.get("name", "")) != "", "channel %d named" % (i + 1))
		var cost: float = float(c.get("cost", 0.0))
		_check(cost > 0.0 and cost > prev, "channel %d cost positive + monotonic" % (i + 1))
		prev = cost
		if i == 0 or i == 4:
			_check(str(c.get("floor_realm", "")) == str((realms[int(c.get("floor", 0))] as Dictionary).get("name", "")), "channel %d floor name resolves" % (i + 1))

func _test_contentdb() -> void:
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	root.add_child(cdb)
	_check(bool(cdb.call("load_all")), "content loads with leylines")
	_check((cdb.get("leylines") as Array).size() == 8, "contentdb holds 8 channels")
	_check(bool(cdb.call("validate")), "contentdb validates with leylines")
	cdb.queue_free()

func _test_matrix() -> void:
	var ge: Node = _new_engine()
	_check(int(ge.get("leyline_open")) == 0, "channels start sealed")
	_check(str((ge.call("leyline_next") as Dictionary).get("id", "")) == "leyline_01", "next is channel one")
	_check(absf(float(ge.call("leyline_mult")) - 1.0) < 0.000000001, "sealed factor is x1.0")
	_rich(ge, 0, 100000.0)
	var r1: Dictionary = ge.call("attune_next")
	_check(not bool(r1.get("ok", true)) and str(r1.get("reason", "")) == "floor", "below-floor attune refused")
	_check(str(r1.get("line", "")).find("realm 2") >= 0 and str(r1.get("line", "")).find("now 1") >= 0, "floor refusal names the gap")
	_rich(ge, 1, 0.0)
	var r2: Dictionary = ge.call("attune_next")
	_check(not bool(r2.get("ok", true)) and str(r2.get("reason", "")) == "qi", "broke attune refused")
	_check(str(r2.get("line", "")).find("2000") >= 0, "qi refusal names the cost")
	_rich(ge, 1, 5000.0)
	var r3: Dictionary = ge.call("attune_next")
	_check(bool(r3.get("ok", false)) and int(ge.get("leyline_open")) == 1, "funded attune opens channel one")
	_check(absf(float(ge.call("qi_num")) - 3000.0) < 0.001, "attune deducts exactly 2000 qi")
	_check(str((ge.call("leyline_next") as Dictionary).get("id", "")) == "leyline_02", "next advances to channel two")
	_check(str(r3.get("line", "")).find("x1.08") >= 0, "attune voices the new factor")
	# Skip-ahead is impossible: channel six's entry exists, but the next
	# seal is channel two — below its floor the refusal fires.
	_check(not (ge.call("leyline_entry", 5) as Dictionary).is_empty(), "late entry readable")
	var r4: Dictionary = ge.call("attune_next")
	_check(not bool(r4.get("ok", true)) and str(r4.get("reason", "")) == "floor", "no skipping to channel two below R05")
	# Sealed state: all eight open refuses with the sealed line.
	ge.set("leyline_open", 8)
	var r5: Dictionary = ge.call("attune_next")
	_check(not bool(r5.get("ok", true)) and str(r5.get("reason", "")) == "sealed", "full opening seals further attune")
	_check(str(r5.get("line", "")).find("eight channels") >= 0, "sealed line says so")
	_check((ge.call("leyline_next") as Dictionary).is_empty(), "no next when sealed")
	# Targeted fault (R-S20): an unwired table refuses sealed, never ok.
	var bare: Node = _new_engine()
	bare.call("set_leyline_table", [])
	_check(not bool((bare.call("attune_next") as Dictionary).get("ok", true)), "empty table cannot attune")
	ge.queue_free()
	bare.queue_free()

func _test_factor_math() -> void:
	# Always through the real path: direct var sets skip the cached-rate
	# recompute, so only attune_next (or reset/load paths that recompute)
	# may open channels under measurement.
	var ge: Node = _new_engine()
	_rich(ge, 24, 1.0e17)
	# Settle the compiled-rate cache through a public no-op path
	# (set_gear_mult(1.0) is the default and unconditionally recomputes) —
	# virgin caches read 1.0 until the first recompute, which would make
	# every ratio meaningless.
	ge.call("set_gear_mult", 1.0)
	var r0: float = float(ge.call("rate_num"))
	ge.call("set_leyline_table", _load_json("res://data/leylines.json"))
	_check(float(ge.call("rate_num")) == r0, "wiring the table touches nothing (bit-identical)")
	_check(bool((ge.call("attune_next") as Dictionary).get("ok", false)), "first channel attunes on the real path")
	_check(absf(float(ge.call("rate_num")) / r0 - 1.08) < 0.000000001, "one channel pays exact x1.08")
	for i in range(7):
		ge.call("attune_next")
	_check(int(ge.get("leyline_open")) == 8, "full walk opens all eight")
	_check(absf(float(ge.call("rate_num")) / r0 - 1.64) < 0.000000001, "full opening pays exact x1.64")
	_check(absf(float(ge.call("leyline_mult")) - 1.64) < 0.000000001, "leyline_mult reports x1.64")
	ge.queue_free()

func _test_resets() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 5, 1000000000.0)
	ge.set("leyline_open", 2)
	ge.call("rebirth")
	_check(int(ge.get("leyline_open")) == 0, "Samsara re-opens the meridians")
	ge.set("leyline_open", 2)
	ge.set("qi_earned_total", 4000000.0)
	_check(int(ge.call("ascend")) > 0, "ascension pays out")
	_check(int(ge.get("leyline_open")) == 0, "ascension leaves channels behind")
	ge.queue_free()

func _test_load() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 5, 1000000000.0)
	ge.set("leyline_open", 3)
	var st: Dictionary = ge.call("get_state")
	_check(int(st.get("leyline_open", -1)) == 3, "state stamps the opening")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(int(ge2.get("leyline_open")) == 3, "load resumes attuned (inverse of presence)")
	ge2.call("apply_state", {})
	_check(int(ge2.get("leyline_open")) == 0, "missing key defaults sealed")
	ge2.set("leyline_open", 99)
	ge2.call("apply_state", ge2.call("get_state"))
	_check(int(ge2.get("leyline_open")) == 8, "load clamps to the table")
	ge.queue_free()
	ge2.queue_free()

func _test_offline_inclusion() -> void:
	# The offline path IS the tick path (SaveManager calls _step_tick per
	# away-second), so a tick-delta pair plus saved-state load composes to
	# offline inclusion. 300 ticks keeps both engines alive (no rebirth
	# may reset the measured opening mid-run).
	var mk := func(n: int) -> Node:
		var g: Node = _new_engine()
		_rich(g, 5, 1000000000.0)
		g.call("set_gear_mult", 1.0)
		for i in range(n):
			g.call("attune_next")
		return g
	var a: Node = mk.call(0)
	var b: Node = mk.call(2)
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var sma: Node = SM.new()
	root.add_child(sma)
	sma.set("engine_ref", a)
	var smb: Node = SM.new()
	root.add_child(smb)
	smb.set("engine_ref", b)
	var qa0: float = float(a.call("qi_num"))
	var qb0: float = float(b.call("qi_num"))
	var ra: Dictionary = sma.call("apply_offline", 0, 300)
	var rb: Dictionary = smb.call("apply_offline", 0, 300)
	_check(int(ra.get("months", 0)) == 300 and int(rb.get("months", 0)) == 300, "both away-runs resolve fully")
	var ga: float = float(a.call("qi_num")) - qa0
	var gb: float = float(b.call("qi_num")) - qb0
	_check(gb > ga, "attuned away-gains exceed sealed")
	_check(absf((gb / maxf(ga, 0.001)) - 1.16) < 0.02, "away-gain ratio tracks x1.16")
	_check(int(b.get("leyline_open")) == 2, "away-ticks never seal channels")
	a.queue_free()
	b.queue_free()
	sma.queue_free()
	smb.queue_free()

func _test_orthogonality() -> void:
	var ge: Node = _new_engine()
	_rich(ge, 5, 1000000000.0)
	ge.call("set_gear_mult", 1.0)
	var base: float = float(ge.call("rate_num"))
	ge.call("set_presence", true)
	ge.set("heaven_marks", 2)
	ge.call("attune_next")
	ge.call("attune_next")
	_check(int(ge.get("leyline_open")) == 2, "orthogonality pair attunes on the real path")
	var want: float = base * 1.5 * pow(1.02, 2.0) * 1.16
	_check(absf(float(ge.call("rate_num")) / want - 1.0) < 0.000001, "presence x marks x leyline compose exactly")
	ge.call("set_stake", "heaven")
	_check(absf(float(ge.call("rate_num")) / want - 1.0) < 0.000001, "pledging heaven never touches the rate")
	ge.queue_free()

func _test_migration() -> void:
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	_check(int(SM.get("SAVE_VERSION")) == 14, "save version is 14")
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	var f: FileAccess = FileAccess.open("user://cultivation_nation_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 13, "saved_unix": 1, "engine": {"tick_count": 7, "realm_index": 3}, "extra": {}}))
	f.close()
	var loaded: Dictionary = sm.call("load_game")
	_check(int(loaded.get("save_version", 0)) == 14, "v13 fixture stamped to v14")
	var eng: Dictionary = loaded.get("engine", {})
	_check(int(eng.get("leyline_open", -1)) == 0, "v13 gains sealed channels")
	_check(int(eng.get("tick_count", 0)) == 7, "migration preserves existing keys")
	ge.call("set_realm_table", _load_json("res://data/realms.json"))
	ge.call("set_leyline_table", _load_json("res://data/leylines.json"))
	_rich(ge, 5, 1000000000.0)
	ge.set("leyline_open", 3)
	_check(bool(sm.call("save_game")), "v14 save writes")
	var back: Dictionary = sm.call("load_game")
	_check(int((back.get("engine", {}) as Dictionary).get("leyline_open", -1)) == 3, "v14 opening roundtrips")
	ge.queue_free()
	sm.queue_free()

func _world() -> Node:
	return _scene_main.get_node("WorldViewport/World")

func _test_modal_flow() -> void:
	# Node ley-line modal: builds headless, attune + meditate buttons,
	# presents through the modal manager, sealed state shows no attune.
	# Re-wire the shared engine's table first (mirrors Main._wire_world;
	# hermetic against ready-order).
	var age: Node = root.get_node_or_null("GameEngine")
	if age != null:
		age.call("set_leyline_table", _load_json("res://data/leylines.json"))
	var dlg: AcceptDialog = _scene_main.call("_build_leyline_dialog", "leyline_01") as AcceptDialog
	_check(dlg != null and dlg.name == "LeylineDialog", "leyline dialog builds")
	_check(dlg.get_node_or_null("LeylineBox") != null, "dialog carries its box")
	var texts: Array = []
	for c in (dlg.get_node("LeylineBox") as Container).get_children():
		if c is Button:
			texts.append(str((c as Button).text))
	_check(texts.size() >= 2, "modal offers attune + meditate")
	_scene_main.call("_show_leyline", "leyline_01")
	var shown: Node = _scene_main.get_node_or_null("UI/LeylineDialog")
	_check(shown != null, "show presents the dialog")
	_scene_main.call("_on_leyline_meditate", shown)
	var gone: Node = _scene_main.get_node_or_null("UI/LeylineDialog")
	_check(gone == null or gone.is_queued_for_deletion(), "meditate choice frees the dialog")
	var w: Node = _world()
	_check(w.has_method("take_leyline_request"), "world voices leyline requests")
	_check(w.has_method("meditate_at_node"), "world voices node meditation")

func _test_budgets() -> void:
	var w: Node = _world()
	_check(int(w.call("count_nodes")) <= 170, "world node budget holds with leyline routing")
	var b: Dictionary = w.call("particle_budget")
	_check(int(b.get("total", 9999)) <= 768, "total budget holds with leyline routing")
