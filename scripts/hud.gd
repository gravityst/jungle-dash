extends CanvasLayer
## THE ON-SCREEN DISPLAY — score, coins, and the game over screen.
##
## A CanvasLayer draws on top of the 3D world and is completely unaffected by
## the camera, the lighting or the fog. That's why the score stays crisp and
## readable no matter what the game is doing behind it.
##
## This script never asks "what's the score?" every frame. It waits for
## GameState to tell it something changed, and only then redraws. That's what
## the `signal` lines in game_state.gd are for.


# Every node is found by its unique %Name rather than a path, so the layout
# can be rearranged in the editor without breaking this script.
@onready var _score_label: Label = %Score
@onready var _distance_label: Label = %Distance
@onready var _coin_label: Label = %Coins
@onready var _coin_panel: Control = %CoinPanel
@onready var _mult_label: Label = %Multiplier
@onready var _mult_badge: Control = %MultBadge
@onready var _powers: Control = %Powerups
@onready var _shield_label: Control = %Shield
@onready var _near_label: Label = %NearMiss
@onready var _hint_label: Control = %Hint
@onready var _mode_label: Label = %Mode
@onready var _chase_label: Control = %Chase
@onready var _chase_who: Label = %ChaseWho
@onready var _chase_gap: Label = %ChaseGap

## Where this run landed on the board, or -1 if it did not make it. Typing
## letters on the game over screen renames THIS row.
var _placed: int = -1

## Counts down while the controls hint is on screen.
var _hint_timer: float = HINT_SECONDS

## How long the controls stay up if you do nothing. Touching any control hides
## them immediately — once you have shown you know, the reminder is clutter.
const HINT_SECONDS: float = 5.0

## Seconds left on the near-miss flash.
var _near_timer: float = 0.0
## Your best before this run started, so the game over screen can tell a new
## record from an old one — GameState overwrites best_score as you die.
var _best_before: int = 0
var _last_coins: int = 0
@onready var _game_over: Control = %GameOver
@onready var _result_label: Label = %Result
@onready var _final_score: Label = %FinalScore
@onready var _new_best: Label = %NewBest
@onready var _stats_label: Label = %Stats
@onready var _footer: Label = %Footer
@onready var _restart_button: Button = %RestartButton
@onready var _danger: Control = %Danger
@onready var _speed_lines: ColorRect = %SpeedLines
var _lines_k: float = 0.0
@onready var _title_screen: Control = %TitleScreen
@onready var _press_start: Control = %PressStart
@onready var _title_best: Label = %TitleBest
@onready var _logo: Control = %Logo
@onready var _toast: Label = %Toast
@onready var _why: Label = %Why
const CoachScript := preload("res://scripts/coach.gd")
@onready var _journal: Control = %Journal
@onready var _journal_rank: Label = %JournalRank
var _toast_timer: float = 0.0
var _pulse: float = 0.0
@onready var _title: Label = %Title


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.multiplier_changed.connect(_on_multiplier_changed)
	GameState.magnet_changed.connect(_on_power_changed)
	GameState.surge_changed.connect(_on_power_changed)
	GameState.spring_changed.connect(_on_power_changed)
	GameState.shield_changed.connect(_on_shield_changed)
	GameState.near_miss.connect(_on_near_miss)
	GameState.rival_passed.connect(_on_rival_passed)
	GameState.mode_changed.connect(func(_d: bool) -> void: _refresh_mode())
	GameState.died.connect(_on_died)
	GameState.stumbled.connect(_on_stumbled)
	GameState.run_started.connect(_on_run_started)
	GameState.mission_done.connect(_on_mission_done)
	GameState.powerup_collected.connect(_on_powerup)
	GameState.rank_up.connect(_on_rank_up)
	_toast.visible = false
	_restart_button.pressed.connect(_restart)

	_game_over.visible = false
	_best_before = GameState.best_score
	_last_coins = GameState.coins
	# The scene is rebuilt on restart, so draw the current values immediately
	# rather than waiting for the first change.
	_on_score_changed(GameState.score)
	_on_coins_changed(GameState.coins)
	_on_multiplier_changed(GameState.multiplier)
	_on_power_changed(0.0)
	_on_shield_changed(GameState.has_shield)
	_near_label.visible = false
	_hint_label.visible = _hint_wanted()
	_refresh_mode()
	_refresh_chase()
	_show_title(GameState.on_title())


