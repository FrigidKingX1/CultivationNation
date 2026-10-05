extends Node
## SfxSynth autoload — procedural sound effects. All tones synthesized in code
## (sine + decay envelope); zero audio assets. Original work.

const MIX_RATE: int = 22050

var muted: bool = false
var volume: float = 1.0
var _streams: Dictionary = {}
var _players: Dictionary = {}

func _ready() -> void:
	# P21: runtime bus install (mirrors the Maaack plugin installer, which
	# only runs in the editor — headless runs never execute it). Music and
	# SFX buses hang off Master; everything below routes explicitly.
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_streams["click"] = _tone(880.0, 0.06)
	_streams["hover"] = _tone(1320.0, 0.03)
	_streams["breakthrough"] = _chime([523.25, 659.25, 783.99], 0.12)
	_streams["rebirth"] = _tone(220.0, 0.4)
	_streams["achievement"] = _chime([783.99, 1046.5], 0.10)
	_streams["fail"] = _tone(160.0, 0.15)
	for k in _streams:
		var p := AudioStreamPlayer.new()
		p.stream = _streams[k]
		p.bus = "SFX"
		add_child(p)
		_players[k] = p

func _ensure_bus(bus_name: String) -> void:
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func _tone(freq: float, dur: float) -> AudioStreamWAV:
	return _chime([freq], dur)

func _chime(freqs: Array, note_dur: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for f in freqs:
		var n: int = int(MIX_RATE * note_dur)
		for i in range(n):
			var t: float = float(i) / float(MIX_RATE)
			var env: float = exp(-3.0 * t / note_dur)
			var v: float = sin(TAU * float(f) * t) * env
			var s: int = int(clampf(v, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w

func play(sfx_name: String) -> bool:
	if muted:
		return false
	if not _players.has(sfx_name):
		return false
	var p: AudioStreamPlayer = _players[sfx_name]
	# P17-Step3: volume slider (mute preserved as the hard switch).
	p.volume_db = linear_to_db(maxf(volume, 0.0001))
	p.play()
	return true

func ui_stream(sfx_name: String) -> AudioStream:
	## P21: exposes procedural streams to the Maaack UI-sound controller
	## (hover/focus assignment at boot). Null when unknown — never errors.
	return _streams.get(sfx_name, null)

func stream_frames(sfx_name: String) -> int:
	if not _streams.has(sfx_name):
		return 0
	return ((_streams[sfx_name] as AudioStreamWAV).data.size() / 2)
