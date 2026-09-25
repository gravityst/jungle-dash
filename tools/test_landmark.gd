extends Node
## The long ridable landmarks — the jungle's trains.
##   A) they generate at a sane rate and never trap the player
##   B) the player can jump on and RUN ALONG one
##   C) running into the blunt end still kills

var _root: Node
var _track: Node3D
var _player: CharacterBody3D
var _fails := []
var _reserved_ok := true
var _edge_only := true


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
	await _wait(3)

	_test_generation()
	await _test_riding()
	await _test_end_kills()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL LANDMARK CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## Roll a lot of pieces and check the rules hold every time.
func _test_generation() -> void:
	var chunk: TrackChunk = _track.get_child(3)
	var rng := RandomNumberGenerator.new()
	var with_landmark := 0
	var rounds := 3000
	var worst_open := 99
	var kinds := {}

	for i in rounds:
		rng.seed = i * 6151
		chunk.randomise(rng, 0.9, false, true)
		if chunk.landmark_lane < 0:
			continue
		with_landmark += 1
		# There must ALWAYS be a reserved lane, and it must never be the
		# landmark's own lane, or there is no continuous path past it.
		if chunk.landmark_safe_lane < 0 or chunk.landmark_safe_lane == chunk.landmark_lane:
			_reserved_ok = false
		# A middle-lane landmark isolates the two outer lanes from each other,
		# which is unsurvivable if you are in the wrong one. Edge only.
		if chunk.landmark_lane != 0 and chunk.landmark_lane != LaneConfig.LANE_COUNT - 1:
			_edge_only = false
		for ob2 in chunk.get_node("Obstacles").get_children():
			if ob2.visible and LaneConfig.x_to_lane(ob2.position.x) == chunk.landmark_safe_lane:
				_reserved_ok = false
		for m in chunk.get_node("Landmarks/Landmark0").get_children():
			if m is MeshInstance3D and m.visible:
				kinds[m.name] = int(kinds.get(m.name, 0)) + 1

		# With a lane eaten by the landmark, count how many lanes a row leaves
		# genuinely open. It must never be zero.
		var per_row := {}
		for ob in chunk.get_node("Obstacles").get_children():
			if ob.visible:
				per_row[snappedf(ob.position.z, 0.5)] = int(
					per_row.get(snappedf(ob.position.z, 0.5), 0)) + 1
		for key in per_row:
			var open_lanes: int = LaneConfig.LANE_COUNT - 1 - int(per_row[key])
			worst_open = mini(worst_open, open_lanes)

	print("\n===== A) GENERATION =====")
	print("  pieces rolled          %d" % rounds)
	print("  with a landmark        %d (%.0f%%)" % [
		with_landmark, 100.0 * float(with_landmark) / float(rounds)])
	print("  kinds seen             %s" % [kinds])
	print("  fewest open lanes in a row alongside a landmark: %d (must be >= 1)" % worst_open)
	print("  reserved through-lane always set: %s" % _reserved_ok)
	print("  landmarks confined to edge lanes: %s" % _edge_only)

	_chk(with_landmark > rounds / 8, "landmarks almost never appear")
	_chk(with_landmark < rounds * 3 / 4, "landmarks appear far too often")
	_chk(kinds.size() >= 2, "only one kind of landmark ever shows up")
	_chk(worst_open >= 1, "a row left ZERO lanes open next to a landmark — impossible run")
	_chk(_reserved_ok, "the reserved through-lane was missing or had an obstacle dropped in it")
	_chk(_edge_only, "a landmark was placed in a MIDDLE lane — that traps a player in an outer lane")
	chunk.randomise(RandomNumberGenerator.new(), 0.0, true, false)


## Build our own landmark and actually run the player onto it.
func _test_riding() -> void:
	var top := 1.10
	var length := 16.0
	var lm := StaticBody3D.new()
	lm.add_to_group("obstacle")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, top, length)
	col.shape = box
	col.position.y = top * 0.5
	lm.add_child(col)
	add_child(lm)

	_player.global_position = Vector3(0.0, 0.0, 0.0)
	_player.velocity = Vector3.ZERO
	_player.forward_speed = 20.0      # the hardest case: top speed
	_player.speed_ramp = 0.0
	await _wait(4)
	# Put the near end 14 m ahead, box centred half a length beyond that.
	lm.global_position = Vector3(0.0, 0.0, _player.global_position.z - 14.0 - length * 0.5)

	# Jump so the arc peaks over the lip: at 20 m/s the player is above 1.10 m
	# between roughly 3.6 m and 8.9 m after take-off.
	var jumped := false
	var heights := []
	var on_top_frames := 0
	for i in 150:
		var dist: float = _player.global_position.z - (lm.global_position.z + length * 0.5)
		if not jumped and dist < 6.0:
			_player.request_jump()
			jumped = true
		await _wait(1)
		var y: float = _player.global_position.y
		heights.append(y)
		if y > top - 0.15 and _player.is_on_floor():
			on_top_frames += 1

	print("\n===== B) RIDING ONE =====")
	print("  landmark top      %.2f m" % top)
	print("  peak height       %.2f m" % heights.max())
	print("  frames stood ON it %d" % on_top_frames)
	print("  still alive        %s" % GameState.is_running())

	_chk(GameState.is_running(), "died while trying to ride it")
	_chk(on_top_frames > 25, "never settled on the roof (%d frames)" % on_top_frames)
	lm.queue_free()
	await _wait(2)


## The blunt end must still be fatal, or the whole thing is a ramp.
func _test_end_kills() -> void:
	GameState.restart_state_only()
	_player.global_position = Vector3(0.0, 0.0, _player.global_position.z)
	_player.velocity = Vector3.ZERO
	await _wait(5)

	var lm := StaticBody3D.new()
	lm.add_to_group("obstacle")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.10, 16.0)
	col.shape = box
	col.position.y = 0.55
	lm.add_child(col)
	add_child(lm)
	lm.global_position = Vector3(0.0, 0.0, _player.global_position.z - 8.0 - 8.0)
	_player.forward_speed = 20.0
	await _wait(90)     # run straight at it, no jump

	print("\n===== C) THE END FACE STILL KILLS =====")
	print("  alive after running into it: %s (want false)" % GameState.is_running())
	_chk(not GameState.is_running(), "ran straight into the end of a landmark and survived")
