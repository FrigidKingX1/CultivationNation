extends SceneTree
## P2 bench + low-power + clamp + compiled-rate tests. Original code.
## Run: --headless -s res://tests/bench_test.gd (exit 0 = pass).

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _initialize() -> void:
	print("BENCH start")
	_test_throughput()
	_test_low_power()
	_test_clamp()
	_test_compiled_rate()
	if _failures == 0:
		print("BENCH PASS")
	else:
		printerr("BENCH FAIL count=", _failures)
	quit(_failures)

func _test_throughput() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.set("qi_per_tick", 5.0)
	ge.call("_recompute_rate")
	var t0: int = Time.get_ticks_msec()
	for i in range(50000):
		ge.call("_step_tick")
	var ms: int = Time.get_ticks_msec() - t0
	var per_sec: float = 50000.0 / maxf(float(ms) / 1000.0, 0.001)
	print("bench: 50000 ticks in ", ms, "ms = ", int(per_sec), " ticks/sec")
	_check(ms < 5000, "50k ticks complete <5s")
	_check(int(ge.get("tick_count")) == 50000, "tick count exact after bench")
	ge.free()

func _test_low_power() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var normal: Node = GE.new()
	normal.set("time_scale", 1000.0)
	normal.set("low_power_mode", false)
	normal.call("_process", 1.0)
	var low: Node = GE.new()
	low.set("time_scale", 1000.0)
	low.set("low_power_mode", true)
	low.call("_process", 1.0)
	var n: int = int(normal.get("tick_count"))
	var l: int = int(low.get("tick_count"))
	print("bench: normal steps=", n, " low-power steps=", l)
	_check(l < n, "low-power yields fewer steps at 1000x")
	_check(l == 100, "low-power single 1s frame = 100 steps")
	_check(n == 5000, "normal single 1s frame clamped to 5000 (catch-up guard)")
	normal.free()
	low.free()

func _test_clamp() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.call("set_time_scale", 99999.0)
	_check(float(ge.get("time_scale")) == 1000.0, "time_scale clamps to 1000 max")
	ge.call("set_time_scale", 0.0)
	_check(float(ge.get("time_scale")) == 1.0, "time_scale clamps to 1 min")
	_check(float(ge.call("effective_rate")) == 10.0, "effective rate at 1x = 10tps")
	ge.free()

func _test_compiled_rate() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.set("aptitude", 2.0)
	ge.call("set_activity_rate", 3.0)
	# P12-2 formula: base x aptitude x origin x dantian x mind x env x season.
	# Fresh engine: mind 70 Serene 1.25x, no grounds 1.0x, month 0 Spring 1.1x.
	var expect: float = 3.0 * 2.0 * 1.0 * (0.5 + 80.0 / 100.0) * 1.25 * 1.0 * 1.1
	_check(absf(ge.call("rate_num") - expect) < 0.0001, "compiled rate = qi x aptitude x origin x dantian")
	var q0: float = ge.call("qi_num")
	ge.call("_step_tick")
	_check(absf(ge.call("qi_num") - (q0 + expect)) < 0.0001, "tick uses compiled cache")
	ge.call("set_focus", "train")
	# P13-B5 keystone: drill yields xp but zero Qi (was half).
	_check(absf(ge.call("rate_num") - 0.0) < 0.0001, "drill focus zeroes Qi rate")
	ge.free()
