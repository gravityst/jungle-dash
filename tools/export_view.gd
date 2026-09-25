extends Node
## Dumps the REAL geometry of a treetop section to JSON, so it can be looked at
## in a browser instead of in a Godot window.
##
## This exists because --headless genuinely cannot render: it uses a dummy
## rasteriser and RenderingServer.frame_post_draw never fires, so there is no
## way to screenshot the game without opening a window that steals focus. What
## it CAN do is read the exact vertices the renderer would have drawn. So we
## export those, colour them with the materials the game actually uses, and
## draw them somewhere else.
##
## Nothing about the game is reconstructed or approximated here — every
## triangle below is a triangle the game would put on screen.

const OUT := "res://view_data.json"
const TRACK_OUT := "res://track_data.json"

## Ordinary track, for showing the authored obstacle patterns. Patterns stand
## aside for set-pieces, so they can only be seen on NORMAL pieces.
const TRACK_PIECES := ["NORMAL", "NORMAL", "NORMAL", "NORMAL"]

## Which role each exported piece is given, near end first.
const PIECES := ["APPROACH", "LAUNCH", "DECK", "NARROW", "DECK", "EXIT"]


func _ready() -> void:
	await _export(PIECES, OUT, 0.55, true)
	await _export(TRACK_PIECES, TRACK_OUT, 0.9, false)
	get_tree().quit()


func _export(pieces: Array, path: String, difficulty: float,
		with_runner: bool) -> void:
	var by_colour := {}
	var tris := 0

	for i in pieces.size():
		var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
		add_child(chunk)
		await get_tree().physics_frame
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + i * 7
		var role: int = _role_of(pieces[i])
		chunk.randomise(rng, difficulty, false, true, role)
		chunk.position = Vector3(0.0, 0.0, -30.0 * float(i))
		# Two frames: collider enables are deferred, and randomise() re-parents
		# nothing but does move things.
		await get_tree().physics_frame
		await get_tree().physics_frame
		tris += _collect(chunk, by_colour)

	# The runner, for scale — on the deck for the treetop view, on the trail for
	# the ordinary one.
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().physics_frame
	player.position = Vector3(LaneConfig.lane_to_x(1),
		TrackChunk.DECK_Y if with_runner else 0.0,
		-52.0 if with_runner else -4.0)
	await get_tree().physics_frame
	tris += _collect(player.get_node("Visual"), by_colour)

	var groups := []
	for key in by_colour:
		var g: Dictionary = by_colour[key]
		var verts: PackedFloat32Array = g["v"]
		var idx: PackedInt32Array = g["i"]
		groups.append({
			"color": key,
			"count": idx.size() / 3,
			"v": Marshalls.raw_to_base64(verts.to_byte_array()),
			"i": Marshalls.raw_to_base64(idx.to_byte_array()),
		})

	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"deck_y": TrackChunk.DECK_Y,
		"pad_z": TrackChunk.PAD_Z,
		"lane_width": LaneConfig.LANE_WIDTH,
		"chunk_length": LaneConfig.CHUNK_LENGTH,
		"pieces": pieces,
		"groups": groups,
	}))
	f.close()
	print("EXPORT: %d triangles in %d colour groups -> %s" % [tris, groups.size(), path])
	for c in get_children():
		c.queue_free()
	await get_tree().physics_frame


func _role_of(name: String) -> int:
	match name:
		"APPROACH": return TrackChunk.Role.APPROACH
		"LAUNCH": return TrackChunk.Role.LAUNCH
		"DECK": return TrackChunk.Role.DECK
		"NARROW": return TrackChunk.Role.NARROW
		"EXIT": return TrackChunk.Role.EXIT
	return TrackChunk.Role.NORMAL


## Walks a subtree and appends every VISIBLE triangle, in world space, into a
## bucket keyed by the colour it is drawn with.
func _collect(node: Node, by_colour: Dictionary) -> int:
	var tris := 0
	for n in _walk(node):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xform := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var col := _colour_of(mi, si)
			var key := col.to_html(false)
			if not by_colour.has(key):
				by_colour[key] = {"v": PackedFloat32Array(), "i": PackedInt32Array()}
			var g: Dictionary = by_colour[key]
			var verts: PackedFloat32Array = g["v"]
			var idx: PackedInt32Array = g["i"]
			var base: int = verts.size() / 3

			var arrays := mi.mesh.surface_get_arrays(si)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for p in pos:
				var w := xform * p
				verts.append(w.x)
				verts.append(w.y)
				verts.append(w.z)
			var src: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if src.size() > 0:
				for v in src:
					idx.append(base + v)
				tris += src.size() / 3
			else:
				for k in pos.size():
					idx.append(base + k)
				tris += pos.size() / 3
			g["v"] = verts
			g["i"] = idx
	return tris


## The colour a surface is actually drawn with — including the shader materials
## used for the wind-blown foliage and the dappled ground.
func _colour_of(mi: MeshInstance3D, si: int) -> Color:
	var mat: Material = mi.material_override
	if mat == null:
		mat = mi.mesh.surface_get_material(si)
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).albedo_color
	if mat is ShaderMaterial:
		var v = (mat as ShaderMaterial).get_shader_parameter("albedo")
		if v is Color:
			return v
	return Color(0.7, 0.7, 0.7)


func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
