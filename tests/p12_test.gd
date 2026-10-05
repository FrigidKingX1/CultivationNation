extends SceneTree
## P12 cultivation-systems test: roots, mind, seasons, layers, labels, lifespan.
## Run: --headless -s res://tests/p12_test.gd (exit 0 = pass).
## Extended per P12 phase (waves, alchemy, karma...); each slice adds checks.

var _failures: int = 0

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	return ge

func _realms() -> Array:
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _beasts() -> Array:
	var f: FileAccess = FileAccess.open("res://data/beasts.json", FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

func _initialize() -> void:
	print("P12-TEST start")
	# QA Round 1: fresh boot required (see p10/p17 guard).
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _press(path: String) -> void:
	## P17-Step3: tab homes for management boxes.
	var moved: Dictionary = {
		"PillBox/Brew_pill_prep": "UI/Root/SidePanel/PanelScroll/PanelTabs/Alchemy/PillBox/RowBrew_pill_prep/Brew_pill_prep",
		"PillBox/Drink_pill_prep": "UI/Root/SidePanel/PanelScroll/PanelTabs/Alchemy/PillBox/Drink_pill_prep",
		"TalentBox/Talent_talent_roots": "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/TalentBox/RowTalent_talent_roots/Talent_talent_roots",
		"SoulBox/Soul_soul_blade": "UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/SoulBox/Soul_soul_blade",
	}
	(_scene_main.get_node(str(moved.get(path, path))) as BaseButton).emit_signal("pressed")

func _process(_delta: float) -> bool:
	# Ready-delivery rule (project convention): nodes added during _initialize
	# get _ready on the first frame flush, so all assertions run frame-driven.
	_frames += 1
	if _stage == 0 and _frames >= 1:
		_test_roots()
		_test_env()
		_test_mind()
		_test_seasons()
		_test_layers()
		_test_labels_lifespan()
		_test_waves()
		_test_alchemy()
		_test_samsara()
		_test_zones()
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 2:
		_test_pill_ui_ready()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 1:
		_test_pill_ui_press()
		_stage = 3
		_frames = 0
	elif _stage == 3 and _frames >= 1:
		_test_pill_ui_drink()
		if _failures == 0:
			print("P12-TEST PASS")
		else:
			printerr("P12-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("P12-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_pill_ui_ready() -> void:
	_check(_scene_main.is_node_ready(), "scene ready delivered")
	var box: Node = _scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Alchemy/PillBox")
	_check(box != null, "pillbox exists")
	_check(_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/SoulBox") != null, "soulbox exists")
	_check(_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/TalentBox") != null, "talentbox exists")
	var ge: Node = root.get_node("GameEngine")
	ge.set("herbs", 100.0)
	ge.set("karma", 100)
	_scene_main.call("_refresh_pills")
	_scene_main.call("_refresh_talents")

func _test_pill_ui_press() -> void:
	_press("PillBox/Brew_pill_prep")
	var ge: Node = root.get_node("GameEngine")
	_check(int((ge.get("pills") as Dictionary).get("pill_prep", 0)) == 1, "brew button stocks shelf")
	_scene_main.call("_refresh_pills")

func _test_pill_ui_drink() -> void:
	_press("PillBox/Drink_pill_prep")
	var ge: Node = root.get_node("GameEngine")
	_check(float(ge.get("_prep_power")) == 1.25, "drink button charges prep")
	_press("TalentBox/Talent_talent_roots")
	_check(int(ge.call("talent_level", "talent_roots")) == 1, "talent button buys rank")
	_check(int(ge.get("karma")) == 90, "talent button spends 10 karma")
	_press("SoulBox/Soul_soul_blade")
	_check(str((ge.get("soulweapon") as Dictionary).get("path", "")) == "soul_blade", "soul button binds path")

func _test_roots() -> void:
	var ge: Node = _new_engine()
	# Fresh life rolls fated affinities over the 5 elements summing to 1.5.
	var roots: Dictionary = ge.get("roots")
	_check(roots.size() == 5, "roots cover 5 elements")
	var total: float = 0.0
	for el in roots:
		total += float(roots[el])
	_check(absf(total - 1.5) < 1e-9, "roots sum to 1.5")
	# Deterministic per seed: same seed reproduces exactly.
	ge.call("roll_roots", 4242)
	var a: Dictionary = (ge.get("roots") as Dictionary).duplicate()
	ge.call("roll_roots", 4242)
	var b: Dictionary = ge.get("roots")
	_check(str(a) == str(b), "root roll deterministic per seed")
	# New life, new fate: rebirth re-rolls from the life number.
	ge.call("roll_roots", 1 * 7919 + 13)
	var life1: Dictionary = (ge.get("roots") as Dictionary).duplicate()
	ge.call("rebirth")
	_check(str(ge.get("roots")) != str(life1), "rebirth re-rolls roots")
	var ge2: Node = _new_engine()
	ge2.call("roll_roots", 2 * 7919 + 13)
	_check(str(ge.get("roots")) == str(ge2.get("roots")), "life-2 fate reproducible")
	ge.queue_free()
	ge2.queue_free()

func _test_env() -> void:
	var ge: Node = _new_engine()
	ge.call("set_beast_pool", _beasts())
	ge.call("generate_map", 7)
	# No node, no sympathy.
	_check(float(ge.get("_env_mult")) == 1.0, "env neutral without grounds")
	# Fixed affinity on matching water grounds (Dewfield, gate 0).
	ge.set("roots", {"water": 0.5})
	var dew: String = ""
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) == "Dewfield":
			dew = str((n as Dictionary).get("id", ""))
			break
	_check(dew != "" and bool(ge.call("travel_to", dew)), "walk dewfield grounds")
	_check(float(ge.get("_env_mult")) == 1.5, "matching grounds add affinity")
	ge.queue_free()

func _test_mind() -> void:
	var ge: Node = _new_engine()
	_check(int(ge.call("mind_stage")) == 0, "fresh heart serene")
	_check(float(ge.call("mind_mult")) == 1.25, "serene 1.25x")
	ge.set("mind", 50.0)
	_check(int(ge.call("mind_stage")) == 1, "mid heart steady")
	_check(float(ge.call("mind_mult")) == 1.0, "steady 1.0x")
	ge.set("mind", 10.0)
	_check(int(ge.call("mind_stage")) == 2, "worn heart strained")
	_check(float(ge.call("mind_mult")) == 0.8, "strained 0.8x (bounded)")
	# P13-B5: drilling strains (-1 per 30 drill-ticks); breathing calms.
	ge.set("mind", 70.0)
	ge.set("focus_technique", "pace_art")
	ge.call("set_focus", "train")
	for i in range(30):
		ge.call("_step_tick")
	_check(float(ge.get("mind")) == 69.0, "drilling strains mind")
	ge.call("set_focus", "cultivate")
	for i in range(24):
		ge.call("_step_tick")
	_check(float(ge.get("mind")) == 70.0, "breathing calms mind")
	# Wilderness air eases: +1 per 12 hunt-ticks abroad. (First visit also
	# grants +8 exploration rest, so the dial is reset before measuring ease.)
	ge.call("set_beast_pool", _beasts())
	ge.call("generate_map", 7)
	var dew: String = str((ge.get("map_nodes") as Array)[0].get("id", ""))
	ge.call("travel_to", dew)
	ge.set("mind", 69.0)
	ge.call("set_focus", "hunt")
	for i in range(12):
		ge.call("_step_tick")
	_check(float(ge.get("mind")) == 70.0, "hunt abroad eases mind")
	# Surviving the heavens settles the heart (+25).
	ge.set("mind", 70.0)
	ge.set("qi", 200.0)
	ge.set("qi_bottleneck", 120.0)
	ge.call("attempt_breakthrough", 10.0, 5.0)
	_check(float(ge.get("mind")) == 95.0, "breakthrough settles mind")
	ge.queue_free()

func _test_seasons() -> void:
	var ge: Node = _new_engine()
	ge.set("_month_accum", 0)
	_check(int(ge.call("season_index")) == 0, "month 0 spring")
	_check("Spring" in str(ge.call("season_label")), "spring label")
	ge.set("_month_accum", 4)
	_check(int(ge.call("season_index")) == 1, "month 4 summer")
	_check(float(ge.call("technique_power_bonus", "tech_stillwater")) == 1.1, "summer drills hotter")
	ge.set("_month_accum", 8)
	_check(int(ge.call("season_index")) == 2, "month 8 autumn")
	ge.set("_month_accum", 10)
	_check(int(ge.call("season_index")) == 3, "month 10 winter")
	_check(float(ge.call("season_power_bonus")) == 1.1, "winter favors defender")
	ge.set("_month_accum", 0)
	_check(float(ge.call("season_power_bonus")) == 1.0, "spring no power bonus")
	ge.queue_free()

func _test_layers() -> void:
	var ge: Node = _new_engine()
	_check(int(ge.call("layer_index_for", 0.0, 120.0)) == 0, "empty early")
	_check(int(ge.call("layer_index_for", 40.0, 120.0)) == 1, "third mid")
	_check(int(ge.call("layer_index_for", 80.0, 120.0)) == 2, "two-thirds late")
	_check(int(ge.call("layer_index_for", 120.0, 120.0)) == 2, "full late")
	# Late-layer gate: below 2/3 the attempt is refused outright.
	ge.set("qi", 79.0)
	ge.set("qi_bottleneck", 120.0)
	_check(not bool(ge.call("attempt_breakthrough", 999.0, 1.0)), "early attempt refused")
	ge.set("qi", 80.0)
	_check(bool(ge.call("attempt_breakthrough", 999.0, 1.0)), "late attempt opens")
	ge.queue_free()

func _test_waves() -> void:
	var ge: Node = _new_engine()
	ge.call("set_realm_table", _realms())
	# Tier-1 internal trial: no waves, quality from fill alone.
	var f0: Dictionary = ge.call("forecast_quality", 10.0, 5.0, 1.0, 1.0)
	_check(str(f0.get("quality", "")) == "Radiant", "full T1 trial radiant")
	_check((f0.get("waves", []) as Array).is_empty(), "T1 trial wavless")
	var f1: Dictionary = ge.call("forecast_quality", 10.0, 5.0, 1.0, 0.8)
	_check(str(f1.get("quality", "")) == "Steady", "partial T1 trial steady")
	# Realm 8 (tier 2, 3 waves, trib_power 45): overwhelming force is clean.
	ge.set("realm_index", 8)
	var fr: Dictionary = ge.call("forecast_quality", 99.0, 45.0, 1.0, 1.0)
	_check((fr.get("waves", []) as Array).size() == 3, "three waves logged")
	_check(str(fr.get("quality", "")) == "Radiant", "overwhelm radiant")
	_check(float(fr.get("leak", -1.0)) == 0.0, "overwhelm no leak")
	# Measured force endures; thin force buckles.
	var fs: Dictionary = ge.call("forecast_quality", 50.0, 45.0, 1.0, 1.0)
	_check(str(fs.get("quality", "")) == "Steady", "measured force steady")
	var fh: Dictionary = ge.call("forecast_quality", 35.0, 45.0, 1.0, 1.0)
	_check(str(fh.get("quality", "")) == "Shaky", "thin force shaky")
	# A ward doubles the shield: thin force holds clean.
	var fw: Dictionary = ge.call("forecast_quality", 35.0, 45.0, 1.0, 1.0, 2.0)
	_check(str(fw.get("quality", "")) == "Radiant", "ward saves thin force")
	# Radiant baptism washes all flaws; Steady eases one.
	ge.set("qi", 120.0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("deviation", 2)
	ge.call("attempt_breakthrough", 99.0, 45.0)
	_check(str(ge.get("last_quality")) == "Radiant", "attempt records radiant")
	_check(int(ge.get("deviation")) == 0, "radiant washes flaws")
	ge.set("realm_index", 8)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	ge.set("deviation", 2)
	ge.call("attempt_breakthrough", 50.0, 45.0)
	_check(str(ge.get("last_quality")) == "Steady", "attempt records steady")
	_check(int(ge.get("deviation")) == 1, "steady eases one flaw")
	# Sloppy crossing (strained, thin): Shaky scars years and flaws.
	ge.set("realm_index", 8)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	ge.set("mind", 10.0)
	ge.set("deviation", 0)
	ge.set("lifespan_scars", 0)
	ge.call("attempt_breakthrough", 45.0, 45.0)
	_check(str(ge.get("last_quality")) == "Shaky", "sloppy crossing shaky")
	_check(int(ge.get("deviation")) == 2, "shaky+strained flaws compound")
	# P13-B2: endured crossings flaw but never scar (scars = failures only).
	_check(int(ge.get("lifespan_scars")) == 0, "shaky scars nothing")
	# Failed gate scars too.
	ge.set("lifespan_scars", 0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	ge.call("attempt_breakthrough", 1.0, 999.0)
	_check(str(ge.get("last_quality")) == "Failed", "failed gate recorded")
	_check(int(ge.get("lifespan_scars")) == 5, "failed gate scars years")
	# Readiness is display math: 200% spring, 220% winter.
	_check(float(ge.call("readiness_pct", 10.0, 5.0, 1.0)) == 200.0, "readiness spring")
	ge.set("_month_accum", 10)
	_check(float(ge.call("readiness_pct", 10.0, 5.0, 1.0)) == 220.0, "readiness winter")
	ge.queue_free()

func _test_alchemy() -> void:
	var ge: Node = _new_engine()
	# Brewing spends herbs; unknown and unpaid recipes refuse.
	ge.set("herbs", 100.0)
	_check(bool(ge.call("brew_pill", "pill_prep")), "brew prep spends")
	_check(float(ge.get("herbs")) == 90.0, "brew deducts 10 herbs")
	_check(int((ge.get("pills") as Dictionary).get("pill_prep", 0)) == 1, "brew stocks shelf")
	_check(not bool(ge.call("brew_pill", "pill_unknown")), "unknown recipe refused")
	ge.set("herbs", 0.0)
	_check(not bool(ge.call("brew_pill", "pill_prep")), "poor cauldron refused")
	# A kindling charge decides a thin attempt, then burns out.
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 120.0)
	_check(not bool(ge.call("attempt_breakthrough", 40.0, 45.0)), "thin attempt fails uncharged")
	ge.set("qi", 120.0)
	ge.set("herbs", 100.0)
	ge.call("brew_pill", "pill_prep")
	ge.call("drink_pill", "pill_prep")
	_check(float(ge.get("_prep_power")) == 1.25, "quaff charges prep")
	_check(bool(ge.call("attempt_breakthrough", 40.0, 45.0)), "charged attempt passes")
	_check(float(ge.get("_prep_power")) == 1.0, "charge burns out")
	# Mending eases a flaw; cleansing burns residue (then stains again).
	ge.set("deviation", 2)
	ge.set("herbs", 100.0)
	ge.call("brew_pill", "pill_heal")
	ge.call("drink_pill", "pill_heal")
	_check(int(ge.get("deviation")) == 1, "mending eases flaw")
	ge.set("toxicity", 50.0)
	ge.set("herbs", 100.0)
	ge.call("brew_pill", "pill_purge")
	ge.call("drink_pill", "pill_purge")
	_check(float(ge.get("toxicity")) == 22.0, "cleansing purges then stains")
	# Warding doubles the shield for one crossing.
	ge.set("herbs", 100.0)
	ge.call("brew_pill", "pill_ward")
	ge.call("drink_pill", "pill_ward")
	_check(float(ge.get("_ward_power")) == 2.0, "warding charges shield")
	# Residue damps throughput to a 0.5x floor and sweats out at rest.
	ge.set("toxicity", 0.0)
	ge.call("_recompute_rate")
	var r0: float = ge.call("rate_num")
	ge.set("toxicity", 100.0)
	ge.call("_recompute_rate")
	_check(absf(ge.call("rate_num") - r0 * 0.5) < 1e-9, "toxicity floor 0.5x")
	ge.set("toxicity", 10.0)
	for i in range(12):
		ge.call("_step_tick")
	_check(float(ge.get("toxicity")) == 9.0, "residue sweats out")
	# The garden yields even untended; journeys purge.
	ge.set("herbs", 0.0)
	for i in range(48):
		ge.call("_step_tick")
	_check(absf(float(ge.get("herbs")) - 1.0) < 1e-9, "garden trickles")
	ge.call("set_beast_pool", _beasts())
	ge.call("generate_map", 7)
	ge.set("toxicity", 50.0)
	ge.call("travel_to", str((ge.get("map_nodes") as Array)[0].get("id", "")))
	_check(float(ge.get("toxicity")) == 30.0, "journeys purge residue")
	ge.queue_free()

func _test_samsara() -> void:
	var ge: Node = _new_engine()
	# Surface lives earn nothing; depth pays super-linearly.
	_check(int(ge.call("karma_yield")) == 0, "surface life yields nothing")
	ge.set("realm_index", 5)
	ge.set("qi_earned_this_life", 1000000.0)
	ge.set("achievements", ["a", "b"])
	var y5: int = int(ge.call("karma_yield"))
	_check(y5 > 200 and y5 < 400, "realm-5 yield sane")
	ge.set("realm_index", 10)
	var y10: int = int(ge.call("karma_yield"))
	_check(y10 > y5 * 3, "yield rewards depth")
	# Rebirth banks the yield, resets earnings, keeps the old curve.
	ge.set("realm_index", 5)
	ge.call("rebirth")
	_check(int(ge.get("karma")) == y5, "rebirth banks karma")
	_check(ge.call("earned_num") == 0.0, "earnings reset")
	_check(float(ge.get("aptitude")) == 1.25, "aptitude curve untouched")
	# Talents: polynomial costs, caps, refusals.
	ge.set("karma", 1000)
	_check(bool(ge.call("buy_talent", "talent_roots")), "buy clarity")
	_check(int(ge.call("talent_level", "talent_roots")) == 1, "clarity level 1")
	_check(int(ge.get("karma")) == 990, "first rank costs 10")
	_check(bool(ge.call("buy_talent", "talent_roots")), "buy clarity 2")
	_check(int(ge.get("karma")) == 950, "second rank costs 40")
	_check(not bool(ge.call("buy_talent", "talent_unknown")), "unknown refused")
	ge.set("karma", 0)
	_check(not bool(ge.call("buy_talent", "talent_body")), "poor refused")
	ge.set("talents", {"talent_roots": 10})
	ge.set("karma", 999999)
	# P15-Step2: ranks never cap — deep ranks are the karma sink.
	_check(bool(ge.call("buy_talent", "talent_roots")), "deep ranks never cap")
	_check(int(ge.call("talent_level", "talent_roots")) == 11, "rank 11 reached")
	_check(int(ge.get("karma")) == 999999 - 1210, "rank 11 costs 1210")
	# Clarity purifies retroactively and on every fate roll.
	ge.set("talents", {})
	ge.set("roots", {"water": 0.5})
	ge.set("karma", 1000)
	ge.call("buy_talent", "talent_roots")
	_check(absf(float((ge.get("roots") as Dictionary).get("water", 0.0)) - 0.55) < 1e-9, "clarity retroactive")
	# Body + soul ride effective power; breath lengthens years.
	ge.set("talents", {})
	_check(float(ge.call("artifact_power_bonus")) == 0.0, "no artifacts no bonus")
	ge.set("karma", 1000)
	ge.call("buy_talent", "talent_body")
	_check(float(ge.call("artifact_power_bonus")) == 2.0, "body +2 power")
	ge.set("soulweapon", {"path": "soul_blade", "xp": 40})
	_check(int(ge.call("soul_level")) == 2, "soul level from xp")
	_check(float(ge.call("artifact_power_bonus")) == 4.0, "soul +2 power")
	_check(absf(float(ge.call("readiness_pct", 8.0, 10.0, 1.0)) - 120.0) < 1e-9, "readiness counts artifacts")
	ge.set("talents", {"talent_breath": 1})
	ge.call("_recompute_lifespan")
	_check(int(ge.get("lifespan_years")) == 66, "breath lengthens 10%%")
	# One soul, one path; strikes temper it; death cannot unbind it.
	var ge2: Node = _new_engine()
	_check(bool(ge2.call("choose_soul_weapon", "soul_blade")), "first oath binds")
	_check(not bool(ge2.call("choose_soul_weapon", "soul_bell")), "second oath refused")
	_check(not bool(ge2.call("choose_soul_weapon", "soul_unknown")), "unknown path refused")
	ge2.call("set_realm_table", _realms())
	ge2.set("realm_index", 8)
	ge2.set("qi_bottleneck", 120.0)
	ge2.set("qi", 120.0)
	ge2.call("attempt_breakthrough", 99.0, 45.0)
	_check(int((ge2.get("soulweapon") as Dictionary).get("xp", -1)) == 3, "waves temper soul")
	ge2.call("rebirth")
	_check(str((ge2.get("soulweapon") as Dictionary).get("path", "")) == "soul_blade", "soul crosses death")
	# Bequest consumes the perfected, never the unfinished.
	ge.set("gear", {"gear_riverband": 5, "gear_starcompass": 1})
	_check(bool(ge.call("bequeath_gear", "gear_riverband", 5)), "perfected given")
	_check(not (ge.get("gear") as Dictionary).has("gear_riverband"), "relic consumed")
	_check(float(ge.get("legacy_mult")) == 1.02, "legacy endures")
	_check(not bool(ge.call("bequeath_gear", "gear_starcompass", 2)), "unfinished refused")
	_check(not bool(ge.call("bequeath_gear", "gear_ghost", 5)), "unknown refused")
	# Samsara state round-trips through saves.
	ge.set("karma", 7)
	var st: Dictionary = ge.call("get_state")
	_check(int(st.get("karma", -1)) == 7, "karma in state")
	_check((st.get("talents") as Dictionary).has("talent_breath"), "talents in state")
	_check((st.get("soulweapon") as Dictionary).has("path"), "soul in state")
	var ge3: Node = _new_engine()
	ge3.call("apply_state", st)
	_check(int(ge3.get("karma")) == 7, "karma survives save/load")
	_check(float(ge3.get("legacy_mult")) == 1.02, "legacy survives save/load")
	ge.queue_free()
	ge2.queue_free()
	ge3.queue_free()

func _test_zones() -> void:
	var ge: Node = _new_engine()
	ge.call("set_beast_pool", _beasts())
	ge.call("generate_map", 4242)
	_check((ge.get("map_nodes") as Array).size() == 36, "nine zones charted")
	var zones: Dictionary = {}
	for n in (ge.get("map_nodes") as Array):
		zones[str((n as Dictionary).get("zone", ""))] = true
	_check(zones.size() == 9, "nine distinct grounds")
	_check(int(ge.call("zone_gate", "beast_shalewing")) == 8, "stonehollow gate 8")
	_check(int(ge.call("zone_gate", "beast_pollentyrant")) == 40, "thornwake gate 40")
	# Deep grounds refuse the shallow, open to the deep (stonehollow mirror).
	var snode: String = ""
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) == "Stonehollow":
			snode = str((n as Dictionary).get("id", ""))
			break
	ge.set("realm_index", 7)
	_check(not bool(ge.call("travel_to", snode)), "stonehollow refused at realm 7")
	ge.set("realm_index", 8)
	_check(bool(ge.call("travel_to", snode)), "stonehollow opens at realm 8")
	# Display holds past the old ceiling: 1e36 compacts, campaign total too.
	var BN: GDScript = load("res://scripts/BigNumber.gd")
	_check(str(BN.format_hybrid(1e36)) == "1.00Ud", "display reaches Ud")
	var total: float = 0.0
	for r in _realms():
		total += float(r.get("qi_required", 0.0))
	_check(not ("e+" in str(BN.format_hybrid(total))), "50-realm total compacts")
	ge.queue_free()

func _test_labels_lifespan() -> void:
	var ge: Node = _new_engine()
	_check(str(ge.call("realm_label")) == "Realm 0 (Early)", "label falls back table-less")
	ge.call("set_realm_table", _realms())
	_check("Dustroot" in str(ge.call("realm_label")), "label names realm")
	_check("Qi Refining" in str(ge.call("realm_label")), "label names macro tier")
	# P18: fill against the wired bottleneck (front-loaded realm 1),
	# not a literal — the table owns the cost.
	ge.set("qi", ge.call("bottleneck_num"))
	_check("Late" in str(ge.call("realm_label")), "label tracks layer")
	_check(int(ge.get("lifespan_years")) == 110, "tier-1 lifespan 110")
	ge.set("realm_index", 8)
	ge.call("_recompute_lifespan")
	_check(int(ge.get("lifespan_years")) == 250, "tier-2 lifespan 250")
	ge.set("realm_index", 48)
	ge.call("_recompute_lifespan")
	_check(int(ge.get("lifespan_years")) == 1000000000, "true immortal ageless")
	ge.queue_free()
