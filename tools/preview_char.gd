extends Node3D
## CHARACTER PREVIEW — renders one character on its own, under game-like
## light, from the angles that matter, and saves PNGs. For sculpting the
## characters in tools/char_*.gd without rebuilding the whole game.
##
##   PREVIEW_CHAR = monkey | gorilla | croc | test
##   PREVIEW_POSE = rest | run | tuck | jump    (monkey; others use their own swing)
##   PREVIEW_OUT  = directory for the PNGs (default user://)
##
## Shots: chase  — exactly the in-game camera (4.4 m up, 7.2 m back, FOV 52),
##                 so you see the size the player actually sees
##        back   — close 3/4 from behind (what you see most)
##        front  — close 3/4 from in front (the title screen)
##        side   — profile
##
## Run WINDOWED and silent:
##   godot --path . --audio-driver Dummy --resolution 1280x720 res://tools/preview_char.tscn

const SM := preload("res://tools/smooth_mesh.gd")

var _cam: Camera3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	_build_stage()
	var which := OS.get_environment("PREVIEW_CHAR")
	if which == "":
		which = "test"
	var out := OS.get_environment("PREVIEW_OUT")
	if out == "":
		out = "user://"
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var body := Node3D.new()
	body.name = "Body"
	visual.add_child(body)
	if which == "test":
		_test_shapes(body)
	else:
		var script: GDScript = load("res://tools/char_%s.gd" % which)
		script.build(body, self)
	_pose(body, which, OS.get_environment("PREVIEW_POSE"))

	var shots := {
		"chase": [Vector3(0.0, 4.4, 7.2), Vector3(0.0, 0.0, -10.0), 52.0],
		"back": [Vector3(1.5, 1.9, 3.2), Vector3(0.0, 1.0, 0.0), 38.0],
		"front": [Vector3(1.7, 1.55, -3.1), Vector3(0.0, 1.1, 0.0), 38.0],
		"side": [Vector3(4.2, 1.2, 0.3), Vector3(0.0, 0.9, 0.0), 36.0],
	}
	if which == "croc":
		shots["back"] = [Vector3(1.3, 1.4, 3.0), Vector3(0.0, 0.3, -0.3), 38.0]
		shots["front"] = [Vector3(1.4, 1.0, -3.2), Vector3(0.0, 0.3, -0.5), 38.0]
		shots["side"] = [Vector3(4.2, 0.9, -0.2), Vector3(0.0, 0.3, -0.2), 40.0]
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
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The game's sun: from behind and above the camera, plus a warm rim light
	# from ahead.
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
	# A strip of trail to stand on.
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(9.0, 60.0)
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.46, 0.33, 0.20)
	ground.material_override = gmat
	ground.position = Vector3(0.0, 0.0, -20.0)
	add_child(ground)
	for x in [-1.25, 1.25]:
		var g2 := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.62, 60.0)
		g2.mesh = pm
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0.26, 0.50, 0.17)
		g2.material_override = m2
		g2.position = Vector3(x, 0.01, -20.0)
		add_child(g2)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true


## Test pattern for the shape library: an ellipsoid, a rounded box and a tube.
func _test_shapes(body: Node3D) -> void:
	var m := SM.mat(Color(0.9, 0.5, 0.2))
	SM.add(body, self, "Egg", SM.ellipsoid(Vector3(0.3, 0.45, 0.25)),
		Transform3D(Basis(), Vector3(-0.8, 0.5, 0.0)), m)
	SM.add(body, self, "Box", SM.rounded_box(Vector3(0.3, 0.3, 0.3), 0.3),
		Transform3D(Basis(), Vector3(0.0, 0.4, 0.0)), SM.mat(Color(0.2, 0.5, 0.9)))
	var pts := []
	var rs := []
	for i in 12:
		var t := float(i) / 11.0
		pts.append(Vector3(0.6 + 0.4 * sin(t * PI), 0.2 + 1.2 * t, 0.3 * cos(t * PI)))
		rs.append(lerpf(0.12, 0.04, t))
	SM.add(body, self, "Tube", SM.tube(pts, rs), Transform3D(), SM.mat(Color(0.3, 0.8, 0.3)))


## Puts the rig in a pose, so the joints can be judged in motion, not just at rest.
func _pose(body: Node3D, which: String, pose: String) -> void:
	var set_x := func(path: String, x: float) -> void:
		var n := body.get_node_or_null(path) as Node3D
		if n != null:
			n.rotation.x = x
	if which == "monkey":
		match pose:
			"run":
				for kv in [["LegLeft", 0.48], ["LegLeft/Knee", -0.18], ["LegLeft/Knee/Ankle", -0.16],
						["LegRight", -0.58], ["LegRight/Knee", -0.60], ["LegRight/Knee/Ankle", 0.60],
						["ArmLeft", -0.55], ["ArmLeft/Elbow", 1.05],
						["ArmRight", 0.65], ["ArmRight/Elbow", 1.50]]:
					set_x.call(kv[0], kv[1])
			"tuck":
				for kv in [["LegLeft", -0.15], ["LegLeft/Knee", -1.60], ["LegLeft/Knee/Ankle", 1.20],
						["LegRight", 0.24], ["LegRight/Knee", -0.42], ["LegRight/Knee/Ankle", 0.18],
						["ArmLeft", 0.45], ["ArmLeft/Elbow", 1.35],
						["ArmRight", -0.35], ["ArmRight/Elbow", 1.05]]:
					set_x.call(kv[0], kv[1])
			"jump":
				for kv in [["ArmLeft", -2.4], ["ArmRight", -2.4], ["LegLeft", -1.0],
						["LegRight", -0.4], ["LegLeft/Knee", -1.45], ["LegRight/Knee", -0.85],
						["ArmLeft/Elbow", 0.40], ["ArmRight/Elbow", 0.40]]:
					set_x.call(kv[0], kv[1])
	elif which == "gorilla" and pose == "run":
		set_x.call("ArmL", 0.85)
		set_x.call("ArmR", -0.85)
		set_x.call("LegL", -0.6)
		set_x.call("LegR", 0.6)
