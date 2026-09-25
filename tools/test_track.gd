extends Node
## Endless-track checks.
##   A) the track never runs out, never leaves a hole, and never grows
##   B) generated obstacle rows ALWAYS leave at least one lane open
##   C) obstacles sit exactly on lane centres (player/track stay aligned)

const RUN_FRAMES := 3000        # 50 s at 60 Hz = 600 m

var _root: Node
var _track: TrackManager
var _player: CharacterBody3D
var _f := 0
var _fails := []

var _node_counts := []
var _min_y := 1e9
var _recycles_seen := 0
var _last_front := 0.0
var _rows_checked := 0
var _worst_free_lanes := 99
var _lane_x_error := 0.0


func _ready() -> void:
	_root = load("res://scenes/main.tscn").instantiate()
	# Part A runs on an empty track: we're testing the TRACK here, not whether
	# a scripted player can dodge. Obstacle correctness is Part B.
	# Must be set BEFORE add_child() — the track builds its first pieces in
	# _ready(), so setting it afterwards would leave those pieces populated
	# and the player could be blocked by one.
	_track = _root.get_node("TrackManager")
	_track.spawn_obstacles = false
	# The treetop run would rewrite the track under this test; keep it plain.
	_track.canopy_runs = false
	add_child(_root)
	_player = _root.get_node("Player")
	get_tree().physics_frame.connect(_tick)


func _tick() -> void:
	_f += 1
	var pz: float = _player.global_position.z
	_min_y = minf(_min_y, _player.global_position.y)

	if _f % 50 == 0:
		_node_counts.append(get_tree().get_node_count())
		_check_coverage(pz)

	if _f >= RUN_FRAMES:
		_finish_part_a()


## Every frame we sample: is there actually a piece of ground under the player,
## and do the pieces form one unbroken run with no gaps?
func _check_coverage(pz: float) -> void:
	var chunks := _track.get_children()
	var covered := false
	var edges := []
	for c in chunks:
		var near: float = c.position.z
		var far: float = near - LaneConfig.CHUNK_LENGTH
		edges.append([far, near])
		if pz <= near and pz >= far:
			covered = true
	if not covered:
		_fails.append("frame %d: NO track piece under the player (z=%.1f)" % [_f, pz])

	# sort by far edge and confirm each piece butts against the next
	edges.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(edges.size() - 1):
		var gap: float = edges[i + 1][0] - edges[i][1]
		if absf(gap) > 0.01:
			_fails.append("frame %d: %.3f m GAP between pieces at z=%.1f" % [_f, gap, edges[i][1]])
			break


func _finish_part_a() -> void:
	get_tree().physics_frame.disconnect(_tick)

	var travelled: float = _track.distance_travelled()
	var chunk_n: int = _track.get_child_count()
	var nodes_min: int = _node_counts.min()
	var nodes_max: int = _node_counts.max()

	print("\n===== A) TRACK CONTINUITY & POOLING =====")
	print("  distance run            = %.0f m" % travelled)
	print("  live pieces at end      = %d (configured %d)" % [chunk_n, _track.chunk_count])
	print("  scene node count        = %d .. %d over the whole run" % [nodes_min, nodes_max])
	print("  lowest player Y         = %.4f" % _min_y)

	if travelled < 500.0:
		_fails.append("player only covered %.0f m — it got stuck" % travelled)
	if chunk_n != _track.chunk_count:
		_fails.append("piece count drifted to %d (should stay %d)" % [chunk_n, _track.chunk_count])
	if nodes_max != nodes_min:
		_fails.append("node count grew %d -> %d — pieces are being created, not recycled" % [nodes_min, nodes_max])
	if _min_y < -1.0:
		_fails.append("player fell through the track (min y = %.2f)" % _min_y)

	_run_part_b()


