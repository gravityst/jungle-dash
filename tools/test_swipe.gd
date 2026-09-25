extends Node
## Regression test for the spurious-swipe bug.
##
## A drag event that arrives with NO touch-down before it used to be measured
## against _touch_start's default of (0, 0) — which reads as a huge swipe and
## fired a lane change out of nowhere. "Emulate Touch From Mouse" made this
## trivial to trigger on desktop, so the player wandered between lanes on its
## own. These checks pin the fix down.

var _p: CharacterBody3D
var _f := 0
var _log := {}
var _fails := []

func _ready() -> void:
	var s: Node = load("res://scenes/main.tscn").instantiate()
	# Empty track: this test is about the PLAYER, and a stray obstacle
	# would make it fail for unrelated reasons. Set before add_child(),
	# because the track builds its first pieces in _ready().
	(s.get_node("TrackManager") as TrackManager).spawn_obstacles = false
	add_child(s)
	_p = s.get_node("Player")
	get_tree().physics_frame.connect(_tick)

func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)

func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)

func _tick() -> void:
	_f += 1

	# --- 1. a stray drag with NO touch-down must be ignored ---
	if _f == 30:
		_log["lane_before"] = _p.current_lane
		_drag(Vector2(900, 400), Vector2(40, 0))
		_drag(Vector2(940, 400), Vector2(40, 0))
	if _f == 35:
		_log["lane_after_stray_drag"] = _p.current_lane

	# --- 2. a real swipe right (touch down, then drag) must work ---
	if _f == 50:
		_touch(Vector2(400, 400), true)
	if _f == 52:
		_drag(Vector2(500, 405), Vector2(100, 5))
	if _f == 55:
		_log["lane_after_real_swipe"] = _p.current_lane
		_touch(Vector2(500, 405), false)

	# --- 3. one swipe = one lane change, even if the drag continues ---
	if _f == 60:
		_touch(Vector2(400, 400), true)
	if _f == 62:
		_drag(Vector2(520, 400), Vector2(120, 0))
	if _f == 64:
		_drag(Vector2(640, 400), Vector2(120, 0))
	if _f == 66:
		_drag(Vector2(760, 400), Vector2(120, 0))
	if _f == 70:
		_log["lane_after_long_drag"] = _p.current_lane
		_touch(Vector2(760, 400), false)

	if _f == 80:
		_report()

func _report() -> void:
	print("\n===== SWIPE REGRESSION =====")
	for k in ["lane_before", "lane_after_stray_drag", "lane_after_real_swipe", "lane_after_long_drag"]:
		print("  %-24s = %s" % [k, _log.get(k, "?")])

	if _log["lane_after_stray_drag"] != _log["lane_before"]:
		_fails.append("a stray drag with no touch-down changed the lane (%d -> %d)" % [
			_log["lane_before"], _log["lane_after_stray_drag"]])
	if _log["lane_after_real_swipe"] != 2:
		_fails.append("a real swipe right did not move to lane 2 (got %d)" % _log["lane_after_real_swipe"])
	if _log["lane_after_long_drag"] != 2:
		_fails.append("one continuous drag moved more than one lane (ended at %d, should stay 2)" % _log["lane_after_long_drag"])

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL SWIPE CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)
