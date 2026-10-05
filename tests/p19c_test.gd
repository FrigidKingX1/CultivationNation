extends SceneTree
## P19c — interface systems proofs. Run with:
## --headless -s res://tests/p19c_test.gd (exit 0 = pass).
## Covers ModalManager (build/present/lifecycle), milestone dedication
## (poll once, dedupe, table-less, persistence), bulk buying (all four
## kinds, MAX cap, stop-at-refusal, unknown kinds), and UpgradeRow
## structure (names, dimming, bulk suffix). Rail + reskin ride in p17_test
## (scene census, tab switching, theme tokens).

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
	print("P19C-TEST start")
	_test_modal()
	_test_milestone()
	_test_bulk()
	_test_rows()
	if _failures == 0:
		print("P19C-TEST PASS")
	else:
		printerr("P19C-TEST FAIL count=", _failures)
	quit(_failures)

func _test_modal() -> void:
	var MODAL: GDScript = load("res://scripts/ModalManager.gd")
	var c: ConfirmationDialog = MODAL.build_confirm("Leave This World", "Ascend for +24?", "Ascend +24")
	_check(c.title == "Leave This World", "confirm carries title")
	_check("+24" in c.dialog_text, "confirm names the stakes")
	_check(c.ok_button_text == "Ascend +24", "confirm ok text")
	var r: AcceptDialog = MODAL.build_report("While You Were Away", PackedStringArray(["a", "b"]))
	_check(r.title == "While You Were Away", "report carries title")
	_check("a\nb" in r.dialog_text, "report joins lines")
	# Present: parents, themes from live tree, any close frees.
	var host := Node.new()
	host.name = "ModalHost"
	root.add_child(host)
	MODAL.present(host, c)
	_check(c.get_parent() == host, "present parents the dialog")
	var fired: Array = []
	c.confirmed.connect(func(): fired.append(1))
	c.emit_signal("confirmed")
	_check(not fired.is_empty(), "callers ride confirmed")
	# queue_free is deferred: assert queued, not gone (frame flush deletes).
	_check(c.is_queued_for_deletion(), "confirm frees on close")
	MODAL.present(host, r)
	r.emit_signal("canceled")
	_check(r.is_queued_for_deletion(), "cancel frees on close")
	host.queue_free()

func _test_milestone() -> void:
	var ge: Node = _new_engine()
	_check((ge.call("poll_milestone") as Dictionary).is_empty(), "no dedication at journey start")
	ge.set("realm_index", 8)
	var ms: Dictionary = ge.call("poll_milestone")
	_check(str(ms.get("name", "")) == "Foundation Establishment", "tier entry dedicates")
	_check((ge.call("poll_milestone") as Dictionary).is_empty(), "dedication fires once")
	ge.set("realm_index", 9)
	_check((ge.call("poll_milestone") as Dictionary).is_empty(), "mid-tier stays quiet")
	ge.set("realm_index", 16)
	var ms2: Dictionary = ge.call("poll_milestone")
	_check(int(ms2.get("tier", 0)) == 3, "next tier dedicates in turn")
	var st: Dictionary = ge.call("get_state")
	_check(int((st.get("milestones_seen", []) as Array).size()) == 2, "dedications saved")
	var GE2: GDScript = load("res://scripts/GameEngine.gd")
	var ge2: Node = GE2.new()
	root.add_child(ge2)
	ge2.call("apply_state", st)
	ge2.call("set_realm_table", (ge.get("_realm_table") as Array).duplicate())
	ge2.set("realm_index", 8)
	_check((ge2.call("poll_milestone") as Dictionary).is_empty(), "dedications persist across saves")
	# Table-less engine never dedicates.
	var GE3: GDScript = load("res://scripts/GameEngine.gd")
	var ge3: Node = GE3.new()
	root.add_child(ge3)
	ge3.set("realm_index", 8)
	_check((ge3.call("poll_milestone") as Dictionary).is_empty(), "table-less stays quiet")
	ge.queue_free()
	ge2.queue_free()
	ge3.queue_free()

func _test_bulk() -> void:
	var ge: Node = _new_engine()
	_check(int(ge.call("buy_bulk", "soul", "x", 3)) == 0, "unknown kinds buy nothing")
	_check(int(ge.call("buy_bulk", "gear", "gear_riverband", 0, 5)) == 0, "broke bulk buys nothing")
	# Gear: 100k Qi funds refines at 100x4^lv (100+400+1600+6400+...).
	ge.set("qi", 100000.0)
	var got: int = int(ge.call("buy_bulk", "gear", "gear_riverband", 3, 5))
	_check(got == 3, "bulk refines exactly n")
	_check(int((ge.get("gear") as Dictionary).get("gear_riverband", 0)) == 3, "bulk levels recorded")
	# Talent: quadratic 10/40/90... 500 karma buys 10+40+90+160=300, stops at 250-cost rank.
	ge.set("karma", 500)
	var tg: int = int(ge.call("buy_bulk", "talent", "talent_roots", 10))
	_check(tg == 4, "bulk stops at first refusal")
	_check(int(ge.call("talent_level", "talent_roots")) == 4, "bulk ranks recorded")
	# Dao: marks arithmetic 1+2+3... 10 marks buys 4 ranks exactly.
	ge.set("dao_marks", 10)
	var dg: int = int(ge.call("buy_bulk", "dao", "dao_flow", -1))
	_check(dg == 4, "MAX spends the purse precisely")
	_check(int(ge.get("dao_marks")) == 0, "purse empties exactly")
	# MAX caps iterations: 1e10 karma would fund ~1400 ranks (cubic
	# costs), so the 999-iteration cap — not the purse — must bind.
	ge.set("karma", 10000000000.0)
	var mx: int = int(ge.call("buy_bulk", "talent", "talent_body", -1))
	_check(mx == 999, "MAX caps at 999 iterations")
	# Pills: herb stock bounds the brew (10-herb recipe, 25 herbs -> 2).
	ge.set("herbs", 25.0)
	var br: int = int(ge.call("buy_bulk", "pill", "pill_prep", 10))
	_check(br == 2, "bulk brews to stock")
	_check(int((ge.get("pills") as Dictionary).get("pill_prep", 0)) == 2, "bulk stock recorded")
	ge.queue_free()

func _test_rows() -> void:
	var ROW: GDScript = load("res://scripts/UpgradeRow.gd")
	var row: VBoxContainer = ROW.build_row("RowGear_x", "Riverband — Lv5", "Refine 5>6 (100 Qi) ×10", "tip", true)
	_check(row.name == "RowGear_x", "row keeps its name")
	_check((row.get_node("TitleLabel") as Label).text == "Riverband — Lv5", "row titles")
	var btn: Button = row.get_node("BuyBtn") as Button
	_check("×10" in btn.text, "row shows bulk suffix")
	_check(btn.tooltip_text == "tip", "row explains itself")
	_check(not btn.disabled, "affordable rows enable")
	var poor: VBoxContainer = ROW.build_row("RowGear_y", "t", "a", "tip", false)
	var pbtn: Button = poor.get_node("BuyBtn") as Button
	_check(pbtn.disabled, "broke rows disable")
	_check(pbtn.modulate.a < 1.0, "broke rows dim")
	_check(ROW.bulk_suffix(1) == "", "single buys bare")
	_check(ROW.bulk_suffix(10) == " ×10", "tens suffix")
	_check(ROW.bulk_suffix(-1) == " ×MAX", "max suffix")
	row.queue_free()
	poor.queue_free()
