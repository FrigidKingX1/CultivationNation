extends Node3D
## WorldView — 2.5D ink-wash diorama. Reads engine state/signals only; owns
## zero sim state. All sprites route through SpriteFactory (swappable art).
## No class_name (project convention). Scripts stay flat in scripts/.
## Headless-safe: pure node/resource construction, no draw calls; the tree
## exists headless so budget tests can walk it.

const SF: GDScript = preload("res://scripts/SpriteFactory.gd")

var _headless: bool = false
var _camera: Camera3D = null
var _sun: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _env: Environment = null
var _poll: float = 0.0
var _elapsed: float = 0.0
var _base_cam_pos := Vector3(14.0, 12.0, 14.0)
var _look_target := Vector3(0.0, 1.0, 0.0)

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_build_camera()
	_build_environment()
	_build_diorama()
	apply_zone("Dewfield")
	_build_cultivator()
	_build_weather()
	_apply_season(0)
	_apply_tier(1)
	_build_fx()
	_build_presentation()
	_connect_engine_signals()
	_sync_viewport_size()
	var root_vp: Viewport = get_tree().root
	if root_vp != null and not root_vp.size_changed.is_connected(_on_root_resized):
		root_vp.size_changed.connect(_on_root_resized)
	set_process(true)

func _engine() -> Node:
	return get_node_or_null("/root/GameEngine")

func set_glow(on: bool) -> void:
	## P17-Step3 settings toggle: world glow on/off. Headless-safe state flip.
	if _env != null:
		_env.glow_enabled = on

func cultivator_screen() -> Vector2:
	## P17-Step4: screen anchor for floating numbers. Falls back to viewport
	## center when headless, cameraless, or mid-build — never errors.
	if _camera != null and _cultivator != null:
		return _camera.unproject_position(_cultivator.global_position + Vector3(0, 2.2, 0))
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size * 0.5
	return Vector2(640, 360)

func _connect_engine_signals() -> void:
	## Death/rebirth transitions ride engine signals (Main's connect pattern).
	var ge := _engine()
	if ge == null:
		return
	if ge.has_signal("died") and not ge.is_connected("died", _on_died):
		ge.connect("died", _on_died)
	if ge.has_signal("reborn") and not ge.is_connected("reborn", _on_reborn):
		ge.connect("reborn", _on_reborn)

func _build_camera() -> void:
	## Fixed orthographic 3/4 view. A breath-slow sway gives living parallax
	## without ever handing the camera to the player.
	_camera = Camera3D.new()
	_camera.name = "OrthoCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 16.0
	# look_at_from_position: valid before entering the tree (look_at errors).
	_camera.look_at_from_position(_base_cam_pos, _look_target, Vector3.UP)
	_camera.current = true
	add_child(_camera)

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.07, 0.08, 0.11)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.58, 0.66)
	_env.ambient_light_energy = 0.9
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.55, 0.58, 0.66)
	_env.fog_density = 0.01
	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnv"
	_world_env.environment = _env
	add_child(_world_env)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	_sun.light_energy = 1.1
	_sun.shadow_enabled = true
	add_child(_sun)

func _on_root_resized() -> void:
	_sync_viewport_size()

func _sync_viewport_size() -> void:
	var vp: Viewport = get_viewport()
	if vp == null or not (vp is SubViewport):
		return
	var root_size: Vector2i = get_tree().root.size
	(vp as SubViewport).size = Vector2i(maxi(root_size.x, 320), maxi(root_size.y, 200))

func _process(delta: float) -> void:
	_elapsed += delta
	if _camera != null:
		var sway: float = sin(_elapsed * 0.1047) * 0.6
		_shake = maxf(0.0, _shake - delta * 1.5)
		var jolt := Vector3.ZERO
		if _shake > 0.01:
			jolt = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * _shake * 0.5
		_camera.position = _base_cam_pos + Vector3(sway * 0.4, 0.0, -sway * 0.4) + jolt
		_camera.look_at(_look_target, Vector3.UP)
	if _beast_row != null:
		for spr in _beast_row.get_children():
			if spr.has_meta("base_y") and spr is Node3D:
				(spr as Node3D).position.y = float(spr.get_meta("base_y")) + sin(_elapsed * 2.0 + float(spr.get_meta("phase"))) * 0.15
	if _dev_glow != null and _dev_glow.visible:
		var a: float = 0.45 + 0.25 * sin(_elapsed * 3.0)
		_dev_glow.modulate = Color(1.0, 0.25, 0.2, a)
	_poll += delta
	if _poll >= 0.25:
		_poll = 0.0
		_poll_engine()

func _poll_engine() -> void:
	_poll_cultivator()
	_poll_world_state()
	_poll_tribulation()
	_poll_representation()