## Generate a few hundred fresh rows and check every single one is passable.
func _run_part_b() -> void:
	var chunk: TrackChunk = _track.get_child(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	for i in 400:
		var difficulty := float(i) / 400.0
		chunk.randomise(rng, difficulty, false)

		# Group the live obstacles by which row they're in.
		var per_row := {}
		for ob in chunk.get_node("Obstacles").get_children():
			if not ob.visible:
				continue
			var key := snappedf(ob.position.z, 0.5)
			per_row[key] = per_row.get(key, 0) + 1

			# lane alignment: obstacle X must match a lane centre exactly
			var lane := LaneConfig.x_to_lane(ob.position.x)
			_lane_x_error = maxf(_lane_x_error, absf(ob.position.x - LaneConfig.lane_to_x(lane)))

		for key in per_row:
			_rows_checked += 1
			var free_lanes: int = LaneConfig.LANE_COUNT - per_row[key]
			_worst_free_lanes = mini(_worst_free_lanes, free_lanes)

	print("\n===== B) OBSTACLES ARE ALWAYS PASSABLE =====")
	print("  obstacle rows generated = %d" % _rows_checked)
	print("  fewest free lanes seen  = %d (must be >= 1)" % _worst_free_lanes)

	print("\n===== C) LANE ALIGNMENT =====")
	print("  worst obstacle-to-lane offset = %.6f m" % _lane_x_error)
	print("  lane centres = %s" % [_lane_centres()])

	if _rows_checked < 100:
		_fails.append("only %d rows generated — test isn't proving much" % _rows_checked)
	if _worst_free_lanes < 1:
		_fails.append("a row blocked EVERY lane — the run would be impossible")
	if _lane_x_error > 0.0001:
		_fails.append("obstacles are off-lane by %.4f m" % _lane_x_error)

	await _run_part_d()

	_test_pattern_table()
	_test_obstacle_contrast()
	await _test_pattern_pacing()
	await _test_coin_weave()

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL TRACK CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## D) Two hazards that fail SILENTLY:
##    1. Godot shares sub-resources across every instantiate() of a scene, so
##       all nine chunks could point at ONE BoxShape3D — resize one obstacle
##       and you resize all nine. track_chunk.gd calls duplicate() to break
##       that; this proves it worked.
##    2. Disabling collision must actually reach the physics server, not just
##       the node. A raycast is the only honest way to check.
func _run_part_d() -> void:
	var a: TrackChunk = _track.get_child(0)
	var b: TrackChunk = _track.get_child(1)
	var a0: CollisionShape3D = a.get_node("Obstacles/Obstacle0/CollisionShape3D")
	var b0: CollisionShape3D = b.get_node("Obstacles/Obstacle0/CollisionShape3D")

	print("\n===== D) POOLING SAFETY =====")
	var shared: bool = a0.shape.get_instance_id() == b0.shape.get_instance_id()
	print("  chunk A and chunk B share one collision shape? %s" % shared)

	var before: Vector3 = b0.shape.size
	(a0.shape as BoxShape3D).size = Vector3(9.0, 9.0, 9.0)
	var after: Vector3 = b0.shape.size
	print("  resized A's obstacle 0 -> B's obstacle 0 size %s -> %s" % [before, after])
	if shared:
		_fails.append("chunks SHARE collision shapes — resizing one obstacle resizes them all")
	if before != after:
		_fails.append("resizing chunk A's obstacle changed chunk B's")

	# put A back the way it was. FIXED seed, not RandomNumberGenerator.new():
	# an unseeded generator makes the raycast check below depend on the dice,
	# and it fails on roughly a third of runs for a reason that is not a bug
	# (see the landmark note there).
	var reroll := RandomNumberGenerator.new()
	reroll.seed = 555
	a.randomise(reroll, 0.5, false)

	# Collision is switched on and off with set_deferred, so it does not reach
	# the physics server until the END of the current frame. Wait one frame
	# before asking the physics engine anything, or you measure the old state.
	await get_tree().physics_frame

	# --- raycast proof that disabled really means non-solid ---
	var space := a.get_world_3d().direct_space_state
	var active := []
	var inactive := []
	for ob in a.get_node("Obstacles").get_children():
		if ob.visible:
			active.append(ob)
			continue
		# An obstacle hidden because a LANDMARK took its lane is not a fair
		# subject for this check: the landmark is sitting right there and is
		# supposed to be solid, so the ray stops on its roof at 1.10 m and the
		# obstacle gets blamed for it. Only test lanes with nothing else in
		# them.
		if a.landmark_lane >= 0 \
				and LaneConfig.x_to_lane(ob.position.x) == a.landmark_lane:
			continue
		inactive.append(ob)

	print("  live obstacles on the test piece: %d active, %d switched off" % [
		active.size(), inactive.size()])

	for ob in active:
		var hit_y := _ray_top(space, a, ob)
		if hit_y < 0.3:
			_fails.append("an ACTIVE obstacle is not solid (ray fell through to y=%.2f)" % hit_y)
		else:
			print("  active obstacle at lane x=%.1f -> ray stopped at y=%.2f (solid)" % [ob.position.x, hit_y])
		break
	for ob in inactive:
		var hit_y := _ray_top(space, a, ob)
		if hit_y > 0.3:
			_fails.append("a SWITCHED-OFF obstacle is still solid (ray stopped at y=%.2f)" % hit_y)
		else:
			print("  disabled obstacle -> ray passed through to the ground at y=%.2f" % hit_y)
		break


## Fires a ray straight down onto an obstacle and returns the height it hit.
func _ray_top(space: PhysicsDirectSpaceState3D, chunk: TrackChunk, ob: Node3D) -> float:
	var wx: float = ob.position.x
	var wz: float = chunk.position.z + ob.position.z
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(wx, 6.0, wz), Vector3(wx, -2.0, wz))
	var hit := space.intersect_ray(q)
	return hit.get("position", Vector3(0, -99, 0)).y


