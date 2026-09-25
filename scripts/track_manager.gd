extends Node3D
class_name TrackManager
## THE ENDLESS TRACK.
##
## Keeps a fixed number of track pieces alive at all times. As the player runs
## forward, any piece that falls far enough behind is picked up, moved to the
## far end of the track and re-rolled with new obstacles and scenery.
##
## The player never actually "arrives" anywhere — the world is a treadmill of
## about nine pieces being reused forever. Because the pool never grows or
## shrinks, the game runs at a steady frame rate no matter how far you get.


@export_group("Setup")

## The track piece to repeat. Drag scenes/track_chunk.tscn here.
@export var chunk_scene: PackedScene

## The player to follow. Leave empty and it finds the node in the "player"
## group automatically.
@export var player: Node3D

@export_group("Track")

## How many pieces stay alive at once. Each is 30 m, so 9 pieces is 270 m of
## track. More = you can see further, but more to draw.
@export_range(3, 24, 1) var chunk_count: int = 9

## How much track to keep BEHIND the player before recycling a piece, in metres.
## This must comfortably exceed the camera's distance behind the player
## (about 8 m) — otherwise the ground vanishes from under the camera.
@export_range(10.0, 80.0, 1.0) var keep_behind: float = 24.0

## The first few pieces have no obstacles, so you get a moment to settle in
## before anything can hit you.
@export_range(0, 6, 1) var safe_start_chunks: int = 2

## Untick to get a completely empty track. Very useful while you're working on
## the camera, the scenery or the player's feel and don't want to keep
## crashing into things.
@export var spawn_obstacles: bool = true

@export_group("Difficulty")

## Distance in metres over which the game ramps from easiest to hardest.
## Lower = the difficulty climbs faster.
@export_range(100.0, 5000.0, 50.0) var difficulty_distance: float = 900.0

@export_group("Treetops")

## How far apart the treetop runs are, in metres. The first one arrives at
## roughly this distance, the next at twice it, and so on.
##
## The floor of 300 is not arbitrary: the set-piece is 180 m long and is dealt
## about 200 m ahead of the player, so a value near the sequence length would
## queue the next run before the current one had finished and the game would
## become permanently airborne.
@export_range(300.0, 5000.0, 50.0) var canopy_every: float = 900.0

## How far in the FIRST treetop run is, separately from the spacing after it.
##
## This exists because the answer used to be "you don't get one". The sequence
## is laid about 215 m ahead of you, so at the old 900 m spacing you first met
## the treetops at roughly 1115 m — around SIXTY SECONDS of never dying. The
## best thing in the game was behind a wall almost nobody would get through,
## and a player who never sees a feature may as well not have it.
##
## 220 m puts the first one at about 435 m, which is roughly 25 seconds in:
## long enough to have learned the controls, early enough to actually happen.
@export_range(100.0, 3000.0, 20.0) var canopy_first: float = 220.0

## Turn the treetop run off entirely. Used by the tests that want a plain,
## predictable track.
@export var canopy_runs: bool = true

@export_group("Randomness")

## Leave at 0 for a different track every run. Set any other number to get the
## SAME track every time, which is very handy when you're testing a change and
## want to compare like with like.
@export var random_seed: int = 0


## The live pool, ordered from the piece nearest BEHIND the player (index 0)
## to the piece furthest AHEAD (last index).
var _chunks: Array[TrackChunk] = []
var _rng := RandomNumberGenerator.new()

## Z position of the near edge of the furthest-ahead piece.
var _front_z: float = 0.0
## Where the player started, so we can measure how far they've run.
var _start_z: float = 0.0
## Whether the piece built most recently carries a landmark.
var _last_had_landmark: bool = false

## Which authored shape the previous piece used, so the next one can avoid
## repeating it. A chunk cannot see its neighbours — they live in a recycled
## ring — so the manager has to remember, exactly as it does for landmarks.
var _last_pattern: String = ""

## Lanes the previous piece ended with something jumpable in. The next piece
## must not block them, because a jump from that row lands 0.7 m into this one.
var _last_jump_lanes: Array[int] = []

