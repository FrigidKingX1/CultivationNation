extends SceneTree
## Pacing projection: plays the REAL GameEngine formulas life after life and
## prints hours-per-realm. Diagnostic (exit 0); bands asserted in p11_test.
## Policy: train until tribulation power suffices, else cultivate; rebirth at
## death; aptitude/gear/disciples compound as coded. Conservative: no gear,
## no disciples, no offline gains, time_scale 1x (speeds divide wall time).

var _ticks: int = 0

func _need(realm: int) -> float:
	return 5.0 + float(realm) * 5.0

func _load_realms() -> Array:
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _initialize() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	ge.call("set_activity_rate", 1.0)
	ge.call("set_realm_table", _load_realms())
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_beast_pool", cdb.get("beasts"))
	cdb.free()
	ge.call("generate_map", 4242)
	print("PACING: policy=train-then-cultivate, 1x sim seconds, cap 10M ticks")
	var per_realm: Dictionary = {}
	var t_realm: int = 0
	var cap: int = 10000000
	var i: int = 0
	while i < cap and int(ge.get("realm_index")) < 50:
		if int(ge.call("mind_stage")) == 2:
			ge.call("wander")
		var r: int = int(ge.get("realm_index"))
		# P15-Step1: engine bonus (attunement-aware), mirroring live Main.
		# A manual formula here would blind pacing to power-curve changes.
		var bonus: float = float(ge.call("technique_power_bonus", "pace_art"))
		if not bool(ge.call("is_ready", 10.0, _need(r), bonus)):
			ge.call("set_focus", "train")
			ge.set("focus_technique", "pace_art")
		elif ge.call("qi_num") < ge.call("bottleneck_num"):
			ge.call("set_focus", "cultivate")
		else:
			ge.call("attempt_breakthrough", 10.0, _need(r), bonus)
		ge.call("_step_tick")
		_ticks += 1
		i += 1
		if int(ge.get("realm_index")) > r:
			var dt: int = _ticks - t_realm
			per_realm[r + 1] = dt
			t_realm = _ticks
			print("PACING: realm %d at tick %d (+%d ticks = %1.1fh)" % [r + 1, _ticks, dt, float(dt) / 36000.0])
	var done: bool = int(ge.get("realm_index")) >= 50
	print("PACING: done=", done, " ticks=", _ticks, " lives=", ge.get("life_number"),
		" aptitude=", ge.get("aptitude"), " hours1x=", float(_ticks) / 36000.0)
	quit(0)
