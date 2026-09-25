extends CharacterBody3D
## PLAYER — 3-lane endless runner controller (Subway Surfers / Jungle Dash style).
##
## WHAT THIS DOES
##   * Runs forward automatically, forever, at a constant speed.
##   * Lets you slide between 3 lanes: left / centre / right.
##   * Lets you jump.
##   * Tells the AnimationPlayer whether to show "run" or "jump".
##
## HOW TO CHANGE THE FEEL WITHOUT CODING
##   Every setting marked "@export" below shows up in the INSPECTOR panel
##   (right-hand side of the Godot editor) when you click the Player node.
##   Run the game, then drag those numbers around to tune it live.
##
## DIRECTIONS IN GODOT 3D
##   -Z is forward.   +X is right.   +Y is up.
##   So "running forward" means moving in the NEGATIVE Z direction.


# =============================================================================
#  SETTINGS — these all appear in the Inspector
# =============================================================================


## Fired by a trampoline launch. The camera punches its lens wide on it.
signal launched

@export_group("Running")

## Speed you start each run at, in metres per second. 12 is a brisk jog.
@export_range(0.0, 60.0, 0.5) var start_speed: float = 12.0

## The fastest the game will ever get. The run ramps up to this and stops.
##
## Don't raise this without doing the sum. Obstacle rows are 15 m apart, so the
## warning you get is 15 / max_speed seconds. A person needs about 0.25 s to
## react plus 0.35 s for the lane change to finish — call it 0.6 s — so:
##
##     20 m/s -> 0.75 s   comfortable
##     24 m/s -> 0.62 s   right on the edge
##     30 m/s -> 0.50 s   not reactable; you die to things you never saw
##
## If you want it faster, space the rows further apart too (ROW_Z and
## CHUNK_LENGTH), or drop to one row per piece.
@export_range(0.0, 80.0, 0.5) var max_speed: float = 20.0

## How much speed is added per second of running. At 0.22 it takes about
## 55 seconds to go from 12 to 24 — fast enough to notice, slow enough to
## stay fair. Set it to 0 for a constant-speed game.
@export_range(0.0, 3.0, 0.01) var speed_ramp: float = 0.22

@export_group("Lanes")

## NOTE: lane COUNT and lane WIDTH are not set here. They live in
## scripts/lane_config.gd, because the track needs the exact same numbers —
## if the two ever disagreed, the lanes you see wouldn't be the lanes you
## run in. Change them there and both follow.

## How snappily you slide sideways into the next lane.
## Higher = faster, more arcade. Subway Surfers is very snappy — the switch is
## basically over in a fifth of a second — so this is deliberately high.
@export_range(1.0, 40.0, 0.5) var lane_switch_sharpness: float = 19.0

## How far the character BANKS into a lane change, in degrees at full speed.
## This is the single most recognisable bit of the feel: the runner leans into
## the turn and straightens up as it arrives. Set it to 0 and the character
## slides sideways like a chess piece.
@export_range(0.0, 45.0, 1.0) var lean_degrees: float = 24.0

## How quickly the lean follows the movement. Lower lags behind and feels
## heavy; too high and it snaps and looks robotic.
@export_range(1.0, 30.0, 0.5) var lean_response: float = 11.0

## Hard speed limit on the sideways slide, so a big lane_width can't fling you.
@export_range(1.0, 60.0, 0.5) var max_strafe_speed: float = 18.0

@export_group("Jumping")

## Upward speed the instant you jump. Higher = higher jump.
## Raised from 8.5 on player feedback: at 8.5 the apex was 1.49 m, which only
## just gets you onto a landmark roof at 1.10 m — it cleared by 39 cm, so
## anything short of a perfectly timed jump clipped the edge. 9.2 lifts the
## apex to 1.72 m and makes that a landing rather than a squeak.
##
## It cannot go much higher: holding the key adds more on top, and the total
## has to stay under 2.35 m or you start landing on the roofs of the stone idol
## (2.40 m) and the tree (2.60 m), which are meant to be gone AROUND.
@export_range(0.0, 30.0, 0.1) var jump_velocity: float = 9.2

## Downward acceleration. Higher = heavier, faster-falling, more arcade.
@export_range(0.0, 80.0, 0.5) var gravity: float = 26.0

## Makes FALLING faster than RISING. This is a classic platformer trick that
## makes jumps feel snappy instead of floaty. 1.0 = off, 1.6 = nice.
@export_range(1.0, 4.0, 0.05) var fall_gravity_multiplier: float = 1.6

## HANG TIME. Near the top of a jump, gravity is scaled by this — so the arc
## slows as it peaks instead of turning over sharply.
##
## Almost every game that feels good to jump in does this. The top of the arc
## is where you are reading the world and deciding what to do, and it is the
## part a pure parabola gives you least of. Slowing it does not make the jump
## higher in any meaningful way (about 10 cm), it makes it LEGIBLE.
@export_range(0.2, 1.0, 0.05) var apex_gravity_scale: float = 0.55

## How close to the top of the arc counts as "the apex", in metres per second.
@export_range(0.0, 8.0, 0.1) var apex_window: float = 2.5

## How much gravity is cancelled while the jump key is HELD and you are still
## rising, in metres per second squared.
##
## This is deliberately the opposite way round from the usual platformer
## variable jump. The normal trick is that a tap gives you a SHORT hop and
## holding gives the full one — but in a runner that is a trap, because almost
## every jump needs to be near maximum to clear anything, so a mistimed tap is
## a death with no lesson in it. I built it that way first and measured it: a
## quick tap apexed at 0.93 m against a 0.78 m boulder, which is 15 cm of
## margin for a player who did nothing wrong.
##
## So a tap gives the FULL ordinary jump — exactly what it always did — and
## holding buys you extra height on top. At 6.0 the effective gravity while
## rising drops from 26 to 20, which lifts the apex from 1.49 m to about
## 1.81 m: enough to reach things and to feel like a real choice, and still
## comfortably under the stone idol at 2.40 m and the tree at 2.60 m, which are
## meant to be gone around rather than over.
##
## It also means nothing that jumps in CODE — the swipe handler, the test bot —
## is affected at all, because there is no key held down for them.
@export_range(0.0, 20.0, 0.5) var jump_hold_boost: float = 6.0

