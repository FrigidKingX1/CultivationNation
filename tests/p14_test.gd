extends SceneTree
## P14 presentation test: world scene, factory, diorama, palettes, budgets.
## Run: --headless -s res://tests/p14_test.gd (exit 0 = pass).
## Extended per P14 slice (shell â†’ diorama â†’ cultivator â†’ weather â†’ FX).

var _failures: int = 0
var _frames: int = 0
var _stage: int = 0
var _scene_main: Node = null

const SF: GDScript = preload("res://scripts/SpriteFactory.gd")

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)

func _initialize() -> void:
	print("P14-TEST start")
	# QA Round 1: fresh boot required (see p10/p17 guard).
	for p in ["user://cultivation_nation_save.json", "user://cultivation_nation_save.bak.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames >= 1:
		_test_factory()
		var packed: PackedScene = load("res://scenes/Main.tscn")
		_scene_main = packed.instantiate()
		root.add_child(_scene_main)
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames >= 2:
		_test_world_shell()
		_test_diorama()
		_test_cultivator()
		_test_weather_tiers_beasts()
		_test_budget()
		_test_presentation()
		_test_tribulation_start()
		_stage = 2
		_frames = 0
	elif _stage == 2:
		if not bool(_world().call("tribulation_active")) and _frames >= 5:
			_test_tribulation_done()
			_stage = 3
			_frames = 0
		elif _frames > 1800:
			printerr("P14-TEST FAIL: tribulation never settled")
			quit(1)
			return true
	elif _stage == 3:
		if _world_body_restored() and _frames >= 5:
			if _failures == 0:
				print("P14-TEST PASS")
			else:
				printerr("P14-TEST FAIL count=", _failures)
			quit(_failures)
		elif _frames > 1800:
			printerr("P14-TEST FAIL: rebirth never restored")
			quit(1)
			return true
	elif _frames > 3600:
		printerr("P14-TEST FAIL: frame timeout")
		quit(1)
	return false

func _world_body_restored() -> bool:
	var b: Sprite3D = _world().get_node("Cultivator/Body") as Sprite3D
	return b.modulate == Color.WHITE and b.scale == Vector3.ONE

func _test_factory() -> void:
	# Single factory, three kinds, real sizes, cached repeats.
	var cult: Texture2D = SF.make_sprite("cultivator", "", Color(0.3, 0.5, 0.7))
	_check(cult != null, "factory cultivator exists")
	_check(int(cult.get_width()) == 64 and int(cult.get_height()) == 96, "cultivator 64x96")
	var beast: Texture2D = SF.make_sprite("beast", "beast_mistralhare", Color(0.3, 0.5, 0.7))
	_check(beast != null, "factory beast exists")
	_check(int(beast.get_width()) == 64 and int(beast.get_height()) == 64, "beast 64x64")
	var glow: Texture2D = SF.make_sprite("glow")
	_check(glow != null, "factory glow exists")
	_check(SF.make_sprite("beast", "beast_mistralhare", Color(0.3, 0.5, 0.7)) == beast, "factory caches repeats")
	_check(SF.make_sprite("nope") != null, "factory falls back, never errors")
	_check(SF.make_sprite("beast", "beast_mistralhare", Color.RED) != SF.make_sprite("beast", "beast_mistralhare", Color.BLUE), "tint varies cache key")
	_check(SF.make_sprite("beast", "beast_a", Color.WHITE) != SF.make_sprite("beast", "beast_b", Color.WHITE), "variant varies shape")

func _world() -> Node:
	return _scene_main.get_node("WorldViewport/World")

func _test_world_shell() -> void:
	_check(_scene_main.get_node_or_null("WorldViewport") != null, "world viewport docked")
	var w: Node = _world()
	_check(w != null, "world node exists")
	_check(_scene_main.get_node_or_null("WorldDisplay") != null, "world display docked")
	_check((_scene_main.get_node("WorldDisplay") as TextureRect).material != null, "ink material assigned")
	_check((_scene_main.get_node("WorldDisplay") as TextureRect).texture != null, "world texture bound")
	# P17-Step3: tabbed panels replace the old scrolling action column.
	_check(_scene_main.get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs") != null, "tab container docked")
	_check((_scene_main.get_node("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer).get_tab_count() == 9, "nine tabs staged")
	var cam_rig: Node = w.get_node_or_null("CamRig")
	_check(cam_rig != null, "camera rig staged")
	# P23 rule-11: fixed orthographic 3/4 cam replaced by the perspective
	# orbit rig (CamRig/Yaw/Pitch/Camera3D); resize lesson kept in
	# _sync_viewport_size. See docs/adr/P23_WORLD_ADR.md Camera (P23).
	var cam: Camera3D = w.get_node_or_null("CamRig/Yaw/Pitch/Camera3D") as Camera3D
	_check(cam != null and bool(cam.current), "perspective camera current")
	_check(int(cam.projection) == int(Camera3D.PROJECTION_PERSPECTIVE), "camera perspective")
	_check(w.get_node_or_null("WorldEnv") != null, "world environment present")
	# P17-Step3: glow toggle backend for the settings panel.
	w.call("set_glow", false)
	_check(not bool((w.get_node("WorldEnv") as WorldEnvironment).environment.glow_enabled), "glow toggles off")
	w.call("set_glow", true)
	_check(bool((w.get_node("WorldEnv") as WorldEnvironment).environment.glow_enabled), "glow toggles on")
	_check(w.get_node_or_null("Sun") != null, "sun present")

func _test_diorama() -> void:
	# P23 rule-11: the diorama slab + seeded peaks are replaced by nine
	# floating zone islands (Islands/Island_<zone>, active + neighbors
	# resident). Zone coverage and fallback semantics are unchanged.
	# See docs/adr/P23_WORLD_ADR.md Topology.
	var w: Node = _world()
	_check(w.get_node_or_null("Islands") != null, "island root staged")
	# Every authored zone resolves to a palette; unknowns fall back cleanly.
	var f: FileAccess = FileAccess.open("res://data/beasts.json", FileAccess.READ)
	var beasts: Array = JSON.parse_string(f.get_as_text())
	f.close()
	var zones: Dictionary = {}
	for b in beasts:
		zones[str((b as Dictionary).get("zone", ""))] = true
	_check(zones.size() == 9, "nine authored zones")
	for z in zones:
		_check(bool(w.call("has_zone_palette", str(z))), "palette covers " + str(z))
	w.call("apply_zone", "Pyrefen")
	_check(str(w.call("current_zone")) == "Pyrefen", "zone reskin applies")
	w.call("apply_zone", "Nope")
	_check(str(w.call("current_zone")) == "Dewfield", "unknown zone falls back")

func _test_cultivator() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	_check(w.get_node_or_null("Cultivator") != null, "cultivator rigged")
	_check(w.get_node_or_null("Cultivator/Body") != null, "body billboarded")
	_check(w.get_node_or_null("Cultivator/Aura") != null, "aura alive")
	# Robe follows the dominant root through the factory cache.
	ge.set("roots", {"fire": 0.9, "water": 0.1, "wood": 0.1, "metal": 0.1, "earth": 0.1})
	w.call("_poll_engine")
	var fire_tex: Texture2D = SF.make_sprite("cultivator", "", SF.element_color("fire"))
	_check((w.get_node("Cultivator/Body") as Sprite3D).texture == fire_tex, "robe tinted by root")
	# Aura color tracks mind stage; density tracks toxicity + deviation.
	ge.set("mind", 70.0)
	ge.set("toxicity", 0.0)
	w.call("_poll_engine")
	_check((w.get_node("Cultivator/Aura") as GPUParticles3D).amount == 24, "aura base density")
	ge.set("mind", 10.0)
	w.call("_poll_engine")
	var pmc: Color = ((w.get_node("Cultivator/Aura") as GPUParticles3D).process_material as ParticleProcessMaterial).color
	_check(pmc.r > 0.8 and pmc.g < 0.5, "aura reddens when strained")
	# Readiness ring: hidden when Qi is short, green when safe to cross.
	ge.set("realm_index", 0)
	ge.set("qi_bottleneck", 120.0)
	ge.set("qi", 0.0)
	w.call("_poll_engine")
	_check(not bool((w.get_node("Cultivator/ReadyRing") as MeshInstance3D).visible), "ring hidden below Late")
	ge.set("qi", 120.0)
	w.call("_poll_engine")
	var ring: MeshInstance3D = w.get_node("Cultivator/ReadyRing")
	_check(bool(ring.visible), "ring shows at full Qi")
	_check((ring.material_override as StandardMaterial3D).albedo_color.g > 0.9, "ring green when ready")
	# Soul charm appears once bound; gear ring swells with refinements.
	_check(not bool((w.get_node("Cultivator/SoulCharm") as Sprite3D).visible), "charm hidden unbound")
	ge.set("soulweapon", {"path": "soul_bell", "xp": 0})
	ge.set("gear", {"gear_riverband": 3})
	w.call("_poll_engine")
	_check(bool((w.get_node("Cultivator/SoulCharm") as Sprite3D).visible), "charm shows when bound")
	_check(bool((w.get_node("Cultivator/GearRing") as MeshInstance3D).visible), "gear ring shows refinements")

func _test_weather_tiers_beasts() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	_check(w.get_node_or_null("Weather") != null, "weather alive")
	_check(w.get_node_or_null("BeastGrounds") != null, "beast grounds ready")
	# Season switch reconfigures the sky: winter means snow.
	ge.set("_month_accum", 10)
	w.call("_poll_engine")
	_check(int((w.get_node("Weather") as GPUParticles3D).amount) == 260, "winter snow count")
	var wcol: Color = (((w.get_node("Weather") as GPUParticles3D).process_material) as ParticleProcessMaterial).color
	_check(wcol.b > 0.9 and wcol.r > 0.85, "winter snow pale")
	ge.set("_month_accum", 4)
	w.call("_poll_engine")
	_check(int((w.get_node("Weather") as GPUParticles3D).amount) == 120, "summer firefly count")
	# Tier grade deepens the light: tier 7 outshines tier 1.
	ge.set("realm_index", 0)
	w.call("_poll_engine")
	var e1: float = (w.get_node("Sun") as DirectionalLight3D).light_energy
	ge.set("realm_index", 48)
	w.call("_poll_engine")
	var e7: float = (w.get_node("Sun") as DirectionalLight3D).light_energy
	_check(e7 > e1, "ascendant light outshines dawn")
	# Beast row follows the walked grounds: Murkfen shows wood beasts.
	var CDB: GDScript = load("res://scripts/ContentDB.gd")
	var cdb: Node = CDB.new()
	cdb.call("load_all")
	ge.call("set_beast_pool", cdb.get("beasts"))
	cdb.free()
	ge.call("generate_map", 4242)
	var murk: String = ""
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) == "Murkfen":
			murk = str((n as Dictionary).get("id", ""))
			break
	ge.set("realm_index", 6)
	_check(bool(ge.call("travel_to", murk)), "walk murkfen")
	w.call("_poll_engine")
	_check(str(w.call("current_zone")) == "Murkfen", "world tracks walked zone")
	_check((w.get_node("BeastGrounds") as Node3D).get_child_count() > 0, "murkfen beasts on grounds")

func _test_budget() -> void:
	# Sanity budgets enforced by a FAILING test (not convention). P23
	# rule-11: gray-box islands hold far under the P14 caps (measured ~75
	# nodes / ~434 particles), so the caps stand unchanged; P23b dressing
	# may claim the ADR headroom (450 island + 120 ambient) with bench
	# evidence, never silently. Growth past caps must justify itself in
	# DECISIONS.md, not slip in silently.
	var w: Node = _world()
	_check(int(w.call("count_nodes")) <= 160, "world node budget")
	var b: Dictionary = w.call("particle_budget")
	_check(int(b.get("max_per_effect", 9999)) <= 384, "per-effect particle budget")
	_check(int(b.get("total", 9999)) <= 768, "total particle budget")
	_check(int(b.get("effects", 0)) >= 4, "all four effects staged")

func _test_presentation() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	_check(w.get_node_or_null("SectRow") != null, "sect row staged")
	_check(w.get_node_or_null("Cauldron") != null, "cauldron staged")
	_check(w.get_node_or_null("Cultivator/DevGlow") != null, "dev glow staged")
	# Disciples appear as duty-colored dots; herb stock piles bundles.
	ge.set("disciples", [{"task": "gather"}, {"task": "hunt"}, {"task": "idle"}])
	ge.set("herbs", 60.0)
	w.call("_poll_engine")
	_check((w.get_node("SectRow") as Node3D).get_child_count() == 3, "three disciples dotted")
	var bundles: int = 0
	for i in range(5):
		if bool((w.get_node("Cauldron/Herbs%d" % i) as MeshInstance3D).visible):
			bundles += 1
	_check(bundles == 2, "sixty herbs pile two bundles")
	# Deviation flaw glows red on the cultivator; clean hides it.
	ge.set("deviation", 2)
	w.call("_poll_engine")
	_check(bool((w.get_node("Cultivator/DevGlow") as Sprite3D).visible), "flaw glows")
	ge.set("deviation", 0)
	w.call("_poll_engine")
	_check(not bool((w.get_node("Cultivator/DevGlow") as Sprite3D).visible), "clean hides glow")
	# Factory variety: distinct ids paint distinct silhouettes (byte-exact).
	var shapes: Dictionary = {}
	for bid in ["beast_a", "beast_b", "beast_c", "beast_d", "beast_e", "beast_f", "beast_g", "beast_h"]:
		var t: Texture2D = SF.make_sprite("beast", bid, Color.WHITE)
		shapes[t.get_image().get_data()] = true
	_check(shapes.size() >= 2, "beast silhouettes vary")

func _test_tribulation_start() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	w.call("play_tribulation", "Shaky", 6)
	_check(bool(w.call("tribulation_active")), "sequence starts on demand")
	# Death mid-tribulation slumps the body; rebirth comes after.
	ge.emit_signal("died", "age")

func _test_tribulation_done() -> void:
	var w: Node = _world()
	var ge: Node = root.get_node("GameEngine")
	var bars_hidden: bool = true
	for i in range(4):
		if bool((w.get_node("Strike%d" % i) as MeshInstance3D).visible):
			bars_hidden = false
	_check(bars_hidden, "strike bars rest hidden")
	_check(w.get_node_or_null("Crack0") != null and w.get_node_or_null("Crack2") != null, "crack set staged")
	var modc: Color = (w.get_node("Cultivator/Body") as Sprite3D).modulate
	_check(modc.r < 0.6, "death slumps grey")
	ge.emit_signal("reborn", 2)
