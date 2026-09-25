extends Node
## Core gameplay loop: scoring, speed ramp, coins, dying, forgiveness, restart.
##
## Obstacles used for the crash tests are built HERE rather than borrowed from
## the track, because a borrowed one gets re-randomised the moment its chunk
## recycles and the test turns flaky.

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
	# Clear the track BEFORE the scene enters the tree. The manager builds its
	# first nine pieces in _ready(), so setting this afterwards would leave
	# those pieces full of obstacles and the player would die in part A.
	_track = _root.get_node("TrackManager")
	_track.spawn_obstacles = false
	# The treetop run would rewrite the track under this test; keep it plain.
	_track.canopy_runs = false

	# Add the game under the WINDOW root, not under this test node, so that
	# reload_current_scene() replaces the game and leaves the test running.
	# Deferred because the root is still busy setting up while _ready runs.
	get_tree().root.add_child.call_deferred(_root)
	await _wait(2)
	get_tree().current_scene = _root
	_player = _root.get_node("Player")
	# Never file test deaths on a real person's scoreboard.
	GameState.record_runs = false
	GameState.restart_state_only()

	await _wait(2)
	await _test_scoring_and_speed()
	await _test_coin()
	await _test_landing_on_top_is_forgiven()
	await _test_duck_under_vines()
	await _test_side_hit_kills()
	await _test_restart()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL GAMEPLAY CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _test_scoring_and_speed() -> void:
	var speed_before: float = _player.forward_speed
	await _wait(300)                     # 5 seconds
	var travelled: float = GameState.distance

	print("\n===== A) SCORE AND SPEED =====")
	print("  distance   = %.1f m" % travelled)
	print("  coins      = %d (picked up while running — coins spawn even with"
		% GameState.coins)
	print("               obstacles switched off)")
	print("  score      = %d  (= %d from distance + %d x %d from coins)" % [
		GameState.score, int(travelled), GameState.coins, GameState.POINTS_PER_COIN])
	print("  speed      = %.2f -> %.2f m/s (max %.1f)" % [
		speed_before, _player.forward_speed, _player.max_speed])

	_chk(travelled > 50.0, "only travelled %.1f m in 5 s" % travelled)
	var expected: int = int(travelled * GameState.POINTS_PER_METRE) \
		+ GameState.coins * GameState.POINTS_PER_COIN
	_chk(GameState.score == expected,
		"score is %d, expected %d (%.1f m + %d coins)" % [
			GameState.score, expected, travelled, GameState.coins])
	_chk(_player.forward_speed > speed_before, "speed did not ramp up")
	_chk(_player.forward_speed <= _player.max_speed + 0.001, "speed exceeded max_speed")


func _test_coin() -> void:
	# Hold the player still so the track can't recycle the coin out from under us.
	_player.speed_ramp = 0.0
	_player.forward_speed = 0.0
	await _wait(5)

	var coins_before: int = GameState.coins
	var score_before: int = GameState.score

	var coin: Area3D = _find_coin_far_ahead()
	if coin == null:
		_fails.append("no coin nodes found in any track piece")
		return
	coin.visible = true
	coin.set_deferred("monitoring", true)
	await _wait(2)
	# Drop it straight onto the player.
	coin.global_position = _player.global_position + Vector3(0.0, 0.9, 0.0)
	await _wait(10)

	print("\n===== B) COINS =====")
	print("  coins   %d -> %d" % [coins_before, GameState.coins])
	print("  score   %d -> %d  (a coin is worth %d)" % [
		score_before, GameState.score, GameState.POINTS_PER_COIN])
	print("  coin hidden after pickup = %s" % (not coin.visible))

	_chk(GameState.coins == coins_before + 1,
		"expected exactly 1 coin, got %d" % (GameState.coins - coins_before))
	_chk(not coin.visible, "collected coin is still visible")
	_chk(GameState.score == score_before + GameState.POINTS_PER_COIN,
		"score rose by %d, expected %d" % [
			GameState.score - score_before, GameState.POINTS_PER_COIN])

	# and it must not pay out twice for the same overlap
	await _wait(20)
	_chk(GameState.coins == coins_before + 1,
		"coin paid out more than once (total %d)" % (GameState.coins - coins_before))


func _test_landing_on_top_is_forgiven() -> void:
	var ob := _make_obstacle(Vector3(1.6, 0.6, 1.0),
		Vector3(_player.global_position.x, 0.0, _player.global_position.z - 1.0))
	await _wait(2)
	_player.global_position = Vector3(ob.global_position.x, 2.4, ob.global_position.z)
	_player.velocity = Vector3.ZERO
	await _wait(80)

	print("\n===== C) LANDING ON A LOW HURDLE IS FORGIVEN =====")
	print("  player y    = %.3f  (the hurdle's top is at 0.60)" % _player.global_position.y)
	print("  on floor    = %s" % _player.is_on_floor())
	print("  still alive = %s" % GameState.is_running())

	_chk(_player.global_position.y > 0.5, "did not land on top of the hurdle")
	_chk(GameState.is_running(), "landing on top of a low hurdle killed the player")
	ob.queue_free()