## Grace period AFTER walking off a ledge where a jump still works.
## Stops the "I pressed jump and nothing happened!" feeling. In seconds.
@export_range(0.0, 0.4, 0.01) var coyote_time: float = 0.12

## Grace period BEFORE landing where a jump press is remembered and fires
## the moment you touch down. Also in seconds.
@export_range(0.0, 0.4, 0.01) var jump_buffer_time: float = 0.14

## How long a trampoline launch is protected from being cancelled, in seconds.
## Only needs to outlast jump_buffer_time (0.14) plus the frame or two the body
## takes to actually leave the ground; 0.35 is comfortable margin.
@export_range(0.0, 1.0, 0.01) var launch_lock_time: float = 0.35

## How strong the SECOND jump is, as a fraction of the first, while the spring
## power-up is running.
##
## 0.70 is not a taste call. A first jump peaks at 1.39 m; a second jump of
## 0.70 x 8.5 = 5.95 m/s launched from there adds 5.95^2/52 = 0.68 m, for a
## ceiling of 2.07 m. That has to stay UNDER the shortest thing you are meant
## to go around rather than over — the stone idol at 2.40 m and the tree at
## 2.60 m — or you would land on top of dodge-only obstacles, which the crash
## check forgives and which nothing in the game is designed for.
## Lowered from 0.70 when the base jump went from 8.5 to 9.2. The two
## multiply: at 0.70 the combined apex measured 2.45 m, which is OVER the
## 2.35 m line and therefore lands you on the roof of the stone idol (2.40 m).
## The cap is on the TOTAL, so raising the first jump has to lower this one.
@export_range(0.2, 1.0, 0.05) var double_jump_scale: float = 0.58

## The hard ceiling on how high the runner can get above the ground it left,
## whatever combination of jump, hold and spring is used.
##
## It exists because the stone idol tops out at 2.40 m and the tree at 2.60 m,
## and both are meant to be gone AROUND. Landing on one is forgiven by the
## crash check, so the runner would end up standing on a dodge-only obstacle —
## behaviour nothing else in the game accounts for.
@export_range(1.0, 5.0, 0.05) var max_air_height: float = 2.25

## How long you are untouchable after a shield saves you, in seconds. It has to
## be long enough to physically clear the obstacle you just hit: at the 12 m/s
## starting speed, 0.9 s carries you 10.8 m, and the deepest obstacle in the
## game is 1.15 m front to back.
@export_range(0.0, 3.0, 0.05) var invuln_time: float = 0.9

@export_group("Juice")
## How much the runner squashes on a hard landing, as a fraction of height.
## Squash-and-stretch is the oldest trick in animation and it is what makes a
## landing feel like it had weight rather than just stopping.
@export_range(0.0, 0.5, 0.01) var squash_amount: float = 0.20
## How long the squash takes to spring back out, in seconds.
@export_range(0.05, 1.0, 0.01) var squash_time: float = 0.22

@export_group("Ducking")

## How long a duck lasts, in seconds. The player shrinks for this long and
## then pops back up on its own — you tap, you don't hold.
@export_range(0.1, 1.5, 0.05) var duck_time: float = 0.55

## How tall the player is while ducking, in metres. Must be comfortably under
## the 1.05 m underside of the vines and branches, and the standing height is
## 1.8 m, so 0.9 leaves 0.15 m of clearance either way.
@export_range(0.4, 1.6, 0.05) var duck_height: float = 0.9

## Ducking in MID-AIR slams you back down instead of being ignored. This is
## straight out of Subway Surfers and it matters more than it sounds: without
## it, a mistimed jump means waiting helplessly to land on the thing that is
## about to kill you. With it you always have an option.
## The slam. Raised from 26: the drop has to feel decisive, and 30 m/s is
## still only 0.50 m of travel per physics frame, comfortably inside the 0.80 m
## thickness of the treetop deck — any faster and a slam could tunnel through
## it in a single tick.
@export_range(0.0, 60.0, 1.0) var fast_fall_speed: float = 30.0


@export_group("Crashing")

## How forgiving landing on top of an obstacle is.
##
## When you touch an obstacle we look at the direction of the surface you
## touched. Landing on its flat top gives an upward-pointing surface (y near
## 1.0); smacking into its side gives a sideways one (y near 0.0). Anything
## above this number counts as "I landed on it" and is forgiven.
## Set it to 1.1 to make ANY contact fatal.
@export_range(0.0, 1.1, 0.05) var land_forgiveness: float = 0.7

## Below land_forgiveness but above THIS, a hit is a clipped edge — you caught
## the top lip of a hurdle — and you stumble over it rather than crash.
## Under it, you ran into the face of the thing, and that is still a crash.
@export_range(0.0, 1.0, 0.05) var stumble_lip: float = 0.35

## How long a stumble protects you from a second hit on the same obstacle.
@export_range(0.0, 2.0, 0.05) var stumble_invuln: float = 0.5


@export_group("Touch / Swipe")

## Turn swipe controls on or off (they work on desktop too if you drag
## the mouse, once "Emulate Touch From Mouse" is enabled in Project Settings).
@export var swipe_enabled: bool = true

