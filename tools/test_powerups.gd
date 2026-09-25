extends Node
## THE THREE POWER-UPS — the slot, the magnet, the shield and the surge.
##
## The shield gets the most attention here because it is the only power-up that
## touches the death path, and a bug in it is the difference between a rescue
## and being pinned motionless against a tree for the rest of the run.

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
	await _test_slot_and_placement()

	_root = load("res://scenes/main.tscn").instantiate()
	_track = _root.get_node("TrackManager")
	_track.spawn_obstacles = false
	_track.canopy_runs = false
	# Fixed, so a failure here can be reproduced instead of guessed at.
	_track.random_seed = 9090
	get_tree().root.add_child.call_deferred(_root)
	await _wait(2)
	get_tree().current_scene = _root
	_player = _root.get_node("Player")
	# Never file test deaths on a real person's scoreboard.
	GameState.record_runs = false
	GameState.restart_state_only()
	await _wait(2)

	await _test_magnet_timer()
	await _test_magnet_pull()
	await _test_surge()
	await _test_double_jump()
	await _test_shield_saves()
	await _test_clears_on_restart()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL POWER-UP CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## The slot holds three looks and must show exactly one.
func _test_slot_and_placement() -> void:
	var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(chunk)
	await _wait(1)

	var pickup: Area3D = chunk.get_node("Powerups/Pickup")
	var looks: Node3D = chunk.get_node("Powerups/Pickup/Looks")

	print("===== SLOT =====")
	# The chunk shows a look by INDEX, so the child order and the enum order
	# have to agree. If someone reorders the build, this is what catches it.
	var want := ["Magnet", "Shield", "Surge", "Spring"]
	for i in want.size():
		var got: String = looks.get_child(i).name if i < looks.get_child_count() else "MISSING"
		_chk(got == want[i],
			"Looks child %d is '%s', expected '%s' (order must match enum Pickup)"
				% [i, got, want[i]])
	for look in looks.get_children():
		var size := _size_of(look)
		var surf := _surfaces(look)
		print("  %-8s %.2f x %.2f x %.2f, %d surfaces" % [look.name, size.x, size.y, size.z, surf])
		_chk(size.x > 0.3 and size.x < 1.2, "%s is %.2f wide, expected 0.3-1.2" % [look.name, size.x])
		# Up to 1.5 m: pickups are drawn bigger than life (PICKUP_SCALE in
		# build_scenes.gd) so they read at the 40-60 m decision distance.
		_chk(size.y > 0.3 and size.y < 1.5, "%s is %.2f tall, expected 0.3-1.5" % [look.name, size.y])
		# One merged surface per material is the point of _merged(); if this
		# climbs, a power-up has quietly become a pile of draw calls.
		_chk(surf <= 2, "%s is %d surfaces, should merge to at most 2" % [look.name, surf])

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var seen := 0
	var kinds := {0: 0, 1: 0, 2: 0, 3: 0}
	var in_landmark := 0
	var blocked := 0
	var multi_look := 0
	var trials := 500

	for i in trials:
		chunk.randomise(rng, 0.5, false)
		await _wait(1)
		var shown := 0
		for look in looks.get_children():
			if look.visible:
				shown += 1
		if not pickup.visible:
			if shown != 0:
				multi_look += 1
			continue
		seen += 1
		kinds[int(chunk.pickup_kind)] += 1
		if shown != 1:
			multi_look += 1
		if chunk.landmark_lane >= 0 \
				and LaneConfig.x_to_lane(pickup.position.x) == chunk.landmark_lane:
			in_landmark += 1
		for ob in chunk.get_node("Obstacles").get_children():
			if not ob.visible:
				continue
			if absf(ob.position.z - chunk.ROW_Z[1]) > 0.01:
				continue
			if absf(ob.position.x - pickup.position.x) < 0.5:
				blocked += 1
				break

	var rate := float(seen) / float(trials)
	print("===== PLACEMENT =====")
	print("  pickups in %d rolls : %d  (rate %.3f, want ~%.2f)"
		% [trials, seen, rate, chunk.PICKUP_CHANCE])
	print("  kinds  magnet %d / shield %d / surge %d / spring %d"
		% [kinds[0], kinds[1], kinds[2], kinds[3]])
	print("  in the landmark lane   : %d  (want 0)" % in_landmark)
	print("  blocked by the next row: %d  (want 0)" % blocked)
	print("  wrong number of looks  : %d  (want 0)" % multi_look)

	_chk(seen > 0, "no power-up appeared in %d rolls" % trials)
	_chk(absf(rate - chunk.PICKUP_CHANCE) < 0.07,
		"pickup rate %.3f is far from PICKUP_CHANCE %.2f" % [rate, chunk.PICKUP_CHANCE])
	_chk(in_landmark == 0, "%d power-ups were buried in the landmark" % in_landmark)
	_chk(blocked == 0, "%d power-ups sat in a lane the next row blocks" % blocked)
	_chk(multi_look == 0, "%d rolls showed the wrong number of looks" % multi_look)
	for k in kinds:
		_chk(kinds[k] > 0, "kind %d never came up in %d rolls" % [k, trials])

	chunk.queue_free()
	await _wait(1)


