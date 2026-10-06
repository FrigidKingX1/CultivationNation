extends Node3D
## WorldView — true-3D island world (P23). Reads engine state/signals only;
## owns zero sim state. Nine floating zone islands in a cloud sea replace
## the ink-wash diorama; camera is a perspective orbit rig (player-driven).
## Facade preserved member-for-member (contract:
## docs/qa/p23_worldview_contract.txt): method names, signatures, and the
## C1-C9 semantic surfaces in docs/adr/P23_COUPLING_ADDENDUM.md.
## No class_name (project convention). Scripts stay flat in scripts/.
## Headless-safe: pure node/resource construction, no draw calls; the tree
## exists headless so budget tests can walk it.

const SF: GDScript = preload("res://scripts/SpriteFactory.gd")

var _headless: bool = false
var _camera: Camera3D = null
var _cam_yaw: Node3D = null
var _cam_pitch: Node3D = null
var _cam_rig: Node3D = null
var _sun: DirectionalLight3D = null
var _world_env: WorldEnvironment = null
var _env: Environment = null
var _poll: float = 0.0
var _elapsed: float = 0.0
# Orbit state: yaw/pitch around the focus point, clamped zoom distance.
var _orbit_yaw: float = 0.6
var _orbit_pitch: float = -0.5
var _orbit_dist: float = 26.0
var _focus_target := Vector3.ZERO
var _fly_debug: bool = false

func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_build_camera()
	_build_environment()
	_build_cloud_sea()
	_load_zones()
	_build_islands()
	apply_zone("Dewfield")
	_build_cultivator()
	_build_weather()
	_apply_season(0)
	_apply_tier(1)
	_build_fx()
	_build_presentation()
	_connect_engine_signals()
	_sync_viewport_size()
	_focus_on_island(_zone)
	var root_vp: Viewport = get_tree().root
	if root_vp != null and not root_vp.size_changed.is_connected(_on_root_resized):
		root_vp.size_changed.connect(_on_root_resized)
	set_process(true)
	set_process_unhandled_input(true)

func _engine() -> Node:
	return get_node_or_null("/root/GameEngine")

func set_glow(on: bool) -> void:
	## P17-Step3 settings toggle: world glow on/off. Headless-safe state flip.
	if _env != null:
		_env.glow_enabled = on

func cultivator_screen() -> Vector2:
	## P17-Step4: screen anchor for floating numbers. Falls back to viewport
	## center when headless, cameraless, or mid-build — never errors.
	## C1: same return space as before (SubViewport -> canvas translation
	## owned by the view; Main's call sites unchanged).
	if _camera != null and _cultivator != null and _camera.is_position_in_frustum(_cultivator.global_position):
		return _camera.unproject_position(_cultivator.global_position + Vector3(0, 2.2, 0))
	if _camera != null and _cultivator != null:
		return _camera.unproject_position(_cultivator.global_position + Vector3(0, 2.2, 0))
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size * 0.5
	return Vector2(640, 360)

func _connect_engine_signals() -> void:
	## Death/rebirth transitions ride engine signals (Main's connect pattern).
	## C3: same signals consumed, same visual beats, nothing new invented.
	var ge := _engine()
	if ge == null:
		return
	if ge.has_signal("died") and not ge.is_connected("died", _on_died):
		ge.connect("died", _on_died)
	if ge.has_signal("reborn") and not ge.is_connected("reborn", _on_reborn):
		ge.connect("reborn", _on_reborn)

func _build_camera() -> void:
	## P23: perspective orbit rig. Drag-rotate, wheel zoom (clamped), focus
	## target = current island POI. Replaces the fixed orthographic 3/4 cam
	## (rule-11: p14 camera assertions migrated with citation).
	_cam_rig = Node3D.new()
	_cam_rig.name = "CamRig"
	add_child(_cam_rig)
	_cam_yaw = Node3D.new()
	_cam_yaw.name = "Yaw"
	_cam_rig.add_child(_cam_yaw)
	_cam_pitch = Node3D.new()
	_cam_pitch.name = "Pitch"
	_cam_yaw.add_child(_cam_pitch)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 55.0
	_camera.far = 4000.0
	_camera.current = true
	_cam_pitch.add_child(_camera)
	_update_camera()

func _update_camera() -> void:
	if _cam_rig == null or _cam_yaw == null or _cam_pitch == null or _camera == null:
		return
	_cam_rig.position = _focus_target
	_cam_yaw.rotation.y = _orbit_yaw
	_cam_pitch.rotation.x = _orbit_pitch
	_camera.position = Vector3(0, 0, _orbit_dist)

func _ui_open() -> bool:
	## Orbit input suspends while panels or overlays are up (P17 input
	## contract: panels STOP, world IGNORE — no rotation under UI).
	var main: Node = get_node_or_null("/root/Main")
	if main == null:
		return false
	for p in ["UI/Root/SidePanel", "UI/Root/HelpOverlay", "UI/Root/TitleOverlay"]:
		var c: Node = main.get_node_or_null(p) as Node
		if c != null and (c as Control).visible:
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	## Camera input is raw mouse/wheel (Escape raw-key precedent): the 13
	## action InputMap contract is untouched in 0.22.0. F12 free-fly is a
	## documented debug key, not an action.
	if _ui_open():
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		_orbit_yaw -= (event as InputEventMouseMotion).relative.x * 0.005
		_orbit_pitch = clampf(_orbit_pitch - (event as InputEventMouseMotion).relative.y * 0.005, -1.2, 0.35)
		_update_camera()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b: int = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			_orbit_dist = clampf(_orbit_dist - 2.0, 8.0, 60.0)
			_update_camera()
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_dist = clampf(_orbit_dist + 2.0, 8.0, 60.0)
			_update_camera()
		elif b == MOUSE_BUTTON_RIGHT and str(avatar_fight_state()) == "fighting":
			avatar_strike()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).physical_keycode == KEY_F12:
			_fly_debug = not _fly_debug

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
	_shake = maxf(0.0, _shake - delta * 1.5)
	if _camera != null:
		var jolt := Vector2.ZERO
		if _shake > 0.01:
			jolt = Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * _shake * 12.0
		_camera.h_offset = jolt.x
		_camera.v_offset = jolt.y
	if _fly_debug and not _ui_open():
		var spd: float = 24.0 * delta
		var move := Vector3.ZERO
		if Input.is_key_pressed(KEY_W):
			move.z -= spd
		if Input.is_key_pressed(KEY_S):
			move.z += spd
		if Input.is_key_pressed(KEY_A):
			move.x -= spd
		if Input.is_key_pressed(KEY_D):
			move.x += spd
		if Input.is_key_pressed(KEY_Q):
			move.y -= spd
		if Input.is_key_pressed(KEY_E):
			move.y += spd
		if move != Vector3.ZERO:
			_focus_target += (_cam_yaw.global_transform.basis * move)
			_focus_target.x = clampf(_focus_target.x, -2000.0, 2000.0)
			_focus_target.y = clampf(_focus_target.y, -500.0, 500.0)
			_focus_target.z = clampf(_focus_target.z, -2000.0, 2000.0)
			_update_camera()
	_poll_avatar(delta)
	_update_follow()
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
	## C4: the single pump of engine state into the view. Tests invoke it
	## directly; keep it the single pump, idempotent per call.
	_poll_seed()
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

