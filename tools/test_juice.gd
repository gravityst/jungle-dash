extends Node
## CLOSE CALLS AND LANDINGS — the reward for clearing something, and the
## squash that gives a landing weight.
##
## The near-miss rule is deliberately strict: an obstacle only scores if it was
## in YOUR lane and you got past it. Passing something in the next lane over
## was never dangerous, and paying out for it would make the bonus meaningless.

var _root: Node
var _track: Node3D
var _player: CharacterBody3D
var _fails := []


func _ready() -> void:
	_run()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _chk(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _run() -> void:
	_root = load("res://scenes/main.tscn").instantiate()
	_track = _root.get_node("TrackManager")
	_track.spawn_obstacles = false
	_track.canopy_runs = false
	_track.random_seed = 2024
	get_tree().root.add_child.call_deferred(_root)
	await _wait(2)
	get_tree().current_scene = _root
	_player = _root.get_node("Player")
	# Never file test deaths on a real person's scoreboard.
	GameState.record_runs = false
	GameState.restart_state_only()
	await _wait(2)

	await _test_near_miss_in_lane()
	await _test_no_credit_for_another_lane()
	await _test_landing_squash()
	await _test_second_duck_replays()
	await _test_hold_to_jump_higher()
	await _test_footsteps()
	await _test_death_slowmo()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL JUICE CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## Jump, and have a low obstacle pass underneath. That should pay.
func _test_near_miss_in_lane() -> void:
	var before := await _pass_obstacle(0.0)
	print("===== A) CLEARING SOMETHING IN YOUR LANE =====")
	print("  close calls awarded: %d (want 1)" % before)
	_chk(before == 1, "jumping an obstacle in your own lane paid %d close calls" % before)
	_chk(GameState.is_running(), "died while clearing a knee-high obstacle in mid-air")


## The same obstacle, one lane over. That should NOT pay.
func _test_no_credit_for_another_lane() -> void:
	var got := await _pass_obstacle(LaneConfig.LANE_WIDTH)
	print("===== B) SOMETHING IN THE NEXT LANE OVER =====")
	print("  close calls awarded: %d (want 0)" % got)
	_chk(got == 0,
		"an obstacle %.1f m to the side paid %d close calls — the column is too wide"
			% [LaneConfig.LANE_WIDTH, got])


## Sends a low obstacle through the runner's column while it is in the air, and
## reports how many close calls that earned.
func _pass_obstacle(x_offset: float) -> int:
	GameState.restart_state_only()
	_player.forward_speed = 0.0
	_player.speed_ramp = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(12)

	var ob := StaticBody3D.new()
	ob.add_to_group("obstacle")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.5, 0.9)
	col.shape = box
	col.position.y = 0.25
	ob.add_child(col)
	add_child(ob)
	# Start it well clear of the runner in every direction.
	ob.global_position = _player.global_position + Vector3(x_offset, 0.0, -6.0)
	await _wait(2)

	var before: int = GameState.near_misses
	_player.request_jump()
	# Let the jump get going, then sweep the obstacle through underneath.
	await _wait(10)
	for i in 14:
		ob.global_position = _player.global_position \
			+ Vector3(x_offset, 0.0, -6.0 + float(i) * 0.9)
		await get_tree().physics_frame
	await _wait(25)
	var gained: int = GameState.near_misses - before
	ob.queue_free()
	await _wait(2)
	return gained


func _test_landing_squash() -> void:
	GameState.restart_state_only()
	_player.velocity = Vector3.ZERO
	await _wait(20)
	var visual: Node3D = _player.get_node("Visual")
	var rest: float = visual.scale.y

	# Drop from a height so the landing is a real thud rather than a step.
	_player.global_position.y = 4.0
	_player.velocity.y = 0.0
	var squashed := 1.0
	for i in 90:
		await get_tree().physics_frame
		squashed = minf(squashed, visual.scale.y)
		if _player.is_on_floor() and i > 30:
			break
	await _wait(6)
	var mid: float = visual.scale.y
	await _wait(40)
	var recovered: float = visual.scale.y

	print("===== C) LANDING SQUASH =====")
	print("  at rest %.3f  -> lowest %.3f  -> recovered %.3f" % [rest, squashed, recovered])
	_chk(is_equal_approx(rest, 1.0), "the runner is not at scale 1 while just running")
	_chk(squashed < 0.95, "landing from 4 m only squashed to %.3f — no impact at all" % squashed)
	_chk(absf(recovered - 1.0) < 0.01,
		"the squash never sprang back; still at %.3f" % recovered)
	_chk(mid <= 1.0001, "the squash overshot into a stretch (%.3f)" % mid)


