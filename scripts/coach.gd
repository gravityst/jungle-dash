extends Control
## THE COACH — tells you what to do about the obstacle in YOUR lane, until you
## have shown you know.
##
## Two stages, because the moment you can first READ an obstacle is not the
## moment to press. A jump pressed 1.5 s early lands you on the thing. So:
##
##   READY  about 1.5 s out: the verb in white — "JUMP", "SLIDE", "GO RIGHT"
##   NOW    inside the press window: the verb in its colour, punched — "JUMP!"
##
## The NOW times come from the measured windows (see test_jumpwindow): a jump
## clears the log or the boulder if pressed 0.15-0.61 s before it at any
## speed, a slide clears a gate if started 0.06-0.49 s before. A cue at 0.55 s
## (jump) or 0.45 s (slide) is right whether you react instantly or a third of
## a second late. Dodging is NOW straight away — early is never wrong.
##
## It learns. Each kind you get past cleanly counts toward COACH_LEARN; after
## that the coach leaves that kind alone. Hit one and it comes back for it.
## Nothing here touches the player or the physics — it only reads and shows.

const Chunk := preload("res://scripts/track_chunk.gd")

const HEADS_UP_SECONDS := 1.5
## Jumping ON a landmark is a jump too, and has its own window, measured by
## tools/test_coach.tscn (COACH_SWEEP=1): you land on the roof if you leave
## the ground 0.20-0.65 s before its near end at 12 m/s (0.15-0.65 at 20).
## A cue at 0.6 s is inside that for any reaction from instant to 0.35 s.
const NOW_SECONDS := {"jump": 0.55, "duck": 0.45, "wall": 0.6}
## One colour per ACTION, everywhere the game talks about that action.
## Lime for SLIDE, not cyan: cyan already means the spring everywhere.
const COLORS := {"jump": Color(1.0, 0.86, 0.30), "duck": Color(0.62, 1.0, 0.42),
	"dodge": Color(1.0, 0.60, 0.30), "wall": Color(1.0, 0.60, 0.30)}
const VERBS := {"jump": "JUMP", "duck": "SLIDE", "wall": "JUMP ON"}
const KEYS := {"jump": "↑  or  SPACE", "duck": "↓  or  S", "wall": "↑  or  SPACE"}
const PASS_MARGIN := 1.0

var _player: CharacterBody3D
var _track: Node
var _threat := {}
var _stage := ""
## Obstacles the coach has watched come at you, by instance id: family, lane,
## and whether you hit something while it was close.
var _watch := {}
var _touch := false

## What the name tags say. Colours match everything else about that thing.
const TAGS := {
	"magnet": ["MAGNET", "pulls coins to you", Color(1.0, 0.30, 0.22)],
	"plank": ["SURF PLANK", "saves you from one crash", Color(0.35, 0.60, 1.0)],
	"surge": ["DOUBLE SCORE", "every point counts twice", Color(0.82, 0.45, 1.0)],
	"spring": ["SPRING", "jump again in mid-air", Color(0.35, 0.92, 1.0)],
	"landmark": ["", "jump on and run along it", Color(1.0, 0.60, 0.30)],
	"pad": ["BOUNCE PAD", "up into the treetops", Color(0.55, 0.95, 0.25)],
}
## How many times each thing gets a tag before you are assumed to know it.
const TAG_TIMES := {"magnet": 3, "plank": 3, "surge": 3, "spring": 3, "landmark": 2, "pad": 2}
const PICKUP_KEYS := ["magnet", "plank", "surge", "spring"]
var _tagged := {}
var _nudge_time: float = 0.0
var _nudged_this_air := false

@onready var _card: Control = %CoachCard
@onready var _verb: Label = %CoachVerb
@onready var _sub: Label = %CoachSub
@onready var _tag: Control = %CoachTag
@onready var _tag_name: Label = %TagName
@onready var _tag_sub: Label = %TagSub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	_tag.modulate.a = 0.0
	GameState.stumbled.connect(_on_hit)
	GameState.died.connect(_on_hit)


func _input(event: InputEvent) -> void:
	# Say "swipe" to someone on a touch screen and "SPACE" to someone on a
	# keyboard.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch = true
	elif event is InputEventKey:
		_touch = false


func _physics_process(_delta: float) -> void:
	if not GameState.coaching or not GameState.is_running():
		_threat = {}
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		_track = get_tree().get_first_node_in_group("track")
		if _player == null or _track == null:
			return
	_watch_passes()
	_threat = _next_threat(_player.current_lane)
	if _threat.is_empty():
		return
	var id: int = _threat["id"]
	if not _watch.has(id):
		_watch[id] = {"family": _threat["family"], "lane": _threat["lane"], "hit": false}


