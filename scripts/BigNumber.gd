extends RefCounted
## Big-number value type: mantissa + base-10 exponent, immutable by
## convention (every op returns a NEW instance, never mutates).
## Coercion: of() accepts Big, float, int, or save-dict {m, e} — engine
## read sites tolerate legacy float assignment (tests set plain floats).
## P21 backends: "gdscript" (proven P19a core, default) or "native"
## (shoyguer GDExtension, bench-decided). The adapter surface, guards
## (unsigned domain, div-zero, 1e-12 cmp epsilon), display, and save shape
## are backend-independent — only arithmetic kernels delegate. ChronoDK's
## file is vendored as reference (third_party/); the native core descends
## from it, so adopting native adopts that lineage optimized.
## NOTE: no class_name (avoids self-reference parse issue); load via preload const BN.

var mantissa: float = 0.0
var exponent: int = 0
var _nb = null

static var _backend: String = "gdscript"
static var _nb_missing_warned: bool = false

static func use_backend(name: String) -> bool:
	## Switch arithmetic backend. "native" needs the GDExtension class;
	## without it the call fails closed (stays put, returns false).
	if name == "gdscript":
		_backend = name
		return true
	if name == "native" and ClassDB.class_exists("BigNumber"):
		_backend = name
		return true
	return false

static func backend() -> String:
	return _backend

static func _native_of(m: float, e: int):
	## Native handle from any (m, e) pair. The pair is normalized HERE
	## (unsigned domain): set_mantissa normalizes its input in place but
	## leaves the exponent alone (probed: setting 1234 keeps e=0), and
	## native normalize() drops the shift entirely — so neither can be
	## trusted with unnormalized input. Guards stay in the adapter.
	var mm: float = m
	var ee: int = e
	if mm == 0.0 or not is_finite(mm):
		mm = 0.0
		ee = 0
	else:
		while mm >= 10.0:
			mm /= 10.0
			ee += 1
		while mm < 1.0:
			mm *= 10.0
			ee -= 1
	var n = BigNumber.new()
	n.set_mantissa(mm)
	n.set_exponent(ee)
	return n

static func _wrap_nb(n) -> Variant:
	## Adapter shell around a native result. Vars re-canonicalized through
	## the adapter norm (native results may arrive unnormalized); the
	## native handle is kept as returned for the next delegated op.
	var S: GDScript = load("res://scripts/BigNumber.gd")
	var b = S.new()
	b._nb = n
	b.mantissa = float(n.get_mantissa())
	b.exponent = int(n.get_exponent())
	b._norm()
	return b

static func _native_enabled() -> bool:
	if _backend == "native" and ClassDB.class_exists("BigNumber"):
		return true
	if _backend == "native" and not _nb_missing_warned:
		_nb_missing_warned = true
		push_warning("BigNumber adapter: native backend requested but BigNumber class missing; staying GDScript for this call.")
	return false

static func _make(m: float, e: int):
	var b = (load("res://scripts/BigNumber.gd") as GDScript).new()
	b.mantissa = m
	b.exponent = e
	b._norm()
	if _native_enabled():
		b._nb = _native_of(b.mantissa, b.exponent)
	return b

func _norm() -> void:
	if mantissa == 0.0 or not is_finite(mantissa):
		mantissa = 0.0
		exponent = 0
		return
	if mantissa < 0.0:
		mantissa = 0.0
		exponent = 0
		return
	while mantissa >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while mantissa < 1.0:
		mantissa *= 10.0
		exponent -= 1

static func _nb_of(v):
	## Native handle for a value, building + caching it from the synced
	## vars when the value was born under the other backend (backend flips
	## happen in tests; live runs never flip). Cache attach is invisible.
	if v.get("_nb") != null:
		return v.get("_nb")
	var n = _native_of(float(v.get("mantissa")), int(v.get("exponent")))
	v.set("_nb", n)
	return n

