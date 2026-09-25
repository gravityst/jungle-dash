extends Node
## GAME STATE — the score, the coins, and whether you're alive.
##
## This is an AUTOLOAD (also called a singleton): Godot creates it once when the
## game starts and keeps it alive forever, so any script can reach it just by
## typing `GameState.` — no dragging node references around.
##
## It also survives a restart, which is exactly what we want: the level is
## rebuilt from scratch but your BEST score carries over.
##
## It is registered under Project → Project Settings → Globals → Autoload.


## Other scripts listen to these instead of checking every frame.
## The HUD, for instance, only redraws when one of these actually fires.
signal score_changed(new_score: int)
signal coins_changed(new_coins: int)
signal multiplier_changed(new_multiplier: int)
## Fires when the magnet starts, expires, or is topped up. Carries the seconds
## remaining, so the HUD can show a countdown without polling every frame.
signal magnet_changed(seconds_left: float)
## Fires when the double-score surge starts or expires.
signal surge_changed(seconds_left: float)
## Fires when a shield is picked up (true) or spent (false).
signal shield_changed(has_shield: bool)
## Fires when you clear an obstacle that was in your lane. Carries the points.
signal near_miss(points: int)
## Fires when the double-jump spring starts or expires.
signal spring_changed(seconds_left: float)
signal died
signal restarted
## Fires when you overtake someone on the board, mid-run.
signal rival_passed(who: String, their_score: int)
## Fires when the run mode changes between the daily challenge and free play.
signal mode_changed(is_daily: bool)
## Fires when the title screen is dismissed and the first run begins.
signal run_started
## Fires the moment a power-up is picked up: "magnet", "plank", "surge" or
## "spring". The HUD names it and says what it does.
signal powerup_collected(kind: String)
## Fires when a journal mission is completed. Carries its text.
signal mission_done(text: String)
## Fires when a whole journal page is finished and the rank goes up.
signal rank_up(new_rank: int)
## Fires when you clip something and stumble instead of crashing. The chaser
## closes in on it; a second one before he drops back and you are caught.
signal stumbled


## FREE is a fresh random track every run. DAILY is the same track for
## everyone, all day — which is the only thing that makes two people's scores
## mean anything next to each other. Without it "I got 2,000" is a claim about
## two different games.
enum Mode {FREE, DAILY}


enum Phase {
	RUNNING,   ## normal play
	DEAD,      ## hit an obstacle; waiting for the player to restart
	TITLE,     ## the title screen before the very first run; any key starts it
}

# ---------------------------------------------------------------------------
#  SCORING — change these numbers to retune the game
# ---------------------------------------------------------------------------

## Points earned per metre run.
const POINTS_PER_METRE: float = 1.0

## Points earned per coin. Make this big enough that grabbing coins is worth
## the risk of moving into a lane you didn't need to be in.
const POINTS_PER_COIN: int = 25

## How long the coin magnet lasts, in seconds. Long enough to feel like a
## different mode of play, short enough that you want another one. Grabbing a
## second magnet while one is running REPLACES the timer rather than adding to
## it, so a lucky streak can't stack into a minute of free coins.
const MAGNET_SECONDS: float = 7.0

## How far the magnet reaches, in metres, and how fast it drags a coin in.
## The reach is deliberately wider than the track (9.1 m) so it sweeps coins
## out of lanes you are not in — that is the whole point of the power-up.
const MAGNET_RANGE: float = 11.0
const MAGNET_PULL: float = 26.0

## How long DOUBLE POINTS lasts. Shorter than the magnet because it is worth
## more: the magnet gets you coins, this doubles everything including distance.
const SURGE_SECONDS: float = 9.0

## What the surge multiplies score by. Applied ON TOP of the distance
## multiplier, so at x5 with a surge running you are earning x10.
const SURGE_FACTOR: int = 2

## Points for clearing an obstacle that was in your own lane — jumping a log,
## ducking a vine. Deliberately worth less than a coin: it is a bonus for
## playing well, not a reason to seek danger out.
const POINTS_PER_NEAR_MISS: int = 10

## How long the double jump lasts. Longer than the others because it changes
## how you MOVE rather than what you earn, and a movement ability you only get
## for a moment is more frustrating than fun.
const SPRING_SECONDS: float = 10.0

