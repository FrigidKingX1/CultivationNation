extends Node
## Main — P1 vertical-slice glue. Original code.
## Auto-cultivate loop + auto-tribulation attempt + periodic save + UI poll.
## Playable: leave running, watch Life/Age/Qi advance, breakthroughs and rebirths occur.

const BN: GDScript = preload("res://scripts/BigNumber.gd")
const MODAL: GDScript = preload("res://scripts/ModalManager.gd")
const ROW: GDScript = preload("res://scripts/UpgradeRow.gd")

# P21: lofi direction (Eric Matyas, soundimage.org — attribution filed).
# Missing track → silence, never errors (player-less/headless safe).
const TRACKS := {
	"title": "res://assets/music/title_lofi.ogg",
	"game": "res://assets/music/game_lofi.ogg",
	"triumph": "res://assets/music/triumph_lofi.ogg",
}
const SETTINGS_SECTION := "CultivationNation"

# P19c: global bulk-buy quantity for repeatable shops (gear, brews,
# talents, dao). Cycles 1 → 10 → MAX(−1) from the top-bar button.
var _bulk_qty: int = 1

var _ui_timer: float = 0.0
var _save_timer: float = 0.0
var _auto_breakthrough_power: float = 10.0
# P13-B1: one unready note per fill (reset while Qi is short of the bottleneck).
var _unready_note_done: bool = false
# P22: one lost-duel note per fill for the same reason (duels repeat until
# the pool drops below the bottleneck; wins always report, max seven ever).
var _warden_note_done: bool = false
# P24b: one stride-refusal note per locked zone (avatar movement polls
# every frame; the warden pattern applies to feet too).
var _stride_note: String = "#"
# P15-Step3: victory celebration fires once per Main session, on the attempt
# that clears the ladder (post-clear attempts are cap-refused, so no encore).
var _victory_logged: bool = false

func _maybe_celebrate() -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.get("victorious")) and not _victory_logged:
		_victory_logged = true
		_log("The fiftieth gate opens onto morning. The climb is complete.")
		_log("Samsara bows; the heavens record the name. (Post-clear sandbox continues.)")
		_toast("Summit cleared — COMPLETE", "realm")
		_sfx("breakthrough")
		var ui_fx: Node = get_node_or_null("UI")
		if ui_fx != null and ui_fx.has_method("play_breakthrough_fx"):
			ui_fx.call("play_breakthrough_fx")
		_music_play("triumph")
		_maybe_milestone()
		return
	# Post-triumph sandbox crossings settle back into the game theme.
	_music_play("game")
	_maybe_milestone()

func _maybe_milestone() -> void:
	## P19c: first entry into a macro tier gets a dedication modal (once
	## per tier per save) plus the chronicle line. Called after every
	## successful breakthrough on both attempt paths.
	var ge: Node = get_node("/root/GameEngine")
	var ms: Dictionary = ge.call("poll_milestone")
	if ms.is_empty():
		return
	var line: String = "The %s opens before you. Heaven notes the crossing." % str(ms.get("name", ""))
	_log(line)
	_toast("Entered %s" % str(ms.get("name", "")), "realm")
	_sfx("breakthrough")
	var ui: Node = get_node_or_null("UI")
	if ui != null:
		MODAL.present(ui, MODAL.build_report("The %s Opens" % str(ms.get("name", "")), PackedStringArray([line, "The climb continues — deeper heavens, heavier tribulations."])))
# P12-1 — cached realm table (wired from ContentDB). Single source of truth
# for tribulation power; legacy 5+5r formula is the table-less fallback.
var _realm_table: Array = []

func _trib_need(ge: Node) -> float:
	var r: int = int(ge.get("realm_index"))
	if r >= 0 and r < _realm_table.size():
		return float((_realm_table[r] as Dictionary).get("trib_power", 5.0 + 5.0 * float(r)))
	return 5.0 + float(r) * 5.0

var _veil_frames: int = -1

func _ready() -> void:
	_show_veil()
	_veil_frames = 0
	# P14: bind the live viewport texture directly (get_texture() is already
	# bound — no path resolution to fail. A path-based ViewportTexture
	# sub-resource resolved to a 0x0 texture and showed flat grey.)
	var wdr: TextureRect = get_node_or_null("WorldDisplay")
	var svp: SubViewport = get_node_or_null("WorldViewport")
	if wdr != null and svp != null:
		wdr.texture = svp.get_texture()
	var ge: Node = get_node("/root/GameEngine")
	ge.call("set_time_scale", 10.0)  # P1 demo pace: 10x so progress visible quickly
	# P16-Step1: connects land before load so offline deaths and pauses log
	# through the same handlers as live ones.
	if ge.has_signal("paused_for_death") and not ge.is_connected("paused_for_death", _on_pause_for_death):
		ge.connect("paused_for_death", _on_pause_for_death)
	if ge.has_signal("achievement_unlocked") and not ge.is_connected("achievement_unlocked", _on_achievement):
		ge.connect("achievement_unlocked", _on_achievement)
	if ge.has_signal("reborn") and not ge.is_connected("reborn", _on_reborn):
		ge.connect("reborn", _on_reborn)
	if get_node_or_null("/root/SaveManager") != null:
		var sm: Node = get_node("/root/SaveManager")
		sm.set("engine_ref", ge)  # P2: explicit ref, no absolute-path lookup
		_wire_world(ge)  # P4: beast pool, hunt order, map, gear bonus
	# P17-Step2: title gates the run. Fresh boot (no save) starts at once
	# exactly like before; a present save shows the overlay and holds the
	# sim until New/Continue. Tests boot fresh unless they pre-write a save.
	_wire_buttons()
	_register_input_actions()
	_wire_advanced_options()
	_build_help()
	_apply_tooltips()
	_apply_modal_blur()
	_sync_mute(ge)
	_set_version_label()
	_apply_settings()
	_wire_uisound()
	var has_save: bool = false
	if get_node_or_null("/root/SaveManager") != null:
		has_save = FileAccess.file_exists("user://cultivation_nation_save.json")
	if has_save:
		ge.set("running", false)
		_show_title(true)
	else:
		_show_title(false)
		_log("New journey begins. Cultivating…")
		_log("P1 slice: auto-cultivate ON. Breakthrough when Qi fills.")
	_music_play("title" if has_save else "game")
	_refresh_sect()
	_refresh_map()
	_refresh_gear()
	_refresh_pills()
	_refresh_soul()
	_refresh_talents()
	_refresh_prestige()

func _set_version_label() -> void:
	# Display face loads at runtime (dynamic fonts need no editor import;
	# a tscn FontFile ext_resource fails headless without import metadata).
	var t: Label = get_node_or_null("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleLabel") as Label
	if t != null:
		var TH: GDScript = load("res://scripts/UITheme.gd")
		t.add_theme_font_override("font", TH.load_font(TH.FONT_DISPLAY))
		t.add_theme_font_size_override("font_size", TH.SIZE_TITLE)
	var v: Label = get_node_or_null("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/VersionLabel") as Label
	if v != null:
		v.text = "v" + str(ProjectSettings.get_setting("application/config/version", "?"))

func _show_title(on: bool) -> void:
	var t: Node = get_node_or_null("UI/TitleOverlay")
	if t != null:
		t.visible = on

func _on_title_new() -> void:
	## Fresh journey: sim already fresh, just lift the hold.
	_show_title(false)
	get_node("/root/GameEngine").set("running", true)
	_log("New journey begins. Cultivating…")
	_music_play("game")
	_sfx("click")

func _on_title_continue() -> void:
	## Returning exile: load, catch up offline, then lift the hold.
	var ge: Node = get_node("/root/GameEngine")
	if get_node_or_null("/root/SaveManager") != null:
		var sm: Node = get_node("/root/SaveManager")
		_wire_world(ge)
		var loaded: Dictionary = sm.call("load_game")
		_wire_world(ge)
		if not loaded.is_empty():
			_log("Save loaded (v%d)." % int(loaded.get("save_version", 0)))
			_apply_offline_gains(sm, int(loaded.get("saved_unix", 0)))
	_show_title(false)
	ge.set("running", true)
	_music_play("game")
	_sfx("click")

func _on_achievement(ach_id: String) -> void:
	# P17-Step2: log the human name (IDs were leaking into player text).
	var ui0: Node = get_node_or_null("UI")
	var nm: String = ach_id
	if ui0 != null:
		nm = str((ui0.get("ach_names") as Dictionary).get(ach_id, ach_id))
	_log("Achievement unlocked: %s." % nm)
	var ui: Node = get_node_or_null("UI")
	if ui != null and ui.has_method("toast"):
		ui.call("toast", "Achievement: %s" % str((ui.get("ach_names") as Dictionary).get(ach_id, ach_id)), "realm")
	_sfx("achievement")

func _on_reborn(life_number: int) -> void:
	_log("A new life begins (life %d)." % life_number)
	var ui2: Node = get_node_or_null("UI")
	if ui2 != null and ui2.has_method("toast"):
		ui2.call("toast", "Life %d begins" % life_number, "info")
	_music_play("game")
	_sfx("rebirth")

func _toast(msg: String, cat: String = "info") -> void:
	var ui: Node = get_node_or_null("UI")
	if ui != null and ui.has_method("toast"):
		ui.call("toast", msg, cat)

func _on_filter(f: String) -> void:
	var ui: Node = get_node_or_null("UI")
	if ui != null and ui.has_method("set_filter"):
		ui.call("set_filter", f)
	_sfx("click")

func _on_collapse_log() -> void:
	var t: Node = get_node_or_null("UI/Root/ChroniclePanel/ChronicleBox/LogText2")
	if t != null:
		t.visible = not t.visible
	_sfx("click")

func _fmt_away(seconds: int) -> String:
	var h: int = seconds / 3600
	var m: int = (seconds % 3600) / 60
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm" % maxi(m, 1)

func _apply_offline_gains(sm: Node, saved_unix: int) -> void:
	## P16-Step1: resolves away-time right after load, then tells the story.
	## Deaths already logged via the reborn listener above; the summary covers
	## the pool, the toll of years, and any vigil kept at death's door.
	var ge: Node = get_node("/root/GameEngine")
	var rep: Dictionary = sm.call("apply_offline", saved_unix)
	if bool(rep.get("skipped", true)):
		return
	_log("While you were away (%s): the dantian holds %s Qi." % [_fmt_away(int(rep.get("away_seconds", 0))), BN.format_hybrid(float(rep.get("qi", 0.0)))])
	if int(rep.get("deaths", 0)) > 0:
		_log("(%d lives lived and ended in seclusion.)" % int(rep.get("deaths", 0)))
	if bool(rep.get("vigil", false)):
		_log("You stood vigil at death's door; unspent moons went quiet.")
	# P19c: the welcome-back story also arrives as a report modal.
	var ui: Node = get_node_or_null("UI")
	if ui != null:
		var away_txt: String = _fmt_away(int(rep.get("away_seconds", 0)))
		var moons: int = int(rep.get("months", 0))
		var pool_txt: String = BN.format_hybrid(float(rep.get("qi", 0.0)))
		var lines := PackedStringArray(["Away %s; %d moons passed in seclusion." % [away_txt, moons], "The dantian holds %s Qi." % pool_txt])
		if int(rep.get("deaths", 0)) > 0:
			lines.append("%d lives lived and ended unseen." % int(rep.get("deaths", 0)))
		if bool(rep.get("vigil", false)):
			lines.append("Vigil kept at death's door; unspent moons went quiet.")
		MODAL.present(ui, MODAL.build_report("While You Were Away", lines))

