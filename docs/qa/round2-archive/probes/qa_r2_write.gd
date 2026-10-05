extends SceneTree
## QA Round 2 probe: write mode. Boots the real scene, then persists a
## custom rebind + settings the way the vendor options UI does.
## Run: --headless -s res://tools/qa_r2_write.gd

func _initialize() -> void:
	print("QA2-WRITE start")
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var custom := InputEventKey.new()
	custom.physical_keycode = KEY_B
	# Same call the vendor list makes on rebind.
	AppSettings.set_config_input_events("cult_breathe", [custom])
	PlayerConfig.set_config("CultivationNation", "sfx_volume", 0.25)
	PlayerConfig.set_config("CultivationNation", "skin", "parchment")
	PlayerConfig.set_config("CultivationNation", "music_volume", 0.75)
	print("QA2-WRITE cfg=", FileAccess.get_file_as_string("user://player_config.cfg").replace("\n", " | "))
	quit(0)