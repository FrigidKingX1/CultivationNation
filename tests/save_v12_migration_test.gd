extends SceneTree
## P22 save v12 migration. Run with:
## --headless -s res://tests/save_v12_migration_test.gd (exit 0 = pass).
## Proves v11 saves gain guardian defaults, v12 saves roundtrip intact,
## and the version only ever moves forward (never back to 2).

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _slot() -> String:
	return "user://cultivation_nation_save.json"

func _bak() -> String:
	return "user://cultivation_nation_save.bak.json"

func _wipe() -> void:
	for p in [_slot(), _bak()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _write(payload: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(_slot(), FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f.close()

func _initialize() -> void:
	print("SAVE-V12-TEST start")
	_wipe()
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	_check(int(SM.get("SAVE_VERSION")) == 12, "save version is 12")
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	# v11 payload: engine state with no guardians key at all.
	_write({"save_version": 11, "saved_unix": 1, "engine": {"tick_count": 7, "realm_index": 3}, "extra": {}})
	var loaded: Dictionary = sm.call("load_game")
	_check(int(loaded.get("save_version", 0)) == 12, "v11 fixture stamped to v12")
	var eng: Dictionary = loaded.get("engine", {})
	_check((eng.get("guardians", {}) as Dictionary).get("defeated", ["x"]).is_empty(), "v11 gains empty victories")
	_check(((eng.get("guardians", {}) as Dictionary).get("attempts", {"x": 1}) as Dictionary).is_empty(), "v11 gains empty attempts")
	_check(int(eng.get("tick_count", 0)) == 7, "migration preserves existing keys")
	_check(int(eng.get("realm_index", -1)) == 3, "migration preserves progress")
	# A v12 payload with victories roundtrips through save/load intact.
	ge.call("set_realm_table", JSON.parse_string(FileAccess.open("res://data/realms.json", FileAccess.READ).get_as_text()))
	var defs_f: FileAccess = FileAccess.open("res://data/guardians.json", FileAccess.READ)
	ge.call("set_guardian_defs", JSON.parse_string(defs_f.get_as_text()))
	defs_f.close()
	ge.set("realm_index", 7)
	ge.call("attempt_guardian", 1.0e9, 1.0)
	_check(bool(sm.call("save_game")), "v12 save writes")
	var back: Dictionary = sm.call("load_game")
	var beng: Dictionary = back.get("engine", {})
	_check((beng.get("guardians", {}) as Dictionary).get("defeated", []).has("guardian_01"), "victories survive save roundtrip")
	_check(int(beng.get("guardians", {}).get("attempts", {}).get("guardian_01", 0)) == 1, "attempt counts survive roundtrip")
	ge.queue_free()
	sm.queue_free()
	_wipe()
	if _failures == 0:
		print("SAVE-V12-TEST PASS")
	else:
		printerr("SAVE-V12-TEST FAIL count=", _failures)
	quit(_failures)
