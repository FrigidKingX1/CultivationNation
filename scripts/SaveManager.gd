extends Node
## SaveManager autoload — versioned JSON saves, backup, offline progress. Original code.
## Stores only IDs/flags/stats, never authored text (avoids CoFD browser-limit failure mode).

const SAVE_VERSION: int = 14
const SLOT_PATH: String = "user://cultivation_nation_save.json"
const BACKUP_PATH: String = "user://cultivation_nation_save.bak.json"
const OFFLINE_CAP_SECONDS: int = 8 * 3600

# Explicit engine reference. Set by Main.gd at runtime and by headless tests.
# Avoids absolute-path get_node() which is illegal outside the active scene tree.
var engine_ref: Node = null

func _engine() -> Node:
	if engine_ref != null:
		return engine_ref
	if is_inside_tree():
		if has_node("/root/GameEngine"):
			return get_node("/root/GameEngine")
	return null

func save_game(extra: Dictionary = {}) -> bool:
	var payload: Dictionary = {
		"save_version": SAVE_VERSION,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"engine": {},
		"extra": extra,
	}
	var ge: Node = _engine()
	if ge != null and ge.has_method("get_state"):
		payload["engine"] = ge.call("get_state")
	var text: String = JSON.stringify(payload)
	# Rotate backup first (cheap insurance, per CoFD lesson).
	if FileAccess.file_exists(SLOT_PATH):
		var old: FileAccess = FileAccess.open(SLOT_PATH, FileAccess.READ)
		if old != null:
			var old_text: String = old.get_as_text()
			old.close()
			var bak: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if bak != null:
				bak.store_string(old_text)
				bak.close()
	var f: FileAccess = FileAccess.open(SLOT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open save for write")
		return false
	f.store_string(text)
	f.close()
	return true

func export_save(path: String) -> bool:
	## P17-Step3: copy the live slot to an outside path (Documents picker in
	## the UI; direct paths in tests). Returns success, never throws.
	if not FileAccess.file_exists(SLOT_PATH):
		return false
	var src: FileAccess = FileAccess.open(SLOT_PATH, FileAccess.READ)
	if src == null:
		return false
	var text: String = src.get_as_text()
	src.close()
	var dst: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_string(text)
	dst.close()
	return true

func import_save(path: String) -> Dictionary:
	## P17-Step3: replace the slot from an outside file (backup rotation
	## first, like save_game), migrate, apply, and return the payload —
	## or {} when the file is missing or corrupt (slot untouched then).
	if not FileAccess.file_exists(path):
		return {}
	var src: FileAccess = FileAccess.open(path, FileAccess.READ)
	if src == null:
		return {}
	var text: String = src.get_as_text()
	src.close()
	if typeof(JSON.parse_string(text)) != TYPE_DICTIONARY:
		return {}
	if FileAccess.file_exists(SLOT_PATH):
		var old: FileAccess = FileAccess.open(SLOT_PATH, FileAccess.READ)
		if old != null:
			var old_text: String = old.get_as_text()
			old.close()
			var bak: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if bak != null:
				bak.store_string(old_text)
				bak.close()
	var dst: FileAccess = FileAccess.open(SLOT_PATH, FileAccess.WRITE)
	if dst == null:
		return {}
	dst.store_string(text)
	dst.close()
	return load_game()

func load_game() -> Dictionary:
	for path in [SLOT_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var text: String = f.get_as_text()
		f.close()
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = parsed
		if not d.has("save_version"):
			continue
		_migrate(d)
		if d.has("engine") and typeof(d["engine"]) == TYPE_DICTIONARY:
			var ge2: Node = _engine()
			if ge2 != null and ge2.has_method("apply_state"):
				ge2.call("apply_state", d["engine"])
		return d
	return {}

func _migrate(d: Dictionary) -> void:
	# v0 -> v1: old fixtures used flat legacy keys (age, qi) and no time_scale.
	# Maps them onto current schema, fills defaults, stamps v1. Chain future
	# migrations here (v1 -> v2 ...), never by editing old saves in place.
	var ver: int = int(d.get("save_version", 0))
	if ver < 1:
		var eng: Dictionary = {}
		if d.has("engine") and typeof(d["engine"]) == TYPE_DICTIONARY:
			eng = d["engine"]
			if eng.has("age") and not eng.has("age_years"):
				eng["age_years"] = int(eng["age"])
				eng.erase("age")
			# qi key name unchanged; ensure numeric.
			if eng.has("qi"):
				eng["qi"] = float(eng["qi"])
		d["engine"] = eng
		if not d.has("extra"):
			d["extra"] = {}
	if ver < 2:
		# v1 -> v2: P3 systems. Fill defaults; never touch existing keys.
		var eng2: Dictionary = d.get("engine", {})
		var defaults: Dictionary = {
			"origin_id": "origin_wayfarer", "origin_qi_mult": 1.0,
			"origin_lifespan_bonus": 0, "dantian_purity": 80.0,
			"techniques": {}, "beasts": {}, "route": [],
			"pause_before_death_years": 0,
		}
		for k in defaults:
			if not eng2.has(k):
				eng2[k] = defaults[k]
		d["engine"] = eng2
	if ver < 3:
		# v2 -> v3: P4 expansion (gear, sect, map). Fill defaults only.
		var eng3: Dictionary = d.get("engine", {})
		var defaults3: Dictionary = {
			"gear": {}, "sect": {}, "disciples": [],
			"focus_technique": "", "map_seed": -1, "current_node": "",
		}
		for k in defaults3:
			if not eng3.has(k):
				eng3[k] = defaults3[k]
		d["engine"] = eng3
	if ver < 4:
		# v3 -> v4: P5 achievements. Fill defaults only.
		var eng4: Dictionary = d.get("engine", {})
		if not eng4.has("achievements"):
			eng4["achievements"] = []
		d["engine"] = eng4
	if ver < 5:
		# v4 -> v5: P6 player focus + mute. Fill defaults only.
		var eng5: Dictionary = d.get("engine", {})
		if not eng5.has("player_focus"):
			eng5["player_focus"] = "cultivate"
		if not eng5.has("muted"):
			eng5["muted"] = false
		d["engine"] = eng5
	if ver < 6:
		# v5 -> v6: P8 hints + visitation. Fill defaults only.
		var eng6: Dictionary = d.get("engine", {})
		if not eng6.has("hints_seen"):
			eng6["hints_seen"] = []
		if not eng6.has("nodes_visited"):
			eng6["nodes_visited"] = []
		d["engine"] = eng6
	if ver < 7:
		# v6 -> v7: P12 cultivation systems. One bump for all P12 keys
		# (roots through legacy) rather than one migration per subsystem.
		var eng7: Dictionary = d.get("engine", {})
		var defaults7: Dictionary = {
			"roots": {}, "mind": 70.0,
			"deviation": 0, "lifespan_scars": 0,
			"herbs": 0.0, "pills": {}, "toxicity": 0.0,
			"karma": 0, "talents": {},
			"soulweapon": {}, "legacy_mult": 1.0,
			"qi_earned_this_life": 0.0,
		}
		for k in defaults7:
			if not eng7.has(k):
				eng7[k] = defaults7[k]
		d["engine"] = eng7
	if ver < 8:
		# v7 -> v8: P15 depth pass. One bump for all P15 keys (attunement
		# now, victorious for the Step 3 endgame) rather than per-slice bumps.
		var eng8: Dictionary = d.get("engine", {})
		var defaults8: Dictionary = {"attunement": {}, "victorious": false}
		for k in defaults8:
			if not eng8.has(k):
				eng8[k] = defaults8[k]
		d["engine"] = eng8
	if ver < 9:
		# v8 -> v9: P16 seclusion directive. Old saves default to vigil.
		var eng9: Dictionary = d.get("engine", {})
		if not eng9.has("offline_mortality"):
			eng9["offline_mortality"] = "vigil"
		d["engine"] = eng9
	if ver < 10:
		# v9 -> v10: P19a true big math. Qi-economy floats become {m, e}
		# save-dicts. Fill-defaults only; apply_state also accepts legacy
		# floats, so half-migrated payloads still load.
		var eng10: Dictionary = d.get("engine", {})
		var BN: GDScript = load("res://scripts/BigNumber.gd")
		for k in ["qi", "qi_per_tick", "qi_bottleneck", "qi_earned_this_life"]:
			if eng10.has(k) and not (eng10[k] is Dictionary):
				eng10[k] = BN.of(eng10[k]).to_save()
		d["engine"] = eng10
	if ver < 11:
		# v10 -> v11: P21 coach dismissal. Old saves never saw the coach.
		var eng11: Dictionary = d.get("engine", {})
		if not eng11.has("coach_done"):
			eng11["coach_done"] = false
		d["engine"] = eng11
	if ver < 12:
		# v11 -> v12: P22 guardians. Old saves never met the wardens.
		# Fill-defaults only; the roster starts empty and undefeated.
		var eng12: Dictionary = d.get("engine", {})
		if not eng12.has("guardians"):
			eng12["guardians"] = {"defeated": [], "attempts": {}}
		d["engine"] = eng12
	if ver < 13:
		# v12 -> v13: P26 stakes. Old saves never pledged: preference
		# defaults to composed, no heaven marks. Fill-defaults only.
		var eng13: Dictionary = d.get("engine", {})
		if not eng13.has("stakes_preference"):
			eng13["stakes_preference"] = "composed"
		if not eng13.has("heaven_marks"):
			eng13["heaven_marks"] = 0
		d["engine"] = eng13
	if ver < 14:
		# v13 -> v14: 0.26b ley-line attunement. Old saves never opened a
		# channel. Fill-defaults only.
		var eng14: Dictionary = d.get("engine", {})
		if not eng14.has("leyline_open"):
			eng14["leyline_open"] = 0
		d["engine"] = eng14
	d["save_version"] = SAVE_VERSION

func apply_offline(saved_unix: int, now_unix: int = -1) -> Dictionary:
	## P16-Step1: resolves away-time by running real _step_ticks (1 tick =
	## 1 month per real second), capped at OFFLINE_CAP_SECONDS. No attempts
	## fire offline, so bottlenecks and layers are honored trivially — Qi
	## pools, gates wait for the player's return. Deaths follow the engine's
	## mortality directive (vigil stalls at death's door, unfettered resolves
	## unseen). Returns a report dict for the welcome-back summary.
	## Headless-safe; deterministic given its inputs.
	var rep: Dictionary = {"away_seconds": 0, "months": 0, "qi": 0.0, "deaths": 0, "vigil": false, "skipped": true}
	var ge: Node = _engine()
	if ge == null:
		return rep
	var now_t: int = now_unix
	if now_t < 0:
		now_t = int(Time.get_unix_time_from_system())
	var away: int = maxi(0, now_t - saved_unix)
	var capped: int = mini(away, OFFLINE_CAP_SECONDS)
	rep["away_seconds"] = capped
	if capped < 60:
		return rep
	var start_life: int = int(ge.get("life_number"))
	var remaining: int = capped
	var vigil: bool = str(ge.get("offline_mortality")) != "unfettered"
	while remaining > 0:
		if vigil and bool(ge.call("death_looms")):
			rep["vigil"] = true
			break
		ge.call("_step_tick")
		remaining -= 1
	rep["months"] = capped - remaining
	rep["qi"] = ge.call("qi_num")
	rep["deaths"] = int(ge.get("life_number")) - start_life
	rep["skipped"] = false
	return rep

func compute_offline_gains(saved_unix: int, now_unix: int, qi_per_second: float) -> Dictionary:
	var away: int = maxi(0, now_unix - saved_unix)
	away = mini(away, OFFLINE_CAP_SECONDS)
	return {"away_seconds": away, "bonus_qi": float(away) * qi_per_second}