## How many pixels you must drag before it counts as a swipe.
@export_range(10.0, 300.0, 5.0) var swipe_threshold: float = 60.0


# =============================================================================
#  INTERNAL STATE — you don't need to touch anything below here
# =============================================================================

## Which lane we're in right now. 0 = left, 1 = centre, 2 = right.
var current_lane: int = 1

## The speed we're actually running at right now. Starts at start_speed and
## climbs toward max_speed. Read this if you want to show a speedometer.
var forward_speed: float = 12.0

## Where we were last physics frame, used to tell GameState how far we moved.
var _last_z: float = 0.0

## Tracks the air-to-ground transition so the landing thud fires once.
var _was_airborne: bool = false

## True between slamming down and touching the ground, so the landing can
## roll straight out of it.
var _fast_falling: bool = false

## The current bank angle, in radians. Smoothed toward the target every frame.
var _lean: float = 0.0

## Countdown timers for the coyote-time and jump-buffer tricks explained above.
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

## Counts down after a LAUNCH (a trampoline). While it is running, the ordinary
## jump is suppressed and the mid-air slam is refused.
##
## This exists because of a real, repeatable bug. An Area3D's body_entered is
## emitted from inside the physics server's query flush, which happens BEFORE
## _physics_process on that tick — so on the frame after you touch a trampoline
## is_on_floor() is STILL true. That refills the coyote timer below, and if the
## jump key happened to be buffered, the line `velocity.y = jump_velocity` is a
## flat ASSIGNMENT: it would overwrite a 22 m/s launch with an 8.5 m/s hop and
## quietly drop you back on the ground. The lock closes that window.
var _launch_lock: float = 0.0

## True from a trampoline launch until the next landing. Separate from
## _launch_lock, which is a short window: this one has to last the WHOLE rise,
## because the duck key is also the slide key and players hold it down.
var _launched: bool = false

## Counts down after a shield has saved you. While it runs, obstacles cannot
## kill you — which is what lets you actually get clear of the thing you hit.
var _invuln_timer: float = 0.0
## The lane you were in before the last lane change — where a side hit
## throws you back to, because you were standing there a moment ago.
var _prev_lane: int = 1
## Counts down through the stumble wobble.
var _stumble_time: float = 0.0
## When the last slide started, for "stood up too soon under the vines".
var _duck_started_ms: int = -100000

## How hard the last landing was, 0 (none) to 1 (a slam), decaying to zero.
var _squash: float = 0.0
## The downward speed carried into the current landing. Captured while still in
## the air, because move_and_slide zeroes velocity.y the moment the floor is
## touched — reading it after the landing is detected always gives zero.
var _air_vy: float = 0.0
## Set when a fresh duck starts, so a second duck mid-roll replays the tumble
## instead of silently doing nothing.
var _restart_roll: bool = false

## Whether the mid-air jump is still unspent. Refilled on every landing, so the
## spring gives you one extra jump per airborne stretch rather than a
## helicopter.
var _air_jump_ready: bool = false

## The height of the last ground the runner stood on. The mid-air jump is
## capped relative to THIS, so however high the first jump went, the second can
## never carry the pair past the ceiling.
var _ground_y: float = 0.0

## Where in the run cycle the feet actually touch down, as a time in seconds
## into the 0.6 s animation. These are the CONTACT keys from the cycle itself
## (see _make_run_animation in build_scenes.gd) — the left foot lands at the
## start and the right half a stride later.
const STEP_PHASES: Array[float] = [0.0, 0.3]
## How much faster than the authored 0.6 s the run cycle plays at the
## starting pace. 1.2 makes it 0.5 s — four steps a second, a sprint; at the
## authored rate it read as a jog.
const STRIDE_RATE := 1.2

## Where the run animation was last frame, for spotting the moment it crosses a
## footfall. -1 means "not running", so the next step is not double-counted.
var _last_anim_pos: float = -1.0

## Whether the jump in progress can still be extended by holding the key. Only
## true for a jump that came FROM the keyboard: a jump asked for in code has no
## key to hold, and should behave exactly as it always did.
var _jump_cuttable: bool = false
## Whether the pending buffered jump came from the keyboard.
var _buffer_from_key: bool = false

## Where the finger/mouse first touched down, used to measure a swipe.
var _touch_start: Vector2 = Vector2.ZERO
var _swipe_already_handled: bool = false
## Whether a finger is actually down right now. Without this check, a stray
## drag event with no touch-down before it would be measured against
## _touch_start's default of (0, 0) — i.e. against the top-left corner of the
## screen — which looks like an enormous swipe and fires a lane change out of
## nowhere. "Emulate Touch From Mouse" makes that easy to hit on desktop.
var _touch_active: bool = false

## Grabbed once when the scene loads, so we can trigger animations.
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _body: Node3D = $Visual/Body
@onready var _near: Area3D = $NearMiss
@onready var _sparkles: Array[Node] = $Effects.get_children().filter(
	func(n: Node) -> bool: return n.name.begins_with("Sparkle"))
@onready var _dust: CPUParticles3D = $Effects/Dust
@onready var _board: Node3D = $Board
@onready var _board_sparks: CPUParticles3D = $Board/Sparks
@onready var _splinters: CPUParticles3D = $Effects/Splinters
@onready var _power_burst: CPUParticles3D = $Effects/PowerBurst
@onready var _held_magnet: Node3D = $Visual/Body/ArmRight/Elbow/HeldMagnet
@onready var _boots: Array[Node3D] = [$Visual/Body/LegLeft/Knee/Ankle/SpringBoot,
	$Visual/Body/LegRight/Knee/Ankle/SpringBoot]
const POWER_COLORS := {"magnet": Color(1.0, 0.30, 0.22), "plank": Color(0.35, 0.60, 1.0),
	"surge": Color(0.82, 0.45, 1.0), "spring": Color(0.35, 0.92, 1.0)}
