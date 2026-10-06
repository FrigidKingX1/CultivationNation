extends SceneTree
## P26 stakes test: threshold matrix, demotion rollback, rewards, marks,
## persistence, orthogonality, pledge flow, v13 migration.
## Run with: --headless -s res://tests/p26_stakes_test.gd (exit 0 = pass).
## Deterministic throughout: no RNG anywhere in this suite.

var _failures: int = 0
var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

const BN: GDScript = preload("res://scripts/BigNumber.gd")

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _load_json(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var a: Array = JSON.parse_string(f.get_as_text())
	f.close()
	return a

func _new_engine() -> Node:
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	ge.call("set_realm_table", _load_json("res://data/realms.json"))
	return ge

func _ready_engine(ge: Node, realm: int, qi_mult: float = 1.0) -> void:
	## Rich, drilled exile: ready power with margin to spare. Realm FIRST,
	## then re-wire the table so the bottleneck recomputes for that realm
	## (set_realm_table derivations read the live index).
	ge.set("realm_index", realm)
	ge.call("set_realm_table", _load_json("res://data/realms.json"))
	ge.set("techniques", {"tech_emberstep": 6000000})
	ge.set("focus_technique", "tech_emberstep")
	ge.set("qi", float(ge.call("bottleneck_num")) * qi_mult)

func _attempt(ge: Node, power: float, realm: int) -> bool:
	## Attempt exactly the way Main and the pacing bot do: base power plus
	## the live technique bonus as power_mult (never a bare 1.0 — the
	## bonus is part of readiness, and omitting it underpowers every call).
	return bool(ge.call("attempt_breakthrough", float(power), float(ge.call("trib_power_for", realm)), float(ge.call("best_technique_bonus"))))

func _initialize() -> void:
	print("STAKES-TEST start")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_test_set_stake()
	_test_combine_invariant()
	_test_thresholds_move()
	_test_demotion()
	_test_realm_zero_fallback()
	_test_final_crossing()
	_test_rewards_marks()
	_test_persistence()
	_test_orthogonality()
	_test_migration()
	_stage = 1
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 1 and _frames >= 1:
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames >= 5:
		_test_pledge_flow()
		_test_glyph()
		if _failures == 0:
			print("STAKES-TEST PASS")
		else:
			printerr("STAKES-TEST FAIL count=", _failures)
		quit(_failures)
	elif _frames > 3600:
		printerr("STAKES-TEST FAIL: frame timeout")
		quit(1)
	return false

func _test_set_stake() -> void:
	var ge: Node = _new_engine()
	_check(str(ge.call("get_stake")) == "composed", "stake defaults composed")
	ge.call("set_stake", "heaven")
	_check(str(ge.call("get_stake")) == "heaven", "pledge takes")
	ge.call("set_stake", "bogus-nope")
	_check(str(ge.call("get_stake")) == "heaven", "unknown pledge refused silently")
	ge.queue_free()

func _test_combine_invariant() -> void:
	# P3 pin: stakes shift quality thresholds ONLY. Same state across all
	# three stakes: identical win/loss, identical Failed-path costs.
	for setup in ["strong", "weak"]:
		var res: Array = []
		for stake in ["composed", "tempered", "heaven"]:
			var ge: Node = _new_engine()
			if setup == "strong":
				_ready_engine(ge, 10)
			else:
				ge.set("realm_index", 10)
				ge.set("qi", float(ge.call("bottleneck_num")))
			ge.call("set_stake", stake)
			var r0: int = int(ge.get("realm_index"))
			var q0: float = ge.call("qi_num")
			var s0: int = int(ge.get("lifespan_scars"))
			var ok: bool = bool(_attempt(ge, 10.0, 10))
			res.append({
				"ok": ok, "realm": int(ge.get("realm_index")) - r0,
				"dqi": ge.call("qi_num") - q0,
				"dscars": int(ge.get("lifespan_scars")) - s0,
			})
			ge.queue_free()
		_check(bool(res[0].get("ok", false)) == bool(res[1].get("ok", false)) and bool(res[1].get("ok", false)) == bool(res[2].get("ok", false)), "combine identical across stakes (" + setup + ")")
		if not bool(res[0].get("ok", false)):
			_check(absf(float(res[0].get("dqi", 0.0)) - float(res[1].get("dqi", 0.0))) < 0.001 and absf(float(res[1].get("dqi", 0.0)) - float(res[2].get("dqi", 0.0))) < 0.001, "failed costs identical across stakes")
			_check(int(res[0].get("dscars", -1)) == int(res[1].get("dscars", -2)) and int(res[1].get("dscars", -2)) == int(res[2].get("dscars", -3)), "failed scars identical across stakes")

func _test_thresholds_move() -> void:
	# Same marginal state: composed reads Radiant where tempered/heaven
	# read Steady (brim-full + flawless gates). Only quality moves.
	var quals: Array = []
	for stake in ["composed", "tempered", "heaven"]:
		var ge: Node = _new_engine()
		_ready_engine(ge, 10, 0.9)
		ge.call("set_stake", stake)
		_attempt(ge, 10.0, 10)
		quals.append(str(ge.get("last_quality")))
		ge.queue_free()
	_check(quals[0] == "Radiant", "composed crowns the marginal crossing")
	_check(quals[1] == "Steady" and quals[2] == "Steady", "raised gates demote Radiant to Steady")

func _find_shaky_power() -> Array:
	## Adaptive search (deterministic): a power yielding Shaky at realm 40
	## under heaven. Late tiers carry many waves, so ready-but-leaking
	## Shaky exists there (early tiers cannot leak enough while ready —
	## verified by hand computation, pinned in the report).
	for p in [8.0, 8.2, 8.5, 8.7, 9.0, 9.5, 7.5, 10.0]:
		var ge: Node = _new_engine()
		_ready_engine(ge, 40)
		ge.call("set_stake", "heaven")
		_attempt(ge, float(p), 40)
		if str(ge.get("last_quality")) == "Shaky":
			var snap: Dictionary = {"power": p}
			ge.queue_free()
			return [snap]
		ge.queue_free()
	return []

func _test_demotion() -> void:
	# P2 pin: selective restoration. Heaven-Shaky at an interior realm:
	# realm/bottleneck/rate/preps/deviation revert to pre-attempt, qi
	# stands at the Late-band minimum, scars apply once, no double
	# deviation, demotion record names from/to.
	var found: Array = _find_shaky_power()
	_check(not found.is_empty(), "shaky-yielding setup exists")
	if found.is_empty():
		return
	var power: float = float(found[0].get("power", 0.0))
	var ge: Node = _new_engine()
	_ready_engine(ge, 40)
	# Force the compiled cache current BEFORE baselining: fresh engines
	# carry the construction-default cache until the first recompute.
	ge.call("_recompute_rate")
	var pt0: float = BN.of(ge.get("qi_per_tick")).to_float()
	var neck0: float = ge.call("bottleneck_num")
	var dev0: int = int(ge.get("deviation"))
	var scars0: int = int(ge.get("lifespan_scars"))
	ge.call("set_stake", "heaven")
	_check(bool(_attempt(ge, power, 40)), "shaky crossing succeeds")
	_check(int(ge.get("realm_index")) == 40, "demotion restores the origin realm")
	# Exploit killer: the per-tick SOURCE reverts bit-identically (no x4
	# leak into the demoted state). The live compiled rate legitimately
	# drifts +1.5% via the standard post-success purity blessing (+2
	# dantian, shared by every success path) — that is blessing, not
	# stacking, so the assertion targets the source, not the cache.
	var pt1: float = BN.of(ge.get("qi_per_tick")).to_float()
	_check(absf(pt1 - pt0) / maxf(absf(pt0), 0.001) < 1e-9, "per-tick source reverts: no stacking exploit")
	_check(absf(ge.call("bottleneck_num") - neck0) < 0.0001, "bottleneck reverts")
	_check(absf(ge.call("qi_num") - neck0 * 2.0 / 3.0) < 0.001, "qi stands at the Late minimum")
	_check(int(ge.get("deviation")) == dev0, "shaky deviation replaced, not doubled")
	_check(int(ge.get("lifespan_scars")) > scars0, "scar roll applies once")
	var dem: Dictionary = ge.get("last_demotion")
	_check(int(dem.get("from", -1)) == 41 and int(dem.get("to", -2)) == 40, "demotion record names from/to")
	ge.queue_free()
	# Tempered Shaky demotes nothing (documented deviation: attempts fire
	# at Late by gate design; post-crossing qi is already zero).
	var ge2: Node = _new_engine()
	_ready_engine(ge2, 40)
	ge2.call("set_stake", "tempered")
	_attempt(ge2, power, 40)
	_check((ge2.get("last_demotion") as Dictionary).is_empty(), "tempered records no demotion")
	ge2.queue_free()

func _test_realm_zero_fallback() -> void:
	# Realm 0 has no waves (tier-1 table), so forecast never yields Shaky
	# there: the fallback branch is defensive. Exercise it through a
	# waves-bearing injected table (rule-11: test the branch, not the data).
	var ge: Node = _new_engine()
	var realms: Array = _load_json("res://data/realms.json")
	realms[0]["waves"] = 3
	ge.call("set_realm_table", realms)
	ge.set("realm_index", 0)
	ge.set("techniques", {"tech_emberstep": 6000000})
	ge.set("focus_technique", "tech_emberstep")
	ge.set("qi", float(ge.call("bottleneck_num")))
	ge.call("set_stake", "heaven")
	var found_shaky: bool = false
	# Small powers + zero purity: defense just clears readiness while the
	# shrunken core keeps Shaky reachable (hand-computed band).
	for p in [0.15, 0.18, 0.2, 0.25, 0.3]:
		var trial: Node = _new_engine()
		trial.call("set_realm_table", realms)
		trial.set("realm_index", 0)
		trial.set("techniques", {"tech_emberstep": 6000000})
		trial.set("focus_technique", "tech_emberstep")
		trial.set("dantian_purity", 0.0)
		trial.set("qi", float(trial.call("bottleneck_num")))
		trial.call("set_stake", "heaven")
		_attempt(trial, float(p), 0)
		if str(trial.get("last_quality")) == "Shaky":
			found_shaky = true
			_check(int(trial.get("realm_index")) == 1, "realm-0 shaky still advances")
			_check((trial.get("last_demotion") as Dictionary).is_empty(), "realm-0 records no spatial demotion")
			_check(int(trial.get("lifespan_scars")) > 0, "realm-0 pays proportional scars")
			trial.queue_free()
			break
		trial.queue_free()
	_check(found_shaky, "realm-0 shaky reachable under injected waves")
	ge.queue_free()

func _test_final_crossing() -> void:
	# Victory is record-class: it persists even when Heaven-Shaky demotes
	# the crossing spatially afterward. Matrix line required by the pin.
	var ge: Node = _new_engine()
	_ready_engine(ge, 49)
	ge.call("set_stake", "heaven")
	var found: bool = false
	for p in [9.0, 9.5, 10.0, 10.5, 11.0, 12.0]:
		var trial: Node = _new_engine()
		_ready_engine(trial, 49)
		trial.call("set_stake", "heaven")
		_attempt(trial, float(p), 49)
		if str(trial.get("last_quality")) == "Shaky":
			found = true
			_check(bool(trial.get("victorious")), "victory persists through spatial demotion")
			_check(int(trial.get("realm_index")) == 49, "demotion returns to the origin realm")
			trial.queue_free()
			break
		trial.queue_free()
	_check(found, "final-crossing shaky reachable")
	ge.queue_free()

func _test_rewards_marks() -> void:
	# Tempered/Heaven Steady+ head-start: 25% of the crossed requirement.
	# Heaven-Radiant: material cache always; marks on tier crossings only
	# (cap 7); interior Radiants pay material, never marks (negative case).
	var ge: Node = _new_engine()
	_ready_engine(ge, 10)
	var neck: float = ge.call("bottleneck_num")
	ge.call("set_stake", "tempered")
	_attempt(ge, 10.0, 10)
	_check(absf(ge.call("qi_num") - neck * 0.25) < 0.001, "tempered head-start is a quarter pool")
	var ge2: Node = _new_engine()
	_ready_engine(ge2, 10)
	var herbs0: float = float(ge2.get("herbs"))
	ge2.call("set_stake", "heaven")
	_attempt(ge2, 10.0, 10)
	_check(str(ge2.get("last_quality")) == "Radiant", "setup crowns radiant")
	_check(absf(float(ge2.get("herbs")) - herbs0 - 100.0) < 0.001, "heaven-radiant caches material")
	_check(int(ge2.get("heaven_marks")) == 0, "interior radiant earns no mark")
	var ge3: Node = _new_engine()
	_ready_engine(ge3, 15)
	ge3.call("set_stake", "heaven")
	_attempt(ge3, 10.0, 15)
	_check(str(ge3.get("last_quality")) == "Radiant", "tier-crossing crowns radiant")
	_check(int(ge3.get("heaven_marks")) == 1, "tier-crossing radiant earns the mark")
	ge3.call("set_stake", "heaven")
	ge3.set("heaven_marks", 7)
	_ready_engine(ge3, 23)
	_attempt(ge3, 10.0, 23)
	_check(int(ge3.get("heaven_marks")) == 7, "marks cap at seven")
	ge.queue_free()
	ge2.queue_free()
	ge3.queue_free()

func _test_persistence() -> void:
	var ge: Node = _new_engine()
	ge.call("set_stake", "tempered")
	ge.set("heaven_marks", 3)
	ge.call("rebirth")
	_check(str(ge.call("get_stake")) == "tempered", "preference survives rebirth")
	_check(int(ge.get("heaven_marks")) == 3, "marks survive rebirth")
	ge.set("qi_earned_total", 4000000.0)
	ge.call("ascend")
	_check(str(ge.call("get_stake")) == "tempered", "preference survives ascension")
	_check(int(ge.get("heaven_marks")) == 3, "marks survive ascension")
	var st: Dictionary = ge.call("get_state")
	_check(str(st.get("stakes_preference", "")) == "tempered" and int(st.get("heaven_marks", -1)) == 3, "preference and marks save")
	var ge2: Node = _new_engine()
	ge2.call("apply_state", st)
	_check(str(ge2.call("get_stake")) == "tempered" and int(ge2.get("heaven_marks")) == 3, "preference and marks load")
	ge2.call("apply_state", {})
	_check(str(ge2.call("get_stake")) == "composed" and int(ge2.get("heaven_marks")) == 0, "missing keys default safely")
	ge.queue_free()
	ge2.queue_free()

func _test_orthogonality() -> void:
	# Stakes move thresholds only; presence moves rate only. One sanity
	# assertion each direction (stacked opt-ins compose).
	var ge: Node = _new_engine()
	_ready_engine(ge, 10)
	ge.call("set_stake", "heaven")
	ge.call("set_presence", true)
	var q_on: String = str(ge.call("forecast_quality", 10.0, float(ge.call("trib_power_for", 10)), 1.0, 1.0).get("quality", "?"))
	ge.call("set_presence", false)
	var q_off: String = str(ge.call("forecast_quality", 10.0, float(ge.call("trib_power_for", 10)), 1.0, 1.0).get("quality", "?"))
	_check(q_on == q_off, "presence changes no stake outcome")
	var r_tempered: float = 0.0
	ge.call("set_stake", "tempered")
	r_tempered = ge.call("rate_num")
	ge.call("set_stake", "composed")
	_check(absf(ge.call("rate_num") - r_tempered) < 0.0001, "stake changes no rate")
	ge.queue_free()

func _test_migration() -> void:
	# v12 fixture (guardians present, stakes absent) migrates chained to
	# v13 with composed/zero defaults; progress preserved verbatim.
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	_check(int(SM.get("SAVE_VERSION")) == 14, "save version is 14")
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var ge: Node = GE.new()
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	var slot := "user://cultivation_nation_save.json"
	var bak := "user://cultivation_nation_save.bak.json"
	for p in [slot, bak]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var eng: Dictionary = {"tick_count": 7, "realm_index": 12, "guardians": {"defeated": ["guardian_01"], "attempts": {}}}
	var f: FileAccess = FileAccess.open(slot, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 12, "saved_unix": 1, "engine": eng, "extra": {}}))
	f.close()
	var loaded: Dictionary = sm.call("load_game")
	_check(int(loaded.get("save_version", 0)) == 14, "v12 fixture stamped to v14")
	var leng: Dictionary = loaded.get("engine", {})
	_check(str(leng.get("stakes_preference", "")) == "composed", "v12 gains composed default")
	_check(int(leng.get("heaven_marks", -1)) == 0, "v12 gains zero marks")
	_check(int(leng.get("tick_count", 0)) == 7 and int(leng.get("realm_index", -1)) == 12, "migration preserves progress")
	_check((leng.get("guardians", {}) as Dictionary).get("defeated", []).has("guardian_01"), "migration preserves victories")
	ge.queue_free()
	sm.queue_free()
	for p in [slot, bak]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _test_pledge_flow() -> void:
	# Shrine pledge modal: builds headless, four buttons, presses set the
	# pledge and dismiss; Main poll consumes shrine requests into it.
	var dlg: AcceptDialog = _scene_main.call("_build_pledge_dialog", "guardian_01") as AcceptDialog
	_check(dlg != null and dlg.title == "Warden's Shrine", "pledge dialog builds")
	var box: VBoxContainer = dlg.get_node_or_null("PledgeBox") as VBoxContainer
	_check(box != null and box.get_child_count() == 5, "dialog carries header plus four buttons")
	(box.get_child(3) as Button).emit_signal("pressed")
	var ge: Node = root.get_node("GameEngine")
	_check(str(ge.call("get_stake")) == "heaven", "heaven button pledges")
	# hide() applies synchronously; queue_free() defers to frame end, so
	# dismissal asserts visibility, not instance validity.
	_check(not bool(dlg.visible), "pledge press dismisses")
	var dlg2: AcceptDialog = _scene_main.call("_build_pledge_dialog", "guardian_02") as AcceptDialog
	_scene_main.add_child(dlg2)
	var box2: VBoxContainer = dlg2.get_node_or_null("PledgeBox") as VBoxContainer
	(box2.get_child(1) as Button).emit_signal("pressed")
	_check(str(ge.call("get_stake")) == "composed", "composed button pledges")
	_scene_main.call("_show_pledge", "guardian_03")
	_check(_scene_main.get_node_or_null("UI/PledgeDialog") != null, "show presents the dialog")

func _test_glyph() -> void:
	# Stake rides the Attempt button as ASCII text (p17 glyph set intact).
	var ge: Node = root.get_node("GameEngine")
	ge.call("set_stake", "tempered")
	_scene_main.call("_refresh_breakthrough_btn")
	var b: Button = _scene_main.get_node("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn") as Button
	_check("Tempered" in b.text, "tempered rides the button")
	ge.call("set_stake", "composed")
	_scene_main.call("_refresh_breakthrough_btn")
	_check(not ("Tempered" in b.text) and not ("Heaven" in b.text), "composed rides clean")
