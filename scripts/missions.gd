extends RefCounted
## THE EXPEDITION JOURNAL — three missions at a time, and a rank that grows.
##
## Finish all three missions on the page and your Explorer Rank goes up by
## one, which adds one to your score multiplier for good. That is the whole
## loop of the game this is modelled on: every run is a chance to tick a box,
## and every page you finish makes every future run worth more.
##
## A mission is either IN ONE RUN ("collect 40 coins in one run" — the count
## starts again each run) or CUMULATIVE ("jump 15 times" — it adds up across
## runs until it is done). GameState owns one of these and feeds it every
## stat through tally(); this file only keeps score.

## The hand-made pages, in order. Each teaches something: the first is the
## basics, the second the moves, the third the set-pieces, and the last two
## are for players who have got good. After the last page they repeat with
## bigger numbers (see page()).
const PAGES := [
	[
		{"stat": "coins", "goal": 40, "run": true, "text": "Collect %d coins in one run"},
		{"stat": "jumps", "goal": 15, "run": false, "text": "Jump %d times"},
		{"stat": "metres", "goal": 400, "run": true, "text": "Run %d m in one run"},
	],
	[
		{"stat": "rolls", "goal": 10, "run": false, "text": "Roll %d times"},
		{"stat": "powerups", "goal": 3, "run": false, "text": "Grab %d power-ups"},
		{"stat": "rivals", "goal": 2, "run": true, "text": "Pass %d rivals in one run"},
	],
	[
		{"stat": "planks", "goal": 1, "run": false, "text": "Ride a surf plank"},
		{"stat": "launches", "goal": 1, "run": false, "text": "Bounce up to the Skyway"},
		{"stat": "score", "goal": 2500, "run": true, "text": "Score %d in one run"},
	],
	[
		{"stat": "near_misses", "goal": 20, "run": false, "text": "Clear %d close calls"},
		{"stat": "trains", "goal": 3, "run": false, "text": "Run along %d fallen trees or ruins"},
		{"stat": "coins", "goal": 120, "run": true, "text": "Collect %d coins in one run"},
	],
	[
		{"stat": "stumbles", "goal": 3, "run": false, "text": "Shake off Bruno %d times"},
		{"stat": "metres", "goal": 1500, "run": true, "text": "Run %d m in one run"},
		{"stat": "score", "goal": 10000, "run": true, "text": "Score %d in one run"},
	],
]

## The highest the rank goes. Past this the multiplier would swamp the
## distance multiplier the game is balanced around.
const MAX_RANK := 10

var page_index: int = 0
var rank: int = 0
## Progress on each of the current page's three missions.
var progress: Array[int] = [0, 0, 0]
var done: Array[bool] = [false, false, false]


## The current page's three missions. Pages past the hand-made ones repeat
## them with every goal scaled up by half again per lap.
func page() -> Array:
	var base: Array = PAGES[page_index % PAGES.size()]
	var lap := page_index / PAGES.size()
	var out := []
	for m in base:
		var copy: Dictionary = (m as Dictionary).duplicate()
		copy["goal"] = int(round(float(m["goal"]) * (1.0 + 0.5 * float(lap))))
		out.append(copy)
	return out


## Human text for mission i, with its number filled in.
func text(i: int) -> String:
	var m: Dictionary = page()[i]
	var t: String = m["text"]
	return t % int(m["goal"]) if t.contains("%d") else t


## Feeds a stat in. `run_value` is this run's total so far; `amount` is how
## much was just added. Returns the indices of any missions this completed.
func feed(stat: String, run_value: int, amount: int) -> Array[int]:
	var finished: Array[int] = []
	var p := page()
	for i in 3:
		if done[i] or p[i]["stat"] != stat:
			continue
		if p[i]["run"]:
			progress[i] = maxi(progress[i], run_value)
		else:
			progress[i] += amount
		if progress[i] >= int(p[i]["goal"]):
			progress[i] = int(p[i]["goal"])
			done[i] = true
			finished.append(i)
	return finished


## A run ended: in-one-run missions that were not finished start from zero
## next time. (The best attempt is not kept — "in one run" means it.)
func end_run() -> void:
	var p := page()
	for i in 3:
		if p[i]["run"] and not done[i]:
			progress[i] = 0


func page_complete() -> bool:
	return done[0] and done[1] and done[2]


## Turns the page. Returns true if the rank went up.
func turn_page() -> bool:
	page_index += 1
	progress = [0, 0, 0]
	done = [false, false, false]
	if rank < MAX_RANK:
		rank += 1
		return true
	return false


func to_dict() -> Dictionary:
	return {"page": page_index, "rank": rank, "progress": progress, "done": done}


func from_dict(d: Dictionary) -> void:
	page_index = int(d.get("page", 0))
	rank = int(d.get("rank", 0))
	var pr: Array = d.get("progress", [0, 0, 0])
	var dn: Array = d.get("done", [false, false, false])
	for i in 3:
		progress[i] = int(pr[i]) if i < pr.size() else 0
		done[i] = bool(dn[i]) if i < dn.size() else false