## The title screen hides the running HUD; the run brings it back.
## The static controls bar is only for someone with the coach switched off:
## the coach teaches the keys at the moment you need them.
func _hint_wanted() -> bool:
	return not (GameState.coaching and String(GameState.coach_state["mode"]) != "off")


func _show_title(on: bool) -> void:
	_title_screen.visible = on
	_journal.visible = on
	if on:
		_draw_journal()
		_refresh_coach_help()
		# Pressing Play in the Godot editor runs the game INSIDE the editor's
		# Game tab by default, a small pane, where the whole picture is drawn
		# a fraction of its size and full screen cannot take over. Say so,
		# and how to get the real thing.
		var embed_note := %EmbedNote as Label
		embed_note.visible = Engine.is_embedded_in_editor()
		embed_note.text = ("Squeezed into the editor's small Game tab, so it looks tiny and soft. "
			+ "For full screen and full quality, double-click  Play Jungle Dash  in the game folder.")
	for n in [%TopRight, %TopLeft]:
		(n as CanvasItem).visible = not on
	_hint_label.visible = (not on) and _hint_wanted()
	if on:
		_title_best.text = "BEST  %s" % _grouped(GameState.best_score) \
			if GameState.best_score > 0 else "TODAY'S DAILY: PRESS M" \
			if not GameState.is_daily() else "DAILY CHALLENGE  %s" % GameState.daily_label()
		# Drop the logo in from above.
		_logo.position.y -= 420.0
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_logo, "position:y", _logo.position.y + 420.0, 0.7).set_delay(0.2)


func _refresh_coach_help(mode: String = "") -> void:
	if mode == "":
		mode = String(GameState.coach_state["mode"])
	var word: String = {"auto": "ON", "off": "OFF", "new": "RESET FOR A NEW PLAYER"}.get(mode, "ON")
	(%TitleHelp as Label).text = ("\u2190 \u2192 lanes     \u2191 jump     \u2193 slide     "
		+ "M  daily challenge     C  coach: %s     F11  full screen" % word)


func _on_run_started() -> void:
	# Fade the title out rather than cutting it, under the camera swoop.
	var t := create_tween()
	t.tween_property(_title_screen, "modulate:a", 0.0, 0.35)
	t.tween_callback(func() -> void:
		_title_screen.visible = false
		_title_screen.modulate.a = 1.0)
	for n in [%TopRight, %TopLeft]:
		(n as CanvasItem).visible = true
	_hint_timer = HINT_SECONDS
	_hint_label.visible = _hint_wanted()
	_journal.visible = false


## Score in the corner, distance under it. Every runner shows how far you
## got — it is the number people actually compare.
func _on_score_changed(new_score: int) -> void:
	_score_label.text = _grouped(new_score)
	_distance_label.text = "%d m" % int(GameState.distance)
	_refresh_chase()


## 12,480 rather than 12480: a number you read at a glance while running
## needs its thousands marked.
static func _grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## Shows the nearest score still ahead of you. This is the whole competitive
## loop in one plaque: not "your best was 1,240" after the fact, but "ABC is
## 180 points away" while you can still do something about it.
func _refresh_chase() -> void:
	var rival: Dictionary = GameState.next_rival()
	if rival.is_empty():
		_chase_label.visible = GameState.board().size() > 0
		_chase_who.text = "TOP OF THE BOARD"
		_chase_gap.text = "KEEP GOING!"
		return
	_chase_label.visible = true
	_chase_who.text = "CHASING %s" % String(rival["who"])
	_chase_gap.text = "%s TO GO" % _grouped(int(rival["score"]) - GameState.score)


