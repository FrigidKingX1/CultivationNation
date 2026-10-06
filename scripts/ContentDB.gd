extends Node
## ContentDB autoload — loads data/*.json, validates schema. Original code.
## Authored content lives in data files; saves store only IDs.

var realms: Array = []
var origins: Array = []
var techniques: Array = []
var beasts: Array = []
var gear: Array = []
var achievements: Array = []
var prestige: Array = []
var reveal: Array = []
var guardians: Array = []
var zones3d: Array = []
var flight: Dictionary = {}
var leylines: Array = []
var loaded: bool = false

func _ready() -> void:
	load_all()

func load_all() -> bool:
	realms = _load_json_array("res://data/realms.json")
	origins = _load_json_array("res://data/origins.json")
	techniques = _load_json_array("res://data/techniques.json")
	beasts = _load_json_array("res://data/beasts.json")
	gear = _load_json_array("res://data/gear.json")
	achievements = _load_json_array("res://data/achievements.json")
	prestige = _load_json_array("res://data/prestige.json")
	reveal = _load_json_array("res://data/reveal.json")
	guardians = _load_json_array("res://data/guardians.json")
	zones3d = _load_json_array("res://data/zones3d.json")
	flight = _load_json_dict("res://data/flight.json")
	leylines = _load_json_array("res://data/leylines.json")
	loaded = true
	return validate()

func gear_defs() -> Dictionary:
	var defs: Dictionary = {}
	for g in gear:
		defs[str((g as Dictionary).get("id", ""))] = {
			"base_mult": float((g as Dictionary).get("base_mult", 0.0)),
			"max_level": int((g as Dictionary).get("max_level", 0)),
		}
	return defs

func gear_entry(id: String) -> Dictionary:
	for g in gear:
		if str((g as Dictionary).get("id", "")) == id:
			return g
	return {}

func beast_ids_in_order() -> Array:
	var ids: Array = []
	for b in beasts:
		ids.append(str(b.get("id", "")))
	return ids

func origin_by_id(id: String) -> Dictionary:
	for o in origins:
		if str(o.get("id", "")) == id:
			return o
	return {}

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	return []

func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_ARRAY and not (parsed as Array).is_empty():
		return (parsed as Array)[0]
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

