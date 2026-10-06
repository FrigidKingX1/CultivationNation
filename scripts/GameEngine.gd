extends Node
## GameEngine autoload — fixed-tick cultivation sim. Original code.
## 1 tick = 1 in-game month. 12 ticks = 1 year. Time scale multiplies ticks per second.

signal ticked(tick_count: int)
signal aged_years(new_age: int)
signal breakthrough_ready(realm_index: int)
signal died(cause: String)
signal reborn(life_number: int)
signal origin_chosen(origin_id: String)
signal paused_for_death(age: int)
signal achievement_unlocked(ach_id: String)
signal ascended(marks_gained: int)

const TICKS_PER_YEAR: int = 12
const BASE_TICKS_PER_SECOND: float = 10.0
const MIN_TIME_SCALE: float = 1.0
const MAX_TIME_SCALE: float = 1000.0
const LOW_POWER_MAX_RATE: float = 100.0
const BASE_LIFESPAN: int = 60
const DANTIAN_DEFAULT: float = 80.0
const DANTIAN_MIN: float = 0.0
const DANTIAN_MAX: float = 100.0

var tick_count: int = 0
var time_scale: float = 1.0
var running: bool = true
var low_power_mode: bool = false

# Life state (P1 vertical slice)
const BN: GDScript = preload("res://scripts/BigNumber.gd")

var age_years: int = 18
var _month_accum: int = 0
var lifespan_years: int = 60
# P19a — the Qi economy runs on Big (mantissa+exponent, true big math).
# Canonical values are Big objects; plain-float assignment (tests, old call
# paths) is tolerated — every read coerces via BN.of(). Float accessors
# below serve UI/tests; costs computed fresh each call stay floats.
var qi = 0.0
var qi_per_tick = 1.0
var realm_index: int = 0
# P12-0 — ladder bound. Count of completable breakthroughs; the engine never
# advances past realm_count. Wired from data in P12-1 (default 18 preserves P11).
var realm_count: int = 18
var qi_bottleneck = 120.0
var life_number: int = 1
var aptitude: float = 1.0  # prestige multiplier carried across rebirth
var total_rebirths: int = 0

# P3a — origin (locked per life) + dantian purity. Original system.
var origin_id: String = "origin_wayfarer"
var origin_qi_mult: float = 1.0
var origin_lifespan_bonus: int = 0
var _origin_locked: bool = false
var dantian_purity: float = DANTIAN_DEFAULT
# P3b — techniques: id -> xp. Original system.
var techniques: Dictionary = {}
# P3c — bestiary: id -> kills. Original system.
var beasts: Dictionary = {}
# P22 — guardians: duel entities, deliberately disjoint from the beast codex.
# defeated holds guardian ids (persist rebirth AND ascend: the sword dao is
# remembered); attempts maps id -> duel count (records/statistics).
# _guardian_defs injected by caller from data/guardians.json (generated).
var guardians: Dictionary = {"defeated": [], "attempts": {}}
var _guardian_defs: Array = []
# P3d — pause-before-death. Route planner CUT in P13-B5 (no setter, no UI,
# never fed: dead state with a save key). Stored "route" keys in old saves
# sit inert; the v2 migration that fills them stays untouched by rule.
var pause_before_death_years: int = 0
# P4a — soul-gear: id -> level. Persists across rebirth. Original system.
var gear: Dictionary = {}
# P4b — seeded hunt map. Nodes regenerate from map_seed; only seed + current stored.
var map_seed: int = -1
var map_nodes: Array = []
var current_node: String = ""
# P4c — sect legacy: persists across rebirth. Disciples: array of {task}.
var sect: Dictionary = {}
var disciples: Array = []
var focus_technique: String = ""
var _gather_mult: float = 1.0
# P5a — achievements: unlocked ids. Rules supplied by caller (Main/tests).
var achievements: Array = []
var _achievement_rules: Array = []
# P6a — player focus + audio setting. Original system.
var player_focus: String = "cultivate"
var focus_mult: float = 1.0
var muted: bool = false
# P24b — presence premium (ADR-004). Runtime-only view-driven state: never
# serialized, default OFF, reset on apply_state/rebirth/ascend. When active,
# the COMPILED QI RATE gains presence_mult (R-S7: names its scale; touches
# nothing else — not power, tribulation, or offline).
var _presence_active: bool = false
const PRESENCE_MULT := 1.5
# P8b/c — tutorial hints seen + map visitation. Original system.
var hints_seen: Array = []
var nodes_visited: Array = []
# P12-2 — spiritual roots (element -> affinity, fated per life), state of mind
# 0-100, and seasonal calendar. Roots/mind persist (save v7 in P12-5; until
# then apply_state defaults cover them). Seasons derive from _month_accum.
var roots: Dictionary = {}
var mind: float = 70.0
# P12-3 — tribulation quality + deviation. deviation 0-3 flaws (-10% Qi each);
# lifespan_scars accumulate -5y per failed/shaky tribulation. last_quality /
# last_tribulation are transient (resolved instantly, never saved).
var deviation: int = 0
var lifespan_scars: int = 0
var last_quality: String = ""
var last_tribulation: Array = []
# P15-Step4: toxicity backlash. Heavenly lightning agitates pill residue:
# crossing triumphant at toxicity >= BACKLASH_TOXICITY scars all the same.
# Threshold tuned to Step-0 data (natural max 12 = one drink; 24 = a
# deliberate double-dose, never ambient). Avoidable via purge/rest/travel.
var last_backlash: bool = false
const BACKLASH_TOXICITY: float = 24.0
# P12-4 — alchemy-lite. Instant brews (timers cut: no new clock systems for
# four recipes; refine_cost precedent keeps balance numbers in-engine).
# Toxicity 0-100 damps Qi to a 0.5x floor until purged or rested off.
var herbs: float = 0.0
var pills: Dictionary = {}
var toxicity: float = 0.0
var _prep_power: float = 1.0
var _ward_power: float = 1.0
var _tox_wear: int = 0
var _gatherers: int = 0
# P12-5 — Samsara karma, soul weapon, heirloom bequest. Karma rewards depth
# (realm squared x log lifetime Qi); talents compound across lives. Aptitude
# is deliberately untouched: karma adds, never rewrites, the P11 curve.
var karma: int = 0
var talents: Dictionary = {}
var soulweapon: Dictionary = {}
var legacy_mult: float = 1.0
var qi_earned_this_life = 0.0
const TALENT_DEFS: Array = [
	{"id": "talent_roots", "name": "Root Clarity", "max": 10},
	{"id": "talent_body", "name": "Tribulation Body", "max": 10},
	{"id": "talent_breath", "name": "Long Breath", "max": 10},
]
const SOUL_PATHS: Array = [
	{"id": "soul_blade", "name": "Oath Blade"},
	{"id": "soul_bell", "name": "Hollow Bell"},
	{"id": "soul_mirror", "name": "Still Mirror"},
]
const PILL_DEFS: Array = [
	{"id": "pill_prep", "name": "Kindling Pill", "cost": 10.0},
	{"id": "pill_heal", "name": "Mending Pill", "cost": 15.0},
	{"id": "pill_purge", "name": "Cleansing Pill", "cost": 20.0},
	{"id": "pill_ward", "name": "Warding Pill", "cost": 25.0},
]
var _mind_wear: float = 0.0
var _mind_ease: int = 0
var _mind_calm: int = 0
var _mind_stage: int = 1
# P15-Step1 build identity: per-art attunement 0-100 (rises while drilled,
# decays otherwise) scales power and gates perks. `victorious` is the Step 3
# endgame flag, carried in the same v8 bump. No new tick systems.
var attunement: Dictionary = {}
var victorious: bool = false
# P21 — first-session coach dismissal (persisted, v11). Tab reveal itself
# is derived from live state (records-style), never stored.
var coach_done: bool = false
var _reveal_rules: Array = []
# P19c — milestone dedications: first entry into each macro tier, recorded
# once per save so the modal manager celebrates exactly seven times.
var milestones_seen: Array = []
# P19b — ascension prestige (Dao Marks). Lifetime Qi across all lives feeds
# a sqrt-dampened gain; ascending resets the world (realm/rate/aptitude/
# gear/sect/arts) but never the soul, karma, records, or the marks ledger.
const PRESTIGE_THRESHOLD: float = 1000000.0
const PRESTIGE_FACTOR: float = 12.0
var dao_marks: int = 0
var dao_nodes: Dictionary = {}
var dao_ascensions: int = 0
var qi_earned_total = 0.0
var _prestige_defs: Array = []
var _technique_defs: Array = []
# P16-Step1: seclusion directive for offline death. "vigil" stalls the clock
# at death's door (default, gentle); "unfettered" lets death and rebirth
# resolve unseen. Player-chosen, persisted, defaulted for old saves.
var offline_mortality: String = "vigil"

func set_offline_mortality(m: String) -> bool:
	if not ["vigil", "unfettered"].has(m):
		return false
	offline_mortality = m
	return true

func death_looms() -> bool:
	## True when the coming year would end this life. The Vigil consults
	## this before every offline tick; the live loop never calls it.
	var inc: int = 1 if _month_accum + 1 >= TICKS_PER_YEAR else 0
	return age_years + inc >= lifespan_years
var _zone_elements: Dictionary = {}
var _env_mult: float = 1.0
var _season_cached: int = -1
const ROOT_ELEMENTS: Array = ["metal", "wood", "water", "fire", "earth"]
const MIND_NAMES: Array = ["Serene", "Steady", "Strained"]
const SEASON_NAMES: Array = ["Spring", "Summer", "Autumn", "Winter"]
const TERM_NAMES: Array = ["Thawbreak", "Meltwater", "Insects Wake", "Mildew Bloom", "Grain Fill", "Sunpeak", "Cicada Hush", "Heat Haze", "Leafturn", "White Frost", "Frostfall", "Long Night"]

var _accum: float = 0.0
# Compiled-rate cache (P2): derived Qi gain recomputed only when inputs change,
# never per-tick from scratch (CoFD 60k-ticks lesson).
var _cached_qi_per_tick = 1.0
# P12-0 — last finite compiled rate. A non-finite product (overflow chain) can
# never reach the tick accumulator; the guard below falls back to this.
var _last_good_rate: float = 1.0

