extends Node3D
class_name TrackChunk
## ONE MODULAR PIECE OF TRACK.
##
## The endless track is really just a handful of these (about 9) being shuffled
## around forever. When a piece falls behind the player, the TrackManager picks
## it up, moves it to the far end of the track and calls randomise() on it —
## which re-rolls its obstacles and scenery so it looks like a brand new piece.
##
## NOTHING IS EVER CREATED OR DESTROYED WHILE THE GAME RUNS. Every obstacle and
## every tree already exists inside this scene from the start; they just get
## moved, resized and hidden. That's called "pooling", and it's what stops an
## endless runner from stuttering every few seconds as the garbage collector
## cleans up discarded pieces.


## What can sit in a lane.
## What can sit in a lane. The FAMILY is what matters — which button saves you —
## and each family has two looks so the track doesn't repeat itself.
enum Slot {
	EMPTY,    ## nothing — run straight through
	LOG,      ## python            — JUMP
	ROCK,     ## mossy boulder     — JUMP
	TREE,     ## tree trunk        — DODGE (can't jump it, can't duck it)
	PILLAR,   ## stone stela       — DODGE
	VINES,    ## vine curtain      — DUCK
	BRANCH,   ## low branch        — DUCK
}

## The long ridable things. At most one per piece.
enum Landmark {
	NONE,
	FALLEN_GIANT,  ## a rainforest tree lying along the trail
	RUIN_WALL,     ## a run of old temple wall
}

const LANDMARK_LEN := 16.0
const LANDMARK_TOP := 1.10
## Where the landmark's near end sits along the piece. Centred, so it spans
## z -7 to -23 and covers BOTH obstacle rows (-7.5 and -22.5) in its lane.
const LANDMARK_START_Z := -7.0
## How often a piece gets one. Too many and the track is a slalom of walls;
## too few and the player never meets the feature.
const LANDMARK_CHANCE := 0.38

## What each obstacle is called when the game talks about it.
const NAMES := {Slot.LOG: "python log", Slot.ROCK: "boulder", Slot.TREE: "strangler fig",
	Slot.PILLAR: "stone stela", Slot.VINES: "vine curtain", Slot.BRANCH: "fallen trunk"}

const JUMPABLE: Array[int] = [Slot.LOG, Slot.ROCK]
const DODGEABLE: Array[int] = [Slot.TREE, Slot.PILLAR]
## The FIRST entry of each list is that action's standard look, the only one
## you meet early in a run (see CANONICAL_UNTIL): the python log, the deadfall
## and the strangler fig. The deadfall is the standard slide because it is the
## same log as the jump, lifted — low log means jump, high log means slide.
const DUCKABLE: Array[int] = [Slot.BRANCH, Slot.VINES]

## Below this difficulty (about the first 225 m) every obstacle is its
## family's standard look, so a new player learns three shapes before they
## meet six. The random draw still happens, so seeded tracks keep their shape.
const CANONICAL_UNTIL := 0.25

## FIRST-RUN LESSONS: full-width rows that teach one move each, dealt at the
## start of a free run for any move the coach has not seen you do yet. A
## python stretched across the whole trail, a deadfall across all three lanes,
## and a pair of giant trees that funnel you to the middle and then block it.
## Passable by construction — they are outside PATTERNS and its rules.
const LESSONS := {
	"jump": [[Slot.LOG, Slot.LOG, Slot.LOG], [Slot.EMPTY, Slot.EMPTY, Slot.EMPTY]],
	"duck": [[Slot.BRANCH, Slot.BRANCH, Slot.BRANCH], [Slot.EMPTY, Slot.EMPTY, Slot.EMPTY]],
	"dodge": [[Slot.TREE, Slot.EMPTY, Slot.TREE], [Slot.EMPTY, Slot.PILLAR, Slot.EMPTY]],
}

## A pattern cell names a FAMILY, not a specific obstacle. GAP is clear road,
## HOP is something to jump, ROUND is something to go around, UNDER is
## something to duck. Writing patterns in families rather than in slots means
## each cell still picks its own look at random, so an authored shape does not
## come with an authored appearance — you meet the same shape as a log one time
## and a boulder the next.
enum Cell {GAP, HOP, ROUND, UNDER}

## THE AUTHORED PATTERNS.
##
## The rows used to be rolled independently, which is exactly why the track
## felt generated: nothing ever related what the first row asked of you to
## where the second row wanted you to be. A piece had no shape, just two
## unrelated events 15 m apart. These are ten deliberate little shapes that do
## relate their two rows.
##
## Each carries a `min_diff`: the difficulty at which it unlocks, on the same
## 0..1 scale the track manager uses (distance / 900 m). The simple shapes —
## one blocked lane, one idea — are available immediately; the ones that block
## two lanes, or that ask for a jump and then a lane change, only turn up later.
## Without this a player meets the hardest shape in the table as readily as the
## gentlest one on their very first run, which is not difficulty, it is dice.
##
## EVERY ENTRY OBEYS FIVE RULES, and the rules matter more than the table —
## tools/test_track.tscn enforces all five, so a new pattern that breaks one
## fails the build rather than reaching a player:
##
##   1. Exactly ROWS rows of exactly LANE_COUNT cells.
##   2. Every row has at least one GAP. Blocking all three lanes is the one
##      thing that makes a run flatly impossible.
##   3. No HOP in row 1. A held jump stays airborne for about 19 m, which is
##      MORE than the 15 m between rows — so a jump asked for at the second
##      row can carry you past the end of the piece and into whatever the next
##      one starts with, which no piece can see.
##   4. Every HOP must land in a GAP: if row 0 lane L is a HOP, row 1 lane L
##      must be GAP. Otherwise the jump you were told to make drops you onto
##      the thing behind it.
##   5. No full-width chicane — row 0's only gap at one edge and row 1's only
##      gap at the other edge would demand two lane changes in the 0.75 s that
##      15 m buys at top speed, and one change alone takes 0.37 s.
const PATTERNS: Array = [
	# Hold the middle: two dodge-only blockers, one on each edge. A player who
	# keeps still walks through untouched.
	{"name": "centre spine", "min_diff": 0.00, "rows": [[Cell.GAP, Cell.GAP, Cell.ROUND],
		[Cell.ROUND, Cell.GAP, Cell.GAP]]},
	# A duckable with an escape hatch either side: duck it, or go round it.
	{"name": "low bough", "min_diff": 0.00, "rows": [[Cell.GAP, Cell.UNDER, Cell.GAP],
		[Cell.GAP, Cell.GAP, Cell.ROUND]]},
	# Jump timing on its own, with a deliberately empty second row so the
	# airtime always has somewhere safe to land.
	{"name": "lone hurdle", "min_diff": 0.00, "rows": [[Cell.GAP, Cell.HOP, Cell.GAP],
		[Cell.GAP, Cell.GAP, Cell.GAP]]},
	# Pushed off one lane, then asked to leave the one you were pushed into.
	{"name": "two-step", "min_diff": 0.18, "rows": [[Cell.ROUND, Cell.GAP, Cell.GAP],
		[Cell.GAP, Cell.ROUND, Cell.GAP]]},
	# A bank of two hurdles: jump, or take the one open lane.
	{"name": "hurdle bank", "min_diff": 0.38, "rows": [[Cell.HOP, Cell.HOP, Cell.GAP],
		[Cell.GAP, Cell.GAP, Cell.ROUND]]},
	{"name": "duck and slide", "min_diff": 0.38, "rows": [[Cell.GAP, Cell.UNDER, Cell.UNDER],
		[Cell.GAP, Cell.ROUND, Cell.GAP]]},
	# Funnelled into the middle, and then the middle is a duck.
	{"name": "idol funnel", "min_diff": 0.45, "rows": [[Cell.ROUND, Cell.GAP, Cell.ROUND],
		[Cell.GAP, Cell.UNDER, Cell.GAP]]},
	{"name": "push and return", "min_diff": 0.45, "rows": [[Cell.ROUND, Cell.ROUND, Cell.GAP],
		[Cell.GAP, Cell.GAP, Cell.ROUND]]},
	# Jump in the middle, and the middle is the only lane open afterwards.
	{"name": "jump to the spine", "min_diff": 0.60, "rows": [[Cell.GAP, Cell.HOP, Cell.GAP],
		[Cell.ROUND, Cell.GAP, Cell.ROUND]]},
	{"name": "over and under", "min_diff": 0.60, "rows": [[Cell.HOP, Cell.GAP, Cell.GAP],
		[Cell.GAP, Cell.UNDER, Cell.UNDER]]},
]