const QUALITY_FLOAT := {"Radiant": Color(1.0, 0.85, 0.4), "Steady": Color(0.4, 0.9, 0.8), "Shaky": Color(1.0, 0.35, 0.3)}

func _float_quality(ge: Node) -> void:
	## P17-Step4: quality-colored number pops off the cultivator.
	var ui: Node = get_node_or_null("UI")
	var w: Node = get_node_or_null("WorldViewport/World")
	if ui == null or w == null:
		return
	if not ui.has_method("spawn_float") or not w.has_method("cultivator_screen"):
		return
	var q: String = str(ge.get("last_quality"))
	ui.call("spawn_float", w.call("cultivator_screen"), "Realm %d (%s)" % [int(ge.get("realm_index")), q], QUALITY_FLOAT.get(q, Color.WHITE))

func _check_backlash(ge: Node) -> void:
	if bool(ge.get("last_backlash")):
		_log("Backlash! Residue scars you (-2y). Purge first.", "warn")
		_toast("Backlash! Purge toxins first (-2y)", "warn")

func _sfx(sfx_name: String) -> void:
	if get_node_or_null("/root/SfxSynth") != null:
		get_node("/root/SfxSynth").call("play", sfx_name)

func _sync_mute(ge: Node) -> void:
	if get_node_or_null("/root/SfxSynth") != null:
		get_node("/root/SfxSynth").set("muted", bool(ge.get("muted")))
	# P21: engine mute also stills the Music bus (SFX mute is per-player).
	var mi: int = AudioServer.get_bus_index("Music")
	if mi >= 0:
		AudioServer.set_bus_mute(mi, bool(ge.get("muted")))

var _music_cache: Dictionary = {}
var _music_track: String = ""
var _music_wanted: String = ""

func _exit_tree() -> void:
	## P21: leave no live player behind for the vendor controller to clone
	## during teardown (its tree_exiting clone races scene exit and prints
	## engine errors). Stop + detach; the player node exits quietly after.
	var mc: Node = get_node_or_null("/root/MaaackMusic")
	if mc != null:
		mc.call("stop")
		mc.set("music_stream_player", null)
	_music_track = ""
	_music_wanted = ""
	_music_cache.clear()

func _music_stream(id: String) -> AudioStream:
	if _music_cache.has(id):
		return _music_cache[id]
	var path: String = str(TRACKS.get(id, ""))
	if path == "" or not FileAccess.file_exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_music_cache[id] = st
	return st

func _music_play(id: String) -> void:
	## P21: lofi direction requests a track; the _process pump starts it.
	## One frame of latency keeps startup/teardown races out (the vendor
	## controller clones exiting players, which errors during scene exit).
	_music_wanted = id

func _pump_music() -> void:
	if _music_wanted == "" or _music_wanted == _music_track or not is_inside_tree():
		return
	var mc: Node = get_node_or_null("/root/MaaackMusic")
	if mc == null:
		return
	var st: AudioStream = _music_stream(_music_wanted)
	if st == null:
		mc.call("stop")
		_music_track = ""
		_music_wanted = ""
		return
	_music_track = _music_wanted
	mc.set("fade_in_duration", 2.0)
	mc.set("fade_out_duration", 2.0)
	mc.call("play_stream", st)

func _wire_uisound() -> void:
	## P21: hover/focus whispers from our procedural stream through the
	## Maaack UI-sound controller. Pressed stays empty ON PURPOSE — clicks
	## already travel the explicit _sfx path, and auto-attach would double.
	var ctl: Node = get_node_or_null("/root/MaaackUISound")
	var sfx: Node = get_node_or_null("/root/SfxSynth")
	if ctl == null or sfx == null:
		return
	var hover: AudioStream = sfx.call("ui_stream", "hover")
	if hover != null:
		ctl.set("button_hovered", hover)
		ctl.set("button_focused", hover)
		ctl.set("slider_hovered", hover)

func _apply_settings() -> void:
	## P21: persisted settings (Maaack player_config, user://player_config.cfg).
	## Volume mirrors into the live slider; glow into the world; music bus
	## into decibels. Missing file → defaults, never errors.
	var sfx: Node = get_node_or_null("/root/SfxSynth")
	var vol: float = float(PlayerConfig.get_config(SETTINGS_SECTION, "sfx_volume", 1.0))
	if sfx != null:
		sfx.set("volume", clampf(vol, 0.0, 1.0))
	var mvol: float = float(PlayerConfig.get_config(SETTINGS_SECTION, "music_volume", 0.8))
	_set_music_db(mvol)
	var ms: HSlider = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/MusicSlider") as HSlider
	if ms != null:
		ms.value = clampf(mvol, 0.0, 1.0) * 100.0
	var vs: HSlider = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/VolumeSlider") as HSlider
	if vs != null:
		vs.value = clampf(vol, 0.0, 1.0) * 100.0
	var glow_on: bool = bool(PlayerConfig.get_config(SETTINGS_SECTION, "glow", true))
	var w: Node = get_node_or_null("WorldViewport/World")
	if w != null and w.has_method("set_glow"):
		w.call("set_glow", glow_on)
	var gc: CheckBox = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/GlowCheck") as CheckBox
	if gc != null:
		gc.button_pressed = glow_on
	var skin: String = str(PlayerConfig.get_config(SETTINGS_SECTION, "skin", "ink"))
	var ui2: Node = get_node_or_null("UI")
	if ui2 != null and ui2.has_method("set_skin"):
		ui2.call("set_skin", skin)
	var sk: Button = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SkinBtn") as Button
	if sk != null:
		sk.text = "Skin: %s" % ("Parchment" if skin == "parchment" else "Ink")

func _set_music_db(v: float) -> void:
	var mi: int = AudioServer.get_bus_index("Music")
	if mi >= 0:
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(clampf(v, 0.0, 1.0), 0.0001)))

func _save_settings() -> void:
	var sfx: Node = get_node_or_null("/root/SfxSynth")
	if sfx != null:
		PlayerConfig.set_config(SETTINGS_SECTION, "sfx_volume", float(sfx.get("volume")))
	var ms: HSlider = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/MusicSlider") as HSlider
	if ms != null:
		PlayerConfig.set_config(SETTINGS_SECTION, "music_volume", clampf(float(ms.value) / 100.0, 0.0, 1.0))

func _on_skin() -> void:
	## P21: ink/parchment cycle (Kenney variant architecture, our tokens).
	var ui: Node = get_node_or_null("UI")
	if ui == null or not ui.has_method("set_skin"):
		return
	var next: String = "parchment" if ui.call("get_skin") == "ink" else "ink"
	ui.call("set_skin", next)
	PlayerConfig.set_config(SETTINGS_SECTION, "skin", next)
	var b: Button = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SkinBtn") as Button
	if b != null:
		b.text = "Skin: %s" % next.capitalize()
	_sfx("click")

func _wire_buttons() -> void:
	# P17-Step2: dock rows + top bar. Names stable; only parent prefixes moved.
	var dock1: String = "UI/Root/BottomDock/DockRows/DockRow1/"
	_connect_btn(dock1 + "FocusCultivate", _on_focus.bind("cultivate"))
	_connect_btn(dock1 + "FocusTrain", _on_focus.bind("train"))
	_connect_btn(dock1 + "FocusHunt", _on_focus.bind("hunt"))
	_connect_btn(dock1 + "BreakthroughBtn", _on_manual_breakthrough)
	var dock2: String = "UI/Root/BottomDock/DockRows/DockRow2/"
	_connect_btn(dock2 + "RecruitBtn", _on_recruit)
	_connect_btn(dock2 + "GangGather", _on_gang.bind("gather"))
	_connect_btn(dock2 + "GangHunt", _on_gang.bind("hunt"))
	_connect_btn(dock2 + "GangIdle", _on_gang.bind("idle"))
	var top: String = "UI/Root/TopBar/TopBarBox/"
	_connect_btn(top + "Time1", _on_time.bind(1.0))
	_connect_btn(top + "Time10", _on_time.bind(10.0))
	_connect_btn(top + "Time100", _on_time.bind(100.0))
	_connect_btn(top + "Time1000", _on_time.bind(1000.0))
	_connect_btn(top + "PauseBtn", _on_pause_btn)
	_connect_btn(top + "MuteBtn", _on_mute)
	_connect_btn(top + "PanelsBtn", _on_panels_toggle)
	var tabs: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs")
	if tabs != null and tabs.has_signal("tab_changed") and not (tabs as TabContainer).tab_changed.is_connected(_on_tab_changed):
		(tabs as TabContainer).tab_changed.connect(_on_tab_changed)
	_connect_btn("UI/Root/ChroniclePanel/ChronicleBox/FilterBox/FilterAllBtn", _on_filter.bind("all"))
	_connect_btn("UI/Root/ChroniclePanel/ChronicleBox/FilterBox/FilterInfoBtn", _on_filter.bind("info"))
	_connect_btn("UI/Root/ChroniclePanel/ChronicleBox/FilterBox/FilterWarnBtn", _on_filter.bind("warn"))
	_connect_btn("UI/Root/ChroniclePanel/ChronicleBox/FilterBox/CollapseBtn", _on_collapse_log)
	_connect_btn("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleNewBtn", _on_title_new)
	_connect_btn("UI/TitleOverlay/TitleCenter/TitleCard/TitleBox/TitleContinueBtn", _on_title_continue)
	_connect_btn("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/ExportBtn", _on_export)
	_connect_btn("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/ImportBtn", _on_import_show)
	var vol: HSlider = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/VolumeSlider") as HSlider
	if vol != null and not vol.value_changed.is_connected(_on_volume):
		vol.value_changed.connect(_on_volume)
		var sfx0: Node = get_node_or_null("/root/SfxSynth")
		if sfx0 != null:
			vol.value = float(sfx0.get("volume")) * 100.0
	var mus: HSlider = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/MusicSlider") as HSlider
	if mus != null and not mus.value_changed.is_connected(_on_music_volume):
		mus.value_changed.connect(_on_music_volume)
	var glow: CheckBox = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/GlowCheck") as CheckBox
	if glow != null and not glow.toggled.is_connected(_on_glow):
		glow.toggled.connect(_on_glow)
	var dlg: FileDialog = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SaveDialog") as FileDialog
	if dlg != null and not dlg.file_selected.is_connected(_on_import_file):
		dlg.file_selected.connect(_on_import_file)
	# P17-Step3: tab homes. Names stable; only parent prefixes moved.
	var sam: String = "UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/"
	_connect_btn(sam + "EndLifeBtn", _on_rebirth_btn)
	_connect_btn(sam + "AscendBtn", _on_ascend)
	_connect_btn(sam + "OrgWayfarer", _on_origin.bind("origin_wayfarer"))
	_connect_btn(sam + "OrgIronhide", _on_origin.bind("origin_ironhide"))
	_connect_btn(sam + "OrgCinder", _on_origin.bind("origin_cinder"))
	_connect_btn(sam + "OrgBeastkin", _on_origin.bind("origin_beastkin"))
	var arts: String = "UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/"
	_connect_btn(arts + "TechStillwater", _on_focus_tech.bind("tech_stillwater"))
	_connect_btn(arts + "TechEmberstep", _on_focus_tech.bind("tech_emberstep"))
	_connect_btn(arts + "TechRootgrip", _on_focus_tech.bind("tech_rootgrip"))
	_connect_btn(arts + "TechMistwalk", _on_focus_tech.bind("tech_mistwalk"))
	_connect_btn(arts + "TechStonebell", _on_focus_tech.bind("tech_stonebell"))
	_connect_btn("UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/SectGrid/FoundBtn", _on_found)
	_connect_btn("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SeclusionBtn", _on_seclusion)
	_connect_btn("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SkinBtn", _on_skin)
	_connect_btn("UI/Root/BottomDock/DockRows/DockRow1/StalkBtn", _on_stalk)
	_connect_btn("UI/Root/BottomDock/DockRows/DockRow1/WanderBtn", _on_wander)
	_connect_btn("UI/Root/TopBar/TopBarBox/BulkBtn", _on_bulk)
	_connect_btn("UI/Root/CoachPanel/CoachBox/CoachDismissBtn", _on_coach_dismiss)
	_wire_rail()