var _sparkle_next: int = 0
var _coins_seen: int = 0

## Obstacles currently inside the near-miss column. An obstacle only scores
## when it LEAVES, because leaving alive is what proves you cleared it.
var _in_column := {}

## Counts down while ducking. Above zero = ducking.
var _duck_timer: float = 0.0
## The standing height, remembered at startup so we can restore it.
var _stand_height: float = 1.8

## The animation we last ASKED for. We track this ourselves instead of reading
## the AnimationPlayer, because a non-looping animation (like "jump") reports
## an EMPTY current_animation once it finishes — which would make us restart it
## mid-air every time a jump lasts longer than the animation does.
var _requested_anim: String = ""


func _ready() -> void:
	# Start in the centre lane, exactly on it, so we don't slide in at the start.
	current_lane = LaneConfig.LANE_COUNT / 2
	_prev_lane = current_lane
	global_position.x = lane_to_x(current_lane)
	forward_speed = start_speed
	_last_z = global_position.z

	# Give this player its OWN capsule. Shapes are shared between every copy
	# of a scene, so without duplicate() a second player ducking would shrink
	# the first one too.
	_collision.shape = _collision.shape.duplicate()
	_stand_height = (_collision.shape as CapsuleShape3D).height
	# Physics interpolation smooths movement between physics ticks — but that
	# also means a TELEPORT (like the line above) would be shown as a fast
	# slide from the old spot. This tells the engine "that wasn't movement",
	# so frame one draws us already in place.
	reset_physics_interpolation()

	_near.body_entered.connect(_on_column_entered)
	_near.body_exited.connect(_on_column_exited)
	_coins_seen = GameState.coins
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.shield_changed.connect(_on_shield_changed)
	GameState.powerup_collected.connect(func(kind: String) -> void:
		_power_burst.color = POWER_COLORS.get(kind, Color.WHITE)
		_power_burst.restart())
	GameState.restarted.connect(func() -> void: _in_column.clear())

	# Cross-fade between poses instead of snapping. Without this, run -> jump
	# swaps every limb in a single frame, which is a visible pop.
	#
	# The roll is the exception and MUST stay at zero. Its last key rotates the
	# body by a full -TAU, and a blend out of that value would unwind the whole
	# 360 degrees over the fade — you would watch the monkey spin backwards
	# every time it stood up.
	if _anim != null:
		_anim.playback_default_blend_time = 0.10
		_anim.set_blend_time("roll", "run", 0.0)
		_anim.set_blend_time("roll", "jump", 0.0)
		_anim.set_blend_time("roll", "surf", 0.0)
		_anim.set_blend_time("roll", "jump_b", 0.0)


# =============================================================================
#  THE MAIN LOOP
#  _physics_process runs at a fixed rate (60 times a second by default).
#  All movement and physics MUST go here, not in _process.
# =============================================================================

func _physics_process(delta: float) -> void:
	if GameState.is_running():
		_ramp_speed(delta)
		_update_duck(delta)
		_handle_lane_input()
		_apply_forward_run()
		_apply_lane_slide()
		# AFTER the slide, not before it: the lean is computed from velocity.x,
		# and reading it first meant the body was always banking one whole
		# physics tick behind the movement that caused it.
		_update_lean(delta)
		_apply_gravity_and_jump(delta)
		_invuln_timer = maxf(_invuln_timer - delta, 0.0)
		_update_squash(delta)
	else:
		_apply_death_slide(delta)
		# Dead is dead: never leave invulnerability banked across a restart.
		_invuln_timer = 0.0

	# move_and_slide() reads the built-in "velocity" property we just filled in,
	# moves the body, and slides along walls instead of getting stuck on them.
	# In Godot 4 it takes NO arguments — old Godot 3 tutorials pass some. Ignore those.
	move_and_slide()

	if GameState.is_running():
		_report_distance()
		# Must come AFTER move_and_slide() — that's the call that works out
		# what we bumped into, and there's nothing to inspect before it runs.
		_check_for_crash()

	_update_animation()
	_update_footsteps()


# -----------------------------------------------------------------------------
#  SPEEDING UP
# -----------------------------------------------------------------------------

func _ramp_speed(delta: float) -> void:
	# Creeps toward max_speed and then stays there. This is the whole
	# "gets harder the longer you survive" mechanic.
	forward_speed = minf(forward_speed + speed_ramp * delta, max_speed)


## Banks the character into a lane change and straightens it out again.
##
## The target angle comes from how fast we are ACTUALLY moving sideways, not
## from which lane we are aiming at, so it builds and releases with the motion
## instead of snapping on and off with the key press.
func _update_lean(delta: float) -> void:
	if is_ducking():
		# The roll animation is driving Body outright, so we must not write to
		# it — but the stored lean still has to unwind, or it is handed back at
		# whatever angle it held when the roll started and the body snaps into
		# a hard bank the instant you stand up.
		_lean = lerpf(_lean, 0.0, 1.0 - exp(-lean_response * delta))
		return
	# Coming out of a roll, put the pivot back where the animation left it.
	if _body != null and not is_zero_approx(_body.position.y):
		_body.position = Vector3.ZERO
		_body.rotation.x = 0.0

	var sideways: float = clampf(velocity.x / maxf(max_strafe_speed, 0.001), -1.0, 1.0)
	# Negative: moving right (+x) should tip the top of the body to the right,
	# which is a NEGATIVE rotation about Z.
	var target: float = -sideways * deg_to_rad(lean_degrees)
	# Framerate-independent smoothing, same formula as the camera uses.
	var weight: float = 1.0 - exp(-lean_response * delta)
	_lean = lerpf(_lean, target, weight)
	if _body != null:
		# Bank AND turn. A runner changing lanes does not just tip sideways,
		# they aim where they are going, and the small yaw is most of what
		# makes the lane change feel like steering rather than sliding.
		_body.rotation = Vector3(0.0, _lean * 0.55, _lean)
		# The stumble: a fast wobble that dies away, like catching yourself.
		if _stumble_time > 0.0:
			_stumble_time = maxf(_stumble_time - delta, 0.0)
			var k: float = _stumble_time / 0.5
			_body.rotation.z += sin(_stumble_time * 38.0) * 0.32 * k
			_body.rotation.x += 0.22 * k