## Ducking has to do two things: get you UNDER a floating obstacle, and not
## let you cheat one you should have dodged.
func _test_duck_under_vines() -> void:
	_player.global_position = Vector3(0.0, 0.0, _player.global_position.z + 3.0)
	_player.velocity = Vector3.ZERO
	await _wait(10)

	var stand_h: float = (_player.get_node("CollisionShape3D").shape as CapsuleShape3D).height
	_player.request_duck()
	await _wait(4)
	var duck_h: float = (_player.get_node("CollisionShape3D").shape as CapsuleShape3D).height
	var duck_y: float = _player.get_node("CollisionShape3D").position.y

	print("\n===== D) DUCKING =====")
	print("  capsule height  %.2f -> %.2f m" % [stand_h, duck_h])
	print("  capsule centre  y = %.2f (must be half the height, or the feet sink)" % duck_y)
	print("  is_ducking()    = %s" % _player.is_ducking())

	_chk(duck_h < stand_h - 0.5, "ducking did not shrink the capsule")
	_chk(is_equal_approx(duck_y, duck_h * 0.5), "ducked capsule is not resting on the floor")

	# Now run at a floating obstacle — the underside sits at 1.05 m, so a
	# ducked player (0.9 m) fits and a standing one does not.
	var vines := _make_obstacle(Vector3(2.0, 1.55, 0.6),
		Vector3(0.0, 0.0, _player.global_position.z - 9.0), 1.825)
	_player.forward_speed = 12.0
	# Duck at the right moment and keep ducking until we're through.
	for i in 90:
		if absf(_player.global_position.z - vines.global_position.z) < 5.0:
			_player.request_duck()
		await _wait(1)

	print("  survived the vines by ducking = %s" % GameState.is_running())
	print("  got past them                 = %s" % (_player.global_position.z < vines.global_position.z - 1.0))
	_chk(GameState.is_running(), "ducking did NOT get the player under the vines")
	_chk(_player.global_position.z < vines.global_position.z - 1.0,
		"player never made it past the vines")
	vines.queue_free()
	await _wait(2)


func _test_side_hit_kills() -> void:
	_player.global_position = Vector3(0.0, 0.0, _player.global_position.z + 4.0)
	_player.velocity = Vector3.ZERO
	await _wait(10)
	_make_obstacle(Vector3(1.6, 2.2, 1.0),
		Vector3(0.0, 0.0, _player.global_position.z - 8.0))
	_player.forward_speed = 12.0
	await _wait(120)

	print("\n===== E) HITTING A BLOCKER KILLS =====")
	print("  alive          = %s (should be false)" % GameState.is_running())
	print("  score at death = %d" % GameState.score)
	print("  best score     = %d" % GameState.best_score)

	_chk(not GameState.is_running(), "ran into a tall block and survived")
	# >= not ==: the high score is now PERSISTENT (saved to user://save.cfg),
	# so a better score from an earlier session legitimately survives this one.
	_chk(GameState.best_score >= GameState.score,
		"best score %d is below this run's score %d" % [GameState.best_score, GameState.score])

	await _wait(90)
	print("  forward speed after death = %.2f (should be ~0)" % absf(_player.velocity.z))
	_chk(absf(_player.velocity.z) < 0.5, "player still moving forward after dying")


func _test_restart() -> void:
	var best: int = GameState.best_score
	_chk(best > 0, "nothing to preserve — best score was 0 before restart")

	GameState.restart()
	# Check the counters straight away: restart() zeroes them synchronously and
	# only the level rebuild is deferred. Wait first and the NEW player has
	# already run a few metres, so "distance == 0" would fail for no good reason.
	print("\n===== F) RESTART =====")
	print("  immediately after restart():")
	print("    score      = %d (want 0)" % GameState.score)
	print("    coins      = %d (want 0)" % GameState.coins)
	print("    distance   = %.1f (want 0)" % GameState.distance)
	print("    alive      = %s (want true)" % GameState.is_running())
	print("    best score = %d (want %d — it must survive)" % [GameState.best_score, best])

	_chk(GameState.score == 0, "score not reset")
	_chk(GameState.coins == 0, "coins not reset")
	_chk(GameState.distance < 0.001, "distance not reset")
	_chk(GameState.is_running(), "still dead after restart")
	_chk(GameState.best_score == best, "best score was lost across the restart")

	await _wait(20)

	var scene: Node = get_tree().current_scene
	var p: CharacterBody3D = scene.get_node_or_null("Player") if scene else null
	print("  level rebuilt with a player = %s" % (p != null))
	_chk(p != null, "the level was not rebuilt")
	if p != null:
		print("  new player z = %.2f (want ~0)" % p.global_position.z)
		_chk(absf(p.global_position.z) < 8.0, "restarted player is not back at the start")
		_chk(p != _player, "restart reused the OLD player instead of a fresh one")


# --- helpers ---------------------------------------------------------------

## A coin from a piece far enough ahead that it won't be recycled mid-test.
func _find_coin_far_ahead() -> Area3D:
	var best: Area3D = null
	var best_z := 1e9
	for chunk in _track.get_children():
		var coins: Node3D = chunk.get_node_or_null("Coins")
		if coins == null or coins.get_child_count() == 0:
			continue
		if chunk.position.z < best_z:
			best_z = chunk.position.z
			best = coins.get_child(0)
	return best


## Our own obstacle, parented to the test so the track can never touch it.
func _make_obstacle(size: Vector3, pos: Vector3, centre_y: float = -1.0) -> StaticBody3D:
	var ob := StaticBody3D.new()
	ob.add_to_group("obstacle")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	# centre_y lets the caller FLOAT the collider (vines, branches); the
	# default rests it on the ground.
	col.position.y = size.y * 0.5 if centre_y < 0.0 else centre_y
	ob.add_child(col)
	add_child(ob)
	ob.global_position = pos
	return ob