func qi_num() -> float:
	## Float view of stored Qi (UI/tests). Display uses format_any instead.
	return BN.of(qi).to_float()

func bottleneck_num() -> float:
	return BN.of(qi_bottleneck).to_float()

func rate_num() -> float:
	return BN.of(_cached_qi_per_tick).to_float()

func earned_num() -> float:
	return BN.of(qi_earned_this_life).to_float()

func fill_ratio() -> float:
	## Brim fraction vs the wired bottleneck (bars, labels, forecasts).
	var b = BN.of(qi_bottleneck)
	if b.is_zero():
		return 0.0
	return clampf(BN.of(qi).div(b).to_float(), 0.0, 1.0)

func _ready() -> void:
	set_process(true)
	if roots.is_empty():
		roll_roots(life_number * 7919 + 13)
	_mind_stage = mind_stage()
	_season_cached = season_index()
	_recompute_rate()

func set_time_scale(s: float) -> void:
	time_scale = clampf(s, MIN_TIME_SCALE, MAX_TIME_SCALE)

func effective_rate() -> float:
	var rate: float = BASE_TICKS_PER_SECOND * clampf(time_scale, MIN_TIME_SCALE, MAX_TIME_SCALE)
	if low_power_mode:
		rate = minf(rate, LOW_POWER_MAX_RATE)
	return rate

func dantian_mult() -> float:
	return 0.5 + clampf(dantian_purity, DANTIAN_MIN, DANTIAN_MAX) / 100.0

func gear_bonus_for(levels: Dictionary, defs: Dictionary) -> float:
	## Product of (1 + base_mult * level). defs: id -> {base_mult}. Pure helper.
	var m: float = 1.0
	for id in levels:
		var lv: int = int(levels.get(id, 0))
		if lv > 0 and (defs as Dictionary).has(str(id)):
			m *= 1.0 + float((defs as Dictionary)[str(id)].get("base_mult", 0.0)) * float(lv)
	return m

func set_focus(mode: String) -> bool:
	## P13-B5 keystone: only breathing cultivates Qi. Drill yields xp (and
	## strain) but zero Qi; stalk yields kills (and ease) but zero Qi. Time
	## allocation is now the central decision: power XOR progress per tick.
	## (Before: train/hunt paid half Qi, so Qi overfilled during every
	## power chase and the whole throughput economy was decorative.)
	if not ["cultivate", "train", "hunt"].has(mode):
		return false
	player_focus = mode
	focus_mult = 1.0 if mode == "cultivate" else 0.0
	_recompute_rate()
	return true

func best_technique_bonus() -> float:
	var best: float = 1.0
	for k in techniques:
		best = maxf(best, technique_power_bonus(str(k)))
	return best

func assign_all(task: String) -> bool:
	if not ["gather", "hunt", "train", "idle"].has(task):
		return false
	for d in disciples:
		(d as Dictionary)["task"] = task
	_recompute_gather()
	return true

func _player_tick() -> void:
	## Player's own hands each tick, alongside disciple output. Personal
	## drill scales with depth (P11a pacing knob B); disciples stay flat.
	if player_focus == "train" and focus_technique != "":
		train_technique(focus_technique, 1 + realm_index)
	elif player_focus == "hunt" and current_node != "":
		hunt_at(current_node, 1)

func _recompute_rate() -> void:
	# P12-3: each deviation flaw bleeds 10% of throughput (floor 0.7x).
	# P12-4: pill residue clogs the channels to a 0.5x floor.
	# P12-5: bequeathed legacy compounds every future life.
	# P19a: the multiplier chain stays float (bounded magnitudes); only the
	# stored result is Big. qi_per_tick coerces (it is Big after x4 growth).
	var raw: float = BN.of(qi_per_tick).to_float() * aptitude * origin_qi_mult * dantian_mult() * _gear_mult_cached * _gather_mult * focus_mult * mind_mult() * _env_mult * _season_qi_mult() * (1.0 - 0.1 * float(deviation)) * (1.0 - clampf(toxicity, 0.0, 100.0) / 200.0) * legacy_mult * dao_flow_bonus()
	# P24b: presence premium enters by BRANCH, not x1.0 — the bit-identical
	# default-off claim stays auditable by eyeball (R-S13).
	if _presence_active:
		raw *= PRESENCE_MULT
	if is_finite(raw):
		_last_good_rate = raw
	else:
		raw = _last_good_rate
	_cached_qi_per_tick = BN.from_float(raw)

func set_presence(active: bool) -> void:
	## P24b: avatar meditating at a map node. View-driven, runtime-only.
	if bool(active) == _presence_active:
		return
	_presence_active = bool(active)
	_recompute_rate()

func is_presence_active() -> bool:
	return _presence_active

var _gear_mult_cached: float = 1.0

func set_gear_mult(m: float) -> void:
	_gear_mult_cached = maxf(m, 0.0)
	_recompute_rate()

func refine_cost(level: int) -> float:
	return 100.0 * pow(4.0, float(level))

func refine_gear(id: String, max_level: int) -> bool:
	## Spend Qi to raise gear level, without ceiling: radiant overflow past
	## max keeps the 100x4^lvl curve, which self-limits economically (each
	## rank costs 4x more for a flat +base). max_level now marks the
	## perfected/bequest threshold, not a cap — the late Qi sink.
	var lv: int = int(gear.get(id, 0))
	var cost: float = refine_cost(lv)
	if BN.of(qi).lt(cost):
		return false
	qi = BN.of(qi).minus(cost)
	gear[id] = lv + 1
	_poll_achievements()
	return true

func choose_origin(id: String, qi_mult: float, lifespan_bonus: int) -> bool:
	## Origin locked per life: only at life start (fresh, unlocked). Returns success.
	if _origin_locked:
		return false
	origin_id = id
	origin_qi_mult = qi_mult
	origin_lifespan_bonus = lifespan_bonus
	_recompute_lifespan()
	_origin_locked = true
	_recompute_rate()
	origin_chosen.emit(origin_id)
	return true

func _shift_purity(delta: float) -> void:
	dantian_purity = clampf(dantian_purity + delta, DANTIAN_MIN, DANTIAN_MAX)
	_recompute_rate()

func _process(delta: float) -> void:
	if not running:
		return
	var rate: float = effective_rate()
	_accum += delta * rate
	var steps: int = int(_accum)
	if steps <= 0:
		return
	# Clamp catch-up to avoid spiral after tab-out; remainder handled by offline calc.
	steps = mini(steps, 5000)
	_accum -= float(steps)
	for i in range(steps):
		_step_tick()

func _step_tick() -> void:
	tick_count += 1
	# P12-0 finite guard, P19a form: Big cannot hold NaN/Inf by
	# construction (coercion maps poisoned floats to zero), so normalizing
	# IS the guard — accumulation never starts from a poisoned value.
	qi = BN.of(qi).plus(_cached_qi_per_tick)
	# P12-5: lifetime earnings feed the Samsara yield; same guard.
	qi_earned_this_life = BN.of(qi_earned_this_life).plus(_cached_qi_per_tick)
	# P19b: all-time earnings feed ascension gain. Never reset by rebirth.
	qi_earned_total = BN.of(qi_earned_total).plus(_cached_qi_per_tick)
	_disciple_tick()
	_player_tick()
	# P13-B5 mind friction, deepened: drilling strains the heart (-1 per 30
	# drill-ticks with an art set); breathing meditation calms it (+1 per 24
	# cultivate-ticks); wilderness air eases it (+1 per 12 hunt-ticks abroad).
	# Friction now bites the playstyle that actually plays (power-chasers
	# drill ~95% of ticks), and rest is a real decision with a visible rate.
	if player_focus == "train" and focus_technique != "":
		# P15-Step1: attunement rises on the drilled art (+1/12 ticks, cap
		# 100) while the others cool (−1/48). Switching arts costs rebuild —
		# commitment is the build decision. Wear follows the art's nature.
		var art: String = focus_technique
		attunement[art] = minf(100.0, float(attunement.get(art, 0.0)) + 1.0 / 12.0)
		for k in attunement.keys():
			if str(k) != art:
				attunement[k] = maxf(0.0, float(attunement[k]) - 1.0 / 48.0)
		_mind_wear += technique_wear(art)
		if _mind_wear >= 30.0:
			_mind_wear = 0.0
			_shift_mind(-1.0)
	elif player_focus == "cultivate":
		_mind_calm += 1
		if _mind_calm >= 24:
			_mind_calm = 0
			_shift_mind(1.0)
	elif player_focus == "hunt" and current_node != "":
		_mind_ease += 1
		if _mind_ease >= 12:
			_mind_ease = 0
			_shift_mind(1.0)
	# P12-4: residue sweats out slowly at rest (-1 per 12 ticks).
	if toxicity > 0.0:
		_tox_wear += 1
		if _tox_wear >= 12:
			_tox_wear = 0
			toxicity = maxf(0.0, toxicity - 1.0)
			_recompute_rate()
	_month_accum += 1
	if season_index() != _season_cached:
		_season_cached = season_index()
		_recompute_gather()
		_recompute_rate()
	if _month_accum >= TICKS_PER_YEAR:
		_month_accum = 0
		age_years += 1
		aged_years.emit(age_years)
	if BN.of(qi).ge(qi_bottleneck):
		breakthrough_ready.emit(realm_index)
	if age_years >= lifespan_years:
		_die_of_age()
	elif pause_before_death_years > 0 and running and age_years >= lifespan_years - pause_before_death_years:
		running = false
		paused_for_death.emit(age_years)

func set_activity_rate(mult: float) -> void:
	qi_per_tick = BN.from_float(mult)
	_recompute_rate()

