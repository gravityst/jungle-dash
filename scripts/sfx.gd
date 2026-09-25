extends Node
## SOUND — a tiny sound effect player, registered as an autoload so any script
## can just call `Sfx.play("coin")`.
##
## Every sound in audio/ was SYNTHESISED, not recorded: see the note in the
## README. They're plain 16-bit WAVs, so you can replace any of them with a
## real recording of the same name and nothing else has to change.
##
## Sounds are played through a small POOL of players rather than one. With a
## single player, picking up a line of coins would cut each chime off with the
## next one; the pool lets them overlap and ring out.


const POOL_SIZE := 10

const SOUNDS := {
	"coin": preload("res://audio/coin.wav"),
	"jump": preload("res://audio/jump.wav"),
	"land": preload("res://audio/land.wav"),
	"duck": preload("res://audio/duck.wav"),
	"crash": preload("res://audio/crash.wav"),
	"powerup": preload("res://audio/powerup.wav"),
	"launch": preload("res://audio/launch.wav"),
	"shield": preload("res://audio/shield.wav"),
	"whoosh": preload("res://audio/whoosh.wav"),
	"step1": preload("res://audio/step1.wav"),
	"step2": preload("res://audio/step2.wav"),
}

## Per-sound level trim, in decibels. Set by ear relative to each other.
const LEVELS := {
	"coin": -7.0, "jump": -9.0, "land": -12.0, "duck": -11.0, "crash": -3.0,
	"powerup": -4.0, "launch": -4.0, "shield": -3.0, "whoosh": -13.0, "step1": -17.0, "step2": -17.0,
}

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0

## Coins played in quick succession step UP in pitch, which is what makes
## collecting a line of them feel like a run rather than a stutter. The step
## resets once you stop picking them up.
var _coin_step: int = 0
var _coin_time: float = 0.0


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)


func _process(delta: float) -> void:
	_coin_time = maxf(_coin_time - delta, 0.0)
	if _coin_time <= 0.0:
		_coin_step = 0


## How many times each sound has been played. Test-facing; the game ignores it.
var plays := {}


## Plays a sound with a little random pitch variation, so repeated plays don't
## sound mechanically identical.
func play(sound: String, pitch: float = 1.0) -> void:
	if not SOUNDS.has(sound):
		push_warning("Sfx: no sound called '%s'" % sound)
		return
	# A tally of what has been played, per sound. Audio is the one part of a
	# game that cannot be checked by looking at the scene, so without this
	# there is no way for a headless test to tell whether the footsteps are
	# actually in step with the feet.
	plays[sound] = int(plays.get(sound, 0)) + 1
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SOUNDS[sound]
	p.volume_db = LEVELS.get(sound, -6.0)
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()


## The rising coin run.
func play_coin() -> void:
	play("coin", pow(1.0595, float(_coin_step)))   # a semitone per coin
	_coin_step = mini(_coin_step + 1, 8)
	_coin_time = 0.55
