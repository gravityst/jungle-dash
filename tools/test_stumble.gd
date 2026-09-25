extends Node
## STUMBLE, DON'T DIE — the rule that separates a mistake from a crash.
##
##   A) Steering into the SIDE of something throws you back to your lane, alive,
##      and puts the chaser on your heels.
##   B) Doing it again while he is still that close gets you caught.
##   C) Once he has dropped back, a stumble is forgiven all over again.
##   D) Clipping the TOP EDGE of a hurdle stumbles you over it, alive.
##   E) Running into the FRONT of something is still a crash.
##   F) A shield is spent instead of being caught.
##
## Obstacles are built here rather than borrowed from the track, so nothing
## re-randomises under the test.

var _root: Node
var _player: CharacterBody3D
var _fails := []
var _stumbles := 0
var _made: Array[Node] = []


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
	var track: Node = _root.get_node("TrackManager")
	track.spawn_obstacles = false
	track.canopy_runs = false
	get_tree().root.add_child.call_deferred(_root)
	await _wait(2)
	get_tree().current_scene = _root
	_player = _root.get_node("Player")
	GameState.record_runs = false
	GameState.restart_state_only()
	GameState.stumbled.connect(func() -> void: _stumbles += 1)
	await _wait(2)

	await _test_side_hit()
	await _test_second_stumble_caught()
	await _test_cooled_off()
	await _test_clipped_lip()
	await _test_head_on()
	await _test_shield()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL STUMBLE CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## A fresh, alive runner in the centre lane with nothing around it.
func _reset() -> void:
	for n in _made:
		if is_instance_valid(n):
			n.queue_free()
	_made.clear()
	# Let the frees land BEFORE reviving: a runner revived while still pressed
	# against the last test's wall runs straight back into it and dies again.
	await _wait(2)
	if not GameState.is_running():
		GameState.restart_state_only()
	GameState.heat_time = 0.0
	_player.current_lane = 1
	_player._prev_lane = 1
	_player._invuln_timer = 0.0
	_player.global_position = Vector3(0.0, 0.0, _player.global_position.z)
	_player.velocity = Vector3.ZERO
	_player.forward_speed = 12.0
	await _wait(6)


## A long wall standing in `lane`, running alongside the runner.
func _wall_beside(lane: int) -> void:
	var ob := _block(Vector3(1.6, 2.4, 60.0),
		Vector3(LaneConfig.lane_to_x(lane), 0.0, _player.global_position.z - 26.0))
	_made.append(ob)


func _block(size: Vector3, pos: Vector3) -> StaticBody3D:
	var ob := StaticBody3D.new()
	ob.add_to_group("obstacle")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position.y = size.y * 0.5
	ob.add_child(col)
	add_child(ob)
	ob.global_position = pos
	return ob


## Steers right into the wall, and waits for the result.
func _steer_into_wall() -> void:
	_player.change_lane(1)
	for f in 40:
		await get_tree().physics_frame
		if OS.get_environment("STUMBLE_DEBUG") != "":
			for i in _player.get_slide_collision_count():
				var h := _player.get_slide_collision(i)
				if h.get_collider() != null and h.get_collider().is_in_group("obstacle"):
					print("    steer f%d pos=%s n=%s alive=%s" % [f, _player.global_position,
						h.get_normal(), GameState.is_running()])


func _test_side_hit() -> void:
	await _reset()
	_wall_beside(2)
	var before := _stumbles
	await _steer_into_wall()
	print("\n===== A) SIDE HIT =====")
	print("  alive %s   lane %d   heat %.2f s   stumbles +%d" % [
		GameState.is_running(), _player.current_lane, GameState.heat_time, _stumbles - before])
	_chk(GameState.is_running(), "steering into the side of something killed the runner")
	_chk(_player.current_lane == 1, "a side hit did not throw the runner back to its lane")
	_chk(absf(_player.global_position.x) < 0.3,
		"runner is not back in its lane (x = %.2f)" % _player.global_position.x)
	_chk(_stumbles - before == 1, "a side hit fired %d stumbles, expected 1" % (_stumbles - before))
	_chk(GameState.heat_time > 4.0, "the chaser did not close in after a stumble")