func _lane_centres() -> Array:
	var out := []
	for i in LaneConfig.LANE_COUNT:
		out.append(LaneConfig.lane_to_x(i))
	return out


## Coins may invite you to change lane, but never into something solid.
func _test_coin_weave() -> void:
	var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(chunk)
	await get_tree().physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var coins: Node3D = chunk.get_node("Coins")
	var obstacles: Node3D = chunk.get_node("Obstacles")

	var weaves := 0
	var unsafe := 0
	var laid := 0
	for roll in 300:
		chunk.randomise(rng, 0.5, false)
		await get_tree().physics_frame
		var lanes := {}
		for c in coins.get_children():
			if c.visible:
				lanes[LaneConfig.x_to_lane(c.position.x)] = true
		if lanes.size() >= 2:
			weaves += 1
		if not lanes.is_empty():
			laid += 1
		# Whatever shape they are in, no coin may sit INSIDE a live obstacle.
		# This has to be a proper 3D test: a coin arcing over a log sits right
		# above it in plan view and is entirely correct, so checking only x and
		# z reports every single arc as a bug.
		for c in coins.get_children():
			if not c.visible:
				continue
			for ob in obstacles.get_children():
				if not ob.visible:
					continue
				var shape: CollisionShape3D = ob.get_node_or_null("CollisionShape3D")
				if shape == null or shape.disabled:
					continue
				var box: BoxShape3D = shape.shape
				var centre: Vector3 = ob.position + shape.position
				var half: Vector3 = box.size * 0.5
				var d: Vector3 = (c.position - centre).abs()
				if d.x < half.x and d.y < half.y and d.z < half.z:
					unsafe += 1

	print("\n===== COIN LAYOUTS =====")
	print("  pieces that laid any coins  : %d of 300" % laid)
	print("  of those, weaving layouts   : %d" % weaves)
	print("  coins buried in an obstacle : %d  (want 0)" % unsafe)
	if weaves < laid / 12:
		_fails.append("only %d of the %d pieces that laid coins used a weave"
			% [weaves, laid])
	if unsafe > 0:
		_fails.append("%d coins were placed inside a live obstacle" % unsafe)
	chunk.queue_free()


