extends Node3D
## ANIMATION FILMSTRIP — plays one of the runner's real animations from
## scenes/player.tscn and saves N evenly spaced frames side by side, from the
## in-game chase camera and from the side, so a cycle can be judged as motion
## rather than as a single pose.
##
##   STRIP_ANIM  = run | jump | roll | idle | surf   (default run)
##   STRIP_N     = frames across one cycle (default 8)
##   STRIP_OUT   = directory for strip_<anim>_chase.png / _side.png
##
## Run WINDOWED and silent:
##   godot --path . --audio-driver Dummy --resolution 1280x720 res://tools/anim_strip.tscn

const PREVIEW := preload("res://tools/preview_char.gd")

var _cam: Camera3D


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var anim_name := OS.get_environment("STRIP_ANIM")
	if anim_name == "":
		anim_name = "run"
	var n := int(OS.get_environment("STRIP_N")) if OS.get_environment("STRIP_N") != "" else 8
	var out := OS.get_environment("STRIP_OUT")
	if out == "":
		out = "user://"
	_stage()
	var p: Node3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(p)
	await get_tree().physics_frame
	p.set_physics_process(false)
	p.set_process(false)
	p.global_position = Vector3.ZERO
	var anim: AnimationPlayer = p.get_node("AnimationPlayer")
	anim.play(anim_name)
	anim.speed_scale = 0.0
	var length: float = anim.get_animation(anim_name).length
	var views := {
		"chase": [Vector3(0.0, 4.4, 7.2), Vector3(0.0, 0.6, -3.0), 52.0, Rect2i(440, 170, 400, 520)],
		"side": [Vector3(5.0, 1.1, 0.0), Vector3(0.0, 0.95, 0.0), 30.0, Rect2i(420, 60, 440, 620)],
		"back": [Vector3(1.4, 1.6, 3.4), Vector3(0.0, 0.95, 0.0), 36.0, Rect2i(400, 40, 480, 660)],
	}
	for view: String in views:
		var v: Array = views[view]
		_cam.fov = v[2]
		_cam.global_position = v[0]
		_cam.look_at(v[1], Vector3.UP)
		var crop: Rect2i = v[3]
		var strip := Image.create(crop.size.x * n, crop.size.y, false, Image.FORMAT_RGBA8)
		for i in n:
			anim.seek(length * float(i) / float(n), true)
			for k in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(img, crop, Vector2i(crop.size.x * i, 0))
		var path := "%s/strip_%s_%s.png" % [out, anim_name, view]
		strip.save_png(path)
		print("STRIP ", path)
	get_tree().quit()


func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.66, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.6)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-30.0), 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(20.0, 40.0)
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.46, 0.33, 0.20)
	ground.material_override = gmat
	add_child(ground)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
