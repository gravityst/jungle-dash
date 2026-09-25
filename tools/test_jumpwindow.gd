extends Node
## JUMPING SHOULD NOT BE A TRAP.
##
## Two separate things are checked here, and the second is the one that
## actually made jumping feel like it had no margin for error.
##
## A) HOW LONG YOU HAVE TO PRESS. Swept against the real colliders. This turned
##    out to be fine all along — 350 ms or more — which is why measuring
##    mattered: the obvious fix (make the jump bigger) would have been aimed at
##    a problem that did not exist.
##
## B) WHAT IS WAITING WHEN YOU LAND. A jump is 0.717 s, which at the 20 m/s cap
##    carries 14.3 m. The rows are 15 m apart. So you touch down 0.7 m before
##    the next row — 0.035 s — and if the key was held you are still airborne
##    when you reach it. You cannot duck in mid-air and you cannot change lane
##    in 0.035 s, so anything in that lane is unavoidable. Not hard:
##    unavoidable. The landing lane must always be clear.

var _root: Node
var _track: Node3D
var _player: CharacterBody3D
var _fails := []

## Sections that ran all the way to the end. A runtime error inside an awaited
## function aborts THAT function and lets the caller carry on, so without this
## a section could die silently and the suite would still print PASSED — which
## is exactly what happened the first time this test was written.
var _done := {}


func _ready() -> void:
	_run()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _chk(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _run() -> void:
	await _test_landing_lane_is_clear()

	_root = load("res://scenes/main.tscn").instantiate()
	_track = _root.get_node("TrackManager")
	_track.spawn_obstacles = false
	_track.canopy_runs = false
	_track.random_seed = 404
	get_tree().root.add_child.call_deferred(_root)
	await _wait(2)
	get_tree().current_scene = _root
	_player = _root.get_node("Player")
	# Never file test deaths on a real person's scoreboard.
	GameState.record_runs = false
	GameState.restart_state_only()
	await _wait(2)
	await _test_press_window()

	for section in ["landing_lane", "press_window"]:
		if not _done.has(section):
			_fails.append("section '%s' did not finish — look for a SCRIPT ERROR above"
				% section)

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL JUMP CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## B) No piece may put anything in the lane a jump lands in — within the piece,
##    or carried in from the piece before.
func _test_landing_lane_is_clear() -> void:
	var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(chunk)
	await _wait(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	var obstacles: Node3D = chunk.get_node("Obstacles")

	var traps := 0
	var jumps := 0
	var entry_violations := 0
	var carried := 0

	for roll in 600:
		# Alternate between letting the previous piece hand over a jump lane
		# and not, so both halves of the rule get exercised.
		# Built explicitly rather than with a ternary: `[] `in an `if/else`
		# expression is an untyped Array and will not assign to Array[int].
		var entry: Array[int] = []
		if roll % 2 == 0:
			entry.append(roll % LaneConfig.LANE_COUNT)
		chunk.randomise(rng, 0.7, false, true, TrackChunk.Role.NORMAL, "", entry)
		await get_tree().physics_frame

		# Read the rows back off the live obstacle nodes, not off an internal
		# array — what the player meets is what is actually in the scene.
		var grid := {}
		for ob in obstacles.get_children():
			if not ob.visible:
				continue
			# The BODY is called "Obstacle3"; what it currently is shows as the
			# one visible mesh child, named after its kind.
			var kind := ""
			for child in ob.get_children():
				if child is MeshInstance3D and (child as MeshInstance3D).visible:
					kind = child.name
					break
			if kind == "":
				continue
			var row: int = 0 if absf(ob.position.z - chunk.ROW_Z[0]) < 0.01 else 1
			grid[[row, LaneConfig.x_to_lane(ob.position.x)]] = kind

		for lane in LaneConfig.LANE_COUNT:
			var first: String = grid.get([0, lane], "")
			if first == "Log" or first == "Rock":
				jumps += 1
				if grid.has([1, lane]):
					traps += 1
		for lane in entry:
			carried += 1
			if grid.has([0, lane]):
				entry_violations += 1

	print("===== B) WHAT IS WAITING WHEN YOU LAND =====")
	print("  pieces rolled                  : 600")
	print("  jumps set up in the first row  : %d" % jumps)
	print("  ...landing on something        : %d  (want 0)" % traps)
	print("  lanes handed over from before  : %d" % carried)
	print("  ...blocked anyway              : %d  (want 0)" % entry_violations)

	_chk(jumps > 40, "only %d jumps appeared in 600 rolls; this proves nothing" % jumps)
	_chk(traps == 0,
		"%d jumps land on something solid 0.035 s after touching down" % traps)
	_chk(entry_violations == 0,
		"%d lanes were blocked despite the previous piece jumping into them"
			% entry_violations)
	_done["landing_lane"] = true
	chunk.queue_free()
	await _wait(1)


## A) The press window, swept coarsely against the real colliders.
func _test_press_window() -> void:
	print("\n===== A) HOW LONG YOU HAVE TO PRESS =====")
	var worst := 1e9
	for spec in [
		{"name": "log ", "size": Vector3(2.00, 0.80, 0.70), "y": 0.40},
		{"name": "rock", "size": Vector3(2.00, 0.80, 1.15), "y": 0.40},
	]:
		var speed := 20.0
		var earliest := -1.0
		var latest := -1.0
		var lead := 1.0
		while lead <= 12.0:
			if await _survives(spec, speed, lead):
				if latest < 0.0:
					latest = lead
				earliest = lead
			lead += 0.5
		if latest < 0.0:
			_fails.append("%s cannot be jumped at all at %.0f m/s" % [spec["name"], speed])
			continue
		var ms: float = (earliest - latest) / speed * 1000.0
		print("  %s at %.0f m/s: press between %.1f m and %.1f m out -> %.0f ms"
			% [spec["name"], speed, latest, earliest, ms])
		worst = minf(worst, ms)

	print("  tightest window: %.0f ms" % worst)
	# A person pressing a key lands within roughly 60 ms of where they meant
	# to. Under about 180 ms total and the game is a timing test, not a runner.
	_chk(worst >= 180.0,
		"the tightest jump window is %.0f ms, which is a timing test" % worst)
	_done["press_window"] = true


func _survives(spec: Dictionary, speed: float, lead: float) -> bool:
	GameState.restart_state_only()
	_player.speed_ramp = 0.0
	_player.forward_speed = 0.0
	_player.velocity = Vector3.ZERO
	_player.global_position.x = LaneConfig.lane_to_x(1)
	for i in 120:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break

	var ob := StaticBody3D.new()
	ob.add_to_group("obstacle")
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = spec["size"]
	col.shape = box
	col.position.y = spec["y"]
	ob.add_child(col)
	add_child(ob)
	var ob_z: float = _player.global_position.z - 26.0
	ob.global_position = Vector3(LaneConfig.lane_to_x(1), 0.0, ob_z)

	_player.forward_speed = speed
	var pressed := false
	var survived := true
	for i in 300:
		await get_tree().physics_frame
		if not GameState.is_running():
			survived = false
			break
		var gap: float = _player.global_position.z - ob_z
		if not pressed and gap <= lead:
			_player.request_jump()
			pressed = true
		if gap < -4.0:
			break
	ob.queue_free()
	await _wait(1)
	_player.speed_ramp = 0.22
	return survived
