extends Node
## Exports the runner's rig, its meshes and its BAKED run cycle, so the
## animation can be watched in a browser instead of in a Godot window.
##
## The cycle is baked — sampled frame by frame out of the real AnimationPlayer
## — rather than exported as keyframes. That way what you watch is exactly what
## the engine produces, including its cubic interpolation, rather than a second
## implementation of interpolation that might disagree with it.

const OUT := "res://runner_data.json"
const FRAMES := 72


func _ready() -> void:
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	await get_tree().physics_frame
	p.set_physics_process(false)
	var anim: AnimationPlayer = p.get_node("AnimationPlayer")
	var visual: Node3D = p.get_node("Visual")

	# --- the node tree, parent-first so a reader can build it in one pass ---
	var order: Array[Node3D] = []
	_collect(visual, order)
	var index := {}
	for i in order.size():
		index[order[i]] = i

	var nodes := []
	for i in order.size():
		var n := order[i]
		nodes.append({
			"name": n.name,
			"parent": index.get(n.get_parent(), -1),
		})

	# --- geometry, in each mesh's OWN local space ---
	var meshes := []
	for i in order.size():
		var mi := order[i] as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var verts := PackedFloat32Array()
			for v in pos:
				verts.append(v.x)
				verts.append(v.y)
				verts.append(v.z)
			var idx := PackedInt32Array()
			var src: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if src.size() > 0:
				idx.append_array(src)
			else:
				for k in pos.size():
					idx.append(k)
			meshes.append({
				"node": i,
				"color": _colour_of(mi, si).to_html(false),
				"v": Marshalls.raw_to_base64(verts.to_byte_array()),
				"i": Marshalls.raw_to_base64(idx.to_byte_array()),
			})

	# --- the baked cycle ---
	var clips := {}
	for clip_name in ["run", "jump", "roll"]:
		var a: Animation = anim.get_animation(clip_name)
		anim.play(clip_name)
		var frames := []
		for f in FRAMES:
			var t: float = a.length * float(f) / float(FRAMES)
			anim.seek(t, true)
			await get_tree().physics_frame
			var row := PackedFloat32Array()
			for n in order:
				row.append(n.position.x); row.append(n.position.y); row.append(n.position.z)
				row.append(n.rotation.x); row.append(n.rotation.y); row.append(n.rotation.z)
			frames.append(Marshalls.raw_to_base64(row.to_byte_array()))
		clips[clip_name] = {"length": a.length, "frames": frames}

	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"nodes": nodes, "meshes": meshes, "clips": clips, "fps": FRAMES,
	}))
	f.close()
	print("EXPORT: %d nodes, %d meshes, %d clips x %d frames"
		% [nodes.size(), meshes.size(), clips.size(), FRAMES])
	get_tree().quit()


func _collect(n: Node, out: Array[Node3D]) -> void:
	if n is Node3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


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
