extends RefCounted
## UpgradeRow — one data-driven shop row: title line + buy button.
## Original code. build_row() returns a VBoxContainer; the caller connects
## the BuyBtn and rebuilds on state change (same signature-gated pattern as
## every other shop). Unaffordable rows dim instead of hiding, so costs
## stay visible as goals. One-shots (oaths, origins, bequests) stay plain
## buttons — rows are for repeatable buys, with optional bulk suffix.
## NOTE: no class_name; load via preload const ROW.

static func build_row(row_name: String, title: String, action_text: String, tip: String, affordable: bool) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 0)
	var lab := Label.new()
	lab.name = "TitleLabel"
	lab.text = title
	lab.autowrap_mode = 2
	row.add_child(lab)
	var b := Button.new()
	b.name = "BuyBtn"
	b.text = action_text
	b.tooltip_text = tip
	b.disabled = not affordable
	if not affordable:
		b.modulate.a = 0.45
	row.add_child(b)
	return row

static func bulk_suffix(qty: int) -> String:
	## " ×10" / " ×MAX" appended to bulkable action text; "" for single buys.
	if qty < 0:
		return " ×MAX"
	if qty > 1:
		return " ×%d" % qty
	return ""