func attempt_breakthrough(power: float, required: float, power_mult: float = 1.0, ward_mult: float = 1.0) -> bool:
	## Tribulation gate: effective power = power * power_mult (technique bonus).
	## ward_mult is the P12-4 pill ward (default 1.0: all 9 existing call
	## sites keep working unchanged). Outcomes stay deterministic throughout.
	if realm_index >= realm_count:
		return false  # ladder complete; further attempts refused (P12-0)
	# P12-1 Late-layer gate: attempts open at 2/3 full. Filling to the brim
	# stays optimal (quality input in P12-3); every existing headless flow
	# overfills, so all current policies pass unchanged.
	if BN.of(qi).lt(BN.of(qi_bottleneck).times_float(2.0 / 3.0)):
		last_quality = "Unready"
		last_tribulation = []
		return false
	# P22: macro-tier wardens. The breakthrough leaving a tier (including the
	# final ladder-clearing crossing) requires that tier's guardian defeated.
	# Interior breakthroughs pass through untouched.
	var gate: Dictionary = guardian_gate()
	if bool(gate.get("blocked", false)):
		last_quality = "Warded"
		last_tribulation = []
		return false
	## Winter tribulations strike 10% harder through the cultivator: the season
	## favors the defender. Engine-side, so all callers share it.
	# P12-4: pill charges ride this attempt, then burn out win or lose.
	# P12-5: body talent + soul weapon ride inside effective power.
	# eff_power is the single combined number gate, waves, and readiness share.
	var eff_power: float = (power + artifact_power_bonus()) * _prep_power
	var charged_ward: float = ward_mult * _ward_power
	if not is_ready(power, required, power_mult):
		# P13-B1 proportional costs: a 99% near-miss barely stings (Qi x~1,
		# ~0 scars), a hopeless 0% pays the old full price. Brinkmanship
		# with safety instead of a flat execution.
		var r: float = clampf(eff_power * power_mult * season_power_bonus() / maxf(required, 0.001), 0.0, 1.0)
		_prep_power = 1.0
		_ward_power = 1.0
		last_quality = "Failed"
		last_tribulation = []
		qi = BN.of(qi).times_float(0.5 + 0.5 * r)  # failed tribulation costs Qi by shortfall
		lifespan_scars += int(round(5.0 * (1.0 - r)))
		_recompute_lifespan()
		_shift_purity(-2.0 * (1.0 - r))
		return false
	var fill: float = fill_ratio()
	var fc: Dictionary = forecast_quality(eff_power, required, power_mult, fill, charged_ward)
	_prep_power = 1.0
	_ward_power = 1.0
	last_backlash = false
	if toxicity >= BACKLASH_TOXICITY:
		last_backlash = true
		lifespan_scars += 2
		_recompute_lifespan()
	# P12-5: the soul drinks every endured strike, win or tempered.
	# P13-B5: wavless T1 crossings still witness (+2) — the soul now moves
	# from the first tier instead of idling through it.
	if not soulweapon.is_empty():
		soulweapon["xp"] = int(soulweapon.get("xp", 0)) + maxi(2, (fc.get("waves", []) as Array).size())
	last_quality = str(fc.get("quality", "Steady"))
	last_tribulation = fc.get("waves", [])
	# P12-3 consequences: baptism washes flaws by quality; sloppy crossings
	# scar. A strained heart always leaves a mark, whatever the sky decides.
	match last_quality:
		"Radiant":
			deviation = 0
		"Steady":
			deviation = maxi(0, deviation - 1)
		_:  # Shaky
			# P13-B2: an endured crossing flaws the channels but does not
			# shorten years — scars are reserved for true failures. Passed
			# tribulations must never kill by a thousand papercuts.
			deviation = mini(3, deviation + 1)
	if mind_stage() == 2:
		deviation = mini(3, deviation + 1)
	_recompute_lifespan()
	realm_index += 1
	# P15-Step3: clearing the ladder is a permanent victory, recorded once.
	# Post-clear play continues as sandbox under the existing cap refusal.
	if realm_index >= realm_count:
		victorious = true
	qi = BN.from_float(0.0)
	if _realm_table.is_empty():
		qi_bottleneck = BN.of(qi_bottleneck).times_float(4.0)
	else:
		qi_bottleneck = _realm_total_for(realm_index)
	# P11a pacing: each breakthrough multiplies the foundation rate by the same
	# x4 as bottlenecks, so per-realm effort holds steady instead of doubling.
	qi_per_tick = BN.of(qi_per_tick).times_float(4.0)
	# P12-2: surviving the heavens settles the heart (+25, +40 under an
	# attuned stonebell focus — the settling perk).
	var settle: float = 40.0 if (str(_tech_def(focus_technique).get("perk", "none")) == "settling" and attunement_of(focus_technique) >= 60.0) else 25.0
	_shift_mind(settle)
	_shift_purity(2.0)
	_poll_achievements()
	return true

# --- P22: macro-tier guardians (ADR-001). Deterministic duels, no RNG. ---
func set_guardian_defs(defs: Array) -> void:
	## Guardian roster injected by caller (Main/tests) from
	## data/guardians.json. Engine stays data-free.
	_guardian_defs = defs.duplicate()

func guardian_ids_in_order() -> Array:
	var ids: Array = []
	for g in _guardian_defs:
		ids.append(str((g as Dictionary).get("id", "")))
	return ids

func guardian_roster() -> Array:
	## UI-ready roster: id, name, tier, guard_realm, defeated, attempts,
	## and whether this guardian currently bars the crossing.
	var out: Array = []
	var gate: Dictionary = guardian_gate()
	var active_id: String = str(gate.get("id", ""))
	var att: Dictionary = guardians.get("attempts", {})
	for g in _guardian_defs:
		var gid: String = str((g as Dictionary).get("id", ""))
		out.append({
			"id": gid, "name": str((g as Dictionary).get("name", gid)),
			"tier": int((g as Dictionary).get("tier", 0)),
			"guard_realm": int((g as Dictionary).get("guard_realm", 0)),
			"defeated": guardian_defeated(gid),
			"attempts": int(att.get(gid, 0)),
			"active": gid != "" and gid == active_id,
		})
	return out

func _guardian_def(id: String) -> Dictionary:
	for g in _guardian_defs:
		if str((g as Dictionary).get("id", "")) == id:
			return g
	return {}

func guardian_defeated(id: String) -> bool:
	return str(id) != "" and (guardians.get("defeated", []) as Array).has(id)

func guardian_gate() -> Dictionary:
	## Returns {"blocked": true, "id":, "name":, "tier":} when the current
	## realm is the last of its macro tier and that tier's guardian stands
	## undefeated. Empty Dictionary otherwise (interior realms, defeated
	## guardians, unwired tables, completed ladders).
	if _realm_table.is_empty() or _guardian_defs.is_empty():
		return {}
	if realm_index < 0 or realm_index >= realm_count:
		return {}
	var cur: Dictionary = _realm_table[clampi(realm_index, 0, _realm_table.size() - 1)]
	var t: int = int(cur.get("macro_tier", 0))
	if t <= 0:
		return {}
	var tier_end: int = -1
	for i in range(_realm_table.size()):
		if int((_realm_table[i] as Dictionary).get("macro_tier", 0)) == t:
			tier_end = i
	if tier_end < 0 or realm_index != tier_end:
		return {}
	for g in _guardian_defs:
		if int((g as Dictionary).get("tier", 0)) == t:
			var gid: String = str((g as Dictionary).get("id", ""))
			if gid == "" or guardian_defeated(gid):
				return {}
			return {"blocked": true, "id": gid, "name": str((g as Dictionary).get("name", gid)), "tier": t}
	return {}

func attempt_guardian(power: float, power_mult: float = 1.0) -> Dictionary:
	## Deterministic N-wave duel reusing the tribulation resolution family.
	## Defense is the same combined number as is_ready (power + artifact,
	## prep, season); guardian strikes escalate per wave. Guardian power is
	## the boundary tribulation power, so a cultivator ready to cross the
	## tier blocks every strike and wins Radiant by construction: the duel
	## is ceremony, stakes, and story — not a new wall.
	## Win (Radiant/Steady/Shaky): guardian falls, first-win reward pays.
	## Defeat: proportional Qi cost only — no death, no stage loss.
	var gate: Dictionary = guardian_gate()
	if gate.is_empty():
		return {"win": false, "reason": "no_guardian", "quality": "", "waves": [], "leak": 0.0, "reward": 0.0}
	var gid: String = str(gate.get("id", ""))
	var def: Dictionary = _guardian_def(gid)
	var G: float = maxf(float(def.get("power", 0.0)), 0.001)
	var n: int = maxi(int(def.get("waves", 4)), 1)
	var D: float = (power + artifact_power_bonus()) * _prep_power * power_mult * season_power_bonus()
	var leak: float = 0.0
	var waves_out: Array = []
	for j in range(n):
		var s: float = G * (0.5 + 0.5 * float(j) / maxf(float(n - 1), 1.0))
		var blocked: float = minf(s, D)
		leak += s - blocked
		waves_out.append({"strike": s, "blocked": blocked})
	var core: float = G * 1.5
	var quality: String = "Radiant" if leak <= 0.0 else ("Steady" if leak / maxf(core, 0.001) < 0.3 else ("Shaky" if leak <= core else "Defeat"))
	var att: Dictionary = guardians.get("attempts", {})
	att[gid] = int(att.get(gid, 0)) + 1
	guardians["attempts"] = att
	if quality == "Defeat":
		var r: float = clampf(D / maxf(G, 0.001), 0.0, 1.0)
		qi = BN.of(qi).times_float(0.5 + 0.5 * r)
		last_quality = "Defeated"
		last_tribulation = waves_out
		return {"win": false, "reason": "", "quality": quality, "waves": waves_out, "leak": leak, "reward": 0.0}
	(guardians.get("defeated", []) as Array).append(gid)
	var req: float = BN.of(qi_bottleneck).to_float()
	if not _realm_table.is_empty():
		req = float((_realm_table[clampi(int(def.get("guard_realm", realm_index)), 0, _realm_table.size() - 1)] as Dictionary).get("qi_required", req))
	var reward: float = req * float(def.get("reward_mult", 0.25))
	qi = BN.of(qi).plus(BN.from_float(reward))
	qi_earned_this_life = BN.of(qi_earned_this_life).plus(BN.from_float(reward))
	qi_earned_total = BN.of(qi_earned_total).plus(BN.from_float(reward))
	if focus_technique != "":
		train_technique(focus_technique, 100)
	last_quality = quality
	last_tribulation = waves_out
	_poll_achievements()
	return {"win": true, "reason": "", "quality": quality, "waves": waves_out, "leak": leak, "reward": reward}

