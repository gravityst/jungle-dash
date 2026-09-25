class_name LaneConfig
extends RefCounted
## THE SINGLE SOURCE OF TRUTH FOR LANE GEOMETRY.
##
## The player and the track both read their lane positions from here, so they
## can never disagree. If you want wider lanes or a 5-lane game, change the
## numbers in THIS FILE ONLY — everything else follows automatically.
##
## You never add this script to a node. It's just a shared box of numbers,
## used like `LaneConfig.LANE_WIDTH` or `LaneConfig.lane_to_x(2)`.


## How many lanes. 3 = left, centre, right. Try 5 if you're feeling brave —
## the track, the player and the obstacle spawner all adapt on their own.
const LANE_COUNT: int = 3

## Distance between the centre of one lane and the next, in metres.
const LANE_WIDTH: float = 2.5

## Extra ground beyond the outermost lanes, so the track doesn't end exactly
## at the player's shoulder. Purely cosmetic.
const SHOULDER: float = 0.8

## Total width of the ground mesh. Worked out from the numbers above.
const TRACK_WIDTH: float = LANE_WIDTH * LANE_COUNT + SHOULDER * 2.0

## How long one piece of track is, in metres. Pieces are spawned and recycled
## in units of this. Bigger = fewer, larger pieces.
const CHUNK_LENGTH: float = 30.0


## Turns a lane number (0, 1, 2) into a world X position.
## With 3 lanes at 2.5 m this gives: -2.5, 0.0, +2.5
static func lane_to_x(lane: int) -> float:
	return (float(lane) - (float(LANE_COUNT) - 1.0) * 0.5) * LANE_WIDTH


## X position of the painted line BETWEEN lane `i` and lane `i + 1`.
## For 3 lanes there are 2 lines, at -1.25 and +1.25.
static func divider_x(i: int) -> float:
	return lane_to_x(i) + LANE_WIDTH * 0.5


## How many painted lines a track piece needs.
static func divider_count() -> int:
	return LANE_COUNT - 1


## Nearest lane number to a given world X. Handy if you ever need to work out
## which lane something is sitting in.
static func x_to_lane(x: float) -> int:
	var lane := int(round(x / LANE_WIDTH + (float(LANE_COUNT) - 1.0) * 0.5))
	return clampi(lane, 0, LANE_COUNT - 1)
