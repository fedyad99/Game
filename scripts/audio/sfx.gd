extends Node
## Звуки и музыка (автозагрузка Sfx). Звуки лежат в assets/audio/sfx/<имя>.wav,
## музыка — в assets/audio/music/<имя>.ogg. Всё синтезировано tools/make_sounds.py.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 16

var sfx_on := true
var music_on := true
var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}      # имя -> время, чтобы одинаковые звуки не сливались в кашу
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)


func _stream(name_: String) -> AudioStream:
	if not _cache.has(name_):
		var path := SFX_DIR + name_ + ".wav"
		_cache[name_] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name_]


## Сыграть звук. pitch_var — случайный разброс высоты, чтобы повторы не надоедали.
func play(name_: String, volume_db := 0.0, pitch_var := 0.06, min_gap := 0.04) -> void:
	if not sfx_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name_, -1.0)) < min_gap:
		return
	_last_played[name_] = now
	var s := _stream(name_)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Звук в мире: тише, если далеко от героя (камеры).
func play_at(name_: String, pos: Vector3, volume_db := 0.0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(pos)
		if d > 40.0:
			return
		volume_db -= clamp((d - 14.0) * 0.6, 0.0, 30.0)
	play(name_, volume_db)


## Включить музыку с плавным переходом. "" — выключить.
func music(name_: String, volume_db := -8.0) -> void:
	if name_ == _music_name:
		return
	_music_name = name_
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.tween_callback(old.stop)
	if name_ == "" or not music_on:
		return
	var path := MUSIC_DIR + name_ + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = true
	_music_a.stream = st
	_music_a.volume_db = -40.0
	_music_a.play()
	create_tween().tween_property(_music_a, "volume_db", volume_db, 1.5)


func set_music_on(v: bool) -> void:
	music_on = v
	var cur := _music_name
	_music_name = "-"
	if v:
		music(cur if cur != "" else "menu")
	else:
		_music_a.stop()
		_music_b.stop()
		_music_name = cur