## THE CRASH. Time drops to this fraction of normal for a moment when you die,
## so the hit lands as an event rather than the game simply stopping.
##
## 0.35 for 0.35 s is deliberately short. Long enough to read what hit you and
## to let the camera shake register; short enough that it never becomes the
## thing standing between you and pressing restart.
const DEATH_SLOWMO: float = 0.35

## How long the slow motion lasts, in REAL seconds — measured off the system
## clock, because `delta` is exactly the thing being slowed and counting it
## down with a scaled delta would take 1/0.35 times as long as intended.
const DEATH_SLOWMO_SECONDS: float = 0.35

## Every this many metres, the multiplier goes up by one.
## How long the chaser stays on your heels after a stumble. Stumble again
## inside this window and he catches you.
const HEAT_SECONDS: float = 6.0

const MULTIPLIER_EVERY: float = 400.0
const MAX_MULTIPLIER: int = 5

# ---------------------------------------------------------------------------
#  LIVE STATE
# ---------------------------------------------------------------------------

var phase: Phase = Phase.RUNNING
var distance: float = 0.0     ## metres run this life
var coins: int = 0            ## coins collected this life
var score: int = 0            ## distance + coins, combined
var multiplier: int = 1       ## rises with distance; applies to everything
var magnet_time: float = 0.0  ## seconds of magnet left; 0 means inactive
var surge_time: float = 0.0   ## seconds of double points left
var has_shield: bool = false  ## true if a hit is currently survivable
var near_misses: int = 0      ## obstacles cleared in your own lane this life
var spring_time: float = 0.0  ## seconds of double jump left
var heat_time: float = 0.0    ## seconds the chaser stays close; >0 = one more stumble and you are caught
## What ended the run: "crash" (ran into something head on) or "caught"
## (stumbled twice with the chaser on your heels). The game over screen
## says which.
var death_cause: String = "crash"
## THE COACH (scripts/coach.gd). It shows JUMP / SLIDE / GO for the obstacle
## in your lane until you have cleared each kind a few times, then leaves you
## alone — and comes back for a kind you start failing. Off for robots: every
## test would otherwise have a coach counting its moves. CAP_COACH=1 turns it
## on for a screenshot.
var coaching: bool = true
const COACH_LEARN := 3
var coach_state := {"mode": "auto", "learned": {"jump": 0, "duck": 0, "dodge": 0, "wall": 0},
	"named": {"magnet": 0, "plank": 0, "surge": 0, "spring": 0, "landmark": 0, "pad": 0,
		"spring_jump": 0}}
## What you hit last, for "why did I die": the obstacle, how, and what you
## were doing. Display only — nothing in the rules reads it.
var last_hit := {}

## The Expedition Journal: three missions and the Explorer Rank. Loaded by
## path rather than class name, so it works before the editor has ever
## scanned the project.
const Missions := preload("res://scripts/missions.gd")
var journal: Missions = Missions.new()
## This run's tallies, for the journal: jumps, rolls, trains ridden...
var run_stats := {}

## System-clock time at which the crash slow motion ends. 0 means "not slowed".
var _slowmo_until_ms: int = 0

## Score is accumulated as you go rather than recomputed from totals, because
## the multiplier must apply to what you earn WHILE it is active — earning at
## x3 should not retroactively re-score the first kilometre.
var _accum: float = 0.0
var best_score: int = 0       ## highest score you have ever got

## Which kind of run this is.
var mode: Mode = Mode.FREE

## Top scores, kept separately per mode — a daily score and a free-play score
## are not comparable, so mixing them into one table would be meaningless.
## Each entry is {"who": String, "score": int, "metres": int, "coins": int}.
var boards := {Mode.FREE: [], Mode.DAILY: []}

## Whether finished runs are filed on the board at all. The tests kill the
## player deliberately and repeatedly; without this they would fill a real
## person's scoreboard with entries nobody earned.
var record_runs: bool = true

## The name new scores are filed under. Three letters, arcade style.
var player_name: String = "YOU"

## The board entry currently being chased, so passing it can be announced once.
var _rival_index: int = -1