func validate() -> bool:
	for r in realms:
		if not (r.has("id") and r.has("name") and r.has("qi_required") and r.has("macro_tier") and r.has("macro_name") and r.has("lifespan") and r.has("waves") and r.has("trib_power")):
			push_error("ContentDB: bad realm entry")
			return false
	for o in origins:
		if not (o.has("id") and o.has("name") and o.has("qi_mult") and o.has("lifespan_bonus")):
			push_error("ContentDB: bad origin entry")
			return false
	for t in techniques:
		if not (t.has("id") and t.has("name") and t.has("curve") and t.has("wear") and t.has("perk")):
			push_error("ContentDB: bad technique entry")
			return false
	for b in beasts:
		if not (b.has("id") and b.has("name") and b.has("zone") and b.has("element") and b.has("power") and b.has("min_realm")):
			push_error("ContentDB: bad beast entry")
			return false
	for g in gear:
		if not (g.has("id") and g.has("name") and g.has("base_mult") and g.has("max_level")):
			push_error("ContentDB: bad gear entry")
			return false
	for a in achievements:
		if not (a.has("id") and a.has("name") and a.has("desc") and a.has("stat") and a.has("value")):
			push_error("ContentDB: bad achievement entry")
			return false
	for p in prestige:
		if not (p.has("id") and p.has("name") and p.has("desc") and p.has("max") and p.has("effect")):
			push_error("ContentDB: bad prestige entry")
			return false
	for r in reveal:
		if not (r.has("tab") and r.has("stat") and r.has("value") and r.has("line")):
			push_error("ContentDB: bad reveal entry")
			return false
	for g in guardians:
		if not (g.has("id") and g.has("name") and g.has("tier") and g.has("guard_realm") and g.has("power") and g.has("waves") and g.has("reward_mult")):
			push_error("ContentDB: bad guardian entry")
			return false
		if not str((g as Dictionary).get("id", "")).begins_with("guardian_"):
			push_error("ContentDB: guardian id must use guardian_ prefix")
			return false
	# P23: zone-id set and gate values are owned by beasts.json; zones3d
	# carries consistent copies only (single source of truth stays put).
	var gate_by_zone: Dictionary = {}
	for b in beasts:
		var z: String = str((b as Dictionary).get("zone", ""))
		var m: int = int((b as Dictionary).get("min_realm", 0))
		if not gate_by_zone.has(z) or m < int(gate_by_zone[z]):
			gate_by_zone[z] = m
	for z3 in zones3d:
		if not (z3.has("id") and z3.has("island_seed") and z3.has("size_radius") and z3.has("height_amp") and z3.has("palette") and z3.has("gate") and z3.has("spawn") and z3.has("weather") and z3.has("props")):
			push_error("ContentDB: bad zones3d entry")
			return false
		var zid: String = str((z3 as Dictionary).get("id", ""))
		if not gate_by_zone.has(zid):
			push_error("ContentDB: zones3d id outside beasts zones")
			return false
		var zg: Dictionary = (z3 as Dictionary).get("gate", {})
		if int(zg.get("min_realm", -1)) != int(gate_by_zone[zid]):
			push_error("ContentDB: zones3d gate disagrees with beasts data")
			return false
		var pal: Dictionary = (z3 as Dictionary).get("palette", {})
		for k in ["low", "mid", "high", "accent", "fog", "sky_tint"]:
			if not pal.has(k):
				push_error("ContentDB: zones3d palette incomplete")
				return false
		var wth: Dictionary = (z3 as Dictionary).get("weather", {})
		for k in ["spring", "summer", "autumn", "winter"]:
			if not wth.has(k):
				push_error("ContentDB: zones3d weather incomplete")
				return false
	if zones3d.size() != gate_by_zone.size():
		push_error("ContentDB: zones3d zone set must match beasts zones")
		return false
	# P24b: flight unlock rule (reveal.json pattern: stat-gated, data-owned).
	if not (flight.has("unlock") and flight.has("stat") and flight.has("value") and flight.has("line")):
		push_error("ContentDB: bad flight entry")
		return false
	if not realms.is_empty() and (int(flight.get("value", -1)) < 0 or int(flight.get("value", -1)) >= realms.size()):
		push_error("ContentDB: flight unlock realm outside the ladder")
		return false
	# 0.26b: ley-line channels — exactly 8, immutable sequence, floors on
	# the ladder, costs positive + monotonic. Unknown fields reject.
	var want_ids: Array = ["leyline_01", "leyline_02", "leyline_03", "leyline_04", "leyline_05", "leyline_06", "leyline_07", "leyline_08"]
	if leylines.size() != 8:
		push_error("ContentDB: leylines must hold exactly 8 channels")
		return false
	var prev_cost: float = 0.0
	for i in range(leylines.size()):
		var c: Dictionary = leylines[i]
		for k in c:
			if not ["id", "channel", "name", "floor", "floor_realm", "cost"].has(str(k)):
				push_error("ContentDB: leyline has unknown field")
				return false
		if not (c.has("id") and c.has("channel") and c.has("name") and c.has("floor") and c.has("floor_realm") and c.has("cost")):
			push_error("ContentDB: bad leyline entry")
			return false
		if str(c.get("id", "")) != str(want_ids[i]):
			push_error("ContentDB: leyline sequence is immutable")
			return false
		if not realms.is_empty() and (int(c.get("floor", -1)) < 0 or int(c.get("floor", -1)) >= realms.size()):
			push_error("ContentDB: leyline floor outside the ladder")
			return false
		var cost: float = float(c.get("cost", 0.0))
		if cost <= 0.0 or cost <= prev_cost:
			push_error("ContentDB: leyline costs must be positive + monotonic")
			return false
		prev_cost = cost
	return true
