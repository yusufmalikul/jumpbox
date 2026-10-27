extends Node
## Plays sound effects and the looping background music.
## The sounds are made by tools/make_sounds.py.

const SFX := {
	"jump": preload("res://assets/sfx/jump.wav"),
	"boing": preload("res://assets/sfx/boing.wav"),
	"land": preload("res://assets/sfx/land.wav"),
	"step": preload("res://assets/sfx/step.wav"),
	"slide": preload("res://assets/sfx/slide.wav"),
	"kick": preload("res://assets/sfx/kick.wav"),
	"sit": preload("res://assets/sfx/sit.wav"),
	"home": preload("res://assets/sfx/home.wav"),
	"fanfare": preload("res://assets/sfx/fanfare.wav"),
	"checkpoint": preload("res://assets/sfx/checkpoint.wav"),
	"lava": preload("res://assets/sfx/lava.wav"),
	"splash": preload("res://assets/sfx/splash.wav"),
}
const MUSIC := preload("res://assets/music/park.wav")
const MUSIC_VOLUME_DB := -8.0

var music_on := true

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var stream: AudioStreamWAV = MUSIC
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()


func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	# Prefer a free player; if all are busy, take over the oldest one.
	var p := _players[_next]
	for candidate in _players:
		if not candidate.playing:
			p = candidate
			break
	_next = (_next + 1) % _players.size()
	p.stream = SFX[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


func toggle_music() -> void:
	music_on = not music_on
	_music.stream_paused = not music_on