func _refresh_mode() -> void:
	_mode_label.text = "DAILY  %s" % GameState.daily_label() if GameState.is_daily() \
		else "FREE RUN"


func _on_rival_passed(who: String, _their_score: int) -> void:
	_pop("PASSED %s!" % who, Color(0.55, 1.0, 0.55), 1.2)


func _on_coins_changed(new_coins: int) -> void:
	_coin_label.text = _grouped(new_coins)
	if new_coins > _last_coins:
		_punch(_coin_panel, 1.12)
	_last_coins = new_coins


## Hidden at x1: a permanent "x1" is noise, and the label appearing is itself
## the feedback that something just improved.
## ONE multiplier on screen: everything your points are being multiplied by
## right now, distance and rank and a running Double Score together — and
## violet while Double Score is part of it, the colour of that power-up.
func _on_multiplier_changed(_new_multiplier: int) -> void:
	var total: int = GameState.score_factor()
	var was: bool = _mult_badge.visible
	var was_text: String = _mult_label.text
	_mult_badge.visible = total > 1
	_mult_label.text = "x%d" % total
	var sb := _mult_badge.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.bg_color = Color(0.62, 0.30, 0.86) if GameState.surge_active() else Color(0.30, 0.74, 0.18)
	if total > 1 and is_inside_tree() and (was or GameState.is_running()) \
			and _mult_label.text != was_text:
		_punch(_mult_badge, 1.35)


## One bar per power-up, draining as it runs out. Two can run at once, so
## the only correct thing to draw is the whole current state, not whichever
## one happened to fire the signal.
var _surge_was := false


func _on_power_changed(_seconds_left: float) -> void:
	# Double Score starting or ending changes the multiplier badge.
	if GameState.surge_active() != _surge_was:
		_surge_was = GameState.surge_active()
		_on_multiplier_changed(GameState.multiplier)
	_set_power("PowerMagnet", GameState.magnet_time, GameState.MAGNET_SECONDS)
	_set_power("PowerDouble", GameState.surge_time, GameState.SURGE_SECONDS)
	_set_power("PowerSpring", GameState.spring_time, GameState.SPRING_SECONDS)


func _set_power(node_name: String, left: float, total: float) -> void:
	var row: Control = _powers.get_node(node_name)
	row.visible = left > 0.0
	if row.visible:
		(row.get_node("Row/Bar") as ProgressBar).value = clampf(left / total, 0.0, 1.0)
		# The last two seconds blink, so running out is never a surprise.
		row.modulate.a = 0.45 + 0.55 * absf(cos(Time.get_ticks_msec() * 0.012)) \
			if left < 2.0 else 1.0


func _on_shield_changed(has_shield: bool) -> void:
	_shield_label.visible = has_shield


## Flashes when you clear something that was in your lane.
func _on_near_miss(points: int) -> void:
	_pop("NICE! +%d" % points, Color(1.0, 0.84, 0.28), 0.75)


## Big text that punches in over the track and fades. It fades rather than
## just vanishing, because a label that blinks off draws the eye back to
## itself at exactly the moment you need to be looking at the track.
## Priority of the pop on screen now: a power-up banner (2) is not replaced
## by a "NICE! +10" (0) while it is still being read.
var _pop_prio: int = 0


func _pop(text: String, color: Color, seconds: float, prio: int = 0) -> void:
	if prio < _pop_prio and _near_timer > 0.0:
		return
	_pop_prio = prio
	_near_label.text = text
	_near_label.label_settings.font_color = color
	_near_label.visible = true
	_near_label.modulate.a = 1.0
	_near_timer = seconds
	_near_label.pivot_offset = _near_label.size * 0.5
	_near_label.scale = Vector2(1.45, 1.45)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_near_label, "scale", Vector2.ONE, 0.22)


