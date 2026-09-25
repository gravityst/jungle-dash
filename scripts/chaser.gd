extends Node3D
## THE CHASE — Bruno the silverback gorilla and Snapper the crocodile.
##
## They chase you off the start line, then drop back out of shot. Stumble —
## clip the side of a cart, catch the top of a barrier — and they are right
## back on your heels. Stumble again before they drop back and Bruno has you.
## (The rule itself lives in GameState.stumble(); this is the part you see.)
##
## THE TRICK THAT MAKES IT WORK: the chasers do not steer. Every physics tick
## the runner's position is written into a short history, and the chasers are
## placed where the runner WAS, `gap` metres ago. So Bruno jumps exactly where
## you jumped, rides the train roof you rode, and switches lane where you
## switched — which means he can never run through an obstacle you avoided,
## with no collision, no pathfinding and no AI.

## How close they run while hot, in metres behind the runner. Close enough to
## be right there over your shoulder, far enough that Bruno's head stays below
## the camera's line of sight to the monkey.
@export var hot_gap: float = 3.5
## Where they sit while cold: behind the camera, which is 5.9 m back, so they
## are simply out of shot rather than vanishing.
@export var cold_gap: float = 12.0
## Off the start line they are closer still, for the opening chase.
@export var start_gap: float = 2.4
## How long the opening chase lasts before they fall away.
@export var intro_seconds: float = 2.4
## How fast they close in when you stumble, and fall back when you escape,
## in metres per second relative to you.
@export var close_speed: float = 16.0
@export var fall_back_speed: float = 3.2

## Sideways offset from your path. Bruno runs half a lane toward the middle so
## he never covers the monkey; Snapper runs on your OTHER side, so neither of
## them hides the runner's feet.
const BRUNO_SIDE := 1.4
const SNAPPER_SIDE := -0.62
## Snapper runs a little ahead of Bruno: the faster of the two over a short dash.
const SNAPPER_LEAD := 0.5

## About eight seconds of history at 60 Hz — far more than the widest gap
## ever needs, even at top speed.
const HISTORY := 480

var _player: Node3D
var _gap: float = 2.0
var _history: Array[Vector3] = []
var _run_time: float = 0.0
var _phase: float = 0.0
var _caught: bool = false
var _side: float = 1.0

@onready var _bruno: Node3D = $Bruno
@onready var _bruno_body: Node3D = $Bruno/Body
@onready var _snapper: Node3D = $Snapper
@onready var _snapper_body: Node3D = $Snapper/Body
@onready var _arm_l: Node3D = $Bruno/Body/ArmL
@onready var _arm_r: Node3D = $Bruno/Body/ArmR
@onready var _leg_l: Node3D = $Bruno/Body/LegL
@onready var _leg_r: Node3D = $Bruno/Body/LegR
@onready var _bruno_head: Node3D = $Bruno/Body/Head
@onready var _jaw: Node3D = $Snapper/Body/Head/Jaw


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_gap = start_gap
	GameState.died.connect(_on_died)
	# Chasers move on the physics tick like the runner, and are smoothed the
	# same way, so they do not shimmer against it.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	if _player != null:
		_record()
		_place(0.0)
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if GameState.is_running():
		_run_time += delta
		_record()
	_gap = _next_gap(delta)
	_place(delta)


## Where they WANT to be, and how fast they get there.
func _next_gap(delta: float) -> float:
	var target := cold_gap
	if GameState.on_title():
		# Lurking a few metres back, shoulders rolling, while you get ready.
		return 5.5
	if _caught:
		target = 0.9
	elif _run_time < intro_seconds:
		target = start_gap
	elif GameState.heat_time > 1.5:
		target = hot_gap
	elif GameState.heat_time > 0.0:
		# The last second and a half of heat: easing off, visibly giving up.
		target = lerpf(cold_gap, hot_gap, GameState.heat_time / 1.5)
	var speed := close_speed if target < _gap else fall_back_speed
	return move_toward(_gap, target, speed * delta)