func rebirth() -> void:
	# P12-5: the completed life settles into karma BEFORE anything resets;
	# the soul weapon, talents, and legacy cross over intact by design.
	# P22: guardian victories cross over too (sword dao remembered).
	# P24b: the new life does not start meditating.
	_presence_active = false
	karma += karma_yield()
	qi_earned_this_life = BN.from_float(0.0)
	total_rebirths += 1
	life_number += 1
	aptitude = 1.0 + float(total_rebirths) * 0.25
	age_years = 18
	_month_accum = 0
	qi = BN.from_float(0.0)
	# New life, new origin: reset to default, unlock choice. Dantian refinement persists.
	origin_id = "origin_wayfarer"
	origin_qi_mult = 1.0
	origin_lifespan_bonus = 0
	# P12-3: a new body sheds old scars (lifespan restored), but channel
	# flaws are karmic and persist until washed by baptism or medicine.
	lifespan_scars = 0
	_recompute_lifespan()
	_origin_locked = false
	# P12-2: new life, new fate and a rested heart. Roots re-roll from the
	# life number, so incarnations reproduce exactly across saves and tests.
	mind = 70.0
	_mind_wear = 0
	_mind_ease = 0
	_mind_calm = 0
	roll_roots(life_number * 7919 + 13)
	_mind_stage = mind_stage()
	_recompute_rate()
	reborn.emit(life_number)
	_poll_achievements()

func _die_of_age() -> void:
	died.emit("age")
	rebirth()

# --- P3b: techniques (xp per tick, level = floor(sqrt(xp/100))) ---
func train_technique(id: String, ticks: int = 1) -> void:
	var before: int = technique_level(id)
	techniques[id] = int(techniques.get(id, 0)) + maxi(ticks, 0)
	if technique_level(id) != before:
		_poll_achievements()

func technique_level(id: String) -> int:
	return int(floor(sqrt(float(int(techniques.get(id, 0))) / 100.0)))

func set_technique_defs(defs: Array) -> void:
	## Per-art params injected by caller (Main/tests) from data/techniques.json.
	## Engine stays data-free; unknown ids fall back to the legacy curve.
	_technique_defs = defs.duplicate()

func _tech_def(id: String) -> Dictionary:
	for t in _technique_defs:
		if str((t as Dictionary).get("id", "")) == id:
			return t
	return {"curve": [1.0, 0.10], "wear": 1.0, "perk": "none"}

func attunement_of(id: String) -> float:
	return clampf(float(attunement.get(id, 0.0)), 0.0, 100.0)

func perk_ready(id: String) -> bool:
	## Attunement-gated perks unlock at 60: commitment has a payoff threshold.
	return attunement_of(id) >= 60.0 and str(_tech_def(id).get("perk", "none")) != "none"

func technique_wear(id: String) -> float:
	## Heart-strain per drill tick for the art. Untiring/lightfoot perks
	## reshape it once attuned; emberstep is always costly, mistwalk kind.
	var w: float = float(_tech_def(id).get("wear", 1.0))
	var perk: String = str(_tech_def(id).get("perk", "none"))
	if perk == "untiring" and attunement_of(id) >= 60.0:
		return 0.0
	if perk == "lightfoot" and attunement_of(id) >= 60.0:
		w *= 0.5
	return w

func technique_power_bonus(id: String) -> float:
	## Per-art curve x attunement (max +50% power at 100) x summer.
	## Fresh/unknown ids reproduce the legacy 1+0.10L exactly.
	var curve: Array = _tech_def(id).get("curve", [1.0, 0.10])
	var summer: float = 1.1 if season_index() == 1 else 1.0
	return (float(curve[0]) + float(curve[1]) * float(technique_level(id))) * (1.0 + attunement_of(id) / 200.0) * summer

# --- P3c: bestiary (id -> kills; marked 5000, apex 20000) ---
const MARKED_KILLS: int = 5000
const APEX_KILLS: int = 20000

func _gain_herbs(x: float) -> void:
	## P15-Step2: single herb choke point, capped at 999 (a full cauldron).
	herbs = minf(999.0, maxf(0.0, herbs + x))

func hunt_tick(id: String, kills: int = 1) -> void:
	var before: String = completion_mark(id)
	beasts[id] = int(beasts.get(id, 0)) + maxi(kills, 0)
	if completion_mark(id) != before:
		_poll_achievements()
		# P13-B5 forage: milestone kills fund the cauldron — marked nests
		# hold +25 herbs, apex lairs +100. Stalk now feeds alchemy.
		if completion_mark(id) == "marked":
			_gain_herbs(25.0)
		elif completion_mark(id) == "apex":
			_gain_herbs(100.0)

func completion_mark(id: String) -> String:
	var k: int = int(beasts.get(id, 0))
	if k >= APEX_KILLS:
		return "apex"
	if k >= MARKED_KILLS:
		return "marked"
	return "none"

func seek_unfinished(order: Array) -> String:
	## First beast in data order without at least a marked completion.
	for id in order:
		if completion_mark(str(id)) == "none":
			return str(id)
	return ""

# --- P4b: seeded hunt map. Beast pool supplied by caller (Main/tests) to keep
# the engine data-free; nodes regenerate deterministically from map_seed. ---
var _beast_pool: Array = []
var _hunt_order: Array = []

func set_realm_count(n: int) -> void:
	## Ladder length supplied by caller (Main/tests) to keep the engine
	## data-free. Attempted breakthroughs past realm_count are refused.
	realm_count = maxi(n, 1)

# P12-1 — realm table supplied by caller (Main/tests) from data/realms.json.
# The engine never reads JSON itself. When present, the table is the single
# source of truth for bottleneck totals, lifespan, and tribulation tuning.
var _realm_table: Array = []
const LAYER_NAMES: Array = ["Early", "Mid", "Late"]

func set_realm_table(table: Array) -> void:
	## Wiring config never mutates progress counters: bottleneck derivation
	## happens on breakthrough/apply_state, so a frozen or mid-ladder engine
	## keeps its exact Qi position across the wire.
	_realm_table = table.duplicate()
	realm_count = maxi(_realm_table.size(), 1)
	# P18: the wired table owns the current bottleneck — a fresh run starts
	# at the authored realm-1 cost (front-loaded), never the 120.0 default.
	# Saved runs recompute the same derived value in apply_state.
	qi_bottleneck = _realm_total_for(realm_index)
	_recompute_lifespan()

func _realm_total_for(i: int):
	## Qi required to clear realm i (0-based), as Big. Beyond authored data
	## the x4 ladder continues ("room for more"); exact past float range.
	if _realm_table.is_empty():
		return BN.from_float(120.0 * pow(4.0, float(maxi(i, 0))))
	if i < 0:
		return BN.of((_realm_table[0] as Dictionary).get("qi_required", 120.0))
	if i < _realm_table.size():
		return BN.of((_realm_table[i] as Dictionary).get("qi_required", 120.0))
	var last = BN.of((_realm_table[_realm_table.size() - 1] as Dictionary).get("qi_required", 120.0))
	return last.times_float(pow(4.0, float(i - _realm_table.size() + 1)))

func _lifespan_for_realm(i: int) -> int:
	if not _realm_table.is_empty():
		var e: Dictionary = _realm_table[clampi(i, 0, _realm_table.size() - 1)]
		return maxi(int(e.get("lifespan", BASE_LIFESPAN)), 1)
	return BASE_LIFESPAN

func _recompute_lifespan() -> void:
	# P12-5: Long Breath lengthens every incarnation by 10% per level.
	var breath: float = 1.0 + 0.1 * float(talent_level("talent_breath"))
	lifespan_years = maxi(int(float(_lifespan_for_realm(realm_index) + origin_lifespan_bonus - lifespan_scars + dao_years_bonus()) * breath), 1)

func layer_index_for(qi_value: float, total: float) -> int:
	## Within-realm layer purely derived from fill fraction (nothing stored):
	## Early [0, 1/3), Mid [1/3, 2/3), Late [2/3, full].
	if total <= 0.0:
		return 0
	var f: float = clampf(qi_value / total, 0.0, 1.0)
	if f >= 2.0 / 3.0:
		return 2
	if f >= 1.0 / 3.0:
		return 1
	return 0

func realm_label() -> String:
	## Display string: index + authored name + macro tier + current layer.
	## Falls back to the numeric form when no table is wired (tests).
	## P15-Step3: a cleared summit reads COMPLETE — the persistent record.
	if victorious and realm_count > 0 and realm_index >= realm_count:
		return "Summit cleared · COMPLETE"
	var layer: String = str(LAYER_NAMES[layer_index_for(qi_num(), bottleneck_num())])
	if _realm_table.is_empty() or realm_index < 0 or realm_index >= _realm_table.size():
		return "Realm %d (%s)" % [realm_index, layer]
	var e: Dictionary = _realm_table[realm_index]
	return "R%d %s (%s, %s)" % [realm_index, str(e.get("name", "?")), str(e.get("macro_name", "?")), layer]

func set_reveal_rules(rules: Array) -> void:
	## P21: tab-unlock table injected by caller (Main) from data/reveal.json.
	## Engine stays data-free. Empty stat = always open (core tabs).
	_reveal_rules = rules.duplicate()

var _flight_rule: Dictionary = {}

func set_flight_rule(rule: Dictionary) -> void:
	## P24b: sword-flight unlock injected by caller (Main) from
	## data/flight.json. Same stat-gated pattern as reveal rules.
	_flight_rule = (rule as Dictionary).duplicate()

func flight_unlocked() -> bool:
	if _flight_rule.is_empty():
		return false
	return _stat_value(str(_flight_rule.get("stat", ""))) >= float(_flight_rule.get("value", 0))

func flight_unlock_line() -> String:
	return str(_flight_rule.get("line", ""))

func reveal_wired() -> bool:
	return not _reveal_rules.is_empty()