## The journal page: a tick box, the mission, and how far along it is.
func _draw_journal() -> void:
	var j: GameState.Missions = GameState.journal
	var rb := GameState.rank_bonus()
	_journal_rank.text = "EXPLORER RANK %d   \u2022   +%d MULTIPLIER" % [j.rank, rb] \
		if not GameState.is_daily() else "EXPLORER RANK %d   \u2022   OFF IN THE DAILY" % j.rank
	var p := j.page()
	for i in 3:
		var row: Control = get_node("%%Mission%d" % i)
		var done: bool = j.done[i]
		(row.get_node("Text") as Label).text = j.text(i)
		(row.get_node("Text") as Label).modulate = Color(0.75, 1.0, 0.7) if done else Color(1, 1, 1)
		(row.get_node("Count") as Label).text = "DONE" if done else "%s / %s" % [
			_grouped(j.progress[i]), _grouped(int(p[i]["goal"]))]
		var tick := row.get_node("Tick") as Panel
		var sb := (tick.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = Color(0.36, 0.82, 0.22) if done else Color(0, 0, 0, 0.4)
		tick.add_theme_stylebox_override("panel", sb)


## Name it and say what it does, the moment you grab it. A power-up you do
## not understand is just a shiny thing that made the screen change.
## Each power-up has ONE colour, used for its glow on the track, its row in
## the HUD, this banner and the flash — so the four always read as the same
## four things.
var POWERUP_NAMES := {
	"magnet": ["MAGNET!", "Coins fly to you  \u2022  %d s" % GameState.MAGNET_SECONDS,
		Color(1.0, 0.30, 0.22), "PowerMagnet"],
	"plank": ["SURF PLANK!", "It takes the next crash for you", Color(0.35, 0.60, 1.0), "Shield"],
	"surge": ["DOUBLE SCORE!", "Every point counts twice  \u2022  %d s" % GameState.SURGE_SECONDS,
		Color(0.82, 0.45, 1.0), "PowerDouble"],
	"spring": ["SPRING!", "Press jump again in mid-air  \u2022  %d s" % GameState.SPRING_SECONDS,
		Color(0.35, 0.92, 1.0), "PowerSpring"],
}


func _on_powerup(kind: String) -> void:
	var info: Array = POWERUP_NAMES.get(kind, [kind.to_upper(), "", Color.WHITE, ""])
	_pop(String(info[0]), info[2], 2.2, 2)
	_show_toast(String(info[1]), 2.2)
	# A quick wash of its colour over the whole screen, and a kick on its row.
	# Gold, for every pickup: a full-screen wash of the magnet's red read as
	# taking a hit. The colour identity lives in the banner, bubble and row.
	var flash: ColorRect = %Flash
	flash.color = Color(1.0, 0.86, 0.35, 0.16)
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.3)
	var row: Control = _powers.get_node_or_null(String(info[3]))
	if row != null:
		call_deferred("_punch", row, 1.3)


func _on_mission_done(text: String) -> void:
	_pop("MISSION COMPLETE!", Color(0.55, 1.0, 0.45), 1.8, 1)
	_show_toast(text, 1.8)


func _on_rank_up(rank: int) -> void:
	_pop("RANK UP!", Color(1.0, 0.84, 0.28), 2.2, 3)
	_show_toast("Explorer Rank %d: +1 score multiplier, for good" % rank, 2.2)


func _show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_timer = seconds


## A quick scale kick on a counter, so a change is felt as well as read.
func _punch(c: Control, amount: float) -> void:
	if not is_inside_tree():
		return
	c.pivot_offset = c.size * Vector2(1.0, 0.5)
	c.scale = Vector2(amount, amount)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.18)