func _process(delta: float) -> void:
	_update_tag(delta)
	var want := 0.0
	var stage := ""
	# The spring's second jump: tell them it is there, the first times.
	if _spring_nudge(delta):
		_card.modulate.a = lerpf(_card.modulate.a, 1.0, 1.0 - exp(-18.0 * delta))
		return
	if not _threat.is_empty() and GameState.is_running() and _player != null:
		var family: String = _threat["family"]
		var level := GameState.coach_level(family)
		if level > 0 and not _action_taken(family):
			var secs: float = float(_threat["dist"]) / maxf(_player.forward_speed, 1.0)
			var now_at: float = NOW_SECONDS.get(family, HEADS_UP_SECONDS)
			stage = "now" if secs <= now_at else "ready"
			# A player who has half-learned it only gets the NOW.
			if stage == "ready" and level < 2:
				stage = ""
			if stage != "":
				want = 1.0
				_show(family, stage)
	if stage == "now" and _stage != "now":
		_punch()
	_stage = stage
	_card.modulate.a = lerpf(_card.modulate.a, want, 1.0 - exp(-18.0 * delta))


func _show(family: String, stage: String) -> void:
	var col: Color = COLORS[family]
	var now := stage == "now"
	var what: String = _threat["what"]
	var esc: Dictionary = _threat.get("escape", {})
	var dir: int = int(esc.get("dir", 0))
	var waiting: bool = String(esc.get("state", "")) == "wait"
	var arrow := "←  or  A" if dir < 0 else "→  or  D"
	var side := "LEFT" if dir < 0 else "RIGHT"
	# READY names what is coming; it is not yet an order. A JUMP shown 1.5 s
	# out gets pressed 1.5 s out, and lands you on the thing.
	if not now and family != "dodge":
		_verb.text = "%s AHEAD" % what.to_upper()
		_verb.label_settings.font_color = Color(1, 1, 1)
		_sub.text = "get ready to %s" % {"jump": "JUMP", "duck": "SLIDE", "wall": "JUMP ON"}[family]
		return
	_verb.label_settings.font_color = col
	match family:
		"jump", "duck":
			_verb.text = VERBS[family] + "!"
			var how := "over" if family == "jump" else "under"
			_sub.text = ("SWIPE %s" % ("UP" if family == "jump" else "DOWN")) if _touch \
				else "%s the %s   •   %s" % [how, what, KEYS[family]]
		"wall":
			_verb.text = "JUMP ON!"
			_sub.text = ("SWIPE UP" if _touch else "onto the %s   •   %s" % [what, KEYS["wall"]])
			if dir != 0 and not waiting:
				_sub.text += "   •   or go %s" % side
		_:
			if dir == 0:
				_verb.text = "GO ROUND"
				_sub.text = "the %s" % what
			elif waiting:
				# The way round is blocked a little further on: hold, then go.
				_verb.text = "WAIT..."
				_verb.label_settings.font_color = Color(1, 1, 1)
				_sub.text = "then go %s round the %s" % [side, what]
			else:
				_verb.text = "GO %s!" % side
				_sub.text = "round the %s" % what + ("" if _touch else "   •   %s" % arrow)


func _punch() -> void:
	_card.pivot_offset = Vector2(_card.size.x * 0.5, _card.size.y)
	_card.scale = Vector2(1.22, 1.22)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "scale", Vector2.ONE, 0.16)


## Has the player already done the right thing? Then say nothing more.
func _action_taken(family: String) -> bool:
	match family:
		"jump":
			# Any time in the air counts: after an early jump the card must not
			# come back shouting JUMP! while you are already falling.
			return not _player.is_on_floor()
		"duck":
			return _player.is_ducking()
		"wall":
			return _player.current_lane != int(_threat["lane"]) \
				or (not _player.is_on_floor() and _player.velocity.y > 0.0)
		_:
			return _player.current_lane != int(_threat["lane"])


