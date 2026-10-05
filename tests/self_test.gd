extends SceneTree
## Self-contained headless tests. Run: --headless -s res://tests/self_test.gd
## Exit 0 = pass, 1 = fail. No addon downloads required.

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _initialize() -> void:
	print("Cultivation Nation self-test start")
	_test_bignumber()
	_test_engine_rebirth()
	_test_engine_breakthrough()
	_test_offline()
	_test_content_files()
	if _failures == 0:
		print("SELF-TEST PASS")
	else:
		printerr("SELF-TEST FAIL count=", _failures)
	quit(_failures)

func _test_bignumber() -> void:
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(BN.format_hybrid(999.0) == "999", "fmt under 1k")
	_check(BN.format_hybrid(1500.0) == "1.50K", "fmt 1.5K")
	_check(BN.format_hybrid(2500000.0) == "2.50M", "fmt 2.5M")
	var b: RefCounted = BN.from_float(1234.0)
	_check(b.to_float() > 1233.0 and b.to_float() < 1235.0, "bignumber roundtrip")

func _test_engine_rebirth() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.set("total_rebirths", 0)
	ge.set("aptitude", 1.0)
	ge.call("rebirth")
	_check(float(ge.get("aptitude")) > 1.0, "rebirth keeps/raises aptitude")
	_check(int(ge.get("life_number")) == 2, "rebirth increments life")
	_check(int(ge.get("age_years")) == 18, "rebirth resets age")
	ge.free()

func _test_engine_breakthrough() -> void:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	ge.set("qi", 200.0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("realm_index", 0)
	var ok: bool = bool(ge.call("attempt_breakthrough", 10.0, 5.0))
	_check(ok, "breakthrough success path")
	_check(int(ge.get("realm_index")) == 1, "realm advances")
	ge.set("qi", 200.0)
	ge.set("qi_bottleneck", 120.0)
	var fail_ok: bool = bool(ge.call("attempt_breakthrough", 1.0, 999.0))
	_check(not fail_ok, "weak power fails tribulation")
	ge.free()

func _test_offline() -> void:
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var sm: Node = SM.new()
	var r: Dictionary = sm.call("compute_offline_gains", 1000, 1000 + 3600, 2.0)
	_check(int(r.get("away_seconds", 0)) == 3600, "offline seconds")
	_check(float(r.get("bonus_qi", 0.0)) == 7200.0, "offline qi math")
	var capped: Dictionary = sm.call("compute_offline_gains", 0, 9999999, 1.0)
	_check(int(capped.get("away_seconds", 0)) == 8 * 3600, "offline cap 8h")
	sm.free()

func _test_content_files() -> void:
	_check(FileAccess.file_exists("res://data/realms.json"), "realms.json exists")
	_check(FileAccess.file_exists("res://data/origins.json"), "origins.json exists")
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	_check(typeof(parsed) == TYPE_ARRAY and (parsed as Array).size() == 50, "50 original realms")
