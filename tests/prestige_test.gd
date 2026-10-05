extends SceneTree
## P19b — ascension prestige (Dao Marks) proofs. Run with:
## --headless -s res://tests/prestige_test.gd (exit 0 = pass).
## Covers gain formula boundaries, node shop, ascend reset semantics,
## bonus hooks, Big lifetime totals, and save round-trip. UI flow
## (forecast label, two-press confirm, tree rows) lives in p17_test.

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
	ge.call("set_activity_rate", 1.0)
	var f: FileAccess = FileAccess.open("res://data/realms.json", FileAccess.READ)
	ge.call("set_realm_table", JSON.parse_string(f.get_as_text()))
	f.close()
	var pf: FileAccess = FileAccess.open("res://data/prestige.json", FileAccess.READ)
	ge.call("set_prestige_defs", JSON.parse_string(pf.get_as_text()))
	pf.close()
	return ge

func _initialize() -> void:
	print("PRESTIGE-TEST start")
	_test_gain()
	_test_shop()
	_test_ascend()
	_test_bonuses()
	_test_persist()
	if _failures == 0:
		print("PRESTIGE-TEST PASS")
	else:
		printerr("PRESTIGE-TEST FAIL count=", _failures)
	quit(_failures)

func _test_gain() -> void:
	var ge: Node = _new_engine()
	# Below the first threshold there is nothing to ascend with.
	_check(int(ge.call("calculate_prestige_gain")) == 0, "fresh life gains nothing")
	ge.set("qi_earned_total", 999999.0)
	_check(int(ge.call("calculate_prestige_gain")) == 0, "below 1M gains nothing")
	# floor(12 * sqrt(total / 1M)): 1M -> 12, 4M -> 24, 1T -> 12000.
	ge.set("qi_earned_total", 1000000.0)
	_check(int(ge.call("calculate_prestige_gain")) == 12, "threshold pays base")
	ge.set("qi_earned_total", 4000000.0)
	_check(int(ge.call("calculate_prestige_gain")) == 24, "sqrt dampening holds")
	ge.set("qi_earned_total", 1e12)
	_check(int(ge.call("calculate_prestige_gain")) == 12000, "deep totals scale sublinearly")
	_check(ge.call("lifetime_qi_num") == 1e12, "lifetime reads back past float-int range")
	ge.queue_free()

func _test_shop() -> void:
	var ge: Node = _new_engine()
	_check(int(ge.call("dao_node_cost", "dao_nope")) == -1, "unknown node refused")
	_check((ge.call("dao_rows") as Array).size() == 3, "three dao nodes from data")
	_check(not bool(ge.call("buy_dao_node", "dao_flow")), "broke cultivator refused")
	ge.set("dao_marks", 5)
	_check(bool(ge.call("buy_dao_node", "dao_flow")), "first rank buys")
	_check(int(ge.call("dao_rank", "dao_flow")) == 1, "rank recorded")
	_check(int(ge.call("dao_node_cost", "dao_flow")) == 2, "next rank costs rank+1")
	_check(int(ge.get("dao_marks")) == 4, "marks deducted")
	# Twenty deep, then perfected.
	ge.set("dao_marks", 1000000)
	for i in range(19):
		ge.call("buy_dao_node", "dao_flow")
	_check(int(ge.call("dao_rank", "dao_flow")) == 20, "flow caps at 20")
	_check(int(ge.call("dao_node_cost", "dao_flow")) == -1, "perfected refuses")
	_check(not bool(ge.call("buy_dao_node", "dao_flow")), "perfected buys nothing")
	ge.queue_free()