func tabs_unlocked() -> Array:
	## Tabs whose rule is met right now (derived, never stored). Only
	## meaningful once reveal_wired(); Main keeps the status quo until
	## then. Gates navigation only — content builders and programmatic
	## switches bypass the rail entirely (tests unaffected).
	var open: Array = []
	for r in _reveal_rules:
		var tab: String = str((r as Dictionary).get("tab", ""))
		if tab == "":
			continue
		var stat: String = str((r as Dictionary).get("stat", ""))
		if stat == "":
			open.append(tab)
		elif _stat_value(stat) >= float((r as Dictionary).get("value", 0)):
			open.append(tab)
	return open

func reveal_line(tab: String) -> String:
	for r in _reveal_rules:
		if str((r as Dictionary).get("tab", "")) == tab:
			return str((r as Dictionary).get("line", ""))
	return ""

func poll_milestone() -> Dictionary:
	## First entry into a new macro tier (call after breakthroughs).
	## Returns {} or {"tier": t, "name": macro}. Engine records the
	## dedication; Main presents it. Exactly one celebration per tier.
	var out: Dictionary = {}
	if _realm_table.is_empty() or realm_index <= 0:
		return out
	var e: Dictionary = _realm_table[clampi(realm_index, 0, _realm_table.size() - 1)]
	var t: int = int(e.get("macro_tier", 0))
	var prev: Dictionary = _realm_table[clampi(realm_index - 1, 0, _realm_table.size() - 1)]
	if int(prev.get("macro_tier", 0)) == t or milestones_seen.has(t):
		return out
	milestones_seen.append(t)
	return {"tier": t, "name": str(e.get("macro_name", ""))}

func realm_short() -> String:
	## Compact realm tag for the thin top bar (full realm_label would crowd
	## 15 siblings out of 1280px). Keeps index + name so all name asserts hold.
	if not _realm_table.is_empty() and realm_index >= 0 and realm_index < _realm_table.size():
		return "R%d %s" % [realm_index, str((_realm_table[realm_index] as Dictionary).get("name", "?"))]
	return "R%d" % realm_index

# --- P12-2: roots, mind, seasons ---
func roll_roots(seed_value: int) -> void:
	## Fated affinities: 5 weights normalized to sum 1.5. Deterministic per
	## seed (life fates), so tests and saves reproduce exactly.
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(seed_value, 1)
	var ws: Array = []
	var total: float = 0.0
	for el in ROOT_ELEMENTS:
		var w: float = 0.05 + rng.randf()
		ws.append(w)
		total += w
	roots.clear()
	for i in range(ROOT_ELEMENTS.size()):
		roots[ROOT_ELEMENTS[i]] = 1.5 * float(ws[i]) / total
	# P12-5: clarity purifies every incarnation at birth.
	_apply_root_clarity()
	_recompute_env()

func root_glyph() -> String:
	## Dominant element, or "unsettled" before the first fate roll.
	if roots.is_empty():
		return "unsettled"
	var best: String = ""
	var best_v: float = -1.0
	for el in roots:
		if float(roots[el]) > best_v:
			best_v = float(roots[el])
			best = str(el)
	return best

func mind_stage() -> int:
	if mind >= 66.0:
		return 0
	if mind >= 33.0:
		return 1
	return 2

func mind_stage_name() -> String:
	return str(MIND_NAMES[mind_stage()])

func mind_mult() -> float:
	## Bounded friction: a degenerate no-rest loop cruises at 0.8x, never
	## bricks. Teeth live in deviation (P12-3), not in this multiplier.
	match mind_stage():
		0:
			return 1.25
		2:
			return 0.8
	return 1.0

func _shift_mind(delta: float) -> void:
	mind = clampf(mind + delta, 0.0, 100.0)
	if mind_stage() != _mind_stage:
		_mind_stage = mind_stage()
		_recompute_rate()

func season_index() -> int:
	return clampi(_month_accum / 3, 0, 3)

func season_label() -> String:
	## P13-B4: the active seasonal effect rides in the label — buffs used to
	## be invisible. Substring-compatible with the old "Season · Term" form.
	var effects: Array = ["+Qi", "+drill", "+gather", "+ward"]
	return "%s (%s) · %s" % [str(SEASON_NAMES[season_index()]), str(effects[season_index()]), str(TERM_NAMES[clampi(_month_accum, 0, 11)])]

func _season_qi_mult() -> float:
	return 1.1 if season_index() == 0 else 1.0

func _season_gather_mult() -> float:
	return 1.1 if season_index() == 2 else 1.0

func season_power_bonus() -> float:
	return 1.1 if season_index() == 3 else 1.0

var _env_element: String = ""

func sympathy_glyph() -> String:
	## The element currently answering the cultivator's roots, or "—".
	## P13-B4: sympathy used to be invisible; now the HUD names it.
	if _env_mult > 1.0 and _env_element != "":
		return _env_element
	return "—"

func _recompute_env() -> void:
	## Environment sympathy: cultivating on grounds whose element matches a
	## root adds the full affinity as bonus Qi. No node, no sympathy.
	var m: float = 1.0
	_env_element = ""
	if current_node != "":
		var n: Dictionary = node_by_id(current_node)
		var el: String = str(_zone_elements.get(str(n.get("zone", "")), ""))
		if el != "" and float(roots.get(el, 0.0)) > 0.0:
			m = 1.0 + float(roots.get(el, 0.0))
			_env_element = el
	_env_mult = maxf(m, 0.0)
	_recompute_rate()

# --- P12-3: tribulation waves + deviation ---
func _waves_for_realm(i: int) -> int:
	## Strike count for the realm being ATTEMPTED (0-based index).
	if not _realm_table.is_empty():
		return maxi(int((_realm_table[clampi(i, 0, _realm_table.size() - 1)] as Dictionary).get("waves", 3)), 0)
	return 3

func pill_defs() -> Array:
	return PILL_DEFS.duplicate()

func pill_cost(id: String) -> float:
	for p in PILL_DEFS:
		if str((p as Dictionary).get("id", "")) == id:
			return float((p as Dictionary).get("cost", 0.0))
	return -1.0

func brew_pill(id: String) -> bool:
	## Spend herbs to concoct one pill. Instant: no brew timers.
	var cost: float = pill_cost(id)
	if cost < 0.0 or herbs < cost:
		return false
	herbs -= cost
	pills[id] = int(pills.get(id, 0)) + 1
	_poll_achievements()
	return true

func drink_pill(id: String) -> bool:
	## Quaff a pill: prep/ward charge the next tribulation, heal mends a
	## flaw, purge burns toxicity out. Every draught leaves residue (+12).
	if pill_cost(id) < 0.0 or int(pills.get(id, 0)) <= 0:
		return false
	pills[id] = int(pills.get(id, 0)) - 1
	match id:
		"pill_prep":
			_prep_power = 1.25
		"pill_ward":
			_ward_power = 2.0
		"pill_heal":
			deviation = maxi(0, deviation - 1)
		"pill_purge":
			toxicity = maxf(0.0, toxicity - 40.0)
		_:
			return false
	toxicity = minf(100.0, toxicity + 12.0)
	_recompute_rate()
	_poll_achievements()
	return true

# --- P12-5: karma, talents, soul weapon, bequest ---
func karma_yield() -> int:
	## Samsara yield: depth squared times log lifetime Qi, achievement-weighted.
	## Rapid low-tier farming pays nothing; deep runs pay super-linearly.
	## P15-Step1: an attuned soulmirror path tithes +5% per soul level.
	var psi: float = 1.0 + 0.02 * float(achievements.size())
	var depth: float = float(realm_index * realm_index)
	var q: float = pow(maxf(log(BN.of(qi_earned_this_life).plus(1.0).to_float()) / log(10.0), 0.0), 1.35)
	var mirror: float = 1.0
	if str(soulweapon.get("path", "")) == "soul_mirror":
		mirror = 1.0 + 0.05 * float(soul_level())
	return int(floor(psi * depth * q * mirror * dao_tithe_bonus()))

func talent_level(id: String) -> int:
	return int(talents.get(id, 0))

func talent_cost(id: String) -> int:
	## P15-Step2: ranks never cap — the quadratic cost is the sink. Deep
	## ranks (L50 ≈ 26k, L100 ≈ 102k) eventually outrun any single life's
	## yield, so surplus karma always has somewhere to go.
	var known: bool = false
	for t in TALENT_DEFS:
		if str((t as Dictionary).get("id", "")) == id:
			known = true
			break
	if not known:
		return -1
	var lv: int = talent_level(id)
	return 10 * (lv + 1) * (lv + 1)

func buy_talent(id: String) -> bool:
	var cost: int = talent_cost(id)
	if cost < 0 or karma < cost:
		return false
	karma -= cost
	talents[id] = talent_level(id) + 1
	if id == "talent_roots":
		_apply_root_clarity()
	_recompute_lifespan()
	_recompute_rate()
	_poll_achievements()
	return true

func _apply_root_clarity() -> void:
	## Each clarity level purifies every affinity by +0.05, retroactive to
	## the current incarnation and re-applied on every fate roll.
	var bonus: float = 0.05 * float(talent_level("talent_roots"))
	if bonus <= 0.0 or roots.is_empty():
		return
	for el in roots:
		roots[el] = float(roots[el]) + bonus
	_recompute_env()

func talent_power_bonus() -> float:
	return 2.0 * float(talent_level("talent_body"))

func soul_level() -> int:
	if soulweapon.is_empty():
		return 0
	return int(floor(sqrt(maxf(float(soulweapon.get("xp", 0)), 0.0) / 10.0)))

func soul_power_bonus() -> float:
	## P15-Step1: only the oathblade converts levels to raw power. The bell
	## wards (forecast shield) and the mirror tithes karma instead — three
	## paths, three play styles, one permanent choice that finally matters.
	if str(soulweapon.get("path", "")) == "soul_blade":
		return 1.0 * float(soul_level())
	return 0.0

func artifact_power_bonus() -> float:
	## Talent body + soul weapon ride every effective-power computation.
	return talent_power_bonus() + soul_power_bonus()

