extends Node
## Long-run playability: can the game actually be PLAYED, with obstacles and
## death on, for a sustained run?
##
## WHAT THIS TEST IS AND IS NOT. The bot is a simple heuristic — it looks a
## fixed time ahead, scores each lane by clear road, and checks the lanes it
## would cross. It is NOT a skill ceiling, and at the 20 m/s top speed it dies.
## Its distance also varies enormously between seeds: 922 m, 2767 m and 4357 m
## on three consecutive runs of the same build. So a single run on a random
## seed tells you almost nothing.
##
## Hence: three FIXED seeds, and a bar on the MEDIAN. What this catches is a
## change that makes the game dramatically harder. Fairness itself is proved
## elsewhere and by construction — test_landmark asserts a reserved
## through-lane always exists beside a landmark, and test_track asserts every
## obstacle row leaves a lane open.

const RUN_FRAMES := 6000         # 100 s each at 60 Hz
const SEEDS := [101, 202, 303]
## The median must clear this. Well under the 1855 m the bot currently manages
## on every seed — and 1855 m is the CEILING, not a lucky run: the speed ramp
## (12 m/s, +0.22 m/s², capped at 20) puts exactly that much track under you in
## 100 s, so hitting it means the bot never died. The floor sits well below
## that, so it fires on a real regression rather than on noise.
const MEDIAN_FLOOR := 1200.0

var _results := []
var _fails := []


func _ready() -> void:
	_run_all()


func _run_all() -> void:
	for seed_value in SEEDS:
		var r := await _one_run(seed_value)
		_results.append(r)
		print("  seed %-4d %6.0f m   %3d coins  %3d jumps  %s" % [
			seed_value, r["distance"], r["coins"], r["jumps"],
			"survived" if r["alive"] else "died"])

	var dists := []
	for r in _results:
		dists.append(r["distance"])
	dists.sort()
	var median: float = dists[dists.size() / 2]

	print("\n===== AUTOPLAY OVER %d SEEDS =====" % SEEDS.size())
	print("  distances   %s" % [dists])
	print("  median      %.0f m (floor %.0f)" % [median, MEDIAN_FLOOR])
	var nodes_stable := true
	for r in _results:
		if r["node_min"] != r["node_max"]:
			nodes_stable = false
	print("  node count  stable across every run: %s" % nodes_stable)

	if median < MEDIAN_FLOOR:
		_fails.append("median distance %.0f m is below the %.0f m floor" % [median, MEDIAN_FLOOR])
	if not nodes_stable:
		_fails.append("node count changed during a run — something is leaking")

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL AUTOPLAY CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _one_run(seed_value: int) -> Dictionary:
	var root_node: Node = load("res://scenes/main.tscn").instantiate()
	var track: TrackManager = root_node.get_node("TrackManager")
	track.random_seed = seed_value
	add_child(root_node)
	var player: CharacterBody3D = root_node.get_node("Player")
	var bot: Node = load("res://tools/autopilot.gd").new()
	add_child(bot)
	bot.setup(player, track)
	# Never file test deaths on a real person's scoreboard.
	GameState.record_runs = false
	GameState.restart_state_only()

	var node_min := 1 << 30
	var node_max := 0
	var jumps := 0
	var was_air := false
	var min_y := 1e9

	for f in RUN_FRAMES:
		await get_tree().physics_frame
		min_y = minf(min_y, player.global_position.y)
		var air := not player.is_on_floor()
		if air and not was_air:
			jumps += 1
		was_air = air
		if f % 60 == 0:
			var n := get_tree().get_node_count()
			node_min = mini(node_min, n)
			node_max = maxi(node_max, n)
		if not GameState.is_running():
			break

	var out := {
		"distance": track.distance_travelled(),
		"coins": GameState.coins,
		"jumps": jumps,
		"alive": GameState.is_running(),
		"node_min": node_min,
		"node_max": node_max,
	}
	if min_y < -1.0:
		_fails.append("seed %d: fell through the track (min y %.2f)" % [seed_value, min_y])
	bot.queue_free()
	root_node.queue_free()
	await get_tree().physics_frame
	return out