# P21: rebindable actions (Maaack input options edit these live; the
# player_config section persists them). Defaults mirror the legacy keys,
# and handle_shortcut(keycode) stays as the test/stable path.
# P24: 13 -> 19 actions. WASD movement needs W unambiguous, so the legacy
# cult_wander default moves W -> V (rule-11: p11 shortcut + help/hint text
# move with it; rebind-replacement semantics mean existing player configs
# keep their stored keys). World actions below.
const INPUT_DEFAULTS := {
	"cult_breathe": [KEY_1], "cult_drill": [KEY_2], "cult_stalk": [KEY_3],
	"cult_tribulation": [KEY_T], "cult_speed1": [KEY_7], "cult_speed10": [KEY_8],
	"cult_speed100": [KEY_9], "cult_speed1000": [KEY_0], "cult_pause": [KEY_SPACE],
	"cult_hunt": [KEY_H], "cult_wander": [KEY_V], "cult_mute": [KEY_M],
	"cult_help": [KEY_F1],
	"world_move_forward": [KEY_W], "world_move_back": [KEY_S],
	"world_move_left": [KEY_A], "world_move_right": [KEY_D],
	"world_interact": [KEY_E], "world_toggle_flight": [KEY_F],
}

func _register_input_actions() -> void:
	for action in INPUT_DEFAULTS:
		if not InputMap.has_action(str(action)):
			InputMap.add_action(str(action))
		var saved: Array = AppSettings.get_config_input_events(str(action), [])
		InputMap.action_erase_events(str(action))
		var events: Array = []
		if not saved.is_empty():
			events = saved
		else:
			for key in (INPUT_DEFAULTS[action] as Array):
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				events.append(ev)
		for ev in events:
			if ev is InputEvent:
				InputMap.action_add_event(str(action), ev)
	_seed_input_defaults()

func _seed_input_defaults() -> void:
	## QA Round 2: the vendor options list resets with
	## AppSettings.reset_to_default_inputs(), which only restores actions
	## present in its default_action_events snapshot. We register our own
	## actions instead of going through AppSettings.set_from_config(), so
	## that snapshot was empty — the Reset button erased the config but
	## left the live rebinds in place (probed: still [B] after reset).
	## Seeding it here makes Reset restore our documented defaults.
	AppSettings.default_action_events.clear()
	for action in INPUT_DEFAULTS:
		var defaults: Array[InputEvent] = []
		for key in (INPUT_DEFAULTS[action] as Array):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			defaults.append(ev)
		AppSettings.default_action_events[StringName(str(action))] = defaults

func _wire_advanced_options() -> void:
	## P21: Maaack input/video options live here on real displays only.
	## Their list builders query the display server for key names, which
	## headless lacks — static instances would error every test boot, so
	## they are built in code behind a display guard. Actions themselves
	## (above) register everywhere; only the vendor UI is gated.
	if DisplayServer.get_name() == "headless":
		return
	var pairs: Array = [
		["UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/InputOptionsBox", "res://addons/maaacks_game_template/base/nodes/menus/options_menu/input/input_options_menu.tscn"],
		["UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/VideoOptionsBox", "res://addons/maaacks_game_template/base/nodes/menus/options_menu/video/video_options_menu.tscn"],
	]
	for pair in pairs:
		var box: Node = get_node_or_null(str(pair[0]))
		if box == null or box.get_child_count() > 0:
			continue
		var packed: PackedScene = load(str(pair[1]))
		if packed != null and packed.can_instantiate():
			var inst: Node = packed.instantiate()
			box.add_child(inst)
			# QA Round 1: the vendor action list only shows its configured
			# input_action_names (empty by default). Ours register at boot,
			# so show-all carries them; the deferred build picks this up
			# same-frame, before its first flush.
			_show_all_actions(inst)
			# QA Round 1: the rebinding ScrollContainer needs claimed
			# height or the VBox squeezes its built rows to zero —
			# invisible despite a full ParentBoxContainer.
			_give_list_height(inst)