func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	m.metallic = 0.0
	return m

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

# --- P24a: avatar presence (idle/walk; meditate/fly land in P24b) ---
# --- P24b: meditate + fly states live here. ---
# The cultivator rig IS the avatar: robe tint + aura carry over, and
# cultivator_screen() keeps projecting it (C1 return-space unchanged).
var _avatar_state: String = "idle"
const WALK_SPEED := 8.0
# R-S7: FLY_MULT scales AVATAR-MOVEMENT speed (units/sec multiplier).
# It must not be confused with PRESENCE_MULT, which scales the COMPILED
# QI RATE engine-side. Two constants, two scales, both named.
const FLY_MULT := 2.5
const INTERACT_RADIUS := 6.0
var _fly_mult: float = 1.0
var _node_marks: Node3D = null
var _stride_note: String = "#"

func avatar_state() -> String:
	## Headless-readable avatar state: idle, walk, meditate, fly.
	return _avatar_state

func avatar_move(dir: Vector2, dt: float = 0.016) -> void:
	## Headless-testable movement primitive: walks the avatar on the
	## active island, clamped to 90% of its radius. Direction is
	## island-local XZ. Zero direction rests to idle.
	if _cultivator == null:
		return
	var entry: Dictionary = _zone_entry(_zone if _zone != "" else "Dewfield")
	var r: float = float(entry.get("size_radius", 200.0))
	var spawn: Array = ((entry.get("spawn", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0]) as Array)
	var cx: float = float(spawn[0])
	var cz: float = float(spawn[2])
	if dir.length() < 0.01:
		_avatar_state = "idle"
		return
	if avatar_lock_reason() != "":
		# R13: locked grounds refuse strides from ANY caller (tests drive
		# avatar_move directly; the live poll checks too).
		_avatar_state = "idle"
		return
	if _avatar_state == "meditate":
		_break_meditation()
	var p: Vector3 = _cultivator.position + Vector3(dir.x, 0.0, dir.y) * WALK_SPEED * _fly_mult * maxf(dt, 0.0)
	var flat := Vector2(p.x - cx, p.z - cz)
	if flat.length() > r * 0.9:
		flat = flat.normalized() * r * 0.9
	_cultivator.position = Vector3(cx + flat.x, p.y, cz + flat.y)
	_avatar_state = "walk"

func set_avatar_flying(on: bool) -> void:
	## Sword-mount pose + speed. Only Main calls this (after the flight
	## unlock check); the state machine otherwise owns the avatar.
	if _cultivator == null:
		return
	if on:
		_fly_mult = FLY_MULT
		_avatar_state = "fly"
		_cultivator.position.y += 1.5
		_cultivator.rotation.x = -0.25
	else:
		_fly_mult = 1.0
		if _avatar_state == "fly":
			_avatar_state = "idle"
			_cultivator.position.y = maxf(_cultivator.position.y - 1.5, 0.0)
		_cultivator.rotation.x = 0.0

func avatar_lock_reason() -> String:
	## Warded-style walking rule, read off existing engine zone data
	## (R13 discipline: no duplicate rule logic). "" means walkable.
	var ge := _engine()
	if ge == null:
		return ""
	var entry: Dictionary = _zone_entry(_zone if _zone != "" else "Dewfield")
	var need: int = int((entry.get("gate", {}) as Dictionary).get("min_realm", 0))
	if int(ge.get("realm_index")) >= need:
		return ""
	return "The %s grounds want realm %d." % [str(entry.get("id", "?")), need]

func avatar_near_node() -> String:
	## Map node within interaction radius of the avatar, else "".
	var ge := _engine()
	if ge == null or _cultivator == null or _node_marks == null:
		return ""
	for m in _node_marks.get_children():
		if not (m as Node3D).visible:
			continue
		var mp: Vector3 = (m as Node3D).global_position
		var ap: Vector3 = _cultivator.global_position
		if Vector2(mp.x - ap.x, mp.z - ap.z).length() <= INTERACT_RADIUS:
			return str(m.get_meta("node_id", ""))
	return ""

var _shrine_request: String = ""
var _challenge_beast: String = ""

func avatar_den_near() -> String:
	## Beast den (marker) within interaction radius, else "".
	if _cultivator == null or _beast_row == null:
		return ""
	for m in _beast_row.get_children():
		if not (m as Node3D).visible:
			continue
		var mp: Vector3 = (m as Node3D).global_position
		var ap: Vector3 = _cultivator.global_position
		if Vector2(mp.x - ap.x, mp.z - ap.z).length() <= INTERACT_RADIUS:
			return str(m.get_meta("beast_id", ""))
	return ""

func avatar_shrine_near() -> String:
	## Guardian id whose flame stands within interaction radius, else "".
	## Shrines live on resident islands; only the active neighborhood
	## is reachable, which is exactly the design.
	if _cultivator == null:
		return ""
	var ap: Vector3 = _cultivator.global_position
	for iz in _island_order:
		var n: Node = _islands.get(str(iz)) as Node
		if n == null:
			continue
		for fname in ["ShrineFlame", "SentinelFlame"]:
			var f: MeshInstance3D = n.get_node_or_null(fname) as MeshInstance3D
			if f == null:
				continue
			var fp: Vector3 = f.global_position
			if Vector2(fp.x - ap.x, fp.z - ap.z).length() <= INTERACT_RADIUS:
				return str(f.get_meta("guardian_id", ""))
	return ""

