extends Node
## DOES THE ART TELL THE TRUTH ABOUT THE COLLIDER?
##
## A player can only see the mesh; the collider is what actually hits them. If
## the two disagree, the game is lying — and it lies in one of two ways:
##
##   art LOWER than a duckable's underside  -> the gap looks too small, so you
##       duck when you did not need to, or flinch and mistime it
##   art HIGHER than a jumpable's top       -> it looks too tall to clear, so
##       you dodge something you could have jumped
##
## Neither shows up as a death, which is why nothing caught it: the vines' art
## hung 0.33 m below their collider for the entire life of the project.
var _fails := []


func _ready() -> void:
	_run()


func _run() -> void:
	var chunk: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(chunk)
	await get_tree().physics_frame
	var obstacles: Node3D = chunk.get_node("Obstacles")
	var slot: StaticBody3D = obstacles.get_child(0)

	print("===== ART vs COLLIDER =====")
	print("  %-8s %-18s %-18s" % ["", "art (low .. high)", "collider"])
	for name in ["Log", "Rock", "Tree", "Pillar", "Vines", "Branch"]:
		var mesh: Node3D = slot.get_node_or_null(name)
		if mesh == null:
			_fails.append("no mesh called '%s' in an obstacle slot" % name)
			continue
		var spec: Dictionary = _spec_for(name)
		var lo := 1e9
		var hi := -1e9
		# Per vertex, in the obstacle's own space. For a slide gate only the
		# art INSIDE the collider's width counts toward "how low does it
		# hang": its posts stand in the ground at the lane edge on purpose,
		# to read as a gate, and have no collider.
		var half_w: float = spec["size"].x * 0.5 - 0.02
		for n in _walk(mesh):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var xf: Transform3D = mesh.global_transform.affine_inverse() * mi.global_transform \
				if mi != mesh else Transform3D()
			for si in mi.mesh.get_surface_count():
				var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				for v in verts:
					var w: Vector3 = xf * v
					hi = maxf(hi, w.y)
					if absf(w.x) < half_w:
						lo = minf(lo, w.y)

		var c_lo: float = spec["y"] - spec["size"].y * 0.5
		var c_hi: float = spec["y"] + spec["size"].y * 0.5
		var note := ""
		# A duckable floats: its UNDERSIDE is the promise.
		if c_lo > 0.5:
			if lo < c_lo - 0.06:
				note = "<-- art hangs %.2f m BELOW the gap" % (c_lo - lo)
		# Anything resting on the floor: its TOP is the promise.
		elif hi > c_hi + 0.10:
			note = "<-- art stands %.2f m ABOVE the collider" % (hi - c_hi)
		# The dangerous direction: art LOWER than what actually hits you. It
		# looks clearable and is not, and that is a death the player can
		# never have seen coming. Only for things low enough to jump — a
		# 2.5 m tree cannot be cleared whatever it looks like.
		elif c_hi < 1.5 and hi < c_hi - 0.06:
			note = "<-- art is %.2f m LOWER than what you must clear" % (c_hi - hi)
		print("  %-8s %6.2f .. %-6.2f   %6.2f .. %-6.2f  %s"
			% [name, lo, hi, c_lo, c_hi, note])
		if note != "":
			_fails.append("%s: %s" % [name, note.replace("<-- ", "")])

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL SILHOUETTE CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _spec_for(node_name: String) -> Dictionary:
	for key in TrackChunk.SPEC:
		var spec: Dictionary = TrackChunk.SPEC[key]
		if spec["node"] == node_name:
			return spec
	return {"size": Vector3.ONE, "y": 0.5}


func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
