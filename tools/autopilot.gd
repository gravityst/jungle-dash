extends Node
## A simple robot player, used by the tests and by the demo recording.
## It is NOT part of the game — nothing in scenes/ references it.
##
## It scans the track ahead, and for whatever is in its own lane it either
## jumps (low hurdle) or slides to whichever lane has the most clear road.

## Everything the bot does is measured in SECONDS of warning, not metres,
## because the player speeds up as the run goes on. A fixed 15 m look-ahead is
## 1.25 s at the starting speed but only 0.6 s at top speed — which is how you
## end up with a bot that plays well early and dies the moment it gets fast.

## How far ahead it can see, in seconds of travel.
const LOOK_SECONDS := 1.6
## Start reacting when the obstacle is this many seconds away.
const REACT_SECONDS := 1.15
## Include obstacles slightly BEHIND us too. Without this the bot goes blind
## exactly when it's pressed against something, and can never escape.
const LOOK_MIN := -1.5

## When to jump, as a fraction of the jump's own length. The jump lasts about
## 0.57 s, and the player is above a 0.6 m hurdle for roughly the middle 80% of
## that arc — so committing when the hurdle is ~0.30 s away puts the peak right
## over it. Expressed in time, this stays correct at any speed.
const JUMP_SECONDS := 0.30
## When to duck. The duck lasts 0.55 s, so this commits with roughly a third
## of it left to spare after the obstacle has gone past.
const DUCK_SECONDS := 0.30

## After changing lane, wait this long before changing again, so the bot can't
## dither between two lanes and end up straddling the line.
const LANE_COMMIT := 0.22

var player: CharacterBody3D
var track: Node3D

var _commit := 0.0


func setup(p: CharacterBody3D, t: Node3D) -> void:
	player = p
	track = t


## Current speed, never zero, so we can convert seconds into metres.
func _speed() -> float:
	return maxf(player.forward_speed, 1.0)


func _physics_process(delta: float) -> void:
	if player == null or track == null:
		return
	_commit = maxf(_commit - delta, 0.0)

	var seen := _scan()
	if seen.is_empty():
		return

	var cur: int = player.current_lane
	var threat := _nearest_in_lane(seen, cur)
	if threat.is_empty():
		return

	var dist: float = threat["dist"]
	var kind: String = threat["kind"]

	# Pressed up against something with nowhere to go? Deal with it now,
	# ignoring the commit timer — this is the "I am stuck" escape hatch.
	var stuck: bool = absf(player.velocity.z) < 0.5 and player.is_on_floor()

	if dist > REACT_SECONDS * _speed() and not stuck:
		return

	# Something we can jump or duck: deal with it in place rather than
	# swerving. Staying in a lane you already know is clear beats trading a
	# known hazard for an unknown one — it's what a good human player does too.
	if kind == "jump":
		if player.is_on_floor() and (dist <= JUMP_SECONDS * _speed() or stuck):
			player.request_jump()
		return
	if kind == "wall":
		# Nothing to do but leave the lane — handled below.
		pass
	elif kind == "duck":
		# Duck later than you jump: the duck only lasts 0.55 s, so committing
		# early means standing up again right in front of the vines.
		if player.is_on_floor() and dist <= DUCK_SECONDS * _speed():
			player.request_duck()
		return

	# A blocker we can neither jump nor duck: we have to go round it.
	if _commit > 0.0 and not stuck:
		return

	var best := _clearest_lane(seen, cur)
	if best != cur:
		player.change_lane(signi(best - cur))
		_commit = LANE_COMMIT
	elif player.is_on_floor():
		# Boxed in. A wall cannot be jumped or ducked, so there is nothing
		# useful to do but keep trying to leave the lane.
		if kind == "duck":
			player.request_duck()
		elif kind != "wall":
			player.request_jump()