static func of(v):
	## Coerce anything into Big. Big passes through (no copy — immutable).
	var S: GDScript = load("res://scripts/BigNumber.gd")
	if v == null:
		return S._make(0.0, 0)
	if typeof(v) == TYPE_OBJECT and v.get("mantissa") != null:
		if _native_enabled():
			_nb_of(v)
		return v
	if v is Dictionary:
		var dm: float = float(v.get("m", 0.0))
		var de: int = int(v.get("e", 0))
		# Integer fast path mirrors from_float: exactly-representable
		# integers survive the save round-trip bit-identical.
		if de >= -15:
			var f: float = dm * pow(10.0, float(de))
			if is_finite(f) and f >= 0.0 and f < 1e15 and f == floor(f):
				return S._raw(f, 0)
		return S._make(dm, de)
	if v is float or v is int:
		return S.from_float(float(v))
	return S._make(0.0, 0)

static func _raw(m: float, e: int):
	## Un-normalized construction. Only from_float may use it (integer
	## fast path below); every op normalizes through _make.
	var b = (load("res://scripts/BigNumber.gd") as GDScript).new()
	b.mantissa = m
	b.exponent = e
	return b

static func from_float(v: float):
	if v <= 0.0 or not is_finite(v):
		return (load("res://scripts/BigNumber.gd") as GDScript)._make(0.0, 0)
	# Integers inside float64's exact range stay byte-identical (mantissa =
	# the integer, exponent 0): save round-trips and == asserts in tests
	# survive the migration. Fractional values take the normalized path.
	if v == floor(v) and v < 1e15:
		return (load("res://scripts/BigNumber.gd") as GDScript)._raw(v, 0)
	var e: int = int(floor(log(v) / log(10.0)))
	return (load("res://scripts/BigNumber.gd") as GDScript)._make(v / pow(10.0, float(e)), e)

func is_zero() -> bool:
	return mantissa == 0.0

func to_float() -> float:
	var S: GDScript = load("res://scripts/BigNumber.gd")
	if S._native_enabled():
		return float(S._nb_of(self).to_float())
	return mantissa * pow(10.0, float(exponent))

func plus(other):
	var S: GDScript = load("res://scripts/BigNumber.gd")
	var b = S.of(other)
	if is_zero():
		return b
	if b.is_zero():
		return self
	if S._native_enabled():
		return S._wrap_nb(S._nb_of(self).plus(S._nb_of(b)))
	var d: int = exponent - int(b.get("exponent"))
	if d > 15:
		return self
	if d < -15:
		return b
	var m: float
	if d >= 0:
		m = mantissa + float(b.get("mantissa")) / pow(10.0, float(d))
	else:
		m = mantissa / pow(10.0, float(-d)) + float(b.get("mantissa"))
	return S._make(m, maxi(exponent, int(b.get("exponent"))))

func minus(other):
	var S: GDScript = load("res://scripts/BigNumber.gd")
	var b = S.of(other)
	if cmp(b) <= 0:
		return S._make(0.0, 0)
	# Guard first: the native core mis-signs true underflow (probed:
	# 4242−10000 yields +5758), which can never arrive past this guard.
	if S._native_enabled():
		return S._wrap_nb(S._nb_of(self).minus(S._nb_of(b)))
	var d: int = exponent - int(b.get("exponent"))
	var m: float
	if d >= 0:
		m = mantissa - float(b.get("mantissa")) / pow(10.0, float(maxi(d, 0)))
	else:
		m = mantissa / pow(10.0, float(-d)) - float(b.get("mantissa"))
	return S._make(maxf(m, 0.0), exponent)

func times(other):
	var S: GDScript = load("res://scripts/BigNumber.gd")
	var b = S.of(other)
	if is_zero() or b.is_zero():
		return S._make(0.0, 0)
	if S._native_enabled():
		return S._wrap_nb(S._nb_of(self).multiply(S._nb_of(b)))
	return S._make(mantissa * float(b.get("mantissa")), exponent + int(b.get("exponent")))

func times_float(f: float):
	var S: GDScript = load("res://scripts/BigNumber.gd")
	if f <= 0.0 or is_zero():
		return S._make(0.0, 0)
	if S._native_enabled():
		return S._wrap_nb(S._nb_of(self).multiply(f))
	return S._make(mantissa * f, exponent)

