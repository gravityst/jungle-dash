extends Node
## THE TREETOP RUN — the deck geometry, the launch, and a full trip up and back.
##
## The launch-protection section is the important one. Four separate reviews of
## this feature independently predicted the same failure: an Area3D's
## body_entered fires from the physics server's query flush, which runs BEFORE
## _physics_process, so on the frame after the bounce is_on_floor() is still
## true — and the plain assignment `velocity.y = jump_velocity` in the jump
## block would overwrite a 22 m/s launch with an 8.5 m/s hop. Section C is the
## test that would catch that coming back.

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
	await _test_deck_geometry()

	_root = load("res://scenes/main.tscn").instantiate()
	_track = _root.get_node("TrackManager")
	# No obstacles: this test is about the treetops, and a death on the run-up
	# would make it flaky for a reason that has nothing to do with the feature.
	# The pad spans the whole track, so the runner meets it without steering.
	_track.spawn_obstacles = false
	_track.canopy_runs = true
	# Left at the SHIPPING values on purpose. A test that overrides the spacing
	# proves the treetops work; it does not prove a player will ever meet them,
	# which was the actual bug — at the old spacing the first one was about
	# 1115 m in, roughly a minute of never dying.
	_track.random_seed = 7171
	get_tree().root.add_child.call_deferred(_root)
	await _wait(2)
	get_tree().current_scene = _root
	_player = _root.get_node("Player")
	# Never file test deaths on a real person's scoreboard.
	GameState.record_runs = false
	GameState.restart_state_only()
	await _wait(2)

	await _test_launch_survives_input()
	await _test_narrow_is_one_lane()
	await _test_round_trip()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL CANOPY CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## A) The deck must be where the maths says it is, for each role.
func _test_deck_geometry() -> void:
	var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(chunk)
	await _wait(1)

	var deck: StaticBody3D = chunk.get_node("Skyway/Deck")
	var col: CollisionShape3D = chunk.get_node("Skyway/Deck/CollisionShape3D")
	var pad: Area3D = chunk.get_node("Skyway/Pad")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	print("===== A) DECK GEOMETRY =====")
	var L: float = LaneConfig.CHUNK_LENGTH
	var expected := {
		chunk.Role.NORMAL:   null,
		chunk.Role.APPROACH: null,
		chunk.Role.LAUNCH:   [chunk.PAD_Z - chunk.DECK_LEAD, -L],
		chunk.Role.DECK:     [0.0, -L],
		chunk.Role.NARROW:   [0.0, -L],
		chunk.Role.EXIT:     [0.0, -chunk.EXIT_DECK_LEN],
	}
	for role in expected:
		chunk.randomise(rng, 0.5, false, true, role)
		await _wait(2)
		var want = expected[role]
		if want == null:
			print("  role %d: no deck (%s)" % [role, "correct" if not deck.visible else "WRONG"])
			_chk(not deck.visible, "role %d showed a deck it should not have" % role)
			_chk(not chunk.get_node("Skyway/Crowns").visible,
				"role %d showed treetop crowns with no deck" % role)
			continue
		var box: BoxShape3D = col.shape
		var near: float = col.position.z + box.size.z * 0.5
		var far: float = col.position.z - box.size.z * 0.5
		var top: float = col.position.y + box.size.y * 0.5
		print("  role %d: deck z %.1f .. %.1f (want %.1f .. %.1f), top y %.2f"
			% [role, near, far, want[0], want[1], top])
		_chk(deck.visible, "role %d did not show its deck" % role)
		_chk(absf(near - want[0]) < 0.01,
			"role %d deck starts at %.2f, expected %.2f" % [role, near, want[0]])
		_chk(absf(far - want[1]) < 0.01,
			"role %d deck ends at %.2f, expected %.2f" % [role, far, want[1]])
		_chk(absf(top - chunk.DECK_Y) < 0.01,
			"role %d deck top is %.2f, expected DECK_Y %.2f" % [role, top, chunk.DECK_Y])
		# The deck must never be lethal — that is the whole promise of the
		# treetops. Tagging it as an obstacle would make its leading face kill.
		_chk(not deck.is_in_group("obstacle"),
			"the deck is in the obstacle group, so its edge can kill you")

	# The canopy decoration has to be off for the WHOLE sequence, approach
	# included: each piece's leaves overhang ~16 m into the piece in front.
	for role in [chunk.Role.APPROACH, chunk.Role.LAUNCH, chunk.Role.DECK,
			chunk.Role.NARROW, chunk.Role.EXIT]:
		chunk.randomise(rng, 0.5, false, true, role)
		await _wait(1)
		_chk(not chunk.get_node("Canopy").visible,
			"role %d left the leaf canopy on — the runner flies through it" % role)
		var obs := 0
		for ob in chunk.get_node("Obstacles").get_children():
			if ob.visible:
				obs += 1
		_chk(obs == 0, "role %d carried %d obstacles; the treetop run must be clear" % [role, obs])
	chunk.randomise(rng, 0.5, false, true, chunk.Role.LAUNCH)
	await _wait(1)
	_chk(pad.visible, "the LAUNCH piece did not show its trampoline")

	chunk.queue_free()
	await _wait(1)


