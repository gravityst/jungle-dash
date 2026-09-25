extends Node
## Headless gameplay probe: runs main.tscn for real and asserts behaviour.

var _player: CharacterBody3D
var _cam: Camera3D
var _anim: AnimationPlayer
var _f := 0
var _log := {}
var _fail := []
var _apex := 0.0
var _jump_started := false
var _airborne_frames := 0

func _ready() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	# This test measures the PLAYER, so give it an empty track to run on.
	# Must be set BEFORE add_child(): the track builds its first pieces in
	# _ready(), and _ready() fires the moment the node enters the tree.
	(scene.get_node("TrackManager") as TrackManager).spawn_obstacles = false
	add_child(scene)
	_player = scene.get_node("Player")
	_cam = scene.get_node("FollowCamera")
	_anim = _player.get_node("AnimationPlayer")
	get_tree().physics_frame.connect(_tick)

func _tick() -> void:
	_f += 1
	var p := _player.global_position

	if _jump_started:
		_apex = maxf(_apex, p.y)
		if not _player.is_on_floor():
			_airborne_frames += 1

	if _f == 30:
		_log["settled_y"] = p.y
		_log["on_floor"] = _player.is_on_floor()
		_log["anim_grounded"] = _anim.current_animation
		_log["z_at_30"] = p.z

	if _f == 60:
		_log["fwd_speed"] = (_log["z_at_30"] - p.z) / 0.5
		Input.action_press("move_right")
	if _f == 62:
		Input.action_release("move_right")
		_log["lane_after_press"] = _player.current_lane   # read 2 frames later

	if _f == 70:
		_log["x_mid_slide"] = p.x        # partway through the slide
	if _f == 95:
		_log["x_after_lane_change"] = p.x
		_log["slide_frames"] = 35
		Input.action_press("jump")
		_jump_started = true
	if _f == 97:
		Input.action_release("jump")
	if _f == 100:
		_log["anim_in_air"] = _anim.current_animation

	if _f == 160:
		_log["jump_apex_y"] = _apex
		_log["airborne_frames"] = _airborne_frames
		_log["airtime_sec"] = _airborne_frames / 60.0
		_log["on_floor_after"] = _player.is_on_floor()
		_log["anim_after_landing"] = _anim.current_animation
		Input.action_press("move_left")
	if _f == 162:
		Input.action_release("move_left")
	if _f == 170:
		Input.action_press("move_left")
	if _f == 172:
		Input.action_release("move_left")
	if _f == 180:
		Input.action_press("move_left")
	if _f == 182:
		Input.action_release("move_left")

	if _f == 230:
		_log["lane_clamped"] = _player.current_lane
		_log["x_clamped"] = p.x
		_log["cam_height_above"] = _cam.global_position.y - p.y
		_log["cam_behind"] = _cam.global_position.z - p.z
		_log["cam_lateral"] = _cam.global_position.x
		_finish()

func _chk(cond: bool, msg: String) -> void:
	if not cond:
		_fail.append(msg)

func _finish() -> void:
	print("\n===== PROBE RESULTS =====")
	var keys := _log.keys()
	keys.sort()
	for k in keys:
		print("  %-22s = %s" % [k, _log[k]])

	_chk(_log["on_floor"], "player not on floor at frame 30")
	_chk(absf(_log["settled_y"]) < 0.05, "not resting at y~0 (got %f)" % _log["settled_y"])
	_chk(_log["anim_grounded"] == "run", "grounded anim '%s' != 'run'" % _log["anim_grounded"])
	_chk(absf(_log["fwd_speed"] - 12.0) < 0.6, "fwd speed %f != ~12" % _log["fwd_speed"])
	_chk(_log["lane_after_press"] == 2, "lane = %d != 2" % _log["lane_after_press"])
	_chk(_log["x_mid_slide"] > 0.3 and _log["x_mid_slide"] < 2.45,
		"slide not gradual: x=%f at mid-slide (should be between lanes)" % _log["x_mid_slide"])
	_chk(absf(_log["x_after_lane_change"] - 2.5) < 0.1, "x = %f != ~2.5" % _log["x_after_lane_change"])
	_chk(_log["jump_apex_y"] > 1.2, "jump apex only %f m" % _log["jump_apex_y"])
	_chk(_log["anim_in_air"] == "jump", "air anim '%s' != 'jump'" % _log["anim_in_air"])
	_chk(_log["on_floor_after"], "did not land")
	_chk(_log["anim_after_landing"] == "run", "anim after landing '%s'" % _log["anim_after_landing"])
	_chk(_log["lane_clamped"] == 0, "lane clamped to %d != 0" % _log["lane_clamped"])
	_chk(absf(_log["x_clamped"] + 2.5) < 0.1, "x clamped %f != -2.5" % _log["x_clamped"])
	_chk(_log["cam_behind"] > 4.0, "camera not behind (dz=%f)" % _log["cam_behind"])
	_chk(_log["cam_height_above"] > 2.0, "camera not above (dy=%f)" % _log["cam_height_above"])
	_chk(absf(_log["cam_lateral"]) < 2.0, "camera swung too far sideways (x=%f)" % _log["cam_lateral"])
	# The camera must never rise into the canopy. The highest the runner gets
	# under the trees is a spring jump off a landmark roof, 3.35 m; the lowest
	# leaves over the lanes are at 5.37 m.
	for y in [0.0, 1.10, 2.25, 3.35]:
		var cam_y: float = _cam._follow_y(y) + _cam.offset.y
		_chk(cam_y <= 5.2, "camera would enter the canopy at player y %.2f (camera %.2f)" % [y, cam_y])
	_chk(_cam._follow_y(7.0) >= 6.9, "camera no longer follows the runner up onto the treetop deck")

	print("\n===== VERDICT =====")
	if _fail.is_empty():
		print("ALL CHECKS PASSED")
	else:
		for f in _fail:
			print("  FAIL: ", f)
		print("%d CHECK(S) FAILED" % _fail.size())
	get_tree().quit(0 if _fail.is_empty() else 1)