## The treetop set-piece, dealt one piece per recycle. Empty means "not in one".
var _canopy_queue: Array[TrackChunk.Role] = []

## The distance at which the next treetop run is queued up.
var _next_canopy_at: float = 0.0

## The order the pieces come in. APPROACH clears the run-in AND switches off
## the leaf canopy that would otherwise hang in the launch path; the run up top
## lasts about 5.5 seconds, which is long enough to enjoy and short enough to
## want again.
##
## The NARROW stretch sits in the MIDDLE on purpose. Putting it first would ask
## something of you before you had found your feet up there, and putting it
## last would overlap the drop home — in the middle you get a stretch of easy
## running, one thing to do, then a stretch of easy running again.
const CANOPY_SEQUENCE: Array[TrackChunk.Role] = [
	TrackChunk.Role.APPROACH,
	TrackChunk.Role.LAUNCH,
	TrackChunk.Role.DECK,
	TrackChunk.Role.NARROW,
	TrackChunk.Role.DECK,
	TrackChunk.Role.EXIT,
]


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_error("TrackManager has no player. Assign one, or put the player in the 'player' group.")
		return
	if chunk_scene == null:
		push_error("TrackManager has no chunk_scene. Drag scenes/track_chunk.tscn into it.")
		return

	# Seed order matters. An explicitly set random_seed always wins, because
	# that is what the tests use to make a run reproducible. Otherwise the
	# daily challenge hands everyone the same number for the whole day — which
	# is the entire reason two people's scores can be compared at all — and
	# free play just rolls the dice.
	if random_seed != 0:
		_rng.seed = random_seed
	elif GameState.is_daily():
		_rng.seed = GameState.daily_seed()
	else:
		_rng.randomize()

	_start_z = player.global_position.z
	_next_canopy_at = canopy_first
	_build_track()


func _build_track() -> void:
	# Piece 0 sits BEHIND the player (covering z 0 .. +30) so there's ground
	# under the camera. Every following piece steps one length further ahead.
	_front_z = _start_z + LaneConfig.CHUNK_LENGTH

	# First-run lessons for any move the coach has not yet seen you make:
	# one full-width row each, straight after the safe opening pieces. Never
	# on a seeded track (every test and screenshot) and never in the daily,
	# which has to be the same course for everyone.
	var lessons: Array[String] = GameState.lessons_due() \
		if random_seed == 0 and spawn_obstacles else ([] as Array[String])
	for i in chunk_count:
		var chunk: TrackChunk = chunk_scene.instantiate()
		add_child(chunk)
		chunk.position = Vector3(0.0, 0.0, _front_z)
		var k := i - safe_start_chunks
		var forced: Array = TrackChunk.LESSONS[lessons[k]] \
			if k >= 0 and k < lessons.size() else []
		# randomise() needs the node to be ready, which it now is.
		chunk.randomise(_rng, 0.0, _is_safe(i), not _last_had_landmark and forced.is_empty(),
			TrackChunk.Role.NORMAL, _last_pattern, _last_jump_lanes, forced)
		_last_had_landmark = chunk.landmark_lane >= 0
		_last_pattern = chunk.pattern_name
		_last_jump_lanes = chunk.jump_exit_lanes
		_chunks.append(chunk)
		_front_z -= LaneConfig.CHUNK_LENGTH

	# _front_z overshot by one step in the final loop iteration; wind it back
	# so it points at the near edge of the piece furthest ahead.
	_front_z += LaneConfig.CHUNK_LENGTH


## Whether piece number `i` should be built empty.
func _is_safe(i: int) -> bool:
	return not spawn_obstacles or i < safe_start_chunks


func _physics_process(_delta: float) -> void:
	if player == null or _chunks.is_empty():
		return

	# "while", not "if": if the game ever hitches badly enough that the player
	# crosses two pieces in one frame, this still catches up in the same frame
	# instead of leaving a hole in the track.
	while not _chunks.is_empty() and _is_behind(_chunks[0]):
		_recycle_front()