func _test_second_duck_replays() -> void:
	GameState.restart_state_only()
	_player.global_position.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(20)
	var anim: AnimationPlayer = _player.get_node("AnimationPlayer")

	_player.request_duck()
	await _wait(18)
	var part_way: float = anim.current_animation_position
	_player.request_duck()
	await _wait(2)
	var after: float = anim.current_animation_position

	print("===== D) DUCKING AGAIN REPLAYS THE ROLL =====")
	print("  roll was at %.2f s, after a second duck it is at %.2f s" % [part_way, after])
	_chk(anim.current_animation == "roll", "a second duck did not leave the roll playing")
	_chk(part_way > 0.05, "the roll never got going, so this proves nothing")
	_chk(after < part_way,
		"the second duck did not restart the tumble (%.2f -> %.2f)" % [part_way, after])


## Holding the jump key buys height; tapping gives exactly the ordinary jump.
## The direction matters: a tap must never be PUNISHED, because almost every
## jump in a runner needs to be near maximum, so a mistimed tap would be a
## death with no lesson in it.
func _test_hold_to_jump_higher() -> void:
	var tapped := await _keyed_jump(2)
	var held := await _keyed_jump(40)

	print("===== E) HOLD TO JUMP HIGHER =====")
	print("  tap  (2 frames) : %.2f m" % tapped)
	print("  hold (40 frames): %.2f m" % held)

	_chk(tapped > 1.25,
		"a tapped jump only reached %.2f m — a tap must still be a full jump" % tapped)
	_chk(held > tapped + 0.20,
		"holding only added %.2f m, which nobody would feel" % (held - tapped))
	# The same ceiling the double jump respects, for the same reason: the idol
	# is 2.40 m and the tree 2.60 m, and both are meant to be gone AROUND.
	_chk(held < 2.35,
		"holding reaches %.2f m, which lands on top of dodge-only obstacles" % held)

	# AND BOTH TOGETHER. Each of these was guarded on its own — hold in this
	# test, the double jump in test_powerups — and the combination was guarded
	# by neither, which is exactly the shape of bug that keeps getting through.
	GameState.restart_state_only()
	_player.global_position.y = 0.0
	_player.velocity = Vector3.ZERO
	for i in 120:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
	GameState.start_spring()
	var base: float = _player.global_position.y
	Input.action_press("jump")
	var both := 0.0
	var spent := false
	for i in 90:
		await get_tree().physics_frame
		both = maxf(both, _player.global_position.y - base)
		if not spent and i > 20:
			_player.request_jump()
			spent = true
		if _player.velocity.y < -1.0 and spent:
			break
	Input.action_release("jump")
	print("  hold + spring   : %.2f m" % both)
	_chk(both < 2.35,
		"holding the key through a spring double jump reaches %.2f m — over the ceiling"
			% both)


## Presses the real jump action for `frames` physics frames, and reports how
## high the runner got, measured from whatever it was standing on.
func _keyed_jump(frames: int) -> float:
	GameState.restart_state_only()
	_player.global_position.y = 0.0
	_player.velocity = Vector3.ZERO
	for i in 120:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
	var base: float = _player.global_position.y
	Input.action_press("jump")
	var apex := 0.0
	for i in 80:
		if i == frames:
			Input.action_release("jump")
		await get_tree().physics_frame
		apex = maxf(apex, _player.global_position.y - base)
		if _player.velocity.y < -1.0:
			break
	Input.action_release("jump")
	return apex