## The five rules every authored obstacle pattern must obey.
##
## These are checked STATICALLY, against the table itself, rather than by
## rolling pieces and hoping to hit a bad one. A broken pattern might only
## surface one run in a hundred, and "we did not happen to see it" is not the
## same as "it is not there".
##
## Rules 3, 4 and 5 are the ones that actually strand a player, and all three
## were invisible in the original design — it obeyed them by accident, with
## nothing written down to stop the eleventh pattern breaking them.
func _test_pattern_table() -> void:
	var broken := 0
	for entry in TrackChunk.PATTERNS:
		var name: String = entry["name"]
		var rows: Array = entry["rows"]

		# 1. shape
		if rows.size() != TrackChunk.ROWS:
			_fails.append("pattern '%s' has %d rows, expected %d"
				% [name, rows.size(), TrackChunk.ROWS])
			broken += 1
			continue
		var bad := false
		for r in rows.size():
			if (rows[r] as Array).size() != LaneConfig.LANE_COUNT:
				_fails.append("pattern '%s' row %d has %d lanes, expected %d"
					% [name, r, (rows[r] as Array).size(), LaneConfig.LANE_COUNT])
				bad = true
		if bad:
			broken += 1
			continue

		# 2. never block every lane
		for r in rows.size():
			if not (rows[r] as Array).has(TrackChunk.Cell.GAP):
				_fails.append("pattern '%s' row %d blocks every lane" % [name, r])
				broken += 1

		# 3. no jump in the LAST row — a held jump carries about 19 m, more
		#    than the 15 m to the next row, so it would fly off the end of the
		#    piece into whatever the next one happens to start with.
		var last: Array = rows[TrackChunk.ROWS - 1]
		if last.has(TrackChunk.Cell.HOP):
			_fails.append("pattern '%s' puts a jump in the last row" % name)
			broken += 1

		# 4. a jump must land on clear road
		for lane in LaneConfig.LANE_COUNT:
			if rows[0][lane] == TrackChunk.Cell.HOP \
					and last[lane] != TrackChunk.Cell.GAP:
				_fails.append("pattern '%s' lane %d jumps into something solid"
					% [name, lane])
				broken += 1

		# 5. no full-width chicane: one gap at one edge, then only the other
		#    edge. That demands two lane changes in the 0.75 s that 15 m buys
		#    at top speed, and one change alone costs 0.37 s.
		var g0 := _gaps(rows[0])
		var g1 := _gaps(last)
		if g0.size() == 1 and g1.size() == 1 and absi(g0[0] - g1[0]) > 1:
			_fails.append("pattern '%s' is a full-width chicane (lane %d then lane %d)"
				% [name, g0[0], g1[0]])
			broken += 1

	# 6. At least a few shapes must be unlocked the moment patterns switch on.
	#    Set every min_diff above the gate and the feature simply never fires,
	#    silently — no error, no obstacle, just the old random rows forever.
	var at_gate := 0
	for entry in TrackChunk.PATTERNS:
		if float(entry["min_diff"]) <= TrackChunk.PATTERN_MIN_DIFF:
			at_gate += 1
	if at_gate < 3:
		_fails.append("only %d patterns are unlocked at the %.2f gate; the feature barely fires"
			% [at_gate, TrackChunk.PATTERN_MIN_DIFF])

	print("\n===== PATTERN TABLE =====")
	print("  %d unlocked at the difficulty gate" % at_gate)
	print("  %d authored patterns, %d breaking a rule (want 0)"
		% [TrackChunk.PATTERNS.size(), broken])


func _gaps(row: Array) -> Array[int]:
	var out: Array[int] = []
	for lane in row.size():
		if row[lane] == TrackChunk.Cell.GAP:
			out.append(lane)
	return out