## Where the high score is kept. user:// is a real folder on your machine
## (~/Library/Application Support/Godot/app_userdata/JungleDash on a Mac), so
## this survives quitting the game, not just restarting a run.
const SAVE_PATH := "user://save.cfg"

## Where progress is actually written. The tests point this at a scratch
## file: they used to write straight into the real one, and every run of the
## suite replaced the player's leaderboard with the test's AAA-to-EEE fixture
## rows and a best score set by the robot.
var save_path: String = SAVE_PATH

## How many names the board keeps. Five is enough for a household or a couple
## of friends passing a laptop around, and short enough to read at a glance on
## the game over screen.
const BOARD_SIZE := 5


func _ready() -> void:
	# Anything launched from tools/ — a test, a probe, a screenshot — is a
	# robot, not a player, and must never touch the real save. Deciding it
	# here means a new test is safe by default instead of safe only if its
	# author remembered to opt out.
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tools/"):
			record_runs = false
			coaching = false
	if OS.get_environment("CAP_COACH") != "":
		coaching = true
	# The title screen greets a PLAYER, once, when the game opens. Robots
	# skip it (every test expects to be running from frame one) unless a
	# screenshot tool asks for it, and restarts go straight back to running.
	if record_runs or OS.get_environment("CAP_TITLE") != "":
		phase = Phase.TITLE
	_load_progress()
	multiplier = 1 + rank_bonus()
	# Open BIG. The window used to open at 1920 x 1080 PIXELS, which on a
	# Retina Mac is a postcard in the middle of the screen. Maximized fills
	# the screen and renders at its full native resolution; F11 goes truly
	# full screen. Robots keep the exact window size they asked for.
	# (Only from a plain window: launched with --fullscreen it stays full
	# screen, and inside the editor's Game tab the editor owns the size.)
	if record_runs and DisplayServer.get_name() != "headless" \
			and not Engine.is_embedded_in_editor() \
			and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


## F11, Alt+Enter or Cmd+Ctrl+F (the Mac's own shortcut) toggles full screen,
## from anywhere in the game. Taken here, in _input, so the title screen's
## "any key starts" never sees it.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed) \
			or (key.keycode == KEY_F and key.meta_pressed and key.ctrl_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full
		else DisplayServer.WINDOW_MODE_FULLSCREEN)


## The magnet is the one piece of state that runs on a clock, so GameState is
## the only thing in the game that needs a per-frame update of its own.
func _process(delta: float) -> void:
	# This has to come BEFORE the is_running() guard below. The slow motion
	# starts at the moment of death, so by the time it needs ending the game is
	# already not running — put it after the guard and time never speeds back
	# up, which leaves the whole game in slow motion forever.
	if _slowmo_until_ms > 0 and Time.get_ticks_msec() >= _slowmo_until_ms:
		_end_slowmo()

	# Freeze every timer on death, so the game-over screen doesn't quietly burn
	# a power-up you paid attention to earn.
	if not is_running():
		return
	if magnet_time > 0.0:
		magnet_time = maxf(0.0, magnet_time - delta)
		magnet_changed.emit(magnet_time)
	if surge_time > 0.0:
		surge_time = maxf(0.0, surge_time - delta)
		surge_changed.emit(surge_time)
	if spring_time > 0.0:
		spring_time = maxf(0.0, spring_time - delta)
		spring_changed.emit(spring_time)
	if heat_time > 0.0:
		heat_time = maxf(0.0, heat_time - delta)


## Puts time back to normal. Safe to call at any moment, including when
## nothing was slowed.
func _end_slowmo() -> void:
	Engine.time_scale = 1.0
	_slowmo_until_ms = 0


## True while coins should be flying toward the player.
func magnet_active() -> bool:
	return magnet_time > 0.0 and is_running()


## True while score is being doubled.
func surge_active() -> bool:
	return surge_time > 0.0 and is_running()


## What every point earned is currently multiplied by: the distance multiplier,
## doubled again if a surge is running.
## How much coaching a kind of obstacle gets: 2 = the full READY then NOW
## with a reason, 1 = just the NOW, 0 = none — you know this one.
func coach_level(family: String) -> int:
	if not coaching or String(coach_state["mode"]) == "off":
		return 0
	var n: int = int(coach_state["learned"].get(family, COACH_LEARN))
	if n <= 0:
		return 2
	return 1 if n < COACH_LEARN else 0


