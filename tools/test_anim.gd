extends Node
## Two animation checks:
##  A) the tracks actually MOVE the limbs (a wrong NodePath fails silently)
##  B) the non-looping "jump" animation does NOT restart mid-air on a long jump
##
## Samples on the PHYSICS frame, because the AnimationPlayer is set to the
## physics callback mode (to stay in step with physics interpolation).

var _p: CharacterBody3D
var _anim: AnimationPlayer
var _arm: Node3D
var _vis: Node3D
var _f := 0
var _arm_vals := []
var _vis_y := []

var _airborne := false
var _air_frames := 0
var _last_pos := -1.0
var _restarts := 0
var _anim_finished_in_air := false
var _reported := false
var _fails := []

func _ready() -> void:
	var s: Node = load("res://scenes/main.tscn").instantiate()
	# Empty track: this test is about the PLAYER, and a stray obstacle
	# would make it fail for unrelated reasons. Set before add_child(),
	# because the track builds its first pieces in _ready().
	(s.get_node("TrackManager") as TrackManager).spawn_obstacles = false
	add_child(s)
	_p = s.get_node("Player")
	_anim = _p.get_node("AnimationPlayer")
	_vis = _p.get_node("Visual")
	_arm = _p.get_node("Visual/Body/ArmLeft")
	get_tree().physics_frame.connect(_tick)

func _tick() -> void:
	if _reported:
		return
	_f += 1

	# ---- A) run-cycle motion (0.6 s cycle = 36 physics frames) ----
	if _f > 20 and _f < 80:
		_arm_vals.append(_arm.rotation.x)
		_vis_y.append(_vis.position.y)

	# ---- B) long jump, watch for a restart ----
	if _f == 100:
		Input.action_press("jump")
	if _f == 102:
		Input.action_release("jump")

	if _f > 102:
		if not _p.is_on_floor():
			_airborne = true
			_air_frames += 1
			var cur := String(_anim.current_animation)
			if cur == "jump":
				var pos := _anim.current_animation_position
				# A restart shows up as the playhead jumping BACKWARDS.
				if _last_pos >= 0.0 and pos < _last_pos - 0.001:
					_restarts += 1
				_last_pos = pos
			elif cur == "":
				# Finished and holding its final pose. This is the correct result.
				_anim_finished_in_air = true
		elif _airborne and _air_frames > 5:
			_report()

	if _f > 600:
		_report()

func _report() -> void:
	_reported = true
	var swing: float = _arm_vals.max() - _arm_vals.min()
	var bob: float = _vis_y.max() - _vis_y.min()

	print("\n===== A) RUN CYCLE DRIVES THE MESH =====")
	print("  ArmLeft.rotation.x swing = %.3f rad (expect ~1.8)" % swing)
	print("  Visual.position.y  bob   = %.3f m   (expect ~0.10)" % bob)
	if swing < 0.5:
		_fails.append("arms not swinging - run track path broken")
	if bob < 0.03:
		_fails.append("body not bobbing - Visual:position track broken")

	print("\n===== B) JUMP ANIM DOES NOT RESTART MID-AIR =====")
	print("  airtime                    = %.2f s" % (_air_frames / 60.0))
	print("  jump anim length           = 0.45 s")
	print("  anim finished while in air = %s" % _anim_finished_in_air)
	print("  playhead restarts observed = %d" % _restarts)
	if not _anim_finished_in_air:
		_fails.append("jump anim never reached its end while airborne - test proves nothing")
	if _restarts > 0:
		_fails.append("jump animation RESTARTED %d time(s) mid-air" % _restarts)

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL ANIMATION CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)