func take_shrine_request() -> String:
	## One-shot consume for Main's poll: interact at a shrine queues the
	## tier's guardian; Main opens the EXISTING duel flow for it.
	var out: String = _shrine_request
	_shrine_request = ""
	return out

func avatar_challenge() -> String:
	## Beast id currently challenged ("" when none). P25a: entry state
	## only — the exchange loop lands in P25b.
	return _challenge_beast

func _engine_running() -> bool:
	var ge := _engine()
	if ge == null:
		return true
	return bool(ge.get("running"))

func _poll_avatar(dt: float) -> void:
	## Live movement: WASD world actions while playing with panels closed.
	## Same UIManager gating source as orbit input — one rule, two cameras.
	## Locked grounds refuse strides (R13: engine zone rules, view-side
	## enforcement only). Interact at a node marker meditates (presence);
	## any stride breaks meditation.
	if _ui_open() or not _engine_running():
		if _avatar_state == "walk":
			_avatar_state = "idle"
		return
	if avatar_lock_reason() != "":
		if _avatar_state == "walk" or _avatar_state == "meditate":
			_avatar_state = "idle"
		_break_meditation()
		return
	var dir := Vector2.ZERO
	if Input.is_action_pressed("world_move_forward"):
		dir.y -= 1.0
	if Input.is_action_pressed("world_move_back"):
		dir.y += 1.0
	if Input.is_action_pressed("world_move_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("world_move_right"):
		dir.x += 1.0
	if dir.length() > 0.01:
		if _avatar_state == "meditate":
			_break_meditation()
		avatar_move(dir.normalized() if dir.length() > 1.0 else dir, dt)
		return
	if Input.is_action_pressed("world_interact"):
		_try_interact()
		return
	if _avatar_state == "walk":
		_avatar_state = "idle"

func _try_interact() -> void:
	## P25a: interact routing — den first, then shrine, then node.
	## Dens challenge (or refuse warded-style below strength); shrines
	## queue their guardian for Main's duel flow; nodes meditate.
	## The fight exchange loop itself lands in P25b.
	var ge := _engine()
	if ge == null or not _engine_running():
		return
	if _avatar_state == "fly":
		return
	var den: String = avatar_den_near()
	if den != "":
		_try_den(den)
		return
	var shrine: String = avatar_shrine_near()
	if shrine != "":
		_shrine_request = shrine
		_avatar_state = "idle"
		return
	_try_meditate()

func _try_den(beast_id: String) -> void:
	## P25b: den challenge entry. Refusal below quarter strength (power
	## ratio under 0.25, read off skirmish_stats — R13, no duplicate
	## logic); the accepted 0.25+ band includes losable underdog fights,
	## which is what makes manual outcomes meaningful. Accepted challenges
	## stage the beast id; the exchange loop resolves them below.
	## (P25a refused below parity; the P25b loop needs the wider band.)
	_challenge_beast = ""
	var ge := _engine()
	if ge == null or str(beast_id) == "":
		return
	var st: Dictionary = ge.call("skirmish_stats", str(beast_id))
	if not bool(st.get("ok", false)):
		return
	var ratio: float = float(st.get("cult_dmg", 0.0)) / maxf(float(st.get("beast_power", 1.0)), 0.001)
	if ratio < 0.25:
		_den_outcome = {"beast": str(beast_id), "accepted": false}
		_avatar_state = "idle"
		return
	_challenge_beast = str(beast_id)
	_den_outcome = {"beast": str(beast_id), "accepted": true}
	_avatar_state = "idle"

var _den_outcome: Dictionary = {}

func take_den_outcome() -> Dictionary:
	## One-shot consume for Main's poll: voices challenge entry + refusal.
	var out: Dictionary = _den_outcome
	_den_outcome = {}
	return out

# --- P25b: manual skirmish (Q34-C design: docs/adr/P25_COMBAT_DESIGN.md) ---
# Shared gated clock: ONE combat tick elapses per landed attack, up to
# TEMPO_CLAMP_TPS ticks/sec. No attack -> no tick -> BOTH sides frozen:
# tempo gates delivery speed only. Same stats + same input trace ->
# identical outcome (tested). Wall-clock duration = ticks / tempo.
# R-S7: BONUS_TEMPO_FRAC is a fraction of the tempo clamp (dimensionless);
# BONUS_XP is technique XP (existing economy unit, Q35 via existing API).
const TEMPO_CLAMP_TPS := 2.5
const BONUS_TEMPO_FRAC := 0.8
const BONUS_XP := 100
var _fight: Dictionary = {}
var _fight_outcome: Dictionary = {}
var _fight_hud: Node3D = null
var _fight_beast_bar: MeshInstance3D = null
var _fight_self_bar: MeshInstance3D = null
var _fight_beast_label: Label3D = null
var _fight_self_label: Label3D = null

func avatar_fight_state() -> String:
	## idle | fighting | won | lost. Won/lost persist until consumed by
	## take_fight_outcome() or a new challenge starts.
	return str(_fight.get("phase", "idle"))

func avatar_fight(beast_id: String) -> Dictionary:
	## Open a manual skirmish. Requires a staged challenge for the same
	## beast (P25a entry); refused or busy otherwise. Initializes HP from
	## skirmish_stats and stages the HUD. No ticks elapse here.
	if str(beast_id) == "" or str(beast_id) != str(_challenge_beast):
		return {"ok": false, "reason": "no_challenge"}
	if str(avatar_fight_state()) == "fighting":
		return {"ok": false, "reason": "busy"}
	var ge := _engine()
	if ge == null:
		return {"ok": false, "reason": "no_engine"}
	var st: Dictionary = ge.call("skirmish_stats", str(beast_id))
	if not bool(st.get("ok", false)):
		return {"ok": false, "reason": "no_stats"}
	_fight = {
		"phase": "fighting", "beast": str(beast_id),
		"beast_hp": float(st.get("beast_hp", 1.0)),
		"beast_max": float(st.get("beast_hp", 1.0)),
		"self_hp": float(st.get("player_hp", 1.0)),
		"self_max": float(st.get("player_hp", 1.0)),
		"cult_dmg": float(st.get("cult_dmg", 1.0)),
		"beast_tick": float(st.get("beast_tick", 1.0)),
		"ticks": 0, "landed": 0,
		"first_msec": -1, "last_msec": -1,
	}
	_build_fight_hud()
	_update_fight_hud()
	return {"ok": true, "phase": "fighting"}

func avatar_strike(at_msec: int = -1) -> Dictionary:
	## One player attack. Tempo clamp (min interval), range check, then
	## exactly ONE combat tick: both sides deal simultaneously, cultivator
	## first (a killing blow lands before the answer). Returns the tick
	## result; resolution sets take_fight_outcome() for Main's poll.
	if str(avatar_fight_state()) != "fighting":
		return {"ok": false, "reason": "not_fighting"}
	var now: int = at_msec if at_msec >= 0 else int(Time.get_ticks_msec())
	var last: int = int(_fight.get("last_msec", -1))
	var min_gap: int = int(1000.0 / TEMPO_CLAMP_TPS)
	if last >= 0 and now - last < min_gap:
		return {"ok": false, "reason": "tempo"}
	if _in_reach() != "":
		return {"ok": false, "reason": "range"}
	_fight["ticks"] = int(_fight.get("ticks", 0)) + 1
	_fight["landed"] = int(_fight.get("landed", 0)) + 1
	if int(_fight.get("first_msec", -1)) < 0:
		_fight["first_msec"] = now
	_fight["last_msec"] = now
	_fight["beast_hp"] = float(_fight.get("beast_hp", 0.0)) - float(_fight.get("cult_dmg", 0.0))
	if float(_fight.get("beast_hp", 0.0)) <= 0.0:
		return _resolve_fight(true)
	_fight["self_hp"] = float(_fight.get("self_hp", 0.0)) - float(_fight.get("beast_tick", 0.0))
	if float(_fight.get("self_hp", 0.0)) <= 0.0:
		return _resolve_fight(false)
	_update_fight_hud()
	return {"ok": true, "phase": "fighting", "ticks": int(_fight.get("ticks", 0))}

func _in_reach() -> String:
	## "" when the avatar stands within reach of the challenged den;
	## otherwise a short reason. Range is the skirmish reach scale.
	if _cultivator == null:
		return "no_avatar"
	var ge := _engine()
	if ge == null:
		return "no_engine"
	var st: Dictionary = ge.call("skirmish_stats", str(_fight.get("beast", "")))
	var reach: float = float(st.get("reach", 6.0))
	var ap: Vector3 = _cultivator.global_position
	for m in _beast_row.get_children():
		if str(m.get_meta("beast_id", "")) != str(_fight.get("beast", "")):
			continue
		var mp: Vector3 = (m as Node3D).global_position
		if Vector2(mp.x - ap.x, mp.z - ap.z).length() <= reach:
			return ""
	return "far"

func take_fight_outcome() -> Dictionary:
	## One-shot consume for Main's poll: voices wins and losses.
	var out: Dictionary = _fight_outcome
	_fight_outcome = {}
	return out

func _resolve_fight(won: bool) -> Dictionary:
	var ge := _engine()
	var out := {"ok": true, "win": won, "phase": "won" if won else "lost"}
	if won:
		_grant_fight_rewards()
	_fight["phase"] = "won" if won else "lost"
	if not won:
		_avatar_knockback()
	_free_fight_hud()
	_fight_outcome = out
	_challenge_beast = ""
	return out

func _grant_fight_rewards() -> void:
	## Win rewards flow through the EXISTING hunt path: the zone's map
	## node carrying this beast (node yield + marks + forage + mind rules
	## exactly as one auto-kill), else hunt_tick directly. Then the Q35
	## technique-XP bonus via the EXISTING XP API — conditional on tempo
	## quality (avg landed tempo >= BONUS_TEMPO_FRAC of clamp).
	var ge := _engine()
	if ge == null:
		return
	var bid: String = str(_fight.get("beast", ""))
	var node_id: String = ""
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("beast_id", "")) == bid:
			node_id = str((n as Dictionary).get("id", ""))
			break
	if node_id != "":
		ge.call("hunt_at", node_id, 1)
	else:
		ge.call("hunt_tick", bid, 1)
	var elapsed: float = maxf(float(int(_fight.get("last_msec", 0)) - int(_fight.get("first_msec", 0))) / 1000.0, 0.001)
	var tempo: float = float(_fight.get("landed", 0)) / elapsed
	if tempo >= BONUS_TEMPO_FRAC * TEMPO_CLAMP_TPS:
		var art: String = str(ge.get("focus_technique"))
		if art != "":
			ge.call("train_technique", art, BONUS_XP)