func choose_soul_weapon(path_id: String) -> bool:
	## One soul, one path, forever: the second oath is refused.
	if not soulweapon.is_empty():
		return false
	for p in SOUL_PATHS:
		if str((p as Dictionary).get("id", "")) == path_id:
			soulweapon = {"path": path_id, "xp": 0}
			_poll_achievements()
			return true
	return false

func soul_paths() -> Array:
	return SOUL_PATHS.duplicate()

func talent_rows() -> Array:
	var out: Array = []
	for t in TALENT_DEFS:
		var tid: String = str((t as Dictionary).get("id", ""))
		out.append({
			"id": tid,
			"name": str((t as Dictionary).get("name", tid)),
			"level": talent_level(tid),
			"max": int((t as Dictionary).get("max", 10)),
			"cost": talent_cost(tid),
		})
	return out

func soul_display() -> String:
	if soulweapon.is_empty():
		return "unbound"
	var pid: String = str(soulweapon.get("path", ""))
	var nm: String = pid
	for p in SOUL_PATHS:
		if str((p as Dictionary).get("id", "")) == pid:
			nm = str((p as Dictionary).get("name", pid))
	return "%s Lv%d (%d strikes weathered)" % [nm, soul_level(), int(soulweapon.get("xp", 0))]

func bequeath_gear(id: String, max_level: int) -> bool:
	## Sacrifice a perfected relic: the gear is consumed, +0.02 legacy Qi
	## endures across all future lives. Only the perfected may be given.
	if int(gear.get(id, 0)) < maxi(max_level, 1):
		return false
	gear.erase(id)
	legacy_mult += 0.02
	_recompute_rate()
	_poll_achievements()
	return true

# --- P19b: ascension prestige (Dao Marks) ---
func set_prestige_defs(defs: Array) -> void:
	## Per-node params injected by caller (Main/tests) from data/prestige.json.
	## Engine stays data-free; unknown ids fall back to flat defaults.
	_prestige_defs = defs.duplicate()

func _dao_def(id: String) -> Dictionary:
	for p in _prestige_defs:
		if str((p as Dictionary).get("id", "")) == id:
			return p
	return {"max": 20, "effect": 0.1}

func dao_rank(id: String) -> int:
	return maxi(int(dao_nodes.get(id, 0)), 0)

func dao_flow_bonus() -> float:
	return 1.0 + float(_dao_def("dao_flow").get("effect", 0.1)) * float(dao_rank("dao_flow"))

func dao_years_bonus() -> int:
	return int(round(float(_dao_def("dao_years").get("effect", 5.0)) * float(dao_rank("dao_years"))))

func dao_tithe_bonus() -> float:
	return 1.0 + float(_dao_def("dao_tithe").get("effect", 0.1)) * float(dao_rank("dao_tithe"))

func dao_rows() -> Array:
	var out: Array = []
	for p in _prestige_defs:
		var pid: String = str((p as Dictionary).get("id", ""))
		out.append({
			"id": pid,
			"name": str((p as Dictionary).get("name", pid)),
			"level": dao_rank(pid),
			"max": int((p as Dictionary).get("max", 20)),
			"cost": dao_node_cost(pid),
		})
	return out

func dao_node_cost(id: String) -> int:
	## Next rank costs rank+1 marks; -1 when unknown or perfected.
	var known: bool = false
	for p in _prestige_defs:
		if str((p as Dictionary).get("id", "")) == id:
			known = true
			break
	if not known:
		return -1
	if dao_rank(id) >= int(_dao_def(id).get("max", 20)):
		return -1
	return dao_rank(id) + 1

func buy_dao_node(id: String) -> bool:
	var cost: int = dao_node_cost(id)
	if cost < 0 or dao_marks < cost:
		return false
	dao_marks -= cost
	dao_nodes[id] = dao_rank(id) + 1
	_recompute_lifespan()
	_recompute_rate()
	return true

func lifetime_qi_num() -> float:
	return BN.of(qi_earned_total).to_float()

func calculate_prestige_gain() -> int:
	## Sqrt-dampened ascension yield on all-time earnings. Below the first
	## threshold (1M lifetime Qi) there is nothing to ascend with.
	var total: float = lifetime_qi_num()
	if total < PRESTIGE_THRESHOLD:
		return 0
	return int(floor(PRESTIGE_FACTOR * sqrt(total / PRESTIGE_THRESHOLD)))

func ascend() -> int:
	## Leave this world: bank Dao Marks, reset realm/rate/aptitude/gear/
	## sect/arts/attunement/herbs. Soul, talents, karma, achievements,
	## records, guardians, and the marks ledger cross over. Returns marks gained.
	var gain: int = calculate_prestige_gain()
	if gain <= 0:
		return 0
	dao_marks += gain
	dao_ascensions += 1
	# P24b: ascension lands the avatar — presence never crosses over.
	_presence_active = false
	total_rebirths = 0
	life_number += 1
	aptitude = 1.0
	age_years = 18
	_month_accum = 0
	qi = BN.from_float(0.0)
	qi_per_tick = BN.from_float(1.0)
	realm_index = 0
	qi_bottleneck = _realm_total_for(0)
	qi_earned_this_life = BN.from_float(0.0)
	gear = {}
	sect = {}
	disciples = []
	techniques = {}
	attunement = {}
	herbs = 0.0
	pills = {}
	toxicity = 0.0
	deviation = 0
	lifespan_scars = 0
	current_node = ""
	origin_id = "origin_wayfarer"
	origin_qi_mult = 1.0
	origin_lifespan_bonus = 0
	_origin_locked = false
	mind = 70.0
	_mind_wear = 0
	_mind_ease = 0
	_mind_calm = 0
	roll_roots(life_number * 7919 + 13)
	_mind_stage = mind_stage()
	_prep_power = 1.0
	_ward_power = 1.0
	_recompute_lifespan()
	_recompute_gather()
	_recompute_env()
	_recompute_rate()
	_poll_achievements()
	ascended.emit(gain)
	return gain

func buy_bulk(kind: String, id: String, n: int, max_level: int = 0) -> int:
	## Repeatable buys in bulk: gear refines, pill brews, talent ranks,
	## dao ranks. n < 0 means MAX (capped at 999 iterations). Returns units
	## actually bought; stops at the first refusal (broke or perfected).
	var want: int = 999 if n < 0 else maxi(n, 0)
	var got: int = 0
	while got < want:
		var ok: bool = false
		match kind:
			"gear":
				ok = refine_gear(id, max_level)
			"pill":
				ok = brew_pill(id)
			"talent":
				ok = buy_talent(id)
			"dao":
				ok = buy_dao_node(id)
		if not ok:
			break
		got += 1
	return got

func is_ready(power: float, required: float, power_mult: float = 1.0) -> bool:
	## Single authority for attemptability. Callers gate on this; the engine
	## enforces the identical expression below — same op order, so no 1-ulp
	## boundary drift between "looks ready" and "passes the gate".
	return (power + artifact_power_bonus()) * _prep_power * power_mult * season_power_bonus() >= required

func trib_power_for(i: int) -> float:
	## Realm i's tribulation requirement from data (legacy 5+5r fallback).
	## Powers the drill hint; Main/policies read the same table directly.
	if not _realm_table.is_empty():
		return float((_realm_table[clampi(i, 0, _realm_table.size() - 1)] as Dictionary).get("trib_power", 5.0 + 5.0 * float(maxi(i, 0))))
	return 5.0 + 5.0 * float(maxi(i, 0))

func readiness_pct(power: float, required: float, power_mult: float = 1.0) -> float:
	## Effective power over requirement as a percentage. Display only; the
	## gate in attempt_breakthrough is the authority, never this number.
	if required <= 0.0:
		return 100.0
	return 100.0 * (power + artifact_power_bonus()) * power_mult * season_power_bonus() / required

func forecast_quality(power: float, required: float, power_mult: float, fill: float, ward_mult: float = 1.0) -> Dictionary:
	## Deterministic wave resolution, no state change. Each strike tests the
	## regenerating shield (defense re-raises per wave); leaks accumulate
	## against core health. Returns {quality, waves, leak, core}.
	var waves_n: int = _waves_for_realm(realm_index)
	var out: Array = []
	if waves_n <= 0:
		var q0: String = "Radiant" if fill >= 0.999 else "Steady"
		return {"quality": q0, "waves": out, "leak": 0.0, "core": 1.0}
	var req: float = maxf(required, 0.001)
	## power arrives pre-combined: (base + artifact) x prep. The forecast
	## never adds artifact itself, so gate, waves, and readiness agree.
	## P15-Step1: an attuned rootgrip focus braces the shield (+25%); an
	## attuned soulbell pathwardens it (+15%/soul level). Bulwarks, not numbers.
	var defense: float = power * power_mult * season_power_bonus() * maxf(ward_mult, 0.0) * (0.7 + 0.3 * clampf(fill, 0.0, 1.0))
	if str(_tech_def(focus_technique).get("perk", "none")) == "bulwark" and attunement_of(focus_technique) >= 60.0:
		defense *= 1.25
	if str(soulweapon.get("path", "")) == "soul_bell":
		defense *= 1.0 + 0.15 * float(soul_level())
	if mind_stage() == 2:
		defense *= 0.8  # a strained heart cannot hold the shield steady
	var core: float = req * 1.5 * (0.5 + clampf(dantian_purity, 0.0, 100.0) / 100.0)
	var leak: float = 0.0
	for j in range(waves_n):
		var frac: float = 0.0 if waves_n <= 1 else float(j) / float(waves_n - 1)
		var strike: float = req * (0.7 + 0.6 * frac)
		var blocked: float = minf(strike, defense)
		leak += strike - blocked
		out.append({"strike": strike, "blocked": blocked, "leaked": strike - blocked})
	var q: String = "Shaky"
	if leak <= 0.0:
		q = "Radiant"
	elif leak / maxf(core, 0.001) < 0.3:
		q = "Steady"
	return {"quality": q, "waves": out, "leak": leak, "core": core}