# -----------------------------------------------------------------------------
#  SCORING
# -----------------------------------------------------------------------------

func _report_distance() -> void:
	# How far forward we actually travelled since last frame. Using our REAL
	# movement rather than speed * delta means being blocked doesn't earn points.
	var moved: float = _last_z - global_position.z
	_last_z = global_position.z
	GameState.add_distance(maxf(moved, 0.0))


# -----------------------------------------------------------------------------
#  CRASHING
# -----------------------------------------------------------------------------

func _check_for_crash() -> void:
	if _invuln_timer > 0.0:
		return
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var collider := hit.get_collider()
		# The ground turns up in this list on literally every frame, so we
		# can't just treat "touched something" as death. Only nodes tagged
		# as obstacles count.
		if collider == null or not collider.is_in_group("obstacle"):
			continue
		# get_normal() points out of the surface we touched. Straight up
		# (y near 1) means we landed on top of a low hurdle — that's allowed.
		var n: Vector3 = hit.get_normal()
		if n.y > land_forgiveness:
			continue
		# Pointing SIDEWAYS means you steered into the side of it while
		# changing lane. Pointing half up means you clipped the top edge.
		# Neither is running into it, and neither ends the run: you stumble,
		# and the chaser closes in. Only a face pointing back down the track
		# at you — a head-on hit — is a crash.
		# Tell GameState what happened, before anything reacts to it, so the
		# HUD can say WHY: which obstacle, which face, and what you were doing.
		GameState.note_hit({
			"slot": int(collider.get_meta(&"slot", -1)),
			"what": String(collider.get_meta(&"what", "")),
			"landmark": String(collider.name) == "Landmark0",
			"how": "side" if absf(n.x) > 0.6 else ("lip" if n.y > stumble_lip else "face"),
			"airborne": not is_on_floor(),
			"rising": not is_on_floor() and _air_vy > 0.0,
			"ducking": is_ducking(),
			"ms_since_duck": Time.get_ticks_msec() - _duck_started_ms,
		})
		if absf(n.x) > 0.6 or n.y > stumble_lip:
			_stumble(collider, absf(n.x) > 0.6)
			return
		# A shield turns the fatal hit into a scrape.
		if GameState.spend_shield():
			_survive_hit(collider)
			return
		GameState.die()
		return


## Bounced off the side of something, or tripped over its top edge.
##
## A side hit throws you back into the lane you came from, which you were
## standing in a moment ago and so is clear at this depth. A clipped edge
## switches that obstacle's collider off, exactly as a shield does, so you
## stumble over it rather than being pinned against it.
func _stumble(collider: Node, from_side: bool) -> void:
	if from_side and _prev_lane != current_lane:
		current_lane = _prev_lane
	else:
		_survive_hit(collider)
	_invuln_timer = maxf(_invuln_timer, stumble_invuln)
	forward_speed = maxf(start_speed, forward_speed * 0.92)
	_stumble_time = 0.5
	Sfx.play("land")
	GameState.stumble()


## Being saved by a shield is only half the job. The obstacle is still SOLID,
## so without this you would survive the tree and then be pinned flat against
## it, unable to move, which is worse than dying. Switching its collider off
## lets you pass straight through the thing that nearly got you.
##
## Nothing has to switch it back on: every obstacle's collider is re-enabled
## from scratch the next time its chunk is recycled and re-rolled.
func _survive_hit(collider: Node) -> void:
	_invuln_timer = invuln_time
	var shape := collider.get_node_or_null("CollisionShape3D")
	if shape != null:
		shape.set_deferred("disabled", true)


## Dead: skid to a stop rather than halting dead in mid-stride, and keep
## falling normally so we settle onto the ground instead of hovering.
func _apply_death_slide(delta: float) -> void:
	_duck_timer = 0.0
	_fast_falling = false
	velocity.x = move_toward(velocity.x, 0.0, 45.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 45.0 * delta)
	# Same heavier fall the living player gets. Without the multiplier a body
	# knocked off the 7 m treetop deck drifts down at half the speed it was
	# falling a moment earlier, which looks like the game has given up.
	velocity.y -= gravity * fall_gravity_multiplier * delta


# -----------------------------------------------------------------------------
#  LANES
# -----------------------------------------------------------------------------

## Converts a lane number (0, 1, 2) into a world X position.
## With 3 lanes at 2.5 m this gives: -2.5, 0.0, +2.5
## The maths lives in lane_config.gd so the track agrees with us exactly.
func lane_to_x(lane: int) -> float:
	return LaneConfig.lane_to_x(lane)


## Moves us one lane left or right, refusing to go past the edges.
func change_lane(direction: int) -> void:
	# clampi keeps the result inside 0..2, so pressing left in the
	# left-most lane simply does nothing instead of running off the road.
	var target := clampi(current_lane + direction, 0, LaneConfig.LANE_COUNT - 1)
	if target != current_lane:
		_prev_lane = current_lane
	current_lane = target


func _handle_lane_input() -> void:
	# "just_pressed" fires only on the frame the key goes DOWN, so holding
	# the key does not rocket you across all three lanes.
	if Input.is_action_just_pressed("move_left"):
		change_lane(-1)
	if Input.is_action_just_pressed("move_right"):
		change_lane(1)