func _process(delta: float) -> void:
	_update_speed_lines(delta)
	if _title_screen.visible:
		# The start button breathes, so it reads as the thing to press.
		_pulse += delta
		_press_start.pivot_offset = _press_start.size * 0.5
		var k := 1.0 + 0.05 * sin(_pulse * 4.0)
		_press_start.scale = Vector2(k, k)
	_update_hint(delta)
	if _toast_timer > 0.0:
		_toast_timer = maxf(_toast_timer - delta, 0.0)
		_toast.modulate.a = clampf(_toast_timer / 0.5, 0.0, 1.0)
		_toast.visible = _toast_timer > 0.0
	if _near_timer <= 0.0:
		return
	_near_timer = maxf(_near_timer - delta, 0.0)
	# Hold full strength for most of it, then fade over the last half second.
	var k: float = clampf(_near_timer / 0.5, 0.0, 1.0)
	_near_label.modulate.a = k
	if _near_timer <= 0.0:
		_near_label.visible = false
		_pop_prio = 0


## Speed lines fade in over the last third of the speed range, and run flat
## out during a double-score surge, the one time the game wants you to feel
## you are going faster than you are.
func _update_speed_lines(delta: float) -> void:
	var want := 0.0
	var p := get_tree().get_first_node_in_group("player")
	if GameState.is_running() and p != null:
		var hi: float = p.max_speed
		want = clampf((p.forward_speed - hi * 0.72) / (hi * 0.28), 0.0, 1.0) * 0.7
		if GameState.surge_active():
			want = 1.0
	_lines_k = lerpf(_lines_k, want, 1.0 - exp(-3.0 * delta))
	_speed_lines.visible = _lines_k > 0.01
	(_speed_lines.material as ShaderMaterial).set_shader_parameter("strength", _lines_k)


## Fades the controls out, either on a timer or the moment you use one.
func _update_hint(delta: float) -> void:
	if not _hint_label.visible:
		return
	if not GameState.is_running():
		_hint_label.visible = false
		return
	var used: bool = Input.is_action_pressed("move_left") \
		or Input.is_action_pressed("move_right") \
		or Input.is_action_pressed("jump") \
		or Input.is_action_pressed("duck")
	if used:
		_hint_timer = minf(_hint_timer, 0.45)
	_hint_timer = maxf(_hint_timer - delta, 0.0)
	_hint_label.modulate.a = clampf(_hint_timer / 0.9, 0.0, 1.0)
	if _hint_timer <= 0.0:
		_hint_label.visible = false


## Red at the edges of the screen, and a warning: Bruno is right behind you
## and one more slip ends the run.
func _on_stumbled() -> void:
	_danger.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_danger, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	_pop("CAREFUL!", Color(1.0, 0.45, 0.35), 1.4, 2)
	# Say what happened. The advice only while the coach thinks you are
	# still learning that kind of obstacle; after that, just the fact.
	var why := CoachScript.explain(GameState.last_hit)
	var family := CoachScript.family_of_hit(GameState.last_hit)
	var line: String = why[0] if GameState.coach_level(family) == 0 or why[1] == "" \
		else "%s  \u2022  %s" % [why[0], why[1]]
	# (The red edge of the screen already says Bruno is behind you.)
	_show_toast(line, 2.4)


func _on_died() -> void:
	_title.text = "CAUGHT!" if GameState.death_cause == "caught" else "WIPEOUT!"
	var why := CoachScript.explain(GameState.last_hit, GameState.death_cause == "caught")
	_why.text = why[0] + ("\n" + why[1] if why[1] != "" else "")
	_placed = GameState.submit_run(GameState.player_name)
	_chase_label.visible = false
	_hint_label.visible = false
	_final_score.text = _grouped(GameState.score)
	_new_best.visible = GameState.score > _best_before and GameState.score > 0
	_stats_label.text = "%s m      %s coins" % [
		_grouped(int(GameState.distance)), _grouped(GameState.coins)]
	_draw_board()
	# Hold the panel back for a beat: the camera is swinging round to show the
	# crash, and Bruno arriving, and a panel slammed over it would hide the
	# best shot in the game. Real time, not game time — this runs inside the
	# death slow-motion. Restart works throughout; this is only the panel.
	var wait := create_tween()
	wait.set_ignore_time_scale(true)
	wait.tween_interval(1.0)
	wait.tween_callback(_show_game_over)