func _avatar_knockback() -> void:
	## Q37=A: defeat displaces to the zone entrance. Nothing else — no
	## death, no lifespan hit, no spiral, no qi cost.
	var entry: Dictionary = _zone_entry(_zone if _zone != "" else "Dewfield")
	var spawn: Array = ((entry.get("spawn", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0]) as Array)
	if _cultivator != null:
		_cultivator.position = Vector3(float(spawn[0]), 0.0, float(spawn[2])) + Vector3(0, 0, 2.0)
	_avatar_state = "idle"

func _build_fight_hud() -> void:
	_free_fight_hud()
	_fight_hud = Node3D.new()
	_fight_hud.name = "FightHud"
	add_child(_fight_hud)
	_fight_beast_bar = _hud_bar("BeastHp", Color(0.9, 0.3, 0.25))
	_fight_self_bar = _hud_bar("SelfHp", Color(0.4, 1.0, 0.5))
	_fight_beast_label = _hud_text("BeastHpText")
	_fight_self_label = _hud_text("SelfHpText")

func _hud_bar(bar_name: String, color: Color) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	bar.name = bar_name
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 0.25, 0.4)
	bar.mesh = bm
	bar.material_override = _unshaded(color, 1.5)
	_fight_hud.add_child(bar)
	return bar

func _hud_text(text_name: String) -> Label3D:
	var lab := Label3D.new()
	lab.name = text_name
	lab.font_size = 48
	lab.pixel_size = 0.01
	lab.no_depth_test = true
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1, 1, 1)
	_fight_hud.add_child(lab)
	return lab

func _free_fight_hud() -> void:
	if _fight_hud != null and is_instance_valid(_fight_hud):
		remove_child(_fight_hud)
		_fight_hud.queue_free()
	_fight_hud = null
	_fight_beast_bar = null
	_fight_self_bar = null
	_fight_beast_label = null
	_fight_self_label = null