## The nearest obstacle (or landmark end) coming at you in `lane`, inside the
## heads-up window. {} if there is none.
func _next_threat(lane: int) -> Dictionary:
	var pz: float = _player.global_position.z
	var reach: float = HEADS_UP_SECONDS * maxf(_player.forward_speed, 1.0)
	var best := {}
	for chunk in _track.get_children():
		var obstacles: Node = chunk.get_node_or_null("Obstacles")
		if obstacles == null:
			continue
		for ob in obstacles.get_children():
			if not ob.visible:
				continue
			if LaneConfig.x_to_lane(ob.position.x) != lane:
				continue
			var dist: float = pz - (chunk.position.z + ob.position.z)
			if dist < -0.5 or dist > reach:
				continue
			if not best.is_empty() and dist >= float(best["dist"]):
				continue
			var slot: int = int(ob.get_meta(&"slot", 0))
			var family := Chunk.family_of(slot)
			if family == "":
				continue
			best = {"id": ob.get_instance_id(), "dist": dist, "family": family, "lane": lane,
				"what": String(Chunk.NAMES.get(slot, "obstacle")), "z": chunk.position.z + ob.position.z}
		# The near end of a landmark in your lane: jump on, or go round.
		var lm: Node3D = chunk.get_node_or_null("Landmarks/Landmark0")
		if lm != null and lm.visible and LaneConfig.x_to_lane(lm.position.x) == lane \
				and _player.global_position.y < Chunk.LANDMARK_TOP - 0.2:
			var d2: float = pz - (chunk.position.z + lm.position.z)
			if d2 > -0.5 and d2 <= reach and (best.is_empty() or d2 < float(best["dist"])):
				best = {"id": lm.get_instance_id(), "dist": d2, "family": "wall", "lane": lane,
					"what": String(lm.get_meta(&"what", "fallen giant")),
					"z": chunk.position.z + lm.position.z}
	if not best.is_empty() and (best["family"] == "dodge" or best["family"] == "wall"):
		best["escape"] = _escape(lane, float(best["dist"]))
	return best


## Which way to go round, and whether you can go NOW. Each neighbouring lane
## is one of:
##   clear     nothing in it from here to just past the obstacle
##   same-row  blocked at the same depth, but the lane beyond it is clear —
##             the right answer is two moves, so go, and re-cue from there
##   wait      blocked NEARER than the obstacle, then clear: usable once that
##             thing has gone past you
## Preference: clear (toward the middle if both are), then same-row, then
## wait. {"dir": 0} if there is no way round at all.
func _escape(lane: int, dist: float) -> Dictionary:
	var found := {"clear": [], "same": [], "wait": []}
	for d: int in [-1, 1]:
		var l: int = lane + d
		if l < 0 or l >= LaneConfig.LANE_COUNT:
			continue
		var near := _nearest_in(l, -1.0, dist + 6.0)
		if near < 0.0:
			found["clear"].append(d)
		elif absf(near - dist) <= 1.5:
			var l2: int = l + d
			if l2 >= 0 and l2 < LaneConfig.LANE_COUNT and _nearest_in(l2, -1.0, dist + 6.0) < 0.0:
				found["same"].append(d)
		elif near < dist - 1.5 and _nearest_in(l, near + 1.5, dist + 6.0) < 0.0:
			found["wait"].append(d)
	for state in ["clear", "same", "wait"]:
		var ds: Array = found[state]
		if ds.is_empty():
			continue
		var d: int = ds[0]
		if ds.size() == 2:
			d = 1 if lane < LaneConfig.LANE_COUNT / 2 else -1
		return {"dir": d, "state": state}
	return {"dir": 0, "state": "none"}


## Distance to the nearest solid thing in `lane` between `lo` and `hi` metres
## ahead, or -1. A landmark counts for its whole length.
func _nearest_in(lane: int, lo: float, hi: float) -> float:
	var pz: float = _player.global_position.z
	var best := -1.0
	for chunk in _track.get_children():
		var obstacles: Node = chunk.get_node_or_null("Obstacles")
		if obstacles == null:
			continue
		for ob in obstacles.get_children():
			if not ob.visible or LaneConfig.x_to_lane(ob.position.x) != lane:
				continue
			var dist: float = pz - (chunk.position.z + ob.position.z)
			if dist > lo and dist < hi and (best < 0.0 or dist < best):
				best = dist
		var lm: Node3D = chunk.get_node_or_null("Landmarks/Landmark0")
		if lm != null and lm.visible and LaneConfig.x_to_lane(lm.position.x) == lane:
			var near_end: float = pz - (chunk.position.z + lm.position.z)
			var far_end: float = near_end + Chunk.LANDMARK_LEN
			if far_end > lo and near_end < hi:
				var d := maxf(near_end, lo + 0.001)
				if best < 0.0 or d < best:
					best = d
	return best