## The moves still to be taught with a full-width lesson row: any the coach
## has never seen you do. Only in free play with the coach on.
func lessons_due() -> Array[String]:
	var out: Array[String] = []
	if not coaching or String(coach_state["mode"]) == "off" or is_daily():
		return out
	for f in ["jump", "duck", "dodge"]:
		if int(coach_state["learned"].get(f, 0)) <= 0:
			out.append(f)
	return out


## You got past one the right way.
func coach_cleared(family: String) -> void:
	if coach_state["learned"].has(family):
		coach_state["learned"][family] = mini(int(coach_state["learned"][family]) + 1, 99)


## You hit one: the coach comes back for that kind.
func coach_failed(family: String) -> void:
	if coach_state["learned"].has(family):
		# Back to the short NOW-only prompt for a couple of clears, not the
		# full beginner's version: one slip is not forgetting how to play.
		coach_state["learned"][family] = mini(int(coach_state["learned"][family]), COACH_LEARN - 2)


## Title screen C: auto -> off -> "new player" (forget everything) -> auto.
func cycle_coach_mode() -> String:
	var m := String(coach_state["mode"])
	if m == "auto":
		coach_state["mode"] = "off"
	elif m == "off":
		coach_state["mode"] = "auto"
		for k in coach_state["learned"]:
			coach_state["learned"][k] = 0
		for k in coach_state["named"]:
			coach_state["named"][k] = 0
		save_board()
		return "new"
	save_board()
	return String(coach_state["mode"])


## The player reports what it hit, just before stumbling or dying.
func note_hit(info: Dictionary) -> void:
	last_hit = info


## What the Explorer Rank adds to the multiplier. Nothing in the daily: that
## is the one run where everybody has to be on the same footing.
func rank_bonus() -> int:
	return 0 if is_daily() else journal.rank


## Counts something the journal cares about. `amount` is added to this run's
## total; for running values like distance use tally_value() instead.
func tally(stat: String, amount: int = 1) -> void:
	if not is_running():
		return
	run_stats[stat] = int(run_stats.get(stat, 0)) + amount
	_feed_journal(stat, int(run_stats[stat]), amount)


## Journal progress is a PLAYER's. Robots count their stats but never tick a
## box: a test that finished a page would get a rank, and a rank changes the
## multiplier, and every score the test then checks would be wrong.


## For stats that are a level rather than a count — metres, score.
func tally_value(stat: String, value: int) -> void:
	if not is_running() or value <= int(run_stats.get(stat, 0)):
		return
	var added := value - int(run_stats.get(stat, 0))
	run_stats[stat] = value
	_feed_journal(stat, value, added)


func _feed_journal(stat: String, run_value: int, amount: int) -> void:
	if not record_runs:
		return
	var finished: Array[int] = journal.feed(stat, run_value, amount)
	if finished.is_empty():
		return
	for i in finished:
		mission_done.emit(journal.text(i))
		Sfx.play("powerup")
	if journal.page_complete():
		if journal.turn_page():
			rank_up.emit(journal.rank)
			# Takes effect at once: the badge on the score ticks up.
			var wanted := clampi(1 + rank_bonus() + int(distance / MULTIPLIER_EVERY), 1,
				MAX_MULTIPLIER + rank_bonus())
			if wanted != multiplier:
				multiplier = wanted
				multiplier_changed.emit(multiplier)
	_save_progress()


func score_factor() -> int:
	return multiplier * (SURGE_FACTOR if surge_active() else 1)


## Called by the double-points pickup.
func start_surge() -> void:
	if not is_running():
		return
	powerup_collected.emit("surge")
	tally("powerups")
	surge_time = SURGE_SECONDS
	Sfx.play("powerup")
	surge_changed.emit(surge_time)


## True while a second jump is available in mid-air.
func spring_active() -> bool:
	return spring_time > 0.0 and is_running()


## Called by the spring pickup.
func start_spring() -> void:
	if not is_running():
		return
	powerup_collected.emit("spring")
	tally("powerups")
	spring_time = SPRING_SECONDS
	Sfx.play("powerup")
	spring_changed.emit(spring_time)