func set_beast_pool(pool: Array) -> void:
	_beast_pool = pool.duplicate()
	# P12-2: zone -> element sympathy, first-seen wins (each zone is pure
	# in authored data; the convention is enforced by ContentDB + tests).
	_zone_elements.clear()
	for b in _beast_pool:
		var z: String = str((b as Dictionary).get("zone", ""))
		if z != "" and not _zone_elements.has(z):
			_zone_elements[z] = str((b as Dictionary).get("element", ""))

func set_hunt_order(order: Array) -> void:
	_hunt_order = order.duplicate()

func generate_map(seed_value: int = -1) -> void:
	var s: int = seed_value
	if s < 0:
		s = int(Time.get_unix_time_from_system()) % 1000000
	map_seed = s
	regenerate_map()

func regenerate_map() -> void:
	map_nodes.clear()
	if _beast_pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	# Zones derived from pool in first-seen order (matches beasts.json layout).
	var zones: Array = []
	for b in _beast_pool:
		var z: String = str((b as Dictionary).get("zone", ""))
		if z != "" and not zones.has(z):
			zones.append(z)
	for z in zones:
		var pool: Array = []
		for b in _beast_pool:
			if str((b as Dictionary).get("zone", "")) == str(z):
				pool.append(b)
		if pool.is_empty():
			continue
		for i in range(4):
			var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			var y: float = 1.0 + float(rng.randi_range(0, 100)) / 100.0
			map_nodes.append({
				"id": "%s_%d" % [str(z).to_lower(), i],
				"zone": str(z),
				"beast_id": str(pick.get("id", "")),
				"yield_mult": y,
			})

func node_by_id(id: String) -> Dictionary:
	for n in map_nodes:
		if str((n as Dictionary).get("id", "")) == id:
			return n
	return {}

func _beast_def(beast_id: String) -> Dictionary:
	for b in _beast_pool:
		if str((b as Dictionary).get("id", "")) == beast_id:
			return b
	return {}

func zone_gate(beast_id: String) -> int:
	return int(_beast_def(beast_id).get("min_realm", 0))

func travel_toll(id: String) -> float:
	## P15-Step5: new horizons call freely, but pacing old roads costs
	## provisions (5% of the current bottleneck). First visits stay free so
	## exploration and mind-healing loops never break; repetition is taxed.
	## Must-afford invariant: the toll never exceeds spendable Qi, so travel
	## can refuse but never strands (breathing to earn is always legal, and
	## unwalked grounds are always free).
	var n: Dictionary = node_by_id(id)
	if n.is_empty():
		return 0.0
	if realm_index < zone_gate(str(n.get("beast_id", ""))):
		return 0.0
	if not nodes_visited.has(id):
		return 0.0
	return 0.05 * maxf(bottleneck_num(), 1.0)

func travel_to(id: String) -> bool:
	var n: Dictionary = node_by_id(id)
	if n.is_empty():
		return false
	if realm_index < zone_gate(str(n.get("beast_id", ""))):
		return false
	var toll: float = travel_toll(id)
	if BN.of(qi).lt(toll):
		return false
	qi = BN.of(qi).minus(toll)
	current_node = id
	if not nodes_visited.has(id):
		nodes_visited.append(id)
		# P12-2: new ground restores the heart (+8). Commuting over walked
		# ground does not; exploration, not motion, is the medicine.
		_shift_mind(8.0)
	# P12-4: secular downtime purges residue (-20 per journey).
	toxicity = maxf(0.0, toxicity - 20.0)
	_recompute_env()
	return true

func hunt_yield_mult(beast_id: String) -> float:
	## P15-Step4: stalking beyond your strength yields less and rattles the
	## heart. Typical power (Main's 10 + artifacts, best art) against the
	## beast's recorded power: full at parity, 3/4 down to half strength,
	## half below that. Drill-before-stalking becomes a real decision.
	var bpower: float = float(_beast_def(beast_id).get("power", 0.0))
	if bpower <= 0.0:
		return 1.0
	var ratio: float = (10.0 + artifact_power_bonus()) * best_technique_bonus() / bpower
	if ratio >= 1.0:
		return 1.0
	if ratio >= 0.5:
		return 0.75
	return 0.5

func hunt_at(id: String, kills: int = 1) -> int:
	var n: Dictionary = node_by_id(id)
	if n.is_empty():
		return 0
	var bid: String = str(n.get("beast_id", ""))
	var mult: float = hunt_yield_mult(bid)
	var got: int = maxi(1, int(round(float(kills) * float(n.get("yield_mult", 1.0)) * mult)))
	if mult < 1.0:
		_shift_mind(-1.0)  # overmatched outings rattle even on success
	hunt_tick(bid, got)
	return got

func wander() -> String:
	## Travel to the richest unvisited ground; once all are walked, chase the
	## highest-yield ground whose beast still wants recording. Candidates are
	## tried richest-first until one succeeds (P15-Step5 tolls can refuse the
	## richest). Returns node id or "" when nothing is walkable.
	var cands: Array = []
	for n in map_nodes:
		var nid: String = str((n as Dictionary).get("id", ""))
		if nodes_visited.has(nid):
			continue
		if not _walkable(str((n as Dictionary).get("beast_id", ""))):
			continue
		cands.append(nid)
	cands.sort_custom(func(a: String, b: String) -> bool: return _node_yield(a) > _node_yield(b))
	if cands.is_empty() and not _hunt_order.is_empty():
		var target: String = seek_unfinished(_hunt_order)
		for n in map_nodes:
			var bid: String = str((n as Dictionary).get("beast_id", ""))
			if bid == target and _walkable(bid):
				cands.append(str((n as Dictionary).get("id", "")))
				break
	for nid in cands:
		if travel_to(str(nid)):
			return str(nid)
	return ""

func _node_yield(nid: String) -> float:
	var n: Dictionary = node_by_id(nid)
	if n.is_empty():
		return -1.0
	return float(n.get("yield_mult", 1.0))

func _walkable(beast_id: String) -> bool:
	return realm_index >= zone_gate(beast_id)

func due_hints() -> Array:
	## One-time contextual guidance, evaluated in state order. Caller logs and
	## marks seen via mark_hint(). Original text.
	var out: Array = []
	var debts: Array = [
		["hint_origin", not _origin_locked],
		["hint_bottleneck", BN.of(qi).ge(qi_bottleneck) and realm_index == 0 and _origin_locked],
		# P13-B3: brimming but weak — typical power 10 plus artifacts against
		# the table requirement. Names the drill fix exactly once per save.
		["hint_drill", BN.of(qi).ge(qi_bottleneck) and (10.0 + artifact_power_bonus()) * best_technique_bonus() < trib_power_for(realm_index)],
		["hint_pause", pause_before_death_years == 0 and total_rebirths >= 1],
		["hint_travel", realm_index >= 2 and current_node == ""],
		["hint_sect", realm_index >= 3 and sect.is_empty()],
		["hint_duties", disciples.size() >= 1 and _all_idle()],
		["hint_gear", int(_gear_levels()) == 0 and BN.of(qi).ge(100.0)],
		["hint_legacy", total_rebirths >= 1 and (techniques.size() + (gear as Dictionary).size() + (beasts as Dictionary).size()) > 0],
	]
	for pair in debts:
		var hid: String = str(pair[0])
		if bool(pair[1]) and not hints_seen.has(hid) and not out.has(hid):
			out.append(hid)
	return out

func _all_idle() -> bool:
	for d in disciples:
		if str((d as Dictionary).get("task", "idle")) != "idle":
			return false
	return true

func _gear_levels() -> int:
	var t: int = 0
	for k in gear:
		t += int(gear.get(k, 0))
	return t

func mark_hint(hid: String) -> void:
	if not hints_seen.has(hid):
		hints_seen.append(hid)

# --- P4c: sect + disciples. Legacy persists across rebirth. ---
func found_sect(sect_name: String) -> bool:
	if not sect.is_empty():
		return false
	var n: String = sect_name.strip_edges()
	if n == "":
		return false
	sect = {"name": n}
	_poll_achievements()
	return true

func disciple_cap() -> int:
	return 2 + realm_index

func recruit_cost() -> float:
	## P15-Step2: capped at 8 fills so an early companion never costs more
	## than a fraction of a life. Disciples persist across rebirth, so the
	## lifetime ROI was always positive; the cap removes the early trap only.
	return minf(200.0 * pow(3.0, float(disciples.size())), 8.0 * maxf(bottleneck_num(), 1.0))

func recruit_disciple() -> bool:
	if disciples.size() >= disciple_cap():
		return false
	var c: float = recruit_cost()
	if BN.of(qi).lt(c):
		return false
	qi = BN.of(qi).minus(c)
	disciples.append({"task": "idle"})
	_recompute_gather()
	_poll_achievements()
	return true

func assign_disciple(i: int, task: String) -> bool:
	if i < 0 or i >= disciples.size():
		return false
	if not ["gather", "hunt", "train", "idle"].has(task):
		return false
	(disciples[i] as Dictionary)["task"] = task
	_recompute_gather()
	return true

func _recompute_gather() -> void:
	var n: int = 0
	for d in disciples:
		if str((d as Dictionary).get("task", "")) == "gather":
			n += 1
	_gatherers = n
	_gather_mult = (1.0 + 0.02 * float(n)) * _season_gather_mult()
	_recompute_rate()

func _disciple_tick() -> void:
	# P12-4 garden: the plot yields 1 herb per 48 ticks tended alone, plus
	# 1 per 12 ticks per gather-duty disciple.
	_gain_herbs(float(_gatherers) / 12.0 + 1.0 / 48.0)
	if disciples.is_empty():
		return
	var hunters: int = 0
	var trainers: int = 0
	for d in disciples:
		match str((d as Dictionary).get("task", "")):
			"hunt":
				hunters += 1
			"train":
				trainers += 1
	if hunters > 0 and not _hunt_order.is_empty():
		var target: String = seek_unfinished(_hunt_order)
		if target != "":
			hunt_tick(target, maxi(1, int(round(float(hunters) * hunt_yield_mult(target)))))
	if trainers > 0 and focus_technique != "":
		train_technique(focus_technique, trainers)

func resume() -> void:
	running = true

