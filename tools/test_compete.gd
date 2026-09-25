extends Node
## THE COMPETITIVE LAYER — the daily challenge and the scoreboard.
##
## The property everything else rests on is that two people running today's
## daily meet the SAME track. Without that, comparing scores is comparing two
## different games and the whole feature is decoration.

var _fails := []
var _done := {}


func _ready() -> void:
	_run()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _chk(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _run() -> void:
	await _test_daily_is_the_same_track()
	_test_board()
	_test_share_line()

	for section in ["track", "board", "share"]:
		if not _done.has(section):
			_fails.append("section '%s' did not finish — look for a SCRIPT ERROR" % section)

	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL COMPETITION CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)


## Two separate runs of today's daily must lay down identical track; two free
## runs must not.
func _test_daily_is_the_same_track() -> void:
	GameState.set_mode(true)
	var daily_a := await _fingerprint()
	var daily_b := await _fingerprint()
	GameState.set_mode(false)
	var free_a := await _fingerprint()
	var free_b := await _fingerprint()

	print("===== A) TODAY'S TRACK IS EVERYONE'S TRACK =====")
	print("  daily seed        : %d  (%s)" % [GameState.daily_seed(), GameState.daily_label()])
	print("  daily run 1 vs 2  : %s" % ("identical" if daily_a == daily_b else "DIFFERENT"))
	print("  free  run 1 vs 2  : %s" % ("identical" if free_a == free_b else "different"))

	_chk(daily_a != "", "could not fingerprint a track at all")
	_chk(daily_a == daily_b,
		"two daily runs produced different tracks, so scores cannot be compared")
	_chk(free_a != free_b,
		"two free runs produced the SAME track — free play has stopped being random")
	_done["track"] = true


## Builds a short signature of the first few pieces of a fresh run.
func _fingerprint() -> String:
	var root: Node = load("res://scenes/main.tscn").instantiate()
	# Deferred: the window root is still walking its own children during
	# _ready, and a direct add_child there fails outright — which leaves the
	# track unbuilt and the fingerprint empty.
	get_tree().root.add_child.call_deferred(root)
	await _wait(4)
	var track: Node3D = root.get_node("TrackManager")
	var sig := ""
	for chunk in track.get_children():
		sig += "%d:" % int(chunk.landmark_lane)
		for ob in chunk.get_node("Obstacles").get_children():
			sig += "1" if ob.visible else "0"
		sig += "|"
	root.free()
	await _wait(1)
	return sig


func _test_board() -> void:
	GameState.set_mode(false)
	# This is the one test that is ABOUT filing runs, so it opts back in —
	# and then puts the flag back, so nothing after it writes to a real save.
	GameState.save_path = "user://test_compete_save.cfg"
	GameState.record_runs = true
	GameState.boards[GameState.Mode.FREE] = []
	# File six runs; only the best five may survive, in order.
	for pair in [["AAA", 500], ["BBB", 900], ["CCC", 100], ["DDD", 1500],
			["EEE", 700], ["FFF", 50]]:
		GameState.restart_state_only()
		GameState.score = int(pair[1])
		GameState.distance = float(pair[1])
		GameState.submit_run(String(pair[0]))

	var rows: Array = GameState.board()
	var names := ""
	var ordered := true
	for i in rows.size():
		names += String(rows[i]["who"]) + " "
		if i > 0 and int(rows[i]["score"]) > int(rows[i - 1]["score"]):
			ordered = false

	print("===== B) THE BOARD =====")
	print("  after six runs: %s(kept %d of 6)" % [names, rows.size()])
	_chk(rows.size() == GameState.BOARD_SIZE,
		"the board kept %d entries, expected %d" % [rows.size(), GameState.BOARD_SIZE])
	_chk(ordered, "the board is not in descending score order")
	_chk(int(rows[0]["score"]) == 1500, "the best run is not at the top")
	_chk(not names.contains("FFF"), "a score of 50 made a board whose lowest is higher")

	# And the chase: with the score at 800, the next one up is BBB on 900.
	GameState.restart_state_only()
	GameState.score = 800
	var rival: Dictionary = GameState.next_rival()
	print("  at 800 points, chasing: %s" % (String(rival["who"]) if rival else "nobody"))
	_chk(not rival.is_empty() and String(rival["who"]) == "BBB",
		"at 800 the next rival should be BBB on 900")

	GameState.score = 99999
	_chk(GameState.next_rival().is_empty(),
		"a score above everyone still reports somebody to chase")
	GameState.record_runs = false
	GameState.save_path = GameState.SAVE_PATH
	_done["board"] = true


func _test_share_line() -> void:
	GameState.restart_state_only()
	GameState.score = 1234
	GameState.distance = 890.0
	GameState.coins = 42
	GameState.set_mode(true)
	var daily := GameState.share_line()
	GameState.set_mode(false)
	var free := GameState.share_line()
	print("===== C) THE LINE YOU SEND A FRIEND =====")
	print("  daily: %s" % daily)
	print("  free : %s" % free)
	_chk(daily.contains(GameState.daily_label()),
		"the daily share line does not name the day, so it cannot be compared")
	_chk(daily.contains("1234") and daily.contains("890") and daily.contains("42"),
		"the share line is missing one of score, distance or coins")
	_chk(not free.contains(GameState.daily_label()),
		"a free run's share line claims to be a daily")
	_done["share"] = true
