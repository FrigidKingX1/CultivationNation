extends SceneTree
## P23 world test: islands, gates, determinism, budgets, contract drift.
## Run with: --headless -s res://tests/p23_world_test.gd (exit 0 = pass).

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

func _world() -> Node:
	return _scene_main.get_node("WorldViewport/World")

func _initialize() -> void:
	print("P23-TEST start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		# Viewport pinning per hazard 2.3.3 (headless dummy is square).
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1280, 720)
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 5:
		_test_contract_drift()
		_test_islands()
		_test_gates()
		_test_determinism()
		_test_budgets()
		_test_weather_trib()
		_test_rebuild_on_seed()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 30:
		# Tribulation VFX must settle and free cleanly (post-leak discipline).
		if not bool(_world().call("tribulation_active")):
			_test_settled()
			if _failures == 0:
				print("P23-TEST PASS")
			else:
				printerr("P23-TEST FAIL count=", _failures)
			quit(_failures)
		elif _frames > 1800:
			printerr("P23-TEST FAIL: tribulation never settled")
			quit(1)
	elif _frames > 3600:
		printerr("P23-TEST FAIL: frame timeout")
		quit(1)
	return false

func _contract_text() -> String:
	# Mirrors tools/p23_worldview_inventory.gd extraction (duplication is
	# deliberate: any probe/test drift fails the diff, which is the goal).
	var src: String = (load("res://scripts/WorldView.gd") as Script).source_code
	var lines: Array[String] = [
		"# WorldView facade contract",
		"contract-format: 3",
		"# Deterministic output. Member removal/edit requires a rule-11",
		"# contract edit with justification. Semantic requirements:",
		"# docs/adr/P23_COUPLING_ADDENDUM.md",
		"script: res://scripts/WorldView.gd", "", "## signals"]
	var sig_re := RegEx.new()
	sig_re.compile("(?m)^signal\\s+.*$")
	var fun_re := RegEx.new()
	fun_re.compile("(?m)^func\\s+.*$")
	var stat_re := RegEx.new()
	stat_re.compile("(?m)^static\\s+func\\s+.*$")
	var exp_re := RegEx.new()
	exp_re.compile("(?m)^@export\\s+.*$")
	for m in sig_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	lines.append("")
	lines.append("## exports")
	for m in exp_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	lines.append("")
	lines.append("## methods (ALL — underscore included; full signatures)")
	for m in fun_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	lines.append("")
	lines.append("## static methods")
	for m in stat_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	var scene_text := ""
	var f := FileAccess.open("res://scenes/Main.tscn", FileAccess.READ)
	if f:
		scene_text = f.get_as_text()
	lines.append("")
	lines.append("## tscn connections targeting World node")
	var con_re := RegEx.new()
	con_re.compile("(?m)^\\[connection[^\\n]*\\]")
	for m in con_re.search_all(scene_text):
		var l := m.get_string(0)
		for hint in ["WorldViewport/World", "World"]:
			if l.contains("node=\"" + hint) or l.contains("from=\"" + hint) or l.contains("to=\"" + hint):
				lines.append(l)
				break
	return "\n".join(lines) + "\n"

func _test_contract_drift() -> void:
	var f := FileAccess.open("res://docs/qa/p23_worldview_contract.txt", FileAccess.READ)
	_check(f != null, "contract file committed")
	if f == null:
		return
	_check(f.get_as_text() == _contract_text(), "contract exact-diff clean")