## C) The launch must survive the player mashing jump and duck.
func _test_launch_survives_input() -> void:
	print("===== C) THE LAUNCH SURVIVES INPUT =====")
	var plain := await _launch_and_measure(false)
	var mashed := await _launch_and_measure(true)
	print("  apex, launched cleanly         : %.2f m" % plain)
	print("  apex, mashing jump and duck    : %.2f m" % mashed)
	# An ordinary jump reaches 1.39 m. If either number lands near that, the
	# launch is being cancelled and the feature is broken.
	_chk(plain > 8.0, "a clean launch only reached %.2f m, expected ~9.1" % plain)
	_chk(mashed > 8.0,
		"mashing jump/duck cut the launch to %.2f m — _launch_lock is not working"
			% mashed)


func _launch_and_measure(mash: bool) -> float:
	GameState.restart_state_only()
	_player.velocity = Vector3.ZERO
	# Settle on whatever surface is underfoot, then measure the climb RELATIVE
	# to it. Absolute height is the wrong yardstick here: a previous launch can
	# leave the runner standing on the 7 m treetop deck, and the same 9 m climb
	# then reports as 16 m.
	for i in 200:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
	var base: float = _player.global_position.y
	_player.launch(TrackChunk.LAUNCH_SPEED)
	var apex := 0.0
	for i in 90:
		if mash:
			# Exactly what a player holding the keys would generate.
			_player.request_jump()
			_player.request_duck()
		await get_tree().physics_frame
		apex = maxf(apex, _player.global_position.y - base)
		# Stop at the top of the FIRST arc. This test runs on a live track with
		# treetop runs enabled, so carrying on would eventually catch a second
		# trampoline and report its height instead — which is how this once
		# reported a "mashed" launch reaching higher than a clean one.
		if _player.velocity.y < -1.0:
			break
	return apex