## Called by the shield pickup. Holding one is binary — a second pickup while
## you already have one is simply wasted, rather than stacking into a stock of
## lives that would flatten the difficulty entirely.
func give_shield() -> void:
	if not is_running():
		return
	powerup_collected.emit("plank")
	tally("powerups")
	tally("planks")
	has_shield = true
	Sfx.play("powerup")
	shield_changed.emit(true)


## Try to spend the shield to survive a hit. Returns true if it saved you.
## The player calls this from _check_for_crash BEFORE calling die().
func spend_shield() -> bool:
	if not is_running() or not has_shield:
		return false
	has_shield = false
	Sfx.play("shield")
	shield_changed.emit(false)
	return true


## Called by the magnet pickup when the player runs through it.
func start_magnet() -> void:
	if not is_running():
		return
	powerup_collected.emit("magnet")
	tally("powerups")
	magnet_time = MAGNET_SECONDS
	Sfx.play("powerup")
	magnet_changed.emit(magnet_time)


## A fresh game's board is not empty. Arcade machines always shipped with a
## table to beat, because "CHASING KOA, 180 TO GO" in your very first run is
## the whole competitive loop working before you have any friends on it.
## Pitched so a first run passes one or two and a good one tops the lot.
const STARTER_BOARD := [
	{"who": "ACE", "score": 6000, "metres": 2600, "coins": 120},
	{"who": "KOA", "score": 2500, "metres": 1300, "coins": 60},
	{"who": "MIA", "score": 1200, "metres": 700, "coins": 30},
	{"who": "BOB", "score": 600, "metres": 380, "coins": 12},
	{"who": "TIK", "score": 250, "metres": 180, "coins": 4},
]


func _load_progress() -> void:
	# Robots start from a clean slate every time. Reading the real save here
	# would make a test's score depend on the player's Explorer Rank.
	if not record_runs:
		boards[Mode.FREE] = STARTER_BOARD.duplicate(true)
		return
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		boards[Mode.FREE] = STARTER_BOARD.duplicate(true)
		return
	journal.from_dict(cfg.get_value("journal", "state", {}))
	# Read BEFORE the coach block below, which asks "has this person played
	# before?" by looking at it.
	best_score = int(cfg.get_value("progress", "best_score", 0))
	# An empty dict as the default, never null: ConfigFile treats a null
	# default as "no default" and prints an error for every older save.
	var cs: Dictionary = cfg.get_value("coach", "state", {})
	if not cs.is_empty():
		coach_state["mode"] = String(cs.get("mode", "auto"))
		var learned: Dictionary = cs.get("learned", {})
		for k in coach_state["learned"]:
			coach_state["learned"][k] = int(learned.get(k, 0))
		# Merged key by key, so an older save missing a key still loads.
		var named: Dictionary = cs.get("named", {})
		for k in coach_state["named"]:
			coach_state["named"][k] = int(named.get(k, 0))
	elif best_score > 0:
		# Somebody who has played before the coach existed: one short prompt
		# per kind, then silence — not a tutorial for a game they know.
		for k in coach_state["learned"]:
			coach_state["learned"][k] = COACH_LEARN - 1
	best_score = int(cfg.get_value("progress", "best_score", 0))
	player_name = String(cfg.get_value("progress", "player_name", "YOU"))
	boards[Mode.FREE] = cfg.get_value("board", "free", [])
	# The daily board is only meaningful for the day it was set on. A new day
	# is a different track, so yesterday's scores are not something to beat —
	# they were set on a course that no longer exists.
	var saved_day: String = String(cfg.get_value("board", "daily_day", ""))
	boards[Mode.DAILY] = cfg.get_value("board", "daily", []) \
		if saved_day == daily_label() else []


func _save_progress() -> void:
	# record_runs is off in every test and probe. Without this, a robot run
	# that died on a new high score wrote that score into the real save.
	if not record_runs:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "player_name", player_name)
	cfg.set_value("board", "free", boards[Mode.FREE])
	cfg.set_value("board", "daily", boards[Mode.DAILY])
	cfg.set_value("board", "daily_day", daily_label())
	cfg.set_value("journal", "state", journal.to_dict())
	cfg.set_value("coach", "state", coach_state)
	cfg.save(save_path)


