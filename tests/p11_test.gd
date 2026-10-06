extends SceneTree
## P11 pacing + shortcuts test. Original code.
## Run: --headless -s res://tests/p11_test.gd (exit 0 = pass).
## Pacing policy mirrors tests/pacing.gd (diagnostic): train until power
## suffices, else cultivate; rebirth at death. Bands: realm 3 fast, full
## clear bounded in ticks and lives.

var _failures: int = 0
var _stage: int = 0
var _frames: int = 0
var _scene_main: Node = null

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _need(realm: int) -> float:
	return 5.0 + float(realm) * 5.0

func _realms() -> Array:
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _initialize() -> void:
	print("P11-TEST start")
	_test_pacing()
	var packed: PackedScene = load("res://scenes/Main.tscn")
	_scene_main = packed.instantiate()
	root.add_child(_scene_main)
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 2:
		_test_shortcuts()
		_stage = 2
	elif _stage == 2:
		_finish()
	elif _frames > 3600:
		printerr("P11-TEST FAIL: frame timeout")
		quit(1)
	return false

func _finish() -> void:
	if _failures == 0:
		print("P11-TEST PASS")
	else:
		printerr("P11-TEST FAIL count=", _failures)
	quit(_failures)

func _test_pacing() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	ge.call("set_activity_rate", 1.0)
	ge.call("set_realm_table", _realms())
	# P12-2 mind hygiene: wire grounds and walk when Strained, mirroring a
	# player who rests the heart. Fixed map seed keeps it deterministic.
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_beast_pool", cdb.get("beasts"))
	cdb.free()
	ge.call("generate_map", 4242)
	var ticks: int = 0
	var t3: int = -1
	var fails: int = 0
	var cap: int = 300000
	while ticks < cap and int(ge.get("realm_index")) < 50:
		if int(ge.call("mind_stage")) == 2:
			ge.call("wander")
		var r: int = int(ge.get("realm_index"))
		# P15-Step1: engine bonus (attunement-aware), mirroring live Main.
		var bonus: float = float(ge.call("technique_power_bonus", "pace_art"))
		# P13-B1: readiness first — train to ready, then fill, then attempt.
		# Doomed attempts never fire, so fails must stay zero.
		if not bool(ge.call("is_ready", 10.0, _need(r), bonus)):
			ge.call("set_focus", "train")
			ge.set("focus_technique", "pace_art")
		elif ge.call("qi_num") < ge.call("bottleneck_num"):
			ge.call("set_focus", "cultivate")
		else:
			if not bool(ge.call("attempt_breakthrough", 10.0, _need(r), bonus)):
				fails += 1
		ge.call("_step_tick")
		ticks += 1
		if r + 1 == 3 and t3 < 0 and int(ge.get("realm_index")) >= 3:
			t3 = ticks
	_check(int(ge.get("realm_index")) >= 50, "pacing: full clear within cap")
	_check(fails == 0, "pacing: no doomed attempts fired")
	# P16-Step2 lower bounds (exact pin now lives in pacing_pin_test.gd
	# EXPECTED_PACING, re-measured 73038/13 after the M2-M5 wardens: slow
	# start, untouched late): tripwires against silent
	# trivialization. A future change that halves the clear must trip these
	# and justify itself in DECISIONS.md, not slide by unnoticed.
	_check(ticks >= 30000, "pacing: clear takes real journeys (ticks floor)")
	_check(int(ge.get("life_number")) >= 5, "pacing: clear costs lives (lives floor)")
	_check(t3 > 0 and t3 <= 5000, "pacing: realm 3 in first session")
	_check(ticks <= 300000, "pacing: full clear bounded (ticks)")
	# P12-3: sloppy-bot crossings scar years, so lives run hot (measured 83);
	# aptitude compensates ticks. Band holds the same ~1.8x headroom as ticks.
	_check(int(ge.get("life_number")) <= 150, "pacing: full clear bounded (lives)")
	print("P11: clear in ", ticks, " ticks, ", ge.get("life_number"), " lives")
	ge.queue_free()

func _shortcut(key: int) -> bool:
	return bool(_scene_main.call("handle_shortcut", key))

func _test_shortcuts() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var ge: Node = root.get_node("GameEngine")
	_check(not _shortcut(KEY_F5), "unknown key rejected")
	_check(_shortcut(KEY_2) and str(ge.get("player_focus")) == "train", "2: drill focus")
	_check(_shortcut(KEY_3) and str(ge.get("player_focus")) == "hunt", "3: stalk focus")
	_check(_shortcut(KEY_1) and str(ge.get("player_focus")) == "cultivate", "1: breathe focus")
	ge.set("qi", 10000.0)
	ge.set("qi_bottleneck", 120.0)
	var r0: int = int(ge.get("realm_index"))
	_check(_shortcut(KEY_T) and int(ge.get("realm_index")) == r0 + 1, "T: tribulation")
	_check(_shortcut(KEY_9) and float(ge.get("time_scale")) == 100.0, "9: speed 100x")
	_check(_shortcut(KEY_7) and float(ge.get("time_scale")) == 1.0, "7: speed 1x")
	_check(_shortcut(KEY_SPACE) and not bool(ge.get("running")), "space: pause")
	_check(_shortcut(KEY_SPACE) and bool(ge.get("running")), "space: resume")
	ge.call("generate_map", 4242)
	ge.call("travel_to", str((ge.get("map_nodes") as Array)[0].get("id", "")))
	var bid: String = str((ge.get("map_nodes") as Array)[0].get("beast_id", ""))
	var k0: int = int((ge.get("beasts") as Dictionary).get(bid, 0))
	_check(_shortcut(KEY_H) and int((ge.get("beasts") as Dictionary).get(bid, 0)) > k0, "H: stalk grounds")
	_check(_shortcut(KEY_M) and bool(ge.get("muted")), "M: mute")
	_check(_shortcut(KEY_M) and not bool(ge.get("muted")), "M: unmute")
	ge.set("current_node", "")
	# P24 rule-11: legacy wander default moved W -> V (W now walks the
	# world); rebind-replacement semantics keep stored player keys intact.
	_check(_shortcut(KEY_V) and str(ge.get("current_node")) != "", "V: wander walks")
