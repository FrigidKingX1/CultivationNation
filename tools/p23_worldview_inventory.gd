extends SceneTree
## v3: extracts the FULL WorldView facade contract (all methods — no
## underscore exclusion, since GDScript privacy is convention), all signals,
## all exports, PLUS [connection] lines in Main.tscn that target the World
## node. Deterministic output (no timestamps): the p23 contract test
## re-extracts and requires an exact diff. Run BEFORE any P23 edit; commit
## output. No scene boot -> no save contamination.
## Run: <engine> --headless --path <project> -s "res://tools/p23_worldview_inventory.gd"
const SCRIPT_PATH := "res://scripts/WorldView.gd"
const SCENE_PATH := "res://scenes/Main.tscn"
const OUT_PATH := "res://docs/qa/p23_worldview_contract.txt"
const CONTRACT_FORMAT := 3
const WORLD_NODE_HINTS := ["WorldViewport/World", "World"]

func _initialize() -> void:
	var script: Script = load(SCRIPT_PATH)
	if script == null:
		push_error("WorldView script not found")
		quit(1)
		return
	var src: String = script.source_code
	var lines: Array[String] = [
		"# WorldView facade contract",
		"contract-format: %d" % CONTRACT_FORMAT,
		"# Deterministic output. Member removal/edit requires a rule-11",
		"# contract edit with justification. Semantic requirements:",
		"# docs/adr/P23_COUPLING_ADDENDUM.md",
		"script: %s" % SCRIPT_PATH, "", "## signals"]
	var sig_re := RegEx.new()
	sig_re.compile("(?m)^signal\\s+.*$")
	var fun_re := RegEx.new()
	fun_re.compile("(?m)^func\\s+.*$")
	var stat_re := RegEx.new()
	stat_re.compile("(?m)^static\\s+func\\s+.*$")
	var exp_re := RegEx.new()
	exp_re.compile("(?m)^@export\\s+.*$")
	for m in sig_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	lines.append("")
	lines.append("## exports")
	for m in exp_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	lines.append("")
	lines.append("## methods (ALL — underscore included; full signatures)")
	for m in fun_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	lines.append("")
	lines.append("## static methods")
	for m in stat_re.search_all(src):
		lines.append(m.get_string(0).strip_edges())
	var scene_text := ""
	var f := FileAccess.open(SCENE_PATH, FileAccess.READ)
	if f:
		scene_text = f.get_as_text()
	lines.append("")
	lines.append("## tscn connections targeting World node")
	var con_re := RegEx.new()
	con_re.compile("(?m)^\\[connection[^\\n]*\\]")
	for m in con_re.search_all(scene_text):
		var l := m.get_string(0)
		for hint in WORLD_NODE_HINTS:
			if l.contains("node=\"" + hint) or l.contains("from=\"" + hint) or l.contains("to=\"" + hint):
				lines.append(l)
				break
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var out := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if out == null:
		push_error("cannot write " + OUT_PATH)
		quit(1)
		return
	out.store_string("\n".join(lines) + "\n")
	print("Wrote %s (%d lines)" % [OUT_PATH, lines.size()])
	quit(0)