# ---------------------------------------------------------------------------
#  THE DAILY CHALLENGE
# ---------------------------------------------------------------------------

## Today's date as a plain string, used to label the challenge and to tell when
## the daily board has gone stale.
func daily_label() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


## The seed everyone gets today.
##
## Derived from the date alone, so two people running the daily on the same day
## meet the same obstacles in the same order — which is the entire point. It is
## multiplied out rather than just concatenated so that consecutive days are not
## adjacent numbers, because adjacent seeds can produce visibly similar tracks.
func daily_seed() -> int:
	var d := Time.get_date_dict_from_system()
	var n: int = int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
	return (n * 2654435761) % 2147483647


## True when this run is today's shared challenge.
func is_daily() -> bool:
	return mode == Mode.DAILY


func set_mode(daily: bool) -> void:
	var wanted: Mode = Mode.DAILY if daily else Mode.FREE
	if mode == wanted:
		return
	mode = wanted
	mode_changed.emit(daily)


# ---------------------------------------------------------------------------
#  THE BOARD
# ---------------------------------------------------------------------------

## The table for the mode currently being played.
func board() -> Array:
	return boards[mode]


## The lowest entry still ahead of the current score, or an empty Dictionary
## once you are top. This is what the HUD chases.
func next_rival() -> Dictionary:
	var rows: Array = board()
	for i in range(rows.size() - 1, -1, -1):
		if int(rows[i]["score"]) > score:
			return rows[i]
	return {}


## Files the run just finished. Returns its position, or -1 if it did not make
## the table.
func submit_run(who: String) -> int:
	if not record_runs:
		return -1
	var rows: Array = board()
	var entry := {"who": who.to_upper().substr(0, 3), "score": score,
		"metres": int(distance), "coins": coins}
	rows.append(entry)
	rows.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if rows.size() > BOARD_SIZE:
		rows.resize(BOARD_SIZE)
	boards[mode] = rows
	player_name = entry["who"]
	_save_progress()
	return rows.find(entry)


## Writes the board out. Public so the HUD can persist a rename.
func save_board() -> void:
	_save_progress()


## One line a player can screenshot or type to a friend.
func share_line() -> String:
	if is_daily():
		return "Jungle Dash daily %s - %d pts, %d m, %d coins" % [
			daily_label(), score, int(distance), coins]
	return "Jungle Dash - %d pts, %d m, %d coins" % [score, int(distance), coins]


func on_title() -> bool:
	return phase == Phase.TITLE


## Leaves the title screen and starts the first run.
func start_run() -> void:
	if phase != Phase.TITLE:
		return
	phase = Phase.RUNNING
	run_started.emit()


## True while the player is alive and should be moving.
func is_running() -> bool:
	return phase == Phase.RUNNING


# ---------------------------------------------------------------------------
#  THINGS THE GAME CALLS
# ---------------------------------------------------------------------------

## Called by the player every physics frame with how far it just moved.
func add_distance(metres: float) -> void:
	if not is_running():
		return
	distance += metres
	_accum += metres * POINTS_PER_METRE * float(score_factor())
	if int(distance) / 50 != int(run_stats.get("metres", 0)) / 50:
		tally_value("metres", int(distance) / 50 * 50)
	var wanted := clampi(1 + rank_bonus() + int(distance / MULTIPLIER_EVERY), 1,
		MAX_MULTIPLIER + rank_bonus())
	if wanted != multiplier:
		multiplier = wanted
		multiplier_changed.emit(multiplier)
	_apply_score()


## Called by a coin when the player runs through it.
func collect_coin() -> void:
	if not is_running():
		return
	coins += 1
	_accum += float(POINTS_PER_COIN * score_factor())
	Sfx.play_coin()
	coins_changed.emit(coins)
	_apply_score()
	tally("coins")


## Called by the player when it clears an obstacle that was in its lane.
func award_near_miss() -> void:
	if not is_running():
		return
	var points: int = POINTS_PER_NEAR_MISS * score_factor()
	_accum += float(points)
	near_misses += 1
	Sfx.play("whoosh")
	near_miss.emit(points)
	_apply_score()
	tally("near_misses")


