extends Node
## THE COACH — its advice has to be RIGHT, not just visible.
##
##   A) It finds the obstacle in your lane and names the right action.
##   B) Doing what it says, when it says NOW, clears the obstacle cleanly —
##      instantly, or after a 0.2 s or a slow 0.35 s reaction, at the starting
##      speed and at top speed, for every jumpable and every slide gate. No
##      stumble allowed: a cue that gets you clipped is a bad cue.
##   C) It learns, forgets on a hit, and remembers across a save.
##   D) Robots never get coached.
##   E) Every crash gets an explanation.
##
## Section B is the one that matters. If a physics retune ever breaks it,
## re-derive NOW_SECONDS from the window rather than loosening the check.

const Coach := preload("res://scripts/coach.gd")
const Chunk := preload("res://scripts/track_chunk.gd")

var _root: Node
var _player: CharacterBody3D
var _fails := []
var _stumbles := 0


func _ready() -> void:
	_run()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _chk(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _run() -> void:
	print("===== D) ROBOTS ARE NOT COACHED =====")
	print("  coaching on launch from tools/: %s" % GameState.coaching)
	_chk(not GameState.coaching, "the coach is on for a robot launched from tools/")

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

	await _test_threat()
	await _test_cues()
	await _test_jump_on()
	_test_memory()
	_test_explain()

	GameState.coaching = false
	GameState.record_runs = false
	GameState.save_path = GameState.SAVE_PATH
	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL COACH CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _test_threat() -> void:
	GameState.coaching = true
	var coach: Node = _root.get_node("HUD").get_node("%Coach")
	# The first piece fully ahead of the runner.
	var chunk: Node = null
	for c in _root.get_node("TrackManager").get_children():
		if c.has_method("randomise") and c.position.z < _player.global_position.z - 20.0:
			if chunk == null or c.position.z > chunk.position.z:
				chunk = c
	var slots: Array = chunk.get_node("Obstacles").get_children()
	var local_z: float = _player.global_position.z - 12.0 - chunk.position.z
	chunk._apply_slot(slots[0], Chunk.Slot.ROCK, LaneConfig.lane_to_x(1), local_z)
	chunk._apply_slot(slots[1], Chunk.Slot.TREE, LaneConfig.lane_to_x(0), local_z)
	_player.current_lane = 1
	await _wait(2)
	var t: Dictionary = coach._next_threat(1)
	print("\n===== A) WHAT IS IN MY LANE =====")
	print("  lane 1: %s  (%s at %.1f m)" % [t.get("family", "-"), t.get("what", "-"), t.get("dist", -1.0)])
	_chk(t.get("family", "") == "jump" and t.get("what", "") == "boulder",
		"boulder in lane 1 read as %s / %s" % [t.get("family", "-"), t.get("what", "-")])
	var t0: Dictionary = coach._next_threat(0)
	var e0: Dictionary = t0.get("escape", {})
	print("  lane 0: %s, escape %s" % [t0.get("family", "-"), e0])
	_chk(t0.get("family", "") == "dodge", "tree in lane 0 was not a dodge")
	# Lane 1 is blocked at the same depth by the boulder, lane 2 is clear:
	# the right advice is to head right (two moves), not "no way round".
	_chk(int(e0.get("dir", 0)) == 1 and String(e0.get("state", "")) == "same",
		"from lane 0 past a same-row block the advice should be GO RIGHT (two moves), got %s" % e0)
	# Now put something NEARER in lane 1: the way round is to WAIT, then go.
	var near_z: float = _player.global_position.z - 5.0 - chunk.position.z
	chunk._apply_slot(slots[0], Chunk.Slot.PILLAR, LaneConfig.lane_to_x(1), near_z)
	chunk._apply_slot(slots[1], Chunk.Slot.TREE, LaneConfig.lane_to_x(0), local_z)
	chunk._apply_slot(slots[2], Chunk.Slot.TREE, LaneConfig.lane_to_x(2), local_z)
	await _wait(1)
	var t1: Dictionary = coach._next_threat(0)
	var e1: Dictionary = t1.get("escape", {})
	print("  lane 0 with a nearer stela in lane 1: escape %s" % e1)
	_chk(String(e1.get("state", "")) == "wait" and int(e1.get("dir", 0)) == 1,
		"with something nearer in the only way round, the advice should be WAIT then right, got %s" % e1)
	for i in 3:
		chunk._apply_slot(slots[i], Chunk.Slot.EMPTY, 0.0, 0.0)
	GameState.coaching = false
	await _wait(2)


func _test_cues() -> void:
	print("\n===== B) DOING WHAT IT SAYS, WHEN IT SAYS, WORKS =====")
	var cases := []
	for slot in Chunk.JUMPABLE + Chunk.DUCKABLE:
		cases.append(slot)
	for slot in cases:
		var spec: Dictionary = Chunk.SPEC[slot]
		var family := Chunk.family_of(slot)
		var cue: float = Coach.NOW_SECONDS[family]
		for speed in [12.0, 20.0]:
			var line := "  %-13s %4.0f m/s:" % [Chunk.NAMES[slot], speed]
			for delay in [0.0, 0.2, 0.35]:
				var ok: bool = await _clean_pass(spec, speed, (cue - delay) * speed, family)
				line += "  +%.2fs %s" % [delay, "ok" if ok else "FAIL"]
				_chk(ok, "%s at %.0f m/s: acting %.2f s after the NOW cue did not clear it cleanly"
					% [Chunk.NAMES[slot], speed, delay])
			print(line)


## Runs at a real collider of the obstacle's size and acts when it is `lead`
## metres away. True only for a clean pass: alive, and no stumble.
func _clean_pass(spec: Dictionary, speed: float, lead: float, family: String,
		centre_offset: float = 0.0, must_ride: bool = false) -> bool:
	GameState.restart_state_only()
	GameState.heat_time = 0.0
	_player.speed_ramp = 0.0
	_player.forward_speed = 0.0
	_player.velocity = Vector3.ZERO
	_player.current_lane = 1
	_player.global_position.x = LaneConfig.lane_to_x(1)
	for i in 120:
		await get_tree().physics_frame
		if _player.is_on_floor() and not _player.is_ducking():
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
	var ob_z: float = _player.global_position.z - 30.0 - centre_offset
	ob.global_position = Vector3(LaneConfig.lane_to_x(1), 0.0, ob_z)
	var rode := false
	var stumbles_before := _stumbles
	_player.forward_speed = speed
	var acted := false
	var ok := true
	for i in 400:
		await get_tree().physics_frame
		if not GameState.is_running() or _stumbles != stumbles_before:
			ok = false
			break
		var gap: float = _player.global_position.z - ob_z
		if not acted and gap <= lead:
			if family == "jump":
				_player.request_jump()
			else:
				_player.request_duck()
			acted = true
		if _player.is_on_floor() and _player.global_position.y > Chunk.LANDMARK_TOP - 0.1:
			rode = true
		if gap < -4.0 - centre_offset:
			break
	if must_ride and not rode:
		ok = false
	ob.queue_free()
	await _wait(2)
	_player.speed_ramp = 0.22
	return ok


## JUMP ON: doing it when the card says NOW lands you on a landmark's roof.
func _test_jump_on() -> void:
	print("\n===== B2) JUMP ON! LANDS YOU ON THE ROOF =====")
	var spec := {"size": Vector3(1.6, Chunk.LANDMARK_TOP, Chunk.LANDMARK_LEN),
		"y": Chunk.LANDMARK_TOP * 0.5}
	if OS.get_environment("COACH_SWEEP") != "":
		# Measure the real window: which press times (seconds before the near
		# end) land on the roof, at each speed.
		for speed in [12.0, 20.0]:
			var line := "  sweep %4.0f m/s:" % speed
			var t := 0.05
			while t <= 0.95:
				var ok: bool = await _clean_pass(spec, speed, t * speed + Chunk.LANDMARK_LEN * 0.5,
					"jump", Chunk.LANDMARK_LEN * 0.5, true)
				line += " %.2f%s" % [t, "+" if ok else "."]
				t += 0.05
			print(line)
	var cue: float = Coach.NOW_SECONDS["wall"]
	for speed in [12.0, 20.0]:
		var line := "  landmark      %4.0f m/s:" % speed
		for delay in [0.0, 0.2, 0.35]:
			# The collider's near end is where the card measures to; the box
			# is centred half its length further on.
			var ok: bool = await _clean_pass(spec, speed, (cue - delay) * speed + Chunk.LANDMARK_LEN * 0.5,
				"jump", Chunk.LANDMARK_LEN * 0.5, true)
			line += "  +%.2fs %s" % [delay, "ok" if ok else "FAIL"]
			_chk(ok, "landmark at %.0f m/s: jumping %.2f s after JUMP ON! did not land on the roof"
				% [speed, delay])
		print(line)


func _test_memory() -> void:
	print("\n===== C) IT LEARNS, AND REMEMBERS =====")
	GameState.coaching = true
	GameState.save_path = "user://test_coach_save.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	GameState.record_runs = true
	for k in GameState.coach_state["learned"]:
		GameState.coach_state["learned"][k] = 0
	var lv0 := GameState.coach_level("jump")
	for i in GameState.COACH_LEARN - 1:
		GameState.coach_cleared("jump")
	var lv1 := GameState.coach_level("jump")
	GameState.coach_cleared("jump")
	var lv2 := GameState.coach_level("jump")
	print("  new: %d   after %d clears: %d   after %d: %d" % [lv0, GameState.COACH_LEARN - 1, lv1,
		GameState.COACH_LEARN, lv2])
	_chk(lv0 == 2 and lv1 == 1 and lv2 == 0, "coach levels went %d/%d/%d, expected 2/1/0" % [lv0, lv1, lv2])
	GameState.coach_failed("jump")
	print("  after a hit: %d" % GameState.coach_level("jump"))
	_chk(GameState.coach_level("jump") == 1, "a hit did not bring the (short) coach back")
	GameState.coach_cleared("duck")
	GameState.save_board()
	var saved: Dictionary = GameState.coach_state.duplicate(true)
	for k in GameState.coach_state["learned"]:
		GameState.coach_state["learned"][k] = 7
	GameState._load_progress()
	print("  saved %s  loaded %s" % [saved["learned"], GameState.coach_state["learned"]])
	_chk(GameState.coach_state["learned"] == saved["learned"], "coach memory lost across a reload")
	GameState.coach_state["mode"] = "off"
	_chk(GameState.coach_level("jump") == 0, "coach mode OFF still coaches")
	GameState.coach_state["mode"] = "auto"
	GameState.record_runs = false
	GameState.coaching = false


func _test_explain() -> void:
	print("\n===== E) EVERY CRASH HAS A REASON =====")
	var empty := true
	for slot in Chunk.SPEC.keys():
		for how in ["side", "lip", "face"]:
			for air in [false, true]:
				for duck in [false, true]:
					var why := Coach.explain({"slot": slot, "how": how, "airborne": air,
						"rising": air, "ducking": duck, "ms_since_duck": 400})
					if why[0] == "" or why[1] == "":
						empty = false
						_fails.append("no reason for %s/%s air=%s duck=%s" % [slot, how, air, duck])
	var wall := Coach.explain({"landmark": true, "what": "temple wall", "how": "face"})
	var caught := Coach.explain({}, true)
	print("  e.g.  %s / %s" % [wall[0], wall[1]])
	print("        %s / %s" % [caught[0], caught[1]])
	_chk(empty, "some crash combinations have no explanation")
	_chk(Coach.explain({})[0] != "", "an empty hit gives no headline")
