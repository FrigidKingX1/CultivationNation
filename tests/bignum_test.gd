extends SceneTree
## P19a — true big-math proofs. Run: --headless -s res://tests/bignum_test.gd
## Exit 0 = pass, 1 = fail. Covers the Big value type (ops, coercion,
## save-dicts, display) plus engine integration (accumulation parity with
## the old float path, v9->v10 migration, save round-trip in Big form).

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _initialize() -> void:
	print("BIGNUM-TEST start")
	_test_coerce()
	_test_arith()
	_test_compare()
	_test_floor_save()
	_test_display()
	_test_accumulation_parity()
	_test_engine_big()
	_test_native_parity()
	if _failures == 0:
		print("BIGNUM-TEST PASS")
	else:
		printerr("BIGNUM-TEST FAIL count=", _failures)
	quit(_failures)

func _test_coerce() -> void:
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	var z = BN.of(0.0)
	_check(z.is_zero(), "zero coerces zero")
	_check(BN.of(-5.0).is_zero(), "negatives floor at zero")
	_check(BN.of(null).is_zero(), "null coerces zero")
	var b = BN.from_float(1234.0)
	_check(b.to_float() == 1234.0, "integers stay bit-identical")
	var same = BN.of(b)
	_check(same.to_float() == 1234.0, "Big passes through")
	var d = BN.of({"m": 4.242, "e": 3})
	_check(absf(d.to_float() - 4242.0) < 1e-9, "save-dict reconstructs")
	var di = BN.of({"m": 4242.0, "e": 0})
	_check(di.to_float() == 4242.0, "integer save-dict bit-identical")
	_check(BN.of(7).to_float() == 7.0, "ints coerce")

func _test_arith() -> void:
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(BN.from_float(999.0).plus(1.0).to_float() == 1000.0, "999+1 carries")
	# Arithmetic normalizes (1.68 is not binary-exact): decade-exact and
	# within float64 noise, never bit-identical. Storage stays exact.
	_check(absf(BN.from_float(1200.0).plus(480.0).to_float() - 1680.0) < 1e-9, "realm sums within noise")
	# Float64-noise parity: 1e16+1 loses the 1 in float64; Big agrees.
	_check(BN.from_float(1e16).plus(1.0).to_float() == 1e16, "far-scale absorbs noise like float64")
	_check(BN.from_float(1200.0).minus(1200.0).is_zero(), "self-minus zeroes")
	_check(BN.from_float(5.0).minus(10.0).is_zero(), "minus floors at zero")
	_check(absf(BN.from_float(10000.0).minus(6.0).to_float() - 9994.0) < 1e-9, "toll-scale subtract")
	_check(BN.from_float(120.0).times(4.0).to_float() == 480.0, "times exact")
	_check(BN.from_float(480.0).div(4.0).to_float() == 120.0, "div exact")
	_check(BN.from_float(3.0).div(0.0).is_zero(), "div-by-zero zeroes")
	# x4 breakthrough growth, 50 deep: exact powers of two throughout.
	var r = BN.from_float(1.0)
	for i in range(50):
		r = r.times_float(4.0)
	_check(absf(r.to_float() - pow(4.0, 50.0)) / pow(4.0, 50.0) < 1e-12, "4^50 growth exact")
	# Realm-50 scale: 120x4^49 past float-int precision, still exact decade.
	var big = BN.from_float(120.0)
	for i in range(49):
		big = big.times_float(4.0)
	_check(absf(big.to_float() - 120.0 * pow(4.0, 49.0)) / (120.0 * pow(4.0, 49.0)) < 1e-9, "realm-50 scale holds")

func _test_compare() -> void:
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(BN.from_float(1199.0).lt(1200.0), "less-than")
	_check(BN.from_float(1200.0).ge(1200.0), "equal counts as met")
	_check(BN.from_float(120.0).ge(BN.from_float(120.0)), "Big-to-Big equal")
	_check(not BN.from_float(119.0).ge(100.0 + 20.0), "no phantom afford")
	# Rep-insensitive: raw integer vs normalized decade of the same value.
	_check(BN.of({"m": 4242.0, "e": 0}).eq(BN.from_float(4242.0).plus(0.0)), "raw equals normalized")
	# Last-ulp forgiveness at gate boundaries (float noise never blocks).
	_check(BN.from_float(1200.0).minus(1e-10).ge(1200.0), "ulp forgiveness at gates")

