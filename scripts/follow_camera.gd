extends Camera3D
## FOLLOW CAMERA — smooth third-person chase camera for the endless runner.
##
## Sits behind and slightly above the player, eases into place instead of
## snapping, and only PARTIALLY follows sideways lane changes — which is the
## trick Subway Surfers uses to keep all three lanes comfortably on screen.
##
## HOW TO USE
##   Attach this to a Camera3D, then set "Target" in the Inspector to your
##   Player node. That's it.


@export_group("Target")

## Drag your Player node here in the Inspector.
@export var target: Node3D

@export_group("Framing")

## Where the camera sits relative to the player, in metres.
##   Y = how high above.   Z = how far BEHIND (positive, because -Z is forward).
##
## The camera follows RIGIDLY along the track (see _process), so this is
## exactly where it sits at every speed.
## Closer and higher than it was (0, 3.05, 6.6). The old camera sat far back
## and low, so the runner was about 95 px tall in a 720 px frame — a dark blob
## you could not identify as a monkey. The reference framing for this kind of
## game puts the character at roughly a quarter of the screen height, sitting
## in the lower third, with the camera looking PAST it down the track. That is
## what `look_ahead` below is for: moving closer shrinks how much track you
## can see, and tilting the aim forward buys it back.
##
## HIGHER AND FURTHER BACK than it was (0, 3.4, 5.9), and looking DOWN the
## track rather than along it. That camera put the horizon a third of the way
## down the screen and squeezed everything 20-60 m ahead — where you decide
## what to do about the next obstacle — into 0.6% of the frame, so obstacles
## there were 5-10 px specks. From here the same stretch gets about twice the
## screen, and the runner stays the same size because the lens is longer.
@export var offset: Vector3 = Vector3(0.0, 4.4, 7.2)

## How far ahead of the runner the camera aims, in metres.
@export_range(0.0, 20.0, 0.5) var look_ahead: float = 10.0

## Field of view at the starting pace, and how much wider it opens at top
## speed. Widening the lens as you speed up is the oldest trick there is for
## selling velocity: the edges of the picture start moving faster than the
## middle, which is exactly what your eyes do when you actually run. It also
## quietly shows you more track, so it buys reaction time as well as drama.
## A longer lens than most chase cameras: 52 rather than 64. A wide lens makes
## distant things tiny, and distant things are what you need to read.
@export_range(40.0, 110.0, 1.0) var base_fov: float = 52.0
@export_range(0.0, 30.0, 0.5) var speed_fov_gain: float = 4.0

## How high above the player's feet the camera aims. Around chest height
## keeps the horizon sensible and stops the player hugging the bottom edge.
@export_range(0.0, 5.0, 0.1) var look_at_height: float = 0.0

## How much of the runner's height the camera follows. A quarter: jumps and
## train roofs still move the picture, but a 4.4 m camera cannot ride a held
## jump off a landmark up into the canopy leaves. It follows fully only when
## the runner is well above the trees' lowest branches — up on the Skyway.
@export_range(0.0, 1.0, 0.05) var vertical_follow: float = 0.20

## How much the camera slides sideways when you change lane.
##   0.0 = camera never moves sideways (very arcade, all 3 lanes always framed)
##   1.0 = camera sits perfectly behind you at all times (can feel swimmy)
##   0.5 = the sweet spot most endless runners use.
@export_range(0.0, 1.0, 0.05) var lateral_follow: float = 0.5

@export_group("Smoothing")

## How quickly the camera catches up. Higher = tighter/snappier,
## lower = floatier and more cinematic. 6 is a good starting point.
@export_range(0.5, 30.0, 0.1) var follow_sharpness: float = 6.0

## Smoothing for where the camera AIMS. Keep this a bit higher than
## follow_sharpness so the aim stays locked while the body drifts.
@export_range(0.5, 30.0, 0.1) var aim_sharpness: float = 10.0

@export_group("Crash shake")

## How hard the camera kicks when you hit something, in metres.
@export_range(0.0, 1.0, 0.01) var shake_strength: float = 0.30

## How long the kick takes to die away, in seconds.
@export_range(0.0, 2.0, 0.05) var shake_time: float = 0.45


@export_group("Title shot")

## The title screen looks at the monkey from the front — the one time the game
## shows its face — drifting slowly round it from the front-right. The jungle
## wall on the far side fills the background, so the camera never looks down
## the empty track behind the start line.
@export var title_radius: float = 3.3
@export var title_height: float = 1.55
## How long the swoop from the title shot into the chase camera takes.
@export var swoop_time: float = 1.1