func _test_islands() -> void:
	var w: Node = _world()
	var zones: Array = w.call("_island_zones")
	_check(zones.size() == 9, "nine islands registered")
	var expect: Dictionary = {}
	var bf: FileAccess = FileAccess.open("res://data/beasts.json", FileAccess.READ)
	for b in (JSON.parse_string(bf.get_as_text()) as Array):
		expect[str((b as Dictionary).get("zone", ""))] = true
	bf.close()
	var same: bool = zones.size() == expect.size()
	for z in zones:
		if not expect.has(str(z)):
			same = false
	_check(same, "island zone set equals beasts zones")
	_check(w.get_node_or_null("CamRig/Yaw/Pitch/Camera3D") != null, "orbit rig staged")
	# Warden shrines: gold flame on tier-threshold islands, plinth only
	# elsewhere; the tier-7 sentinel shares Thornwake at the ladder's end.
	# (Only the active island plus neighbors are resident, so each check
	# visits its island first.)
	w.call("apply_zone", "Murkfen")
	_check(w.get_node_or_null("Islands/Island_Murkfen/Ground") != null, "murkfen ground meshed")
	_check(w.get_node_or_null("Islands/Island_Murkfen/GateWall") != null, "gate wall staged")
	_check(w.get_node_or_null("Islands/Island_Murkfen/ShrineFlame") != null, "warden flame lit")
	w.call("apply_zone", "Thornwake")
	_check(w.get_node_or_null("Islands/Island_Thornwake/SentinelFlame") != null, "sentinel watches the ladder's end")
	w.call("apply_zone", "Dewfield")
	_check(w.get_node_or_null("Islands/Island_Dewfield/Shrine") != null, "plinth on quiet isles")
	_check(w.get_node_or_null("Islands/Island_Dewfield/ShrineFlame") == null, "no flame where no warden stands")

func _test_gates() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("realm_index", 0)
	w.call("_poll_engine")
	var dew: MeshInstance3D = w.get_node("Islands/Island_Dewfield/GateWall") as MeshInstance3D
	_check(not bool(dew.visible), "open grounds show no wall")
	ge.set("realm_index", 7)
	w.call("_poll_engine")
	var thorn: MeshInstance3D = w.get_node("Islands/Island_Thornwake/GateWall") as MeshInstance3D
	_check(bool(thorn.visible), "locked grounds show their wall")

func _test_determinism() -> void:
	var w: Node = _world()
	var h1: String = str(w.call("_vertex_hash", "Murkfen"))
	var h2: String = str(w.call("_vertex_hash", "Murkfen"))
	_check(h1 != "" and h1 == h2, "same seed hashes identically")
	var ge: Node = root.get_node("GameEngine")
	ge.call("generate_map", 4243)
	var h3: String = str(w.call("_vertex_hash", "Murkfen"))
	_check(h3 != h1, "different seed hashes differently")
	ge.call("generate_map", 4242)

func _test_budgets() -> void:
	var w: Node = _world()
	_check(int(w.call("count_nodes")) <= 160, "world node budget holds")
	var b: Dictionary = w.call("particle_budget")
	_check(int(b.get("max_per_effect", 9999)) <= 384, "per-effect budget holds")
	_check(int(b.get("total", 9999)) <= 768, "total budget holds")
	_check(int(b.get("effects", 0)) >= 4, "four effects staged")
	var islands: Node = w.get_node("Islands")
	var n: int = 0
	for c in islands.get_children():
		n += 1
	_check(n == 3, "active island plus neighbors resident")

func _test_weather_trib() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	ge.set("_month_accum", 10)
	w.call("_poll_engine")
	_check(int((w.get_node("Weather") as GPUParticles3D).amount) == 260, "winter snow count kept")
	w.call("play_tribulation", "Radiant", 2)
	_check(bool(w.call("tribulation_active")), "sequence starts on demand")

func _test_rebuild_on_seed() -> void:
	# C6: a seed change (ascension path) rebuilds and frees cleanly.
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	var before: int = int(w.call("count_nodes"))
	ge.call("generate_map", 777001)
	w.call("_poll_engine")
	w.call("_poll_engine")
	var after: int = int(w.call("count_nodes"))
	_check(after == before, "rebuild returns node count to baseline")
	ge.call("generate_map", 4242)
	w.call("_poll_engine")

func _test_settled() -> void:
	var w: Node = _world()
	var bars_hidden: bool = true
	for i in range(4):
		if bool((w.get_node("Strike%d" % i) as MeshInstance3D).visible):
			bars_hidden = false
	_check(bars_hidden, "strike bars rest hidden")