## Difficulty should PACE the patterns, and the same shape should not arrive
## twice running.
func _test_pattern_pacing() -> void:
	var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(chunk)
	await get_tree().physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337

	# EARLY: nothing above the difficulty may appear.
	var early := {}
	var too_hard := 0
	for i in 400:
		chunk.randomise(rng, 0.15, false, false)
		await get_tree().physics_frame
		if chunk.pattern_name == "":
			continue
		early[chunk.pattern_name] = true
		for entry in TrackChunk.PATTERNS:
			if String(entry["name"]) == chunk.pattern_name \
					and float(entry["min_diff"]) > 0.15:
				too_hard += 1

	# LATE: the whole table should be reachable.
	var late := {}
	for i in 600:
		chunk.randomise(rng, 1.0, false, false)
		await get_tree().physics_frame
		if chunk.pattern_name != "":
			late[chunk.pattern_name] = true

	# And never the same shape twice running, which is what the manager's
	# memory of the last one is for.
	var repeats := 0
	var previous := ""
	for i in 400:
		chunk.randomise(rng, 1.0, false, false, TrackChunk.Role.NORMAL, previous)
		await get_tree().physics_frame
		if chunk.pattern_name != "" and chunk.pattern_name == previous:
			repeats += 1
		previous = chunk.pattern_name

	print("\n===== PATTERN PACING =====")
	print("  shapes seen at difficulty 0.15 : %d" % early.size())
	print("  ...of those, too hard for it   : %d  (want 0)" % too_hard)
	print("  shapes seen at difficulty 1.00 : %d of %d" % [late.size(), TrackChunk.PATTERNS.size()])
	print("  back-to-back repeats in 400    : %d  (want 0)" % repeats)

	if too_hard > 0:
		_fails.append("%d pieces used a pattern above their difficulty" % too_hard)
	if early.size() < 2:
		_fails.append("only %d shapes ever appeared early; pacing has locked it down too hard"
			% early.size())
	if late.size() < TrackChunk.PATTERNS.size():
		_fails.append("only %d of %d shapes are reachable at full difficulty"
			% [late.size(), TrackChunk.PATTERNS.size()])
	if repeats > 0:
		_fails.append("the same shape came up twice running %d times" % repeats)
	chunk.queue_free()


## The thing you must not hit has to be the thing you notice.
##
## Printed by the audit too, but ASSERTED here, because this is not decoration:
## an obstacle you cannot pick out of the background is an unfair death, and it
## is the same class of bug as a lane you cannot reach. Measured before this
## palette existed, the vines scored 1.00 against the jungle — the two colours
## were the same brightness, so the thing you had to duck was invisible.
func _test_obstacle_contrast() -> void:
	var dirt := Color(0.46, 0.33, 0.20)
	var leaf := Color(0.17, 0.44, 0.19)
	var worst := 99.0
	var worst_name := ""
	for label in ["ob_wood", "ob_wood_pale", "ob_stone", "ob_stone_dark",
			"ob_vine", "ob_leaf", "ob_snake", "ob_snake_dark", "ob_fungus"]:
		var res := load("res://materials/%s.tres" % label)
		if res == null:
			_fails.append("obstacle material '%s' is missing" % label)
			continue
		var col: Color = res.albedo_color if res is StandardMaterial3D \
			else res.get_shader_parameter("albedo")
		# The WORSE of the two backgrounds is what counts — an obstacle is met
		# against the path or against the jungle, and it must work on both.
		var weakest: float = minf(_contrast_of(col, dirt), _contrast_of(col, leaf))
		if weakest < worst:
			worst = weakest
			worst_name = label
	print("\n===== OBSTACLE CONTRAST =====")
	print("  weakest: %s at %.2f against its background (want 1.60+)"
		% [worst_name, worst])
	if worst < 1.6:
		_fails.append("obstacle colour '%s' is only %.2f against the background — invisible"
			% [worst_name, worst])


func _contrast_of(a: Color, b: Color) -> float:
	var la: float = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b + 0.05
	var lb: float = 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b + 0.05
	return maxf(la, lb) / minf(la, lb)
