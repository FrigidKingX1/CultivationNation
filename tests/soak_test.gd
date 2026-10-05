extends SceneTree
## Soak (P2 extended): 210 in-game years fast-forward, proves long-run stability.
## Run: --headless -s res://tests/soak_test.gd

func _initialize() -> void:
	print("SOAK start (210y)")
	var GE: GDScript = load("res://scripts/GameEngine.gd")
	var SM: GDScript = load("res://scripts/SaveManager.gd")
	var ge: Node = GE.new()
	ge.set_name("GameEngine")
	root.add_child(ge)
	var sm: Node = SM.new()
	root.add_child(sm)
	sm.set("engine_ref", ge)
	ge.call("set_time_scale", 100.0)
	ge.call("set_activity_rate", 5.0)
	var start_life: int = int(ge.get("life_number"))
	var saw_breakthrough: bool = false
	var rebirths: int = 0
	# 210 in-game years of ticks directly (no wall-clock wait).
	for i in range(12 * 210):
		ge.call("_step_tick")
		if int(ge.get("realm_index")) > 0:
			saw_breakthrough = true
		if int(ge.get("life_number")) > start_life + rebirths:
			rebirths = int(ge.get("life_number")) - start_life
		# Auto-breakthrough like Main.gd does.
		if ge.call("qi_num") >= ge.call("bottleneck_num"):
			ge.call("attempt_breakthrough", 9999.0, 1.0)
		# Mid-soak save/load roundtrip at year ~100 mark.
		if i == 12 * 100:
			_check_save_mid_soak(sm, ge)
	print("age=", ge.get("age_years"), " realm=", ge.get("realm_index"),
		" life=", ge.get("life_number"), " aptitude=", ge.get("aptitude"),
		" rebirths=", rebirths)
	if int(ge.get("tick_count")) != 12 * 210:
		printerr("SOAK FAIL: tick count mismatch, got ", ge.get("tick_count"))
		quit(1)
		return
	if not saw_breakthrough:
		printerr("SOAK FAIL: no breakthrough in 210y at high qi rate")
		quit(1)
		return
	if rebirths < 2:
		printerr("SOAK FAIL: fewer than 2 rebirths in 210y (lifespan 60)")
		quit(1)
		return
	# P12-0 finite guards: the uncapped climb must stop at the ladder, and the
	# whole rate chain must stay finite across 210 years of auto-breakthroughs.
	if int(ge.get("realm_index")) > int(ge.get("realm_count")):
		printerr("SOAK FAIL: realm advanced past ladder (got ", ge.get("realm_index"), ")")
		quit(1)
		return
	if not is_finite(ge.call("qi_num")):
		printerr("SOAK FAIL: qi non-finite after soak")
		quit(1)
		return
	if not is_finite(ge.call("bottleneck_num")) or not is_finite(ge.call("rate_num")):
		printerr("SOAK FAIL: rate chain non-finite after soak")
		quit(1)
		return
	print("SOAK PASS: age + breakthrough + 2+ rebirths + mid-soak save/load observed")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	quit(0)

func _check_save_mid_soak(sm: Node, ge: Node) -> void:
	var before: int = int(ge.get("age_years"))
	if not bool(sm.call("save_game")):
		printerr("SOAK FAIL: mid-soak save failed")
		quit(1)
		return
	ge.set("age_years", 18)
	sm.call("load_game")
	if int(ge.get("age_years")) != before:
		printerr("SOAK FAIL: mid-soak save/load mismatch")
		quit(1)