## How often a piece uses an authored shape instead of rolling its rows
## independently. Not 1.0 on purpose: the random roll is what stops the ten
## shapes becoming recognisable, and a track you can predict is worse than one
## that is merely noisy.
const PATTERN_CHANCE: float = 0.45

## Patterns stay switched off for roughly the first 110 m. That opening stretch
## is where a beginner is still working out which button does what, and it
## should stay as gentle and as unstructured as it has always been.
const PATTERN_MIN_DIFF: float = 0.12

## Which mesh to show, and the collider that goes with it.
##   size/y are the collision box. For the DUCK ones the box deliberately
##   FLOATS: its underside sits at 1.05 m, above a ducking player (0.9 m tall)
##   and below a standing one (1.8 m). That gap IS the mechanic.
const SPEC := {
	# ONE LOOK PER ACTION, and the colliders are the look:
	#   JUMP  — a low wide lump, 0.8 m, bright top (python on a log; boulder)
	#   SLIDE — a gate on two posts, gap to 1.10 m (vines; deadfall)
	#   DODGE — a column up into the canopy (strangler fig 6 m; stela 3.3 m)
	Slot.LOG:    {"node": "Log",    "size": Vector3(2.00, 0.80, 0.70), "y": 0.40},
	Slot.ROCK:   {"node": "Rock",   "size": Vector3(2.00, 0.80, 1.15), "y": 0.40},
	Slot.TREE:   {"node": "Tree",   "size": Vector3(1.30, 6.00, 1.30), "y": 3.00},
	Slot.PILLAR: {"node": "Pillar", "size": Vector3(1.30, 3.30, 1.10), "y": 1.65},
	Slot.VINES:  {"node": "Vines",  "size": Vector3(2.10, 1.80, 0.55), "y": 2.00},
	Slot.BRANCH: {"node": "Branch", "size": Vector3(2.10, 1.50, 0.75), "y": 1.85},
}

## How many rows of obstacles each piece gets.
const ROWS: int = 2

## How far along the piece each row sits (0 = the near edge, negative = ahead).
##
## These are spaced EVENLY — 15 m apart, including across the join to the next
## piece (which starts 30 m further on). The obvious-looking [-8, -20] leaves
## gaps of 12 m and 18 m, and it's the 12 m one that hurts: the time you get to
## react is (smallest gap / speed), so one tight pair sets the difficulty of
## the whole game. Even spacing buys 25% more reaction time for free.
const ROW_Z: Array[float] = [-7.5, -22.5]

## How many scenery objects sit alongside each piece.
const DECOR_COUNT: int = 12

## How many coins each piece can show at once.
const COIN_COUNT: int = 8
## Gap between coins in a run, in metres.
const COIN_SPACING: float = 1.2
## Height of the line of coins threaded under a slide gate: the coin tops sit
## at ~0.8 m, well under the gate's 1.10 m edge.
const UNDER_COIN_Y: float = 0.45

## How high coins float. The player is 1.8 m tall with its feet at 0, so this
## is about chest height — you run straight through them.
const COIN_HEIGHT: float = 0.9
## Where a coin run starts along the piece (it sits between the two obstacle
## rows at -8 and -20, so it never overlaps one).
const COIN_START_Z: float = -10.5
## Where along the piece a magnet sits: midway between the two obstacle rows
## (-7.5 and -22.5), so it is never tangled up in either of them.
const MAGNET_Z: float = -15.0

## The power-up's hover: lifted a little, bobbing, swaying (radians) rather
## than spinning.
const PICKUP_LIFT: float = 0.15
const PICKUP_BOB: float = 0.10
const PICKUP_SWAY: float = 0.6
var _pickup_t: float = 0.0

## How high it floats. Shoulder height on a 1.8 m runner, so you collect it by
## running through it rather than by jumping.
const MAGNET_Y: float = 1.05

## How often a piece carries a power-up of ANY kind. Kept low on purpose: one
## you see every few seconds stops being a power-up and becomes the baseline.
const PICKUP_CHANCE: float = 0.20

## Which kind you get, as cumulative thresholds on one random roll. The shield
## is the most common because it is the one that helps a struggling player, and
## the surge is the rarest because it is worth the most.
const PICKUP_WEIGHTS := {Pickup.SHIELD: 0.32, Pickup.MAGNET: 0.28,
	Pickup.SURGE: 0.20, Pickup.SPRING: 0.20}

## How close a magnetised coin has to get before it counts as collected. The
## pull is fast, so this only has to be big enough that a coin cannot tunnel
## past the player between two frames.
const MAGNET_GRAB: float = 0.9

## The three power-ups. One slot holds all three; only one look is ever shown.
enum Pickup {MAGNET, SHIELD, SURGE, SPRING}

## What job this piece is doing. NORMAL is the ordinary game; the other four
## are the treetop set-piece, dealt in order by the track manager.
##   APPROACH  clear run-in, and the leaf canopy switched off
##   LAUNCH    the trampoline, and the deck starting part-way along
##   DECK      full-length deck, coins, nothing that can hurt you
##   NARROW    the walkway shrinks to a single lane, so you must line up
##   EXIT      a short stub of deck that runs out, dropping you home
enum Role {NORMAL, APPROACH, LAUNCH, DECK, NARROW, EXIT}