## Called by the player when it hits an obstacle.
## A mistake that is not a crash: you clipped the side of something, or the
## top edge of a hurdle. The first one costs you nothing but a scare — the
## chaser closes right in. A second one while he is still that close ends the
## run. A shield, if you have one, is spent instead.
##
## Returns true if this stumble got you caught.
func stumble() -> bool:
	if not is_running():
		return false
	if heat_time > 0.0:
		if spend_shield():
			heat_time = HEAT_SECONDS
			stumbled.emit()
			return false
		death_cause = "caught"
		die()
		return true
	heat_time = HEAT_SECONDS
	stumbled.emit()
	tally("stumbles")
	return false


func die() -> void:
	if not is_running():
		return
	phase = Phase.DEAD
	Sfx.play("crash")
	Engine.time_scale = DEATH_SLOWMO
	_slowmo_until_ms = Time.get_ticks_msec() + int(DEATH_SLOWMO_SECONDS * 1000.0)
	if score > best_score:
		best_score = score
	journal.end_run()
	_save_progress()
	died.emit()


## Wipes this life and rebuilds the level from scratch.
## Clears this life's score without rebuilding the level. Used by the tests,
## and handy if you ever add a level-select or a tutorial screen.
func restart_state_only() -> void:
	phase = Phase.RUNNING
	distance = 0.0
	coins = 0
	score = 0
	multiplier = 1 + rank_bonus()
	_accum = 0.0
	_end_slowmo()
	magnet_time = 0.0
	surge_time = 0.0
	has_shield = false
	near_misses = 0
	spring_time = 0.0
	heat_time = 0.0
	death_cause = "crash"
	run_stats = {}
	last_hit = {}
	# Forget who has been overtaken, or a second run would announce nobody.
	_rival_index = -1
	magnet_changed.emit(magnet_time)
	surge_changed.emit(surge_time)
	spring_changed.emit(spring_time)
	shield_changed.emit(false)
	multiplier_changed.emit(multiplier)
	score_changed.emit(score)
	coins_changed.emit(coins)


func restart() -> void:
	phase = Phase.RUNNING
	distance = 0.0
	coins = 0
	score = 0
	multiplier = 1 + rank_bonus()
	_accum = 0.0
	_end_slowmo()
	magnet_time = 0.0
	surge_time = 0.0
	has_shield = false
	near_misses = 0
	spring_time = 0.0
	heat_time = 0.0
	death_cause = "crash"
	run_stats = {}
	last_hit = {}
	# Forget who has been overtaken, or a second run would announce nobody.
	_rival_index = -1
	magnet_changed.emit(magnet_time)
	surge_changed.emit(surge_time)
	spring_changed.emit(spring_time)
	shield_changed.emit(false)
	multiplier_changed.emit(multiplier)
	score_changed.emit(score)
	coins_changed.emit(coins)
	restarted.emit()
	# reload_current_scene() throws everything away and builds main.tscn again,
	# which resets the track, the player and the camera in one go. THIS object
	# is an autoload, so it is NOT destroyed — that's how best_score survives.
	#
	# Deferred because restart() is usually called from an input or a button
	# press, and tearing the scene down while Godot is still walking it is a
	# good way to crash.
	get_tree().call_deferred("reload_current_scene")


## Watches for the moment the run overtakes somebody on the board.
func _check_rivals() -> void:
	var rows: Array = board()
	for i in rows.size():
		if int(rows[i]["score"]) <= score and _rival_index != i:
			# Only announce the FIRST one passed in a frame, and only once.
			if _rival_index < 0 or i < _rival_index:
				_rival_index = i
				rival_passed.emit(String(rows[i]["who"]), int(rows[i]["score"]))
				tally("rivals")
			return


func _apply_score() -> void:
	var new_score := int(_accum)
	if new_score != score:
		score = new_score
		score_changed.emit(score)
		# Only on whole hundreds: the journal saves on every change it sees.
		if score / 100 != int(run_stats.get("score", 0)) / 100:
			tally_value("score", score / 100 * 100)
		_check_rivals()