func _test_magnet_timer() -> void:
	GameState.restart_state_only()
	_chk(not GameState.magnet_active(), "the magnet was already active at the start")
	GameState.start_magnet()
	_chk(GameState.magnet_active(), "start_magnet() did not turn the magnet on")
	# Topping up REPLACES rather than stacks — otherwise a lucky streak turns
	# into a minute of free coins.
	GameState.magnet_time = 1.0
	GameState.start_magnet()
	_chk(is_equal_approx(GameState.magnet_time, GameState.MAGNET_SECONDS),
		"a second magnet stacked instead of replacing: %.2f s" % GameState.magnet_time)
	var before := GameState.magnet_time
	await _wait(20)
	_chk(GameState.magnet_time < before, "the magnet timer did not count down")
	print("===== MAGNET TIMER =====")
	print("  ticked %.2f -> %.2f over 20 frames" % [before, GameState.magnet_time])


## One coin, placed by this test, 6 m to the side.
func _test_magnet_pull() -> void:
	var off := await _one_coin_pulled(false)
	var on := await _one_coin_pulled(true)
	print("===== MAGNET PULL =====")
	print("  coin 6 m to the side, magnet off: %s" % ("collected" if off else "left behind"))
	print("  coin 6 m to the side, magnet on : %s" % ("collected" if on else "left behind"))
	_chk(not off, "a coin 6 m away was collected with NO magnet running")
	_chk(on, "the magnet failed to pull in a coin 6 m away")


func _one_coin_pulled(magnet_on: bool) -> bool:
	GameState.restart_state_only()
	await _wait(2)
	var coin := _find_coin()
	if coin == null:
		_fails.append("could not find a coin to test the pull with")
		return false
	coin.global_position = _player.global_position + Vector3(-6.0, 0.7, -2.0)
	coin.visible = true
	coin.monitoring = true
	await _wait(1)
	for i in 40:
		if magnet_on:
			GameState.magnet_time = 10.0
		await get_tree().physics_frame
	# Its own visibility, not the coin COUNTER: the player is still running
	# and may pick up unrelated coins, which would poison a total.
	return not coin.visible


func _find_coin() -> Area3D:
	for chunk in _track.get_children():
		var coins: Node3D = chunk.get_node_or_null("Coins")
		if coins == null:
			continue
		for c in coins.get_children():
			return c as Area3D
	return null


func _test_surge() -> void:
	GameState.restart_state_only()
	_chk(GameState.score_factor() == 1,
		"score factor is %d with nothing running, expected 1" % GameState.score_factor())
	GameState.start_surge()
	_chk(GameState.surge_active(), "start_surge() did not turn the surge on")
	_chk(GameState.score_factor() == GameState.SURGE_FACTOR,
		"score factor is %d during a surge, expected %d"
			% [GameState.score_factor(), GameState.SURGE_FACTOR])

	# Earning while it runs must actually pay double.
	GameState.restart_state_only()
	GameState.add_distance(20.0)
	var plain := GameState.score
	GameState.restart_state_only()
	GameState.start_surge()
	GameState.add_distance(20.0)
	var doubled := GameState.score
	print("===== SURGE =====")
	print("  20 m plain: %d points   20 m surged: %d points" % [plain, doubled])
	_chk(doubled == plain * GameState.SURGE_FACTOR,
		"20 m scored %d with a surge, expected %d" % [doubled, plain * GameState.SURGE_FACTOR])


## The spring gives exactly one extra jump per airborne stretch, and that jump
## must not be strong enough to land you on top of things you are supposed to
## go AROUND.
func _test_double_jump() -> void:
	var plain := await _jump_apex(false)
	var sprung := await _jump_apex(true)
	var twice := await _jump_apex(true, 2)

	print("===== DOUBLE JUMP =====")
	print("  apex, no spring          : %.2f m" % plain)
	print("  apex, spring + one extra : %.2f m" % sprung)
	print("  apex, spring + two extras: %.2f m (must equal the line above)" % twice)

	# The band, not the number: jump_velocity is meant to be tuned, and a test
	# that pins the exact height turns every tuning pass into a test failure.
	# What matters is that it clears the 1.10 m landmark roof with room, and
	# stays well under the 2.35 m ceiling on its own.
	_chk(plain > 1.45 and plain < 1.95,
		"an ordinary jump reached %.2f m; it should clear the 1.10 m landmark roof"
			% plain)
	_chk(sprung > plain + 0.35,
		"the second jump only added %.2f m — the spring is doing nothing" % (sprung - plain))
	# The hard safety line. PILLAR tops out at 2.40 and TREE at 2.60, and both
	# are meant to be gone AROUND. Landing on their roofs is forgiven by the
	# crash check, so an over-strong second jump would silently invent a whole
	# category of behaviour nothing else in the game accounts for.
	_chk(sprung < 2.35,
		"the double jump reaches %.2f m, which lands on top of dodge-only obstacles"
			% sprung)
	_chk(absf(twice - sprung) < 0.02,
		"a THIRD jump worked (%.2f vs %.2f) — it should be one extra per landing"
			% [twice, sprung])


