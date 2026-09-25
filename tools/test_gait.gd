extends Node
## THE RUN CYCLE, MEASURED — does the monkey actually look like it is running?
##
## Every number here is read out of the engine after seeking the real animation,
## not computed from a model of it. That matters: the forward kinematics of a
## two-segment limb under Godot's YXZ euler order and cubic interpolation is
## very easy to get wrong on paper, and a cycle that looks right in a
## spreadsheet can still put the feet through the floor.
##
## What makes a run read as a run, in order of importance:
##   1. the feet TOUCH THE GROUND. The old cycle's lowest sole was 7 cm up —
##      the character hovered, which is why it read as skating.
##   2. the two feet are at DIFFERENT heights. With a rigid leg, foot height is
##      hip - len*cos(angle), and cosine is even — so two legs at equal and
##      opposite angles are always at the SAME height. That is a pogo stick.
##      Breaking it is exactly what the knee is for.
##   3. nothing snaps, and no limb passes through the body.

var _p: CharacterBody3D
var _anim: AnimationPlayer
var _fails := []


func _ready() -> void:
	_run()


func _chk(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _run() -> void:
	_p = load("res://scenes/player.tscn").instantiate()
	add_child(_p)
	await get_tree().physics_frame
	# The script would run, fall, and drag everything with it. This test is
	# about the ANIMATION, so freeze the physics and let only the poses move.
	_p.set_physics_process(false)
	_anim = _p.get_node("AnimationPlayer")

	var footL: MeshInstance3D = _p.get_node("Visual/Body/LegLeft/Knee/Ankle/Foot")
	var footR: MeshInstance3D = _p.get_node("Visual/Body/LegRight/Knee/Ankle/Foot")
	var handL: MeshInstance3D = _p.get_node("Visual/Body/ArmLeft/Elbow/Hand")
	var torso: MeshInstance3D = _p.get_node("Visual/Body/Torso")
	var kneeL: Node3D = _p.get_node("Visual/Body/LegLeft/Knee")

	_anim.play("run")
	var length: float = _anim.get_animation("run").length

	var min_sole := 1e9
	var max_gap := 0.0
	var max_knee_rate := 0.0
	var max_pen := 0.0
	var prev_knee := 0.0
	var steps := 120
	var dt: float = length / float(steps)

	for i in steps + 1:
		var t: float = dt * float(i)
		_anim.seek(t, true)
		await get_tree().physics_frame
		var base: float = _p.global_position.y

		min_sole = minf(min_sole, minf(_low(footL), _low(footR)) - base)
		max_gap = maxf(max_gap, absf(footL.global_position.y - footR.global_position.y))

		# A knee that moves faster than the eye can follow reads as a glitch,
		# not as speed.
		if i > 0:
			max_knee_rate = maxf(max_knee_rate, absf(kneeL.rotation.x - prev_knee) / dt)
		prev_knee = kneeL.rotation.x

		max_pen = maxf(max_pen, _overlap(handL, torso))

	print("===== RUN CYCLE, MEASURED =====")
	print("  lowest sole over the cycle : %+.3f m  (want between -0.02 and 0.06)" % min_sole)
	print("  biggest left/right foot gap: %.3f m  (the old rigid-leg cycle: 0.086)" % max_gap)
	print("  fastest knee               : %.1f rad/s (want under 20)" % max_knee_rate)
	print("  worst hand-into-torso       : %.3f m  (want 0.000)" % max_pen)

	# 1. The feet must reach the ground...
	_chk(min_sole < 0.06,
		"the lowest sole is %.3f m up — the runner is hovering, not running" % min_sole)
	# ...without going through it.
	_chk(min_sole > -0.03,
		"the sole drops %.3f m through the floor" % min_sole)
	# 2. The legs must genuinely alternate.
	_chk(max_gap > 0.25,
		"the feet are never more than %.3f m apart vertically — that is a pogo, not a run"
			% max_gap)
	# 3. Nothing snaps or clips.
	_chk(max_knee_rate < 20.0,
		"the knee hits %.1f rad/s, which reads as a snap" % max_knee_rate)
	_chk(max_pen < 0.01, "the hand sinks %.3f m into the torso" % max_pen)

	await _check_poses()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL GAIT CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## The other two animations have to drive the new joints as well. A pivot with
## no track in the playing animation silently holds whatever the previous
## animation left it at, so a missing track shows up as a leg frozen mid-stride
## through an entire jump.
func _check_poses() -> void:
	print("===== JUMP AND ROLL DRIVE THE NEW JOINTS =====")
	for anim_name in ["jump", "roll"]:
		var anim: Animation = _anim.get_animation(anim_name)
		var paths := {}
		for i in anim.get_track_count():
			paths[str(anim.track_get_path(i))] = true
		var driven := 0
		for joint in ["LegLeft/Knee", "LegRight/Knee", "LegLeft/Knee/Ankle",
				"LegRight/Knee/Ankle", "ArmLeft/Elbow", "ArmRight/Elbow"]:
			var want := "Visual/Body/%s:rotation" % joint
			var has: bool = paths.has(want)
			if has:
				driven += 1
			_chk(has, "the '%s' animation has no track for %s, so it freezes"
				% [anim_name, joint])
		print("  %-5s %d tracks, %d/6 new joints driven" % [anim_name,
			anim.get_track_count(), driven])


## Lowest corner of a mesh's box in world space.
func _low(mi: MeshInstance3D) -> float:
	var ab: AABB = mi.global_transform * mi.mesh.get_aabb()
	return ab.position.y


## How deeply two meshes overlap, 0.0 if they do not. Uses world-space bounding
## boxes, which for rotated parts is the pessimistic answer — fine for a check
## that is supposed to catch limbs passing through the body.
func _overlap(a: MeshInstance3D, b: MeshInstance3D) -> float:
	var ba: AABB = a.global_transform * a.mesh.get_aabb()
	var bb: AABB = b.global_transform * b.mesh.get_aabb()
	if not ba.intersects(bb):
		return 0.0
	var i: AABB = ba.intersection(bb)
	return minf(minf(i.size.x, i.size.y), i.size.z)