func _test_ascend() -> void:
	var ge: Node = _new_engine()
	_check(int(ge.call("ascend")) == 0, "ascension refused below threshold")
	_check(int(ge.get("dao_ascensions")) == 0, "refusal records nothing")
	# A developed world: realm, gear, sect, arts, attunement, pills.
	ge.set("qi_earned_total", 4000000.0)
	ge.set("realm_index", 5)
	ge.set("aptitude", 2.0)
	ge.set("total_rebirths", 4)
	ge.set("gear", {"gear_riverband": 5})
	ge.set("sect", {"name": "X"})
	ge.set("disciples", [{"task": "gather"}])
	ge.set("techniques", {"tech_stillwater": 500})
	ge.set("attunement", {"tech_stillwater": 80.0})
	ge.set("herbs", 100.0)
	ge.set("soulweapon", {"path": "soul_blade", "xp": 40})
	ge.set("talents", {"talent_breath": 2})
	ge.set("karma", 50)
	var gain: int = int(ge.call("ascend"))
	_check(gain == 24, "ascension banks forecast gain")
	_check(int(ge.get("dao_marks")) == 24, "marks ledger credited")
	_check(int(ge.get("dao_ascensions")) == 1, "ascension counted")
	# The world resets...
	_check(int(ge.get("realm_index")) == 0, "realm returns to dust")
	_check(float(ge.get("aptitude")) == 1.0, "aptitude returns to one")
	_check(int(ge.get("total_rebirths")) == 0, "rebirth count returns to zero")
	_check((ge.get("gear") as Dictionary).is_empty(), "gear left behind")
	_check((ge.get("sect") as Dictionary).is_empty(), "sect left behind")
	_check((ge.get("disciples") as Array).is_empty(), "disciples left behind")
	_check((ge.get("techniques") as Dictionary).is_empty(), "arts left behind")
	_check((ge.get("attunement") as Dictionary).is_empty(), "attunement left behind")
	_check(ge.call("qi_num") == 0.0, "qi returns to zero")
	_check(ge.call("bottleneck_num") == 1200.0, "bottleneck returns to front-loaded realm 1")
	# ...but the soul, karma, talents, and lifetime cross over.
	_check(str((ge.get("soulweapon") as Dictionary).get("path", "")) == "soul_blade", "soul crosses ascension")
	_check(int((ge.get("talents") as Dictionary).get("talent_breath", 0)) == 2, "talents cross ascension")
	_check(int(ge.get("karma")) == 50, "karma crosses ascension")
	_check(ge.call("lifetime_qi_num") == 4000000.0, "lifetime basis untouched")
	ge.queue_free()

func _test_bonuses() -> void:
	var ge: Node = _new_engine()
	_check(ge.call("dao_flow_bonus") == 1.0, "unranked flow neutral")
	_check(int(ge.call("dao_years_bonus")) == 0, "unranked years neutral")
	_check(ge.call("dao_tithe_bonus") == 1.0, "unranked tithe neutral")
	ge.set("dao_marks", 100)
	ge.call("buy_dao_node", "dao_flow")
	ge.call("buy_dao_node", "dao_flow")
	_check(absf(float(ge.call("dao_flow_bonus")) - 1.2) < 1e-9, "flow +10%/rank")
	ge.call("buy_dao_node", "dao_years")
	# Tier-1 lifespan 110 + 5 negotiated years.
	_check(int(ge.get("lifespan_years")) == 115, "years lengthen incarnations")
	ge.queue_free()

func _test_persist() -> void:
	var ge: Node = _new_engine()
	ge.set("dao_marks", 24)
	ge.set("dao_nodes", {"dao_flow": 2})
	ge.set("dao_ascensions", 1)
	ge.set("qi_earned_total", 4000000.0)
	var st: Dictionary = ge.call("get_state")
	_check(int((st as Dictionary).get("dao_marks", -1)) == 24, "marks saved")
	var GE2: GDScript = load("res://scripts/GameEngine.gd")
	var ge2: Node = GE2.new()
	root.add_child(ge2)
	ge2.call("apply_state", st)
	_check(int(ge2.get("dao_marks")) == 24, "marks restored")
	_check(int(ge2.call("dao_rank", "dao_flow")) == 2, "ranks restored")
	_check(int(ge2.get("dao_ascensions")) == 1, "ascension count restored")
	_check(ge2.call("lifetime_qi_num") == 4000000.0, "lifetime restored")
	ge.queue_free()
	ge2.queue_free()