## Every live obstacle within the look-ahead window.
func _scan() -> Array:
	var pz: float = player.global_position.z
	var out := []
	for chunk in track.get_children():
		var obstacles: Node3D = chunk.get_node_or_null("Obstacles")
		if obstacles == null:
			continue
		for ob in obstacles.get_children():
			# `visible` is the immediate "is this obstacle in play" flag.
			# CollisionShape3D.disabled is set deferred, so it can lag by a
			# frame right after a chunk recycles.
			if not ob.visible:
				continue
			var col: CollisionShape3D = ob.get_node("CollisionShape3D")
			# Obstacle positions are LOCAL to their chunk; add the chunk's z.
			var dist: float = pz - (chunk.position.z + ob.position.z)
			if dist < LOOK_MIN or dist > LOOK_SECONDS * _speed():
				continue
			# Work out what SAVES you from this obstacle purely from the shape
			# of its collider, rather than asking the track what kind it is:
			#   floats clear of the ground -> duck under it
			#   low enough to clear        -> jump it
			#   otherwise                  -> go round it
			var box := col.shape as BoxShape3D
			var bottom: float = col.position.y - box.size.y * 0.5
			var top: float = col.position.y + box.size.y * 0.5
			var kind := "dodge"
			if bottom > 0.9:
				kind = "duck"
			elif top <= 0.85:
				kind = "jump"
			out.append({
				"lane": LaneConfig.x_to_lane(ob.position.x),
				"dist": dist,
				"kind": kind,
			})

		# --- landmarks ---
		# Long ridable things. A human might jump on and run the roof; this bot
		# plays it safe and treats the lane as closed for the whole length,
		# which is what makes it a fair test of whether the track stays
		# passable AROUND them.
		var lm: Node3D = chunk.get_node_or_null("Landmarks/Landmark0")
		if lm != null and lm.visible:
			var near_z: float = chunk.position.z + lm.position.z
			var far_z: float = near_z - TrackChunk.LANDMARK_LEN
			var dist: float = pz - near_z
			# Alongside it: treat as right on top of us so we never steer in.
			if pz <= near_z and pz >= far_z:
				dist = 0.0
			if dist >= LOOK_MIN and dist <= LOOK_SECONDS * _speed():
				out.append({
					"lane": LaneConfig.x_to_lane(lm.position.x),
					"dist": maxf(dist, 0.0),
					"kind": "wall",
				})
	return out


func _nearest_in_lane(seen: Array, lane: int) -> Dictionary:
	var best := {}
	for o in seen:
		if o["lane"] != lane:
			continue
		if best.is_empty() or o["dist"] < best["dist"]:
			best = o
	return best


## How much clear road a lane has before its first obstacle.
##
## A landmark is a WALL, not a point: it blocks its lane for 16 m, so a lane
## carrying one is worth less than its raw distance suggests — you cannot pass
## it, only leave again.
##
## It is scored at HALF distance rather than zeroed, and getting that wrong
## cost a bot two lives. Judging a wall purely on distance-to-near-end made a
## landmark 20 m away look like the roomiest lane going, so the bot steered in
## and got trapped. Over-correcting to zero was worse: a wall 30 m away then
## scored the same as an obstacle 0.2 m away, and the bot swerved out of the
## one safe lane into a tree. Halving keeps both cases honest.
const WALL_PENALTY := 0.5

func _clearance(seen: Array, lane: int) -> float:
	var m := INF
	for o in seen:
		if o["lane"] != lane:
			continue
		var d: float = o["dist"]
		if o["kind"] == "wall":
			d *= WALL_PENALTY
		m = minf(m, d)
	return m


## The lanes CROSSED on the way to a target have to be survivable too. You do
## not teleport between lanes, you slide through the ones in between.
##
## This is what killed the bot twice: it would pick a lane 0.35 m "roomier"
## two lanes over, and walk straight through a tree standing in the lane
## between. A human would never do that, and the track was not unfair — the
## bot was just not modelling its own movement.
const CROSS_SECONDS := 0.40

func _path_is_clear(seen: Array, cur: int, target: int) -> bool:
	if target == cur:
		return true
	var step := signi(target - cur)
	var lane := cur + step
	while lane != target:
		if _clearance(seen, lane) < CROSS_SECONDS * _speed():
			return false
		lane += step
	return true


## Pick the lane with the most room, out of the ones we can actually GET to.
## Ties go to the nearest lane, so the bot takes one step rather than crossing
## the whole track for no reason.
func _clearest_lane(seen: Array, cur: int) -> int:
	var best := cur
	var best_clear := _clearance(seen, cur)
	for lane in LaneConfig.LANE_COUNT:
		if not _path_is_clear(seen, cur, lane):
			continue
		var c := _clearance(seen, lane)
		if c > best_clear + 0.01 or (absf(c - best_clear) <= 0.01 and absi(lane - cur) < absi(best - cur)):
			best = lane
			best_clear = c
	return best
