extends Node
## The Subway-Surfers-style behaviours: banking into lane changes, slamming
## down out of a jump, rolling on landing, and the score multiplier.

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
	# The treetop run would rewrite the track under this test; keep it plain.
	_track.canopy_runs = false
	get_tree().root.add_child.call_deferred(_root)
	await _wait(2)
	get_tree().current_scene = _root
	_player = _root.get_node("Player")
	# Never file test deaths on a real person's scoreboard.
	GameState.record_runs = false
	GameState.restart_state_only()
	await _wait(5)

	await _test_lean()
	await _test_fast_fall()
	await _test_roll()
	await _test_multiplier()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL FEEL CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _test_lean() -> void:
	var body: Node3D = _player.get_node("Visual/Body")
	var upright: float = body.rotation.z

	_player.change_lane(1)          # move RIGHT
	await _wait(8)
	var going_right: float = body.rotation.z
	await _wait(60)                 # let it arrive and settle
	var settled: float = body.rotation.z

	_player.change_lane(-1)         # move LEFT
	await _wait(8)
	var going_left: float = body.rotation.z

	print("\n===== A) BANKING INTO THE TURN =====")
	print("  upright          %+.3f rad" % upright)
	print("  moving right     %+.3f rad (want negative — top tips right)" % going_right)
	print("  settled again    %+.3f rad (want ~0)" % settled)
	print("  moving left      %+.3f rad (want positive)" % going_left)

	_chk(going_right < -0.05, "no lean when moving right (got %+.3f)" % going_right)
	_chk(going_left > 0.05, "no lean when moving left (got %+.3f)" % going_left)
	_chk(absf(settled) < 0.06, "still leaning after arriving (%+.3f)" % settled)
	await _wait(40)


func _test_fast_fall() -> void:
	_player.request_jump()
	await _wait(12)
	var rising_y: float = _player.global_position.y
	var vy_before: float = _player.velocity.y
	_player.request_duck()          # slam, mid-air
	await _wait(1)
	var vy_after: float = _player.velocity.y

	print("\n===== B) SLAM DOWN IN MID-AIR =====")
	print("  height when slammed %.2f m" % rising_y)
	print("  velocity.y  %+.1f -> %+.1f  (want <= -%.0f)" % [
		vy_before, vy_after, _player.fast_fall_speed])

	_chk(rising_y > 0.3, "was not actually airborne when slamming")
	_chk(vy_after <= -_player.fast_fall_speed + 0.01,
		"slam did not force the player downward (%.1f)" % vy_after)
	await _wait(60)


func _test_roll() -> void:
	# On the ground now — a duck should roll.
	_player.request_duck()
	await _wait(6)
	var anim: AnimationPlayer = _player.get_node("AnimationPlayer")
	var body: Node3D = _player.get_node("Visual/Body")
	var playing := String(anim.current_animation)
	var tumbled: float = absf(body.rotation.x)
	var lifted: float = body.position.y

	print("\n===== C) THE ROLL =====")
	print("  animation playing = '%s' (want 'roll')" % playing)
	print("  body pitch        = %.2f rad (a full tumble is %.2f)" % [tumbled, TAU])
	print("  body lifted       = %.2f m (rolls about the hip, not the feet)" % lifted)

	_chk(playing == "roll", "ducking did not play the roll, played '%s'" % playing)
	_chk(tumbled > 0.2, "the body never pitched over (%.2f rad)" % tumbled)
	_chk(lifted > 0.05, "body did not lift — it is rotating about the feet")

	# and it must come back to upright afterwards
	await _wait(80)
	print("  after the roll: pitch %.3f, lift %.3f (both want ~0)" % [
		absf(body.rotation.x), body.position.y])
	_chk(absf(body.position.y) < 0.02, "body stayed lifted after the roll")


func _test_multiplier() -> void:
	var start: int = GameState.multiplier
	GameState.add_distance(GameState.MULTIPLIER_EVERY + 5.0)
	var after_one: int = GameState.multiplier
	GameState.add_distance(GameState.MULTIPLIER_EVERY * 10.0)
	var capped: int = GameState.multiplier

	print("\n===== D) SCORE MULTIPLIER =====")
	print("  at the start        x%d" % start)
	print("  after %.0f m        x%d" % [GameState.MULTIPLIER_EVERY, after_one])
	print("  far down the track  x%d (cap is x%d)" % [capped, GameState.MAX_MULTIPLIER])

	_chk(start == 1, "did not start at x1")
	_chk(after_one == 2, "multiplier did not rise after one interval")
	_chk(capped == GameState.MAX_MULTIPLIER, "multiplier did not cap")
