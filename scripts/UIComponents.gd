extends RefCounted
## UIComponents — reusable HUD factories (stat rows now, tabs/toasts/modals in
## later P17 steps). Code-built controls keep every component headless-testable.
## NOTE: no class_name; load via preload const UICOMP.

static func stat_row(name_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StatRow"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var name_label := Label.new()
	name_label.name = "StatName"
	name_label.text = name_text
	var value_label := Label.new()
	value_label.name = "StatValue"
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(value_label)
	return row