## --- THE SKYWAY ---
## These MUST match the constants of the same name in tools/build_scenes.gd.
## That file builds the mesh; this one places the collider.
const DECK_Y: float = 7.0
const DECK_THICK: float = 0.8
const PAD_Z: float = -3.0

## How far PAST the pad the deck's leading edge sits.
##
## This is the one number the whole feature balances on, and it was chosen by
## simulating the real 60 Hz physics loop rather than by algebra. Launched at
## 22 m/s the runner's feet cross 7.00 m somewhere between 5.4 m (at the 12 m/s
## starting speed) and 9.0 m (at the 20 m/s cap) past the pad, and drop back
## through 7.00 m between 14.0 m and 23.3 m past it. So the edge has to sit
## after the LAST of the crossing points and before the FIRST of the landings:
## anywhere in 9.0 .. 14.0. At 11.5 the feet clear the edge by 1.28 m in the
## worst case and 2.12 m in the best, across the entire speed range, with one
## fixed constant and no speed compensation.
const DECK_LEAD: float = 11.5

## How wide the walkway gets on its NARROW stretch: one lane instead of three.
##
## This replaced a hole in the deck, and the reason is worth writing down. A
## hole sounds like the obvious "something to do up here", but it cannot be
## made to work: the runner is 1.80 m tall and the deck is a 0.80 m slab, so
## getting PAST the far edge of a hole means dropping far enough that your HEAD
## clears the slab — about 2.6 m, which is roughly 9 m of travel at the 20 m/s
## cap. No hole that is jumpable at the 12 m/s starting pace (a jump carries
## 8.6 m) is anywhere near that wide, so anyone who missed it was guaranteed to
## slam into the far edge and stop dead. The test bot lost 3-4 m a run to
## exactly that, every run.
##
## Narrowing sideways has none of that problem. Miss this and the walkway ends
## up BESIDE you rather than in front of you, so there is nothing to collide
## with at all — you simply drop to the jungle floor and carry on running.
const NARROW_W: float = LaneConfig.LANE_WIDTH

## How much deck the EXIT piece keeps before it runs out. The drop from 7 m
## takes 0.58 s, which is 7 m of track at the starting speed and 11.6 m at the
## cap — so ending the deck 6 m in puts every landing inside this same piece,
## on ground that is guaranteed clear.
const EXIT_DECK_LEN: float = 6.0

## How hard the trampoline throws you. Gives a 9.12 m apex — measured from the
## engine's own integrator, not from v^2/(2g), which is 18 cm optimistic.
const LAUNCH_SPEED: float = 22.0

## How often a piece lays its coins as a weave between two lanes instead of a
## straight line, when it has two safe lanes to weave between.
##
## This is higher than it looks like it needs to be, because three other
## layouts get first refusal: a treetop deck, a landmark roof, and an arc over
## something jumpable. Only what is left reaches this roll, so at 0.35 a weave
## turned up on 5% of pieces — too rare to be a feature. Measured, not
## guessed: tools/test_track.tscn counts them over 300 rolls.
const ZIGZAG_CHANCE: float = 0.55

## How fast coins spin, in radians per second.
const COIN_SPIN: float = 2.5

## The shape of an arc of coins thrown over a jumpable obstacle.
const ARC_SPAN: float = 7.5      ## metres from first coin to last
const ARC_LOW: float = 0.55      ## height at the ends
const ARC_PEAK: float = 1.65     ## height at the top, just under the jump apex

var _mat_low: StandardMaterial3D = preload("res://materials/obstacle_low.tres")
var _mat_tall: StandardMaterial3D = preload("res://materials/obstacle_tall.tres")

@onready var _obstacles: Node3D = $Obstacles
@onready var _decor: Node3D = $Decor
@onready var _coins: Node3D = $Coins
@onready var _wall: Node3D = $JungleWall
@onready var _understory: Node3D = $Understory
@onready var _landmark: StaticBody3D = $Landmarks/Landmark0
@onready var _pickup: Area3D = $Powerups/Pickup
@onready var _pickup_looks: Node3D = $Powerups/Pickup/Looks
@onready var _pickup_glow: GeometryInstance3D = $Powerups/Pickup/Glow

## The glow's colour for each kind, in Pickup order: magnet, shield (the
## surf plank), surge, spring. One colour per power-up, used everywhere that
## power-up appears.
const GLOW_TINT := [Color(1.0, 0.42, 0.36), Color(0.25, 0.45, 1.0),
	Color(0.86, 0.52, 1.0), Color(0.46, 0.95, 1.0)]

## Which power-up this piece is currently carrying.
var pickup_kind: Pickup = Pickup.MAGNET

## What job this piece is doing this time round.
var role: Role = Role.NORMAL

@onready var _canopy: Node3D = $Canopy
@onready var _deck: StaticBody3D = $Skyway/Deck
@onready var _deck_mesh: MeshInstance3D = $Skyway/Deck/Mesh
@onready var _deck_col: CollisionShape3D = $Skyway/Deck/CollisionShape3D
@onready var _crowns: MeshInstance3D = $Skyway/Crowns
@onready var _pad: Area3D = $Skyway/Pad

## Cached once, lazily — the player does not exist yet while chunks are being
## built, so this cannot be an @onready.
var _player: Node3D = null

## Which lane the landmark is in this round, or -1 for none. The obstacle rows
## read this so they never drop something inside it.
var landmark_lane: int = -1

## Which authored shape this piece is using, or "" when its rows were rolled
## independently. Exists so a test can say which shape it is looking at.
var pattern_name: String = ""

## Whether that shape was flipped left-to-right this time.
var pattern_mirrored: bool = false

## Lanes this piece ends with something jumpable in. The next piece must leave
## these lanes clear in its first row — see _clear_landing_lanes.
var jump_exit_lanes: Array[int] = []

## While a landmark is present, ONE other lane is kept clear for its whole
## length. This is not belt-and-braces, it is required: a landmark in the
## MIDDLE lane cuts the two outer lanes off from each other for 16 m, so if
## one row blocked the left and another blocked the right the run would be
## flatly impossible — you cannot cross through a wall. Reserving a lane makes
## a continuous path exist by construction, wherever the landmark sits.
var landmark_safe_lane: int = -1


func _ready() -> void:
	# Give every obstacle its OWN mesh and collision shape.
	#
	# This matters more than it looks. When Godot saves a scene it may store one
	# shared copy of two identical resources — so all six obstacles could end up
	# pointing at the SAME BoxShape3D. Resize one and you'd silently resize all
	# six. duplicate() breaks that sharing once, at startup, and makes the
	# pooling below safe no matter how the scene was saved.
	for ob in _obstacles.get_children():
		var col: CollisionShape3D = ob.get_node("CollisionShape3D")
		col.shape = col.shape.duplicate()

	# Wire up the coins ONCE. Connections survive the piece being moved and
	# re-rolled, so there's never any need to reconnect them later.
	for coin in _coins.get_children():
		coin.body_entered.connect(_on_coin_touched.bind(coin))
	_pickup.body_entered.connect(_on_pickup_touched)
	_pad.body_entered.connect(_on_pad_touched)
	# Same reason the obstacles do it: a saved scene may store ONE shared copy
	# of two identical resources, and all nine pooled pieces would then be
	# resizing each other's deck.
	_deck_col.shape = _deck_col.shape.duplicate()