func _update_fight_hud() -> void:
	## HP bars ARE the engine's math, presented live (skirmish_stats in,
	## bar fractions out — no separate numbers anywhere).
	if _fight_hud == null or _fight.is_empty():
		return
	var anchor: Vector3 = _fx_anchor() + Vector3(0, 4.2, 0)
	_fight_hud.position = anchor
	var bf: float = clampf(float(_fight.get("beast_hp", 0.0)) / maxf(float(_fight.get("beast_max", 1.0)), 0.001), 0.0, 1.0)
	var sf: float = clampf(float(_fight.get("self_hp", 0.0)) / maxf(float(_fight.get("self_max", 1.0)), 0.001), 0.0, 1.0)
	_fight_beast_bar.position = Vector3(0, 0.6, 0)
	_fight_beast_bar.scale = Vector3(maxf(bf, 0.001), 1.0, 1.0)
	_fight_self_bar.position = Vector3(0, 0.0, 0)
	_fight_self_bar.scale = Vector3(maxf(sf, 0.001), 1.0, 1.0)
	_fight_beast_label.position = Vector3(0, 1.1, 0)
	_fight_beast_label.text = "Foe %d/%d" % [maxi(int(_fight.get("beast_hp", 0.0)), 0), int(_fight.get("beast_max", 1.0))]
	_fight_self_label.position = Vector3(0, -0.5, 0)
	_fight_self_label.text = "Self %d/%d" % [maxi(int(_fight.get("self_hp", 0.0)), 0), int(_fight.get("self_max", 1.0))]

func _break_meditation() -> void:
	if _avatar_state == "meditate":
		_avatar_state = "idle"
	var ge := _engine()
	if ge != null and ge.has_method("set_presence"):
		ge.call("set_presence", false)

func _try_meditate() -> void:
	## world_interact at a node marker: meditate state + presence, provided
	## the run is live (not paused). Rule-5 factor engages engine-side.
	var ge := _engine()
	if ge == null or not _engine_running():
		return
	if _avatar_state == "fly":
		return
	if avatar_near_node() == "":
		return
	_avatar_state = "meditate"
	if ge.has_method("set_presence"):
		ge.call("set_presence", true)

func _update_follow() -> void:
	## Follow camera during play; orbit framing (static island POI) while
	## panels or modals are open.
	if _cultivator == null:
		return
	if _ui_open():
		_focus_on_island(_zone if _zone != "" else "Dewfield")
	else:
		_focus_target = _cultivator.global_position + Vector3(0, 4.0, 0)
		_update_camera()

# --- P23: floating zone islands (gray-box; dressing lands in P23b) ---
var _cloud_sea: Node3D = null
var _islands_root: Node3D = null
# _islands maps zone id -> built content node (null when not resident).
# _island_order is the full 9-zone ring; residency = active + neighbors.
var _islands: Dictionary = {}
var _island_order: Array = []
var _zones3d: Array = []
var _zone: String = ""
var _last_seed: int = -999999
const _FALLBACK_DEWFIELD := {
	"id": "Dewfield", "island_seed": "fallback", "size_radius": 200.0,
	"height_amp": 20,
	"palette": {"low": [0.112, 0.168, 0.161], "mid": [0.16, 0.24, 0.23], "high": [0.422, 0.497, 0.535], "accent": [1.0, 0.96, 0.88], "fog": [0.45, 0.55, 0.58], "sky_tint": [1.0, 0.972, 0.916]},
	"gate": {"min_realm": 0, "wall_type": "mist"},
	"spawn": {"pos": [1200.0, 0.0, 0.0], "facing": 3.1416},
	"weather": {"spring": "petal", "summer": "clear", "autumn": "ash", "winter": "snow"},
	"props": {"density": 20, "tree_style": "pine", "rock_style": "crag", "herb_nodes": 3},
}

func _build_cloud_sea() -> void:
	_cloud_sea = Node3D.new()
	_cloud_sea.name = "CloudSea"
	add_child(_cloud_sea)
	_islands_root = Node3D.new()
	_islands_root.name = "Islands"
	add_child(_islands_root)

func _load_zones() -> void:
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb != null:
		_zones3d = (cdb.get("zones3d") as Array).duplicate()
	_island_order = []
	_islands = {}
	for z in _zones3d:
		var zid: String = str((z as Dictionary).get("id", ""))
		if zid != "":
			_island_order.append(zid)
			_islands[zid] = null

func _zone_entry(zone: String) -> Dictionary:
	for z in _zones3d:
		if str((z as Dictionary).get("id", "")) == zone:
			return z
	return _FALLBACK_DEWFIELD

func has_zone_palette(zone: String) -> bool:
	## C7: pure query over the palette table. Unknown zone -> false.
	if _zones3d.is_empty():
		return zone == "Dewfield"
	for z in _zones3d:
		if str((z as Dictionary).get("id", "")) == zone:
			return true
	return false

func current_zone() -> String:
	## C7: query of stored zone. Never errors while held at title.
	return _zone

func apply_zone(zone: String) -> void:
	## C7: the zone-switch entry point. Idempotent: re-applying the current
	## zone refreshes dressing state without rebuilding geometry.
	var z: String = zone if has_zone_palette(zone) else "Dewfield"
	_zone = z
	_dress_island(z)
	_ensure_residency()
	_move_anchors(z)

func _stable_hash(s: String) -> int:
	## FNV-1a 32-bit: stable across sessions (GDScript hash() is not).
	var h: int = 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) * 16777619 & 0xFFFFFFFF
	return h

func _terrain_seed(zone: String) -> int:
	var ge := _engine()
	var ms: int = -1
	if ge != null:
		ms = int(ge.get("map_seed"))
	return _stable_hash(str(ms) + "|" + zone)

func _terrain_h(seed: int, x: float, z: float) -> float:
	## Pure-math heightfield in [-1, 1]. Same inputs => same heights,
	## every session (no RNG anywhere in terrain).
	var s: float = float(seed % 100000) / 100000.0
	return sin(x * 0.11 + s * 6.2831) * 0.5 + sin(z * 0.13 + s * 12.5663) * 0.3 + sin((x + z) * 0.05 + s * 3.1416) * 0.2

func _vertex_hash(zone: String) -> String:
	## Determinism observable: md5 over a fixed height grid. Same seed =>
	## identical hash across sessions; different seed => different hash.
	var entry: Dictionary = _zone_entry(zone)
	var r: float = float(entry.get("size_radius", 200.0))
	var seed: int = _terrain_seed(zone)
	var parts: PackedStringArray = [zone, str(r)]
	for ix in range(9):
		for iz in range(9):
			var x: float = -r + 2.0 * r * float(ix) / 8.0
			var zz: float = -r + 2.0 * r * float(iz) / 8.0
			parts.append("%.3f" % _terrain_h(seed, x, zz))
	return "".join(parts).md5_text()

