extends SceneTree
## G2 first-session driver (1.0a): automated UI-level playthrough on a fresh
## save — the friction-detection proxy. Wherever the script stumbles, a hint
## fails to fire, or a refusal reads wrong, that's a real new-player friction
## point. Display-required (screenshots + rendered world). Keeps no state;
## wipes user:// first (R-S5). Timing per step; stumbles print FRICTION lines.
## Evidence lines print as G2-EVIDENCE. Run WITHOUT --headless:
## <engine> --path <project> -s res://tools/g2_first_session.gd

var _frames: int = 0
var _stage: int = 0
var _main: Node = null
var _t0: int = 0
var _stumbles: int = 0

func _world() -> Node:
	return _main.get_node("WorldViewport/World")

func _ge() -> Node:
	return root.get_node("GameEngine")

func _snap(tag: String) -> void:
	var img: Image = root.get_texture().get_image()
	print("G2 snap ", tag, " err=", img.save_png("user://g2_" + tag + ".png"))

func _step_ms(tag: String) -> void:
	print("G2-TIMING ", tag, " ms=", Time.get_ticks_msec() - _t0)
	_t0 = Time.get_ticks_msec()

func _stumble(what: String) -> void:
	_stumbles += 1
	print("G2-FRICTION: ", what)

func _evidence(what: String) -> void:
	print("G2-EVIDENCE: ", what)

func _stand_on_mark(meta_key: String) -> bool:
	var w: Node = _world()
	var cult: Node3D = w.get_node_or_null("Cultivator") as Node3D
	if cult == null:
		return false
	for src in [w.get_node_or_null("NodeMarks"), w.get_node_or_null("BeastGrounds"), w.get_node_or_null("BeastRow")]:
		if src == null:
			continue
		for m in (src as Node).get_children():
			if str((m as Node3D).get_meta(meta_key, "")) != "":
				cult.global_position = (m as Node3D).global_position
				return true
	# Fallback: beast row children carry beast_id metas (P25 pattern).
	var row: Node = w.get_node_or_null("BeastRow")
	if row != null and meta_key == "beast_id" and row.get_child_count() > 0:
		cult.global_position = (row.get_child(0) as Node3D).global_position
		return true
	return false

func _press(action: String) -> void:
	Input.action_press(action)
	_world().call("_poll_avatar", 0.25)
	Input.action_release(action)