## Re-rolls this piece's contents. Called every time the piece is recycled.
##   rng        — the manager's random number generator (shared, so a given
##                seed always produces the same track)
##   difficulty — 0.0 at the start of a run, rising toward 1.0
##   safe       — true for the first couple of pieces, so the player isn't
##                hit by an obstacle before the game has even started
func randomise(rng: RandomNumberGenerator, difficulty: float, safe: bool,
		allow_landmark: bool = true, piece_role: Role = Role.NORMAL,
		avoid_pattern: String = "", entry_block: Array = [],
		forced_rows: Array = []) -> void:
	role = piece_role
	_apply_role()
	# Every piece of the set-piece is "quiet": no obstacles, no landmark, no
	# power-up. The treetop run is a rest, and the approach to it has to be
	# clear too — being killed on the run-up to a reward is miserable.
	var quiet: bool = role != Role.NORMAL
	_place_landmark(rng, difficulty, safe or quiet, allow_landmark and not quiet)
	var lesson: bool = not forced_rows.is_empty() and not (safe or quiet)
	var rows := _place_obstacles(rng, difficulty, safe or quiet, avoid_pattern,
		entry_block, forced_rows if lesson else [])
	_place_coins(rng, rows)
	_place_pickup(rng, rows, safe or quiet or lesson)
	_place_decor(rng)
	_shuffle_wall(rng)
	_shuffle_understory(rng)
	# This piece just teleported from behind the player to the far distance.
	# Physics interpolation would otherwise try to SMOOTH that jump and smear
	# the piece across the screen for one frame. This says "that wasn't
	# movement, it was a teleport".
	reset_physics_interpolation()


## Runs on the PHYSICS tick, not the render tick. Everything else the piece
## owns moves on physics and is then smoothed by physics interpolation; spinning
## the coins on the render frame instead meant they were the one thing in the
## scene stepping to a different clock.
func _physics_process(delta: float) -> void:
	# A slowly turning coin catches the light and reads as "pick me up"
	# far better than a static disc does.
	var spin := COIN_SPIN * delta
	for coin in _coins.get_children():
		if coin.visible:
			coin.rotate_y(spin)
	if _pickup.visible:
		# Bob and sway, never spin. A spin puts a flat horseshoe or plank
		# edge-on — a 2 px sliver — for 40% of every turn, and it is the same
		# motion the coins make. A bob with a gentle side-to-side sway always
		# shows at least 83% of the face and moves like nothing else on the
		# track, which is half of what says "this one is special".
		_pickup_t += delta
		_pickup_looks.position.y = PICKUP_LIFT + PICKUP_BOB * sin(_pickup_t * 3.4)
		_pickup_looks.rotation.y = PICKUP_SWAY * sin(_pickup_t * 2.1)
		_pickup_glow.position.y = _pickup_looks.position.y
	if GameState.magnet_active():
		_pull_coins(delta)


# -----------------------------------------------------------------------------
#  THE SKYWAY
# -----------------------------------------------------------------------------

## Shows the parts of the treetop set-piece this piece's role calls for, and
## sizes the deck to match. Nothing is created here — every piece already owns
## a full-length deck, a set of crowns and a pad, and this just reveals and
## reshapes them.
func _apply_role() -> void:
	var on_deck: bool = role == Role.LAUNCH or role == Role.DECK \
			or role == Role.NARROW or role == Role.EXIT

	# The decorative leaf canopy goes off for the WHOLE sequence, APPROACH
	# included. That is not tidiness: _build_canopy runs from z +8 down to
	# -(length + 14), so every piece's leaves overhang roughly 16 m into the
	# piece in front of it. Leave the approach piece's canopy on and the runner
	# launches straight up through the previous piece's foliage.
	_canopy.visible = role == Role.NORMAL
	_crowns.visible = on_deck
	_deck.visible = on_deck
	_deck_col.set_deferred("disabled", not on_deck)
	_set_pad_active(role == Role.LAUNCH)

	if not on_deck:
		return

	# Where this piece's deck starts, and how long it is. The mesh is built at
	# full chunk length running 0 .. -L, so a shorter deck is the same mesh
	# scaled down the Z axis and slid back to where it should begin.
	var start_z: float = 0.0
	var deck_len: float = LaneConfig.CHUNK_LENGTH
	if role == Role.LAUNCH:
		start_z = PAD_Z - DECK_LEAD
		deck_len = LaneConfig.CHUNK_LENGTH + start_z
	elif role == Role.EXIT:
		deck_len = EXIT_DECK_LEN

	# The NARROW stretch is the same deck squeezed sideways to one lane. Same
	# mesh, same collider, same node — only the X scale differs.
	var width: float = NARROW_W if role == Role.NARROW else LaneConfig.TRACK_WIDTH
	_deck_mesh.position.z = start_z
	_deck_mesh.scale = Vector3(width / LaneConfig.TRACK_WIDTH, 1.0,
		deck_len / LaneConfig.CHUNK_LENGTH)
	_deck_col.position.z = start_z - deck_len * 0.5
	var box: BoxShape3D = _deck_col.shape
	box.size.z = deck_len
	box.size.x = width


## Where this piece's deck begins, in local Z. Used to lay the coins.
func deck_start_z() -> float:
	return PAD_Z - DECK_LEAD if role == Role.LAUNCH else 0.0


func _set_pad_active(active: bool) -> void:
	_pad.visible = active
	_pad.set_deferred("monitoring", active)