## Seconds into the swoop; negative while still on the title.
var _swoop: float = -1.0
## Seconds into the wipeout orbit; negative while alive.
var _wipeout: float = -1.0
var _wipe_side: float = 1.0
var _wipe_from: Vector3
## How long the orbit round to the side of the crash takes, in REAL seconds
## (it runs through the death slow-motion, so it is timed off the clock).
@export var wipeout_time: float = 1.3
var _wipe_last_ms: int = 0

## Extra field of view that springs back to zero: a punch of speed on a
## trampoline launch or when a surge starts.
var _fov_kick: float = 0.0
var _title_t: float = 0.0
var _title_pos: Vector3
var _title_aim: Vector3


## The point the camera is currently looking at. Smoothed separately from
## the camera's own position, which is what stops the picture from wobbling.
var _aim_point: Vector3 = Vector3.ZERO

## Counts down after a crash. The shake is applied AFTER the smoothing, so it
## kicks the camera without the follow logic fighting to cancel it out.
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# The camera moves every drawn frame (_process), NOT on the physics tick,
	# so it must not be physics-interpolated itself or it would lag a frame.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	# Safety net: if the Target field in the Inspector is empty, find the
	# player automatically. The Player node is in the "player" group.
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D
		if target == null:
			push_warning("FollowCamera has no target and no node is in the 'player' group.")

	_rng.randomize()
	GameState.died.connect(_on_died)
	GameState.run_started.connect(func() -> void: _swoop = 0.0)
	GameState.surge_changed.connect(func(left: float) -> void:
		if left >= GameState.SURGE_SECONDS - 0.05:
			kick(10.0))
	if target != null and target.has_signal("launched"):
		target.connect("launched", func() -> void: kick(14.0))
	# A stumble is a jolt, not a crash: a shorter, softer kick.
	GameState.stumbled.connect(func() -> void: _shake = maxf(_shake, shake_time * 0.6))

	if target != null:
		# Jump straight to the correct spot on frame 1 instead of swooping
		# in from wherever the camera happened to be left in the editor.
		var t: Vector3 = target.global_position
		_aim_point = Vector3(t.x, _follow_y(t.y) + look_at_height, t.z - look_ahead)
		global_position = _desired_position(t)
		look_at(_aim_point, Vector3.UP)


# _process runs once per DRAWN FRAME (so 144 times a second on a 144Hz screen).
# Cameras belong here, not in _physics_process, so the motion is as smooth as
# the monitor allows rather than being capped at the 60Hz physics rate.
func _process(delta: float) -> void:
	if target == null:
		return

	# The player moves on the physics tick, which is slower than the draw rate.
	# get_global_transform_interpolated() gives us its smoothly-blended
	# position *between* physics ticks — this is what removes camera judder.
	var target_pos: Vector3 = target.get_global_transform_interpolated().origin

	if GameState.on_title():
		_title_shot(target_pos, delta)
		return
	if _wipeout >= 0.0:
		_wipeout_shot(target_pos)
		_apply_shake(delta)
		return

	# --- move the camera body ---
	# 1.0 - exp(-sharpness * delta) is the framerate-INDEPENDENT smoothing
	# formula. The naive "lerp(target, 0.1)" you'll see in tutorials moves at a
	# different speed on a 144Hz screen than on a 60Hz one. This one doesn't.
	var move_weight: float = 1.0 - exp(-follow_sharpness * delta)
	var desired: Vector3 = _desired_position(target_pos)
	var pos: Vector3 = global_position.lerp(desired, move_weight)
	# RIGID along the track. Smoothing Z made the camera trail by
	# forward_speed / follow_sharpness — 2 m at the start, 3.3 m at top speed
	# — so the runner shrank on screen exactly as the run got exciting. X and
	# Y keep their easing; that is where smoothing actually earns its keep.
	pos.z = desired.z
	global_position = pos
	_update_fov(delta)

	# --- move the point we're aiming at ---
	var aim_weight: float = 1.0 - exp(-aim_sharpness * delta)
	var desired_aim: Vector3 = Vector3(
		target_pos.x * lateral_follow,
		_follow_y(target_pos.y) + look_at_height,
		target_pos.z - look_ahead
	)
	_aim_point = _aim_point.lerp(desired_aim, aim_weight)
	_aim_point.z = desired_aim.z

	look_at(_aim_point, Vector3.UP)

	# --- the swoop out of the title shot ---
	# Blend from where the title camera was to where the chase camera is,
	# eased at both ends so it reads as one continuous move.
	if _swoop >= 0.0 and _swoop < swoop_time:
		_swoop += delta
		var k: float = smoothstep(0.0, 1.0, clampf(_swoop / swoop_time, 0.0, 1.0))
		var aim: Vector3 = _title_aim.lerp(_aim_point, k)
		global_position = _title_pos.lerp(global_position, k)
		# Arc over the top rather than cutting through the runner's head.
		global_position.y += sin(k * PI) * 1.2
		look_at(aim, Vector3.UP)

	_apply_shake(delta)