## Footsteps have to land WITH the feet, at every speed.
##
## The stride rate follows forward speed — at the 20 m/s cap the cycle plays
## 1.67x faster than at the 12 m/s start — so a footstep driven by a fixed
## timer would drift out of step within a second or two. This checks the rate
## actually tracks the animation, and that the feet go quiet when they are not
## on the ground.
func _test_footsteps() -> void:
	var slow := await _steps_over(180, 12.0)
	var fast := await _steps_over(180, 20.0)
	var air := await _steps_airborne()

	# One cycle is 0.6 s and plants two feet, so the rate is
	# 2 * speed_scale / 0.6 steps a second, and speed_scale is
	# STRIDE_RATE * speed / 12.
	var stride: float = _player.get_script().get_script_constant_map()["STRIDE_RATE"]
	var expect_slow: float = 3.0 * 180.0 / 60.0 * stride
	var expect_fast: float = expect_slow * (20.0 / 12.0)

	print("===== F) FOOTSTEPS =====")
	print("  3 s at 12 m/s: %d steps (expect about %.0f)" % [slow, expect_slow])
	print("  3 s at 20 m/s: %d steps (expect about %.0f)" % [fast, expect_fast])
	print("  while airborne: %d steps (want 0)" % air)

	_chk(absf(float(slow) - expect_slow) <= 2.0,
		"at 12 m/s the feet landed %d times, expected about %.0f" % [slow, expect_slow])
	_chk(absf(float(fast) - expect_fast) <= 3.0,
		"at 20 m/s the feet landed %d times, expected about %.0f" % [fast, expect_fast])
	_chk(fast > slow + 3, "running faster did not produce more footsteps")
	_chk(air == 0, "the feet made %d sounds while off the ground" % air)


func _steps_over(frames: int, speed: float) -> int:
	GameState.restart_state_only()
	_player.speed_ramp = 0.0
	_player.forward_speed = speed
	_player.global_position.y = 0.0
	_player.velocity = Vector3.ZERO
	for i in 120:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
	await _wait(10)
	var before: int = _step_count()
	for i in frames:
		await get_tree().physics_frame
	var got: int = _step_count() - before
	_player.speed_ramp = 0.22
	return got


func _steps_airborne() -> int:
	GameState.restart_state_only()
	_player.velocity = Vector3.ZERO
	for i in 120:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
	_player.launch(18.0)
	await _wait(6)
	var before: int = _step_count()
	# Well inside the flight, nowhere near the landing.
	for i in 40:
		await get_tree().physics_frame
	return _step_count() - before


func _step_count() -> int:
	return int(Sfx.plays.get("step1", 0)) + int(Sfx.plays.get("step2", 0))


## The crash slows time for a moment — and, much more importantly, always puts
## it back. A leaked Engine.time_scale does not crash anything; it just leaves
## the entire game running in slow motion with no clue as to why, which is the
## kind of bug that survives for months.
func _test_death_slowmo() -> void:
	GameState.restart_state_only()
	await _wait(5)
	var before: float = Engine.time_scale
	GameState.die()
	var during: float = Engine.time_scale
	var ended := await _wait_for_normal_speed()
	var after: float = Engine.time_scale

	# And a restart in the MIDDLE of the slow motion must clear it too, rather
	# than leaving it to a timer that the restart just invalidated.
	GameState.restart_state_only()
	await _wait(2)
	GameState.die()
	await _wait(2)
	GameState.restart_state_only()
	var after_restart: float = Engine.time_scale
	await _wait_for_normal_speed()

	print("===== G) THE CRASH SLOWS TIME =====")
	print("  before %.2f  ->  during %.2f  ->  after %.2f" % [before, during, after])
	print("  restarted mid-slowdown -> %.2f" % after_restart)

	_chk(is_equal_approx(before, 1.0), "time was already scaled before dying (%.2f)" % before)
	_chk(during < 0.9, "dying did not slow time down (%.2f)" % during)
	_chk(ended, "the slow motion never ended on its own")
	_chk(is_equal_approx(after, 1.0), "time did not return to normal (%.2f)" % after)
	_chk(is_equal_approx(after_restart, 1.0),
		"restarting during the slow motion left time at %.2f" % after_restart)


## Waits, in REAL time, for the slow motion to lift. Bounded, so a failure here
## reports a failure instead of hanging the suite.
func _wait_for_normal_speed() -> bool:
	var t0: int = Time.get_ticks_msec()
	for i in 600:
		await get_tree().process_frame
		if is_equal_approx(Engine.time_scale, 1.0):
			return true
		if Time.get_ticks_msec() - t0 > 3000:
			return false
	return is_equal_approx(Engine.time_scale, 1.0)
