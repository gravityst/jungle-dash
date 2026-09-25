extends Node
## SEE THE GAME. Runs the real game in a window with the bot driving, and saves
## screenshots at chosen frames. Audio is killed twice over: the launch command
## passes --audio-driver Dummy, and the master bus is muted here as well.
##
## Usage (from the project folder):
##   Godot --path . --audio-driver Dummy --resolution 1280x720 res://tools/capture.tscn
## Frames and output folder come from the environment so one scene serves every
## kind of shot:  CAP_FRAMES="90,300,600"  CAP_OUT="/some/dir"  CAP_TAG="base"

var _frames: Array[int] = []
var _out := ""
var _tag := "shot"
var _f := 0
var _root: Node


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	for part in OS.get_environment("CAP_FRAMES").split(",", false):
		_frames.append(int(part))
	if _frames.is_empty():
		_frames = [120, 360, 720]
	_out = OS.get_environment("CAP_OUT")
	if _out == "":
		_out = "user://"
	_tag = OS.get_environment("CAP_TAG") if OS.get_environment("CAP_TAG") != "" else "shot"

	GameState.record_runs = false
	_root = load("res://scenes/main.tscn").instantiate()
	var seed_env := OS.get_environment("CAP_SEED")
	if seed_env != "":
		_root.get_node("TrackManager").random_seed = int(seed_env)
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = _root
	if OS.get_environment("CAP_NOBOT") == "":
		var bot: Node = load("res://tools/autopilot.gd").new()
		_root.add_child(bot)
		bot.setup(_root.get_node("Player"), _root.get_node("TrackManager"))
	get_tree().process_frame.connect(_tick)


func _tick() -> void:
	_f += 1
	# CAP_TITLE=1 opens on the title screen; CAP_START=<frame> presses start.
	if GameState.on_title() and _f == int(OS.get_environment("CAP_START")):
		GameState.start_run()
	# CAP_SHIELD=<frame>: hand the runner a surf plank at that frame.
	if _f == int(OS.get_environment("CAP_SHIELD")) and GameState.is_running():
		GameState.give_shield()
	if _f in _frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s_%04d.png" % [_out, _tag, _f]
		img.save_png(path)
		print("CAPTURED ", path, "  dist=%.0f alive=%s" % [GameState.distance, GameState.is_running()])
	if _f >= _frames.max() + 2:
		get_tree().quit()