## The bounce. Note this calls player.launch() rather than writing velocity
## directly: the player has to defend the launch from its own jump buffer, and
## it can only do that if it knows a launch happened.
func _on_pad_touched(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not _pad.visible:
		return
	_set_pad_active(false)
	body.launch(LAUNCH_SPEED)


# -----------------------------------------------------------------------------
#  POWER-UPS
# -----------------------------------------------------------------------------

## Drags every visible coin on this piece toward the player, and banks the ones
## that reach them.
##
## The pull runs from the CHUNK rather than from the player because the coins
## live here — a coin is a child of the piece it was laid out on, so this is
## the only place that can move one without reaching across the scene tree.
func _pull_coins(delta: float) -> void:
	# is_instance_valid, not just null: on a restart the old player is freed
	# while this chunk may still be holding a reference to it, and reading
	# global_position off a freed node is a crash rather than a null.
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var target := _player.global_position + Vector3(0.0, 0.7, 0.0)
	for child in _coins.get_children():
		var coin: Area3D = child
		if not coin.visible:
			continue
		var delta_v := target - coin.global_position
		var dist := delta_v.length()
		if dist > GameState.MAGNET_RANGE:
			continue
		if dist <= MAGNET_GRAB:
			_set_coin_active(coin, false)
			GameState.collect_coin()
			continue
		# Accelerate as it closes, so coins arrive in a stream rather than a
		# clump — and so a coin at the edge of range doesn't snap instantly.
		var speed: float = GameState.MAGNET_PULL * (1.0 + (1.0 - dist / GameState.MAGNET_RANGE))
		coin.global_position += delta_v / dist * minf(speed * delta, dist)


## Decides whether this piece carries a power-up, which one, and where.
func _place_pickup(rng: RandomNumberGenerator, rows: Array, safe: bool) -> void:
	# Never on the opening pieces. The first thing you learn should be the
	# controls, not a power-up you don't have the vocabulary for yet.
	if safe or rng.randf() > PICKUP_CHANCE:
		_set_pickup_active(false)
		return
	# Put it in a lane that is CLEAR in the row it sits next to, for the same
	# reason the coins do it: a reward you cannot reach without dying is a
	# punishment. _clear_lanes is what the coin placer already trusts.
	var lanes := _clear_lanes(rows, 1)
	if lanes.is_empty():
		lanes = _clear_lanes(rows, 0)
	if lanes.is_empty():
		_set_pickup_active(false)
		return
	# Prefer a lane with no coins running through the pickup's spot: in a
	# coin line a power-up is just one more gold thing among twenty.
	var open_lanes: Array[int] = []
	for l in lanes:
		var busy := false
		for coin in _coins.get_children():
			if coin.visible and absf(coin.position.x - LaneConfig.lane_to_x(l)) < 0.5 \
					and absf(coin.position.z - MAGNET_Z) < 6.0:
				busy = true
				break
		if not busy:
			open_lanes.append(l)
	if not open_lanes.is_empty():
		lanes = open_lanes
	var lane: int = lanes[rng.randi_range(0, lanes.size() - 1)]
	pickup_kind = _roll_pickup_kind(rng)
	var px := LaneConfig.lane_to_x(lane)
	_pickup.position = Vector3(px, MAGNET_Y, MAGNET_Z)
	_pickup.rotation.y = 0.0
	_pickup_t = rng.randf() * TAU
	# And clear a 4 m gap in any coin line that does run through it, so the
	# power-up is framed by empty air rather than buried.
	for coin in _coins.get_children():
		if absf(coin.position.x - px) < 0.5 and absf(coin.position.z - MAGNET_Z) < 2.0:
			_set_coin_active(coin, false)
	_set_pickup_active(true)


## Picks a kind from PICKUP_WEIGHTS with a single random draw. Walking the
## dictionary keeps the weights and the choice in one place, so adding a fourth
## power-up later means editing the table and nothing else.
func _roll_pickup_kind(rng: RandomNumberGenerator) -> Pickup:
	var roll := rng.randf()
	var running := 0.0
	for kind in PICKUP_WEIGHTS:
		running += PICKUP_WEIGHTS[kind]
		if roll <= running:
			return kind
	return Pickup.MAGNET


## Which lanes are EMPTY in a given obstacle row. Shared by the magnet and
## (in spirit) the coin placer: a reward you cannot reach without dying is a
## punishment, so both only ever use lanes that something isn't already in.
func _clear_lanes(rows: Array, row: int) -> Array[int]:
	var out: Array[int] = []
	if row >= rows.size():
		return out
	var pattern: Array = rows[row]
	for lane in LaneConfig.LANE_COUNT:
		# The landmark lane is excluded even when the rows say it is empty:
		# there is a 16 m solid object sitting in it, and the magnet would end
		# up buried inside the log.
		if lane == landmark_lane:
			continue
		if pattern[lane] == Slot.EMPTY:
			out.append(lane)
	return out


func _set_pickup_active(active: bool) -> void:
	_pickup.visible = active
	_pickup.set_deferred("monitoring", active)
	# Show only the look that matches the kind. Done here rather than in
	# _place_pickup so that switching the slot off hides all three.
	for i in _pickup_looks.get_child_count():
		var look: Node3D = _pickup_looks.get_child(i)
		look.visible = active and i == int(pickup_kind)
	if active:
		_pickup_glow.set_instance_shader_parameter("tint", GLOW_TINT[int(pickup_kind)])


func _on_pickup_touched(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	# `monitoring` is turned off deferred, so this can fire twice in the same
	# frame. `visible` flips immediately, which makes it the reliable guard.
	if not _pickup.visible:
		return
	var kind := pickup_kind
	_set_pickup_active(false)
	match kind:
		Pickup.MAGNET:
			GameState.start_magnet()
		Pickup.SHIELD:
			GameState.give_shield()
		Pickup.SURGE:
			GameState.start_surge()
		Pickup.SPRING:
			GameState.start_spring()


# -----------------------------------------------------------------------------
#  OBSTACLES
# -----------------------------------------------------------------------------

## Puts a landmark in a lane, or clears it. Sets `landmark_lane`, which the
## obstacle rows then treat as already taken.
func _place_landmark(rng: RandomNumberGenerator, difficulty: float, safe: bool,
		allowed: bool) -> void:
	landmark_lane = -1
	landmark_safe_lane = -1
	var show_it := false
	if allowed and not safe and rng.randf() < LANDMARK_CHANCE:
		# EDGE LANES ONLY. A landmark in the MIDDLE lane cuts the two outer
		# lanes off from each other for its whole 16 m: a player caught in the
		# wrong outer lane with anything in front of them is dead with no
		# counterplay, because reaching the safe lane means crossing a wall.
		# Reserving a through-lane is not enough — it guarantees a safe lane
		# EXISTS, not that you can get to it. Keeping landmarks on an edge
		# leaves the other two lanes adjacent, so you can always cross.
		landmark_lane = 0 if rng.randf() < 0.5 else LaneConfig.LANE_COUNT - 1
		# Reserve one of the other lanes as a guaranteed way past.
		var others: Array[int] = []
		for i in LaneConfig.LANE_COUNT:
			if i != landmark_lane:
				others.append(i)
		landmark_safe_lane = others[rng.randi_range(0, others.size() - 1)]
		show_it = true

	for child in _landmark.get_children():
		if child is MeshInstance3D:
			child.visible = false

	var col: CollisionShape3D = _landmark.get_node("CollisionShape3D")
	if not show_it:
		_landmark.visible = false
		col.set_deferred("disabled", true)
		return

	var which: String = "FallenGiant" if rng.randf() < 0.6 else "RuinWall"
	_landmark.set_meta(&"what", "fallen giant" if which == "FallenGiant" else "temple wall")
	var mesh: MeshInstance3D = _landmark.get_node_or_null(which)
	if mesh != null:
		mesh.visible = true
	_landmark.position = Vector3(LaneConfig.lane_to_x(landmark_lane), 0.0, LANDMARK_START_Z)
	_landmark.visible = true
	col.set_deferred("disabled", false)


## Fills in the obstacle rows, and hands back what it rolled so the coin
## placement can steer the player somewhere safe.
func _place_obstacles(rng: RandomNumberGenerator, difficulty: float, safe: bool,
		avoid_pattern: String, entry_block: Array, forced_rows: Array = []) -> Array:
	var slot_index := 0
	var rows: Array = []
	if not forced_rows.is_empty():
		# A lesson. Rows are rebuilt as TYPED arrays: a const row dropped into
		# an Array[int] variable is a runtime error.
		for src in forced_rows:
			var r: Array[int] = []
			r.assign(src)
			rows.append(r)
		pattern_name = "lesson"
		pattern_mirrored = false
	else:
		rows = _pick_pattern(rng, difficulty, safe, avoid_pattern)
	if rows.is_empty():
		# No pattern this time: roll the rows independently, exactly as the
		# game always has. This path is untouched on purpose — when a pattern
		# does not fire, the piece is generated by the same code, with the same
		# difficulty curve and the same draws, as it was before patterns
		# existed at all.
		for row in ROWS:
			rows.append(_roll_row(rng, difficulty, safe))

	_clear_landing_lanes(rows, entry_block)

	for row in ROWS:
		var pattern: Array[int] = rows[row]
		for lane in LaneConfig.LANE_COUNT:
			var ob: StaticBody3D = _obstacles.get_child(slot_index)
			slot_index += 1
			_apply_slot(ob, pattern[lane], LaneConfig.lane_to_x(lane), ROW_Z[row])

	# Any leftover pool entries (if LANE_COUNT changed) get switched off.
	while slot_index < _obstacles.get_child_count():
		_apply_slot(_obstacles.get_child(slot_index), Slot.EMPTY, 0.0, 0.0)
		slot_index += 1

	return rows


## THE LANDING GUARANTEE — the single most important fairness rule here.
##
## A jump is 0.717 s in the air, which at the 20 m/s cap carries you 14.3 m.
## The rows are 15 m apart. So you land 0.7 m before the next row — thirty-five
## THOUSANDTHS of a second before it — and if the key was held you are still in
## the air when you arrive. You cannot duck in mid-air (the duck key slams you
## down instead) and you cannot change lane in 0.035 s.
##
## So anything sitting in the lane you jumped from is unavoidable. Not hard:
## unavoidable. The authored patterns already forbid it, but they are only
## about half the pieces, and the randomly rolled half had no such rule — which
## is exactly why jumping felt like it had no margin for error. It did not have
## a narrow margin, it had none at all.
##
## The fix is to clear the landing lane, and it has to work across the piece
## boundary too: a jumpable in the LAST row is 15 m from the NEXT piece's first
## row, which is the same trap. Pieces cannot see each other — they live in a
## recycled ring — so the manager carries the lanes forward in `entry_block`.
func _clear_landing_lanes(rows: Array, entry_block: Array) -> void:
	# Anything the previous piece jumped into cannot be blocked here.
	for lane in entry_block:
		rows[0][lane] = Slot.EMPTY

	# And within this piece, a jump in one row clears the same lane in the next.
	for row in range(ROWS - 1):
		for lane in LaneConfig.LANE_COUNT:
			if JUMPABLE.has(rows[row][lane]):
				rows[row + 1][lane] = Slot.EMPTY

	# Finally, remember what the NEXT piece has to keep clear.
	jump_exit_lanes = []
	for lane in LaneConfig.LANE_COUNT:
		if JUMPABLE.has(rows[ROWS - 1][lane]):
			jump_exit_lanes.append(lane)


## Chooses an authored shape for this piece, or returns an empty Array meaning
## "roll the rows the old way".
##
## The bail-outs are in a deliberate order, cheapest and most important first:
##
##   safe           — the opening pieces and the whole treetop set-piece are
##                    meant to be empty, and `safe` already covers both.
##   a landmark     — a landmark is 16 m of solid object in one lane for most
##                    of the piece. An authored shape knows nothing about it,
##                    and the two together could close a lane the pattern was
##                    relying on. Patterns simply stand aside.
##   too early      — see PATTERN_MIN_DIFF.
##
## Only after all three does it spend a random draw, so early pieces consume
## exactly the same numbers from the generator as they always did.
func _pick_pattern(rng: RandomNumberGenerator, difficulty: float,
		safe: bool, avoid: String) -> Array:
	if safe or landmark_lane >= 0 or difficulty < PATTERN_MIN_DIFF:
		pattern_name = ""
		return []
	if rng.randf() > PATTERN_CHANCE:
		pattern_name = ""
		return []

	# Only the shapes unlocked at this difficulty, and never the one the piece
	# before used — two identical shapes in a row is the fastest way to make ten
	# authored patterns feel like one.
	var eligible: Array = []
	for candidate in PATTERNS:
		if float(candidate["min_diff"]) > difficulty:
			continue
		if avoid != "" and String(candidate["name"]) == avoid:
			continue
		eligible.append(candidate)
	if eligible.is_empty():
		pattern_name = ""
		return []

	var entry: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)]
	# Mirrored half the time, which doubles the shapes for nothing. Safe
	# because nothing about the track or the runner is left-right asymmetric.
	var mirror: bool = rng.randf() < 0.5
	# The stored name deliberately excludes the mirror flag. A shape and its
	# mirror are the same shape to a player, so letting "spine" follow
	# "spine (mirrored)" would defeat the point of the check above.
	pattern_name = entry["name"]
	if mirror:
		pattern_mirrored = true
	else:
		pattern_mirrored = false

	var out: Array = []
	for row in ROWS:
		var cells: Array = entry["rows"][row]
		# duplicate(), never in place: PATTERNS is a const, and writing to it
		# would either raise a read-only error or — worse — permanently rewrite
		# the table for every future piece.
		var lane_slots: Array[int] = []
		for lane in LaneConfig.LANE_COUNT:
			var src: int = LaneConfig.LANE_COUNT - 1 - lane if mirror else lane
			lane_slots.append(_cell_to_slot(cells[src], rng, difficulty))
		out.append(lane_slots)
	return out


