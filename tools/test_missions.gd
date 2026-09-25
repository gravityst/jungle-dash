extends Node
## THE EXPEDITION JOURNAL — missions tick, pages turn, the rank sticks.
##
##   A) A cumulative mission adds up across runs; an in-one-run one does not.
##   B) Finishing all three turns the page and raises the rank by one...
##   C) ...which raises the score multiplier by one, but never in the daily.
##   D) It all survives a save and a reload.
##   E) With record_runs off (every other test), nothing ever ticks.
##
## Runs against a scratch save file, never the player's.

var _fails := []
var _done_texts: Array[String] = []
var _ranks: Array[int] = []


func _chk(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)


func _ready() -> void:
	GameState.save_path = "user://test_missions_save.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	GameState.record_runs = true
	GameState.set_mode(false)
	GameState.journal = GameState.Missions.new()
	GameState.restart_state_only()
	GameState.mission_done.connect(func(t: String) -> void: _done_texts.append(t))
	GameState.rank_up.connect(func(r: int) -> void: _ranks.append(r))

	var j = GameState.journal
	print("===== A) PAGE ONE =====")
	for i in 3:
		print("  %d. %s" % [i + 1, j.text(i)])
	# Coins in one run: 30, die, 30 again — must NOT add up to 60.
	for i in 30:
		GameState.tally("coins")
	GameState.die()
	GameState.restart_state_only()
	for i in 30:
		GameState.tally("coins")
	_chk(not j.done[0], "an in-one-run mission added up across two runs")
	# Jumps are cumulative: 10 + 10 across a death must finish the 15.
	for i in 10:
		GameState.tally("jumps")
	GameState.die()
	GameState.restart_state_only()
	for i in 10:
		GameState.tally("jumps")
	print("  jumps across two runs done: %s   coins 30+30 done: %s" % [j.done[1], j.done[0]])
	_chk(j.done[1], "a cumulative mission did not add up across runs")

	print("\n===== B) FINISH THE PAGE =====")
	var mult_before := GameState.multiplier
	for i in 45:
		GameState.tally("coins")
	GameState.distance = 450.0
	GameState.tally_value("metres", 450)
	print("  completed: %s" % [_done_texts])
	print("  rank ups: %s   rank now %d   page now %d" % [_ranks, j.rank, j.page_index])
	_chk(_done_texts.size() == 3, "expected 3 missions completed, got %d" % _done_texts.size())
	_chk(j.rank == 1 and _ranks == [1], "finishing the page did not raise the rank to 1")
	_chk(j.page_index == 1, "the page did not turn")

	print("\n===== C) THE MULTIPLIER =====")
	# 450 m is also past the first distance step, so: 1 + rank + 1 step.
	var want: int = 1 + j.rank + int(GameState.distance / GameState.MULTIPLIER_EVERY)
	print("  multiplier %d -> %d (want %d)" % [mult_before, GameState.multiplier, want])
	_chk(GameState.multiplier == want, "rank up did not add one to the multiplier")
	GameState.die()
	GameState.restart_state_only()
	_chk(GameState.multiplier == 2, "a fresh run at rank 1 should start at x2, got x%d" % GameState.multiplier)
	GameState.set_mode(true)
	GameState.restart_state_only()
	print("  daily starts at x%d (rank ignored)" % GameState.multiplier)
	_chk(GameState.multiplier == 1, "the daily must ignore the rank")
	GameState.set_mode(false)
	GameState.restart_state_only()

	print("\n===== D) SAVE AND RELOAD =====")
	for i in 4:
		GameState.tally("rolls")
	GameState.die()
	var saved: Dictionary = j.to_dict()
	GameState.journal = GameState.Missions.new()
	GameState._load_progress()
	var back = GameState.journal
	print("  saved %s" % saved)
	print("  loaded page %d rank %d progress %s" % [back.page_index, back.rank, back.progress])
	_chk(back.rank == 1 and back.page_index == 1, "rank or page lost across a reload")
	_chk(back.progress[0] == 4, "cumulative progress (rolls 4) lost across a reload")

	print("\n===== E) ROBOTS NEVER TICK =====")
	GameState.record_runs = false
	GameState.restart_state_only()
	var before: int = back.progress[0]
	for i in 50:
		GameState.tally("rolls")
	print("  rolls progress with record_runs off: %d -> %d" % [before, back.progress[0]])
	_chk(back.progress[0] == before, "the journal advanced while record_runs was off")

	GameState.save_path = GameState.SAVE_PATH
	print("\n===== VERDICT =====")
	if _fails.is_empty():
		print("ALL MISSION CHECKS PASSED")
	else:
		for f in _fails:
			print("  FAIL: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)
