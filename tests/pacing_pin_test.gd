extends SceneTree
## 0.28b pacing pin (P1, UNCONDITIONAL) + warden budget (P2).
## Seed-frozen default-path bot (mirror of tests/pacing.gd: seed 4242,
## train-then-cultivate, no gear/disciples/offline, 1x) asserts EXACT
## (ticks, lives) against EXPECTED_PACING. The constant changes ONLY via
## a deliberate journal-justified signed-off commit (rebalance re-anchor).
## P2 accumulates tick deltas across attempt_guardian calls and asserts
## the ADR-001 budget (duel ticks <= 1% of ladder total).
## Run with: --headless -s res://tests/pacing_pin_test.gd (exit 0 = pass).

const EXPECTED_TICKS := 73038
const EXPECTED_LIVES := 13

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _need(realm: int) -> float:
	return 5.0 + float(realm) * 5.0

func _load_realms() -> Array:
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _initialize() -> void:
	print("PACING-PIN start: EXPECTED_PACING=(%d, %d)" % [EXPECTED_TICKS, EXPECTED_LIVES])
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	ge.call("set_activity_rate", 1.0)
	ge.call("set_realm_table", _load_realms())
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_beast_pool", cdb.get("beasts"))
	ge.call("set_guardian_defs", cdb.get("guardians"))
	cdb.free()
	ge.call("generate_map", 4242)
	var ticks: int = 0
	var duels: int = 0
	var duel_ticks: int = 0
	var cap: int = 10000000
	var i: int = 0
	while i < cap and int(ge.get("realm_index")) < 50:
		if int(ge.call("mind_stage")) == 2:
			ge.call("wander")
		var r: int = int(ge.get("realm_index"))
		var bonus: float = float(ge.call("technique_power_bonus", "pace_art"))
		if not bool(ge.call("is_ready", 10.0, _need(r), bonus)):
			ge.call("set_focus", "train")
			ge.set("focus_technique", "pace_art")
		elif ge.call("qi_num") < ge.call("bottleneck_num"):
			ge.call("set_focus", "cultivate")
		elif not (ge.call("guardian_gate") as Dictionary).is_empty():
			var t0: int = int(ge.get("tick_count"))
			ge.call("attempt_guardian", 10.0, bonus)
			duel_ticks += int(ge.get("tick_count")) - t0
			duels += 1
		else:
			ge.call("attempt_breakthrough", 10.0, _need(r), bonus)
		ge.call("_step_tick")
		ticks += 1
		i += 1
	var done: bool = int(ge.get("realm_index")) >= 50
	var lives: int = int(ge.get("life_number"))
	print("PACING-PIN done=", done, " ticks=", ticks, " lives=", lives, " duels=", duels, " duel_ticks=", duel_ticks)
	_check(done, "pin run clears the ladder")
	_check(ticks == EXPECTED_TICKS, "ticks pinned exact")
	_check(lives == EXPECTED_LIVES, "lives pinned exact")
	_check(duels == 7, "seven wardens, one duel each")
	_check(duel_ticks * 100 <= ticks, "duel ticks within the 1% ADR-001 budget")
	if _failures == 0:
		print("PACING-PIN PASS")
	else:
		printerr("PACING-PIN FAIL: ", _failures)
	quit(_failures)