func _test_floor_save() -> void:
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(BN.from_float(1234.56).floor_int().to_float() == 1234.0, "floor drops fraction")
	_check(BN.from_float(1e20).floor_int().to_float() == 1e20, "huge already integral")
	var b = BN.from_float(4242.0)
	var rt = BN.of(b.to_save())
	_check(rt.to_float() == 4242.0, "save round-trip bit-identical")
	_check(str(b.to_save().get("m", "")) != "", "save-dict carries mantissa")

func _test_display() -> void:
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(BN.format_any(BN.from_float(999.0)) == "999", "any under 1k")
	_check(BN.format_any(BN.from_float(1500.0)) == "1.50K", "any kilo")
	_check(BN.format_any(BN.from_float(1e36)) == "1.00Ud", "any reaches Ud")
	_check(BN.format_any(4242.0) == "4.24K", "any coerces floats")
	# Past float range entirely: 1e360 renders from the decade, no Inf.
	var huge = BN.from_float(1e30)
	for i in range(12):
		huge = huge.times(huge)
		if huge.to_float() > 1e300:
			break
	_check("e" in BN.format_any(huge), "beyond-float renders scientific")

func _test_accumulation_parity() -> void:
	## The tick loop in Big must match the old float accumulation to
	## float-noise: 100k ticks at a fractional rate, both paths.
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	var rate: float = 1.371234
	var f: float = 0.0
	var acc = BN.from_float(0.0)
	for i in range(100000):
		f += rate
		acc = acc.plus(rate)
	_check(absf(acc.to_float() - f) / maxf(f, 1.0) < 1e-9, "100k-tick accumulation matches float")

func _test_engine_big() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	ge.call("set_activity_rate", 1.0)
	# Stored values are Big after the first tick; accessors read floats.
	ge.call("_step_tick")
	_check(ge.call("qi_num") > 0.0, "ticks accumulate Qi in Big")
	_check(ge.call("rate_num") > 0.0, "compiled rate reads back")
	_check(ge.call("fill_ratio") >= 0.0 and ge.call("fill_ratio") <= 1.0, "fill bounded")
	# Engine tolerates legacy float assignment (every old test path).
	ge.set("qi", 200.0)
	ge.set("qi_bottleneck", 120.0)
	_check(bool(ge.call("attempt_breakthrough", 10.0, 5.0)), "float-seeded breakthrough")
	_check(ge.call("qi_num") == 0.0, "post-crossing Qi zeroes")
	# State carries {m, e} dicts; reload restores bit-identical integers.
	ge.set("qi", 4242.0)
	var st: Dictionary = ge.call("get_state")
	_check((st.get("qi") as Dictionary).has("m"), "state stores Big dicts")
	var GE2: GDScript = load("res://scripts/GameEngine.gd")
	var ge2: Node = GE2.new()
	root.add_child(ge2)
	ge2.call("apply_state", st)
	_check(ge2.call("qi_num") == 4242.0, "Big state restores exactly")
	ge.queue_free()
	ge2.queue_free()

func _test_native_parity() -> void:
	## P21: the native backend (shoyguer GDExtension) must satisfy the same
	## contract. Flip, prove the core subset, flip back — the suite leaves
	## the proven GDScript backend active. Verdict 2026-10-04: native is
	## ~28% SLOWER per tick (call overhead dominates), pacing-identical;
	## GDScript stays primary, native stays available via use_backend.
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(str(BN.backend()) == "gdscript", "suite starts on proven backend")
	if not BN.use_backend("native"):
		printerr("FAIL: native backend unavailable")
		_failures += 1
		return
	_check(BN.from_float(4242.0).to_float() == 4242.0, "native integers exact")
	_check(BN.from_float(999.0).plus(1.0).to_float() == 1000.0, "native carries")
	_check(absf(BN.from_float(10000.0).minus(6.0).to_float() - 9994.0) < 1e-9, "native subtracts")
	_check(BN.from_float(120.0).times(4.0).to_float() == 480.0, "native multiplies")
	_check(BN.from_float(480.0).div(4.0).to_float() == 120.0, "native divides")
	_check(BN.from_float(1200.0).ge(1200.0), "native compares")
	_check(BN.format_any(BN.from_float(1e36)) == "1.00Ud", "native displays")
	var acc = BN.from_float(0.0)
	for i in range(20000):
		acc = acc.plus(1.371234)
	_check(absf(acc.to_float() - 20000.0 * 1.371234) / (20000.0 * 1.371234) < 1e-9, "native accumulates")
	var rt = BN.of(BN.from_float(4242.0).to_save())
	_check(rt.to_float() == 4242.0, "native save round-trips")
	_check(BN.use_backend("gdscript"), "backend flips back")
	_check(str(BN.backend()) == "gdscript", "suite leaves proven backend")