func _initialize() -> void:
	print("G2 start: fresh-save first session")
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json", "user://player_config.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	_t0 = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_main = packed.instantiate()
		root.add_child(_main)
		_stage = 1
		_frames = 0
		return false
	if _stage == 1 and _frames == 44:
		_snap("s0_veil_transition_ink")
		_step_ms("boot_to_veil_window")
		return false
	if _stage == 1 and _frames >= 70:
		# Title -> New Run (fresh journey lifts the hold).
		_main.call("_on_title_new")
		_evidence("title dismissed via _on_title_new; running=" + str(bool(_ge().get("running"))))
		if not bool(_ge().get("running")):
			_stumble("title New did not start the run")
		_snap("s1_title_gone_ink")
		_step_ms("title_new")
		_ge().call("set_time_scale", 1000.0)
		_stage = 2
		_frames = 0
		return false
	if _stage == 2 and _frames <= 3600:
		if int(_ge().get("realm_index")) >= 1:
			_evidence("first breakthrough reached at frame " + str(_frames) + " (1000x)")
			_snap("s2_breakthrough_ink")
			_step_ms("first_breakthrough")
			_stage = 3
			_frames = 0
		elif _frames == 3600:
			_stumble("no breakthrough in 3600 frames at 1000x")
			_stage = 3
			_frames = 0
		return false
	if _stage == 3 and _frames >= 10:
		# Walk to a node marker -> interact -> meditate -> presence ON.
		_ge().call("set_time_scale", 1.0)
		if not _stand_on_mark("node_id"):
			_stumble("no node marker to stand on")
		_press("world_interact")
		_main.call("_refresh_shrine_den")
		_evidence("near_node=" + str(_world().call("avatar_near_node")) + " ready=" + str((_ge().call("leyline_attune_ready") as Dictionary).get("reason", "?")) + " den_near=" + str(_world().call("avatar_den_near")) + " shrine_near=" + str(_world().call("avatar_shrine_near")) + " state=" + str(_world().call("avatar_state")))
		# Either the meditate path (presence on) or the ley-line modal path
		# (Main's poll already drained the request into a presented dialog —
		# look for the DIALOG, not the queue): take "Meditate instead".
		var dlg: Node = _main.get_node_or_null("UI/LeylineDialog")
		if dlg != null:
			_evidence("node interact presented leyline modal; taking Meditate instead")
			_main.call("_on_leyline_meditate", dlg)
		var med: String = str(_world().call("avatar_state"))
		var pres: bool = bool(_ge().call("is_presence_active"))
		_evidence("post-interact avatar=" + med + " presence=" + str(pres))
		if not pres:
			_stumble("interact at node did not meditate (avatar=" + med + ")")
		_snap("s3_meditate_ink")
		_step_ms("node_meditate")
		_stage = 4
		_frames = 0
		return false
	if _stage == 4 and _frames >= 10:
		# First challengeable den -> manual fight -> win OR refusal (both valid).
		if not _stand_on_mark("beast_id"):
			_stumble("no den marker to stand on")
		_press("world_interact")
		_world().call("take_den_outcome")
		var bid: String = str(_world().call("avatar_challenge"))
		if bid == "":
			_evidence("den refused below strength (warded path, valid UX)")
		else:
			var res: Dictionary = _world().call("avatar_fight", bid)
			if bool(res.get("ok", false)):
				var t: int = 1000000
				var outcome: Dictionary = {}
				for g in [400, 400, 400, 400, 400, 400, 400, 400, 400, 400, 400, 400]:
					t += int(g)
					var r: Dictionary = _world().call("avatar_strike", t)
					if r.has("win"):
						outcome = r
				if outcome.is_empty():
					outcome = _world().call("avatar_strike", t + 100000)
				_world().call("take_fight_outcome")
				_evidence("den fight vs " + bid + " win=" + str(bool(outcome.get("win", false))))
			else:
				_stumble("challenge staged but fight refused: " + bid)
		_snap("s4_den_ink")
		_step_ms("den_fight")
		_stage = 5
		_frames = 0
		return false
	if _stage == 5 and _frames >= 10:
		# Shrine flame state (false is a PASS) + ley-line reach + flight refusal.
		var fl: String = str(_world().call("shrine_affordance", "guardian_01"))
		_evidence("shrine01 affordance=" + fl + " (dormant expected pre-R08)")
		if fl != "dormant":
			_stumble("shrine01 lit before its warden gates")
		var att: Dictionary = _ge().call("attune_next")
		_evidence("ley-line reach: ok=" + str(bool(att.get("ok", false))) + " reason=" + str(att.get("reason", "")) + " line=" + str(att.get("line", "")))
		_press("world_toggle_flight")
		var fly: String = str(_world().call("avatar_state"))
		_evidence("post-F avatar=" + fly + " (pre-unlock refusal expected)")
		if fly == "fly":
			_stumble("flight engaged before Nascent Soul")
		_snap("s5_shrine_ink")
		_step_ms("shrine_leyline_flight")
		_stage = 6
		_frames = 0
		return false
	if _stage == 6 and _frames >= 10:
		# HUD + affordances visible; then both skins.
		_main.get_node("UI").call("refresh")
		_snap("s6_hud_ink")
		_main.get_node("UI").call("set_skin", "parchment")
		_stage = 7
		_frames = 0
		return false
	if _stage == 7 and _frames >= 15:
		_snap("s7_world_parchment")
		_step_ms("parchment_pass")
		print("G2 done stumbles=", _stumbles)
		quit(0)
		return true
	if _frames > 14400:
		printerr("G2 FAIL: timeout")
		quit(1)
		return true
	return false
