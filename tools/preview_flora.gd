extends Node3D
## SCENERY PREVIEW — renders one flora module's showcase under the game's
## light and saves PNGs, for sculpting plants without rebuilding the game.
##
##   PREVIEW_FLORA = the module: res://tools/flora_<name>.gd, which must have
##                   static func showcase() -> Array   (merge-list parts, the
##                   same {"mesh", "xform", "mat", "surface"} dicts as
##                   build_scenes.gd's _part(); "mat" names res://materials/)
##                   PREVIEW_FLORA=kit shows the flora kit's own test pattern.
##   PREVIEW_OUT   = directory for the PNGs (default user://)
##
## The showcase is laid out along the RIGHT verge of a trail (x 5..14, z 0..-40)
## the way the game's scenery pool places it, so the "game" shot is exactly
## what a player sees. Shots:
##   game   — the in-game chase camera (4.4 m up, 7.2 m back, FOV 52)
##   verge  — standing on the trail, looking at the verge from 6 m
##   close  — 3/4 close-up of whatever is nearest (x 6, z -6)
##   wide   — high 3/4 overview of the whole showcase
##
## Run WINDOWED and silent:
##   godot --path . --audio-driver Dummy --resolution 1280x720 res://tools/preview_flora.tscn

const FK := preload("res://tools/flora_kit.gd")

var _cam: Camera3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	_build_stage()
	var which := OS.get_environment("PREVIEW_FLORA")
	if which == "":
		which = "kit"
	var out := OS.get_environment("PREVIEW_OUT")
	if out == "":
		out = "user://"
	var parts: Array = _kit_test() if which == "kit" else \
		(load("res://tools/flora_%s.gd" % which) as GDScript).showcase()
	var mi := MeshInstance3D.new()
	mi.mesh = _merge(parts)
	add_child(mi)
	var tris := 0
	for s in (mi.mesh as ArrayMesh).get_surface_count():
		tris += (mi.mesh as ArrayMesh).surface_get_array_len(s) / 3
	print("PREVIEW parts=%d surfaces=%d triangles=%d" % [parts.size(),
		(mi.mesh as ArrayMesh).get_surface_count(), tris])

	var shots := {
		"game": [Vector3(0.0, 4.4, 7.2), Vector3(0.0, 0.0, -10.0), 52.0],
		"verge": [Vector3(1.0, 1.7, -2.0), Vector3(8.0, 1.6, -10.0), 55.0],
		"close": [Vector3(2.6, 1.8, -1.2), Vector3(6.5, 1.2, -6.0), 45.0],
		"wide": [Vector3(-4.0, 9.0, 8.0), Vector3(8.0, 0.0, -16.0), 50.0],
	}
	for shot in shots:
		var s: Array = shots[shot]
		_cam.fov = s[2]
		_cam.global_position = s[0]
		_cam.look_at(s[1], Vector3.UP)
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.png" % [out, which, shot]
		get_viewport().get_texture().get_image().save_png(path)
		print("PREVIEW ", path)
	get_tree().quit()


func _merge(parts: Array) -> ArrayMesh:
	var by_mat := {}
	for part in parts:
		var key: String = part["mat"]
		if not by_mat.has(key):
			by_mat[key] = []
		by_mat[key].append(part)
	var am := ArrayMesh.new()
	for key: String in by_mat:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Dictionary in by_mat[key]:
			st.append_from(_indexed(part["mesh"], int(part.get("surface", 0))), 0, part["xform"])
		var m: Material = load("res://materials/%s.tres" % key)
		if m == null:
			push_error("no material named %s" % key)
		st.set_material(m)
		st.commit(am)
	return am


## SurfaceTool drops the vertices of non-indexed parts once any indexed part
## (a BoxMesh, CylinderMesh...) shares their surface. Index everything, the
## same as build_scenes.gd's _baked() does, so the preview shows what the
## game will.
func _indexed(mesh: Mesh, surface: int) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(surface)
	if arrays[Mesh.ARRAY_INDEX] == null:
		var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var seq := PackedInt32Array()
		seq.resize(n)
		for i in n:
			seq[i] = i
		arrays[Mesh.ARRAY_INDEX] = seq
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.14, 0.46, 0.94)
	sky.sky_horizon_color = Color(0.66, 0.75, 0.69)
	sky.ground_horizon_color = Color(0.34, 0.41, 0.38)
	sky.ground_bottom_color = Color(0.2, 0.25, 0.2)
	env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.32
	env.adjustment_contrast = 1.10
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 100.0
	env.fog_depth_end = 200.0
	env.fog_light_color = Color(0.34, 0.41, 0.38)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-30.0), 0.0)
	sun.light_color = Color(1.0, 0.94, 0.80)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-118.0), 0.0)
	rim.light_color = Color(1.0, 0.85, 0.62)
	rim.light_energy = 0.5
	add_child(rim)
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(40.0, 80.0)
	ground.mesh = gm
	ground.material_override = load("res://materials/verge.tres")
	ground.position = Vector3(0.0, 0.0, -30.0)
	add_child(ground)
	var trail := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(8.5, 80.0)
	trail.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.46, 0.33, 0.20)
	trail.material_override = tmat
	trail.position = Vector3(0.0, 0.01, -30.0)
	add_child(trail)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true


## The kit's own test pattern: clumps, a boulder, blades, straps and a trunk.
func _kit_test() -> Array:
	var p := []
	p.append(FK.part(FK.clump(Vector3(1.6, 0.9, 1.3), 1), Transform3D(Basis(), Vector3(6.0, 1.2, -6.0)), "foliage"))
	p.append(FK.part(FK.clump(Vector3(1.0, 0.7, 0.9), 2), Transform3D(Basis(), Vector3(8.0, 0.6, -3.0)), "shrub"))
	p.append(FK.part(FK.boulder(Vector3(0.9, 0.6, 0.8), 3), Transform3D(Basis(), Vector3(4.8, 0.33, -2.0)), "rock"))
	for i in 6:
		var b := Basis.from_euler(Vector3(deg_to_rad(-40.0), float(i) * TAU / 6.0, 0.0))
		p.append(FK.part(FK.blade(0.55, 0.9), Transform3D(b, Vector3(5.0, 0.4, -9.0)), "leaf_big"))
	for i in 9:
		var b := Basis.from_euler(Vector3(deg_to_rad(-25.0), float(i) * TAU / 9.0, 0.0))
		p.append(FK.part(FK.strap(0.08, 1.1), Transform3D(b, Vector3(7.5, 0.0, -9.5)), "frond_light"))
	var pts := []
	var rs := []
	for i in 7:
		var t := float(i) / 6.0
		pts.append(Vector3(10.0 - 1.2 * t * t, 7.0 * t, -12.0))
		rs.append(lerpf(0.42, 0.18, t))
	p.append(FK.part(FK.trunk(pts, rs), Transform3D(), "trunk_dark"))
	p.append(FK.part(FK.clump(Vector3(2.6, 1.3, 2.2), 5), Transform3D(Basis(), Vector3(8.8, 7.4, -12.0)), "canopy_mid"))
	p.append(FK.part(FK.bevel_box(Vector3(1.1, 2.6, 0.7), 0.06), Transform3D(Basis.from_euler(Vector3(0, 0.5, 0)), Vector3(4.6, 1.3, -4.5)), "ob_stone_dark"))
	p.append(FK.part(FK.bevel_box(Vector3(1.4, 0.3, 1.0), 0.05, 2), Transform3D(Basis(), Vector3(6.2, 0.15, -3.8)), "stone"))
	return p