func _show_game_over() -> void:
	if GameState.is_running():
		return
	_game_over.visible = true
	_draw_journal()
	_journal.visible = true
	# The power-up bars froze when you died; they are noise on this screen.
	_powers.visible = false
	# Slam the title and score in rather than just appearing.
	for c in [_title, _final_score]:
		(c as Control).pivot_offset = (c as Control).size * 0.5
		(c as Control).scale = Vector2(0.4, 0.4)
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(c, "scale", Vector2.ONE, 0.35)


## The game over screen IS the scoreboard. Seeing your name land at number
## three with two people above it is a reason to press restart; a number on its
## own is not.
func _draw_board() -> void:
	var lines: Array[String] = []
	var rows: Array = GameState.board()
	lines.append("%s  TOP %d" % ["TODAY'S DAILY" if GameState.is_daily() else "FREE RUN",
		GameState.BOARD_SIZE])
	for i in rows.size():
		var row: Dictionary = rows[i]
		lines.append("%s %d. %-3s %8s  %6s m" % [
			">" if i == _placed else " ", i + 1, String(row["who"]),
			_grouped(int(row["score"])), _grouped(int(row["metres"]))])
	if _placed < 0:
		lines.append("   (this run did not make the board)")
	_result_label.text = "\n".join(lines)
	_footer.text = "SPACE: run again      type 3 letters: rename      M: %s" % [
		"free run" if GameState.is_daily() else "today's daily"]


## Space / W / up arrow / a tap also restarts, so you don't have to aim at the
## button on a phone.
func _unhandled_input(event: InputEvent) -> void:
	if GameState.on_title():
		_title_input(event)
		return
	if GameState.is_running():
		return

	# On the game over screen the keyboard belongs to the scoreboard: letters
	# rename your entry, M swaps which game you are playing.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_M:
			GameState.set_mode(not GameState.is_daily())
			_placed = -1
			_draw_board()
			get_viewport().set_input_as_handled()
			return
		if key.keycode >= KEY_A and key.keycode <= KEY_Z and _placed >= 0:
			_type_letter(char(key.keycode))
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("jump") or event is InputEventScreenTouch and event.pressed:
		# Swallow it. Without this the SAME keypress restarts the game and is
		# then read again by the fresh runner as a jump, so every restart began
		# with an involuntary hop — which, on a track whose first obstacle row
		# is 7.5 m in, is a jump you did not ask for at the worst moment.
		get_viewport().set_input_as_handled()
		_restart()


## On the title screen: M swaps to the daily challenge (rebuilding the track
## on today's seed, still on the title), and any other key or a tap starts.
func _title_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_M:
		GameState.set_mode(not GameState.is_daily())
		get_viewport().set_input_as_handled()
		get_tree().call_deferred("reload_current_scene")
		return
	if key != null and key.pressed and not key.echo and key.keycode == KEY_C:
		var m := GameState.cycle_coach_mode()
		_refresh_coach_help(m)
		get_viewport().set_input_as_handled()
		return
	var go: bool = (key != null and key.pressed and not key.echo) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if go:
		# Swallowed, so the key that starts the run is not also read as the
		# first jump or lane change of it.
		get_viewport().set_input_as_handled()
		GameState.start_run()


## Types into the three-letter name on the board, arcade style: each letter
## pushes the previous ones left and the fourth wraps back to the start.
func _type_letter(letter: String) -> void:
	var rows: Array = GameState.board()
	if _placed < 0 or _placed >= rows.size():
		return
	var current: String = String(rows[_placed]["who"])
	if current == GameState.player_name and current.length() >= 3:
		current = ""
	current = (current + letter).substr(maxi(0, current.length() + 1 - 3), 3)
	rows[_placed]["who"] = current
	GameState.player_name = current
	GameState.save_board()
	_draw_board()


func _restart() -> void:
	if GameState.is_running():
		return
	GameState.restart()