func _give_list_height(root_box: Node) -> void:
	var stack: Array = [root_box]
	# P24: the rebind list grows with the action count — claim ~24px per
	# action row (Round 1 defect #5 guard: rows squeeze to zero without it).
	var want_y: float = maxf(320.0, 24.0 * float(INPUT_DEFAULTS.size()))
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name) == "InputActionsList" and n is ScrollContainer:
			(n as ScrollContainer).custom_minimum_size = Vector2(0, want_y)
			(n as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
		for c in n.get_children():
			stack.append(c)

func _show_all_actions(root_box: Node) -> void:
	var stack: Array = [root_box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.get_script() != null and str((n.get_script() as Script).resource_path).ends_with("input_actions_list.gd"):
			n.set("show_all_actions", true)
		for c in n.get_children():
			stack.append(c)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# QA Round 2: the bound action IS the truth here — no legacy
		# keycode fallback. The fallback made rebinding additive-only: a
		# released key still fired through handle_shortcut(), so the old
		# binding could never be removed (probed: cult_breathe rebound to
		# B still fired on 1). handle_shortcut() stays the stable
		# test/automation path, and Escape is the one key with no action.
		if event.is_action_pressed("cult_breathe"):
			_on_focus("cultivate")
		elif event.is_action_pressed("cult_drill"):
			_on_focus("train")
		elif event.is_action_pressed("cult_stalk"):
			_on_focus("hunt")
		elif event.is_action_pressed("cult_tribulation"):
			_on_manual_breakthrough()
		elif event.is_action_pressed("cult_speed1"):
			_on_time(1.0)
		elif event.is_action_pressed("cult_speed10"):
			_on_time(10.0)
		elif event.is_action_pressed("cult_speed100"):
			_on_time(100.0)
		elif event.is_action_pressed("cult_speed1000"):
			_on_time(1000.0)
		elif event.is_action_pressed("cult_pause"):
			_on_pause_btn()
		elif event.is_action_pressed("cult_hunt"):
			_on_stalk()
		elif event.is_action_pressed("cult_wander"):
			_on_wander()
		elif event.is_action_pressed("cult_mute"):
			_on_mute()
		elif event.is_action_pressed("cult_help"):
			_on_help()
		elif event.is_action_pressed("world_toggle_flight"):
			_on_flight()
		elif (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			handle_shortcut(KEY_ESCAPE)

func _on_flight() -> void:
	## P24b: sword-flight toggle. Refused warded-style before the unlock
	## milestone (data-driven via flight.json, Q31); the unlock line names
	## the way, mirroring guardian-gate refusals.
	var ge: Node = get_node("/root/GameEngine")
	var world: Node = get_node_or_null("WorldViewport/World")
	if world == null:
		return
	if not bool(ge.call("flight_unlocked")):
		_log("The sky is not yours yet — %s" % str(ge.call("flight_unlock_line")), "warn")
		_sfx("fail")
		return
	var flying: bool = str(world.call("avatar_state")) != "fly"
	world.call("set_avatar_flying", flying)
	if flying:
		_log("Sword-mount risen. The winds answer.")
		_toast("Sword-flight", "realm")
		_sfx("breakthrough")
	else:
		_log("Feet on the ground again.")
	_sfx("click")

func handle_shortcut(key: int) -> bool:
	## Keyboard play. Every action routes to an existing button handler.
	match key:
		KEY_1:
			_on_focus("cultivate")
		KEY_2:
			_on_focus("train")
		KEY_3:
			_on_focus("hunt")
		KEY_T:
			_on_manual_breakthrough()
		KEY_7:
			_on_time(1.0)
		KEY_8:
			_on_time(10.0)
		KEY_9:
			_on_time(100.0)
		KEY_0:
			_on_time(1000.0)
		KEY_SPACE:
			_on_pause_btn()
		KEY_H:
			_on_stalk()
		KEY_V:
			_on_wander()
		KEY_M:
			_on_mute()
		KEY_F1:
			_on_help()
		KEY_ESCAPE:
			var h: Node = get_node_or_null("UI/HelpOverlay")
			if h != null and h.visible:
				h.visible = false
				return true
			var p: Node = get_node_or_null("UI/Root/SidePanel")
			if p != null and p.visible:
				p.visible = false
				var rail: Node = get_node_or_null("UI/Root/RailPanel")
				if rail != null:
					rail.visible = false
				return true
			return false
		_:
			return false
	return true

func _connect_btn(path: String, handler: Callable) -> void:
	var b: Node = get_node_or_null(path)
	if b != null and b is BaseButton and not (b as BaseButton).pressed.is_connected(handler):
		(b as BaseButton).pressed.connect(handler)

func _on_focus(mode: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("set_focus", mode)):
		_log("Focus: %s." % mode)
		_sfx("click")

func _on_manual_breakthrough() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var need: float = _trib_need(ge)
	var bonus: float = float(ge.call("best_technique_bonus"))
	# P22: wardens bar tier crossings until defeated — name the way out.
	var gate0: Dictionary = ge.call("guardian_gate")
	if bool(gate0.get("blocked", false)):
		_log("The %s bars this crossing — defeat it first (Beasts tab)." % str(gate0.get("name", "warden")), "warn")
		_sfx("fail")
		return
	# P13-B1: doomed attempts are refused cost-free, with the way out named.
	if not bool(ge.call("is_ready", _auto_breakthrough_power, need, bonus)):
		_log("Too weak for the tribulation (readiness %d%%) — drill a technique first." % int(ge.call("readiness_pct", _auto_breakthrough_power, need, bonus)), "warn")
		_sfx("fail")
		return
	var ok: bool = bool(ge.call("attempt_breakthrough", _auto_breakthrough_power, need, bonus))
	if ok:
		_log("Breakthrough! Entered realm %d (%s)." % [int(ge.get("realm_index")), str(ge.get("last_quality"))])
		_toast("Breakthrough! Realm %d (%s)" % [int(ge.get("realm_index")), str(ge.get("last_quality"))], "realm")
		_float_quality(ge)
		_sfx("breakthrough")
		var ui_fx: Node = get_node_or_null("UI")
		if ui_fx != null and ui_fx.has_method("play_breakthrough_fx"):
			ui_fx.call("play_breakthrough_fx")
		_check_backlash(ge)
		_maybe_celebrate()
	else:
		_log("Tribulation unready or failed (readiness %d%%)." % int(ge.call("readiness_pct", _auto_breakthrough_power, need, bonus)), "warn")
		_sfx("fail")

func _on_time(s: float) -> void:
	var ge: Node = get_node("/root/GameEngine")
	ge.call("set_time_scale", s)
	_log("Speed %.0fx." % s)
	_sfx("click")

func _on_pause_btn() -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.get("running")):
		ge.set("running", false)
		_log("Paused.")
	else:
		ge.call("resume")
		_log("Resumed.")
	_sfx("click")

func _on_recruit() -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("recruit_disciple")):
		_log("A disciple joins (%d)." % (ge.get("disciples") as Array).size())
		_sfx("click")
	else:
		_log("Cannot recruit yet (need Qi / room).")
		_sfx("fail")
	_refresh_sect()

func _on_gang(task: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("assign_all", task)):
		_log("Gang assigned: %s." % task)
		_sfx("click")
	_refresh_sect()

func _on_origin(id: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb == null:
		return
	var o: Dictionary = cdb.call("origin_by_id", id)
	if o.is_empty():
		return
	if bool(ge.call("choose_origin", id, float(o.get("qi_mult", 1.0)), int(o.get("lifespan_bonus", 0)))):
		_log("Born anew as %s." % str(o.get("name", id)))
		_sfx("click")
	else:
		_log("Origin already set for this life.")
		_sfx("fail")

func _on_rebirth_btn() -> void:
	## P13-B5: voluntary reincarnation — cash in karma now or push deeper.
	## Karma rewards depth quadratically, so the timing is a real decision.
	var ge: Node = get_node("/root/GameEngine")
	var before: int = int(ge.get("life_number"))
	ge.call("rebirth")
	if int(ge.get("life_number")) == before + 1:
		_log("This life is laid down willingly (life %d)." % int(ge.get("life_number")))
		_sfx("rebirth")
		_refresh_pills()
		_refresh_soul()
		_refresh_talents()
	_refresh_prestige()

func _on_seclusion() -> void:
	## P16-Step1: cycle the offline mortality directive. Text shows state;
	## P17 relocates this into the settings panel.
	var ge: Node = get_node("/root/GameEngine")
	var cur: String = str(ge.get("offline_mortality"))
	var nxt: String = "unfettered" if cur == "vigil" else "vigil"
	if bool(ge.call("set_offline_mortality", nxt)):
		_log("Seclusion directive: %s." % ("die and be reborn unseen" if nxt == "unfettered" else "stand vigil at death's door"))
		_sfx("click")
	var b: Button = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SeclusionBtn") as Button
	if b != null:
		b.text = "Seclusion: %s" % ("Unfettered" if str(ge.get("offline_mortality")) == "unfettered" else "Vigil")

func _on_focus_tech(id: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	ge.set("focus_technique", id)
	_log("Drill focus: %s." % id)
	_sfx("click")

const SECT_A: Array = ["Pale", "Quiet", "Ember"]
const SECT_B: Array = ["Lantern", "Root", "Brook"]
const SECT_C: Array = ["Society", "Compact", "Circle"]
const DUTIES: Array = ["idle", "gather", "hunt", "train"]

func _sect_name() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s %s %s" % [SECT_A[rng.randi_range(0, 2)], SECT_B[rng.randi_range(0, 2)], SECT_C[rng.randi_range(0, 2)]]

func _on_found() -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("found_sect", _sect_name())):
		_log("Sect founded: %s." % str((ge.get("sect") as Dictionary).get("name", "")))
		_sfx("click")
	else:
		_log("A sect already stands.")
		_sfx("fail")
	_refresh_sect()

func _refresh_sect() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var sect_label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/SectLabel")
	var roster: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/RosterLabel")
	var sect: Dictionary = ge.get("sect")
	if sect_label != null:
		sect_label.text = "No sect founded." if sect.is_empty() else "Sect: %s." % str(sect.get("name", ""))
	var discs: Array = ge.get("disciples")
	if roster != null:
		if discs.is_empty():
			roster.text = "No disciples."
		else:
			var parts: PackedStringArray = []
			for i in range(discs.size()):
				parts.append("D%d:%s" % [i, str((discs[i] as Dictionary).get("task", "idle"))])
			roster.text = " ".join(parts)
	call_deferred("_rebuild_duties")

func _rebuild_duties() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Sect/DiscipleBox")
	if ge == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var discs: Array = ge.get("disciples")
	for i in range(discs.size()):
		var b := Button.new()
		b.name = "Disciple%d" % i
		b.text = "D%d duty: %s" % [i, str((discs[i] as Dictionary).get("task", "idle"))]
		b.pressed.connect(_on_cycle_duty.bind(i))
		box.add_child(b)

func _on_cycle_duty(i: int) -> void:
	var ge: Node = get_node("/root/GameEngine")
	var discs: Array = ge.get("disciples")
	if i < 0 or i >= discs.size():
		return
	var cur: String = str((discs[i] as Dictionary).get("task", "idle"))
	var nxt: String = DUTIES[(DUTIES.find(cur) + 1) % DUTIES.size()]
	if bool(ge.call("assign_disciple", i, nxt)):
		_log("D%d now: %s." % [i, nxt])
		_sfx("click")
	_refresh_sect()

func _refresh_map() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapLabel")
	if label != null:
		var cur: String = str(ge.get("current_node"))
		label.text = "Wilderness: no chart." if (ge.get("map_nodes") as Array).is_empty() else ("Grounds: %s." % ("unwalked" if cur == "" else cur))
	call_deferred("_rebuild_map")

func _rebuild_map() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/MapBox")
	if ge == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var names: Dictionary = {}
	var elements: Dictionary = {}
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb != null:
		for bdef in (cdb.get("beasts") as Array):
			names[str((bdef as Dictionary).get("id", ""))] = str((bdef as Dictionary).get("name", ""))
			elements[str((bdef as Dictionary).get("id", ""))] = str((bdef as Dictionary).get("element", ""))
	var nodes: Array = ge.get("map_nodes")
	for i in range(nodes.size()):
		var n: Dictionary = nodes[i]
		var gate: int = int(ge.call("zone_gate", str(n.get("beast_id", ""))))
		var locked: bool = int(ge.get("realm_index")) < gate
		var b := Button.new()
		b.name = "Node%d" % i
		if locked:
			b.text = "%s - locked (realm %d)" % [str(n.get("zone", "")), gate]
		else:
			# P15-Step5: repeat journeys show their toll; first walks are free.
			var toll: float = float(ge.call("travel_toll", str(n.get("id", ""))))
			var fare: String = "" if toll <= 0.0 else ", %s Qi" % BN.format_hybrid(toll)
			b.text = "%s - %s (x%1.1f%s)" % [str(n.get("zone", "")), str(names.get(str(n.get("beast_id", "")), "?")), float(n.get("yield_mult", 1.0)), fare]
			b.tooltip_text = "%s grounds, %s Qi. First walks are free; repeat journeys cost 5%% of bottleneck." % [str(n.get("zone", "")), str(elements.get(str(n.get("beast_id", "")), "?"))]
		b.pressed.connect(_on_travel.bind(str(n.get("id", ""))))
		box.add_child(b)

func _on_travel(id: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("travel_to", id)):
		_log("Walked to %s." % id)
		_sfx("click")
	else:
		var n: Dictionary = ge.call("node_by_id", id)
		if n.is_empty():
			_log("Cannot reach %s." % id)
		elif int(ge.get("realm_index")) < int(ge.call("zone_gate", str(n.get("beast_id", "")))):
			_log("%s wants realm %d." % [str(n.get("zone", "")), int(ge.call("zone_gate", str(n.get("beast_id", ""))))])
		else:
			_log("The road to %s demands %s Qi." % [str(n.get("zone", "")), BN.format_hybrid(float(ge.call("travel_toll", id)))], "warn")
		_sfx("fail")
	_refresh_map()

func _on_wander() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var dest: String = str(ge.call("wander"))
	if dest == "":
		_log("No walkable grounds. Earn standing.")
		_sfx("fail")
	else:
		_log("Wandered to %s." % dest)
		_sfx("click")
	_refresh_map()

func _on_stalk() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var cur: String = str(ge.get("current_node"))
	if cur == "":
		_log("Walk somewhere first.")
		_sfx("fail")
		return
	var got: int = int(ge.call("hunt_at", cur, 5))
	_log("Stalked %s: %d signs." % [cur, got])
	var n: Dictionary = ge.call("node_by_id", cur)
	if float(ge.call("hunt_yield_mult", str(n.get("beast_id", "")))) < 1.0:
		_log("Outmatched on those grounds - signs halved. Drill first.", "warn")
	_sfx("click")

func _refresh_gear() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/GearLabel")
	var levels: Dictionary = ge.get("gear")
	if label != null:
		var total: int = 0
		for k in levels:
			total += int(levels[k])
		label.text = "Forge: unworked kit." if total == 0 else "Forge: %d refinements." % total
	call_deferred("_rebuild_gear")

func _rebuild_gear() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var cdb: Node = get_node_or_null("/root/ContentDB")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/GearBox")
	if ge == null or cdb == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var levels: Dictionary = ge.get("gear")
	for g in (cdb.get("gear") as Array):
		var id: String = str((g as Dictionary).get("id", ""))
		var lv: int = int(levels.get(id, 0))
		var mx: int = int((g as Dictionary).get("max_level", 0))
		# P15-Step2: refining never caps (radiant overflow); perfected is a
		# threshold tag, not a ceiling. Bequeathable from mx upward.
		var tag: String = " (perfected)" if (lv >= mx and mx > 0) else ""
		var cost: float = float(ge.call("refine_cost", lv))
		var row: VBoxContainer = ROW.build_row("RowGear_%s" % id, "%s — Lv%d%s" % [str((g as Dictionary).get("name", id)), lv, tag], "Refine %s %d>%d (%s Qi)%s" % [str((g as Dictionary).get("name", id)), lv, lv + 1, BN.format_hybrid(cost), ROW.bulk_suffix(_bulk_qty)], "%s Each level +%.0f%% Qi rate, no ceiling." % [str((g as Dictionary).get("desc", "")), float((g as Dictionary).get("base_mult", 0.0)) * 100.0], ge.call("qi_num") >= cost)
		var gbtn: Button = row.get_node("BuyBtn") as Button
		gbtn.name = "Gear_%s" % id
		gbtn.pressed.connect(_on_refine.bind(id, mx))
		gbtn.pressed.connect(_juice_btn.bind(gbtn))
		box.add_child(row)
		if lv >= mx and mx > 0:
			var qb := Button.new()
			qb.name = "Bequeath_%s" % id
			qb.text = "Bequeath %s (Lv%d → +2%% legacy)" % [str((g as Dictionary).get("name", id)), lv]
			qb.tooltip_text = "Sacrifice this perfected relic for permanent +0.02 legacy Qi across all future lives."
			qb.pressed.connect(_on_bequeath.bind(id, mx))
			box.add_child(qb)

func _on_refine(id: String, mx: int) -> void:
	var ge: Node = get_node("/root/GameEngine")
	var got: int = int(ge.call("buy_bulk", "gear", id, _bulk_qty, mx))
	if got > 0:
		var cdb: Node = get_node("/root/ContentDB")
		ge.call("set_gear_mult", ge.call("gear_bonus_for", ge.get("gear"), cdb.call("gear_defs")))
		_log("Refined %s ×%d (now %d)." % [id, got, int((ge.get("gear") as Dictionary).get(id, 0))])
		if got > 1:
			_toast("Refined %s ×%d" % [id, got], "info")
		_sfx("click")
	else:
		_log("Refining %s needs more Qi." % id)
		_sfx("fail")
	_refresh_gear()

# P13-B5: pill shelf signature — rebuild only when stock actually moved
# (trickle/forage accrue passively; blind 4Hz rebuilds would churn buttons).
var _pill_sig: String = ""

func _refresh_pills_if_stale() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var sig: String = "%d|%s|%d" % [int(float(ge.get("herbs"))), str((ge.get("pills") as Dictionary)), int(float(ge.get("toxicity")))]
	if sig != _pill_sig:
		_pill_sig = sig
		_refresh_pills()

func _refresh_pills() -> void:
	var ge: Node = get_node("/root/GameEngine")
	_pill_sig = "%d|%s|%d" % [int(float(ge.get("herbs"))), str((ge.get("pills") as Dictionary)), int(float(ge.get("toxicity")))]
	var label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Alchemy/PillLabel")
	if label != null:
		var held: PackedStringArray = []
		for pid in (ge.get("pills") as Dictionary):
			held.append("%s x%d" % [str(pid), int((ge.get("pills") as Dictionary).get(pid, 0))])
		var stock: String = "empty shelf" if held.is_empty() else ", ".join(held)
		label.text = "Cauldron: %d herbs, toxicity %d, %s." % [int(float(ge.get("herbs"))), int(float(ge.get("toxicity"))), stock]
	call_deferred("_rebuild_pills")

func _rebuild_pills() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Alchemy/PillBox")
	if ge == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for p in ge.call("pill_defs"):
		var pid: String = str((p as Dictionary).get("id", ""))
		var pcost: int = int(float((p as Dictionary).get("cost", 0.0)))
		var prow: VBoxContainer = ROW.build_row("RowBrew_%s" % pid, "%s" % str((p as Dictionary).get("name", pid)), "Brew %s (%d herbs)%s" % [str((p as Dictionary).get("name", pid)), pcost, ROW.bulk_suffix(_bulk_qty)], "%s Costs %d herbs. Instant brew." % [str(PILL_TIPS.get(pid, "")), pcost], float(ge.get("herbs")) >= float(pcost))
		var brewbtn: Button = prow.get_node("BuyBtn") as Button
		brewbtn.name = "Brew_%s" % pid
		brewbtn.pressed.connect(_on_brew.bind(pid))
		brewbtn.pressed.connect(_juice_btn.bind(brewbtn))
		box.add_child(prow)
		var held: int = int((ge.get("pills") as Dictionary).get(pid, 0))
		if held > 0:
			var db := Button.new()
			db.name = "Drink_%s" % pid
			db.text = "Quaff %s (x%d)" % [str((p as Dictionary).get("name", pid)), held]
			db.tooltip_text = "%s Every draught leaves +12 toxicity." % str(PILL_TIPS.get(pid, ""))
			db.pressed.connect(_on_drink.bind(pid))
			box.add_child(db)

func _on_bulk() -> void:
	## P19c: global bulk quantity cycles x1 → x10 → MAX for every
	## repeatable shop. Rows rebuild to show the active suffix.
	if _bulk_qty == 1:
		_bulk_qty = 10
	elif _bulk_qty == 10:
		_bulk_qty = -1
	else:
		_bulk_qty = 1
	var b: Button = get_node_or_null("UI/Root/TopBar/TopBarBox/BulkBtn") as Button
	if b != null:
		b.text = "Buy %s" % ("xMAX" if _bulk_qty < 0 else "x%d" % _bulk_qty)
	_sfx("click")
	_refresh_gear()
	_refresh_pills()
	_refresh_talents()
	_refresh_prestige()

func _on_brew(id: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	var got: int = int(ge.call("buy_bulk", "pill", id, _bulk_qty))
	if got > 0:
		_log("Brewed %s ×%d." % [id, got])
		if got > 1:
			_toast("Brewed %s ×%d" % [id, got], "info")
		_sfx("click")
	else:
		_log("Not enough herbs for %s." % id)
		_sfx("fail")
	_refresh_pills()

func _on_drink(id: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("drink_pill", id)):
		_log("Quaffed %s (toxicity rises)." % id)
		_sfx("click")
	else:
		_log("No %s on the shelf." % id)
		_sfx("fail")
	_refresh_pills()

func _refresh_soul() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/SoulLabel")
	if label != null:
		label.text = "Soul: %s." % str(ge.call("soul_display"))
	call_deferred("_rebuild_souls")

func _rebuild_souls() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Soul/SoulBox")
	if ge == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	if not (ge.get("soulweapon") as Dictionary).is_empty():
		return
	for p in ge.call("soul_paths"):
		var pid: String = str((p as Dictionary).get("id", ""))
		var b := Button.new()
		b.name = "Soul_%s" % pid
		b.text = "Bind %s" % str((p as Dictionary).get("name", pid))
		b.tooltip_text = "One soul, one path, forever. %s" % str(SOUL_TIPS.get(pid, ""))
		b.pressed.connect(_on_soul_choose.bind(pid))
		box.add_child(b)
		_set_shine(b, true)

func _on_soul_choose(pid: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("choose_soul_weapon", pid)):
		_log("Soul-bound: %s." % pid)
		_sfx("breakthrough")
	else:
		_log("One soul, one path already.")
		_sfx("fail")
	_refresh_soul()

func _refresh_talents() -> void:
	var ge: Node = get_node("/root/GameEngine")
	var label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/KarmaLabel")
	if label != null:
		label.text = "Samsara: %d karma, legacy x%1.2f." % [int(ge.get("karma")), float(ge.get("legacy_mult"))]
	call_deferred("_rebuild_talents")

func _rebuild_talents() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/TalentBox")
	if ge == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var karma: int = int(ge.get("karma"))
	for t in ge.call("talent_rows"):
		var tid: String = str((t as Dictionary).get("id", ""))
		var cost: int = int((t as Dictionary).get("cost", -1))
		var trow: VBoxContainer = ROW.build_row("RowTalent_%s" % tid, "%s — rank %d" % [str((t as Dictionary).get("name", tid)), int((t as Dictionary).get("level", 0))], "Rank %d>%d (%d karma)%s" % [int((t as Dictionary).get("level", 0)), int((t as Dictionary).get("level", 0)) + 1, maxi(cost, 0), ROW.bulk_suffix(_bulk_qty)], "%s Ranks never cap; costs grow quadratically." % str(TALENT_TIPS.get(tid, "")), cost >= 0 and karma >= cost)
		var tbtn: Button = trow.get_node("BuyBtn") as Button
		tbtn.name = "Talent_%s" % tid
		tbtn.pressed.connect(_on_talent.bind(tid))
		tbtn.pressed.connect(_juice_btn.bind(tbtn))
		box.add_child(trow)

func _on_talent(tid: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	var got: int = int(ge.call("buy_bulk", "talent", tid, _bulk_qty))
	if got > 0:
		_log("Talent deepened: %s ×%d." % [tid, got])
		if got > 1:
			_toast("Talent %s ×%d" % [tid, got], "info")
		_sfx("click")
	else:
		_log("Not enough karma for %s." % tid)
		_sfx("fail")
	_refresh_talents()
	_refresh_prestige()

func _refresh_prestige() -> void:
	## P19b: Dao Marks ledger + ascension forecast + tree rows. The armed
	## confirm expires after 12s (checked on press, not per-frame).
	var ge: Node = get_node_or_null("/root/GameEngine")
	if ge == null:
		return
	var gain: int = int(ge.call("calculate_prestige_gain"))
	var label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/DaoMarksLabel") as Label
	if label != null:
		label.text = "Dao Marks: %d. Lifetime Qi %s. Ascension grants +%d." % [int(ge.get("dao_marks")), BN.format_any(ge.call("lifetime_qi_num")), gain]
		label.tooltip_text = "Marks persist across ascensions. Ascending resets realm, rate, aptitude, gear, sect, and arts — never soul, talents, karma, or records. Needs 1M lifetime Qi."
	var abtn: Button = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/AscendBtn") as Button
	if abtn != null:
		if gain <= 0:
			abtn.text = "Ascend (needs 1M lifetime Qi)"
		else:
			abtn.text = "Ascend +%d Dao Marks" % gain
	call_deferred("_rebuild_dao")

func _rebuild_dao() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var cdb: Node = get_node_or_null("/root/ContentDB")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/DaoTreeBox")
	if ge == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var descs: Dictionary = {}
	if cdb != null:
		for p in (cdb.get("prestige") as Array):
			descs[str((p as Dictionary).get("id", ""))] = str((p as Dictionary).get("desc", ""))
	for t in ge.call("dao_rows"):
		var tid: String = str((t as Dictionary).get("id", ""))
		var cost: int = int((t as Dictionary).get("cost", -1))
		var action: String = "%s: perfected" % str((t as Dictionary).get("name", tid)) if cost < 0 else "%s %d>%d (%d marks)%s" % [str((t as Dictionary).get("name", tid)), int((t as Dictionary).get("level", 0)), int((t as Dictionary).get("level", 0)) + 1, cost, ROW.bulk_suffix(_bulk_qty)]
		var drow: VBoxContainer = ROW.build_row("RowDao_%s" % tid, "%s" % str((t as Dictionary).get("name", tid)), action, str(descs.get(tid, "")), cost >= 0 and int(ge.get("dao_marks")) >= cost)
		var dbtn: Button = drow.get_node("BuyBtn") as Button
		dbtn.name = "Dao_%s" % tid
		dbtn.pressed.connect(_on_dao_buy.bind(tid))
		dbtn.pressed.connect(_juice_btn.bind(dbtn))
		box.add_child(drow)

func _on_dao_buy(pid: String) -> void:
	var ge: Node = get_node("/root/GameEngine")
	var got: int = int(ge.call("buy_bulk", "dao", pid, _bulk_qty))
	if got > 0:
		_log("Dao deepened: %s ×%d." % [pid, got])
		if got > 1:
			_toast("Dao %s ×%d" % [pid, got], "info")
		_sfx("click")
	else:
		_log("Not enough marks for %s." % pid)
		_sfx("fail")
	_refresh_prestige()

func _on_ascend() -> void:
	## P19c: ascension leaves through a confirm modal (the manager owns
	## confirms now). Refusals never open a dialog — the button says why.
	var ge: Node = get_node("/root/GameEngine")
	var gain: int = int(ge.call("calculate_prestige_gain"))
	if gain <= 0:
		_log("The heavens refuse: earn 1M lifetime Qi first.")
		_sfx("fail")
		return
	var ui: Node = get_node_or_null("UI")
	if ui == null:
		return
	var dlg: ConfirmationDialog = MODAL.build_confirm("Leave This World", "Ascend for +%d Dao Marks?\nRealm, rate, aptitude, gear, sect, and arts reset.\nSoul, talents, karma, and records cross over." % gain, "Ascend +%d" % gain)
	dlg.confirmed.connect(_execute_ascend)
	MODAL.present(ui, dlg)
	_sfx("click")

func _execute_ascend() -> void:
	var ge: Node = get_node("/root/GameEngine")
	_show_veil("Leaving this world…")
	var gain: int = int(ge.call("ascend"))
	get_tree().create_timer(0.5).timeout.connect(_hide_veil)
	if gain > 0:
		_log("Ascension complete: +%d Dao Marks. A new world, an old soul." % gain)
		_toast("Ascension +%d Dao Marks" % gain, "realm")
		_music_play("triumph")
		_sfx("rebirth")
	else:
		_log("The heavens refuse: earn 1M lifetime Qi first.")
		_sfx("fail")
	_refresh_pills()
	_refresh_soul()
	_refresh_talents()
	_refresh_prestige()
	_refresh_gear()
	_refresh_sect()
	_refresh_map()
	_refresh_prestige()

var _attune_sig: String = ""

func _refresh_attune_if_stale() -> void:
	## Attunement bars refresh only when levels shift (drill ticks move them
	## constantly while training; signature-gating avoids blind rebuilds).
	var ge: Node = get_node_or_null("/root/GameEngine")
	var cdb: Node = get_node_or_null("/root/ContentDB")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/AttuneBox")
	if ge == null or cdb == null or box == null:
		return
	var parts: PackedStringArray = []
	for t in (cdb.get("techniques") as Array):
		var tid: String = str((t as Dictionary).get("id", ""))
		parts.append("%d/%d" % [int(ge.call("technique_level", tid)), int(float((ge.get("attunement") as Dictionary).get(tid, 0.0)))])
	var sig: String = ";".join(parts)
	if sig != _attune_sig:
		_attune_sig = sig
		_rebuild_attune()

func _rebuild_attune() -> void:
	var ge: Node = get_node_or_null("/root/GameEngine")
	var cdb: Node = get_node_or_null("/root/ContentDB")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/AttuneBox")
	if ge == null or cdb == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for t in (cdb.get("techniques") as Array):
		var tid: String = str((t as Dictionary).get("id", ""))
		var row := HBoxContainer.new()
		var lab := Label.new()
		lab.text = "%s Lv%d" % [str((t as Dictionary).get("name", tid)), int(ge.call("technique_level", tid))]
		lab.tooltip_text = "%s Attunement %.0f/100 (perk at 60). Drill it to attune." % [str((t as Dictionary).get("desc", "")), float((ge.get("attunement") as Dictionary).get(tid, 0.0))]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = float((ge.get("attunement") as Dictionary).get(tid, 0.0))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 10)
		bar.tooltip_text = lab.tooltip_text
		row.add_child(lab)
		row.add_child(bar)
		box.add_child(row)

func _rebuild_bestiary() -> void:
	## P17-Step3: 39 rows, rebuilt when opened (tab_changed) or after hunts.
	var ge: Node = get_node_or_null("/root/GameEngine")
	var cdb: Node = get_node_or_null("/root/ContentDB")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/BestiaryBox")
	if ge == null or cdb == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for b in (cdb.get("beasts") as Array):
		var bid: String = str((b as Dictionary).get("id", ""))
		var kills: int = int((ge.get("beasts") as Dictionary).get(bid, 0))
		var mark: String = str(ge.call("completion_mark", bid))
		var lab := Label.new()
		lab.text = "%s — %s (%d)" % [str((b as Dictionary).get("name", bid)), mark, kills]
		lab.tooltip_text = "Signs found stalking the %s grounds. %d for marked, %d for apex." % [str((b as Dictionary).get("zone", "?")), 5000, 20000]
		box.add_child(lab)

func _rebuild_guardians() -> void:
	## P22: 7 warden rows, rebuilt when opened. Duel entities are disjoint
	## from the beast codex — this roster never touches beast kill counts.
	var ge: Node = get_node_or_null("/root/GameEngine")
	var label: Label = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/GuardianLabel") as Label
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Beasts/GuardianBox")
	if ge == null or label == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var roster: Array = ge.call("guardian_roster")
	if roster.is_empty():
		label.text = "Wardens: none met."
		return
	var fallen: int = 0
	for g in roster:
		if bool((g as Dictionary).get("defeated", false)):
			fallen += 1
	label.text = "Wardens: %d of %d fallen." % [fallen, roster.size()]
	label.tooltip_text = "Macro-tier wardens bar ladder crossings until defeated. Defeat stands through Samsara."
	for g in roster:
		var gd: Dictionary = g
		var b := Button.new()
		b.name = "Guardian_%s" % str(gd.get("id", "?"))
		if bool(gd.get("defeated", false)):
			b.text = "%s — fallen (tier %d)" % [str(gd.get("name", "?")), int(gd.get("tier", 0))]
			b.disabled = true
			b.tooltip_text = "This warden stays defeated. The sword dao is remembered."
		elif bool(gd.get("active", false)):
			b.text = "Challenge %s (tier %d)" % [str(gd.get("name", "?")), int(gd.get("tier", 0))]
			b.tooltip_text = "A deterministic duel: power against power, no death, proportional cost on defeat."
			b.pressed.connect(_on_guardian.bind(str(gd.get("id", ""))))
		else:
			b.text = "%s — sleeps (tier %d)" % [str(gd.get("name", "?")), int(gd.get("tier", 0))]
			b.disabled = true
			b.tooltip_text = "This warden bars a deeper crossing. Reach its tier first."
		box.add_child(b)

func _on_guardian(id: String) -> void:
	## Manual warden duel from the Beasts tab. Same power basis as the
	## manual breakthrough (auto power + best technique bonus).
	var ge: Node = get_node("/root/GameEngine")
	var bonus: float = float(ge.call("best_technique_bonus"))
	var wname: String = id
	for g in (ge.call("guardian_roster") as Array):
		if str((g as Dictionary).get("id", "")) == id:
			wname = str((g as Dictionary).get("name", id))
	var res: Dictionary = ge.call("attempt_guardian", _auto_breakthrough_power, bonus)
	if bool(res.get("win", false)):
		_log("Warden fallen: %s (%s)." % [wname, str(res.get("quality", "?"))])
		_toast("Warden fallen: %s" % wname, "realm")
		_sfx("breakthrough")
		var ui_fx: Node = get_node_or_null("UI")
		if ui_fx != null and ui_fx.has_method("play_breakthrough_fx"):
			ui_fx.call("play_breakthrough_fx")
	elif str(res.get("reason", "")) == "no_guardian":
		_log("No warden bars the way right now.", "warn")
		_sfx("fail")
	else:
		_log("The warden prevails — proportional Qi lost. Train and return.", "warn")
		_sfx("fail")
	_rebuild_guardians()
	_refresh_breakthrough_btn()

func _rebuild_achievements() -> void:
	## P17-Step3: 43 rows with unlocked state, rebuilt when opened.
	var ge: Node = get_node_or_null("/root/GameEngine")
	var cdb: Node = get_node_or_null("/root/ContentDB")
	var box: Node = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Deeds/AchieveBox")
	if ge == null or cdb == null or box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var have: Array = ge.get("achievements")
	for a in (cdb.get("achievements") as Array):
		var aid: String = str((a as Dictionary).get("id", ""))
		var lab := Label.new()
		var got: bool = have.has(aid)
		lab.text = "%s%s" % ["✓ " if got else "· ", str((a as Dictionary).get("name", aid))]
		lab.modulate = Color(1, 1, 1, 1) if got else Color(1, 1, 1, 0.45)
		lab.tooltip_text = str((a as Dictionary).get("desc", ""))
		box.add_child(lab)

const PILL_TIPS := {
	"pill_prep": "+25% tribulation power for one crossing.",
	"pill_heal": "Mends one deviation flaw.",
	"pill_purge": "Burns 40 toxicity out of the channels.",
	"pill_ward": "Doubles shield strength for one crossing.",
}
const TALENT_TIPS := {
	"talent_roots": "Purifies every root +0.05 per rank, retroactive.",
	"talent_body": "+2 tribulation power per rank.",
	"talent_breath": "+10% lifespan per rank.",
}
const SOUL_TIPS := {
	"soul_blade": "Oath Blade: +1 tribulation power per soul level.",
	"soul_bell": "Hollow Bell: +15% shield per soul level.",
	"soul_mirror": "Still Mirror: +5% karma per soul level.",
}

func _on_bequeath(id: String, mx: int) -> void:
	var ge: Node = get_node("/root/GameEngine")
	if bool(ge.call("bequeath_gear", id, mx)):
		_log("Bequeathed %s to the lineage." % id)
		_sfx("breakthrough")
	else:
		_log("Only perfected relics may be given.")
		_sfx("fail")
	_refresh_gear()
	_refresh_talents()
	_refresh_prestige()

const RAIL_TABS := ["Sect", "Alchemy", "Arts", "Soul", "Samsara", "Beasts", "Deeds", "Records", "Settings"]

func _wire_rail() -> void:
	## P19c: left-nav rail drives the headerless tab view (template nav
	## pattern, reimplemented: hidden TabContainer + custom buttons).
	for i in range(RAIL_TABS.size()):
		_connect_btn("UI/Root/RailPanel/Rail/Rail" + str(RAIL_TABS[i]), _on_rail.bind(i))

var _last_rail_open: String = ""
var _rail_baselined: bool = false

func _on_rail(i: int) -> void:
	## P21: locked rails refuse with the requirement named (hard gates).
	## Content builders bypass the rail — only navigation is gated.
	var ge: Node = get_node_or_null("/root/GameEngine")
	var tab: String = str(RAIL_TABS[clampi(i, 0, RAIL_TABS.size() - 1)])
	if ge != null and bool(ge.call("reveal_wired")) and not (ge.call("tabs_unlocked") as Array).has(tab):
		_log("%s opens %s." % [tab, _reveal_need(ge, tab)], "warn")
		_sfx("fail")
		return
	var tabs: TabContainer = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	if tabs != null:
		tabs.current_tab = clampi(i, 0, tabs.get_tab_count() - 1)
	_sfx("click")

func _reveal_need(ge: Node, tab: String) -> String:
	for r in (ge.get("_reveal_rules") as Array):
		if str((r as Dictionary).get("tab", "")) == tab:
			return "at %s %s" % [str((r as Dictionary).get("stat", "?")), str((r as Dictionary).get("value", "?"))]
	return "later"

func _refresh_rail() -> void:
	## P21: hard gates on the rail (4Hz poll). Locked buttons disable with
	## the requirement as tooltip; fresh unlocks log their dedication line
	## once (signature diff, same pattern as attunement bars).
	var ge: Node = get_node_or_null("/root/GameEngine")
	var tabs: TabContainer = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	if ge == null or tabs == null or not bool(ge.call("reveal_wired")):
		return
	var open: Array = ge.call("tabs_unlocked")
	var sig: String = ";".join(open)
	if sig != _last_rail_open:
		# First poll baselines silently (returning exiles don't need
		# nine dedication lines); only true transitions announce.
		var before: Array = _last_rail_open.split(";") if _rail_baselined else open.duplicate()
		_last_rail_open = sig
		_rail_baselined = true
		for t in open:
			if not before.has(t):
				var line: String = ge.call("reveal_line", str(t))
				if line != "":
					_log(line)
					_toast("Unlocked: %s" % str(t), "realm")
	for i in range(RAIL_TABS.size()):
		var b: Button = get_node_or_null("UI/Root/RailPanel/Rail/Rail" + str(RAIL_TABS[i])) as Button
		if b == null:
			continue
		var unlocked: bool = open.has(str(RAIL_TABS[i]))
		b.disabled = not unlocked
		b.tooltip_text = "%s panel." % str(RAIL_TABS[i]) if unlocked else "Unlocks %s." % _reveal_need(ge, str(RAIL_TABS[i]))
	_highlight_rail()

func _highlight_rail() -> void:
	var tabs: TabContainer = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs") as TabContainer
	var cur: int = tabs.get_current_tab() if tabs != null else 0
	for i in range(RAIL_TABS.size()):
		var b: Button = get_node_or_null("UI/Root/RailPanel/Rail/Rail" + str(RAIL_TABS[i])) as Button
		if b != null:
			b.modulate = Color(1.0, 0.85, 0.45) if i == cur else Color(1, 1, 1)

func _on_panels_toggle() -> void:
	## P17-Step3: one panel surface for all management; Esc closes.
	## P17-Step4: quick fade on open (motion polish).
	## P19c: the rail docks beside the panel and follows its visibility.
	var p: Node = get_node_or_null("UI/Root/SidePanel")
	var rail: Node = get_node_or_null("UI/Root/RailPanel")
	if p != null:
		p.visible = not p.visible
		if rail != null:
			rail.visible = bool(p.visible)
		if p.visible:
			_rebuild_bestiary()
			_rebuild_guardians()
			_rebuild_achievements()
			_refresh_attune_if_stale()
			_highlight_rail()
			p.modulate = Color(1, 1, 1, 0.3)
			var tw: Tween = create_tween()
			tw.tween_property(p, "modulate:a", 1.0, 0.15)
	_sfx("click")

func _on_tab_changed(_tab: int) -> void:
	## Fresh rows whenever the player looks (cheap lists rebuilt on open).
	_rebuild_bestiary()
	_rebuild_guardians()
	_rebuild_achievements()
	_highlight_rail()

const SHORTCUTS := [
	["1 / 2 / 3", "Breathe / Drill / Stalk focus"],
	["T", "Attempt tribulation"],
	["7 / 8 / 9 / 0", "Speed 1x / 10x / 100x / 1000x"],
	["Space", "Pause / resume"],
	["H", "Stalk current grounds"],
	["V", "Wander unwalked grounds"],
	["M", "Mute sound"],
	["F1", "This help"],
	["Esc", "Close panels / help"],
	["W A S D", "Walk the world (panels closed)"],
	["E", "Interact / meditate at touched points"],
	["F", "Toggle sword-flight (once unlocked)"],
]

func _tip(path: String, text: String) -> void:
	var c: Control = get_node_or_null(path) as Control
	if c != null:
		c.tooltip_text = text

func _apply_tooltips() -> void:
	## P17-Step3: every stat and fixed control explains itself. Data descs
	## feed origin/tech tips; the rest is static doctrine.
	var cdb: Node = get_node_or_null("/root/ContentDB")
	if cdb != null:
		for o in (cdb.get("origins") as Array):
			_tip("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/Org" + str((o as Dictionary).get("id", "")).trim_prefix("origin_").capitalize().replace(" ", ""), str((o as Dictionary).get("desc", "")))
		for t in (cdb.get("techniques") as Array):
			_tip("UI/Root/SidePanel/PanelScroll/PanelTabs/Arts/Tech" + str((t as Dictionary).get("id", "")).trim_prefix("tech_").capitalize().replace(" ", ""), str((t as Dictionary).get("desc", "")))
	_tip("UI/Root/BottomDock/DockRows/DockRow1/FocusCultivate", "Breathe: cultivates Qi and calms the heart. [1]")
	_tip("UI/Root/BottomDock/DockRows/DockRow1/FocusTrain", "Drill: technique xp, zero Qi, strains the heart. [2]")
	_tip("UI/Root/BottomDock/DockRows/DockRow1/FocusHunt", "Stalk: beast signs abroad, zero Qi, eases the heart. [3]")
	_tip("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn", "Attempt when Qi fills. Readiness and forecast shown live. [T]")
	_tip("UI/Root/BottomDock/DockRows/DockRow1/StalkBtn", "Stalk current grounds for signs. Weak hunts yield less. [H]")
	_tip("UI/Root/BottomDock/DockRows/DockRow1/WanderBtn", "Walk rich unwalked grounds. First visits are free. [V]")
	_tip("UI/Root/BottomDock/DockRows/DockRow2/RecruitBtn", "Recruit a disciple for Qi. Cost capped at 8 fills.")
	_tip("UI/Root/TopBar/TopBarBox/RealmLabel", "Current realm, macro tier, and within-realm layer.")
	_tip("UI/Root/TopBar/TopBarBox/AgeLabel", "Age over realm-scaled lifespan. Death ends the life.")
	_tip("UI/Root/TopBar/TopBarBox/QiLabel", "Stored Qi over bottleneck. Fill to Late layer to attempt.")
	_tip("UI/Root/TopBar/TopBarBox/MindLabel", "Serene 1.25x, Steady 1.0x, Strained 0.8x throughput.")
	_tip("UI/Root/TopBar/TopBarBox/SeasonLabel", "Spring +Qi, Summer +drill, Autumn +gather, Winter +tribulation power.")
	_tip("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/EndLifeBtn", "Lay down this life willingly and bank karma now.")
	_tip("UI/Root/RailPanel/Rail/RailSect", "Sect: disciples and duties.")
	_tip("UI/Root/RailPanel/Rail/RailAlchemy", "Alchemy: brews and quaffs.")
	_tip("UI/Root/RailPanel/Rail/RailArts", "Arts: drills and attunement.")
	_tip("UI/Root/RailPanel/Rail/RailSoul", "Soul: relics and the forge.")
	_tip("UI/Root/RailPanel/Rail/RailSamsara", "Samsara: rebirth and ascension.")
	_tip("UI/Root/RailPanel/Rail/RailBeasts", "Beasts: grounds and bestiary.")
	_tip("UI/Root/RailPanel/Rail/RailDeeds", "Deeds: achievements.")
	_tip("UI/Root/RailPanel/Rail/RailRecords", "Records: lives and legends.")
	_tip("UI/Root/RailPanel/Rail/RailSettings", "Settings: sound and saves.")
	_tip("UI/Root/TopBar/TopBarBox/BulkBtn", "Bulk quantity for repeatable buys (forge, brews, talents, dao). Cycles x1, x10, MAX.")
	_tip("UI/Root/SidePanel/PanelScroll/PanelTabs/Samsara/AscendBtn", "Leave this world for Dao Marks. First press arms, second confirms. Resets realm, gear, and sect — never soul or records.")
	_tip("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SeclusionBtn", "Vigil stalls at death's door offline; Unfettered lets death resolve unseen.")
	_tip("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/MusicSlider", "Lofi volume. Title, journey, and triumph themes crossfade.")
	_tip("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SkinBtn", "Alternate skin: warm parchment instead of deep ink.")

func _apply_modal_blur() -> void:
	## P17-Step4: one shared blur material on both full-screen overlays.
	## Screenshot-verified (not just no-crash): the tint must show the
	## blurred world, never flat grey.
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/modal_blur.gdshader")
	for path in ["UI/TitleOverlay", "UI/HelpOverlay"]:
		var c: ColorRect = get_node_or_null(path) as ColorRect
		if c != null:
			c.material = m

func _build_help() -> void:
	var box: Node = get_node_or_null("UI/HelpOverlay/HelpCenter/HelpCard/HelpBox")
	if box == null:
		return
	for pair in SHORTCUTS:
		var lab := Label.new()
		lab.text = "%s — %s" % [str(pair[0]), str(pair[1])]
		box.add_child(lab)

func _on_help() -> void:
	var h: Node = get_node_or_null("UI/HelpOverlay")
	if h != null:
		h.visible = not h.visible
	_sfx("click")

func _on_mute() -> void:
	var ge: Node = get_node("/root/GameEngine")
	ge.set("muted", not bool(ge.get("muted")))
	_sync_mute(ge)
	_log("Sound %s." % ("off" if bool(ge.get("muted")) else "on"))

func _on_volume(v: float) -> void:
	## P17-Step3 settings: slider volume (mute stays the hard switch).
	## P21: persisted to player_config.
	var sfx: Node = get_node_or_null("/root/SfxSynth")
	if sfx != null:
		sfx.set("volume", clampf(v / 100.0, 0.0, 1.0))
	_save_settings()

func _on_music_volume(v: float) -> void:
	## P21: lofi bus level, persisted alongside SFX volume.
	_set_music_db(clampf(v / 100.0, 0.0, 1.0))
	_save_settings()

func _on_glow(on: bool) -> void:
	## P17-Step3 settings: world glow toggle (perf/visibility preference).
	## P21: persisted.
	var w: Node = get_node_or_null("WorldViewport/World")
	if w != null and w.has_method("set_glow"):
		w.call("set_glow", on)
	PlayerConfig.set_config(SETTINGS_SECTION, "glow", on)
	_sfx("click")

func _on_export() -> void:
	## P17-Step3 settings: copy the live slot beside the game documents.
	if get_node_or_null("/root/SaveManager") == null:
		return
	var sm: Node = get_node("/root/SaveManager")
	var path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("cultivation_nation_export.json")
	_show_veil("Copying save…")
	if bool(sm.call("export_save", path)):
		_log("Save exported.")
	else:
		_log("Nothing to export yet.", "warn")
	_hide_veil()
	_sfx("click")

func _on_import_show() -> void:
	var dlg: FileDialog = get_node_or_null("UI/Root/SidePanel/PanelScroll/PanelTabs/Settings/SaveDialog") as FileDialog
	if dlg != null:
		dlg.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		dlg.popup_centered_ratio(0.7)

func _on_import_file(path: String) -> void:
	## P17-Step3 settings: replace the slot from file (backup rotated by the
	## manager), then rewire runtime-only state like a fresh load.
	if get_node_or_null("/root/SaveManager") == null:
		return
	var sm: Node = get_node("/root/SaveManager")
	var ge: Node = get_node("/root/GameEngine")
	_show_veil("Reading save…")
	var loaded: Dictionary = sm.call("import_save", path)
	if loaded.is_empty():
		_hide_veil()
		_log("Import refused (missing or corrupt file).", "warn")
		_sfx("fail")
		return
	_wire_world(ge)
	_wire_world(ge)
	_refresh_all()
	_hide_veil()
	_log("Save imported (v%d)." % int(loaded.get("save_version", 0)))

func _refresh_all() -> void:
	## Full UI rebuild after load/import: every dynamic box, both labels rows.
	_refresh_sect()
	_refresh_map()
	_refresh_gear()
	_refresh_pills()
	_refresh_soul()
	_refresh_talents()
	_refresh_prestige()
	_rebuild_bestiary()
	_rebuild_guardians()
	_rebuild_achievements()
	_refresh_attune_if_stale()
	_refresh_ui()

func _wire_world(ge: Node) -> void:
	## P4: connect engine to authored data + regenerate map + apply gear bonus.
	if get_node_or_null("/root/ContentDB") == null:
		return
	var cdb: Node = get_node("/root/ContentDB")
	ge.call("set_beast_pool", cdb.get("beasts"))
	ge.call("set_hunt_order", cdb.call("beast_ids_in_order"))
	ge.call("set_technique_defs", cdb.get("techniques"))
	ge.call("set_guardian_defs", cdb.get("guardians"))
	if int(ge.get("map_seed")) < 0:
		ge.call("generate_map", -1)
	else:
		ge.call("regenerate_map")
	ge.call("set_gear_mult", ge.call("gear_bonus_for", ge.get("gear"), cdb.call("gear_defs")))
	ge.call("set_achievement_rules", cdb.get("achievements"))
	ge.call("set_prestige_defs", cdb.get("prestige"))
	ge.call("set_reveal_rules", cdb.get("reveal"))
	ge.call("set_flight_rule", cdb.get("flight"))
	_realm_table = (cdb.get("realms") as Array).duplicate()
	ge.call("set_realm_table", _realm_table)
	var ui: Node = get_node_or_null("UI")
	if ui != null:
		var names: Dictionary = {}
		for a in (cdb.get("achievements") as Array):
			names[str((a as Dictionary).get("id", ""))] = str((a as Dictionary).get("name", ""))
		ui.set("ach_names", names)

func _on_pause_for_death(age: int) -> void:
	_log("Paused at age %d — death approaches. Resume when ready." % age)

func _process(delta: float) -> void:
	var ge: Node = get_node("/root/GameEngine")
	# Boot veil + music pump run even while held: the title screen has
	# music, and the veil must lift without waiting for Continue
	# (QA Round 1: both starved behind the running gate on held boots).
	if _veil_frames >= 0:
		_veil_frames += 1
		if _veil_frames >= 45:
			_veil_frames = -1
			_hide_veil()
	_pump_music()
	if not bool(ge.get("running")):
		_ui_timer += delta
		if _ui_timer >= 0.25:
			_ui_timer = 0.0
			_refresh_ui()
		return  # paused for death: hold position, no autos, just show state
	# Auto-tribulation: modest power sharpened by best technique bonus.
	# P13-B1: never auto-attempts an unreadied crossing; names the drill fix
	# once per fill instead of fail-spamming scars into every life.
	if ge.call("qi_num") >= ge.call("bottleneck_num"):
		var need: float = _trib_need(ge)
		var bonus: float = float(ge.call("best_technique_bonus"))
		# P22: idle hands still duel — a standing warden is challenged
		# automatically when the crossing fills, then the attempt proceeds.
		var gateA: Dictionary = ge.call("guardian_gate")
		if bool(gateA.get("blocked", false)):
			var resA: Dictionary = ge.call("attempt_guardian", _auto_breakthrough_power, bonus)
			if bool(resA.get("win", false)):
				_log("Warden fallen: %s (%s)." % [str(gateA.get("name", "warden")), str(resA.get("quality", "?"))])
				_toast("Warden fallen: %s" % str(gateA.get("name", "warden")), "realm")
				_sfx("breakthrough")
				_rebuild_guardians()
			elif not _warden_note_done:
				_warden_note_done = true
				_log("The %s prevails — proportional Qi lost. Train and return." % str(gateA.get("name", "warden")), "warn")
				_sfx("fail")
		if not bool(ge.call("is_ready", _auto_breakthrough_power, need, bonus)):
			if not _unready_note_done:
				_unready_note_done = true
				_log("Qi full but power lacking (readiness %d%%) — drill a technique." % int(ge.call("readiness_pct", _auto_breakthrough_power, need, bonus)), "warn")
		else:
			var ok: bool = bool(ge.call("attempt_breakthrough", _auto_breakthrough_power, need, bonus))
			if ok:
				_log("Breakthrough! Entered realm %d (%s)." % [int(ge.get("realm_index")), str(ge.get("last_quality"))])
				_toast("Breakthrough! Realm %d (%s)" % [int(ge.get("realm_index")), str(ge.get("last_quality"))], "realm")
				_float_quality(ge)
				var ui_fx: Node = get_node_or_null("UI")
				if ui_fx != null and ui_fx.has_method("play_breakthrough_fx"):
					ui_fx.call("play_breakthrough_fx")
				_check_backlash(ge)
				_maybe_celebrate()
			else:
				_log("Tribulation failed (power %.0f < need %.0f). Half Qi lost." % [_auto_breakthrough_power, need], "warn")
	else:
		_unready_note_done = false
		_warden_note_done = false
	# UI poll at ~4Hz (matches high-speed throttle lesson from CoFD).
	_ui_timer += delta
	if _ui_timer >= 0.25:
		_ui_timer = 0.0
		_refresh_ui()
		_refresh_stride_note()
		_refresh_breakthrough_btn()
		_refresh_pills_if_stale()
		_refresh_attune_if_stale()
		_refresh_rail()
		_refresh_coach()
		_poll_hints()
	# Autosave every 30s.
	_save_timer += delta
	if _save_timer >= 30.0:
		_save_timer = 0.0
		if get_node_or_null("/root/SaveManager") != null:
			get_node("/root/SaveManager").call("save_game")

const HINTS: Dictionary = {
	"hint_origin": "Choose how this life begins - pick an origin in the Samsara panel.",
	"hint_bottleneck": "Qi brims over. Attempt the tribulation.",
	"hint_drill": "Power falls short of the tribulation - drill a technique to temper strength.",
	"hint_pause": "Death comes for every life. Set a pause before its years.",
	"hint_travel": "New grounds lie open. Walk the wilderness.",
	"hint_sect": "Your name carries weight now. Found a sect.",
	"hint_duties": "Idle hands learn nothing. Give your disciples duties.",
	"hint_gear": "Qi to spare? Refine your kit at the forge.",
	"hint_legacy": "Death kept what mattered. The rest begins again.",
}

func _poll_hints() -> void:
	var ge: Node = get_node("/root/GameEngine")
	for hid in ge.call("due_hints"):
		_log(str(HINTS.get(str(hid), str(hid))))
		ge.call("mark_hint", str(hid))

func _juice_btn(b: Button) -> void:
	## P21: press squash on shop rows (AICookieClicker feedback fitted to
	## our rows; toasts already cover bulk totals, the pool stays reserved
	## for breakthrough/quality moments).
	if b == null or not is_instance_valid(b):
		return
	b.pivot_offset = b.size / 2.0
	var tw: Tween = create_tween()
	tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.05)
	tw.tween_property(b, "scale", Vector2.ONE, 0.12)

func _show_veil(line: String = "Attuning…") -> void:
	## P21: transition veil (Maaack scene-loader pattern fitted single-scene:
	## a progress veil over boot, imports/exports, and ascensions — no scene
	## ever changes, so the vendor autoload itself stays out of the tree).
	var v: Node = get_node_or_null("UI/LoadingVeil")
	if v == null:
		return
	var lab: Label = get_node_or_null("UI/LoadingVeil/VeilLabel") as Label
	if lab != null:
		lab.text = line
	v.visible = true
	v.modulate = Color(1, 1, 1, 0.0)
	var tw: Tween = create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 0.2)

func _hide_veil() -> void:
	var v: Node = get_node_or_null("UI/LoadingVeil")
	if v == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(v, "modulate:a", 0.0, 0.25)
	tw.tween_callback(v.hide)

func _refresh_ui() -> void:
	var ui: Node = get_node_or_null("UI")
	if ui != null and ui.has_method("refresh"):
		ui.call("refresh")

func _refresh_stride_note() -> void:
	## P24b: one warded-style note per locked zone while stride keys are
	## held (avatar movement polls every frame; the warden pattern applies
	## to feet too). Clears the moment the grounds admit walking again.
	var world: Node = get_node_or_null("WorldViewport/World")
	if world == null or not world.has_method("avatar_lock_reason"):
		return
	var reason: String = str(world.call("avatar_lock_reason"))
	if reason == "":
		_stride_note = "#"
		return
	if reason == _stride_note:
		return
	var striding: bool = false
	for a in ["world_move_forward", "world_move_back", "world_move_left", "world_move_right"]:
		if Input.is_action_pressed(str(a)):
			striding = true
			break
	if striding:
		_stride_note = reason
		_log(reason + " Walk them when admitted.", "warn")
		_sfx("fail")

func _refresh_coach() -> void:
	## P21: first-session coach marks (godot-idle skeleton fitted to our
	## loop: three derived steps, no stored progress). Completes or
	## dismisses forever (coach_done persists, v11).
	var ge: Node = get_node_or_null("/root/GameEngine")
	var panel: PanelContainer = get_node_or_null("UI/Root/CoachPanel") as PanelContainer
	if ge == null or panel == null:
		return
	if bool(ge.get("coach_done")):
		panel.visible = false
		return
	var best: int = 0
	for k in (ge.get("techniques") as Dictionary):
		best = maxi(best, int(ge.call("technique_level", str(k))))
	var steps: Array = [
		ge.call("fill_ratio") >= 2.0 / 3.0,
		best >= 1,
		int(ge.get("realm_index")) >= 1,
	]
	var labels: Array = ["Breathe Qi to a full dantian.", "Drill a technique to rank 1.", "Attempt the first tribulation."]
	for i in range(3):
		var lab: Label = get_node_or_null("UI/Root/CoachPanel/CoachBox/CoachStep%d" % i) as Label
		if lab != null:
			lab.text = "%s %s" % ["✓" if bool(steps[i]) else "·", str(labels[i])]
	var done: bool = bool(steps[0]) and bool(steps[1]) and bool(steps[2])
	if done:
		ge.set("coach_done", true)
		panel.visible = false
		_log("The first steps are walked. The coach bows out.")
		_save_coach()
		return
	panel.visible = true

func _save_coach() -> void:
	if get_node_or_null("/root/SaveManager") != null:
		get_node("/root/SaveManager").call("save_game")

func _on_coach_dismiss() -> void:
	var ge: Node = get_node("/root/GameEngine")
	ge.set("coach_done", true)
	var panel: Node = get_node_or_null("UI/Root/CoachPanel")
	if panel != null:
		panel.visible = false
	_log("You walk alone from here.")
	_save_coach()
	_sfx("click")

func _set_shine(b: Button, on: bool) -> void:
	## P17-Step4: sheen overlay child (mouse-ignore) compositing OVER the
	## button's themed draw. A canvas_item material would replace the draw;
	## the overlay preserves it. One shared shader, per-button overlay node.
	if on:
		var ov: TextureRect = b.get_node_or_null("ShineOverlay") as TextureRect
		if ov == null:
			ov = TextureRect.new()
			ov.name = "ShineOverlay"
			ov.set_anchors_preset(Control.PRESET_FULL_RECT)
			ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var m := ShaderMaterial.new()
			m.shader = load("res://assets/shaders/ui_shine.gdshader")
			ov.material = m
			b.add_child(ov)
		ov.visible = true
	else:
		var ov2: TextureRect = b.get_node_or_null("ShineOverlay") as TextureRect
		if ov2 != null:
			ov2.visible = false

func _refresh_breakthrough_btn() -> void:
	## P13-B4: the Attempt button shows live readiness + forecast quality, so
	## the risk decision is visible BEFORE committing — never after failing.
	var ge: Node = get_node("/root/GameEngine")
	var b: Button = get_node_or_null("UI/Root/BottomDock/DockRows/DockRow1/BreakthroughBtn") as Button
	if b == null:
		return
	var need: float = _trib_need(ge)
	var bonus: float = float(ge.call("best_technique_bonus"))
	var eff: float = (_auto_breakthrough_power + float(ge.call("artifact_power_bonus"))) * float(ge.get("_prep_power"))
	var fill: float = ge.call("fill_ratio")
	var fc: Dictionary = ge.call("forecast_quality", eff, need, bonus, fill, float(ge.get("_ward_power")))
	var pct: int = int(ge.call("readiness_pct", _auto_breakthrough_power, need, bonus))
	# P17-Step2 colorblind-safe readiness: symbol alongside color and number.
	# Glyphs restricted to the verified HUD set (p17 coverage test): » ! ×.
	# P17-Step4: shine sweep while ready (shared material, TIME-driven).
	var sym: String = "» " if pct >= 100 else ("! " if pct >= 70 else "× ")
	_set_shine(b, pct >= 100)
	b.text = "%sAttempt Tribulation (%d%% · %s)" % [sym, pct, str(fc.get("quality", "?"))]
	# P22: a standing warden bars the crossing — name it on the button.
	var gate: Dictionary = ge.call("guardian_gate")
	if bool(gate.get("blocked", false)):
		b.text += " · Warded"
		b.tooltip_text = "The %s bars this crossing. Defeat it first (Beasts tab). [T]" % str(gate.get("name", "warden"))
	else:
		b.tooltip_text = "Attempt when Qi fills. Readiness and forecast shown live. [T]"

func _log(s: String, cat: String = "info") -> void:
	var ui: Node = get_node_or_null("UI")
	if ui != null and ui.has_method("log_line"):
		ui.call("log_line", s, cat)
	else:
		print(s)