func _test_second_stumble_caught() -> void:
	# Straight on from A: the chaser is still hot.
	await _wait(20)
	var heat := GameState.heat_time
	await _steer_into_wall()
	print("\n===== B) SECOND STUMBLE WHILE HOT =====")
	print("  heat before %.2f s   alive %s   cause %s" % [
		heat, GameState.is_running(), GameState.death_cause])
	_chk(heat > 0.0, "setup: heat had already run out")
	_chk(not GameState.is_running(), "a second stumble with the chaser on your heels did not end the run")
	_chk(GameState.death_cause == "caught", "death cause was '%s', expected 'caught'" % GameState.death_cause)
	await _wait(30)


func _test_cooled_off() -> void:
	await _reset()
	_wall_beside(2)
	await _steer_into_wall()
	_chk(GameState.is_running(), "setup: first stumble killed")
	# Let the heat run out completely, then do it again.
	var frames := int((GameState.HEAT_SECONDS + 0.5) * Engine.physics_ticks_per_second)
	await _wait(frames)
	_player.global_position.z = _player.global_position.z  # (keeps the wall alongside)
	_wall_beside(2)
	var heat := GameState.heat_time
	await _steer_into_wall()
	print("\n===== C) STUMBLE AFTER HE DROPPED BACK =====")
	print("  heat before %.2f s   alive %s" % [heat, GameState.is_running()])
	_chk(heat <= 0.0, "setup: heat had not run out after %.1f s" % (GameState.HEAT_SECONDS + 0.5))
	_chk(GameState.is_running(), "a stumble after the chaser dropped back still got you caught")


func _test_clipped_lip() -> void:
	await _reset()
	# A knee-high hurdle, and the runner arriving just too low to clear it:
	# its feet catch the top edge at a glancing angle.
	# Right in front of the feet: from any further out, gravity has the
	# runner back on the ground before it arrives and it is a head-on hit.
	var hurdle := _block(Vector3(1.75, 0.55, 0.95),
		Vector3(0.0, 0.0, _player.global_position.z - 1.0))
	_made.append(hurdle)
	# A jump that left it too late: rising, feet ~0.36 m up as it reaches the
	# hurdle, so the capsule's round bottom meets the top edge at a glancing
	# angle (normal about 0.6 up). Rising matters — a body on the floor is
	# snapped straight back down to it.
	_player.global_position.y = 0.36
	_player.velocity.y = 2.0
	var before := _stumbles
	for f in 60:
		await get_tree().physics_frame
		for i in _player.get_slide_collision_count():
			var h := _player.get_slide_collision(i)
			if h.get_collider() == hurdle and OS.get_environment("STUMBLE_DEBUG") != "":
				print("    f%d y=%.3f n=%s" % [f, _player.global_position.y, h.get_normal()])
	print("\n===== D) CLIPPED THE TOP EDGE =====")
	print("  alive %s   stumbles +%d   past it %s" % [GameState.is_running(), _stumbles - before,
		_player.global_position.z < hurdle.global_position.z - 1.0])
	_chk(GameState.is_running(), "clipping the top edge of a hurdle was a crash")
	_chk(_player.global_position.z < hurdle.global_position.z - 1.0,
		"the runner got pinned on the hurdle instead of stumbling over it")


func _test_head_on() -> void:
	await _reset()
	_made.append(_block(Vector3(1.6, 2.4, 1.0),
		Vector3(0.0, 0.0, _player.global_position.z - 8.0)))
	await _wait(60)
	print("\n===== E) HEAD ON =====")
	print("  alive %s   cause %s" % [GameState.is_running(), GameState.death_cause])
	_chk(not GameState.is_running(), "running into the face of a wall did not end the run")
	_chk(GameState.death_cause == "crash", "a head-on hit was recorded as '%s'" % GameState.death_cause)
	await _wait(30)


func _test_shield() -> void:
	await _reset()
	_wall_beside(2)
	await _steer_into_wall()
	var first_ok := GameState.is_running()
	GameState.give_shield()
	await _wait(20)
	var heat := GameState.heat_time
	await _steer_into_wall()
	print("\n===== F) SHIELD SAVES A CATCH =====")
	print("  first stumble alive %s   heat before second %.2f   cause %s   lane %d" % [
		first_ok, heat, GameState.death_cause, _player.current_lane])
	print("  alive %s   shield left %s" % [GameState.is_running(), GameState.has_shield])
	_chk(GameState.is_running(), "a shield did not save you from being caught")
	_chk(not GameState.has_shield, "the shield was not spent")