func _apply_lane_slide() -> void:
	# Where we WANT to be, versus where we ARE.
	var target_x: float = lane_to_x(current_lane)
	var distance_to_target: float = target_x - global_position.x

	# The further away we are, the faster we move — so the slide starts fast
	# and eases smoothly into place, with no sudden stop. (This is a
	# "proportional controller", the simplest smooth-motion trick there is.)
	velocity.x = distance_to_target * lane_switch_sharpness
	velocity.x = clampf(velocity.x, -max_strafe_speed, max_strafe_speed)

	# Once we're basically there, stop completely so we don't jitter forever.
	if absf(distance_to_target) < 0.01:
		velocity.x = 0.0
		global_position.x = target_x

	# NOTE: we set VELOCITY rather than setting position directly. Setting
	# position directly would teleport us straight through obstacles.


# -----------------------------------------------------------------------------
#  RUNNING & JUMPING
# -----------------------------------------------------------------------------

func _apply_forward_run() -> void:
	# Negative Z is forward in Godot. This never changes and never stops —
	# that's what makes it an *endless* runner.
	velocity.z = -forward_speed


func _apply_gravity_and_jump(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	_launch_lock = maxf(_launch_lock - delta, 0.0)
	var launching: bool = _launch_lock > 0.0

	# --- coyote time: remember that we were recently on the ground ---
	# A launch forces this to zero rather than letting the floor refill it: for
	# the first frame or two after a bounce the body has not physically left
	# the ground yet, and without this the launch is cancellable.
	if launching:
		_coyote_timer = 0.0
	elif on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# --- jump buffer: remember that jump was recently pressed ---
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
		_buffer_from_key = true
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# --- do the jump if both a press and a floor are "remembered" ---
	# `took_off` exists because `on_floor` was read at the TOP of this function,
	# from the previous move_and_slide. Jumping sets _was_airborne on the very
	# same frame, so without this flag the landing test below sees
	# "on the floor AND was airborne" and fires on the take-off frame — playing
	# the landing thud underneath every single jump.
	# Refill on the ground too, not only on the landing frame — otherwise
	# picking the spring up while already running gives you nothing until the
	# next time you happen to land.
	if on_floor:
		_air_jump_ready = true
		_ground_y = global_position.y

	# THE SECOND JUMP. Only in the air, only once per airborne stretch, only
	# while the spring is running, and never out of a trampoline launch — the
	# launch is already nine metres of air and a second jump on top of it would
	# put you over the treetop deck entirely.
	if not launching and not on_floor and _coyote_timer <= 0.0 \
			and _air_jump_ready and _jump_buffer_timer > 0.0 \
			and GameState.spring_active():
		# Capped by HEIGHT, not by a fixed strength. Scaling the second jump
		# down could never work: a held first jump already peaks at 2.21 m, so
		# to stay under the ceiling the second one would have to add almost
		# nothing, which makes the power-up pointless exactly when you are
		# playing well. Clamping to the remaining head room instead means the
		# spring always gives you a real second jump — just never one that puts
		# you on a roof you are supposed to run around.
		var risen: float = maxf(global_position.y - _ground_y, 0.0)
		var head_room: float = maxf(max_air_height - risen, 0.0)
		var capped: float = sqrt(2.0 * gravity * head_room)
		velocity.y = minf(jump_velocity * double_jump_scale, capped)
		_air_jump_ready = false
		# The hold bonus is spent on the FIRST jump and does not carry into the
		# second. Without this the two compound: holding the key through a
		# spring-assisted double jump measured 3.06 m, well over the 2.35 m
		# ceiling that keeps you off the roofs of the stone idol and the tree.
		# Two tests each guarded one half of that and neither tried both.
		_jump_cuttable = false
		_jump_buffer_timer = 0.0
		_fast_falling = false
		Sfx.play("launch")

	var took_off := false
	if not launching and _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		Sfx.play("jump")
		GameState.tally("jumps")
		_was_airborne = true
		took_off = true
		_jump_cuttable = _buffer_from_key
		_buffer_from_key = false
		# Jumping out of a slide is a real move, so let it cancel the roll
		# rather than leaving the character tumbling through the air.
		_duck_timer = 0.0

	# Landing: the frame we go from not-on-floor to on-floor.
	#
	# `not launching` is doing real work here. For a frame or two after a
	# trampoline fires, the body has not physically left the ground yet, so
	# is_on_floor() is still true while _was_airborne has just been set — which
	# looks exactly like a landing. Without this guard a launch would play the
	# landing sound, could start a roll, and would clear _launched immediately,
	# re-opening the duck-slam that _launched exists to close.
	if not on_floor:
		_air_vy = velocity.y

	if on_floor and _was_airborne and not launching and not took_off:
		_was_airborne = false
		_launched = false
		# Scale the squash by how hard the landing was. A gentle hop barely
		# registers; dropping off the treetop deck at 13 m/s gives a real thud.
		_squash = clampf(absf(_air_vy) / 18.0, 0.0, 1.0)
		_air_jump_ready = true
		Sfx.play("land")
		# Landing on the roof of a mine train counts toward the journal.
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_normal().y > land_forgiveness and c.get_collider() != null \
					and String(c.get_collider().name) == "Landmark0":
				GameState.tally("trains")
				break
		# Only a real landing kicks up dust; stepping off a kerb should not.
		if _squash > 0.25 and _dust != null:
			_dust.restart()
		# Land out of a slam and you roll, exactly as you would if you had
		# ducked on the ground.
		if _fast_falling:
			_fast_falling = false
			_duck_timer = duck_time
	elif not on_floor:
		_was_airborne = true

	# --- hold the key, keep climbing ---
	# Only counts while actually rising, so it can never be used to hang in the
	# air on the way down.
	if _jump_cuttable and velocity.y > 0.0 and Input.is_action_pressed("jump"):
		velocity.y += jump_hold_boost * delta
	if velocity.y <= 0.0:
		_jump_cuttable = false

	# --- gravity ---
	var g: float = gravity
	if velocity.y < 0.0:
		# Falling: pull down harder, so the jump arc feels snappy not floaty.
		g *= fall_gravity_multiplier
	if not on_floor and absf(velocity.y) < apex_window:
		# ...except right at the top, where it eases off. This is the hang.
		g *= apex_gravity_scale
	velocity.y -= g * delta


# -----------------------------------------------------------------------------
#  ANIMATION
# -----------------------------------------------------------------------------

## True while the player is ducked under something.
func is_ducking() -> bool:
	return _duck_timer > 0.0


## Ask the player to duck. Ignored in mid-air — you can't duck what you're
## already flying over, and allowing it would let a jump double as a duck.
func request_duck() -> void:
	if is_on_floor():
		# Only re-trigger the swoosh when starting a fresh duck, not on every
		# frame the key is held.
		if _duck_timer <= 0.0:
			Sfx.play("duck")
			GameState.tally("rolls")
			_duck_started_ms = Time.get_ticks_msec()
		# Ducking again while already rolling has to REPLAY the tumble. The
		# animation state machine only calls play() when the wanted animation
		# changes, and "roll" -> "roll" is not a change, so without this flag
		# the second duck shortens the capsule with no animation at all.
		_restart_roll = true
		_duck_timer = duck_time
		return

	# Refuse to slam out of a launch while still going UP. Ducking sets
	# velocity.y to -26, which would turn a trampoline bounce into an immediate
	# faceplant — and since the duck key is also the slide key, players hold it
	# down. Once you are falling it is allowed again: dropping onto the deck
	# faster is a real choice, and it cannot hurt you.
	if _launched and velocity.y > 0.0:
		return

	# Mid-air: slam down, and roll on landing. Only ever ADDS downward speed,
	# so spamming it while already falling fast does nothing extra.
	if velocity.y > -fast_fall_speed:
		velocity.y = -fast_fall_speed
		_fast_falling = true
		Sfx.play("duck")


func _update_duck(delta: float) -> void:
	if Input.is_action_just_pressed("duck"):
		request_duck()
	_duck_timer = maxf(_duck_timer - delta, 0.0)

	var wanted: float = duck_height if is_ducking() else _stand_height
	var cap: CapsuleShape3D = _collision.shape
	if not is_equal_approx(cap.height, wanted):
		cap.height = wanted
		# Keep the FEET on the floor: the capsule is centred, so its centre
		# has to sit at half its height. Forget this and ducking drops the
		# player through the ground.
		_collision.position.y = wanted * 0.5


## Squash on impact, springing back out. Writes only SCALE, which nothing else
## touches — the run cycle animates Visual's position and rotation, so the two
## never fight over the same property.
func _update_squash(delta: float) -> void:
	if _visual == null:
		return
	if _squash > 0.0:
		_squash = maxf(_squash - delta / maxf(squash_time, 0.01), 0.0)
	# Widen as it flattens, so the runner keeps its volume instead of just
	# getting smaller. That is what reads as "squash" rather than "shrink".
	var k: float = _squash * squash_amount
	_visual.scale = Vector3(1.0 + k * 0.55, 1.0 - k, 1.0 + k * 0.55)


## An obstacle has come into the slice of track directly in front of the
## runner, in the runner's own lane.
func _on_column_entered(body: Node3D) -> void:
	if body.is_in_group("obstacle"):
		_in_column[body] = true


## ...and it has left again. If we are still alive, we got past it — which can
## only have happened by jumping it, ducking it, or riding over it.
func _on_column_exited(body: Node3D) -> void:
	if not _in_column.erase(body):
		return
	if not GameState.is_running():
		return
	# Dying is detected on the frame of contact, so anything still leaving the
	# column while the game is running was genuinely cleared.
	GameState.award_near_miss()


## Plays a footfall at the exact moment the animation plants a foot.
##
## Driven off the animation's own playback position rather than a timer,
## because the stride rate changes with speed — at the 20 m/s cap the cycle
## plays 1.67x faster, and a fixed timer would drift out of step with the feet
## within a second or two. Reading the animation means they cannot disagree.
func _update_footsteps() -> void:
	if _anim == null or _requested_anim != "run" or not is_on_floor():
		_last_anim_pos = -1.0
		return
	var pos: float = _anim.current_animation_position
	var prev: float = _last_anim_pos
	_last_anim_pos = pos
	if prev < 0.0:
		return

	# The cycle loops, so "later than last frame" is not simply a bigger
	# number — it can have wrapped back past zero since we last looked.
	var wrapped: bool = pos < prev
	for i in STEP_PHASES.size():
		var phase: float = STEP_PHASES[i]
		var crossed: bool = (phase > prev or phase <= pos) if wrapped \
			else (prev < phase and phase <= pos)
		if crossed:
			# Two samples, a couple of semitones apart. One sample repeating
			# four times a second is the fastest way to sound cheap.
			Sfx.play("step1" if i == 0 else "step2")


## THROW the player upward — used by the trampoline.
##
## Deliberately NOT routed through request_jump(): that only fills the jump
## buffer, still needs a live coyote timer, and can never produce more than
## jump_velocity (8.5 m/s, a 1.39 m hop). A launch has to write velocity
## directly and then defend itself, which is what _launch_lock is for.
func launch(up_speed: float) -> void:
	velocity.y = up_speed
	launched.emit()
	GameState.tally("launches")
	_launch_lock = launch_lock_time
	_launched = true
	# Wipe both "remembered" inputs so a keypress from just before the bounce
	# cannot spend itself on the frame after it.
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_was_airborne = true
	# Clear any slam in progress, otherwise you land rolling from a launch.
	_fast_falling = false
	Sfx.play("launch")


## Ask the player to jump, as if the jump key had just been pressed.
## The jump still only happens if the player is actually on the ground (or
## within coyote time) — this just feeds the same buffer the key does.
## Used by the swipe handler, and handy for an on-screen mobile button later.
func request_jump() -> void:
	_jump_buffer_timer = jump_buffer_time
	# Not from a key, so there is no key to let go of: this one runs full.
	_buffer_from_key = false


func _update_animation() -> void:
	if _anim == null:
		return
	if GameState.on_title():
		if _requested_anim != "idle":
			_requested_anim = "idle"
			_anim.play("idle")
		return
	if not GameState.is_running():
		# Freeze mid-stride on death. pause() keeps the current pose, whereas
		# stop() would snap the character back to its very first frame.
		if _requested_anim != "dead":
			_requested_anim = "dead"
			_anim.pause()
		return
	# Stride rate follows speed. The cycle is authored for the 12 m/s starting
	# pace, so at 20 m/s it has to play 1.67x faster or the monkey is skating —
	# taking the same number of steps to cover far more ground. This is the
	# cheapest single thing that makes a run read as a run at speed.
	_anim.speed_scale = clampf(STRIDE_RATE * forward_speed / start_speed, 0.7, 2.4) \
		if is_on_floor() and not is_ducking() else 1.0

	# Feet on the ground -> run. In the air -> jump. That's the whole state
	# machine — except on a surf plank, which swaps both for board poses.
	var riding: bool = GameState.has_shield
	if _board.visible != riding:
		_board.visible = riding
	var magnet_on: bool = GameState.magnet_active()
	if _held_magnet.visible != magnet_on:
		_held_magnet.visible = magnet_on
	var spring_on: bool = GameState.spring_active()
	if _boots[0].visible != spring_on:
		for b in _boots:
			b.visible = spring_on
	var grinding: bool = riding and is_on_floor() and not is_ducking()
	if _board_sparks.emitting != grinding:
		_board_sparks.emitting = grinding
	var wanted: String = "roll" if is_ducking() else (
		("surf" if riding else "run") if is_on_floor() else ("jump_b" if riding else "jump"))
	if wanted == "surf":
		_anim.speed_scale = 1.0
	# Only call play() when the animation actually needs to CHANGE, otherwise
	# we'd restart it from frame 0 sixty times a second and it'd look frozen.
	# "jump" doesn't loop, so once it finishes it simply holds its last pose
	# until we land — which is exactly what we want for a long fall.
	if _requested_anim != wanted or (wanted == "roll" and _restart_roll):
		_requested_anim = wanted
		_restart_roll = false
		if wanted == "roll":
			# The roll is authored at 0.55 s. Scale playback so one tumble
			# always fills exactly one duck, whatever duck_time is set to.
			_anim.play("roll", -1.0, 0.55 / maxf(duck_time, 0.05))
			# play() does NOT rewind an animation that is already playing — it
			# just carries on from where it was. So replaying the tumble for a
			# second duck needs an explicit seek, or the flag above would set
			# up a restart that never happens.
			_anim.seek(0.0, true)
		else:
			_anim.play(wanted)


# -----------------------------------------------------------------------------
#  SWIPE CONTROLS (mobile) — already wired up and working.
#  Swipe left / right to change lane, swipe up to jump.
# -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not swipe_enabled or not GameState.is_running():
		return

	if event is InputEventScreenTouch:
		# Ignore extra fingers; only the first one steers.
		if event.index != 0:
			return
		if event.pressed:
			# Finger went down: remember where, and reset the "used" flag.
			_touch_active = true
			_touch_start = event.position
			_swipe_already_handled = false
		else:
			_touch_active = false

	elif event is InputEventScreenDrag:
		if event.index != 0:
			return
		# No finger down means this drag has no valid starting point — ignore it.
		if not _touch_active:
			return
		# Only allow ONE action per swipe, so a long drag isn't 10 lane changes.
		if _swipe_already_handled:
			return

		var drag: Vector2 = event.position - _touch_start
		if drag.length() < swipe_threshold:
			return

		_swipe_already_handled = true

		# Whichever axis moved more decides whether it's a sideways swipe
		# or an up swipe. Remember: on screens, Y grows DOWNWARD.
		if absf(drag.x) > absf(drag.y):
			change_lane(1 if drag.x > 0.0 else -1)
		elif drag.y < 0.0:
			request_jump()
		else:
			# Screen Y grows DOWNWARD, so a positive drag.y is a swipe DOWN.
			request_duck()


## A burst of gold where the coin was. Round-robin through the pool, because a
## line of coins arrives faster than one burst can finish.
func _on_coins_changed(total: int) -> void:
	if total > _coins_seen and not _sparkles.is_empty():
		var sp := _sparkles[_sparkle_next] as CPUParticles3D
		_sparkle_next = (_sparkle_next + 1) % _sparkles.size()
		sp.restart()
	_coins_seen = total


## The plank took a crash for you: it bursts into splinters. (Picking one up
## fires this too, with `held` true, and does nothing.)
func _on_shield_changed(held: bool) -> void:
	if not held and GameState.is_running() and _splinters != null:
		_splinters.restart()


## True while the spring's mid-air jump is still waiting to be used — for the
## coach's "JUMP AGAIN!". Read-only: it must never change the jump itself.
func can_air_jump() -> bool:
	return GameState.spring_active() and _air_jump_ready and not is_on_floor()