## The narrow stretch has to be exactly one lane wide, and it has to be the
## MIDDLE lane — if it drifted, the coins that mark it would be pointing at the
## wrong place and the whole cue would be a lie.
func _test_narrow_is_one_lane() -> void:
	var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(chunk)
	await _wait(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	chunk.randomise(rng, 0.5, false, true, chunk.Role.NARROW)
	await _wait(2)
	var col: CollisionShape3D = chunk.get_node("Skyway/Deck/CollisionShape3D")
	var box: BoxShape3D = col.shape
	var half: float = box.size.x * 0.5

	print("===== C2) THE NARROW STRETCH =====")
	print("  walkway is %.2f m wide, centred at x %.2f (a lane is %.2f m)"
		% [box.size.x, col.position.x, LaneConfig.LANE_WIDTH])
	_chk(absf(box.size.x - LaneConfig.LANE_WIDTH) < 0.01,
		"the narrow walkway is %.2f m, expected one lane (%.2f m)"
			% [box.size.x, LaneConfig.LANE_WIDTH])
	_chk(absf(col.position.x) < 0.01,
		"the narrow walkway is off-centre at x %.2f" % col.position.x)

	# The point of doing it sideways rather than as a hole: an outer lane has
	# to be COMPLETELY clear of it, so falling off leaves nothing to hit.
	var outer: float = absf(LaneConfig.lane_to_x(0))
	var gap_to_edge: float = outer - 0.40 - half
	print("  an outer lane clears the edge by %.2f m" % gap_to_edge)
	_chk(gap_to_edge > 0.3,
		"an outer-lane runner overlaps the narrow walkway by %.2f m, so falling off it collides"
			% -gap_to_edge)
	chunk.queue_free()
	await _wait(1)


## D) A full trip: run until the set-piece arrives, go up, run the deck, come
## back down, and still be alive.
func _test_round_trip() -> void:
	GameState.restart_state_only()
	await _wait(5)

	var apex := 0.0
	var stood_on_deck := 0
	var deck_y := 0.0
	var landed_back := false
	var died := false
	var slowest := 1e9
	var first_deck_at := 0.0
	var slow_y := 0.0
	var slow_frame := 0
	var slow_floor := false

	for i in 4200:
		await get_tree().physics_frame
		if not GameState.is_running():
			died = true
			break
		# NOTHING up here may block forward motion. move_and_slide writes the
		# collision response back into velocity, so a dip here means the runner
		# ran into something solid — which is exactly how the far edge of the
		# gap was caught stopping anyone who fell into it.
		if i > 120:
			var frac: float = absf(_player.velocity.z) / _player.forward_speed
			if frac < slowest:
				slowest = frac
				slow_y = _player.global_position.y
				slow_frame = i
				slow_floor = _player.is_on_floor()
		var y: float = _player.global_position.y
		apex = maxf(apex, y)
		if _player.is_on_floor() and y > 6.0:
			if stood_on_deck == 0:
				first_deck_at = GameState.distance
			stood_on_deck += 1
			deck_y = y
		elif stood_on_deck > 0 and _player.is_on_floor() and y < 0.5:
			landed_back = true
			break

	print("===== D) A FULL ROUND TRIP =====")
	print("  first treetop run met at: %.0f m" % first_deck_at)
	print("  highest point reached : %.2f m" % apex)
	print("  frames stood on deck  : %d  (%.2f s)" % [stood_on_deck, stood_on_deck / 60.0])
	print("  height while up there : %.2f m (deck top is %.2f)"
		% [deck_y, TrackChunk.DECK_Y])
	print("  got back to the ground: %s" % landed_back)
	print("  died at any point     : %s (want false)" % died)

	_chk(not died, "the runner died during the treetop section")
	_chk(apex > 6.0, "never got airborne — highest point was %.2f m" % apex)
	_chk(stood_on_deck > 60,
		"only stood on the deck for %d frames; the landing is missing the deck"
			% stood_on_deck)
	_chk(absf(deck_y - TrackChunk.DECK_Y) < 0.15,
		"stood at %.2f m, but the deck top is %.2f" % [deck_y, TrackChunk.DECK_Y])
	_chk(landed_back, "never came back down to the ground")
	# The number that decides whether anyone ever SEES this feature.
	_chk(first_deck_at > 0.0 and first_deck_at < 700.0,
		"the first treetop run is %.0f m in; almost nobody will live to see it"
			% first_deck_at)
	print("  slowest forward speed : %.0f%% of full, at y=%.2f, frame %d, on floor %s"
		% [slowest * 100.0, slow_y, slow_frame, slow_floor])
	# A little slack for the frame the runner actually touches down on.
	_chk(slowest > 0.90,
		"forward motion dropped to %.0f%% — something on the treetop run is blocking"
			% (slowest * 100.0))