## Anything watched that is now behind you, and was not hit, was learned.
func _watch_passes() -> void:
	var pz: float = _player.global_position.z
	for id in _watch.keys():
		var obj := instance_from_id(id) as Node3D
		if obj == null or not obj.visible:
			_watch.erase(id)
			continue
		var z: float = obj.global_position.z
		if obj.name == "Landmark0":
			z -= Chunk.LANDMARK_LEN
		if pz < z - PASS_MARGIN:
			var w: Dictionary = _watch[id]
			var family: String = w["family"]
			var stayed: bool = _player.current_lane == int(w["lane"])
			# Riding a landmark or going round it are both right.
			var right_way := true if family == "wall" \
				else (stayed if (family == "jump" or family == "duck") else not stayed)
			if not w["hit"] and right_way:
				GameState.coach_cleared(family)
			_watch.erase(id)


func _on_hit() -> void:
	# The thing you hit is the one right in front of you — or level with you.
	var family := family_of_hit(GameState.last_hit)
	if family != "":
		GameState.coach_failed(family)
	for id in _watch:
		var obj := instance_from_id(id) as Node3D
		if obj == null or _player == null:
			continue
		var pz := _player.global_position.z
		var near: float = obj.global_position.z
		# A landmark is 16 m long: a scrape anywhere along it counts.
		var far: float = near - (Chunk.LANDMARK_LEN if obj.name == "Landmark0" else 0.0)
		if pz < near + 4.0 and pz > far - 4.0:
			_watch[id]["hit"] = true


static func family_of_hit(hit: Dictionary) -> String:
	if hit.is_empty():
		return ""
	if bool(hit.get("landmark", false)):
		return "wall"
	return Chunk.family_of(int(hit.get("slot", -1)))


## WHY did that happen? A headline and a piece of advice, from what you hit,
## which face of it, and what you were doing at the time.
static func explain(hit: Dictionary, caught: bool = false) -> PackedStringArray:
	if caught:
		return PackedStringArray(["Bruno caught you!",
			"Two slips while he's close and he's got you. Shake him off first."])
	if hit.is_empty():
		return PackedStringArray(["Wipeout!", ""])
	var family := family_of_hit(hit)
	var what: String = String(hit.get("what", "")) if bool(hit.get("landmark", false)) \
		else String(Chunk.NAMES.get(int(hit.get("slot", -1)), "obstacle"))
	var how: String = hit.get("how", "face")
	var airborne: bool = hit.get("airborne", false)
	var rising: bool = hit.get("rising", false)
	var ducking: bool = hit.get("ducking", false)
	match family:
		"jump":
			if ducking:
				return PackedStringArray(["You can't slide under a %s" % what, "JUMP over low things"])
			if airborne and rising:
				return PackedStringArray(["Clipped the %s" % what, "Jump a moment SOONER"])
			if airborne:
				return PackedStringArray(["Came down on the %s" % what, "Jump a moment LATER"])
			return PackedStringArray(["Ran into the %s" % what, "JUMP over low things  (↑ / SPACE)"])
		"duck":
			if airborne:
				return PackedStringArray(["Jumped into the %s" % what, "SLIDE under gates  (↓ / S)"])
			if not ducking and int(hit.get("ms_since_duck", 99999)) < 900:
				return PackedStringArray(["Stood up under the %s" % what, "Slide a moment LATER"])
			return PackedStringArray(["Ran into the %s" % what, "SLIDE under gates  (↓ / S)"])
		"dodge":
			if how == "side":
				# A side hit means you steered INTO it while it was alongside.
				return PackedStringArray(["Moved into the %s too soon" % what, "Wait till it passes, then switch"])
			if airborne:
				return PackedStringArray(["Too tall to jump", "Go AROUND the %s  (← →)" % what])
			return PackedStringArray(["Ran into the %s" % what, "Tall things: go AROUND  (← →)"])
		"wall":
			if how == "side":
				return PackedStringArray(["Scraped the %s" % what, "Wait until it ends to move over"])
			return PackedStringArray(["Ran into the end of the %s" % what, "JUMP ON TOP of it, or go round"])
	return PackedStringArray(["Wipeout!", ""])


