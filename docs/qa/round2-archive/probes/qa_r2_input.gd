extends SceneTree
## QA Round 2 probe: input defect verification.
##  1. Vendor "reset to default inputs" restores the live InputMap?
##  2. Does the legacy handle_shortcut fallback defeat a rebind?
## Run: --headless -s res://tools/qa_r2_input.gd

func _initialize() -> void:
	print("QA2-INPUT start")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ge: Node = root.get_node("GameEngine")

	# ---- 1. vendor reset path ----
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_B
	AppSettings.set_config_input_events("cult_breathe", [custom])
	main.call("_register_input_actions")
	print("QA2-INPUT pre-reset events=", _codes("cult_breathe"))
	print("QA2-INPUT defaults_dict_size=", AppSettings.default_action_events.size())
	AppSettings.reset_to_default_inputs()
	print("QA2-INPUT post-reset events=", _codes("cult_breathe"), " cfg=", AppSettings.get_config_input_events("cult_breathe", []).size())
	print("QA2-INPUT config_section_present=", PlayerConfig.has_section(AppSettings.INPUT_SECTION))

	# ---- 2. legacy fallback vs rebind ----
	AppSettings.set_config_input_events("cult_breathe", [custom])
	main.call("_register_input_actions")
	print("QA2-INPUT rebound events=", _codes("cult_breathe"))
	ge.set("player_focus", "")
	var ev_legacy := InputEventKey.new()
	ev_legacy.physical_keycode = KEY_1
	ev_legacy.pressed = true
	main.call("_unhandled_key_input", ev_legacy)
	print("QA2-INPUT after legacy KEY_1 player_focus=", str(ge.get("player_focus")))
	ge.set("player_focus", "")
	var ev_new := InputEventKey.new()
	ev_new.physical_keycode = KEY_B
	ev_new.pressed = true
	main.call("_unhandled_key_input", ev_new)
	print("QA2-INPUT after rebound KEY_B player_focus=", str(ge.get("player_focus")))

	# ---- 3. one key bound to two actions ----
	AppSettings.set_config_input_events("cult_breathe", [custom])
	AppSettings.set_config_input_events("cult_drill", [custom])
	main.call("_register_input_actions")
	ge.set("player_focus", "")
	main.call("_unhandled_key_input", ev_new)
	print("QA2-INPUT conflict KEY_B focus=", str(ge.get("player_focus")), " (first action in chain wins, no error)")

	# ---- 4. unbound action ----
	AppSettings.set_config_input_events("cult_breathe", [])
	AppSettings.set_config_input_events("cult_drill", [])
	main.call("_register_input_actions")
	print("QA2-INPUT unbound events=", _codes("cult_breathe"), " cfg=", AppSettings.get_config_input_events("cult_breathe", []).size())
	ge.set("player_focus", "")
	var ev_one := InputEventKey.new()
	ev_one.physical_keycode = KEY_1
	ev_one.pressed = true
	main.call("_unhandled_key_input", ev_one)
	main.call("_unhandled_key_input", ev_new)
	print("QA2-INPUT unbound no-op focus=", str(ge.get("player_focus")))

	# ---- 5. reset restores an unbound action ----
	AppSettings.reset_to_default_inputs()
	main.call("_register_input_actions")
	print("QA2-INPUT reset after unbind events=", _codes("cult_breathe"))

	# ---- 6. Escape still closes UI after a rebind ----
	AppSettings.set_config_input_events("cult_breathe", [custom])
	main.call("_register_input_actions")
	var panel := main.get_node("UI/Root/SidePanel")
	panel.visible = true
	var ev_esc := InputEventKey.new()
	ev_esc.physical_keycode = KEY_ESCAPE
	ev_esc.pressed = true
	main.call("_unhandled_key_input", ev_esc)
	print("QA2-INPUT escape after rebind panel_visible=", panel.visible)
	quit(0)

func _codes(action: String) -> Array:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		out.append(int((e as InputEventKey).physical_keycode))
	return out