func _record() -> void:
	_history.append(_player.global_position)
	if _history.size() > HISTORY:
		_history.pop_front()


## Where the runner was when it was at `z`. The history runs forward along
## -Z, so it is sorted, and a binary search finds the spot.
func _path_at(z: float) -> Vector3:
	if _history.is_empty():
		return _player.global_position
	# Behind the oldest sample (only at the very start): stand on the start
	# line's lane, on the ground.
	if z >= _history[0].z:
		var first := _history[0]
		return Vector3(first.x, 0.0, z)
	var lo := 0
	var hi := _history.size() - 1
	if z <= _history[hi].z:
		return _history[hi]
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _history[mid].z > z:
			lo = mid
		else:
			hi = mid
	var a := _history[lo]
	var b := _history[hi]
	var t := inverse_lerp(a.z, b.z, z) if not is_equal_approx(a.z, b.z) else 0.0
	return a.lerp(b, t)


func _place(delta: float) -> void:
	var here := _player.global_position
	var shown := _gap < cold_gap - 1.0
	_bruno.visible = shown
	_snapper.visible = shown

	# Which side Bruno runs on: toward the middle of the track, so he stays
	# in shot and clear of the monkey whichever lane you are in.
	var want_side := -1.0 if here.x > 0.5 else 1.0
	_side = move_toward(_side, want_side, 3.0 * delta) if delta > 0.0 else want_side

	var bz := here.z + _gap
	var bp := _path_at(bz)
	_bruno.global_position = Vector3(bp.x + _side * BRUNO_SIDE, bp.y, bz)
	var sz := here.z + maxf(_gap - SNAPPER_LEAD, 1.6)
	var sp := _path_at(sz)
	_snapper.global_position = Vector3(sp.x + SNAPPER_SIDE * _side, sp.y, sz)

	_animate(delta)


## Knuckle-run for Bruno, a waddling scuttle for Snapper. All procedural:
## a few sine waves on the pivots the builder named.
func _animate(delta: float) -> void:
	var speed: float = _player.get("forward_speed") if GameState.is_running() \
		else (1.2 if GameState.on_title() else 4.0)
	_phase += delta * speed * 0.62
	var s := sin(_phase)
	if _caught:
		# Arms up, reaching for the tail.
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.5, 1.0 - exp(-10.0 * delta))
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.5, 1.0 - exp(-10.0 * delta))
	else:
		_arm_l.rotation.x = s * 0.85
		_arm_r.rotation.x = -s * 0.85
	_leg_l.rotation.x = -s * 0.6
	_leg_r.rotation.x = s * 0.6
	_bruno_body.position.y = absf(s) * 0.09
	_bruno_body.rotation.z = s * 0.05
	# The head stays level while the body pitches under it — the way a
	# charging gorilla keeps its eyes on you.
	_bruno_head.rotation.x = -absf(s) * 0.12
	_bruno_head.rotation.z = -s * 0.05

	# Snapper: legs paddle in pairs, the tail whips, the jaws snap.
	for i in 4:
		var leg := _snapper_body.get_node("Leg%d" % i) as Node3D
		leg.rotation.x = sin(_phase * 1.6 + float(i) * PI * 0.5) * 0.8
	var seg: Node3D = _snapper_body.get_node("Tail0")
	var i := 0
	while seg != null:
		seg.rotation.y = sin(_phase * 1.3 - float(i) * 0.7) * 0.28
		i += 1
		seg = seg.get_node_or_null("Tail%d" % i)
	_jaw.rotation.x = -absf(sin(_phase * 0.9)) * 0.45
	_snapper_body.rotation.y = sin(_phase * 1.3) * 0.08


func _on_died() -> void:
	# Caught: Bruno lunges in and grabs. Crashed: they catch up and stand over
	# you — either way the last thing you see is them arriving.
	_caught = GameState.death_cause == "caught"
	if not _caught:
		_run_time = intro_seconds  # no intro override; fall to the gap logic
		GameState.heat_time = maxf(GameState.heat_time, 2.0)