## "JUMP AGAIN!" in mid-air while the spring's second jump is unused, the
## first couple of times you have one. Returns true while it is showing.
func _spring_nudge(delta: float) -> bool:
	if not GameState.coaching or _player == null or not GameState.is_running():
		return false
	if _player.is_on_floor():
		_nudged_this_air = false
	var named: Dictionary = GameState.coach_state["named"]
	if not _nudged_this_air and int(named["spring_jump"]) < 2 and _player.can_air_jump() \
			and _player.velocity.y < 1.5 and String(GameState.coach_state["mode"]) != "off":
		_nudged_this_air = true
		named["spring_jump"] = int(named["spring_jump"]) + 1
		_nudge_time = 0.6
		_verb.text = "JUMP AGAIN!"
		_verb.label_settings.font_color = Color(0.35, 0.92, 1.0)
		_sub.text = "the spring gives you a second jump in the air"
		_punch()
	_nudge_time = maxf(_nudge_time - delta, 0.0)
	return _nudge_time > 0.0


## The floating name tag over the nearest thing worth naming.
func _update_tag(delta: float) -> void:
	var want := 0.0
	if GameState.coaching and GameState.is_running() and _player != null and _track != null \
			and String(GameState.coach_state["mode"]) != "off":
		var target := _tag_target()
		var cam := get_viewport().get_camera_3d()
		if not target.is_empty() and cam != null:
			var pos: Vector3 = target["pos"] + Vector3(0.0, 1.2, 0.0)
			if not cam.is_position_behind(pos):
				var key: String = target["key"]
				var info: Array = TAGS[key]
				_tag_name.text = target.get("name", info[0])
				_tag_name.label_settings.font_color = info[2]
				_tag_sub.text = info[1]
				var sb := _tag.get_theme_stylebox("panel") as StyleBoxFlat
				if sb != null:
					sb.border_color = info[2]
				var sp := cam.unproject_position(target["pos"] + Vector3(0.0, 0.8, 0.0))
				# The HUD is laid out at 1920x1080 and stretched; convert.
				var scale_k: float = get_viewport_rect().size.x / get_viewport().get_visible_rect().size.x
				sp *= scale_k
				# BESIDE the thing, on the verge side of its lane, level with
				# it — never centred over it, where it would hide the next
				# obstacles coming down the same stretch of track.
				var lane := LaneConfig.x_to_lane(float(target["pos"].x))
				var go_left: bool = lane == 0 or (lane == 1 and target["pos"].x <= 0.0)
				var gap := 70.0
				var x: float = sp.x - _tag.size.x - gap if go_left else sp.x + gap
				var y: float = sp.y - _tag.size.y * 0.5
				var w: float = get_viewport_rect().size.x
				_tag.position = Vector2(clampf(x, 16.0, w - _tag.size.x - 16.0), y)
				want = 1.0
				var id: int = target["id"]
				if not _tagged.has(id):
					_tagged[id] = true
					var named: Dictionary = GameState.coach_state["named"]
					named[key] = int(named.get(key, 0)) + 1
	_tag.modulate.a = lerpf(_tag.modulate.a, want, 1.0 - exp(-14.0 * delta))


## The nearest power-up, landmark or bounce pad 8-40 m ahead that has not been
## named enough times yet (or that this very tag is already naming).
func _tag_target() -> Dictionary:
	var pz: float = _player.global_position.z
	var best := {}
	var named: Dictionary = GameState.coach_state["named"]
	for chunk in _track.get_children():
		var cands := []
		var pick: Node3D = chunk.get_node_or_null("Powerups/Pickup")
		if pick != null and pick.visible:
			cands.append({"node": pick, "key": PICKUP_KEYS[clampi(int(chunk.pickup_kind), 0, 3)]})
		var lm: Node3D = chunk.get_node_or_null("Landmarks/Landmark0")
		if lm != null and lm.visible:
			cands.append({"node": lm, "key": "landmark",
				"name": String(lm.get_meta(&"what", "fallen giant")).to_upper()})
		var pad: Node3D = chunk.get_node_or_null("Skyway/Pad")
		if pad != null and pad.visible:
			cands.append({"node": pad, "key": "pad"})
		for c in cands:
			var node: Node3D = c["node"]
			var id := node.get_instance_id()
			var key: String = c["key"]
			if not _tagged.has(id) and int(named.get(key, 0)) >= int(TAG_TIMES[key]):
				continue
			var dist: float = pz - node.global_position.z
			# Past 25 m it is a speck in the vanishing point, and a tag there
			# only hides whatever is coming.
			if dist < 8.0 or dist > 25.0:
				continue
			if best.is_empty() or dist < float(best["dist"]):
				best = {"id": id, "key": key, "dist": dist, "pos": node.global_position}
				if c.has("name"):
					best["name"] = c["name"]
	return best