# --- P14-3: cultivator rig, aura, attachments, readiness ring ---
var _cultivator: Node3D = null
var _body: Sprite3D = null
var _aura: GPUParticles3D = null
var _aura_mat: StandardMaterial3D = null
var _aura_pm: ParticleProcessMaterial = null
var _soul_charm: Sprite3D = null
var _gear_ring: MeshInstance3D = null
var _gear_ring_mat: StandardMaterial3D = null
var _ready_ring: MeshInstance3D = null
var _ready_ring_mat: StandardMaterial3D = null
var _last_robe_key: String = ""
var _last_mind: int = -1
var _last_aura_amount: int = -1
var _last_soul_key: String = "#"
var _last_gear_levels: int = -1
const AURA_COLORS := [Color(1.0, 0.85, 0.40), Color(0.40, 0.90, 0.80), Color(0.90, 0.35, 0.30)]
const SOUL_TINTS := {"soul_blade": Color(0.85, 0.30, 0.25), "soul_bell": Color(0.48, 0.71, 0.85), "soul_mirror": Color(0.81, 0.84, 0.87)}

func _unshaded(c: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission_energy
	return m

func _sprite_node(tex: Texture2D, pos: Vector3, pixel: float = 0.01) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.pixel_size = pixel
	s.position = pos
	return s

func _build_cultivator() -> void:
	_cultivator = Node3D.new()
	_cultivator.name = "Cultivator"
	_cultivator.position = Vector3(0, 0, 2.0)
	add_child(_cultivator)
	_body = _sprite_node(SF.make_sprite("cultivator", "", SF.element_color("unsettled")), Vector3(0, 1.0, 0))
	_body.name = "Body"
	_cultivator.add_child(_body)
	# Aura: rising motes; color = mind, density = toxicity + deviation.
	_aura = GPUParticles3D.new()
	_aura.name = "Aura"
	_aura.amount = 24
	_aura.lifetime = 2.2
	_aura.position = Vector3(0, 1.0, 0)
	_aura_pm = ParticleProcessMaterial.new()
	_aura_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_aura_pm.emission_sphere_radius = 0.9
	_aura_pm.direction = Vector3(0, 1, 0)
	_aura_pm.spread = 30.0
	_aura_pm.initial_velocity_min = 0.4
	_aura_pm.initial_velocity_max = 1.0
	_aura_pm.gravity = Vector3(0, 0.3, 0)
	_aura_pm.color = AURA_COLORS[1]
	_aura.process_material = _aura_pm
	_aura_mat = _unshaded(AURA_COLORS[1], 2.0)
	var mote := SphereMesh.new()
	mote.radius = 0.05
	mote.height = 0.1
	mote.radial_segments = 6
	mote.rings = 3
	mote.material = _aura_mat
	_aura.draw_pass_1 = mote
	_cultivator.add_child(_aura)
	# Soul charm: path-tinted glow, visible only once bound.
	_soul_charm = _sprite_node(SF.make_sprite("glow"), Vector3(0.9, 1.7, 0))
	_soul_charm.name = "SoulCharm"
	_soul_charm.visible = false
	_cultivator.add_child(_soul_charm)
	# Gear ring: legacy made visible; swells with total refinements.
	_gear_ring_mat = _unshaded(Color(0.85, 0.66, 0.22))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.05
	ring.outer_radius = 1.2
	ring.rings = 24
	ring.ring_segments = 6
	_gear_ring = MeshInstance3D.new()
	_gear_ring.name = "GearRing"
	_gear_ring.mesh = ring
	_gear_ring.material_override = _gear_ring_mat
	_gear_ring.position = Vector3(0, 0.56, 0)
	_gear_ring.visible = false
	_cultivator.add_child(_gear_ring)
	# Readiness ring: attemptability on the ground. Green = safe to cross,
	# amber = close, red = weak. Hidden until Qi reaches the Late layer.
	_ready_ring_mat = _unshaded(Color(0.4, 1.0, 0.5))
	var rring := TorusMesh.new()
	rring.inner_radius = 3.3
	rring.outer_radius = 3.5
	rring.rings = 40
	rring.ring_segments = 6
	_ready_ring = MeshInstance3D.new()
	_ready_ring.name = "ReadyRing"
	_ready_ring.mesh = rring
	_ready_ring.material_override = _ready_ring_mat
	_ready_ring.position = Vector3(0, 0.56, 0)
	_ready_ring.visible = false
	_cultivator.add_child(_ready_ring)

func _poll_cultivator() -> void:
	var ge := _engine()
	if ge == null:
		return
	# Robe follows the dominant root; rebuilt only on change.
	var glyph: String = str(ge.call("root_glyph"))
	if glyph != _last_robe_key:
		_last_robe_key = glyph
		_body.texture = SF.make_sprite("cultivator", "", SF.element_color(glyph))
	# Aura color = mind state; density = toxicity + deviation.
	var stage: int = int(ge.call("mind_stage"))
	if stage != _last_mind:
		_last_mind = stage
		_aura_pm.color = AURA_COLORS[clampi(stage, 0, 2)]
		_aura_mat.albedo_color = AURA_COLORS[clampi(stage, 0, 2)]
		_aura_mat.emission = AURA_COLORS[clampi(stage, 0, 2)]
	var want_amount: int = 24 + int(float(ge.get("toxicity")) * 0.24) + int(ge.get("deviation")) * 8
	if want_amount != _last_aura_amount:
		_last_aura_amount = want_amount
		_aura.amount = want_amount
	# Soul charm: bound path tints it; unbound hides it.
	var soul: Dictionary = ge.get("soulweapon")
	var skey: String = str(soul.get("path", ""))
	if skey != _last_soul_key:
		_last_soul_key = skey
		_soul_charm.visible = skey != ""
		if skey != "":
			_soul_charm.modulate = SOUL_TINTS.get(skey, Color.WHITE)
	# Gear ring swells with total refinements.
	var levels: int = 0
	for k in (ge.get("gear") as Dictionary):
		levels += int((ge.get("gear") as Dictionary).get(k, 0))
	if levels != _last_gear_levels:
		_last_gear_levels = levels
		_gear_ring.visible = levels > 0
		var s: float = 1.0 + minf(float(levels) * 0.02, 0.6)
		_gear_ring.scale = Vector3(s, 1.0, s)
	# Readiness ring: visible from the Late layer; color mirrors is_ready.
	if ge.call("fill_ratio") < 2.0 / 3.0:
		_ready_ring.visible = false
	else:
		_ready_ring.visible = true
		var need: float = float(ge.call("trib_power_for", int(ge.get("realm_index"))))
		var bonus: float = float(ge.call("best_technique_bonus"))
		if bool(ge.call("is_ready", 10.0, need, bonus)):
			_ready_ring_mat.albedo_color = Color(0.4, 1.0, 0.5)
		elif float(ge.call("readiness_pct", 10.0, need, bonus)) >= 70.0:
			_ready_ring_mat.albedo_color = Color(1.0, 0.8, 0.3)
		else:
			_ready_ring_mat.albedo_color = Color(1.0, 0.35, 0.3)

# --- P14-2: diorama + zone palettes ---
var _diorama: Node3D = null
var _mat_ground: StandardMaterial3D = null
var _mat_rock: Array = []
var _mat_platform: StandardMaterial3D = null
var _mat_trim: StandardMaterial3D = null
var _zone: String = ""
# Zone palettes: ground, rock, fog, sun tint. Display data (not sim): the
# engine owns zones/elements, the view owns how they look.
const ZONE_PALETTES := {
	"Dewfield": {"ground": Color(0.16, 0.24, 0.23), "rock": Color(0.23, 0.33, 0.38), "fog": Color(0.45, 0.55, 0.58), "sun": Color(1.0, 0.96, 0.88)},
	"Ashbarrow": {"ground": Color(0.25, 0.15, 0.13), "rock": Color(0.32, 0.20, 0.18), "fog": Color(0.55, 0.42, 0.38), "sun": Color(1.0, 0.82, 0.66)},
	"Gloamdeep": {"ground": Color(0.15, 0.15, 0.20), "rock": Color(0.30, 0.30, 0.38), "fog": Color(0.42, 0.42, 0.52), "sun": Color(0.82, 0.85, 1.0)},
	"Murkfen": {"ground": Color(0.14, 0.22, 0.14), "rock": Color(0.22, 0.30, 0.22), "fog": Color(0.45, 0.55, 0.42), "sun": Color(0.92, 1.0, 0.85)},
	"Stonehollow": {"ground": Color(0.26, 0.22, 0.16), "rock": Color(0.42, 0.36, 0.26), "fog": Color(0.60, 0.55, 0.45), "sun": Color(1.0, 0.94, 0.80)},
	"Stillmere": {"ground": Color(0.18, 0.24, 0.30), "rock": Color(0.45, 0.52, 0.60), "fog": Color(0.62, 0.68, 0.75), "sun": Color(0.92, 0.96, 1.0)},
	"Pyrefen": {"ground": Color(0.28, 0.14, 0.10), "rock": Color(0.45, 0.22, 0.14), "fog": Color(0.62, 0.40, 0.30), "sun": Color(1.0, 0.72, 0.52)},
	"Whitefoundry": {"ground": Color(0.30, 0.30, 0.32), "rock": Color(0.55, 0.55, 0.60), "fog": Color(0.65, 0.65, 0.70), "sun": Color(1.0, 0.98, 0.95)},
	"Thornwake": {"ground": Color(0.13, 0.18, 0.13), "rock": Color(0.25, 0.20, 0.30), "fog": Color(0.40, 0.48, 0.40), "sun": Color(0.85, 0.95, 0.80)},
}

func has_zone_palette(zone: String) -> bool:
	return ZONE_PALETTES.has(zone)

func current_zone() -> String:
	return _zone

func apply_zone(zone: String) -> void:
	## Reskin the diorama from the palette table. Unknown zones fall back to
	## Dewfield rather than erroring (data grows; the view never breaks).
	var z: String = zone if ZONE_PALETTES.has(zone) else "Dewfield"
	_zone = z
	var pal: Dictionary = ZONE_PALETTES[z]
	if _mat_ground != null:
		_mat_ground.albedo_color = pal["ground"]
	if _mat_rock.size() == 3:
		_mat_rock[0].albedo_color = (pal["rock"] as Color).darkened(0.15)
		_mat_rock[1].albedo_color = pal["rock"]
		_mat_rock[2].albedo_color = (pal["rock"] as Color).lightened(0.12)
	if _sun != null:
		_sun.light_color = pal["sun"]
	if _env != null:
		_env.fog_light_color = pal["fog"]

func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	m.metallic = 0.0
	return m

func _place(mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	_diorama.add_child(mi)
	return mi

func _build_diorama() -> void:
	_diorama = Node3D.new()
	_diorama.name = "Diorama"
	add_child(_diorama)
	_mat_ground = _flat_mat(Color(0.16, 0.24, 0.23))
	_mat_platform = _flat_mat(Color(0.35, 0.33, 0.30))
	_mat_trim = _flat_mat(Color(0.75, 0.60, 0.28))
	for i in range(3):
		_mat_rock.append(_flat_mat(Color(0.23, 0.33, 0.38)))
	# Ground slab.
	var ground := PlaneMesh.new()
	ground.size = Vector2(220.0, 220.0)
	_place(ground, _mat_ground, Vector3.ZERO)
	# Meditation platform: dais + cushion + four standing stones.
	var dais := CylinderMesh.new()
	dais.top_radius = 3.0
	dais.bottom_radius = 3.4
	dais.height = 0.5
	dais.radial_segments = 24
	_place(dais, _mat_platform, Vector3(0, 0.25, 2.0))
	var cushion := CylinderMesh.new()
	cushion.top_radius = 0.8
	cushion.bottom_radius = 0.95
	cushion.height = 0.3
	cushion.radial_segments = 16
	_place(cushion, _mat_trim, Vector3(0, 0.65, 2.0))
	for i in range(4):
		var a: float = float(i) * PI / 2.0 + PI / 4.0
		var stone := BoxMesh.new()
		stone.size = Vector3(0.7, 2.2 + float(i % 2), 0.7)
		_place(stone, _mat_platform, Vector3(cos(a) * 5.2, 0.9, 2.0 + sin(a) * 5.2))
	# Three mountain rings: near/mid/far, seeded-stable composition.
	var rng := RandomNumberGenerator.new()
	rng.seed = 137
	var rings: Array = [
		{"radius": 16.0, "count": 8, "hmin": 6.0, "hmax": 10.0, "mat": 0},
		{"radius": 26.0, "count": 10, "hmin": 10.0, "hmax": 16.0, "mat": 1},
		{"radius": 40.0, "count": 12, "hmin": 16.0, "hmax": 24.0, "mat": 2},
	]
	for ring in rings:
		for i in range(int(ring["count"])):
			var ang: float = float(i) / float(ring["count"]) * TAU + rng.randf() * 0.4
			var rad: float = float(ring["radius"]) + rng.randf_range(-1.5, 1.5)
			var h: float = rng.randf_range(float(ring["hmin"]), float(ring["hmax"]))
			var w: float = h * rng.randf_range(0.45, 0.65)
			var peak := CylinderMesh.new()
			peak.top_radius = 0.0
			peak.bottom_radius = w
			peak.height = h
			peak.radial_segments = 6
			_place(peak, _mat_rock[int(ring["mat"])], Vector3(cos(ang) * rad, h / 2.0 - 0.6, sin(ang) * rad))

# --- P14-4: season weather, tier grades, beast grounds ---
var _weather: GPUParticles3D = null
var _weather_pm: ParticleProcessMaterial = null
var _weather_mat: StandardMaterial3D = null
var _beast_row: Node3D = null
var _last_season: int = -1
var _last_tier: int = -1
var _last_beast_zone: String = "#"
# Season weather: color, count, fall speed, rise flag. Display only.
const SEASON_WEATHER := [
	{"color": Color(0.70, 0.90, 0.60), "amount": 160, "fall": 1.2, "rise": false},
	{"color": Color(1.00, 0.80, 0.30), "amount": 120, "fall": 0.0, "rise": true},
	{"color": Color(0.90, 0.60, 0.25), "amount": 200, "fall": 1.8, "rise": false},
	{"color": Color(0.90, 0.93, 1.00), "amount": 260, "fall": 0.9, "rise": false},
]
# Tier grades: sun energy/color, fog density, backdrop depth, glow push.
const TIER_GRADES := [
	{"sun_e": 1.0, "sun": Color(1.0, 0.96, 0.88), "fog": 0.008, "bg": Color(0.07, 0.08, 0.11), "glow": 0.5},
	{"sun_e": 1.1, "sun": Color(1.0, 0.90, 0.76), "fog": 0.010, "bg": Color(0.08, 0.08, 0.11), "glow": 0.6},
	{"sun_e": 1.2, "sun": Color(1.0, 0.86, 0.66), "fog": 0.013, "bg": Color(0.09, 0.08, 0.12), "glow": 0.7},
	{"sun_e": 1.3, "sun": Color(0.98, 0.88, 0.72), "fog": 0.016, "bg": Color(0.09, 0.09, 0.13), "glow": 0.8},
	{"sun_e": 1.4, "sun": Color(0.95, 0.90, 0.80), "fog": 0.020, "bg": Color(0.08, 0.09, 0.14), "glow": 0.9},
	{"sun_e": 1.5, "sun": Color(0.95, 0.93, 0.88), "fog": 0.025, "bg": Color(0.07, 0.08, 0.15), "glow": 1.0},
	{"sun_e": 1.7, "sun": Color(1.0, 0.98, 0.94), "fog": 0.030, "bg": Color(0.06, 0.07, 0.16), "glow": 1.2},
]

func _tier_of_realm(realm_index: int) -> int:
	## Macro tier purely for the grade lookup. Reads ContentDB display data
	## (never sim state); defaults to 1 when content is unreachable.
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb != null:
		var realms: Array = cdb.get("realms")
		if realm_index >= 0 and realm_index < realms.size():
			return clampi(int((realms[realm_index] as Dictionary).get("macro_tier", 1)), 1, 7)
	return 1

func _zone_of_node() -> String:
	var ge := _engine()
	if ge == null:
		return "Dewfield"
	var n: Dictionary = ge.call("node_by_id", str(ge.get("current_node")))
	var z: String = str(n.get("zone", ""))
	return z if z != "" else "Dewfield"

func _build_weather() -> void:
	_weather = GPUParticles3D.new()
	_weather.name = "Weather"
	_weather.amount = 160
	_weather.lifetime = 6.0
	_weather.position = Vector3(0, 8.0, 0)
	_weather.visibility_aabb = AABB(Vector3(-25, -10, -25), Vector3(50, 22, 50))
	_weather_pm = ParticleProcessMaterial.new()
	_weather_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_weather_pm.emission_box_extents = Vector3(22.0, 0.5, 22.0)
	_weather_pm.direction = Vector3(0, -1, 0)
	_weather_pm.spread = 12.0
	_weather_pm.initial_velocity_min = 0.8
	_weather_pm.initial_velocity_max = 1.6
	_weather_pm.gravity = Vector3(0.3, -0.4, 0.1)
	_weather_pm.color = Color(0.7, 0.9, 0.6)
	_weather.process_material = _weather_pm
	_weather_mat = _unshaded(Color(0.7, 0.9, 0.6), 1.2)
	var flake := SphereMesh.new()
	flake.radius = 0.06
	flake.height = 0.12
	flake.radial_segments = 6
	flake.rings = 3
	flake.material = _weather_mat
	_weather.draw_pass_1 = flake
	add_child(_weather)
	_beast_row = Node3D.new()
	_beast_row.name = "BeastGrounds"
	add_child(_beast_row)

func _apply_season(s: int) -> void:
	var w: Dictionary = SEASON_WEATHER[clampi(s, 0, 3)]
	_weather.amount = int(w["amount"])
	_weather_pm.color = w["color"]
	_weather_mat.albedo_color = w["color"]
	_weather_mat.emission = w["color"]
	if bool(w["rise"]):
		_weather_pm.direction = Vector3(0, 1, 0)
		_weather_pm.initial_velocity_min = 0.3
		_weather_pm.initial_velocity_max = 0.8
		_weather_pm.gravity = Vector3(0, 0.25, 0)
	else:
		_weather_pm.direction = Vector3(0, -1, 0)
		_weather_pm.initial_velocity_min = 0.8
		_weather_pm.initial_velocity_max = 1.6
		_weather_pm.gravity = Vector3(0.3, -0.4, 0.1)

func _apply_tier(t: int) -> void:
	var g: Dictionary = TIER_GRADES[clampi(t, 1, 7) - 1]
	if _sun != null:
		_sun.light_energy = float(g["sun_e"])
		_sun.light_color = g["sun"]
	if _env != null:
		_env.fog_density = float(g["fog"])
		_env.background_color = g["bg"]
		_env.glow_intensity = float(g["glow"])

func _element_of_beast(beast_id: String) -> String:
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb != null:
		for b in (cdb.get("beasts") as Array):
			if str((b as Dictionary).get("id", "")) == beast_id:
				return str((b as Dictionary).get("element", ""))
	return ""

func _rebuild_beasts(zone: String) -> void:
	for c in _beast_row.get_children():
		_beast_row.remove_child(c)
		c.queue_free()
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb == null:
		return
	var shown: int = 0
	for b in (cdb.get("beasts") as Array):
		if shown >= 6:
			break
		if str((b as Dictionary).get("zone", "")) != zone:
			continue
		var el: String = str((b as Dictionary).get("element", ""))
		var spr := _sprite_node(SF.make_sprite("beast", str((b as Dictionary).get("id", "")), SF.element_color(el)), Vector3(-7.5 + float(shown) * 3.0, 1.0, -4.0 - float(shown % 2) * 2.5))
		spr.set_meta("base_y", 1.0)
		spr.set_meta("phase", float(shown) * 1.1)
		_beast_row.add_child(spr)
		shown += 1

func _poll_world_state() -> void:
	var ge := _engine()
	# Zone follows the walked grounds (Dewfield before the first journey).
	var z: String = _zone_of_node()
	if z != _last_beast_zone or _zone != z:
		apply_zone(z)
		_last_beast_zone = z
		if _beast_row != null:
			_rebuild_beasts(z)
	if ge == null:
		return
	var s: int = int(ge.call("season_index"))
	if s != _last_season:
		_last_season = s
		_apply_season(s)
	var t: int = _tier_of_realm(int(ge.get("realm_index")))
	if t != _last_tier:
		_last_tier = t
		_apply_tier(t)

# --- P14-5: tribulation sequences, death/rebirth, camera shake ---
var _charge_fx: GPUParticles3D = null
var _burst_fx: GPUParticles3D = null
var _burst_mat: StandardMaterial3D = null
var _burst_pm: ParticleProcessMaterial = null
var _strike_bars: Array = []
var _cracks: Array = []
var _shake: float = 0.0
var _trib_active: bool = false
var _last_seen_quality: String = ""
const QUALITY_BURST := {
	"Radiant": {"color": Color(1.0, 0.85, 0.35), "amount": 120, "shake": 0.15},
	"Steady": {"color": Color(0.40, 0.90, 0.80), "amount": 70, "shake": 0.25},
	"Shaky": {"color": Color(0.90, 0.30, 0.25), "amount": 120, "shake": 0.6},
}

func tribulation_active() -> bool:
	return _trib_active

func _build_fx() -> void:
	_charge_fx = _oneshot_fx("ChargeFx", 80, Color(1.0, 0.85, 0.4), Vector3(0, 1.2, 2.0), 2.5)
	_burst_fx = _oneshot_fx("BurstFx", 70, Color(1.0, 0.85, 0.35), Vector3(0, 1.5, 2.0), 5.0)
	_burst_pm = _burst_fx.process_material as ParticleProcessMaterial
	_burst_mat = ((_burst_fx.draw_pass_1 as Mesh).surface_get_material(0) as StandardMaterial3D)
	for i in range(4):
		var bar := MeshInstance3D.new()
		bar.name = "Strike%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 9.0, 0.18)
		bar.mesh = bm
		bar.material_override = _unshaded(Color(1.0, 0.98, 0.9), 4.0)
		bar.position = Vector3(-2.5 + float(i) * 1.7, 5.0, 2.0)
		bar.visible = false
		add_child(bar)
		_strike_bars.append(bar)
	for i in range(3):
		var crack := MeshInstance3D.new()
		crack.name = "Crack%d" % i
		var cm := BoxMesh.new()
		cm.size = Vector3(2.6, 0.06, 0.3)
		crack.mesh = cm
		crack.material_override = _unshaded(Color(0.9, 0.25, 0.2), 2.5)
		crack.position = Vector3(-1.5 + float(i) * 1.5, 0.56, 2.0)
		crack.rotation.y = float(i) * 0.7
		crack.visible = false
		add_child(crack)
		_cracks.append(crack)

func _oneshot_fx(fxname: String, amount: int, color: Color, pos: Vector3, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = fxname
	p.amount = amount
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = false
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = speed * 0.6
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -4, 0)
	pm.color = color
	p.process_material = pm
	var mote := SphereMesh.new()
	mote.radius = 0.07
	mote.height = 0.14
	mote.radial_segments = 6
	mote.rings = 3
	mote.material = _unshaded(color, 2.5)
	p.draw_pass_1 = mote
	add_child(p)
	return p

func _poll_tribulation() -> void:
	var ge := _engine()
	if ge == null:
		return
	var q: String = str(ge.get("last_quality"))
	if q != "" and q != _last_seen_quality:
		_last_seen_quality = q
		if QUALITY_BURST.has(q):
			play_tribulation(q, (ge.get("last_tribulation") as Array).size())

func play_tribulation(quality: String, waves: int) -> void:
	## Starts the buildup → strikes → outcome sequence. Async fire-and-forget;
	## tribulation_active() reports completion. Re-entrant calls while active
	## are ignored (attempts are player-paced; nothing gets stuck).
	if _trib_active:
		return
	_trib_active = true
	_run_tribulation(quality, waves)

func _run_tribulation(quality: String, waves: int) -> void:
	# Buildup: heavens darken, charge gathers.
	var sun_e: float = 1.1
	if _sun != null:
		sun_e = _sun.light_energy
		var dim := create_tween()
		dim.tween_property(_sun, "light_energy", sun_e * 0.35, 0.5)
	_charge_fx.restart()
	await get_tree().create_timer(0.5).timeout
	# Strikes: at most a readable handful, whatever the true count.
	var shown: int = clampi(waves, 0, 6)
	for i in range(maxi(shown, 1) if waves > 0 else 0):
		_flash_strike(i)
		await get_tree().create_timer(0.18).timeout
	# Outcome burst scaled to quality.
	var qb: Dictionary = QUALITY_BURST.get(quality, QUALITY_BURST["Steady"])
	_burst_fx.amount = int(qb["amount"])
	_burst_pm.color = qb["color"]
	_burst_mat.albedo_color = qb["color"]
	_burst_mat.emission = qb["color"]
	_burst_fx.restart()
	_shake = maxf(_shake, float(qb["shake"]))
	if quality == "Shaky":
		_show_cracks()
	elif quality == "Radiant" and _sun != null:
		var flash := create_tween()
		flash.tween_property(_sun, "light_energy", sun_e * 1.6, 0.15)
		flash.tween_property(_sun, "light_energy", sun_e, 0.6)
	elif _sun != null:
		var back := create_tween()
		back.tween_property(_sun, "light_energy", sun_e, 0.6)
	await get_tree().create_timer(0.6).timeout
	_trib_active = false

func _flash_strike(i: int) -> void:
	if i < 0 or i >= _strike_bars.size():
		return
	var bar: MeshInstance3D = _strike_bars[i]
	bar.position.x = -2.5 + float(i) * 1.7 + randf_range(-0.5, 0.5)
	bar.visible = true
	_shake = maxf(_shake, 0.3)
	var fl := create_tween()
	fl.tween_property(bar, "scale:y", 0.55, 0.07)
	fl.tween_property(bar, "scale:y", 1.0, 0.07)
	fl.tween_callback(func() -> void: bar.visible = false)

func _show_cracks() -> void:
	for crack in _cracks:
		(crack as MeshInstance3D).visible = true
		(crack as MeshInstance3D).scale = Vector3.ONE
		var fade := create_tween()
		fade.tween_interval(0.4)
		fade.tween_property(crack, "scale", Vector3(1.6, 1.0, 1.6), 0.8)
		fade.tween_callback(func() -> void: (crack as MeshInstance3D).visible = false)

func _on_died(_cause: String) -> void:
	## The cultivator slumps grey; fog closes in. Restored on rebirth.
	if _body != null:
		var slump := create_tween().set_parallel(true)
		slump.tween_property(_body, "modulate", Color(0.45, 0.45, 0.5, 1.0), 0.8)
		slump.tween_property(_body, "scale", Vector3(1.0, 0.55, 1.0), 0.8)
	if _env != null:
		var gloom := create_tween()
		gloom.tween_property(_env, "fog_density", 0.06, 0.8)

func _on_reborn(_life_number: int) -> void:
	## Dawn relight: body rises restored, gold witness-burst, fog lifts.
	if _body != null:
		var rise := create_tween().set_parallel(true)
		rise.tween_property(_body, "modulate", Color.WHITE, 0.6)
		rise.tween_property(_body, "scale", Vector3.ONE, 0.6)
	if _env != null:
		var lift := create_tween()
		lift.tween_property(_env, "fog_density", 0.01, 1.0)
	_burst_fx.amount = 60
	_burst_pm.color = Color(1.0, 0.85, 0.35)
	_burst_mat.albedo_color = Color(1.0, 0.85, 0.35)
	_burst_mat.emission = Color(1.0, 0.85, 0.35)
	_burst_fx.restart()
	_last_seen_quality = ""
	_poll_engine()

# --- P16-Step3: sect, alchemy, and deviation made visible ---
var _sect_row: Node3D = null
var _cauldron: Node3D = null
var _herb_bundles: Array = []
var _dev_glow: Sprite3D = null
var _last_sect_sig: String = "#"
var _last_herb_stacks: int = -1
const TASK_COLORS := {"gather": Color(0.4, 0.9, 0.5), "hunt": Color(0.9, 0.4, 0.35), "train": Color(1.0, 0.8, 0.3), "idle": Color(0.5, 0.5, 0.55)}

func _build_presentation() -> void:
	_sect_row = Node3D.new()
	_sect_row.name = "SectRow"
	add_child(_sect_row)
	_cauldron = Node3D.new()
	_cauldron.name = "Cauldron"
	_cauldron.position = Vector3(-4.2, 0, 5.0)
	add_child(_cauldron)
	var pot := MeshInstance3D.new()
	pot.name = "Pot"
	var body := CylinderMesh.new()
	body.top_radius = 0.7
	body.bottom_radius = 0.55
	body.height = 0.9
	body.radial_segments = 12
	pot.mesh = body
	pot.material_override = _flat_mat(Color(0.25, 0.20, 0.16))
	pot.position = Vector3(0, 0.45, 0)
	_cauldron.add_child(pot)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.75
	torus.rings = 16
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = _flat_mat(Color(0.55, 0.45, 0.30))
	rim.position = Vector3(0, 0.9, 0)
	_cauldron.add_child(rim)
	for i in range(5):
		var bundle := MeshInstance3D.new()
		bundle.name = "Herbs%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 0.25, 0.35)
		bundle.mesh = bm
		bundle.material_override = _flat_mat(Color(0.35, 0.60, 0.30))
		bundle.position = Vector3(1.1 + float(i % 3) * 0.45, 0.13 + float(i / 3) * 0.28, float(i % 2) * 0.4 - 0.2)
		bundle.visible = false
		_cauldron.add_child(bundle)
		_herb_bundles.append(bundle)
	_dev_glow = _sprite_node(SF.make_sprite("glow"), Vector3(0, 1.0, 0))
	_dev_glow.name = "DevGlow"
	_dev_glow.modulate = Color(1.0, 0.25, 0.2, 0.55)
	_dev_glow.scale = Vector3(2.0, 2.0, 2.0)
	_dev_glow.visible = false
	_cultivator.add_child(_dev_glow)

func _poll_representation() -> void:
	var ge := _engine()
	if ge == null:
		return
	# Sect dots: one per disciple (capped at 8 shown), colored by duty.
	var sig_parts: PackedStringArray = []
	for d in (ge.get("disciples") as Array):
		sig_parts.append(str((d as Dictionary).get("task", "idle")))
	var sig: String = ";".join(sig_parts)
	if sig != _last_sect_sig:
		_last_sect_sig = sig
		for c in _sect_row.get_children():
			_sect_row.remove_child(c)
			c.queue_free()
		var shown: int = 0
		for d in (ge.get("disciples") as Array):
			if shown >= 8:
				break
			var dot := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.14
			sm.height = 0.28
			sm.radial_segments = 8
			sm.rings = 4
			dot.mesh = sm
			dot.material_override = _unshaded(TASK_COLORS.get(str((d as Dictionary).get("task", "idle")), Color.WHITE))
			dot.position = Vector3(-5.25 + float(shown) * 1.5, 0.5, -1.5)
			_sect_row.add_child(dot)
			shown += 1
	# Herb bundles: one per 25 herbs, five shown max.
	var stacks: int = clampi(int(float(ge.get("herbs")) / 25.0), 0, 5)
	if stacks != _last_herb_stacks:
		_last_herb_stacks = stacks
		for i in range(_herb_bundles.size()):
			(_herb_bundles[i] as MeshInstance3D).visible = i < stacks
	# Deviation flaw glows red on the cultivator, swelling per flaw.
	var dev: int = int(ge.get("deviation"))
	_dev_glow.visible = dev > 0
	if dev > 0:
		var s: float = 2.0 + 0.6 * float(dev)
		_dev_glow.scale = Vector3(s, s, s)

# --- Budget helpers (P14-6 failing test walks these) ---
func count_nodes() -> int:
	return _count_recursive(self)

func _count_recursive(n: Node) -> int:
	var t: int = 1
	for c in n.get_children():
		t += _count_recursive(c)
	return t

func particle_budget() -> Dictionary:
	var out: Dictionary = {"total": 0, "max_per_effect": 0, "effects": 0}
	_sum_particles(self, out)
	return out

func _sum_particles(n: Node, out: Dictionary) -> void:
	if n is GPUParticles3D:
		var a: int = int((n as GPUParticles3D).amount)
		out["total"] = int(out["total"]) + a
		out["max_per_effect"] = maxi(int(out["max_per_effect"]), a)
		out["effects"] = int(out["effects"]) + 1
	for c in n.get_children():
		_sum_particles(c, out)