## Jumps, optionally spending `extras` mid-air jumps, and reports the apex.
func _jump_apex(with_spring: bool, extras: int = 1) -> float:
	GameState.restart_state_only()
	_player.global_position.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(25)
	if with_spring:
		GameState.start_spring()
	var base: float = _player.global_position.y
	_player.request_jump()
	var apex := 0.0
	var spent := 0
	for i in 70:
		await get_tree().physics_frame
		apex = maxf(apex, _player.global_position.y - base)
		# Spend the extra jumps near the top of the arc, which is when a player
		# would actually press it.
		if with_spring and spent < extras and i > 18 and i % 6 == 0:
			_player.request_jump()
			spent += 1
	return apex


## The one that matters: a shield has to save you AND get you clear.
func _test_shield_saves() -> void:
	GameState.restart_state_only()
	_player.global_position = Vector3(0.0, 0.0, _player.global_position.z + 4.0)
	_player.velocity = Vector3.ZERO
	await _wait(10)

	GameState.give_shield()
	_chk(GameState.has_shield, "give_shield() did not grant a shield")

	var ob := _make_blocker(Vector3(0.0, 0.0, _player.global_position.z - 8.0))
	_player.forward_speed = 12.0
	await _wait(120)

	var col: CollisionShape3D = ob.get_node("CollisionShape3D")
	print("===== SHIELD =====")
	print("  alive after hitting a blocker : %s (want true)" % GameState.is_running())
	print("  shield still held             : %s (want false)" % GameState.has_shield)
	print("  the blocker's collider is off : %s (want true)" % col.disabled)

	_chk(GameState.is_running(), "the shield did not save the player from a blocker")
	_chk(not GameState.has_shield, "the shield was not spent by the hit")
	# Without this the player survives and is then pinned flat against the
	# tree, unable to move, which is worse than dying.
	_chk(col.disabled, "the blocker stayed solid, so the player is stuck in it")

	# And with no shield, the same hit still kills.
	GameState.restart_state_only()
	_player.global_position = Vector3(0.0, 0.0, _player.global_position.z + 4.0)
	_player.velocity = Vector3.ZERO
	# Long enough for the invulnerability from the save above to lapse.
	await _wait(90)
	_make_blocker(Vector3(0.0, 0.0, _player.global_position.z - 8.0))
	_player.forward_speed = 12.0
	await _wait(120)
	print("  alive after the SAME hit with no shield: %s (want false)"
		% GameState.is_running())
	_chk(not GameState.is_running(), "a blocker was survived with no shield to spend")


func _make_blocker(pos: Vector3) -> StaticBody3D:
	var ob := StaticBody3D.new()
	ob.add_to_group("obstacle")
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.2, 1.0)
	col.shape = box
	col.position.y = 1.1
	ob.add_child(col)
	add_child(ob)
	ob.global_position = pos
	return ob


func _test_clears_on_restart() -> void:
	GameState.restart_state_only()
	GameState.start_magnet()
	GameState.start_surge()
	GameState.give_shield()
	GameState.die()
	_chk(not GameState.magnet_active(), "the magnet stayed active after dying")
	_chk(not GameState.surge_active(), "the surge stayed active after dying")
	var frozen_m := GameState.magnet_time
	var frozen_s := GameState.surge_time
	await _wait(20)
	_chk(is_equal_approx(GameState.magnet_time, frozen_m)
			and is_equal_approx(GameState.surge_time, frozen_s),
		"a timer kept burning while dead (%.2f/%.2f -> %.2f/%.2f)"
			% [frozen_m, frozen_s, GameState.magnet_time, GameState.surge_time])

	GameState.restart_state_only()
	print("===== DEATH / RESTART =====")
	print("  after restart: magnet %.1f, surge %.1f, shield %s"
		% [GameState.magnet_time, GameState.surge_time, GameState.has_shield])
	_chk(GameState.magnet_time == 0.0, "restart left magnet time on the clock")
	_chk(GameState.surge_time == 0.0, "restart left surge time on the clock")
	_chk(not GameState.has_shield, "restart left a shield in hand")


func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func _surfaces(n: Node) -> int:
	var total := 0
	for c in _walk(n):
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			total += mi.mesh.get_surface_count()
	return total


func _size_of(n: Node) -> Vector3:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for c in _walk(n):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var ab := mi.mesh.get_aabb()
		lo = lo.min(ab.position)
		hi = hi.max(ab.position + ab.size)
	return hi - lo
