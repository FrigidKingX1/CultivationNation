extends SceneTree
## P2 save robustness: roundtrip, backup, corrupt fallback, v0 migrate. Original code.
## Run: --headless -s res://tests/save_robustness_test.gd (exit 0 = pass).
## Uses real user:// slot paths, cleans up afterwards.

const SLOT := "user://cultivation_nation_save.json"
const BACKUP := "user://cultivation_nation_save.bak.json"

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _wipe() -> void:
	for p in [SLOT, BACKUP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _initialize() -> void:
	print("SAVE-ROBUSTNESS start")
	_wipe()
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var ge: Node = GE.new()
	ge.set_name("GameEngine")
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)  # P2: bypass absolute-path lookup (illegal in -s context)

	# 1. Roundtrip.
	ge.set("age_years", 42)
	ge.set("qi", 1234.5)
	ge.set("realm_index", 3)
	_check(bool(sm.call("save_game")), "save_game writes")
	ge.set("age_years", 18)
	ge.set("qi", 0.0)
	ge.set("realm_index", 0)
	var loaded: Dictionary = sm.call("load_game")
	_check(not loaded.is_empty(), "load_game returns payload")
	_check(int(ge.get("age_years")) == 42, "roundtrip restores age")
	_check(ge.call("qi_num") > 1234.0, "roundtrip restores qi")
	_check(int(ge.get("realm_index")) == 3, "roundtrip restores realm")

	# 2. Backup rotation: second save with new state keeps prior copy in backup.
	ge.set("age_years", 55)
	_check(bool(sm.call("save_game")), "second save writes")
	_check(FileAccess.file_exists(BACKUP), "backup file exists after 2nd save")
	var bf: FileAccess = FileAccess.open(BACKUP, FileAccess.READ)
	var bparsed: Variant = JSON.parse_string(bf.get_as_text())
	bf.close()
	_check(typeof(bparsed) == TYPE_DICTIONARY, "backup parses as JSON")
	var beng: Dictionary = {}
	if typeof(bparsed) == TYPE_DICTIONARY and (bparsed as Dictionary).has("engine"):
		beng = (bparsed as Dictionary)["engine"]
	_check(int(beng.get("age_years", -1)) == 42, "backup holds prior state")

	# 3. Corrupt primary falls back to backup.
	_write(SLOT, "{corrupt!!! not json")
	ge.set("age_years", 18)
	var loaded2: Dictionary = sm.call("load_game")
	_check(not loaded2.is_empty(), "load falls back to backup when primary corrupt")
	_check(int(ge.get("age_years")) == 42, "fallback restores backup age")

	# 4. v0 fixture migrates (legacy flat keys, no extras).
	_wipe()
	_write(SLOT, JSON.stringify({"save_version": 0, "engine": {"age": 33, "qi": 77}}))
	ge.set("age_years", 18)
	var loaded3: Dictionary = sm.call("load_game")
	_check(int(loaded3.get("save_version", 0)) == 13, "v0 fixture stamped to v13")
	_check(str((loaded3["engine"] as Dictionary).get("origin_id", "")) == "origin_wayfarer", "v0->v2 fills origin default")
	_check(int((loaded3["engine"] as Dictionary).get("pause_before_death_years", -1)) == 0, "v0->v2 fills pause default")
	_check(int(ge.get("age_years")) == 33, "v0 legacy age maps to age_years")
	_check(ge.call("qi_num") == 77.0, "v0 qi preserved")

	# 5. v1 fixture (pre-P3 schema) migrates: old keys preserved, P3 keys defaulted.
	_wipe()
	var v1eng: Dictionary = {"tick_count": 100, "age_years": 40, "lifespan_years": 60,
		"qi": 10.0, "qi_per_tick": 1.0, "realm_index": 1, "qi_bottleneck": 480.0,
		"life_number": 2, "aptitude": 1.25, "total_rebirths": 1, "time_scale": 5.0}
	_write(SLOT, JSON.stringify({"save_version": 1, "engine": v1eng, "extra": {}}))
	var loaded4: Dictionary = sm.call("load_game")
	_check(int(loaded4.get("save_version", 0)) == 13, "v1 fixture stamped to v13")
	_check(int(ge.get("tick_count")) == 100, "v1 tick_count preserved")
	_check(float(ge.get("time_scale")) == 5.0, "v1 time_scale preserved")
	_check(str(ge.get("origin_id")) == "origin_wayfarer", "v1->v3 origin default")
	_check((ge.get("techniques") as Dictionary).is_empty(), "v1->v3 techniques default empty")
	_check((ge.get("beasts") as Dictionary).is_empty(), "v1->v3 beasts default empty")

	# 6. v2 fixture (pre-P4 schema) migrates: old keys preserved, P4 keys defaulted.
	_wipe()
	var v2eng: Dictionary = {"tick_count": 7, "age_years": 30, "lifespan_years": 60,
		"qi": 5.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0}
	_write(SLOT, JSON.stringify({"save_version": 2, "engine": v2eng, "extra": {}}))
	var loaded5: Dictionary = sm.call("load_game")
	_check(int(loaded5.get("save_version", 0)) == 13, "v2 fixture stamped to v13")
	_check(int(ge.get("tick_count")) == 7, "v2 tick_count preserved")
	_check((ge.get("gear") as Dictionary).is_empty(), "v2->v3 gear default empty")
	_check((ge.get("sect") as Dictionary).is_empty(), "v2->v3 sect default empty")
	_check(int(ge.get("map_seed")) == -1, "v2->v3 map_seed default")

	# 7. v4 fixture (pre-P6 schema) migrates: P6 keys defaulted.
	_wipe()
	var v4eng: Dictionary = {"tick_count": 9, "age_years": 28, "lifespan_years": 60,
		"qi": 2.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": []}
	_write(SLOT, JSON.stringify({"save_version": 4, "engine": v4eng, "extra": {}}))
	var loaded6: Dictionary = sm.call("load_game")
	_check(int(loaded6.get("save_version", 0)) == 13, "v4 fixture stamped to v13")
	_check(str(ge.get("player_focus")) == "cultivate", "v4->v5 focus default")
	_check(not bool(ge.get("muted")), "v4->v5 muted default false")

	# 8. v5 fixture (pre-P8 schema) migrates: P8 keys defaulted.
	_wipe()
	var v5eng: Dictionary = {"tick_count": 11, "age_years": 29, "lifespan_years": 60,
		"qi": 3.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": [], "player_focus": "cultivate", "muted": false}
	_write(SLOT, JSON.stringify({"save_version": 5, "engine": v5eng, "extra": {}}))
	var loaded7: Dictionary = sm.call("load_game")
	_check(int(loaded7.get("save_version", 0)) == 13, "v5 fixture stamped to v13")
	_check((ge.get("hints_seen") as Array).is_empty(), "v5->v6 hints default empty")
	_check((ge.get("nodes_visited") as Array).is_empty(), "v5->v6 visited default empty")

	# 9. v6 fixture (pre-P12 schema) migrates: all P12 keys defaulted, old
	# keys preserved.
	_wipe()
	var v6eng: Dictionary = {"tick_count": 13, "age_years": 31, "lifespan_years": 60,
		"qi": 4.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": [], "player_focus": "cultivate", "muted": false,
		"hints_seen": [], "nodes_visited": []}
	_write(SLOT, JSON.stringify({"save_version": 6, "engine": v6eng, "extra": {}}))
	var loaded8: Dictionary = sm.call("load_game")
	_check(int(loaded8.get("save_version", 0)) == 13, "v6 fixture stamped to v13")
	_check((ge.get("roots") as Dictionary).is_empty(), "v6->v7 roots default empty")
	_check(float(ge.get("mind")) == 70.0, "v6->v7 mind default rested")
	_check(int(ge.get("deviation")) == 0, "v6->v7 deviation default clean")
	_check(float(ge.get("herbs")) == 0.0, "v6->v7 herbs default none")
	_check(int(ge.get("karma")) == 0, "v6->v7 karma default none")
	_check((ge.get("talents") as Dictionary).is_empty(), "v6->v7 talents default empty")
	_check((ge.get("soulweapon") as Dictionary).is_empty(), "v6->v7 soul default unbound")
	_check(float(ge.get("legacy_mult")) == 1.0, "v6->v7 legacy default unity")
	_check(ge.call("qi_num") == 4.0, "v6 qi preserved across migration")

	# 10. v7 fixture (pre-P15 schema) migrates: attunement + victorious
	# defaulted, everything else preserved.
	_wipe()
	var v7eng: Dictionary = {"tick_count": 17, "age_years": 33, "lifespan_years": 110,
		"qi": 9.0, "qi_per_tick": 2.0, "realm_index": 1, "qi_bottleneck": 480.0,
		"life_number": 2, "aptitude": 1.25, "total_rebirths": 1, "time_scale": 1.0,
		"origin_id": "origin_ironhide", "origin_qi_mult": 0.9,
		"origin_lifespan_bonus": 20, "dantian_purity": 82.0,
		"techniques": {"tech_stillwater": 400}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "tech_stillwater", "map_seed": 7, "current_node": "",
		"achievements": [], "player_focus": "train", "muted": false,
		"hints_seen": [], "nodes_visited": [],
		"roots": {"water": 0.5}, "mind": 66.0,
		"deviation": 1, "lifespan_scars": 5,
		"herbs": 11.0, "pills": {}, "toxicity": 3.0,
		"karma": 21, "talents": {},
		"soulweapon": {}, "legacy_mult": 1.0,
		"qi_earned_this_life": 500.0}
	_write(SLOT, JSON.stringify({"save_version": 7, "engine": v7eng, "extra": {}}))
	var loaded9: Dictionary = sm.call("load_game")
	_check(int(loaded9.get("save_version", 0)) == 13, "v7 fixture stamped to v13")
	_check((ge.get("attunement") as Dictionary).is_empty(), "v7->v8 attunement default empty")
	_check(not bool(ge.get("victorious")), "v7->v8 victory default false")
	_check(ge.call("qi_num") == 9.0, "v6 qi preserved across migration")
	_check(float(ge.get("mind")) == 66.0, "v7 mind preserved across migration")

	# 11. v8 fixture (pre-P16 schema) migrates: seclusion directive defaults
	# to vigil, everything else preserved.
	_wipe()
	var v8eng: Dictionary = {"tick_count": 19, "age_years": 40, "lifespan_years": 110,
		"qi": 7.0, "qi_per_tick": 1.0, "realm_index": 0, "qi_bottleneck": 120.0,
		"life_number": 1, "aptitude": 1.0, "total_rebirths": 0, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": [], "player_focus": "cultivate", "muted": false,
		"hints_seen": [], "nodes_visited": [],
		"roots": {}, "mind": 70.0,
		"deviation": 0, "lifespan_scars": 0,
		"herbs": 0.0, "pills": {}, "toxicity": 0.0,
		"karma": 0, "talents": {},
		"soulweapon": {}, "legacy_mult": 1.0,
		"qi_earned_this_life": 0.0,
		"attunement": {}, "victorious": false}
	_write(SLOT, JSON.stringify({"save_version": 8, "engine": v8eng, "extra": {}}))
	var loaded10: Dictionary = sm.call("load_game")
	_check(int(loaded10.get("save_version", 0)) == 13, "v8 fixture stamped to v13")
	_check(str(ge.get("offline_mortality")) == "vigil", "v8->v9 seclusion defaults vigil")
	_check(ge.call("qi_num") == 7.0, "v8 qi preserved across migration")

	# 11b. v9 fixture (pre-P19a float Qi) migrates: economy floats become
	# {m, e} dicts in the payload, values preserved across the wire.
	_wipe()
	var v9eng: Dictionary = {"tick_count": 21, "age_years": 30, "lifespan_years": 110,
		"qi": 4242.0, "qi_per_tick": 2.0, "realm_index": 1, "qi_bottleneck": 4260.0,
		"life_number": 2, "aptitude": 1.25, "total_rebirths": 1, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": [], "player_focus": "cultivate", "muted": false,
		"hints_seen": [], "nodes_visited": [],
		"roots": {}, "mind": 70.0,
		"deviation": 0, "lifespan_scars": 0,
		"herbs": 0.0, "pills": {}, "toxicity": 0.0,
		"karma": 0, "talents": {},
		"soulweapon": {}, "legacy_mult": 1.0,
		"qi_earned_this_life": 500.0,
		"attunement": {}, "victorious": false,
		"offline_mortality": "vigil"}
	_write(SLOT, JSON.stringify({"save_version": 9, "engine": v9eng, "extra": {}}))
	var loaded11: Dictionary = sm.call("load_game")
	_check(int(loaded11.get("save_version", 0)) == 13, "v9 fixture stamped to v13")
	_check(((loaded11.get("engine", {}) as Dictionary).get("qi") as Dictionary).has("m"), "v9->v10 qi stored as Big dict")
	_check(ge.call("qi_num") == 4242.0, "v9 qi preserved across migration")
	_check(ge.call("earned_num") == 500.0, "v9 earnings preserved across migration")

	# 11c. v10 fixture (pre-P21, no coach flag) migrates: coach_done fills
	# false, everything else preserved.
	_wipe()
	var v10eng: Dictionary = {"tick_count": 22, "age_years": 30, "lifespan_years": 110,
		"qi": {"m": 4.242, "e": 3}, "qi_per_tick": 2.0, "realm_index": 1, "qi_bottleneck": 4260.0,
		"life_number": 2, "aptitude": 1.25, "total_rebirths": 1, "time_scale": 1.0,
		"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
		"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
		"techniques": {}, "beasts": {}, "route": [],
		"pause_before_death_years": 0,
		"gear": {}, "sect": {}, "disciples": [],
		"focus_technique": "", "map_seed": -1, "current_node": "",
		"achievements": [], "player_focus": "cultivate", "muted": false,
		"hints_seen": [], "nodes_visited": [],
		"roots": {}, "mind": 70.0,
		"deviation": 0, "lifespan_scars": 0,
		"herbs": 0.0, "pills": {}, "toxicity": 0.0,
		"karma": 0, "talents": {},
		"soulweapon": {}, "legacy_mult": 1.0,
		"qi_earned_this_life": 500.0, "qi_earned_total": 600.0,
		"dao_marks": 0, "dao_nodes": {}, "dao_ascensions": 0,
		"milestones_seen": [], "attunement": {}, "victorious": false,
		"offline_mortality": "vigil"}
	_write(SLOT, JSON.stringify({"save_version": 10, "engine": v10eng, "extra": {}}))
	var loaded12: Dictionary = sm.call("load_game")
	_check(int(loaded12.get("save_version", 0)) == 13, "v10 fixture stamped to v13")
	_check(not bool(ge.get("coach_done")), "v10->v11 coach defaults unseen")
	_check(ge.call("qi_num") == 4242.0, "v10 qi preserved across migration")

	# 12. Offline behaviors: zero, cap, pooling, vigil, unfettered, validation.
	var now: int = 1000000
	_check(bool(sm.call("apply_offline", now, now).get("skipped", false)), "zero elapsed skips silently")
	ge.set("offline_mortality", "unfettered")
	var rcap: Dictionary = sm.call("apply_offline", now - 30 * 3600, now)
	_check(int(rcap.get("months", -1)) == 28800, "away capped at 8h of months")
	ge.set("qi", 0.0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("realm_index", 0)
	ge.set("age_years", 30)
	ge.set("lifespan_years", 110)
	var rpool: Dictionary = sm.call("apply_offline", now - 200, now)
	_check(ge.call("qi_num") >= 120.0, "offline pools past bottleneck")
	_check(int(ge.get("realm_index")) == 0, "offline never skips a gate")
	_check(not bool(rpool.get("vigil", true)), "no vigil far from death")
	# Vigil stalls at death's door with years unspent.
	ge.set("age_years", 59)
	ge.set("lifespan_years", 60)
	ge.set("_month_accum", 0)
	ge.set("offline_mortality", "vigil")
	var rvig: Dictionary = sm.call("apply_offline", now - 3600, now)
	_check(int(ge.get("age_years")) < 60, "vigil never dies offline")
	_check(bool(rvig.get("vigil", false)), "vigil reported")
	_check(int(rvig.get("months", 99999)) < 3600, "vigil leaves time unspent")
	# Unfettered resolves death unseen and banks karma.
	ge.set("age_years", 59)
	ge.set("lifespan_years", 60)
	ge.set("_month_accum", 0)
	ge.set("realm_index", 5)
	ge.set("qi_earned_this_life", 1000000.0)
	ge.set("achievements", ["a", "b"])
	ge.set("offline_mortality", "unfettered")
	var l0: int = int(ge.get("life_number"))
	var runf: Dictionary = sm.call("apply_offline", now - 3600, now)
	_check(int(ge.get("life_number")) > l0, "unfettered dies offline")
	_check(int(ge.get("karma")) > 0, "unfettered banks karma")
	_check(not bool(runf.get("vigil", true)), "unfettered never vigils")
	# Directive validation refuses unknowns.
	_check(not bool(ge.call("set_offline_mortality", "lich")), "unknown directive refused")
	_check(str(ge.get("offline_mortality")) == "unfettered", "refusal keeps state")

	# P17-Step3: export/import round-trip through temp paths.
	var XP := "user://export_probe_tmp.json"
	if FileAccess.file_exists(XP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XP))
	ge.set("qi", 4242.0)
	_check(bool(sm.call("save_game")), "export source saved")
	_check(bool(sm.call("export_save", XP)), "export writes outside file")
	_check(FileAccess.file_exists(XP), "export file exists")
	ge.set("qi", 0.0)
	var back: Dictionary = sm.call("import_save", XP)
	_check(not back.is_empty(), "import returns payload")
	_check(ge.call("qi_num") == 4242.0, "import restores state")
	_check(sm.call("import_save", "user://nope-missing.json").is_empty(), "missing import refuses")
	_write(XP, "not json{{{")
	_check(sm.call("import_save", XP).is_empty(), "corrupt import refuses")
	if FileAccess.file_exists(XP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(XP))

	_wipe()
	ge.queue_free()
	sm.queue_free()
	if _failures == 0:
		print("SAVE-ROBUSTNESS PASS")
	else:
		printerr("SAVE-ROBUSTNESS FAIL count=", _failures)
	quit(_failures)