## Turns a pattern cell into an actual obstacle, picking the look at random
## from the family the cell names.
func _cell_to_slot(cell: int, rng: RandomNumberGenerator, difficulty: float = 1.0) -> int:
	match cell:
		Cell.HOP:
			return _look(JUMPABLE, rng, difficulty)
		Cell.ROUND:
			return _look(DODGEABLE, rng, difficulty)
		Cell.UNDER:
			return _look(DUCKABLE, rng, difficulty)
	return Slot.EMPTY


## Picks one look from a family. Early in a run it is always the standard
## one; the draw still happens either way so a seeded track keeps its shape.
func _look(family: Array[int], rng: RandomNumberGenerator, difficulty: float) -> int:
	var idx := rng.randi_range(0, family.size() - 1)
	return family[0] if difficulty < CANONICAL_UNTIL else family[idx]


## Decides what goes in each lane for ONE row.
## The golden rule: never block every lane. There is ALWAYS a way through.
func _roll_row(rng: RandomNumberGenerator, difficulty: float, safe: bool) -> Array[int]:
	var pattern: Array[int] = []
	for i in LaneConfig.LANE_COUNT:
		pattern.append(Slot.EMPTY)

	if safe:
		return pattern

	var max_blocked := 1 if difficulty < 0.35 else 2
	# LANE_COUNT - 1 is the hard ceiling: at least one lane stays open, always.
	max_blocked = mini(max_blocked, LaneConfig.LANE_COUNT - 1)

	# A landmark eats a whole lane for 16 m, so it counts as one of the blocked
	# lanes for EVERY row it spans. Without this the rows would happily block
	# both remaining lanes and the run becomes impossible.
	var lanes: Array[int] = []
	for i in LaneConfig.LANE_COUNT:
		if i != landmark_lane and i != landmark_safe_lane:
			lanes.append(i)
	max_blocked = mini(max_blocked, lanes.size())
	if max_blocked < 1 or lanes.is_empty():
		return pattern

	var blocked := rng.randi_range(1, max_blocked)
	_shuffle(lanes, rng)

	for i in blocked:
		pattern[lanes[i]] = _roll_kind(rng, difficulty)

	return pattern