## Crash kick. Applied last, on top of the settled position. Doing it before
## the smoothing would just let the follow logic smooth it straight back out.
func _apply_shake(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		var fall := _shake / shake_time          # 1 -> 0
		var amount := shake_strength * fall * fall
		global_position += Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.4, 0.4)) * amount


func _on_died() -> void:
	_shake = shake_time
	# Swing out to the open side — away from the middle of the track, which
	# is where Bruno comes in from, so the shot catches him arriving.
	var x: float = target.global_position.x if target != null else 0.0
	_wipe_side = 1.0 if x >= 0.0 else -1.0
	_wipe_from = global_position
	_wipeout = 0.0
	_wipe_last_ms = Time.get_ticks_msec()


## THE WIPEOUT SHOT: after a crash the camera swings round from behind to
## the side of the runner and drops toward its eye line, so you actually see
## what happened — and see Bruno arrive. Timed off the wall clock, because
## the whole thing plays out inside the death slow-motion.
func _wipeout_shot(target_pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	_wipeout += float(now - _wipe_last_ms) / 1000.0
	_wipe_last_ms = now
	var k: float = smoothstep(0.0, 1.0, clampf(_wipeout / wipeout_time, 0.0, 1.0))
	var ang: float = deg_to_rad(100.0) * k
	var r: float = lerpf(offset.z, 4.4, k)
	var h: float = lerpf(offset.y, 1.9, k)
	var orbit := target_pos + Vector3(_wipe_side * sin(ang) * r, h, cos(ang) * r)
	global_position = _wipe_from.lerp(orbit, minf(k * 3.0, 1.0)) if k < 0.34 else orbit
	look_at(target_pos + Vector3(0.0, 1.0, 0.0), Vector3.UP)


## Slowly circling the waving monkey, from in front of it.
func _title_shot(target_pos: Vector3, delta: float) -> void:
	_title_t += delta
	# Swing between about 25 and 55 degrees round from straight in front.
	var ang: float = deg_to_rad(40.0 + 15.0 * sin(_title_t * 0.35))
	_title_pos = target_pos + Vector3(sin(ang) * title_radius, title_height,
		-cos(ang) * title_radius)
	_title_aim = target_pos + Vector3(-0.35, 1.15, 0.0)
	global_position = _title_pos
	look_at(_title_aim, Vector3.UP)
	fov = lerpf(fov, 55.0, 1.0 - exp(-4.0 * delta))
	# The chase camera starts from here when the run begins.
	_aim_point = Vector3(target_pos.x * lateral_follow, _follow_y(target_pos.y) + look_at_height,
		target_pos.z - look_ahead)


## Opens the lens as the runner speeds up, smoothly enough that you feel it
## rather than see it happen.
func _update_fov(delta: float) -> void:
	if target == null or not ("forward_speed" in target):
		return
	var lo: float = target.start_speed
	var hi: float = target.max_speed
	var k: float = clampf((target.forward_speed - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
	# Same frame-rate-independent smoothing as everything else here. Snapping
	# the FOV straight to the target would make the whole picture twitch every
	# time the speed changed.
	# The lens is the smoothed speed FOV; the kick rides on top of it and
	# springs back on its own, so the two never fight over one number.
	if _lens < 0.0:
		_lens = fov
	_lens = lerpf(_lens, base_fov + speed_fov_gain * k, 1.0 - exp(-2.5 * delta))
	_fov_kick = lerpf(_fov_kick, 0.0, 1.0 - exp(-3.2 * delta))
	fov = _lens + _fov_kick


var _lens: float = -1.0


## Punches the lens wider by `degrees`, springing back over about half a
## second. Anything can call it for a moment that should feel fast.
func kick(degrees: float) -> void:
	_fov_kick += degrees


## Works out where the camera would ideally sit for a given player position.
func _desired_position(target_pos: Vector3) -> Vector3:
	return Vector3(
		# Only partially follow the lane change — see lateral_follow above.
		target_pos.x * lateral_follow + offset.x,
		_follow_y(target_pos.y) + offset.y,
		target_pos.z + offset.z
	)


## The part of the runner's height the camera follows: a quarter near the
## ground, rising to all of it by the time the runner is up on the Skyway
## deck (7 m), where there is no canopy overhead to hit.
func _follow_y(y: float) -> float:
	# Ramp from 3.6 m: the highest the runner can get UNDER the canopy is a
	# spring jump off a landmark, 3.35 m, and that must still leave the lens
	# 0.3 m below the lowest leaves (5.37 m). tools/test_probe.tscn checks.
	return y * lerpf(vertical_follow, 1.0, smoothstep(3.6, 6.0, y))