# --- P5a: achievements. Rules: [{id, stat, value}]. Supplied by caller. ---
func set_achievement_rules(rules: Array) -> void:
	_achievement_rules = rules.duplicate()

func _stat_value(stat: String) -> float:
	match stat:
		"rebirths":
			return float(total_rebirths)
		"realm":
			return float(realm_index)
		"marked":
			var n: int = 0
			for k in beasts:
				if completion_mark(str(k)) != "none":
					n += 1
			return float(n)
		"apex":
			var n: int = 0
			for k in beasts:
				if completion_mark(str(k)) == "apex":
					n += 1
			return float(n)
		"gear_levels":
			var t: int = 0
			for k in gear:
				t += int(gear.get(k, 0))
			return float(t)
		"disciples":
			return float(disciples.size())
		"sect":
			return 1.0 if not sect.is_empty() else 0.0
		"tech_level":
			var best: int = 0
			for k in techniques:
				best = maxi(best, technique_level(str(k)))
			return float(best)
		"purity":
			return dantian_purity
		"karma":
			return float(karma)
		"talents":
			var ranks: int = 0
			for k in talents:
				ranks += int(talents.get(k, 0))
			return float(ranks)
		"soul":
			return 1.0 if not soulweapon.is_empty() else 0.0
		"legacy":
			return 1.0 if legacy_mult > 1.0 else 0.0
		"pills":
			var stock: int = 0
			for k in pills:
				stock += int(pills.get(k, 0))
			return float(stock)
		# P21: tab-reveal stats (additive; achievements never key on them).
		"herbs":
			return maxf(0.0, float(herbs))
		"deeds":
			return float(achievements.size())
		"attunement":
			var peak: float = 0.0
			for k in attunement:
				peak = maxf(peak, float(attunement.get(k, 0.0)))
			return peak
		"victorious":
			return 1.0 if victorious else 0.0
	return 0.0

func _poll_achievements() -> void:
	for r in _achievement_rules:
		var id: String = str((r as Dictionary).get("id", ""))
		if id == "" or achievements.has(id):
			continue
		if _stat_value(str((r as Dictionary).get("stat", ""))) >= float((r as Dictionary).get("value", 0)):
			achievements.append(id)
			achievement_unlocked.emit(id)

func get_state() -> Dictionary:
	return {
		"tick_count": tick_count, "age_years": age_years, "lifespan_years": lifespan_years,
		"qi": BN.of(qi).to_save(), "qi_per_tick": BN.of(qi_per_tick).to_save(), "realm_index": realm_index,
		"qi_bottleneck": BN.of(qi_bottleneck).to_save(), "life_number": life_number,
		"aptitude": aptitude, "total_rebirths": total_rebirths,
		"time_scale": time_scale,
		"origin_id": origin_id, "origin_qi_mult": origin_qi_mult,
		"origin_lifespan_bonus": origin_lifespan_bonus,
		"dantian_purity": dantian_purity,
		"techniques": techniques.duplicate(), "beasts": beasts.duplicate(),
		"pause_before_death_years": pause_before_death_years,
		"gear": gear.duplicate(),
		"sect": sect.duplicate(), "disciples": disciples.duplicate(),
		"focus_technique": focus_technique,
		"map_seed": map_seed, "current_node": current_node,
		"achievements": achievements.duplicate(),
		"player_focus": player_focus, "muted": muted,
		"hints_seen": hints_seen.duplicate(),
		"nodes_visited": nodes_visited.duplicate(),
		"roots": roots.duplicate(), "mind": mind,
		"deviation": deviation, "lifespan_scars": lifespan_scars,
		"herbs": herbs, "pills": pills.duplicate(), "toxicity": toxicity,
		"karma": karma, "talents": talents.duplicate(),
		"soulweapon": soulweapon.duplicate(), "legacy_mult": legacy_mult,
		"qi_earned_this_life": BN.of(qi_earned_this_life).to_save(),
		"qi_earned_total": BN.of(qi_earned_total).to_save(),
		"dao_marks": dao_marks, "dao_nodes": dao_nodes.duplicate(),
		"dao_ascensions": dao_ascensions,
		"milestones_seen": milestones_seen.duplicate(),
		"coach_done": coach_done,
		"attunement": attunement.duplicate(), "victorious": victorious,
		"offline_mortality": offline_mortality,
		"guardians": {"defeated": (guardians.get("defeated", []) as Array).duplicate(), "attempts": (guardians.get("attempts", {}) as Dictionary).duplicate()},
	}

func apply_state(d: Dictionary) -> void:
	tick_count = int(d.get("tick_count", 0))
	age_years = int(d.get("age_years", 18))
	lifespan_years = int(d.get("lifespan_years", 60))
	# P19a: BN.of accepts v10 save-dicts {m, e} AND legacy floats.
	qi = BN.of(d.get("qi", 0.0))
	qi_per_tick = BN.of(d.get("qi_per_tick", 1.0))
	realm_index = int(d.get("realm_index", 0))
	qi_bottleneck = BN.of(d.get("qi_bottleneck", 120.0))
	life_number = int(d.get("life_number", 1))
	aptitude = float(d.get("aptitude", 1.0))
	total_rebirths = int(d.get("total_rebirths", 0))
	set_time_scale(float(d.get("time_scale", 1.0)))
	origin_id = str(d.get("origin_id", "origin_wayfarer"))
	origin_qi_mult = float(d.get("origin_qi_mult", 1.0))
	origin_lifespan_bonus = int(d.get("origin_lifespan_bonus", 0))
	_origin_locked = origin_id != "origin_wayfarer" or origin_qi_mult != 1.0
	dantian_purity = clampf(float(d.get("dantian_purity", DANTIAN_DEFAULT)), DANTIAN_MIN, DANTIAN_MAX)
	# P12-1: stale-proof derived values. A stored bottleneck/lifespan from an
	# older ladder is recomputed from the live table whenever one is wired.
	if not _realm_table.is_empty():
		qi_bottleneck = _realm_total_for(realm_index)
		_recompute_lifespan()
	techniques = (d.get("techniques", {}) as Dictionary).duplicate()
	beasts = (d.get("beasts", {}) as Dictionary).duplicate()
	pause_before_death_years = maxi(int(d.get("pause_before_death_years", 0)), 0)
	gear = (d.get("gear", {}) as Dictionary).duplicate()
	sect = (d.get("sect", {}) as Dictionary).duplicate()
	disciples = (d.get("disciples", []) as Array).duplicate()
	focus_technique = str(d.get("focus_technique", ""))
	map_seed = int(d.get("map_seed", -1))
	current_node = str(d.get("current_node", ""))
	achievements = (d.get("achievements", []) as Array).duplicate()
	player_focus = str(d.get("player_focus", "cultivate"))
	if not ["cultivate", "train", "hunt"].has(player_focus):
		player_focus = "cultivate"
	# P24b: presence is runtime-only — a loaded run never resumes meditating.
	_presence_active = false
	focus_mult = 1.0 if player_focus == "cultivate" else 0.0
	muted = bool(d.get("muted", false))
	hints_seen = (d.get("hints_seen", []) as Array).duplicate()
	nodes_visited = (d.get("nodes_visited", []) as Array).duplicate()
	roots = (d.get("roots", {}) as Dictionary).duplicate()
	mind = clampf(float(d.get("mind", 70.0)), 0.0, 100.0)
	deviation = clampi(int(d.get("deviation", 0)), 0, 3)
	lifespan_scars = maxi(int(d.get("lifespan_scars", 0)), 0)
	herbs = maxf(0.0, float(d.get("herbs", 0.0)))
	pills = (d.get("pills", {}) as Dictionary).duplicate()
	toxicity = clampf(float(d.get("toxicity", 0.0)), 0.0, 100.0)
	_prep_power = 1.0
	_ward_power = 1.0
	karma = maxi(int(d.get("karma", 0)), 0)
	talents = (d.get("talents", {}) as Dictionary).duplicate()
	soulweapon = (d.get("soulweapon", {}) as Dictionary).duplicate()
	legacy_mult = maxf(1.0, float(d.get("legacy_mult", 1.0)))
	qi_earned_this_life = BN.of(d.get("qi_earned_this_life", 0.0))
	qi_earned_total = BN.of(d.get("qi_earned_total", 0.0))
	dao_marks = maxi(int(d.get("dao_marks", 0)), 0)
	dao_nodes = (d.get("dao_nodes", {}) as Dictionary).duplicate()
	dao_ascensions = maxi(int(d.get("dao_ascensions", 0)), 0)
	milestones_seen = (d.get("milestones_seen", []) as Array).duplicate()
	coach_done = bool(d.get("coach_done", false))
	attunement = (d.get("attunement", {}) as Dictionary).duplicate()
	victorious = bool(d.get("victorious", false))
	var om: String = str(d.get("offline_mortality", "vigil"))
	offline_mortality = om if ["vigil", "unfettered"].has(om) else "vigil"
	# P22: guardians persist rebirth AND ascend (sword dao remembered).
	# Validate shapes: defeated must be an id array, attempts an id->int map.
	guardians = {"defeated": [], "attempts": {}}
	var gs: Variant = d.get("guardians", {})
	if gs is Dictionary:
		var raw_defeated: Variant = (gs as Dictionary).get("defeated", [])
		if raw_defeated is Array:
			var defeats: Array = []
			for gid in (raw_defeated as Array):
				if str(gid) != "" and not defeats.has(str(gid)):
					defeats.append(str(gid))
			guardians["defeated"] = defeats
		var raw_tries: Variant = (gs as Dictionary).get("attempts", {})
		if raw_tries is Dictionary:
			var tries: Dictionary = {}
			for k in (raw_tries as Dictionary):
				tries[str(k)] = maxi(int((raw_tries as Dictionary).get(k, 0)), 0)
			guardians["attempts"] = tries
	_mind_stage = mind_stage()
	_mind_wear = 0
	_mind_ease = 0
	_mind_calm = 0
	_recompute_env()
	# map_nodes regenerate from seed once caller supplies the beast pool
	# (Main does this on ready; see set_beast_pool + regenerate_map).
	_recompute_gather()
	_recompute_rate()