func div(other):
	var S: GDScript = load("res://scripts/BigNumber.gd")
	var b = S.of(other)
	if is_zero() or b.is_zero():
		return S._make(0.0, 0)
	if S._native_enabled():
		return S._wrap_nb(S._nb_of(self).divide(S._nb_of(b)))
	return S._make(mantissa / float(b.get("mantissa")), exponent - int(b.get("exponent")))

func cmp(other) -> int:
	# Rep-insensitive: integers may sit raw (4242e0) or normalized
	# (4.242e3) — cross-scale into one decade before comparing, so equal
	# values in different reps still compare equal.
	var b = (load("res://scripts/BigNumber.gd") as GDScript).of(other)
	var bz: bool = b.is_zero()
	if is_zero() and bz:
		return 0
	if is_zero():
		return -1
	if bz:
		return 1
	var d: int = exponent - int(b.get("exponent"))
	if d > 15:
		return 1
	if d < -15:
		return -1
	var am: float = mantissa
	var bm: float = float(b.get("mantissa"))
	if d >= 0:
		bm /= pow(10.0, float(d))
	else:
		am /= pow(10.0, float(-d))
	# Relative epsilon kills last-ulp flapping at gate boundaries.
	var rel: float = absf(am - bm) / maxf(am, 1e-300)
	if rel < 1e-12:
		return 0
	return 1 if am > bm else -1

func eq(other) -> bool:
	return cmp(other) == 0

func lt(other) -> bool:
	return cmp(other) < 0

func le(other) -> bool:
	return cmp(other) <= 0

func gt(other) -> bool:
	return cmp(other) > 0

func ge(other) -> bool:
	return cmp(other) >= 0

func floor_int():
	## Largest integral value <= self. Past 16 digits everything is integral.
	if is_zero() or exponent < 0:
		return (load("res://scripts/BigNumber.gd") as GDScript)._make(0.0, 0)
	if exponent > 15:
		return self
	return (load("res://scripts/BigNumber.gd") as GDScript).from_float(floor(to_float()))

func to_save() -> Dictionary:
	return {"m": mantissa, "e": exponent}

static func format_hybrid(v: float, scientific_below_1k: bool = false) -> String:
	if v < 0.0:
		return "-" + str((load("res://scripts/BigNumber.gd") as GDScript).format_hybrid(-v, scientific_below_1k))
	if v < 1000.0:
		if scientific_below_1k:
			return "%1.2e" % v
		if v == floor(v):
			return str(int(v))
		return "%1.1f" % v
	# P12-6: suffixes to 1e51 (~realm 85), so the ladder has display room
	# past 50. Beyond that the scientific fallback still holds.
	var suffixes: PackedStringArray = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid"]
	var tier: int = int(floor(log(v) / log(1000.0)))
	if tier - 1 < suffixes.size():
		var scaled: float = v / pow(1000.0, float(tier))
		return "%1.2f%s" % [scaled, suffixes[tier - 1]]
	return "%1.2e" % v

static func format_any(v) -> String:
	## Display anything: Big renders natively (no float round-trip past
	## 1e308), floats keep the legacy hybrid path.
	var S: GDScript = load("res://scripts/BigNumber.gd")
	var b = S.of(v)
	if int(b.get("exponent")) < 0:
		return S.format_hybrid(0.0)
	if int(b.get("exponent")) < 3:
		return S.format_hybrid(float(b.call("to_float")))
	var suffixes: PackedStringArray = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Qad2", "Qid2", "Sx2", "Sp2"]
	var tier: int = int(b.get("exponent")) / 3
	if tier - 1 < suffixes.size():
		var scaled: float = float(b.get("mantissa")) * pow(10.0, float(int(b.get("exponent")) % 3))
		return "%1.2f%s" % [scaled, suffixes[tier - 1]]
	return "%1.2fe%d" % [float(b.get("mantissa")), int(b.get("exponent"))]