## Picks which obstacle to use. Early on it is mostly things you can jump,
## because jumping is the first thing a player learns. Ducking and the
## dodge-only blockers come in as the run gets harder.
func _roll_kind(rng: RandomNumberGenerator, difficulty: float) -> int:
	var roll := rng.randf()
	var duck_chance := 0.10 + 0.25 * difficulty
	var dodge_chance := 0.20 + 0.20 * difficulty

	if roll < duck_chance:
		return _look(DUCKABLE, rng, difficulty)
	if roll < duck_chance + dodge_chance:
		return _look(DODGEABLE, rng, difficulty)
	return _look(JUMPABLE, rng, difficulty)


## Sets one obstacle up, or switches it off entirely.
func _apply_slot(ob: StaticBody3D, slot: int, x: float, z: float) -> void:
	var col: CollisionShape3D = ob.get_node("CollisionShape3D")
	# What this obstacle is, for the coach and for "why did I die". A meta
	# rather than a property, so the saved scene's format does not change.
	ob.set_meta(&"slot", slot)

	# Hide every variant first, then reveal the one we want. Hidden meshes
	# cost nothing to draw, so carrying all six in each slot is cheap.
	#
	# The `if mesh.visible` guard is not tidiness. Writing `visible` tells the
	# renderer to re-evaluate that instance whether or not the value changed,
	# and this loop runs six times for each of six slots on every recycle — 36
	# writes a piece, of which at most one or two are real changes. Recycles
	# happen about every second and a half, which is exactly the rhythm a
	# player reports as "a slight lag every second".
	for spec in SPEC.values():
		var mesh: Node3D = ob.get_node_or_null(spec["node"])
		if mesh != null and mesh.visible:
			mesh.visible = false

	if slot == Slot.EMPTY or not SPEC.has(slot):
		ob.visible = false
		# Hiding does NOT stop it colliding — visible = false at any level
		# leaves it lethally solid and invisible. Only `disabled` turns it off.
		# Deferred because this can be reached from a collision signal.
		#
		#
		# NOT guarded with `if not col.disabled`, even though skipping the
		# redundant ones looked like free performance. Reading `disabled` to
		# decide whether to set it is a trap: a deferred write has not LANDED
		# yet, so the read returns the stale value. Call randomise() twice
		# before the frame ends — which the track manager does when it builds
		# all nine pieces at once — and the second call sees the old state,
		# skips, and the first call's pending write wins. The result is an
		# obstacle that is invisible and still lethal. test_track caught this.
		col.set_deferred("disabled", true)
		return

	var spec: Dictionary = SPEC[slot]
	var shown: Node3D = ob.get_node_or_null(spec["node"])
	if shown != null:
		shown.visible = true

	(col.shape as BoxShape3D).size = spec["size"]
	col.position.y = spec["y"]

	ob.position = Vector3(x, 0.0, z)
	ob.visible = true
	col.set_deferred("disabled", false)


## The jungle wall mesh is longer than the piece it sits on, so sliding it
## along z (and occasionally mirroring it) makes each piece's backdrop look
## different. Without this you'd see the same lumps repeat every 30 metres.
func _shuffle_wall(rng: RandomNumberGenerator) -> void:
	if _wall == null:
		return
	_wall.position.z = rng.randf_range(-7.0, 7.0)
	_wall.scale.x = -1.0 if rng.randf() < 0.5 else 1.0
	_pick_variant(_wall, rng)


## The scenery layers each carry several differently-seeded looks as hidden
## children. This shows exactly one. Combined with the slide and the mirror
## above, that is enough combinations that the 30 m repeat stops being
## findable — which it very much was with a single strip.
func _pick_variant(layer: Node3D, rng: RandomNumberGenerator) -> void:
	var variants := layer.get_children()
	if variants.size() <= 1:
		return
	var chosen := rng.randi_range(0, variants.size() - 1)
	for i in variants.size():
		(variants[i] as Node3D).visible = i == chosen


func _shuffle_understory(rng: RandomNumberGenerator) -> void:
	if _understory == null:
		return
	_understory.position.z = rng.randf_range(-6.0, 6.0)
	_understory.scale.x = -1.0 if rng.randf() < 0.5 else 1.0
	_pick_variant(_understory, rng)


# -----------------------------------------------------------------------------
#  COINS
# -----------------------------------------------------------------------------

