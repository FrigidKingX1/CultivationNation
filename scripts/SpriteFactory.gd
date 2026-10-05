extends RefCounted
## SpriteFactory — the SINGLE source of every texture and sprite in the game.
## All art (procedural now, imported later) routes through make_sprite(), so
## the look can be swapped without touching scenes or view code. Original
## clean-room art, generated at runtime; zero binary assets.
## NOTE: no class_name (project convention); load via preload const SF.
## Headless-safe: pure Image math + ImageTexture resources, no draw calls.

const INK := Color(0.10, 0.10, 0.13, 1.0)
const PAPER := Color(0.91, 0.88, 0.80, 1.0)
const SKIN := Color(0.91, 0.82, 0.69, 1.0)
const GOLD := Color(0.85, 0.66, 0.22, 1.0)

const ELEMENT_COLORS := {
	"metal": Color(0.81, 0.84, 0.87, 1.0),
	"wood": Color(0.35, 0.56, 0.35, 1.0),
	"water": Color(0.29, 0.50, 0.71, 1.0),
	"fire": Color(0.76, 0.33, 0.23, 1.0),
	"earth": Color(0.60, 0.48, 0.31, 1.0),
}

static var _cache: Dictionary = {}

static func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, PAPER)

## make_sprite(kind, variant, tint) -> Texture2D. Cached by key.
## kinds: "cultivator" (tint = robe color), "beast" (variant = beast id for
## stable per-beast shape, tint = element color resolved by the caller),
## "glow" (soft white radial dot, tinted at use). Unknown kinds fall back
## to glow rather than erroring.
static func make_sprite(kind: String, variant: String = "", tint: Color = Color.WHITE) -> Texture2D:
	var key: String = "%s|%s|%s" % [kind, variant, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	match kind:
		"cultivator":
			tex = _paint_cultivator(tint)
		"beast":
			tex = _paint_beast(variant, tint)
		"glow":
			tex = _paint_glow()
		_:
			tex = _paint_glow()
	_cache[key] = tex
	return tex

static func _img(w: int, h: int) -> Image:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	return im

static func _rect(im: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, im.get_height())):
		for x in range(maxi(x0, 0), mini(x1, im.get_width())):
			im.set_pixel(x, y, c)

