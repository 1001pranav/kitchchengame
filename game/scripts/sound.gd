extends Node
## Autoload "Sound": music by phase, room ambience that follows how busy it is,
## and one-shot effects. Settings live in user://settings.cfg.

const SETTINGS := "user://settings.cfg"
var music_on := true
var sfx_on := true
var _music: Array = []      ## two players for crossfades
var _music_i := 0
var _music_name := ""
var _room: AudioStreamPlayer
var _kitchen: AudioStreamPlayer
var _pool: Array = []
var _streams := {}
var _last := {}
var room_level := 0.0       ## 0..1, set by the game from how full the room is
var kitchen_level := 0.0    ## 0..1, from how many stations are cooking

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		music_on = cfg.get_value("sound", "music", true)
		sfx_on = cfg.get_value("sound", "sfx", true)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80
		add_child(p)
		_music.append(p)
	_room = _loop_player("amb_room")
	_kitchen = _loop_player("amb_kitchen")
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sound", "music", music_on)
	cfg.set_value("sound", "sfx", sfx_on)
	cfg.save(SETTINGS)
	if not music_on:
		for p in _music:
			p.stop()
		_music_name = ""

func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]

func _loop_player(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStreamOggVorbis = _stream("res://assets/audio/%s.ogg" % name).duplicate()
	s.loop = true
	p.stream = s
	p.volume_db = -80
	add_child(p)
	return p

## Crossfades to a music loop ("service", "title") or silence ("").
func music(name: String) -> void:
	if not music_on:
		name = ""
	if name == _music_name:
		return
	_music_name = name
	var old: AudioStreamPlayer = _music[_music_i]
	var tw := create_tween()
	tw.tween_property(old, "volume_db", -60.0, 1.2)
	tw.tween_callback(old.stop)
	if name == "":
		return
	_music_i = 1 - _music_i
	var p: AudioStreamPlayer = _music[_music_i]
	var s: AudioStreamOggVorbis = _stream("res://assets/audio/music_%s.ogg" % name).duplicate()
	s.loop = true
	p.stream = s
	p.volume_db = -40
	p.play()
	var tw2 := create_tween()
	tw2.tween_property(p, "volume_db", -10.0 if name == "service" else -8.0, 1.6)

func ambience(on: bool) -> void:
	for p in [_room, _kitchen]:
		if on and sfx_on and not p.playing:
			p.play()
		elif not on or not sfx_on:
			p.stop()

func _process(delta: float) -> void:
	if _room.playing:
		var want := lerpf(-34.0, -9.0, clampf(room_level, 0, 1))
		_room.volume_db = lerpf(_room.volume_db, want, minf(1.0, delta * 1.5))
	if _kitchen.playing:
		var want2 := lerpf(-40.0, -15.0, clampf(kitchen_level, 0, 1))
		_kitchen.volume_db = lerpf(_kitchen.volume_db, want2, minf(1.0, delta * 2.0))

## A one-shot effect. [gap] stops the same sound repeating too fast.
func play(name: String, volume := 0.0, gap := 0.08, pitch_jitter := 0.06) -> void:
	if not sfx_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last.get(name, -99.0) < gap:
		return
	_last[name] = now
	for p in _pool:
		if not p.playing:
			p.stream = _stream("res://assets/sfx/%s.wav" % name)
			p.volume_db = volume
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return