## Lays out a run of coins. The lane is chosen from the lanes that are CLEAR in
## the second obstacle row — so following the coins leads you somewhere safe
## rather than straight into a block. Greed and survival point the same way.
func _place_coins(rng: RandomNumberGenerator, rows: Array) -> void:
	var safe_lanes: Array[int] = []
	if rows.size() >= ROWS:
		var last_row: Array = rows[ROWS - 1]
		for lane in LaneConfig.LANE_COUNT:
			if last_row[lane] == Slot.EMPTY:
				safe_lanes.append(lane)
	if safe_lanes.is_empty():
		for lane in LaneConfig.LANE_COUNT:
			safe_lanes.append(lane)

	# If the FIRST row has something jumpable in it, arc the coins over that
	# instead of laying them flat somewhere safe. This is the Subway Surfers
	# trick: the reward sits on the path the obstacle already forces you onto,
	# so jumping well and collecting well are the same action.
	var arc_lane := -1
	if rows.size() > 0:
		var first: Array = rows[0]
		for lane_i in LaneConfig.LANE_COUNT:
			if JUMPABLE.has(first[lane_i]):
				arc_lane = lane_i
				break

	# On the treetops the coins ARE the content — there is nothing else up
	# there — so they run the whole length of the deck rather than a short
	# stretch of one lane.
	if role == Role.LAUNCH or role == Role.DECK or role == Role.NARROW \
			or role == Role.EXIT:
		# On the narrow stretch the coins go down the middle, because there is
		# only one lane to be in and the coins are how you learn that before
		# you arrive rather than after.
		var deck_lane: int = LaneConfig.LANE_COUNT / 2 if role == Role.NARROW \
			else rng.randi_range(0, LaneConfig.LANE_COUNT - 1)
		_place_coin_run(deck_lane, rng, DECK_Y + COIN_HEIGHT, deck_start_z() - 2.0)
		return

	# Riding a landmark should PAY. Running the coins along its roof turns it
	# from an obstacle you avoid into a route you choose.
	if landmark_lane >= 0:
		_place_coin_run(landmark_lane, rng, LANDMARK_TOP + COIN_HEIGHT,
			LANDMARK_START_Z - 1.5)
		return

	if arc_lane >= 0:
		_place_coin_arc(arc_lane, rng)
		return

	# A slide gate in the first row: thread a low line of coins THROUGH it.
	# From a distance the gold running under the gate is the proof that the
	# gap is open — it is how the game this is modelled on teaches the slide.
	if rows.size() > 0:
		var first_row: Array = rows[0]
		for lane_i in LaneConfig.LANE_COUNT:
			if DUCKABLE.has(first_row[lane_i]):
				_place_coin_run(lane_i, rng, UNDER_COIN_Y, ROW_Z[0] + 4.2)
				return

	# A weave between two lanes, when there are two to weave between. Coins are
	# the only thing in the game that ASKS you to move rather than forcing you
	# to, so a line that changes lane is the one bit of level design here that
	# is purely an invitation.
	if safe_lanes.size() >= 2 and rng.randf() < ZIGZAG_CHANCE:
		_place_coin_zigzag(safe_lanes, rng)
		return

	var lane: int = safe_lanes[rng.randi_range(0, safe_lanes.size() - 1)]
	var x := LaneConfig.lane_to_x(lane)
	# Not every piece gets a full run — variety stops it feeling mechanical.
	var count := rng.randi_range(0, COIN_COUNT)

	for i in _coins.get_child_count():
		var coin: Area3D = _coins.get_child(i)
		if i < count:
			coin.position = Vector3(x, COIN_HEIGHT, COIN_START_Z - float(i) * COIN_SPACING)
			coin.rotation.y = 0.0
			_set_coin_active(coin, true)
		else:
			_set_coin_active(coin, false)


## Two lanes, alternating every second coin.
##
## Two coins per lane is not arbitrary. At the 20 m/s cap two coins is 4 m,
## which is 0.2 s — almost exactly how long a lane change takes — so the weave
## is continuous rather than a series of stops. Any tighter and it would ask
## for a lane change you cannot finish; any looser and it stops being a weave.
##
## Both lanes are taken from the SAFE list, so a weave can never lead you into
## something. Following the coins is always the right move.
func _place_coin_zigzag(lanes: Array[int], rng: RandomNumberGenerator) -> void:
	var a: int = lanes[rng.randi_range(0, lanes.size() - 1)]
	var b: int = a
	while b == a:
		b = lanes[rng.randi_range(0, lanes.size() - 1)]

	for i in _coins.get_child_count():
		var coin: Area3D = _coins.get_child(i)
		var lane: int = a if int(i / 2) % 2 == 0 else b
		coin.position = Vector3(LaneConfig.lane_to_x(lane), COIN_HEIGHT,
			COIN_START_Z - float(i) * COIN_SPACING)
		coin.rotation.y = 0.0
		_set_coin_active(coin, true)


## A straight line of coins at a fixed height — used along a landmark's roof.
func _place_coin_run(lane: int, rng: RandomNumberGenerator, y: float,
		start_z: float) -> void:
	var x := LaneConfig.lane_to_x(lane)
	for i in _coins.get_child_count():
		var coin: Area3D = _coins.get_child(i)
		coin.position = Vector3(x, y, start_z - float(i) * COIN_SPACING)
		coin.rotation.y = 0.0
		_set_coin_active(coin, true)


## Lays the coins in a jump-shaped arc centred on the first obstacle row.
func _place_coin_arc(lane: int, rng: RandomNumberGenerator) -> void:
	var x := LaneConfig.lane_to_x(lane)
	var centre_z: float = ROW_Z[0]
	var count: int = _coins.get_child_count()
	var span := ARC_SPAN
	for i in count:
		var coin: Area3D = _coins.get_child(i)
		var t: float = float(i) / float(maxi(count - 1, 1))      # 0 .. 1
		var z: float = centre_z + span * 0.5 - span * t
		# A half sine is close enough to the real jump parabola at these
		# speeds, and unlike a parabola it lands neatly at both ends.
		var y: float = ARC_LOW + (ARC_PEAK - ARC_LOW) * sin(PI * t)
		coin.position = Vector3(x, y, z)
		coin.rotation.y = 0.0
		_set_coin_active(coin, true)


## Switches a coin on or off.
func _set_coin_active(coin: Area3D, active: bool) -> void:
	if coin.visible == active:
		return
	coin.visible = active
	# `monitoring` is what actually stops an Area3D noticing the player —
	# hiding it does nothing, exactly like CollisionShape3D.disabled for solid
	# obstacles. set_deferred because this also gets called from INSIDE the
	# body_entered handler below, and Godot refuses a direct change while it
	# is still working through collisions.
	coin.set_deferred("monitoring", active)


func _on_coin_touched(body: Node3D, coin: Area3D) -> void:
	# The ground and the obstacles are physics bodies too, and a coin sitting
	# near them would happily report those. Only the player counts.
	if not body.is_in_group("player"):
		return
	# `monitoring` is turned off deferred, so this can fire twice in the same
	# frame. `visible` flips immediately, which makes it the reliable guard.
	if not coin.visible:
		return
	_set_coin_active(coin, false)
	GameState.collect_coin()


# -----------------------------------------------------------------------------
#  SCENERY
# -----------------------------------------------------------------------------

func _place_decor(rng: RandomNumberGenerator) -> void:
	var edge := LaneConfig.TRACK_WIDTH * 0.5

	for i in _decor.get_child_count():
		var d: Node3D = _decor.get_child(i)
		# Alternate sides so both verges stay populated.
		var side := 1.0 if i % 2 == 0 else -1.0
		d.position = Vector3(
			side * (edge + rng.randf_range(1.2, 9.0)),
			-0.02,   # stand on the jungle floor, which sits just below the track
			rng.randf_range(-LaneConfig.CHUNK_LENGTH + 0.5, -0.5)
		)
		d.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(0.75, 1.45)
		d.scale = Vector3(s, rng.randf_range(0.8, 1.3) * s, s)


## Fisher-Yates shuffle. RandomNumberGenerator has no shuffle() of its own, and
## Array.shuffle() uses Godot's GLOBAL random instead of our seeded one — which
## would break the "same seed gives the same track" guarantee.
func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## "jump", "duck" or "dodge" for an obstacle kind; "" for none.
static func family_of(slot: int) -> String:
	if JUMPABLE.has(slot):
		return "jump"
	if DUCKABLE.has(slot):
		return "duck"
	if DODGEABLE.has(slot):
		return "dodge"
	return ""