static func _disc(im: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx: int = x - cx
			var dy: int = y - cy
			if dx * dx + dy * dy <= r * r:
				if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
					im.set_pixel(x, y, c)

static func _outline_disc(im: Image, cx: int, cy: int, r: int, c: Color, w: int = 2) -> void:
	for i in range(w):
		var rr: int = r - i
		for y in range(cy - rr, cy + rr + 1):
			for x in range(cx - rr, cx + rr + 1):
				var d: float = sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
				if absf(d - float(rr)) < 0.9:
					if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
						im.set_pixel(x, y, c)

static func _paint_cultivator(robe: Color) -> Texture2D:
	var im := _img(64, 96)
	var dark: Color = robe.darkened(0.35)
	# Robe body with ink outline.
	_rect(im, 20, 34, 44, 90, robe)
	_rect(im, 20, 34, 44, 37, INK)
	_rect(im, 20, 87, 44, 90, INK)
	_rect(im, 20, 34, 23, 90, INK)
	_rect(im, 41, 34, 44, 90, INK)
	# Sleeves darker.
	_rect(im, 14, 40, 20, 66, dark)
	_rect(im, 44, 40, 50, 66, dark)
	# Sash gold band.
	_rect(im, 20, 56, 44, 61, GOLD)
	_rect(im, 20, 56, 44, 57, INK)
	# Head: paper face, ink outline, closed meditating eyes.
	_disc(im, 32, 24, 10, SKIN)
	_outline_disc(im, 32, 24, 10, INK)
	_rect(im, 25, 23, 29, 25, INK)
	_rect(im, 35, 23, 39, 25, INK)
	# Straw hat: brim + crown.
	_rect(im, 12, 12, 52, 17, INK)
	_rect(im, 24, 4, 40, 13, robe.darkened(0.15))
	_rect(im, 24, 4, 40, 6, INK)
	return ImageTexture.create_from_image(im)

static func _paint_beast(variant: String, tint: Color) -> Texture2D:
	var im := _img(64, 64)
	var h: int = absi(variant.hash())
	var rx: int = 14 + h % 7
	var ry: int = 10 + (h / 7) % 7
	var cx: int = 32
	var cy: int = 38
	var dark: Color = tint.darkened(0.4)
	var pale: Color = tint.lightened(0.45)
	# P16-Step3: silhouettes by hash — crawler, stander, flyer, serpent.
	# Same canvas and calling convention; new shapes, no scene changes.
	var build: int = h % 4
	if build == 1:
		# Stander: tall narrow body on two legs.
		rx = 10
		ry = 16
		cy = 30
		_rect(im, cx - 8, 44, cx - 4, 56, dark)
		_rect(im, cx + 4, 44, cx + 8, 56, dark)
	elif build == 2:
		# Flyer: swept wings wide.
		_rect(im, cx - rx - 10, cy - 12, cx - rx + 4, cy - 2, dark)
		_rect(im, cx + rx - 4, cy - 12, cx + rx + 10, cy - 2, dark)
	elif build == 3:
		# Serpent: three stacked coils rising.
		_disc(im, cx - 4, 46, 10, tint)
		_disc(im, cx, 36, 8, tint)
		_disc(im, cx + 4, 26, 6, tint)
		_disc(im, cx, 36, 8, pale)
	# Tail for some crawlers and standers.
	if build != 3 and h % 3 == 0:
		_rect(im, 6, cy - 8, 14, cy - 4, dark)
	# Body ellipse + pale belly (serpents already bodied above).
	if build != 3:
		for y in range(cy - ry, cy + ry + 1):
			for x in range(cx - rx, cx + rx + 1):
				var nx: float = float(x - cx) / float(rx)
				var ny: float = float(y - cy) / float(ry)
				if nx * nx + ny * ny <= 1.0:
					im.set_pixel(x, y, tint)
		for y in range(cy + 2, cy + ry):
			for x in range(cx - rx / 2, cx + rx / 2 + 1):
				var nx: float = float(x - cx) / float(rx)
				var ny: float = float(y - cy) / float(ry)
				if nx * nx + ny * ny <= 0.8:
					im.set_pixel(x, y, pale)
	# Ink rim (approximate: darken edge band). Serpents rim their own coils.
	if build != 3:
		for y in range(cy - ry, cy + ry + 1):
			for x in range(cx - rx, cx + rx + 1):
				var nx: float = float(x - cx) / float(rx)
				var ny: float = float(y - cy) / float(ry)
				var d: float = nx * nx + ny * ny
				if d > 0.82 and d <= 1.0:
					im.set_pixel(x, y, INK)
		# Ears or horns by hash.
		if h % 2 == 0:
			_rect(im, cx - rx + 2, cy - ry - 7, cx - rx + 8, cy - ry - 1, dark)
			_rect(im, cx + rx - 8, cy - ry - 7, cx + rx - 2, cy - ry - 1, dark)
		else:
			_rect(im, cx - 8, cy - ry - 9, cx - 6, cy - ry - 1, PAPER)
			_rect(im, cx + 6, cy - ry - 9, cx + 8, cy - ry - 1, PAPER)
	# Eyes: ink dots with paper glint (serpent eyes ride the top coil).
	var ex: int = 6 + h % 4
	var ey: int = 22 if build == 3 else cy - 4
	var ex0: int = cx + 4 if build == 3 else cx
	_rect(im, ex0 - ex - 2, ey, ex0 - ex + 1, ey + 3, INK)
	_rect(im, ex0 + ex - 1, ey, ex0 + ex + 2, ey + 3, INK)
	im.set_pixel(ex0 - ex - 1, ey + 1, PAPER)
	im.set_pixel(ex0 + ex, ey + 1, PAPER)
	return ImageTexture.create_from_image(im)

static func _paint_glow() -> Texture2D:
	var im := _img(32, 32)
	for y in range(32):
		for x in range(32):
			var dx: float = (float(x) - 15.5) / 15.5
			var dy: float = (float(y) - 15.5) / 15.5
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(im)