func _island_zones() -> Array:
	## Registry of all nine island zones (metadata, not residency).
	return _island_order.duplicate()

func _resident_zones() -> Array:
	var out: Array = []
	if _island_order.is_empty():
		return out
	var cur: String = _zone if _island_order.has(_zone) else str(_island_order[0])
	var i: int = _island_order.find(cur)
	for k in [-1, 0, 1]:
		out.append(_island_order[(i + k + _island_order.size()) % _island_order.size()])
	return out

func _build_islands() -> void:
	for z in _island_order:
		_islands[z] = null
	_ensure_residency()

func _free_island(zone: String) -> void:
	var n: Node = _islands.get(zone) as Node
	if n != null and is_instance_valid(n):
		_islands_root.remove_child(n)
		n.queue_free()
	_islands[zone] = null

func _ensure_residency() -> void:
	## Active island + ring neighbors resident; everything else freed.
	var want: Dictionary = {}
	for z in _resident_zones():
		want[str(z)] = true
	for z in _island_order:
		var zid: String = str(z)
		var has: bool = (_islands.get(zid) as Node) != null
		if want.has(zid) and not has:
			_islands[zid] = _island_node(zid)
		elif not want.has(zid) and has:
			_free_island(zid)

func _grid_mesh(r: float, seed: int, amp: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 16
	for ix in range(n):
		for iz in range(n):
			var x0: float = -r + 2.0 * r * float(ix) / float(n)
			var x1: float = -r + 2.0 * r * float(ix + 1) / float(n)
			var z0: float = -r + 2.0 * r * float(iz) / float(n)
			var z1: float = -r + 2.0 * r * float(iz + 1) / float(n)
			var vs: Array = [
				Vector3(x0, _terrain_h(seed, x0, z0) * amp, z0),
				Vector3(x1, _terrain_h(seed, x1, z0) * amp, z0),
				Vector3(x1, _terrain_h(seed, x1, z1) * amp, z1),
				Vector3(x0, _terrain_h(seed, x0, z1) * amp, z1),
			]
			for v in [vs[0], vs[2], vs[1], vs[0], vs[3], vs[2]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
	return mesh

func _multimesh_instances(mesh: Mesh, mat: Material, spots: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = maxi(spots.size(), 1)
	for i in spots.size():
		mm.set_instance_transform(i, spots[i] as Transform3D)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	return mmi

func _prop_spots(seed: int, r: float, count: int, salt: int) -> Array:
	## Deterministic placements: seeded RNG (fixed seed => same layout).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + salt * 7919
	var out: Array = []
	for i in count:
		var a: float = rng.randf() * TAU
		var d: float = r * 0.15 + rng.randf() * r * 0.65
		var x: float = cos(a) * d
		var zz: float = sin(a) * d
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, 0.0, zz))
		out.append(t)
	return out

func _island_node(zone: String) -> Node3D:
	var entry: Dictionary = _zone_entry(zone)
	var r: float = float(entry.get("size_radius", 200.0))
	var amp: float = float(entry.get("height_amp", 20))
	var seed: int = _terrain_seed(zone)
	var spawn: Array = ((entry.get("spawn", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0]) as Array)
	var base := Vector3(float(spawn[0]), 0.0, float(spawn[2]))
	var pal: Dictionary = entry.get("palette", {})
	var mid: Color = Color(0.16, 0.24, 0.23)
	if pal.has("mid") and (pal["mid"] as Array).size() == 3:
		mid = Color(float(pal["mid"][0]), float(pal["mid"][1]), float(pal["mid"][2]))
	var root := Node3D.new()
	root.name = "Island_" + zone
	root.position = base
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = _grid_mesh(r, seed, amp * 0.5)
	var gmat := _flat_mat(mid)
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = gmat
	root.add_child(ground)
	var under := MeshInstance3D.new()
	under.name = "Under"
	var cone := CylinderMesh.new()
	cone.top_radius = r
	cone.bottom_radius = 0.0
	cone.height = r * 0.6
	cone.radial_segments = 12
	under.mesh = cone
	under.material_override = _flat_mat(mid.darkened(0.35))
	under.position = Vector3(0, -r * 0.3, 0)
	root.add_child(under)
	# Gate wall: presentation-only (R13); enforcement stays engine-side.
	var wall := MeshInstance3D.new()
	wall.name = "GateWall"
	var wb := BoxMesh.new()
	wb.size = Vector3(2.0, 30.0, r * 0.5)
	wall.mesh = wb
	var wtype: String = str(((entry.get("gate", {}) as Dictionary).get("wall_type", "mist")))
	var wcol := Color(0.6, 0.7, 0.8, 0.4)
	if wtype == "wind":
		wcol = Color(0.8, 0.95, 0.85, 0.4)
	elif wtype == "lightning":
		wcol = Color(1.0, 0.85, 0.4, 0.4)
	var wmat := _flat_mat(Color(wcol.r, wcol.g, wcol.b))
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = wcol
	wall.material_override = wmat
	wall.position = Vector3(r * 0.7, 12.0, 0)
	root.add_child(wall)
	_islands_root.add_child(root)
	# Props: one node per class (MultiMesh), deterministic placement.
	var props: Dictionary = entry.get("props", {})
	var tree_mesh := CylinderMesh.new()
	tree_mesh.top_radius = 0.0
	tree_mesh.bottom_radius = 1.2
	tree_mesh.height = 4.0
	tree_mesh.radial_segments = 6
	var trees := _multimesh_instances(tree_mesh, _flat_mat(mid.darkened(0.2)), _prop_spots(seed, r, int(props.get("density", 20)) / 2, 1))
	trees.name = "Trees"
	root.add_child(trees)
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(1.6, 1.2, 1.6)
	var rocks := _multimesh_instances(rock_mesh, _flat_mat(mid.lightened(0.15)), _prop_spots(seed, r, int(props.get("density", 20)) / 3, 2))
	rocks.name = "Rocks"
	root.add_child(rocks)
	var herb_mesh := BoxMesh.new()
	herb_mesh.size = Vector3(0.4, 0.5, 0.4)
	var herbs := _multimesh_instances(herb_mesh, _flat_mat(Color(0.35, 0.6, 0.3)), _prop_spots(seed, r, int(props.get("herb_nodes", 3)) * 2, 3))
	herbs.name = "Herbs"
	root.add_child(herbs)
	_build_shrine(root, zone, r, amp)
	return root

# Warden shrines stand on the highest-min_realm island of each tier span
# (T1 Murkfen, T2 Stonehollow, T3 Stillmere, T4 Pyrefen, T5 Whitefoundry,
# T6 Thornwake); the tier-7 sentinel shares Thornwake at the ladder's end.
# Presentation only (R13) — duels resolve via the engine/UI path.
const WARDEN_ISLES := ["Murkfen", "Stonehollow", "Stillmere", "Pyrefen", "Whitefoundry", "Thornwake"]

func _build_shrine(root: Node3D, zone: String, r: float, amp: float) -> void:
	var top: float = amp * 0.5
	var plinth := MeshInstance3D.new()
	plinth.name = "Shrine"
	var pb := BoxMesh.new()
	pb.size = Vector3(2.4, 0.6, 2.4)
	plinth.mesh = pb
	plinth.material_override = _flat_mat(Color(0.55, 0.52, 0.45))
	plinth.position = Vector3(r * 0.4, top + 0.3, -r * 0.3)
	root.add_child(plinth)
	var obelisk := MeshInstance3D.new()
	obelisk.name = "ShrineStone"
	var ob := BoxMesh.new()
	ob.size = Vector3(0.5, 3.0, 0.5)
	obelisk.mesh = ob
	obelisk.material_override = _flat_mat(Color(0.35, 0.33, 0.38))
	obelisk.position = Vector3(r * 0.4, top + 2.1, -r * 0.3)
	root.add_child(obelisk)
	if zone in WARDEN_ISLES:
		var flame := MeshInstance3D.new()
		flame.name = "ShrineFlame"
		var fm := SphereMesh.new()
		fm.radius = 0.35
		fm.height = 0.7
		flame.mesh = fm
		flame.material_override = _unshaded(Color(1.0, 0.8, 0.35), 2.5)
		flame.position = Vector3(r * 0.4, top + 4.0, -r * 0.3)
		# P25a: shrine flames carry their warden (tier by island order).
		flame.set_meta("guardian_id", "guardian_%02d" % (WARDEN_ISLES.find(zone) + 1))
		root.add_child(flame)
	if zone == "Thornwake":
		var sent := MeshInstance3D.new()
		sent.name = "Sentinel"
		var sb := BoxMesh.new()
		sb.size = Vector3(0.7, 4.6, 0.7)
		sent.mesh = sb
		sent.material_override = _flat_mat(Color(0.75, 0.73, 0.80))
		sent.position = Vector3(r * 0.4 + 2.2, top + 2.6, -r * 0.3)
		root.add_child(sent)
		var sflame := MeshInstance3D.new()
		sflame.name = "SentinelFlame"
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		sflame.mesh = sm
		sflame.material_override = _unshaded(Color(1.0, 1.0, 0.95), 3.0)
		sflame.position = Vector3(r * 0.4 + 2.2, top + 5.4, -r * 0.3)
		# P25a: the tier-7 sentinel watches from the ladder's end.
		sflame.set_meta("guardian_id", "guardian_07")
		root.add_child(sflame)

func _pal_color(pal: Dictionary, key: String, fallback: Color) -> Color:
	if pal.has(key) and (pal[key] as Array).size() == 3:
		return Color(float(pal[key][0]), float(pal[key][1]), float(pal[key][2]))
	return fallback

func _dress_island(zone: String) -> void:
	## Full zone dressing (P23b): ground tint plus sun/fog/backdrop grading
	## from the zones3d palette. Tier grades still override sun/fog on tier
	## change (same ordering as the diorama era).
	var entry: Dictionary = _zone_entry(zone)
	var pal: Dictionary = entry.get("palette", {})
	var mid: Color = _pal_color(pal, "mid", Color(0.16, 0.24, 0.23))
	var n: Node = _islands.get(zone) as Node
	if n != null:
		var g: MeshInstance3D = n.get_node_or_null("Ground") as MeshInstance3D
		if g != null and g.material_override != null:
			(g.material_override as StandardMaterial3D).albedo_color = mid
	if _sun != null and pal.has("accent"):
		_sun.light_color = _pal_color(pal, "accent", Color.WHITE)
	if _env != null:
		if pal.has("fog"):
			_env.fog_light_color = _pal_color(pal, "fog", _env.fog_light_color)
		if pal.has("sky_tint"):
			_env.background_color = _pal_color(pal, "sky_tint", _env.background_color)

func _poll_seed() -> void:
	## C6: a changed map_seed (ascension path) rebuilds islands and frees
	## prior subtrees — same post-leak discipline as everything else.
	var ge := _engine()
	if ge == null:
		return
	var ms: int = int(ge.get("map_seed"))
	if ms == _last_seed:
		return
	_last_seed = ms
	for z in _island_order:
		_free_island(str(z))
	_ensure_residency()
	_move_anchors(_zone if _zone != "" else "Dewfield")
	_rebuild_node_marks(_zone if _zone != "" else "Dewfield")
	_rebuild_beasts(_zone if _zone != "" else "Dewfield")
	_rebuild_node_marks(_zone if _zone != "" else "Dewfield")

func _rebuild_node_marks(zone: String) -> void:
	## Meditation points: the zone's map nodes on a deterministic
	## golden-angle ring keyed to (terrain_seed, index) — R12, same as
	## beast markers. Rebuilt on zone change and seed change.
	if _node_marks == null:
		_node_marks = Node3D.new()
		_node_marks.name = "NodeMarks"
		add_child(_node_marks)
	for c in _node_marks.get_children():
		_node_marks.remove_child(c)
		c.queue_free()
	var ge := _engine()
	if ge == null:
		return
	var entry: Dictionary = _zone_entry(zone)
	var spawn: Array = ((entry.get("spawn", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0]) as Array)
	var base := Vector3(float(spawn[0]), 0.0, float(spawn[2]))
	var seed: int = _terrain_seed(zone)
	var shown: int = 0
	for n in (ge.get("map_nodes") as Array):
		if str((n as Dictionary).get("zone", "")) != zone:
			continue
		if shown >= 4:
			break
		var a: float = float(shown) * 2.39996 + float(seed % 1000) * 0.001
		var d: float = 10.0 + float(shown % 2) * 4.0
		var mark := MeshInstance3D.new()
		mark.name = "NodeMark%d" % shown
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.7
		cyl.height = 1.2
		cyl.radial_segments = 8
		mark.mesh = cyl
		mark.material_override = _unshaded(Color(0.85, 0.66, 0.22), 1.5)
		mark.position = base + Vector3(cos(a) * d, 0.6, sin(a) * d)
		mark.set_meta("node_id", str((n as Dictionary).get("id", "")))
		_node_marks.add_child(mark)
		shown += 1

func _focus_on_island(zone: String) -> void:
	var entry: Dictionary = _zone_entry(zone)
	var spawn: Array = ((entry.get("spawn", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0]) as Array)
	_focus_target = Vector3(float(spawn[0]), 4.0, float(spawn[2]))
	_update_camera()

func _move_anchors(zone: String) -> void:
	## Cultivator, weather, FX, and presentation ride the active island.
	var entry: Dictionary = _zone_entry(zone)
	var spawn: Array = ((entry.get("spawn", {}) as Dictionary).get("pos", [0.0, 0.0, 0.0]) as Array)
	var p := Vector3(float(spawn[0]), 0.0, float(spawn[2]))
	if _cultivator != null:
		_cultivator.position = p + Vector3(0, 0, 2.0)
	if _weather != null:
		_weather.position = p + Vector3(0, 8.0, 0)
	if _charge_fx != null:
		_charge_fx.position = p + Vector3(0, 1.2, 2.0)
	if _burst_fx != null:
		_burst_fx.position = p + Vector3(0, 1.5, 2.0)
	for i in range(_strike_bars.size()):
		(_strike_bars[i] as MeshInstance3D).position = p + Vector3(-2.5 + float(i) * 1.7, 5.0, 2.0)
	for i in range(_cracks.size()):
		(_cracks[i] as MeshInstance3D).position = p + Vector3(-1.5 + float(i) * 1.5, 0.56, 2.0)
	if _sect_row != null:
		_sect_row.position = p + Vector3(-5.25, 0, -1.5)
	if _cauldron != null:
		_cauldron.position = p + Vector3(-4.2, 0, 5.0)
	if _beast_row != null:
		_beast_row.position = p + Vector3(0, 0, -6.0)
	_focus_on_island(zone)

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
	## Derives the zone purely from engine current-node state plus static
	## tables (C7: no side channels, no caching across apply_state). The
	## update itself lands in _poll_world_state via apply_zone.
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
	## Beast markers ride the active island on a deterministic golden-angle
	## ring keyed to (terrain_seed, index) — same state, same positions.
	for c in _beast_row.get_children():
		_beast_row.remove_child(c)
		c.queue_free()
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb == null:
		return
	var shown: int = 0
	var seed: int = _terrain_seed(zone)
	for b in (cdb.get("beasts") as Array):
		if shown >= 6:
			break
		if str((b as Dictionary).get("zone", "")) != zone:
			continue
		var el: String = str((b as Dictionary).get("element", ""))
		var spr := _sprite_node(SF.make_sprite("beast", str((b as Dictionary).get("id", "")), SF.element_color(el)), Vector3.ZERO)
		var a: float = float(shown) * 2.39996 + float(seed % 1000) * 0.001
		var d: float = 6.0 + float(shown % 3) * 2.5
		spr.position = Vector3(cos(a) * d, 1.0, sin(a) * d)
		spr.set_meta("base_y", 1.0)
		spr.set_meta("phase", float(shown) * 1.1)
		# P25a: dens are markers elevated to interactable (Q36). The beast
		# id rides metadata; the fight loop lands in P25b.
		spr.set_meta("beast_id", str((b as Dictionary).get("id", "")))
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
		_rebuild_node_marks(z)
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
	# Gate walls stand only while their grounds are locked (R13:
	# presentation only — enforcement stays engine-side).
	var realm_now: int = int(ge.get("realm_index"))
	for iz in _island_order:
		var zid: String = str(iz)
		var n: Node = _islands.get(zid) as Node
		if n == null:
			continue
		var wall: MeshInstance3D = n.get_node_or_null("GateWall") as MeshInstance3D
		if wall != null:
			wall.visible = realm_now < int((_zone_entry(zid).get("gate", {}) as Dictionary).get("min_realm", 0))

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

func _fx_anchor() -> Vector3:
	## Tribulation FX stages around the cultivator on the active island.
	if _cultivator != null:
		return _cultivator.global_position
	return _focus_target

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
	# Buildup: heavens darken, charge gathers over the cultivator.
	var anchor: Vector3 = _fx_anchor()
	var sun_e: float = 1.1
	if _sun != null:
		sun_e = _sun.light_energy
		var dim := create_tween()
		dim.tween_property(_sun, "light_energy", sun_e * 0.35, 0.5)
	_charge_fx.position = anchor + Vector3(0, 1.2, 0)
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
	_burst_fx.position = anchor + Vector3(0, 1.5, 0)
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
	var anchor: Vector3 = _fx_anchor()
	var bar: MeshInstance3D = _strike_bars[i]
	bar.position = anchor + Vector3(-2.5 + float(i) * 1.7 + randf_range(-0.5, 0.5), 5.0, 0)
	bar.visible = true
	_shake = maxf(_shake, 0.3)
	var fl := create_tween()
	fl.tween_property(bar, "scale:y", 0.55, 0.07)
	fl.tween_property(bar, "scale:y", 1.0, 0.07)
	fl.tween_callback(func() -> void: bar.visible = false)

func _show_cracks() -> void:
	var anchor: Vector3 = _fx_anchor()
	for ci in range(_cracks.size()):
		var crack: MeshInstance3D = _cracks[ci]
		crack.position = anchor + Vector3(-1.5 + float(ci) * 1.5, 0.56, 0)
		crack.visible = true
		crack.scale = Vector3.ONE
		var fade := create_tween()
		fade.tween_interval(0.4)
		fade.tween_property(crack, "scale", Vector3(1.6, 1.0, 1.6), 0.8)
		fade.tween_callback(func() -> void: (crack as MeshInstance3D).visible = false)

func _on_died(_cause: String) -> void:
	## The cultivator slumps grey; fog closes in. Restored on rebirth.
	## C3: same beats as the diorama era, ported to the island rig.
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
	_burst_fx.position = _fx_anchor() + Vector3(0, 1.5, 0)
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
