extends SceneTree
## QA Round 2 probe: read mode. Fresh process — no in-memory state at all.
## Asserts the rebind + settings actually came back off disk.
## Run: --headless -s res://tools/qa_r2_read.gd

func _initialize() -> void:
	print("QA2-READ start")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var evs: Array = InputMap.action_get_events("cult_breathe")
	var codes: Array = []
	for e in evs:
		codes.append(int((e as InputEventKey).physical_keycode))
	print("QA2-READ breathe events=", codes, " expect=[", KEY_B, "]")
	var sfx: Node = root.get_node("SfxSynth")
	print("QA2-READ sfx_volume=", sfx.get("volume"))
	var ui: Node = main.get_node("UI")
	print("QA2-READ skin=", ui.call("get_skin"))
	var ok: bool = codes.size() == 1 and int(codes[0]) == KEY_B
	print("QA2-READ rebind_persisted=", ok)
	quit(0 if ok else 1)