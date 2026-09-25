extends Node
## OBSTACLE GALLERY — lines up every obstacle (or both trains) in front of the
## real game camera and saves a screenshot, so art changes can be judged
## side by side instead of waiting for the random track to deal them.
##
##   GAL_SHOT=obstacles  (default)  row 1: python, boulder, stela
##                                  row 2: vine curtain, branch, tree
##   GAL_SHOT=overhead              the same, rows swapped (duck ones in front)
##   GAL_SHOT=far                   the obstacle rows at 40 m and 60 m
##   GAL_SHOT=pickups               all four power-ups
##   GAL_SHOT=close                 boulder, python, stela up close
##   GAL_SHOT=fx                    a coin sparkle and a landing puff
##   GAL_SHOT=trains                fallen giant left, temple wall right
##
##   GAL_OUT=<dir>  where the PNG goes (default user://)
##
## Run it WINDOWED (it needs a real renderer) and silent:
##   godot --path . --audio-driver Dummy --resolution 1280x720 res://tools/gallery.tscn

const Chunk := preload("res://scripts/track_chunk.gd")

var _root: Node


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	GameState.record_runs = false
	_root = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = _root

	# Freeze the runner where it spawned; the camera keeps following it.
	var player: Node = _root.get_node("Player")
	player.set_physics_process(false)
	player.set_process(false)
	# Bruno and Snapper chase you off the start line — out of the way here.
	if _root.has_node("Chaser") and shot_name() != "fx":
		_root.get_node("Chaser").process_mode = Node.PROCESS_MODE_DISABLED
		_root.get_node("Chaser").visible = false

	var chunks: Array = _root.get_node("TrackManager").get_children().filter(
		func(n: Node) -> bool: return n.has_method("randomise"))
	chunks.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return absf(a.global_position.z) < absf(b.global_position.z))

	# Let the first frame's deferred collider writes land before we move things.
	for i in 3:
		await get_tree().process_frame

	var shot := OS.get_environment("GAL_SHOT")
	if shot == "":
		shot = "obstacles"
	for c in chunks:
		_clear(c)
	if shot == "pickups":
		# All four power-ups side by side (and one behind), 14 m out.
		var kinds := ["Magnet", "Shield", "Surge", "Spring"]
		for k in kinds.size():
			var c: Node = chunks[k]
			var pick: Node3D = c.get_node("Powerups/Pickup")
			c.pickup_kind = k
			c._set_pickup_active(true)
			var lane: int = k % 3
			pick.global_position = Vector3(LaneConfig.lane_to_x(lane), 1.05,
				-12.0 - 7.0 * float(k / 3))
	elif shot == "fx":
		# Fire a coin sparkle and a landing puff on the frozen runner.
		GameState.coins += 1
		GameState.coins_changed.emit(GameState.coins)
		player.get_node("Effects/Dust").restart()
		for i in int(OS.get_environment("GAL_WAIT") if OS.get_environment("GAL_WAIT") != "" else "18"):
			await get_tree().process_frame
	elif shot == "trains":
		_show_train(chunks[0], 0, "FallenGiant", -6.0)
		_show_train(chunks[1], LaneConfig.LANE_COUNT - 1, "RuinWall", -6.0)
	else:
		var rows := [
			[Chunk.Slot.LOG, Chunk.Slot.ROCK, Chunk.Slot.PILLAR],
			[Chunk.Slot.VINES, Chunk.Slot.BRANCH, Chunk.Slot.TREE],
		]
		if shot == "overhead":
			rows.reverse()
		if shot == "close":
			# One of each jumpable and dodgeable, close up.
			rows = [[Chunk.Slot.LOG, Chunk.Slot.ROCK, Chunk.Slot.PILLAR],
				[Chunk.Slot.EMPTY, Chunk.Slot.EMPTY, Chunk.Slot.EMPTY]]
		var slots: Array = chunks[0].get_node("Obstacles").get_children()
		var i := 0
		for r in rows.size():
			for lane in LaneConfig.LANE_COUNT:
				var world_z := (-6.0 if shot == "close" else -9.0) - 8.0 * float(r)
				if shot == "far":
					# Where the decision is actually made at speed: 40 and 60 m.
					world_z = -40.0 - 20.0 * float(r)
				chunks[0]._apply_slot(slots[i], rows[r][lane], LaneConfig.lane_to_x(lane),
					world_z - chunks[0].global_position.z)
				i += 1

	if shot != "fx":
		for i in 30:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("GAL_OUT")
	if out == "":
		out = "user://"
	var path := "%s/gallery_%s.png" % [out, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("GALLERY ", path)
	get_tree().quit()


func _clear(chunk: Node) -> void:
	for ob in chunk.get_node("Obstacles").get_children():
		chunk._apply_slot(ob, Chunk.Slot.EMPTY, 0.0, 0.0)
	var lm: Node3D = chunk.get_node("Landmarks/Landmark0")
	lm.visible = false
	if chunk.has_node("Powerups/Pickup"):
		chunk.get_node("Powerups/Pickup").visible = false
	for c in chunk.get_node("Coins").get_children() if chunk.has_node("Coins") else []:
		c.visible = false


func _show_train(chunk: Node, lane: int, which: String, world_z: float) -> void:
	var lm: Node3D = chunk.get_node("Landmarks/Landmark0")
	for m in lm.get_children():
		if m is MeshInstance3D:
			m.visible = m.name == which
	lm.visible = true
	lm.global_position = Vector3(LaneConfig.lane_to_x(lane), 0.0, world_z)


func shot_name() -> String:
	var shot := OS.get_environment("GAL_SHOT")
	return shot if shot != "" else "obstacles"