## True once a piece is entirely behind the player, plus the safety margin.
func _is_behind(chunk: TrackChunk) -> bool:
	# A piece sits between (position.z - CHUNK_LENGTH) and position.z.
	# Its far edge is the smaller number, because forward is NEGATIVE z.
	var far_edge: float = chunk.position.z - LaneConfig.CHUNK_LENGTH
	return far_edge - player.global_position.z > keep_behind


## Takes the piece nearest behind the player and moves it to the far end.
func _recycle_front() -> void:
	var chunk: TrackChunk = _chunks.pop_front()
	_front_z -= LaneConfig.CHUNK_LENGTH
	chunk.position = Vector3(0.0, 0.0, _front_z)
	# Never two landmarks in consecutive pieces. A chunk cannot see its
	# neighbour — they live in a recycled ring — so the manager has to
	# remember. Without this you can get a 30 m-plus wall in one lane.
	chunk.randomise(_rng, difficulty_for_roll(), not spawn_obstacles, not _last_had_landmark,
		_next_role(), _last_pattern, _last_jump_lanes)
	_last_had_landmark = chunk.landmark_lane >= 0
	_last_pattern = chunk.pattern_name
	_last_jump_lanes = chunk.jump_exit_lanes
	_chunks.push_back(chunk)


## Deals the next piece of the treetop sequence, starting a new one when the
## player has run far enough.
##
## The check happens HERE, at the moment a piece is re-rolled, rather than on a
## timer: a recycled piece is laid down a long way ahead of the player, so
## queueing the run when the distance is passed means it actually arrives a few
## hundred metres later. That lag is wanted — it is what makes the clearing
## appear in front of you rather than under you.
func _next_role() -> TrackChunk.Role:
	if not _canopy_queue.is_empty():
		return _canopy_queue.pop_front()
	# Deliberately NOT gated on spawn_obstacles. The two settings answer
	# different questions — "is this track dangerous" and "does it have a
	# treetop run" — and tying them together meant the canopy test, which
	# switches obstacles off so the run-up cannot kill anyone, could never see
	# a canopy at all.
	if not canopy_runs:
		return TrackChunk.Role.NORMAL
	if distance_travelled() < _next_canopy_at:
		return TrackChunk.Role.NORMAL
	# Schedule the next one from the milestone, not from where the player
	# happens to be, so the runs stay evenly spaced however fast you are going.
	_next_canopy_at += canopy_every
	_canopy_queue = CANOPY_SEQUENCE.duplicate()
	return _canopy_queue.pop_front()


# -----------------------------------------------------------------------------
#  USEFUL TO CALL FROM OTHER SCRIPTS (score, speed ramping, UI)
# -----------------------------------------------------------------------------

## How far the player has run, in metres. Always positive.
func distance_travelled() -> float:
	if player == null:
		return 0.0
	return maxf(_start_z - player.global_position.z, 0.0)


## 0.0 at the start of a run, climbing to 1.0 at difficulty_distance.
##
## This is the difficulty WHERE THE PLAYER IS. Anything being built for the
## player to meet later wants difficulty_for_roll() instead.
func difficulty() -> float:
	return clampf(distance_travelled() / difficulty_distance, 0.0, 1.0)


## How far ahead of the player a freshly recycled piece is laid down.
##
## A piece is recycled once its far edge is keep_behind past the player, and it
## reappears at the far end of the ring, so the gap is the whole ring minus the
## piece itself minus that margin.
func lead_distance() -> float:
	return float(chunk_count - 1) * LaneConfig.CHUNK_LENGTH - keep_behind


## The difficulty a piece should be built AT, which is the difficulty of the
## place the player will be standing when they reach it.
##
## Rolling with difficulty() instead was a quiet, systematic bug: every gate in
## the game fired about 216 m later than the number written next to it, because
## the piece carrying that content was built 216 m before the player got to it.
## It made the authored obstacle patterns — the whole feature that stops the
## track feeling generated — have a median first sighting of 728 m, which most
## players never reach. One line, and every gate in the game lines up with its
## own number again.
func difficulty_for_roll() -> float:
	return clampf((distance_travelled() + lead_distance()) / difficulty_distance,
		0.0, 1.0)
