extends SceneTree
## SCENE BUILDER (developer tool — you can ignore or delete this whole folder).
##
## Builds materials/, scenes/player.tscn, scenes/track_chunk.tscn and
## scenes/main.tscn from scratch, and writes the input map into project.godot.
## You never need to run it; it's here so everything can be rebuilt if you
## break something. To re-run it:
##
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless \
##       --path . --script res://tools/build_scenes.gd

# ------------------------------------------------------------ player figure
# Chunky, big-headed proportions. Realistic proportions read as mush at the
# 8 m camera distance; an oversized head and clear blocky limbs keep the
# silhouette legible when the character is only ~90 px tall on screen.
## Smooth scenery building blocks: leaf clumps, leaf blades, tubes.
const FK := preload("res://tools/flora_kit.gd")

const COLL_RADIUS := 0.40
const COLL_HEIGHT := 1.80     # full body capsule, spans y 0.00 .. 1.80
const COLL_CENTRE_Y := 0.90

## The figure is a STACK, and these numbers are what make it meet at every
## joint, put the feet on y = 0 and top the cap out at y = 1.80:
##   sole  0.00-0.05  shoe   0.05-0.16  leg   0.16-0.68  shorts 0.62-0.86
##   torso 0.82-1.26  yoke   1.14-1.30  neck  1.26-1.38
##   head  1.36-1.72  cap    1.68-1.80
## Change one and check the joint above AND below it.
const HIP_Y := 0.68
const HIP_X := 0.145
const LEG_LEN := 0.52          # navy leg; the shoe adds 0.16 below it
# The leg is now TWO segments with a knee between them, and they must still add
# up to LEG_LEN so the rest pose is pixel-identical to the one-piece version.
#
# The knee is not decoration. With a rigid leg the foot's height is
# HIP_Y - LEG*cos(angle), and cosine is an EVEN function — so two legs swinging
# to equal and opposite angles put both feet at exactly the same height, all
# the way round the cycle. That is a pogo stick, not a run, and no amount of
# keyframing fixes it while the leg is one rigid rod. Bending the knee is what
# lets one leg be SHORT while the other is LONG at the same instant.
const THIGH_LEN := 0.30
const SHIN_LEN := LEG_LEN - THIGH_LEN
const SHOE_H := 0.16
const SHOULDER_Y := 1.14
const SHOULDER_X := 0.33
const ARM_LEN := 0.36          # sleeve; the hand adds 0.15 below it
## HEAD SIZE IS MEASURED, not guessed. tools/audit.tscn reports the head:body
## ratio; at 0.20 this read as a small-headed adult, which turns to mush at the
## ~100 px the character actually occupies. Stylised runners land at 0.28-0.34.
## 0.52 / 1.80 = 0.29.
const HEAD_Y := 1.48
const HEAD_W := 0.52
const HEAD_H := 0.52
const HEAD_D := 0.48
## The stack, top down: cap 1.68-1.80, head 1.22-1.74, neck 1.16-1.26,
## yoke 1.08-1.24, torso 0.82-1.20, shorts 0.62-0.86, leg 0.16-0.68,
## shoe 0.00-0.16. Change one and check the joint above AND below.

# ------------------------------------------------------------------- track
## Stop drawing anything past this distance. The fog reaches full opacity at
## fog_depth_end (200 m), so beyond that there is literally nothing left to
## see — this is a free saving. The margin matters: cull exactly AT the fog
## end and you clip objects that are still ~99% faded rather than 100%,
## which shows up as a faint shimmer at the vanishing point (measured on the
## old 150 m fog: 11/255 at 150 m, 0/255 at 162 m).
##
## It's worth doing because gl_compatibility does NO mesh batching — every
## visible MeshInstance3D costs its own draw call.
const CULL_DISTANCE := 212.0

const OBSTACLE_ROWS := 2
## ONE KNOB for how dense the jungle is. 1.0 is the desktop look; drop it for
## phones and rebuild.
##
## Worth knowing what this actually buys, because the headline triangle count
## is misleading. A piece is ~40k triangles and nine are pooled, but geometry
## is culled at 162 m (see CULL_DISTANCE), so only about 5.4 pieces are ever
## drawn — the real in-frame figure is roughly 215k, not 358k. tools/audit.tscn
## reports both.
##
## Of that in-frame cost, the scattered Decor is the largest single slice at
## ~42%, which is why this scales it. The understory and canopy are already
## built from 6-segment, 2-ring spheres — about as cheap as a sphere gets — so
## there is nothing left to win there without removing plants.
const DENSITY := 1.0

const DECOR_COUNT := int(round(18.0 * DENSITY))
const COIN_COUNT := 8          # must match COIN_COUNT in track_chunk.gd
## How many seeded looks each repeating layer gets. Only one is visible at a
## time, so extra variants cost nodes and memory but NOT draw calls.
## ---- LANDMARKS: the jungle's answer to Subway Surfers' trains ----
## A long thing lying in ONE lane that you can jump onto and RUN ALONG.
## The top sits at 1.10 m, comfortably under the player's 1.32 m jump apex —
## and that margin is the whole feature. Raise it above 1.32 and the landmark
## silently stops being ridable and becomes an unfair wall.
const LANDMARK_LEN := 16.0
const LANDMARK_TOP := 1.10
const LANDMARK_W := 1.6

const UNDERSTORY_VARIANTS := 3
const WALL_VARIANTS := 3
const TREE_COUNT := 8          # the rest of DECOR_COUNT become rocks

var _mats := {}


func _initialize() -> void:
	# The scene scripts below refer to `GameState`, which only resolves if the
	# autoload was registered BEFORE this process started. Registering it now
	# is NOT enough — the script compiler has already made up its mind, and
	# you'd get "Identifier not found: GameState" on every script that uses it.
	#
	# So on a fresh project we write the setting and ask to be run once more.
	if not ProjectSettings.has_setting("autoload/GameState") \
			or not ProjectSettings.has_setting("autoload/Sfx"):
		_write_input_map()
		_write_project_settings()
		print("Registered the GameState autoload.")
		print("BUILD_RESULT: RERUN_NEEDED (run this script once more to build the scenes)")
		quit(2)
		return

	var ok := true
	_write_input_map()
	_write_project_settings()

	_build_materials()
	ok = _build_player_scene() and ok
	ok = _build_chunk_scene() and ok
	ok = _build_hud_scene() and ok
	ok = _build_chaser_scene() and ok
	ok = _build_main_scene() and ok
	print("BUILD_RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


# =============================================================================
#  MATERIALS — saved as real files so every mesh can SHARE one.
#  Sharing matters: 250 meshes using one material draw far faster than 250
#  meshes each with their own copy.
# =============================================================================

func _build_materials() -> void:
	var defs := {
		# A DIRT path against deep jungle green. The old light-green-on-green had
		# almost no contrast, so the playable lanes read as part of the scenery.
		# Warm earth against cool green separates them instantly — and that is a
		# gameplay win as much as a visual one.
		"ground": Color(0.46, 0.33, 0.20),
		"path_edge": Color(0.34, 0.24, 0.16),
		"verge": Color(0.10, 0.23, 0.12),
		"verge_patch": Color(0.14, 0.31, 0.15),
		# THE TRAIL. Compacted earth where feet go, grass where they do not.
		# Both sit in the same luminance band as the dirt (~0.3), so every
		# obstacle contrast rule measured against the dirt still holds.
		"trail_worn": Color(0.40, 0.27, 0.16),
		"trail_grass": Color(0.26, 0.50, 0.17),
		# Dull brown, not orange: orange is a game colour (the lichen on the
		# boulders, the bracket fungus), and litter must never read as one.
		"litter": Color(0.40, 0.29, 0.18),
		"moss_tuft": Color(0.24, 0.50, 0.18),
		"trunk": Color(0.42, 0.32, 0.20),
		"trunk_dark": Color(0.27, 0.19, 0.13),
		"foliage": Color(0.10, 0.30, 0.15),
		"foliage_mid": Color(0.17, 0.44, 0.19),
		"foliage_light": Color(0.31, 0.60, 0.24),
		"frond": Color(0.20, 0.50, 0.21),
		"frond_light": Color(0.38, 0.66, 0.27),
		# Canopy sits far above and is seen against bright sky, so it is
		# DARKER than ground foliage — otherwise it bleaches out and the
		# enclosure effect disappears.
		"canopy_dark": Color(0.07, 0.22, 0.11),
		"canopy_mid": Color(0.12, 0.31, 0.14),
		# The sunlit top of the roof. Without a lighter green up there the
		# canopy is one flat mass and you cannot read its depth.
		"canopy_hi": Color(0.19, 0.40, 0.17),
		"leaf_big": Color(0.24, 0.52, 0.21),
		"leaf_big_pale": Color(0.40, 0.65, 0.26),
		"shrub": Color(0.13, 0.35, 0.16),
		"shrub_dark": Color(0.11, 0.29, 0.13),
		"liana": Color(0.20, 0.34, 0.16),
		# Bamboo is the one plant that is NOT green — pale yellow-green stems
		# are what make a clump of it read as bamboo and not as reeds.
		# Toned down: pale bamboo sat in the bright band that is kept for the
		# things you can hit, right at the edge of every lane.
		"bamboo": Color(0.30, 0.42, 0.16),
		"bamboo_node": Color(0.45, 0.48, 0.24),
		"bamboo_leaf": Color(0.38, 0.58, 0.26),
		# The jungle was 100% green. Two flower colours is all it takes to stop
		# that reading as a wall of one hue.
		"flower_pink": Color(0.92, 0.40, 0.56),
		"flower_gold": Color(0.96, 0.78, 0.24),
		"flower": Color(0.92, 0.36, 0.48),
		"rock": Color(0.45, 0.46, 0.44),
		"coin": Color(1.00, 0.80, 0.16),
		"coin_rim": Color(0.86, 0.52, 0.06),
		"coin_star": Color(1.00, 0.95, 0.62),
		# The magnet must never be mistaken for a coin at a glance, so it is
		# the one red thing in the game and it is the only thing that glows.
		# The cap made this exact mistake and was fixed; the magnet kept it.
		# Red cannot be bright — its luminance is dominated by the green
		# channel it does not have — so a red pickup sits in the mid band and
		# vanishes against the path. Bright orange keeps the "not a coin, not a
		# gem" read while actually being bright.
		"magnet": Color(0.80, 0.09, 0.07),
		"magnet_tip": Color(0.62, 0.64, 0.68),
		"shield_face": Color(0.42, 0.28, 0.17),
		"shield_rim": Color(0.96, 0.93, 0.84),
		"surge": Color(0.52, 0.16, 0.86),
		"surge_band": Color(0.62, 0.62, 0.64),
		# Cyan is the last hue not already spoken for: gold coins, red magnet,
		# brown shield, violet gem.
		"spring": Color(0.04, 0.60, 0.70),
		"spring_tip": Color(0.62, 0.66, 0.68),
		# The skyway. Pale planks against dark leaves so the walkable strip
		# reads instantly from 9 m up, where you have no ground reference.
		# OBSTACLES GET THEIR OWN COLOURS, separate from the scenery that uses the
		# same shapes. That separation is the whole point: it lets the things
		# that kill you be tuned for visibility without turning the jungle
		# behind them into the same colour.
		#
		# The rule is the one the character already follows, and it is measured
		# rather than chosen. Both backgrounds an obstacle is met against sit at
		# almost the same mid luminance — dirt 0.348, foliage 0.365 — so to
		# clear 1.6 contrast against BOTH a colour has to be either DARK
		# (luminance under 0.199) or BRIGHT (over 0.62). Anything between has
		# nothing to separate against and reads as scenery.
		#
		# Every obstacle is therefore a dark mass with bright trim, or the
		# reverse. Measured before: the vines scored 1.00 against the jungle,
		# which is not "hard to see", it is invisible.
		"ob_wood": Color(0.26, 0.17, 0.10),        # L 0.18  dark (brown bark, not black)
		# Honey timber rather than near-white: with the sun now behind the
		# camera every obstacle face is fully lit, and at 0.94 the crates
		# rendered as flat white boxes with no wood left in them.
		"ob_wood_pale": Color(0.88, 0.68, 0.40),   # L 0.70  bright
		# Warm limestone, the stone the old jungle temples were built from.
		"ob_stone": Color(0.68, 0.62, 0.47),       # L 0.62  bright
		# The temple walls you run along: older, greyer, greener stone than
		# the stelae. A 16 m wall does not need the hurdle brightness rule to
		# be seen, and at full brightness it read as a row of cream boxes.
		"ob_ruin": Color(0.55, 0.54, 0.45),
		# Carving: a few shades darker than the stone it is cut into. It is
		# detail, not silhouette, so it does not need to clear the rule.
		"ob_stone_carve": Color(0.46, 0.41, 0.31),
		"ob_stone_dark": Color(0.16, 0.16, 0.18),  # L 0.16  dark
		"ob_vine": Color(0.13, 0.19, 0.09),        # L 0.17  dark
		"ob_leaf": Color(0.70, 0.92, 0.28),        # L 0.83  bright
		# The python: gold with a dark net, the pattern of a reticulated
		# python. Bright body, dark markings — the same dark-and-bright rule as
		# everything else you can hit, and the one pattern in the game that
		# says "snake" before you have seen the shape.
		# Olive-khaki, not gold: a gold snake read as a line of coins. Still
		# bright enough to clear the contrast rule against the path (1.72)
		# and the leaves (1.65) — the yellow anaconda's real colour.
		"ob_snake": Color(0.74, 0.64, 0.28),       # L 0.64  bright
		"ob_snake_dark": Color(0.20, 0.13, 0.06),  # L 0.14  dark
		# Bracket fungus on the fallen giants: the brightest natural orange in
		# a rainforest, and a marker you can see down the length of the log.
		"ob_fungus": Color(0.98, 0.60, 0.16),      # L 0.65  bright
		# Dark leaves for anything you can hit. The bright lime leaf was on
		# five of the six obstacles AND is the colour of the grass between the
		# lanes, and above the knee it vanished against the bright end of the
		# tunnel of trees (1.13:1). Dark green holds against both.
		"ob_leaf_dark": Color(0.09, 0.22, 0.09),   # L 0.18  dark
		# The giant fig's trunk: near-black like the stela, so every "go
		# round" column is the same dark-with-pale-verticals look — and never
		# the same brown as the trees along the trail.
		"ob_fig": Color(0.10, 0.08, 0.06),
		# The orange crust (Trentepohlia algae) that really does coat wet rock
		# in a rainforest: the warm, bright top of the boulder you jump.
		# Rust-orange rather than pale: the pale version rendered the exact
		# gold of a coin, and "bright top = jump" must not also mean "coin".
		"ob_lichen": Color(0.86, 0.42, 0.12),
		"lamp": Color(1.00, 0.90, 0.55),
		# THE CHASERS. Bruno is a silverback, and the silver saddle is the
		# one part of him you see most — you spend the chase looking at his
		# back over your shoulder, so it is the brightest thing on him. The
		# cap is navy with a gold band: unmistakably a uniform.
		"bruno_fur": Color(0.22, 0.20, 0.22),
		"bruno_silver": Color(0.42, 0.43, 0.47),
		"bruno_skin": Color(0.32, 0.25, 0.22),
		"bruno_cap": Color(0.12, 0.17, 0.42),
		"bruno_gold": Color(0.98, 0.76, 0.18),
		"croc": Color(0.28, 0.58, 0.20),
		"croc_dark": Color(0.14, 0.34, 0.11),
		"croc_belly": Color(0.90, 0.88, 0.58),
		"croc_collar": Color(0.90, 0.16, 0.14),
		"leash": Color(0.60, 0.40, 0.20),
		# The surf plank: hot orange with a yellow stripe — a toy, and the
		# brightest warm thing on the runner, so you can see at a glance that
		# you are riding one (and that you are therefore protected).
		"board": Color(0.12, 0.30, 0.88),
		"board_stripe": Color(0.80, 0.66, 0.10),
		# DARK timber, not tan. The coins floating over this deck are the only
		# content on the treetop run, and on the narrow stretch a line of them
		# is how you learn which lane to be in before you arrive. At the old
		# tan the coin scored 1.02-1.10 against the plank underneath it once
		# the real lighting was counted — the deck is sunlit and the coin face
		# is not, which cancels the little albedo difference there was. Dark
		# timber puts that back over 2.
		"deck_plank": Color(0.22, 0.17, 0.12),
		# The boardwalk's planks: two tones of weathered timber laid across the
		# deck. Lighter than the slab so the walkway reads as BUILT, and still
		# dark enough (L ~0.26 against the coin's ~0.80) that a line of coins
		# floating over it stands out by a factor of nearly three.
		"deck_board": Color(0.40, 0.27, 0.15),
		"deck_board_b": Color(0.33, 0.22, 0.13),
		"deck_runner": Color(0.62, 0.46, 0.26),
		"deck_edge": Color(0.16, 0.34, 0.17),
		"deck_leaf": Color(0.28, 0.54, 0.26),
		"crown_hi": Color(0.35, 0.62, 0.28),
		# The trampoline. The single most saturated thing in the game, because
		# it is the one object you must not fail to notice.
		"pad": Color(0.55, 0.95, 0.25),
		"pad_mark": Color(0.99, 0.99, 0.92),
		"bark": Color(0.33, 0.24, 0.16),
		"bark_dark": Color(0.22, 0.16, 0.11),
		"log_end": Color(0.55, 0.42, 0.26),
		"moss": Color(0.26, 0.45, 0.20),
		"stone": Color(0.47, 0.46, 0.43),
		"stone_dark": Color(0.33, 0.32, 0.30),
		"vine": Color(0.24, 0.42, 0.19),
		"vine_leaf": Color(0.35, 0.58, 0.24),
		# MEASURED, not chosen by eye. Both backgrounds this character runs
		# across sit at almost the same mid luminance — dirt 0.348, foliage
		# 0.365 — so a mid-tone garment has nothing to separate against and
		# simply disappears. The old teal top scored 1.40 contrast against the
		# path and 1.35 against the leaves; under ~1.6 is invisible.
		#
		# The way out is the EXTREMES: every major mass is now either bright
		# (luminance > 0.67) or dark (< 0.17), and they ALTERNATE down the
		# figure — bright torso, dark arms, dark legs, bright shoes — so the
		# moving parts read against the still ones. Re-check with
		# tools/audit.tscn if you change any of these.
		# A MONKEY. Still obeying the rule the contrast audit forced on the old
		# character: every mass is bright (luminance > 0.67) or dark (< 0.17),
		# never the mid-tones that vanish against dirt (0.348) and leaves
		# (0.365). Dark fur, bright face/hands/feet/tail-tip, and a bright sand
		# pack — which is the biggest thing you see, because you spend the
		# whole game looking at this animal's back.
		# THE OUTFIT — dressed like the runner in the game this is modelled on:
		# hoodie, shorts, backwards cap, big white sneakers, a backpack. The
		# old all-dark monkey followed a luminance-only contrast rule and
		# passed it, but in the real frame it read as a black blob with white
		# mittens. What actually separates a character from a green jungle and
		# a grey track is HUE: a blue hoodie, red shorts and ginger fur are
		# three colours that exist nowhere else in the scene, so the runner is
		# the one thing your eye finds without looking for it. The bright
		# parts (sneakers, pack, cap, face) still clear the luminance rule on
		# their own — tools/audit.tscn prints the numbers.
		"player_top": Color(0.13, 0.46, 0.95),        # hoodie body, bright blue
		"player_sleeve": Color(0.10, 0.38, 0.84),     # sleeves + hood, a shade deeper
		"player_fur": Color(0.80, 0.38, 0.12),        # ginger fur
		"player_hair": Color(0.50, 0.22, 0.08),       # darker fur: crown, ears
		"player_shoe": Color(0.98, 0.86, 0.66),       # hands, ears, tail tip
		"player_sneaker": Color(0.98, 0.98, 0.97),    # sneakers
		"player_pants": Color(0.93, 0.19, 0.15),      # red shorts
		"player_skin": Color(0.98, 0.87, 0.68),       # face + belly
		"player_accent": Color(0.94, 0.16, 0.14),     # cap + pack lid
		"player_accent_dark": Color(0.62, 0.07, 0.08),# brim + sneaker soles
		"player_pack": Color(1.00, 0.80, 0.14),       # backpack, bright yellow
		"player_dark": Color(0.10, 0.11, 0.15),       # eyes, straps, soles
	}
	# --- which materials get the WIND shader, and how hard they move ---
	# Amplitude is in metres at full mask. The mask keeps everything below
	# `start` completely still, so trunks and stalks stay planted: a canopy
	# crown 9 m up sways 22 cm, a shrub at ankle height barely twitches.
	var wind := {
		"canopy_dark":   {"amp": 0.26, "start": 5.0, "range": 7.0, "speed": 0.80},
		"canopy_mid":    {"amp": 0.26, "start": 5.0, "range": 7.0, "speed": 0.80},
		"canopy_hi":     {"amp": 0.28, "start": 5.0, "range": 7.0, "speed": 0.80},
		"frond":         {"amp": 0.15, "start": 1.0, "range": 3.5, "speed": 1.15},
		"frond_light":   {"amp": 0.15, "start": 1.0, "range": 3.5, "speed": 1.15},
		"foliage":       {"amp": 0.11, "start": 1.2, "range": 3.0, "speed": 1.00},
		"foliage_mid":   {"amp": 0.11, "start": 1.2, "range": 3.0, "speed": 1.00},
		"foliage_light": {"amp": 0.12, "start": 1.2, "range": 3.0, "speed": 1.00},
		"leaf_big":      {"amp": 0.07, "start": 0.15, "range": 1.1, "speed": 1.35},
		"leaf_big_pale": {"amp": 0.07, "start": 0.15, "range": 1.1, "speed": 1.35},
		"shrub":         {"amp": 0.05, "start": 0.10, "range": 1.0, "speed": 1.25},
		"shrub_dark":    {"amp": 0.05, "start": 0.10, "range": 1.0, "speed": 1.25},
		"vine_leaf":     {"amp": 0.13, "start": 0.8, "range": 2.0, "speed": 1.45},
		"liana":         {"amp": 0.16, "start": 2.0, "range": 5.0, "speed": 0.95},
	}
	var foliage_shader: Shader = load("res://shaders/foliage.gdshader")

	# --- the ground gets a DAPPLE shader ---
	# The canopy is deliberately out of the shadow pass (it blankets the trail
	# black otherwise), which left a dense roof overhead casting no light
	# pattern at all on the ground you run along. This fakes it: world-space
	# noise darkening the dirt in soft patches, so the dapple flows past as
	# you run. It also breaks up a 9.1 x 30 m slab of one flat colour.
	var ground_shader: Shader = load("res://shaders/ground.gdshader")
	# Things that glow. A power-up has to win a fight for attention against a
	# whole jungle, and emission is the only cue that survives shadow, fog and
	# distance — a bright albedo just goes grey when the canopy covers it.
	var emissive := {
		# Low, on purpose. Emission on top of full sun drove these past 1.0,
		# and the tonemapper clipped all of them to the same pale yellow-white
		# as the coins — the orange magnet, the violet gem and the cyan spring
		# measured (255,255,170), (255,252,255) and (255,255,255). The glow
		# bubble round each pickup now does the shouting; the icon keeps its
		# colour.
		"magnet": 0.12,
		"magnet_tip": 0.12,
		"shield_rim": 0.60,
		"surge": 0.12,
		"surge_band": 0.12,
		"spring": 0.12,
		"spring_tip": 0.12,
		"pad": 0.45,
		"pad_mark": 0.70,
		"coin": 0.28,
		"coin_rim": 0.12,
		"coin_star": 0.55,
		"lamp": 2.2,
		"board": 0.12,
		"board_stripe": 0.12,
	}

	var dappled := {
		"ground":    {"strength": 0.34, "scale": 0.085, "variation": 0.14},
		"verge":     {"strength": 0.30, "scale": 0.070, "variation": 0.18},
		"verge_patch": {"strength": 0.26, "scale": 0.070, "variation": 0.18},
		"path_edge": {"strength": 0.24, "scale": 0.090, "variation": 0.12},
		"trail_worn": {"strength": 0.30, "scale": 0.085, "variation": 0.12, "grain": 0.25},
		"trail_grass": {"strength": 0.26, "scale": 0.070, "variation": 0.20, "grain": 0.35},
	}
	# Nothing in a jungle is polished metal; the table stays for anything that
	# ever needs to glint.
	var metal := {}
	# Gold: a hard toon highlight, but NOT metallic — a metallic surface loses
	# its diffuse colour and mirrors the sky, which turns gold coins blue.
	# The flash as a turning coin sweeps its face through the highlight is
	# the glint.
	var shiny := {"coin": 0.22, "coin_rim": 0.3, "coin_star": 0.18}

	for name in defs:
		if dappled.has(name):
			var gm := ShaderMaterial.new()
			gm.shader = ground_shader
			var g: Dictionary = dappled[name]
			gm.set_shader_parameter("albedo", defs[name])
			gm.set_shader_parameter("dapple_strength", g["strength"])
			gm.set_shader_parameter("dapple_scale", g["scale"])
			gm.set_shader_parameter("variation", g["variation"])
			if g.has("grain"):
				gm.set_shader_parameter("grain", g["grain"])
			var gpath := "res://materials/%s.tres" % name
			var gerr := ResourceSaver.save(gm, gpath)
			if gerr != OK:
				push_error("material save failed: %s (%d)" % [gpath, gerr])
			_mats[name] = load(gpath)
			continue

		if wind.has(name):
			var sm := ShaderMaterial.new()
			sm.shader = foliage_shader
			var w: Dictionary = wind[name]
			sm.set_shader_parameter("albedo", defs[name])
			sm.set_shader_parameter("sway_amp", w["amp"])
			sm.set_shader_parameter("sway_speed", w["speed"])
			sm.set_shader_parameter("mask_start", w["start"])
			sm.set_shader_parameter("mask_range", w["range"])
			sm.set_shader_parameter("tint_amount", 0.12)
			var spath := "res://materials/%s.tres" % name
			var serr := ResourceSaver.save(sm, spath)
			if serr != OK:
				push_error("material save failed: %s (%d)" % [spath, serr])
			_mats[name] = load(spath)
			continue

		var m := StandardMaterial3D.new()
		m.albedo_color = defs[name]
		# Low, for the TOON step below: the toon ramp is a smoothstep whose
		# width IS the roughness, so at 0.95 it was still a soft Lambert
		# gradient. At 0.3 light and shade meet at a crisp cartoon edge.
		# SMOOTH, MODERN LIGHT. This used to be a hard toon step (roughness
		# 0.3 set the width of the step), which on low-poly shapes looked
		# illustrated — and on a big screen looked blocky: every facet and
		# every terminator was a hard edge. Burley diffuse rolls the light
		# round the form, and a broad, faint sheen (rough 0.78) gives surfaces
		# the soft highlight real bark, stone and leaves have.
		# NOTE: do NOT use SHADING_MODE_UNSHADED — that makes the mesh ignore
		# the sun entirely and the shape goes completely flat.
		m.roughness = 0.78
		m.metallic = 0.0
		m.metallic_specular = 0.22
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		# THE CARTOON LOOK. Toon diffuse replaces the smooth Lambert falloff
		# with a clean step between lit and shaded, which is most of what makes
		# a mobile runner read as "illustrated" rather than "rendered". The rim
		# puts a bright edge on every silhouette facing away from the camera,
		# so shapes separate from whatever is behind them even when their
		# colours are close — it does for depth what the contrast rules do for
		# colour.
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.6
		# INK. A dark outline round everything you can touch, and nothing you
		# cannot: the monkey, the obstacles, the trains, coins and power-ups
		# get one; the jungle does not. That split is the point — it sorts the
		# picture into "game" and "scenery" before you have read a single
		# shape. Godot's stencil outline draws only where the object is NOT,
		# so parts that share the stencil reference never outline each other:
		# the box-built monkey gets one clean silhouette, not a line at every
		# joint.
		var ink := _ink_width(name)
		if ink > 0.0 and name.begins_with("ob_"):
			# Obstacles get ink that is a constant width ON SCREEN (see
			# shaders/ink_outline.gdshader): the built-in outline is a fixed
			# width in metres, which is under half a pixel 40 m out — exactly
			# where you read obstacles. Same stencil scheme as the built-in:
			# write 1 where the object is, draw ink only where it is not.
			m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
			m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
			m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
			m.stencil_reference = 1
			var ink_mat := ShaderMaterial.new()
			ink_mat.shader = load("res://shaders/ink_outline.gdshader")
			ink_mat.set_shader_parameter("min_width", ink)
			ink_mat.render_priority = 1
			m.next_pass = ink_mat
		elif ink > 0.0:
			m.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
			m.stencil_outline_thickness = ink
			m.stencil_color = Color(0.10, 0.06, 0.03, 1.0)
		if shiny.has(name):
			m.metallic = 0.15
			m.metallic_specular = 1.0
			m.roughness = shiny[name]
		if metal.has(name):
			m.metallic = 0.85
			m.metallic_specular = 0.7
			m.roughness = metal[name]
		if emissive.has(name):
			m.emission_enabled = true
			m.emission = defs[name]
			m.emission_energy_multiplier = emissive[name]
		var path := "res://materials/%s.tres" % name
		var err := ResourceSaver.save(m, path)
		if err != OK:
			push_error("material save failed: %s (%d)" % [path, err])
		_mats[name] = load(path)
	print("saved %d materials" % defs.size())


## How thick a material's ink outline is, in metres — 0 for none. The
## runner's is thinner because it is always close to the lens; obstacles are
## met from 60 m away and need the extra weight to survive the distance.
func _ink_width(mat_name: String) -> float:
	if mat_name.begins_with("player_"):
		return 0.022
	if mat_name.begins_with("bruno_") or mat_name.begins_with("croc"):
		return 0.028
	if mat_name.begins_with("ob_"):
		return 0.035
	if mat_name in ["board", "board_stripe", "coin", "coin_rim", "coin_star", "magnet", "magnet_tip", "shield_face", "shield_rim",
			"surge", "surge_band", "spring", "spring_tip", "pad", "pad_mark"]:
		return 0.03
	return 0.0


# =============================================================================
#  helpers
# =============================================================================

## Adds `node` under `parent` and registers it with `root` so it gets SAVED.
## Godot only serialises a node into a PackedScene if its `owner` is the scene
## root. Forget this and you save an empty scene.
func _add(parent: Node, node: Node, root: Node, node_name: String) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	return node


func _box(parent: Node, root: Node, node_name: String, size: Vector3,
		pos: Vector3, mat_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mats[mat_name]
	mi.position = pos
	return _add(parent, mi, root, node_name) as MeshInstance3D


func _cyl(parent: Node, root: Node, node_name: String, top_r: float, bot_r: float,
		height: float, pos: Vector3, mat_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = height
	# 14 sides with smooth normals: round, not the hexagonal pencil 6 gave.
	cm.radial_segments = 14
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mats[mat_name]
	mi.position = pos
	return _add(parent, mi, root, node_name) as MeshInstance3D


func _pivot(parent: Node, root: Node, pivot_name: String, pivot_pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_add(parent, pivot, root, pivot_name)
	return pivot


## Takes a mesh out of the shadow pass. Every shadow-caster is drawn a SECOND
## time into the shadow map, so this is also a real saving.
func _no_shadow(mi: MeshInstance3D) -> MeshInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Stops drawing a mesh once it is further away than the fog can be seen through.
func _cull_far(mi: MeshInstance3D) -> MeshInstance3D:
	mi.visibility_range_end = CULL_DISTANCE
	# A hard cut is fine because the fog has already faded it to nothing —
	# there is literally no pixel left to pop.
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return mi


func _save(node: Node, path: String) -> bool:
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err != OK:
		push_error("pack failed for %s: %d" % [path, err])
		return false
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save failed for %s: %d" % [path, err])
		return false
	print("saved ", path)
	return true


# =============================================================================
#  PLAYER SCENE
# =============================================================================

func _build_player_scene() -> bool:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))
	# The `true` is essential: add_to_group() defaults to persistent = FALSE,
	# which means the group is NOT written into the saved scene. Miss it and
	# the group silently vanishes the moment the scene is loaded from disk —
	# coins stop noticing the player and the camera loses its fallback target.
	player.add_to_group("player", true)
	# Godot's default floor_snap_length of 0.1 m is too short for something
	# moving at 12 m/s: crossing the seam between two track pieces briefly
	# counts as LEAVING the floor, which makes is_on_floor() flicker — so jumps
	# get eaten and the run animation stutters into the jump pose. 0.5 keeps
	# the character glued across seams and bumps.
	player.floor_snap_length = 0.5

	var coll := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = COLL_RADIUS
	cap.height = COLL_HEIGHT
	coll.shape = cap
	coll.position = Vector3(0.0, COLL_CENTRE_Y, 0.0)
	_add(player, coll, player, "CollisionShape3D")

	# THE NEAR-MISS COLUMN. A tall, narrow, non-solid box that rides with the
	# runner and covers the slice of track its OWN lane occupies. An obstacle
	# entering it means that obstacle is in your lane, at your depth — so if it
	# then LEAVES while you are still alive, you got past something that was
	# genuinely in the way, by jumping it or ducking it. That is the definition
	# of a close call, and it needs no guesswork about intent.
	#
	# It is deliberately narrow (0.9 m against a 2.5 m lane) so an obstacle in
	# the NEXT lane over never counts: passing something you were never going
	# to hit is not a near miss, and rewarding it would cheapen the real ones.
	var near := Area3D.new()
	# Tall, and hanging well below the runner, so it still contains a knee-high
	# log while you are at the top of a jump 1.4 m above it.
	near.position = Vector3(0.0, 1.0, 0.0)
	_add(player, near, player, "NearMiss")
	var nc := CollisionShape3D.new()
	var nb := BoxShape3D.new()
	nb.size = Vector3(0.90, 6.0, 0.70)
	nc.shape = nb
	_add(near, nc, player, "CollisionShape3D")

	var visual := Node3D.new()
	_add(player, visual, player, "Visual")
	# The figure hangs off a BODY pivot rather than off Visual directly, purely
	# so the code-driven lean has somewhere to live. The run animation already
	# drives Visual:rotation (the stride sway), and if the lean wrote the same
	# property one would simply overwrite the other every frame. On separate
	# nodes they compose: sway from the animation, bank from the movement.
	var body := Node3D.new()
	_add(visual, body, player, "Body")
	# THE MONKEY is sculpted in tools/char_monkey.gd: smooth, rounded forms
	# with real normals, soft light and a thin ink line, on exactly the rig
	# the animations and the gait test expect (Torso, Head, ArmLeft/Elbow/
	# Hand, LegLeft/Knee/Ankle/Foot ...). It replaced a figure built out of
	# boxes, which on a big screen was the most "pixelated" thing in the game.
	(load("res://tools/char_monkey.gd") as GDScript).build(body, player)
	# WHAT YOU HAVE, ON YOU. A magnet held up in the right hand while the
	# magnet runs, and a coil under each sneaker while the spring does — so
	# you can see what is active by looking at the runner, which is where
	# your eyes already are.
	var held := Node3D.new()
	held.visible = false
	_add(body.get_node("ArmRight/Elbow"), held, player, "HeldMagnet")
	held.position = Vector3(0.0, -0.36, -0.05)
	# A horseshoe magnet: one smooth bent bar, arc on top, legs down, with
	# the pole tips in their own colour.
	var hm := []
	var bar: Array = [Vector3(-0.09, -0.165, 0.0)]
	for i in 9:
		var a: float = PI * float(i) / 8.0
		bar.append(Vector3(-cos(a) * 0.09, sin(a) * 0.09, 0.0))
	bar.append(Vector3(0.09, -0.165, 0.0))
	var bar_r: Array = []
	for i in bar.size():
		bar_r.append(0.036)
	hm.append(_part(FK.trunk(bar, bar_r, 14), Transform3D(), "magnet"))
	for sx in [-1.0, 1.0]:
		hm.append(_part(FK.trunk([Vector3(sx * 0.09, -0.16, 0.0), Vector3(sx * 0.09, -0.22, 0.0)],
			[0.039, 0.039], 14), Transform3D(), "magnet_tip"))
	_merged(held, player, "Mesh", hm)
	for leg in ["LegLeft", "LegRight"]:
		var boot := Node3D.new()
		boot.visible = false
		_add(body.get_node("%s/Knee/Ankle" % leg), boot, player, "SpringBoot")
		boot.position = Vector3(0.0, -0.20, -0.06)
		# A real coil spring: a wire wound three times round.
		var wire: Array = []
		var wire_r: Array = []
		for i in 49:
			var a: float = TAU * 3.0 * float(i) / 48.0
			wire.append(Vector3(cos(a) * 0.085, -0.085 * float(i) / 48.0, sin(a) * 0.085))
			wire_r.append(0.018)
		_merged(boot, player, "Mesh", [_part(FK.trunk(wire, wire_r, 8), Transform3D(), "spring")])

	var anim_player := AnimationPlayer.new()
	# Physics interpolation is ON for this project, and it smooths transforms
	# between PHYSICS ticks. An AnimationPlayer left on its default "idle"
	# callback writes transforms on the render frame instead, which fights that
	# system. Ticking on the physics frame keeps the two in step.
	anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_add(player, anim_player, player, "AnimationPlayer")
	var lib := AnimationLibrary.new()
	lib.add_animation("run", _make_run_animation())
	lib.add_animation("jump", _make_jump_animation())
	lib.add_animation("roll", _make_roll_animation())
	lib.add_animation("idle", _make_idle_animation())
	lib.add_animation("surf", _make_surf_animation())
	lib.add_animation("jump_b", _lifted(_make_jump_animation(), 0.12))
	anim_player.add_animation_library("", lib)

	var cam_target := Marker3D.new()
	cam_target.position = Vector3(0.0, 1.4, 0.0)
	_add(player, cam_target, player, "CameraTarget")

	# --- effects: all pre-built, restarted by player.gd, nothing spawned ---
	var fx := Node3D.new()
	_add(player, fx, player, "Effects")
	# A small pool of coin bursts used round-robin: a line of coins arrives
	# every 80 ms, faster than one burst finishes, so a single emitter would
	# keep cutting its own sparkle short.
	for i in 4:
		var sp := _particles(16, 0.45, 0.22,
			[Color(1.0, 0.94, 0.55, 1.0), Color(1.0, 0.76, 0.16, 0.9), Color(1.0, 0.5, 0.05, 0.0)])
		sp.position = Vector3(0.0, 0.95, -0.3)
		sp.spread = 180.0
		sp.initial_velocity_min = 2.6
		sp.initial_velocity_max = 5.0
		# Additive: sparkles ADD light, so they glow against anything behind.
		(sp.mesh.material as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sp.gravity = Vector3(0.0, -6.0, 0.0)
		_add(fx, sp, player, "Sparkle%d" % i)
	# The surf plank, under the feet while a shield is held. A child of the
	# body rather than of Visual, so it stays pointing down the track while
	# the monkey turns side-on on it, and rides up and down with every jump.
	var board := Node3D.new()
	board.visible = false
	_add(player, board, player, "Board")
	_merged(board, player, "Deck", _board_parts(Transform3D(Basis(), Vector3(0, 0.09, 0.0))))
	# Sparks off the tail wheels while it grinds along.
	var sparks := _particles(26, 0.32, 0.09,
		[Color(1.0, 1.0, 0.7, 1.0), Color(1.0, 0.7, 0.2, 1.0), Color(1.0, 0.35, 0.05, 0.0)])
	sparks.one_shot = false
	sparks.explosiveness = 0.0
	sparks.position = Vector3(0.0, 0.05, 0.55)
	sparks.direction = Vector3(0.0, 0.7, 1.0)
	sparks.spread = 28.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.5
	sparks.gravity = Vector3(0.0, -9.0, 0.0)
	(sparks.mesh.material as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_add(board, sparks, player, "Sparks")
	# The plank bursting into splinters when it takes a crash for you.
	var splinters := _particles(18, 0.8, 0.16,
		[Color(0.35, 0.60, 1.0, 1.0), Color(1.0, 0.84, 0.2, 1.0), Color(0.2, 0.3, 0.6, 0.0)])
	splinters.position = Vector3(0.0, 0.3, 0.0)
	splinters.spread = 70.0
	splinters.initial_velocity_min = 3.0
	splinters.initial_velocity_max = 6.0
	splinters.gravity = Vector3(0.0, -12.0, 0.0)
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.09, 0.04, 0.22)
	chunk.material = splinters.mesh.material
	(chunk.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	(chunk.material as StandardMaterial3D).albedo_texture = null
	splinters.mesh = chunk
	splinters.angular_velocity_min = -400.0
	splinters.angular_velocity_max = 400.0
	_add(fx, splinters, player, "Splinters")

	# A burst in the power-up's own colour the moment you grab one. White in
	# the scene file; player.gd tints it per pickup.
	var burst := _particles(28, 0.6, 0.30,
		[Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	burst.position = Vector3(0.0, 1.1, -0.2)
	burst.spread = 180.0
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 6.0
	burst.gravity = Vector3(0.0, -2.0, 0.0)
	(burst.mesh.material as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_add(fx, burst, player, "PowerBurst")

	# Dust kicked up on landing: a low ring of soft brown puffs.
	var dust := _particles(18, 0.6, 0.62,
		[Color(0.86, 0.76, 0.60, 0.75), Color(0.80, 0.70, 0.55, 0.35), Color(0.8, 0.7, 0.55, 0.0)])
	dust.position = Vector3(0.0, 0.08, 0.0)
	dust.direction = Vector3(0.0, 0.25, 0.0)
	dust.spread = 90.0
	dust.flatness = 0.85
	dust.initial_velocity_min = 1.8
	dust.initial_velocity_max = 3.2
	dust.gravity = Vector3(0.0, 0.6, 0.0)
	dust.damping_min = 3.0
	dust.damping_max = 4.0
	_add(fx, dust, player, "Dust")

	return _save(player, "res://scenes/player.tscn")


## A one-shot burst of soft round billboards that shrink as they fade.
## World-space (local_coords off), so a burst stays where it happened while
## the runner carries on — a line of coins leaves a trail of sparkle behind.
func _particles(amount: int, life: float, size: float, ramp: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.1))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray(ramp)
	p.color_ramp = g

	var dot := Gradient.new()
	dot.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	dot.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = dot
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	# Every emitter gets its OWN material, so making one additive cannot
	# quietly turn the dust into glowing light as well.
	mat.resource_local_to_scene = true
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _make_run_animation() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR

	# Nine keys on a 0.075 s grid. A run is not a pendulum swing, it is five
	# distinct poses that repeat, and you need a key for each of them:
	#
	#   0.000  CONTACT  the foot lands out in front, knee barely bent
	#   0.075  ABSORB   weight comes down, knee folds, the body is at its lowest
	#   0.150  PASS     the other leg swings past, this one is under the hips
	#   0.225  DRIVE    the leg pushes back, straightening
	#   0.300  TOE-OFF  fully extended behind, and now airborne
	#   0.375  TUCK     the heel snaps up toward the backside  <- the key pose
	#   0.450  SWING    knee leads forward, heel still high
	#   0.525  REACH    the shin unfolds, reaching for the ground
	#   0.600  CONTACT  back to the start
	#
	# The TUCK is the one that sells it. A leg that swings forward straight
	# reads as a march; a leg that folds up under the body and then unfolds
	# reads as a run. It is only possible because there is now a knee.
	var t := [0.0, 0.075, 0.15, 0.225, 0.3, 0.375, 0.45, 0.525, 0.6]

	# THE SPRINT. The old cycle was a jog: body upright, a short stride, both
	# feet on the ground at once, and from the chase camera — straight behind
	# and above — eight frames of it looked almost identical, so the monkey
	# seemed to glide. What reads as RUNNING from behind is: a strong forward
	# lean, a real bounce with a moment where both feet are off the ground,
	# the heel kicking right up to the backside so the white sole flashes at
	# the camera, high knees, arms pumping hard from the shoulder, and the
	# body rolling over each foot as it lands.
	#
	# Designed with forward kinematics against the real rig (hip 0.68, thigh
	# 0.30, shin 0.22, the sneaker's box below the ankle) and checked the way
	# test_gait measures it: the planted sole sits on the ground (+4 mm)
	# through the whole stance, both feet are 12 cm up at the flight keys,
	# and the swinging foot never scrapes. Every leg angle is in the BODY's
	# frame, which is leaned 0.24 rad forward, so a thigh at 0 points down
	# and slightly back in the world.
	#
	# The right side is the SAME table half a cycle later.
	var lean := -0.24
	_limb(a, "LegLeft", t, [0.64, 0.36, 0.02, -0.31, -0.54, -0.01, 0.96, 0.86, 0.64])
	_limb(a, "LegLeft/Knee", t, [-0.15, -0.62, -0.55, -0.30, -0.58, -1.72, -1.50, -0.55, -0.15])
	_limb(a, "LegRight", t, [-0.54, -0.01, 0.96, 0.86, 0.64, 0.36, 0.02, -0.31, -0.54])
	_limb(a, "LegRight/Knee", t, [-0.58, -1.72, -1.50, -0.55, -0.15, -0.62, -0.55, -0.30, -0.58])

	# The ankles hold the sole flat through the stance, point the toe hard at
	# push-off and in the heel kick (that is the sole you see from behind),
	# then flex the toe UP as the knee drives through so it cannot scrape.
	_limb(a, "LegLeft/Knee/Ankle", t, [-0.13, 0.50, 0.77, 0.50, 0.61, 1.02, 0.73, 0.03, -0.13])
	_limb(a, "LegRight/Knee/Ankle", t, [0.61, 1.02, 0.73, 0.03, -0.13, 0.50, 0.77, 0.50, 0.61])

	# Arms pump against the legs, from the shoulder, elbows bent: the hand
	# comes up to chin height on the forward swing and back past the hip on
	# the back swing. Held a little out from the body (z) so the elbows show
	# either side of the backpack from the camera. POSITIVE elbow is the way
	# an elbow bends; the old tables were negative, which bent them backwards.
	var arm_l := [-0.70, -0.45, 0.05, 0.60, 0.90, 0.70, 0.15, -0.45, -0.70]
	var arm_r := [0.90, 0.70, 0.15, -0.45, -0.70, -0.45, 0.05, 0.60, 0.90]
	var al := []
	var ar := []
	for i in t.size():
		al.append(Vector3(arm_l[i], 0.0, -0.13))
		ar.append(Vector3(arm_r[i], 0.0, 0.13))
	_value_track(a, "Visual/Body/ArmLeft:rotation", t, al, true)
	_value_track(a, "Visual/Body/ArmRight:rotation", t, ar, true)
	_limb(a, "ArmLeft/Elbow", t, [1.15, 1.25, 1.45, 1.65, 1.75, 1.65, 1.45, 1.25, 1.15])
	_limb(a, "ArmRight/Elbow", t, [1.75, 1.65, 1.45, 1.25, 1.15, 1.25, 1.45, 1.65, 1.75])

	# The bounce, solved from the legs so the planted foot stays planted:
	# lowest at mid-stance where the knee gives, highest in the flight
	# between steps. The z offset puts the planted foot under the runner's
	# middle despite the lean carrying the hips forward.
	var bob := [0.005, 0.004, -0.034, 0.097, 0.005, 0.004, -0.034, 0.097, 0.005]
	var pos := []
	for y: float in bob:
		pos.append(Vector3(0.0, y, 0.08))
	_value_track(a, "Visual:position", t, pos, true)

	# Lean (x), the hips turning with the leading leg (y), and the roll over
	# the planted foot (z) — NEGATIVE x is forward.
	var twist := [-0.07, -0.035, 0.0, 0.035, 0.07, 0.035, 0.0, -0.035, -0.07]
	var roll := [0.0, 0.04, 0.05, 0.03, 0.0, -0.04, -0.05, -0.03, 0.0]
	var rot := []
	for i in t.size():
		rot.append(Vector3(lean, twist[i], roll[i]))
	_value_track(a, "Visual:rotation", t, rot, true)
	return a


## One limb track. Everything the run does is an X rotation on a pivot, so this
## keeps the tables above readable as tables instead of walls of Vector3.
func _limb(a: Animation, pivot: String, times: Array, angles: Array,
		cubic: bool = true) -> void:
	var values := []
	for ang in angles:
		values.append(Vector3(ang, 0.0, 0.0))
	_value_track(a, "Visual/Body/%s:rotation" % pivot, times, values, cubic)


## A surf plank as merge-ready parts: an orange deck with a turned-up nose, a
## yellow stripe and four little cart wheels. Built lying flat along -Z (nose
## first) and then placed by `xf`, so the SAME model is the pickup (stood on
## its tail) and the board under the runner's feet. `k` scales it.
## Power-ups are drawn bigger than life. At their old size they were barely
## larger than a coin — about 7 px tall at the 40-60 m where you decide
## whether to go for one. The COLLIDER is untouched, so pickups are no easier
## to collect; they are just impossible to miss.
const PICKUP_SCALE := 1.4


## Scales merge-ready parts about the origin.
func _scaled(parts: Array, k: float) -> Array:
	var sc := Transform3D(Basis.from_scale(Vector3(k, k, k)), Vector3.ZERO)
	for part in parts:
		part["xform"] = sc * part["xform"]
	return parts


func _board_parts(xf: Transform3D, k: float = 1.0, wheels: bool = true,
		wheel_mat: String = "ob_stone_dark") -> Array:
	var parts := []
	var sc := Basis.from_scale(Vector3(k, k, k))
	var put := func(mesh: Mesh, local: Transform3D, mat: String) -> void:
		parts.append(_part(mesh, xf * Transform3D(sc, Vector3.ZERO) * local, mat))
	put.call(_box_mesh(Vector3(0.54, 0.06, 1.16)), Transform3D(Basis(), Vector3(0, 0, 0.04)), "board")
	put.call(_box_mesh(Vector3(0.46, 0.06, 0.26)),
		Transform3D(Basis.from_euler(Vector3(0.45, 0.0, 0.0)), Vector3(0, 0.05, -0.62)), "board")
	put.call(_box_mesh(Vector3(0.12, 0.07, 1.10)), Transform3D(Basis(), Vector3(0, 0.005, 0.02)),
		"board_stripe")
	# The pickup goes without: power-ups are capped at two draw calls each.
	for sx in ([-1.0, 1.0] if wheels else []):
		for sz in [-1.0, 1.0]:
			put.call(_cyl_mesh(0.05, 0.05, 0.06),
				Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)),
					Vector3(sx * 0.20, -0.06, sz * 0.40)), wheel_mat)
	return parts


## SURFING: turned side-on on the plank, knees bent, arms out for balance.
## Lifted so the sneakers stand on the deck rather than in it.
func _make_surf_animation() -> Animation:
	var a := Animation.new()
	a.length = 0.9
	a.loop_mode = Animation.LOOP_LINEAR
	var t := [0.0, 0.225, 0.45, 0.675, 0.9]
	var lift := 0.08
	_value_track(a, "Visual:position", t, [Vector3(0, lift, 0.02), Vector3(0, lift + 0.02, 0.02),
		Vector3(0, lift, 0.02), Vector3(0, lift + 0.02, 0.02), Vector3(0, lift, 0.02)], true)
	_value_track(a, "Visual:rotation", t, [Vector3(0.0, 0.85, 0.04), Vector3(0.0, 0.80, 0.0),
		Vector3(0.0, 0.85, -0.04), Vector3(0.0, 0.80, 0.0), Vector3(0.0, 0.85, 0.04)], true)
	_value_track(a, "Visual/Body/ArmLeft:rotation", t, [Vector3(0.1, 0, -1.25),
		Vector3(0.0, 0, -1.10), Vector3(-0.1, 0, -1.25), Vector3(0.0, 0, -1.10),
		Vector3(0.1, 0, -1.25)], true)
	_value_track(a, "Visual/Body/ArmRight:rotation", t, [Vector3(-0.1, 0, 1.10),
		Vector3(0.0, 0, 1.25), Vector3(0.1, 0, 1.10), Vector3(0.0, 0, 1.25),
		Vector3(-0.1, 0, 1.10)], true)
	for arm in ["ArmLeft", "ArmRight"]:
		_value_track(a, "Visual/Body/%s/Elbow:rotation" % arm, t, [Vector3(0.35, 0, 0),
			Vector3(0.25, 0, 0), Vector3(0.35, 0, 0), Vector3(0.25, 0, 0),
			Vector3(0.35, 0, 0)], true)
	for leg in [["LegLeft", -0.22], ["LegRight", 0.22]]:
		var v := Vector3(0.35, 0.0, float(leg[1]))
		_value_track(a, "Visual/Body/%s:rotation" % leg[0], t, [v, v, v, v, v], true)
		_value_track(a, "Visual/Body/%s/Knee:rotation" % leg[0], t, [Vector3(-0.70, 0, 0),
			Vector3(-0.78, 0, 0), Vector3(-0.70, 0, 0), Vector3(-0.78, 0, 0),
			Vector3(-0.70, 0, 0)], true)
		_value_track(a, "Visual/Body/%s/Knee/Ankle:rotation" % leg[0], t, [Vector3(0.35, 0, 0),
			Vector3(0.39, 0, 0), Vector3(0.35, 0, 0), Vector3(0.39, 0, 0),
			Vector3(0.35, 0, 0)], true)
	return a


## A copy of an animation with the whole figure raised by `lift` — the board
## versions of poses that key the root position, so a jump off the plank
## does not sink the monkey's feet into it.
func _lifted(src: Animation, lift: float) -> Animation:
	var a: Animation = src.duplicate(true)
	for i in a.get_track_count():
		if String(a.track_get_path(i)) != "Visual:position":
			continue
		for k in a.track_get_key_count(i):
			a.track_set_key_value(i, k, a.track_get_key_value(i, k) + Vector3(0, lift, 0))
	return a


## The title screen pose: standing, bouncing on its toes, waving at you with
## one long arm. The only time the game shows the monkey's face, so the one
## time it gets to have a personality.
func _make_idle_animation() -> Animation:
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR
	var t := [0.0, 0.3, 0.6, 0.9, 1.2]
	_value_track(a, "Visual:position", t, [Vector3(0, 0.0, 0), Vector3(0, 0.035, 0),
		Vector3(0, 0.0, 0), Vector3(0, 0.035, 0), Vector3(0, 0.0, 0)], true)
	_value_track(a, "Visual:rotation", t, [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
		Vector3.ZERO, Vector3.ZERO], true)
	# Right arm up and out to the side, forearm swinging back and forth.
	_value_track(a, "Visual/Body/ArmRight:rotation", t, [Vector3(0, 0, 2.45),
		Vector3(0, 0, 2.6), Vector3(0, 0, 2.45), Vector3(0, 0, 2.6), Vector3(0, 0, 2.45)], true)
	_value_track(a, "Visual/Body/ArmRight/Elbow:rotation", t, [Vector3(0, 0, 0.55),
		Vector3(0, 0, -0.35), Vector3(0, 0, 0.55), Vector3(0, 0, -0.35), Vector3(0, 0, 0.55)], true)
	# The other arm hangs loose, swaying a little with the bounce.
	_value_track(a, "Visual/Body/ArmLeft:rotation", t, [Vector3(0.05, 0, -0.12),
		Vector3(-0.05, 0, -0.18), Vector3(0.05, 0, -0.12), Vector3(-0.05, 0, -0.18),
		Vector3(0.05, 0, -0.12)], true)
	_value_track(a, "Visual/Body/ArmLeft/Elbow:rotation", t, [Vector3(0.3, 0, 0),
		Vector3(0.4, 0, 0), Vector3(0.3, 0, 0), Vector3(0.4, 0, 0), Vector3(0.3, 0, 0)], true)
	for leg in ["LegLeft", "LegRight"]:
		_value_track(a, "Visual/Body/%s:rotation" % leg, t, [Vector3.ZERO, Vector3.ZERO,
			Vector3.ZERO, Vector3.ZERO, Vector3.ZERO], true)
		_value_track(a, "Visual/Body/%s/Knee:rotation" % leg, t, [Vector3(-0.12, 0, 0),
			Vector3(0, 0, 0), Vector3(-0.12, 0, 0), Vector3(0, 0, 0), Vector3(-0.12, 0, 0)], true)
		_value_track(a, "Visual/Body/%s/Knee/Ankle:rotation" % leg, t, [Vector3(0.12, 0, 0),
			Vector3(0, 0, 0), Vector3(0.12, 0, 0), Vector3(0, 0, 0), Vector3(0.12, 0, 0)], true)
	return a


func _make_jump_animation() -> Animation:
	var a := Animation.new()
	a.length = 0.45
	a.loop_mode = Animation.LOOP_NONE
	_value_track(a, "Visual:position", [0.0, 0.12, 0.45],
		[Vector3(0, 0, 0), Vector3(0, -0.06, 0), Vector3(0, 0.02, 0)])
	_value_track(a, "Visual:rotation", [0.0, 0.45],
		[Vector3(-0.06, 0, 0), Vector3(-0.18, 0, 0)])
	var jt := [0.0, 0.2, 0.45]
	_limb(a, "ArmLeft", jt, [-0.9, -2.4, -2.2], false)
	_limb(a, "ArmRight", jt, [0.9, -2.4, -2.2], false)
	_limb(a, "LegLeft", jt, [0.8, -1.0, -0.6], false)
	_limb(a, "LegRight", jt, [-0.8, -0.4, -0.2], false)
	# The knees and elbows MUST be keyed here too. A pivot with no track in the
	# animation that is playing simply holds whatever the last animation left
	# it at — so without these the monkey would jump with whatever knee bend it
	# happened to have at take-off and freeze there.
	_limb(a, "LegLeft/Knee", jt, [-0.30, -1.45, -0.95], false)
	_limb(a, "LegRight/Knee", jt, [-0.55, -0.85, -0.50], false)
	_limb(a, "LegLeft/Knee/Ankle", jt, [-0.20, 0.95, 0.75], false)
	_limb(a, "LegRight/Knee/Ankle", jt, [0.40, 0.70, 0.40], false)
	# Arms flung up and back, elbows only softly bent (a real bend here would
	# put the hands behind the head).
	_limb(a, "ArmLeft/Elbow", jt, [0.55, 0.40, 0.45], false)
	_limb(a, "ArmRight/Elbow", jt, [0.55, 0.40, 0.45], false)
	return a


## A full forward tumble — the Subway Surfers roll.
##
## The catch is that Body's origin is at the FEET, so rotating it alone would
## swing the character through the floor like a hand on a clock. To tumble
## about its middle instead, the position has to counter-rotate: for a point
## `c` above the origin, rotating by theta moves it to (c*cos, c*sin), so
## shifting back by (c - c*cos, -c*sin) pins it in place.
##
## c = 0.42 puts the pivot at hip height, so the roll peaks at 0.84 m — which
## is about the 0.9 m the collision capsule shrinks to while ducking, so what
## you see matches what the physics is doing.
func _make_roll_animation() -> Animation:
	var a := Animation.new()
	a.length = 0.55          # matches the player's default duck_time
	a.loop_mode = Animation.LOOP_NONE

	var c := 0.42
	var times := []
	var rots := []
	var poss := []
	var steps := 8
	for i in steps + 1:
		var t := float(i) / float(steps)
		var theta := -TAU * t
		times.append(t * a.length)
		rots.append(Vector3(theta, 0.0, 0.0))
		poss.append(Vector3(0.0, c * (1.0 - cos(theta)), -c * sin(theta)))

	_value_track(a, "Visual/Body:rotation", times, rots)
	_value_track(a, "Visual/Body:position", times, poss)

	# Tuck every limb in for the duration. Two reasons: a ball tumbles and a
	# starfish does not, and — the practical one — a pivot with no track in the
	# playing animation holds whatever the last animation left it at, so
	# without these the monkey would tumble with its legs still mid-stride.
	var rt := [0.0, 0.12, 0.43, 0.55]
	_limb(a, "LegLeft", rt, [0.3, 1.5, 1.5, 0.5], false)
	_limb(a, "LegRight", rt, [0.3, 1.4, 1.4, 0.5], false)
	_limb(a, "LegLeft/Knee", rt, [-0.4, -1.9, -1.9, -0.6], false)
	_limb(a, "LegRight/Knee", rt, [-0.4, -1.8, -1.8, -0.6], false)
	_limb(a, "LegLeft/Knee/Ankle", rt, [0.2, 0.9, 0.9, 0.3], false)
	_limb(a, "LegRight/Knee/Ankle", rt, [0.2, 0.9, 0.9, 0.3], false)
	_limb(a, "ArmLeft", rt, [-0.4, 0.9, 0.9, -0.3], false)
	_limb(a, "ArmRight", rt, [-0.4, 0.9, 0.9, -0.3], false)
	_limb(a, "ArmLeft/Elbow", rt, [0.6, 1.35, 1.35, 0.7], false)
	_limb(a, "ArmRight/Elbow", rt, [0.6, 1.35, 1.35, 0.7], false)
	return a


## `cubic` rounds the corners between keys. A LINEAR value track holds a
## constant angular velocity and then reverses it instantly at each key, which
## is the literal definition of mechanical movement — it is a large part of why
## the old run read as a wind-up toy. Cubic is NOT wanted everywhere though:
## the roll pins the body against a counter-rotation that only works if the
## curve passes exactly through its keys, so that one stays linear.
func _value_track(a: Animation, path: String, times: Array, values: Array,
		cubic: bool = false) -> void:
	var idx := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(idx, NodePath(path))
	a.track_set_interpolation_type(idx,
		Animation.INTERPOLATION_CUBIC if cubic else Animation.INTERPOLATION_LINEAR)
	a.value_track_set_update_mode(idx, Animation.UPDATE_CONTINUOUS)
	for i in times.size():
		a.track_insert_key(idx, times[i], values[i])


# =============================================================================
#  LANDMARKS
#
#  Subway Surfers has trains: long things that block a lane for many metres
#  and that you can ride on top of. The jungle version is a fallen forest
#  giant or a collapsed ruin wall.
#
#  The riding works entirely through machinery that already exists. The player
#  kills you on an obstacle hit UNLESS the surface normal points upward
#  (`land_forgiveness` 0.7) — so the flat TOP is forgiven and you stand on it,
#  while the blunt END face is not and running into it kills you. No special
#  case anywhere in the player.
# =============================================================================

## FALLEN GIANT — a rainforest tree that came down across the trail and lies
## along it. You run along its back. A worn, mossy strip on top marks the
## flat you actually stand on (the collider is a flat box at LANDMARK_TOP);
## the broken end facing you is pale and splintered so its height reads from
## far off; bracket fungus and snapped branches break up the length.
func _landmark_log(parent: Node, root: Node) -> void:
	var parts := []
	var half := LANDMARK_LEN * 0.5
	var r := 0.72
	var cy := LANDMARK_TOP - r
	var lie := Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
	var trunk := CylinderMesh.new()
	trunk.top_radius = r * 0.9
	trunk.bottom_radius = r
	trunk.height = LANDMARK_LEN
	trunk.radial_segments = 10
	trunk.rings = 1
	parts.append(_part(trunk, Transform3D(lie, Vector3(0.0, cy, -half)), "ob_wood"))
	# The walkway along the crown: a flat worn strip and a carpet of moss.
	parts.append(_part(_box_mesh(Vector3(0.80, 0.10, LANDMARK_LEN - 0.3)),
		Transform3D(Basis(), Vector3(0.0, LANDMARK_TOP - 0.05, -half)), "ob_wood"))
	parts.append(_part(_box_mesh(Vector3(0.62, 0.05, LANDMARK_LEN - 1.6)),
		Transform3D(Basis(), Vector3(0.05, LANDMARK_TOP - 0.01, -half - 0.4)), "ob_leaf"))
	# The broken end facing you: a pale face with splinters standing out.
	parts.append(_part(_cyl_mesh(r * 0.96, r * 0.96, 0.10),
		Transform3D(lie, Vector3(0.0, cy, -0.04)), "ob_wood_pale"))
	# Growth rings, a shade darker than the heartwood — not a dark core,
	# which turned the end into the mouth of a pipe.
	for ring in [0.66, 0.36]:
		parts.append(_part(_cyl_mesh(r * ring, r * ring, 0.11),
			Transform3D(lie, Vector3(0.0, cy, -0.035 + 0.01 * ring)), "ob_stone_carve"))
		parts.append(_part(_cyl_mesh(r * ring - 0.05, r * ring - 0.05, 0.12),
			Transform3D(lie, Vector3(0.0, cy, -0.03 + 0.01 * ring)), "ob_wood_pale"))
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		var sp := PrismMesh.new()
		sp.size = Vector3(0.20, 0.36, 0.10)
		parts.append(_part(sp, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0.0, a)),
			Vector3(cos(a) * r * 0.7, cy + sin(a) * r * 0.7, 0.10)), "ob_wood_pale"))
	# The root plate at the far end, torn out of the ground.
	parts.append(_part(_sphere_mesh(1.05, 7, 3),
		Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.35)),
			Vector3(0.0, cy + 0.12, -LANDMARK_LEN - 0.1)), "ob_wood"))
	# Bracket fungus stepping along both flanks.
	var frng := RandomNumberGenerator.new()
	frng.seed = 4410
	for k in 7:
		var side := 1.0 if k % 2 == 0 else -1.0
		var fz := -frng.randf_range(1.5, LANDMARK_LEN - 1.5)
		var fy := cy + frng.randf_range(-0.1, 0.35)
		parts.append(_part(_cyl_mesh(0.26, 0.30, 0.07),
			Transform3D(Basis(), Vector3(side * (r + 0.02), fy, fz)), "ob_fungus"))
		parts.append(_part(_cyl_mesh(0.17, 0.20, 0.07),
			Transform3D(Basis(), Vector3(side * (r - 0.02), fy - 0.14, fz - 0.18)), "ob_fungus"))
	# Snapped-off branches, so the silhouette is not a perfect tube.
	for i in 3:
		var z := -3.0 - 4.4 * float(i)
		var sd := 1.0 if i % 2 == 0 else -1.0
		parts.append(_part(_cyl_mesh(0.08, 0.15, 0.9),
			Transform3D(Basis.from_euler(Vector3(0.35, 0.0, sd * 1.15)),
				Vector3(sd * 0.68, cy + 0.36, z)), "ob_wood"))
	_merged(parent, root, "FallenGiant", parts)


## TEMPLE WALL — a run of an old limestone wall the jungle has swallowed, the
## kind that stands in the forests of Central America. Every block's TOP is
## pinned to LANDMARK_TOP; only how deep it is buried varies, so the surface
## you run on stays dead level while the wall still looks weathered.
func _landmark_ruin(parent: Node, root: Node) -> void:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 8899
	var blocks := 8
	var step := LANDMARK_LEN / float(blocks)
	for i in blocks:
		var z := -step * (float(i) + 0.5)
		var h := 1.10 + rng.randf_range(0.0, 0.5)
		parts.append(_part(_box_mesh(Vector3(LANDMARK_W - 0.08 - rng.randf_range(0.0, 0.12),
				h, step * 0.95)),
			Transform3D(Basis.from_euler(Vector3(0.0, rng.randf_range(-0.06, 0.06), 0.0)),
				Vector3(rng.randf_range(-0.05, 0.05), LANDMARK_TOP - h * 0.5, z)),
			"ob_ruin"))
		# A worn joint between blocks: a shade darker, and only part of the
		# way down, so the wall reads as one old structure and not as a row
		# of separate boxes.
		parts.append(_part(_box_mesh(Vector3(LANDMARK_W - 0.04, 0.5, 0.04)),
			Transform3D(Basis(), Vector3(0.0, LANDMARK_TOP - 0.27, z - step * 0.5)),
			"ob_stone_carve"))
		# Ferns and creepers along the top edge.
		for k in 2:
			var fside := -1.0 if k == 0 else 1.0
			parts.append(_part(_leaf_mesh(0.22, 0.46),
				_leaf_xform(Vector3(fside * (LANDMARK_W * 0.5 - 0.05), LANDMARK_TOP - 0.02,
					z + rng.randf_range(-0.6, 0.6)), rng.randf_range(0.0, TAU),
					deg_to_rad(-110.0), 0.46), "ob_leaf"))
		# Moss creeping over the top.
		if rng.randf() < 0.85:
			parts.append(_part(_box_mesh(Vector3(rng.randf_range(0.7, 1.4), 0.05,
				step * rng.randf_range(0.4, 0.9))),
				Transform3D(Basis(), Vector3(rng.randf_range(-0.2, 0.2), LANDMARK_TOP - 0.005, z)),
				"ob_leaf"))
	# The carved face at the near end, in low relief like the stelae: a
	# stepped frame and a pair of glyphs, which is what makes it a temple wall
	# and not a pile of rocks.
	for fy in [0.20, 0.96]:
		parts.append(_part(_box_mesh(Vector3(1.30, 0.07, 0.05)),
			Transform3D(Basis(), Vector3(0.0, fy, 0.02)), "ob_stone_carve"))
	for gx in [-1.0, 1.0]:
		parts.append(_part(_box_mesh(Vector3(0.40, 0.46, 0.04)),
			Transform3D(Basis(), Vector3(gx * 0.32, 0.58, 0.015)), "ob_stone_carve"))
		parts.append(_part(_box_mesh(Vector3(0.30, 0.36, 0.05)),
			Transform3D(Basis(), Vector3(gx * 0.32, 0.58, 0.02)), "ob_ruin"))
		parts.append(_part(_sphere_mesh(0.08, 6, 3),
			Transform3D(Basis().scaled(Vector3(1.0, 1.0, 0.4)), Vector3(gx * 0.32, 0.64, 0.05)),
			"ob_stone_carve"))
		parts.append(_part(_box_mesh(Vector3(0.18, 0.05, 0.05)),
			Transform3D(Basis(), Vector3(gx * 0.32, 0.48, 0.05)), "ob_stone_carve"))
	# Strangler-fig roots draped over the wall, the signature of every temple
	# the jungle has taken back: a thick root over the top and down both
	# faces, and moss patches creeping up the stone between them.
	for rz in [-3.4, -9.2, -13.6]:
		var rw := LANDMARK_W * 0.5
		var root_parts := [
			[Vector3(-rw - 0.02, 0.45, rz), Vector3(-rw + 0.05, LANDMARK_TOP, rz + 0.25)],
			[Vector3(-rw + 0.05, LANDMARK_TOP + 0.03, rz + 0.25), Vector3(rw - 0.05, LANDMARK_TOP + 0.03, rz - 0.2)],
			[Vector3(rw - 0.05, LANDMARK_TOP, rz - 0.2), Vector3(rw + 0.02, 0.35, rz - 0.05)],
		]
		for seg in root_parts:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			var mid := (a + b) * 0.5
			var up := (b - a).normalized()
			var basis := Basis.looking_at(up, Vector3.FORWARD if absf(up.y) > 0.9 else Vector3.UP)
			# looking_at aims -Z along `up`; the cylinder runs along Y.
			basis = basis * Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
			parts.append(_part(_cyl_mesh(0.07, 0.09, a.distance_to(b) + 0.1),
				Transform3D(basis, mid), "ob_wood"))
	for i in 10:
		var side := 1.0 if i % 2 == 0 else -1.0
		var mh := rng.randf_range(0.25, 0.6)
		parts.append(_part(_box_mesh(Vector3(0.03, mh, rng.randf_range(0.5, 1.4))),
			Transform3D(Basis(), Vector3(side * (LANDMARK_W * 0.5 - 0.02),
				LANDMARK_TOP - rng.randf_range(0.1, 0.5) - mh * 0.5,
				-rng.randf_range(0.8, LANDMARK_LEN - 0.8))), "ob_leaf"))

	# Tumbled blocks at the foot, and vines draping down the side.
	for i in 3:
		parts.append(_part(_box_mesh(Vector3(0.55, 0.42, 0.62)),
			Transform3D(Basis.from_euler(Vector3(0.2, rng.randf_range(0.0, TAU), 0.35)),
				Vector3(rng.randf_range(-0.9, 0.9), 0.20,
					-rng.randf_range(1.0, LANDMARK_LEN - 1.0))), "ob_stone_dark"))
	for i in 6:
		var z2 := -rng.randf_range(1.5, LANDMARK_LEN - 1.5)
		var vlen := rng.randf_range(0.45, 0.95)
		var vside := 1.0 if i % 2 == 0 else -1.0
		parts.append(_part(_cyl_mesh(0.035, 0.05, vlen),
			Transform3D(Basis(), Vector3(vside * (LANDMARK_W * 0.5 - 0.03),
				LANDMARK_TOP - vlen * 0.5, z2)), "ob_vine"))
		parts.append(_part(_leaf_mesh(0.18, 0.36),
			_leaf_xform(Vector3(vside * (LANDMARK_W * 0.5 - 0.03), LANDMARK_TOP - vlen, z2),
				float(i) * 1.3, deg_to_rad(-140.0), 0.36), "ob_leaf"))
	_merged(parent, root, "RuinWall", parts)


# =============================================================================
#  OBSTACLES
#
#  Six kinds, in three families, and the family is readable from the SHAPE
#  alone — which is the whole point, because you have under a second to decide:
#
#    JUMP OVER : python, mossy boulder        — low and wide, hugging the floor
#    DODGE     : tree trunk, stone stela      — tall, floor to overhead
#    DUCK UNDER: vine curtain, low branch     — floats, with clear air beneath
#
#  The node names (Log, Rock, Pillar, Vines...) are the old ones, kept so the
#  gameplay code and the tests that name them did not have to change.
#
#  Each is a merged mesh so an active obstacle costs 1-2 draw calls, and all
#  six live inside every obstacle slot with only one shown at a time.
# =============================================================================

## Lays a cylinder on its side so its axis runs along X (across the lane).
func _lying(radius: float, length: float, pos: Vector3, tilt: float) -> Transform3D:
	var b := Basis.from_euler(Vector3(0.0, tilt, PI * 0.5))
	return Transform3D(b, pos)


## PYTHON — jump it. A big reticulated python lying across the trail in an S,
## its head up and watching you. Pythons really do stretch out across forest
## paths, and a snake is the one hurdle in the game that makes you WANT to
## jump rather than just need to.
##
## Its collider is sized to the snake (see SPEC in track_chunk.gd): a lying
## python is well under knee height, and the art must never look lower than
## the thing that kills you. Only the raised head stands a little proud, and
## looking slightly taller than it is only ever makes you jump earlier.
func _obstacle_log(parent: Node, root: Node) -> void:
	var parts := []
	# The log: dark, lying across the lane, pale broken ends.
	parts.append(_part(_cyl_mesh(0.28, 0.30, 2.0), _lying(0.30, 2.0, Vector3(0, 0.30, 0), 0.03),
		"ob_wood"))
	for sx in [-1.0, 1.0]:
		parts.append(_part(_cyl_mesh(0.26, 0.26, 0.05),
			_lying(0.26, 0.05, Vector3(sx * 1.0, 0.30, sx * 0.03), 0.03), "ob_wood_pale"))
	for k in 2:
		parts.append(_part(_cyl_mesh(0.14, 0.16, 0.05),
			Transform3D(Basis(), Vector3(-0.45 + 0.8 * float(k), 0.36 - 0.1 * float(k), 0.29)),
			"ob_fungus"))
	# The python, basking along the top of it, tail hanging off one end and
	# head curled round toward you. Pythons really do lie out on fallen logs,
	# and gold-and-black is nature's own hazard stripe.
	var n := 40
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in n:
		var t := float(i) / float(n - 1)
		var rad := lerpf(0.045, 0.10, smoothstep(0.0, 0.3, t)) \
			* lerpf(1.0, 0.75, smoothstep(0.82, 1.0, t))
		var x := lerpf(-0.95, 0.85, t)
		var y := 0.60 + rad
		var z := 0.10 * sin(t * TAU * 1.15)
		# The tail drapes down over the left-hand end of the log.
		var drape := 1.0 - smoothstep(0.0, 0.16, t)
		x -= drape * 0.10
		y = lerpf(y, 0.25, drape)
		z += drape * 0.24
		var curl := smoothstep(0.84, 1.0, t)
		x -= curl * 0.25
		z += curl * 0.28
		y += curl * 0.10
		pts.append(Vector3(x, y, z))
		radii.append(rad)
	for i in n:
		parts.append(_part(_sphere_mesh(radii[i], 10, 5), Transform3D(Basis(), pts[i]), "ob_snake"))
	var brng := RandomNumberGenerator.new()
	brng.seed = 77
	var i2 := 4
	while i2 < n - 4:
		var p0: Vector3 = pts[i2]
		var rr: float = radii[i2]
		var along: Vector3 = (pts[i2 + 1] - pts[i2 - 1]).normalized()
		parts.append(_part(_sphere_mesh(rr * 0.78, 7, 3),
			Transform3D(Basis.from_euler(Vector3(0.0, atan2(along.x, along.z), 0.0))
				.scaled(Vector3(0.9, 0.42, 1.25)), p0 + Vector3(0.0, rr * 0.70, 0.0)),
			"ob_snake_dark"))
		i2 += brng.randi_range(3, 4)
	var hp: Vector3 = pts[n - 1] + Vector3(-0.03, 0.0, 0.08)
	parts.append(_part(_sphere_mesh(0.085, 10, 5),
		Transform3D(Basis().scaled(Vector3(1.05, 0.62, 1.5)), hp), "ob_snake"))
	parts.append(_part(_sphere_mesh(0.06, 8, 4),
		Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.4)), hp + Vector3(0.0, 0.025, 0.02)),
		"ob_snake_dark"))
	for side in [-1.0, 1.0]:
		parts.append(_part(_sphere_mesh(0.024, 6, 3),
			Transform3D(Basis(), hp + Vector3(side * 0.065, 0.025, 0.05)), "ob_wood_pale"))
		parts.append(_part(_box_mesh(Vector3(0.01, 0.006, 0.09)),
			Transform3D(Basis.from_euler(Vector3(0.0, side * 0.25, 0.0)),
				hp + Vector3(side * 0.01, -0.015, 0.18)), "flower_pink"))
	_merged(parent, root, "Log", parts)


## MOSSY BOULDER — jump it. Dark granite with a thick cap of bright moss.
## The first boulder in this game was pale stone, and under cartoon shading it
## went flat white and read as a hole in the picture. Dark rock with a lit
## moss top is how a boulder actually looks on a forest floor — and the
## bright cap marks exactly the height you have to clear.
func _obstacle_rock(parent: Node, root: Node) -> void:
	var parts := []
	# A smooth, weathered boulder, sliced flat underneath so it sits on the
	# trail, with a smaller stone shouldered against it. Built to the
	# collider: x within +-1.0, top of the stone at 0.72, the lichen on top
	# reaching 0.80 — the same box the Kenney rock was squashed into, but
	# rounded like stone that has sat in a rainforest for a thousand years
	# instead of faceted like a cut gem.
	parts.append(_part(FK.boulder(Vector3(0.84, 0.46, 0.56), 11, 0.16, 0.42),
		Transform3D(Basis.from_euler(Vector3(0.0, 0.08, 0.0)), Vector3(-0.12, 0.26, 0.0)),
		"ob_stone_dark"))
	parts.append(_part(FK.boulder(Vector3(0.46, 0.34, 0.44), 23, 0.2, 0.45),
		Transform3D(Basis.from_euler(Vector3(0.0, 0.9, 0.0)), Vector3(0.52, 0.19, 0.06)),
		"ob_stone_dark"))
	# The lichen crust over the top: warm and bright, exactly at the height
	# you have to clear.
	parts.append(_part(FK.clump(Vector3(0.62, 0.09, 0.40), 5, 0.25, 0.3, 16, 8),
		Transform3D(Basis(), Vector3(-0.18, 0.69, 0.0)), "ob_lichen"))
	parts.append(_part(FK.clump(Vector3(0.30, 0.07, 0.26), 9, 0.25, 0.3, 14, 7),
		Transform3D(Basis(), Vector3(0.50, 0.49, 0.04)), "ob_lichen"))
	for k in 4:
		parts.append(_part(_leaf_mesh(0.16, 0.40),
			_leaf_xform(Vector3(0.85, 0.05, 0.3), float(k) * 0.9, deg_to_rad(-60.0), 0.40),
			"ob_leaf_dark"))
	_merged(parent, root, "Rock", parts)


## TREE TRUNK — you cannot jump this and you cannot duck it. Change lane.
## Scaled uniformly (a stretched tree looks wrong in a way a stretched log
## does not), which leaves a canopy 1.66 wide: comfortably inside the 2.5m
## lane, so it never overhangs a neighbour and never lies about which lane
## is blocked. Undergrowth fills the base out to the collider footprint, so
## there is no sliver of visible daylight that would still kill you.
func _obstacle_tree(parent: Node, root: Node) -> void:
	var low := []
	var high := []
	var put := func(part: Dictionary, y: float) -> void:
		(high if y > 2.6 else low).append(part)
	# A giant: a trunk that goes up out of shot into the canopy. The old tree
	# was the roadside model shrunk to 2.6 m, and read as a sapling you could
	# hop. Nothing that runs out of the top of the picture looks jumpable.
	#
	# Smooth tubes now, not stacked 8-sided cylinders and flat prism fins: the
	# trunk flares into the ground, root ridges run down into the soil, and
	# the strangler's pale roots WIND up it and knit together. Split at 2.6 m
	# into the part that casts a shadow and the part that does not (below).
	var trunk_r := func(y: float) -> float:
		return lerpf(0.62, 0.50, clampf(y / 6.0, 0.0, 1.0)) + 0.34 * exp(-y * 2.2)
	for half in 2:
		var ys: Array = [-0.1, 0.25, 0.7, 1.4, 2.1, 2.8] if half == 0 else [2.5, 3.3, 4.1, 4.85, 5.5]
		var pts: Array = []
		var rs: Array = []
		for y: float in ys:
			pts.append(Vector3(0.03 * sin(y * 1.3), y, 0.03 * cos(y * 0.9)))
			rs.append(trunk_r.call(y))
		put.call(_part(FK.trunk(pts, rs, 16), Transform3D(), "ob_fig"), 1.0 if half == 0 else 4.0)
	# Root ridges running out of the flare into the soil: the buttresses.
	for k in 5:
		var ang := TAU * float(k) / 5.0 + 0.4
		var out_dir := Vector3(cos(ang), 0.0, sin(ang))
		var ridge := FK.spline([out_dir * 0.55 + Vector3(0, 1.3, 0), out_dir * 0.78 + Vector3(0, 0.55, 0),
			out_dir * 0.98 + Vector3(0, 0.08, 0), out_dir * 1.12 + Vector3(0, -0.06, 0)],
			[0.10, 0.13, 0.11, 0.07], 3)
		put.call(_part(FK.trunk(ridge[0], ridge[1], 10), Transform3D(), "ob_fig"), 0.6)
	# The strangler fig's pale roots, winding up the side that faces you and
	# knitting together: the pattern that makes it a strangler fig and not
	# just a dark post, and the pale-on-dark that reads from 60 m.
	var root_path := func(phi0: float, phase: float, y0: float, y1: float) -> Array:
		var pts: Array = []
		var rs: Array = []
		for i in 9:
			var t := float(i) / 8.0
			var y := lerpf(y0, y1, t)
			var phi := phi0 + 0.30 * sin(y * 0.9 + phase)
			var r: float = trunk_r.call(y) + 0.035
			pts.append(Vector3(sin(phi) * r, y, cos(phi) * r))
			rs.append(lerpf(0.085, 0.055, clampf(y / 6.0, 0.0, 1.0)))
		return [pts, rs]
	for deg in [-78.0, -28.0, 22.0, 72.0]:
		var ph := deg_to_rad(deg)
		for half in 2:
			var seg: Array = root_path.call(ph, deg * 0.05, 0.0 if half == 0 else 2.45,
				2.75 if half == 0 else 5.8)
			put.call(_part(FK.trunk(seg[0], seg[1], 10), Transform3D(), "ob_wood_pale"),
				1.2 if half == 0 else 4.0)
	# Cross-roots knitting neighbours together, climbing diagonally.
	for k in 3:
		var y0 := 1.2 + 1.35 * float(k)
		var p0 := deg_to_rad(-60.0 + 45.0 * float(k))
		var pts: Array = []
		var rs: Array = []
		for i in 7:
			var t := float(i) / 6.0
			var y := y0 + 0.9 * t
			var phi := p0 + 0.85 * t
			var r: float = trunk_r.call(y) + 0.03
			pts.append(Vector3(sin(phi) * r, y, cos(phi) * r))
			rs.append(0.05)
		put.call(_part(FK.trunk(pts, rs, 8), Transform3D(), "ob_wood_pale"), y0 + 0.45)
	# Limbs reaching out into the canopy, curving up at the tips.
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.5
		var d := Vector3(cos(a), 0.0, sin(a))
		var limb := FK.spline([Vector3(0, 5.1, 0) + d * 0.3, Vector3(0, 5.45, 0) + d * 0.9,
			Vector3(0, 5.85, 0) + d * 1.35], [0.17, 0.12, 0.07], 3)
		put.call(_part(FK.trunk(limb[0], limb[1], 10), Transform3D(), "ob_fig"), 5.45)
	var tree := _merged(parent, root, "Tree", low)
	# The upper trunk casts no shadow: 6 m of it would lay a dark band across
	# the next lane, and a dark band across a lane reads as a hurdle. A child
	# of the tree, so showing and hiding the tree shows and hides all of it.
	var top := _merged(tree, root, "Top", high)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## STONE STELA — dodge it. A carved limestone monument on a stepped plinth,
## the kind the old jungle cities left standing all through the forests of
## Central America: a stern face at the top and rows of glyphs below, with
## the jungle growing over it. Pale stone with dark carving is the dark-and-
## bright rule again, and 2.4 m of it is unmistakably "go round".
func _obstacle_pillar(parent: Node, root: Node) -> void:
	var parts := []
	var front := 0.36
	# Lichen-blackened stone with PALE carving — the reverse of before. Its
	# top half is always seen against the bright far end of the tunnel of
	# trees, and pale stone there had no contrast at all (1.03:1).
	parts.append(_part(_box_mesh(Vector3(1.30, 0.24, 1.10)),
		Transform3D(Basis.from_euler(Vector3(0.0, 0.05, 0.0)), Vector3(0.0, 0.12, 0.0)),
		"ob_stone_dark"))
	var lean := Basis.from_euler(Vector3(0.025, 0.0, -0.02))
	parts.append(_part(_box_mesh(Vector3(1.10, 2.65, 0.70)),
		Transform3D(lean, Vector3(0.0, 1.56, 0.0)), "ob_stone_dark"))
	parts.append(_part(_cyl_mesh(0.55, 0.55, 0.70),
		Transform3D(lean * Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)), Vector3(0.0, 2.74, 0.0)),
		"ob_stone_dark"))
	var relief := func(size: Vector3, pos: Vector3) -> void:
		parts.append(_part(_box_mesh(size), Transform3D(lean, pos), "ob_stone"))
	# A face at the top under a headdress...
	relief.call(Vector3(0.84, 0.10, 0.05), Vector3(0.0, 2.84, front))
	for k in 5:
		relief.call(Vector3(0.09, 0.22, 0.05), Vector3(-0.32 + 0.16 * float(k), 3.02, front - 0.01))
	for side in [-1.0, 1.0]:
		relief.call(Vector3(0.20, 0.10, 0.06), Vector3(side * 0.19, 2.62, front))
	relief.call(Vector3(0.10, 0.20, 0.07), Vector3(0.0, 2.46, front + 0.01))
	relief.call(Vector3(0.34, 0.06, 0.06), Vector3(0.0, 2.28, front))
	# ...and two columns of stacked glyph blocks down the front: a strong
	# pale vertical pair, which is what "tall — go round" looks like. Blocks,
	# each a little different, not rails and rungs — those read as ladders,
	# and a ladder says "climb me".
	for side in [-1.0, 1.0]:
		for gy in 4:
			var gcy := 0.62 + 0.38 * float(gy)
			relief.call(Vector3(0.28, 0.28, 0.05), Vector3(side * 0.23, gcy, front))
			# A glyph cut into each block: a dot, a bar, or a smaller square.
			var k := (gy + (1 if side > 0.0 else 0)) % 3
			if k == 0:
				parts.append(_part(_box_mesh(Vector3(0.10, 0.10, 0.05)),
					Transform3D(lean, Vector3(side * 0.23, gcy, front + 0.02)), "ob_stone_dark"))
			elif k == 1:
				parts.append(_part(_box_mesh(Vector3(0.18, 0.05, 0.05)),
					Transform3D(lean, Vector3(side * 0.23, gcy + 0.04, front + 0.02)), "ob_stone_dark"))
			else:
				parts.append(_part(_box_mesh(Vector3(0.06, 0.16, 0.05)),
					Transform3D(lean, Vector3(side * 0.20, gcy, front + 0.02)), "ob_stone_dark"))
	parts.append(_part(_sphere_mesh(0.40, 8, 4),
		Transform3D(Basis().scaled(Vector3(1.3, 0.3, 1.0)), Vector3(0.05, 3.22, 0.0)), "ob_leaf_dark"))
	for k in 3:
		var vy := 3.0 - 0.45 * float(k)
		parts.append(_part(_cyl_mesh(0.03, 0.04, 0.5),
			Transform3D(Basis(), Vector3(0.56, vy - 0.25, 0.2 - 0.12 * float(k))), "ob_vine"))
		parts.append(_part(_leaf_mesh(0.18, 0.34),
			_leaf_xform(Vector3(0.57, vy - 0.5, 0.2 - 0.12 * float(k)), float(k) * 1.7,
				deg_to_rad(-140.0), 0.34), "ob_leaf_dark"))
	_merged(parent, root, "Pillar", parts)


## Where the slide gates' colliders stop, from SPEC in scripts/track_chunk.gd.
## The art below is built to match it.
const VINES_UNDERSIDE := 1.10
## The posts either side of a slide gate. Just inside the lane edge, and no
## collider: they are there to make the thing read as a GATE — something
## standing on the ground with a hole through it — rather than a plank lying
## on the path, which is what the vine curtain used to look like from 40 m.
const DUCK_POST_X := 1.18


## Two posts rooted in the ground either side of a slide gate.
func _duck_frame(parts: Array, top: float) -> void:
	for side in [-1.0, 1.0]:
		parts.append(_part(_cyl_mesh(0.07, 0.09, top),
			Transform3D(Basis(), Vector3(side * DUCK_POST_X, top * 0.5, 0.0)), "ob_wood"))
		parts.append(_part(_cyl_mesh(0.09, 0.12, 0.30),
			Transform3D(Basis(), Vector3(side * DUCK_POST_X, 0.15, 0.0)), "ob_wood"))



## VINE CURTAIN — DUCK under. A thick pale liana slung across the trail
## between the trees, with a curtain of creepers hanging over it. The liana's
## UNDERSIDE sits exactly on VINES_UNDERSIDE, so the one number you care about
## — how low is the gap — is the brightest, sharpest edge in the whole thing.
func _obstacle_vines(parent: Node, root: Node) -> void:
	var parts := []
	# A liana slung between two trees, a curtain of creepers hanging from it,
	# and one pale cord marking where the curtain ENDS — the top of the gap,
	# a thin bright line and not a plank.
	parts.append(_part(_cyl_mesh(0.10, 0.10, 2.4), _lying(0.10, 2.4, Vector3(0, 2.85, 0), 0.0),
		"ob_wood"))
	for i in 15:
		var x := -0.98 + 0.14 * float(i)
		var len_ := 1.63 - 0.05 * float(i % 3)
		parts.append(_part(_cyl_mesh(0.045, 0.055, len_),
			Transform3D(Basis(), Vector3(x, 2.85 - len_ * 0.5, 0.02 * float(i % 2))), "ob_vine"))
		for k in 2:
			var ly := 1.6 + 0.8 * float(k) + 0.1 * float(i % 3)
			parts.append(_part(_leaf_mesh(0.18, 0.30),
				_leaf_xform(Vector3(x, ly, 0.03), float(i + k) * 1.3, deg_to_rad(-150.0), 0.30),
				"ob_leaf_dark"))
	parts.append(_part(_cyl_mesh(0.11, 0.11, 2.1),
		_lying(0.11, 2.1, Vector3(0, VINES_UNDERSIDE + 0.11, 0.0), 0.0), "ob_wood_pale"))
	_duck_frame(parts, 3.1)
	_merged(parent, root, "Vines", parts)


## DEADFALL — slide under it. A fallen trunk hung up between two snags across
## the trail, with the same pale edge along its underside as the vines: in
## this game a thin bright line across the lane at head height means SLIDE.
func _obstacle_branch(parent: Node, root: Node) -> void:
	var parts := []
	# ONE HEAVY MASS from the gap up, with no daylight through it. With a
	# second limb above the trunk it read as a two-rail fence — and fences
	# are for jumping. A fat trunk, a thick mat of moss and epiphytes on top
	# of it, and strands hanging down to the pale edge say "the only way is
	# under".
	parts.append(_part(_cyl_mesh(0.40, 0.44, 2.45),
		_lying(0.44, 2.45, Vector3(0, VINES_UNDERSIDE + 0.52, 0), 0.03), "ob_wood"))
	# The moss mat heaped along the top, up to the collider's 2.6 m.
	for i in 6:
		var x := -0.95 + 0.38 * float(i)
		parts.append(_part(_sphere_mesh(0.36, 7, 4),
			Transform3D(Basis().scaled(Vector3(1.1, 0.95, 0.9)),
				Vector3(x, VINES_UNDERSIDE + 1.05 + 0.08 * float(i % 2), 0.0)), "ob_leaf_dark"))
	for i in 7:
		var x := -0.9 + 0.3 * float(i)
		parts.append(_part(_leaf_mesh(0.34, 0.60),
			_leaf_xform(Vector3(x, VINES_UNDERSIDE + 1.25, 0.05), float(i) * 1.7,
				deg_to_rad(-40.0), 0.60), "ob_leaf_dark"))
	# Moss strands hanging off the underside, down to just above the edge.
	for i in 9:
		var x := -0.88 + 0.22 * float(i)
		var len_ := 0.10 + 0.05 * float(i % 3)
		parts.append(_part(_cyl_mesh(0.02, 0.03, len_),
			Transform3D(Basis(), Vector3(x, VINES_UNDERSIDE + 0.13 + len_ * 0.5 - 0.02, 0.18)),
			"ob_vine"))
	# The pale edge where the gap starts: a broad strip of stripped bark
	# along the underside, wide enough to read from 40 m.
	parts.append(_part(_cyl_mesh(0.11, 0.11, 2.2),
		_lying(0.11, 2.2, Vector3(0, VINES_UNDERSIDE + 0.11, 0.08), 0.03), "ob_wood_pale"))
	_duck_frame(parts, 2.3)
	_merged(parent, root, "Branch", parts)


## A box — with its edges rounded off whenever it is big enough for the edge
## to show. A razor-sharp box edge is the single most "made of cubes" thing a
## 3D game can put on screen; worn stone and sawn wood always have a soft
## edge that catches a line of light. Thin things (planks, leaf litter, the
## grass beds) and huge ones (the ground) stay plain boxes: on those a bevel
## is invisible and only costs triangles.
var _box_cache := {}


func _box_mesh(size: Vector3) -> Mesh:
	var thin := minf(size.x, minf(size.y, size.z))
	var big := maxf(size.x, maxf(size.y, size.z))
	if thin < 0.08 or big > 8.0:
		var bm := BoxMesh.new()
		bm.size = size
		return bm
	var key := "%.3f/%.3f/%.3f" % [size.x, size.y, size.z]
	if not _box_cache.has(key):
		_box_cache[key] = FK.bevel_box(size, clampf(thin * 0.12, 0.012, 0.06), 2)
	return _box_cache[key]


# =============================================================================
#  THE CANOPY
#
#  The thing that makes a jungle trail feel like a jungle is that it is a
#  TUNNEL. Tall trees lean in from both sides and their crowns close overhead,
#  leaving broken gaps of bright sky. Without this you have a park path with
#  shrubs beside it, which is exactly what this looked like before.
#
#  It is built in TWO LAYERS, and you need both:
#    * ARCH trees stand almost on the verge, lean 20-30 degrees over the trail
#      and carry their crowns out past the centre line. These are what close
#      the roof directly above you.
#    * BACK trees stand 9.5-17 m out and go much higher. They fill the top
#      CORNERS of the frame, which the arch layer can never reach, and give
#      the roof a second depth so it doesn't read as one flat lid.
#
#  Each side is ONE merged mesh, so the density here is essentially free: a
#  side carries ~8 big trees for 5 draw calls (bark, liana, and three greens),
#  and doubling the number of crowns costs triangles only.
#
#  WHY IT CANNOT HIDE AN OBSTACLE. The camera sits at y = 3.5 and looks DOWN
#  the trail, so the ray from the camera to anything standing on the track
#  only ever descends — it never rises above y = 3.5, at any distance. So
#  geometry whose lowest point stays above the camera physically cannot cover
#  an obstacle. Everything this function puts over the corridor is held above
#  CANOPY_MIN_Y, and trunks stay out of the corridor until they are above it
#  too. Measured on the built scene: the lowest canopy vertex anywhere over
#  the lanes is at y 5.37 (1.87 m of clear air above the camera), and nothing
#  below eye height comes closer to the centre than x 5.34, which is 1.1 m
#  outside the track edge. On screen the two never meet: crowns are always
#  above the horizon line, obstacles always below it.
# =============================================================================

## Nothing may hang below this while it is over the trail — see the note above.
const CANOPY_MIN_Y := 7.8
## Half-width of the protected corridor: the 8.5 m track plus ~1 m each side.
const CANOPY_CORRIDOR_X := 5.2


func _build_canopy(parent: Node, root: Node, track_w: float, length: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var edge := track_w * 0.5
	for side_index in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var parts := []

		# --- the arch: close in, leaning hard over the trail ---
		var z := 8.0
		while z > -(length + 14.0):
			_canopy_arch_tree(parts, rng, side, edge, z)
			z -= rng.randf_range(10.0, 16.0)

		# --- the back layer: further out, much taller, fills the corners ---
		z = 11.0
		while z > -(length + 14.0):
			_canopy_back_tree(parts, rng, side, z)
			z -= rng.randf_range(12.0, 19.0)

		# NO SHADOW. A canopy this size casts a solid blanket over the entire
		# trail and the dirt turns black — measured, it was the first thing the
		# render showed. Dropping it out of the shadow pass keeps the enclosure
		# you can SEE while letting the sun still light the path, and it halves
		# what the canopy costs to draw.
		_no_shadow(_merged(parent, root, "Canopy%d" % int(side), parts))


## ONE arch tree: a trunk that leans out over the trail with its crown hung off
## the leaning tip. The LEAN is the entire trick. A vertical tree with a crown
## on top puts its foliage at the edge of the frame where it does nothing; the
## same tree leant 25 degrees puts the same foliage directly overhead.
func _canopy_arch_tree(parts: Array, rng: RandomNumberGenerator, side: float,
		edge: float, z: float) -> void:
	var base_x := side * (edge + rng.randf_range(1.4, 4.6))
	var h := rng.randf_range(6.9, 11.5)
	var segs := 5
	var seg_h := h / float(segs)
	var lean := rng.randf_range(0.17, 0.27)     # radians ADDED per segment
	var sway := rng.randf_range(-0.05, 0.05)    # a little wander along z
	var base_r := rng.randf_range(0.30, 0.46)

	var pos := Vector3(base_x, 0.0, z)
	var tilt := 0.0
	# ONE smooth tube up the whole trunk, starting with a root flare — a 9 m
	# tree that meets the ground as a plain stick looks stuck in rather than
	# grown there. (It was five stacked 6-sided cylinders: a hexagonal pencil
	# with a ledge at every joint.)
	var spine: Array = [Vector3(base_x, -0.15, z), Vector3(base_x, 0.3, z),
		Vector3(base_x, 0.9, z)]
	var girth: Array = [base_r * 2.1, base_r * 1.35, base_r * 1.03]
	for i in segs:
		# The bottom segment stays VERTICAL. Start leaning at the ground and a
		# tree this big walks its own base into the running lanes.
		if i > 0:
			tilt += lean
		var b := Basis.from_euler(Vector3(sway * float(i), 0.0, side * tilt))
		var step := b * Vector3(0.0, seg_h, 0.0)
		# SAFETY RAIL: a trunk may only cross into the corridor once it is
		# already above the sightline. If this segment would break that, it
		# stands up straight instead.
		if absf(pos.x + step.x) < CANOPY_CORRIDOR_X and pos.y + step.y < CANOPY_MIN_Y:
			b = Basis()
			step = Vector3(0.0, seg_h, 0.0)
		pos += step
		spine.append(pos)
		girth.append(base_r * (1.0 - 0.15 * float(i + 1)))
	var sp := FK.spline(spine, girth, 3)
	parts.append(_part(FK.trunk(sp[0], sp[1], 12), Transform3D(), "trunk_dark"))

	# How far this tree reaches across, rolled PER TREE. This coin flip is THE
	# coverage dial. Half the trees carry their crown out over the trail and
	# half keep it on their own verge, so the roof closes in patches and the
	# gaps land somewhere different every time. Make every tree cross and the
	# roof seals solid, which kills the dappled light and the whole thing goes
	# muddy — measured at 80% sky cover, and it looked like a hedge tunnel.
	var reach := rng.randf_range(2.6, 5.6) if rng.randf() < 0.5 else rng.randf_range(-0.2, 1.1)
	_canopy_crown(parts, rng, side, pos, reach, 1.9, 3.1, 3, 5)
	_canopy_limbs(parts, rng, side, pos, reach)
	_canopy_liana(parts, rng, side, pos)


## ONE back tree: taller, further out, barely leaning. These never reach the
## middle of the frame — their job is the top corners, where the arch trees
## have already passed overhead and out of shot.
func _canopy_back_tree(parts: Array, rng: RandomNumberGenerator, side: float,
		z: float) -> void:
	var base_x := side * rng.randf_range(9.5, 17.0)
	var h := rng.randf_range(11.5, 16.5)
	var segs := 3
	var seg_h := h / float(segs)
	var lean := rng.randf_range(0.05, 0.13)
	var pos := Vector3(base_x, 0.0, z)
	var tilt := 0.0
	var spine: Array = [Vector3(base_x, -0.15, z), Vector3(base_x, 0.5, z)]
	var girth: Array = [0.62, 0.40]
	for i in segs:
		tilt += lean
		var b := Basis.from_euler(Vector3(0.0, 0.0, side * tilt))
		pos += b * Vector3(0.0, seg_h, 0.0)
		spine.append(pos)
		girth.append(0.33 - 0.06 * float(i))
	var sp := FK.spline(spine, girth, 3)
	parts.append(_part(FK.trunk(sp[0], sp[1], 10), Transform3D(), "trunk_dark"))

	_canopy_crown(parts, rng, side, pos, rng.randf_range(0.0, 3.0), 2.5, 4.0, 2, 4)


## A crown: a raft of SQUASHED blobs. Squashing them is what matters — a
## canopy spreads sideways, and a ball of leaves on a stick reads as a
## lollipop. They are also coloured by where they sit, not at random: the
## blobs that end up over the trail take the darkest green, because what you
## see of those is their shaded underside, and that shading is most of what
## makes the roof read as a roof rather than a green ceiling sticker.
func _canopy_crown(parts: Array, rng: RandomNumberGenerator, side: float,
		top: Vector3, reach: float, r_min: float, r_max: float,
		n_min: int, n_max: int) -> void:
	var blobs := rng.randi_range(n_min, n_max)
	for i in blobs:
		var r := rng.randf_range(r_min, r_max)
		var flat := rng.randf_range(0.30, 0.48)
		var cx := top.x - side * rng.randf_range(-0.6, reach)
		var cy := top.y + rng.randf_range(-2.1, 1.4)
		var cz := top.z + rng.randf_range(-2.1, 2.1)
		# THE ONE RULE: over the trail, keep the underside above the sightline.
		if absf(cx) < CANOPY_CORRIDOR_X:
			cy = maxf(cy, CANOPY_MIN_Y + r * flat)
		var mat := "canopy_mid"
		if absf(cx) < CANOPY_CORRIDOR_X + 1.5:
			mat = "canopy_dark"
		elif cy > top.y - 0.3 or rng.randf() < 0.3:
			mat = "canopy_hi"
		var b := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0))
		var radii := Vector3(r * rng.randf_range(1.1, 1.5), r * flat, r * rng.randf_range(1.0, 1.35))
		parts.append(_part(_leaf_clump(radii, cx, cz), Transform3D(b, Vector3(cx, cy, cz)), mat))


## Limbs from the trunk tip out under the crown. Without them the crown is a
## raft of leaves floating next to a pole, and at speed you notice.
func _canopy_limbs(parts: Array, rng: RandomNumberGenerator, side: float,
		top: Vector3, reach: float) -> void:
	for i in rng.randi_range(2, 3):
		var from_vertical := rng.randf_range(1.0, 1.45)      # ~57-83 deg
		var yaw := rng.randf_range(-1.0, 1.0)
		var limb_len := maxf(1.6, reach * rng.randf_range(0.6, 1.1))
		var b := Basis.from_euler(Vector3(0.0, yaw, side * from_vertical))
		var start := top + Vector3(0.0, -0.8, 0.0)
		# A limb that arcs up at its tip, the way branches reach for light.
		var along := b * Vector3(0.0, limb_len, 0.0)
		var mid := start + along * 0.5 + Vector3(0.0, -0.15 * limb_len, 0.0)
		var tip := start + along + Vector3(0.0, 0.2 * limb_len, 0.0)
		var sp := FK.spline([start, mid, tip], [0.17, 0.12, 0.06], 3)
		parts.append(_part(FK.trunk(sp[0], sp[1], 8), Transform3D(), "trunk_dark"))


## A liana dangling out of the crown, with a tuft of leaves on the end: a bare
## cylinder hanging in space reads as a floating stick, not a vine.
##
## Length is CLIPPED so it can never dangle into the corridor. Out over the
## verge it can drop to head height, which is where it looks best.
func _canopy_liana(parts: Array, rng: RandomNumberGenerator, side: float,
		top: Vector3) -> void:
	if rng.randf() > 0.75:
		return
	var lx := top.x - side * rng.randf_range(-1.5, 3.5)
	var lz := top.z + rng.randf_range(-2.5, 2.5)
	var floor_y := CANOPY_MIN_Y + 0.5 if absf(lx) < CANOPY_CORRIDOR_X else 2.6
	var llen := minf(rng.randf_range(2.5, 6.5), top.y - 0.7 - floor_y)
	if llen < 1.0:
		return
	parts.append(_part(_cyl_mesh(0.06, 0.09, llen),
		Transform3D(Basis(), Vector3(lx, top.y - 0.7 - llen * 0.5, lz)), "liana"))
	for k in 3:
		parts.append(_part(_leaf_mesh(0.22, 0.5),
			_leaf_xform(Vector3(lx, top.y - 0.7 - llen, lz), float(k) * 2.1,
				deg_to_rad(-120.0), 0.5), "canopy_mid"))


# =============================================================================
#  THE UNDERSTORY
#
#  In real jungle there is no bare ground. The strip either side of the trail
#  is packed with broad leaves, shrubs and saplings right up to the dirt.
#  Built as ONE merged mesh per side: dozens of plants for a couple of draw
#  calls, which is the only way to afford this much density.
# =============================================================================

## Builds THREE differently-seeded strips. The chunk shows one at random each
## time it recycles, so the verge stops repeating every 30 m.
##
## Sliding and mirroring ONE strip (what this used to do) gives two looks; a
## player passes ~50 chunks in two minutes and will find that. Three variants,
## mirrored and slid, stops the repeat being findable. Hidden variants cost no
## draw calls — only the visible one is drawn.
func _build_understory(parent: Node, root: Node, track_w: float, length: float) -> void:
	for variant in UNDERSTORY_VARIANTS:
		var group := Node3D.new()
		_add(parent, group, root, "Var%d" % variant)
		group.visible = variant == 0
		_build_understory_variant(group, root, track_w, length, 777001 + variant * 9173)


func _build_understory_variant(parent: Node, root: Node, track_w: float,
		length: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var edge := track_w * 0.5
	for side_index in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var parts := []
		var z := 4.0
		while z > -(length + 10.0):
			var near := edge + rng.randf_range(0.5, 5.5)

			# --- BIG TROPICAL LEAVES: the signature jungle silhouette, and
			#     there were none at all before. Angled up and outward. ---
			if rng.randf() < 0.92:
				var cluster := rng.randi_range(4, 6)
				var bx := side * near
				var bz := z + rng.randf_range(-0.6, 0.6)
				# A short stalk, then broad blades fanning off the top of it.
				parts.append(_part(_cyl_mesh(0.04, 0.06, 0.55),
					Transform3D(Basis(), Vector3(bx, 0.28, bz)), "shrub_dark"))
				for i in cluster:
					var lw: float = rng.randf_range(0.42, 0.72)
					var ll: float = rng.randf_range(0.55, 0.95)
					parts.append(_blade(lw, ll, Vector3(bx, 0.5, bz),
						float(i) * TAU / float(cluster) + rng.randf_range(0.0, 0.8),
						deg_to_rad(rng.randf_range(-52.0, -18.0))))

			# --- shrub mass hugging the path edge, hiding the hard dirt line ---
			if rng.randf() < 0.75:
				var sb := rng.randi_range(2, 3)
				for i in sb:
					var r := rng.randf_range(0.5, 1.1)
					var sx := side * (edge + rng.randf_range(0.1, 3.0))
					var sz := z + rng.randf_range(-1.2, 1.2)
					parts.append(_part(_leaf_clump(Vector3(1.3 * r, 0.8 * r, 1.1 * r), sx, sz),
						Transform3D(Basis(), Vector3(sx, r * 0.55, sz)),
						"shrub" if i % 2 == 0 else "shrub_dark"))

			# --- bare saplings: thin vertical stems of mixed height. Real
			#     understory is full of them and they break up the mass. ---
			if rng.randf() < 0.6:
				for i in rng.randi_range(1, 3):
					var sh := rng.randf_range(1.4, 3.2)
					parts.append(_part(_cyl_mesh(0.035, 0.06, sh),
						Transform3D(Basis.from_euler(Vector3(
								rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))),
							Vector3(side * (edge + rng.randf_range(1.0, 7.0)),
								sh * 0.5, z + rng.randf_range(-1.5, 1.5))),
						"trunk_dark"))

			z -= rng.randf_range(1.8, 3.2)

		# No shadows from the undergrowth. It is 11,304 of the 29,005 caster
		# triangles on a piece — 39% of all the shadow work in the game — and
		# it is ankle-high scrub sitting on the verge, whose shadow falls on
		# more scrub. The player's shadow and the obstacles' shadows are the
		# ones that carry information, and those are untouched.
		_no_shadow(_merged(parent, root, "Understory%d" % int(side), parts))


## One seeded variant of the jungle wall — a lumpy hedge of overlapping blobs
## down both sides, merged into ONE mesh per side.
func _build_wall_variant(parent: Node, root: Node, W: float, L: float,
		seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for side in [-1.0, 1.0]:
		var parts := []
		var z := 10.0
		while z > -(L + 16.0):
			var r := rng.randf_range(1.6, 2.9)
			var off := rng.randf_range(0.0, 10.0)
			# Sits BEHIND the individual plants (which live 5.7-13.5 m out), so
			# the scene layers: path, then trees, then a wall of green. Put the
			# wall in the same band as the trees and it just swallows them.
			var wx: float = side * (W * 0.5 + 9.5 + off)
			parts.append(_part(_leaf_clump(Vector3(r, r, r), wx, z),
				Transform3D(Basis(), Vector3(wx, r * 0.66, z)),
				["foliage", "foliage_mid"][rng.randi_range(0, 1)]))
			z -= rng.randf_range(1.8, 3.4)
		_no_shadow(_merged(parent, root, "Wall%d" % int(side), parts))


# =============================================================================
#  TRACK CHUNK SCENE
#  Origin sits at the piece's NEAR edge; it extends CHUNK_LENGTH in -Z.
# =============================================================================

## The skyway's geometry. These MUST match the constants of the same name in
## scripts/track_chunk.gd — the script positions the collider, this builds the
## mesh, and if they disagree you get a deck you fall through.
const DECK_Y := 7.0
const DECK_THICK := 0.8
const PAD_Z := -3.0
const PAD_TRIGGER_H := 3.2


func _build_chunk_scene() -> bool:
	var L := LaneConfig.CHUNK_LENGTH
	var W := LaneConfig.TRACK_WIDTH
	var mid_z := -L * 0.5

	var root := Node3D.new()
	root.name = "TrackChunk"
	root.set_script(load("res://scripts/track_chunk.gd"))

	# --- ground slab: top surface sits exactly at y = 0 ---
	var ground := StaticBody3D.new()
	_add(root, ground, root, "Ground")
	_box(ground, root, "Mesh", Vector3(W, 1.0, L), Vector3(0.0, -0.5, mid_z), "ground")
	var gc := CollisionShape3D.new()
	var gs := BoxShape3D.new()
	gs.size = Vector3(W, 1.0, L)
	gc.shape = gs
	gc.position = Vector3(0.0, -0.5, mid_z)
	_add(ground, gc, root, "CollisionShape3D")

	# --- the jungle floor: a wide slab under and well beyond the track ---
	# Without this you see straight through to the sky either side of the
	# track, and the only way to hide THAT is to flatten the whole sky to the
	# fog colour — which leaves the track looking like it floats in mist.
	#
	# It sits 2 cm BELOW the track surface. Up close that's ample separation
	# for the depth buffer; far away both surfaces are 100% fogged to the same
	# colour, so even if they do fight over a pixel it cannot be seen.
	# Deliberately NOT distance-culled: this is the backdrop.
	_box(root, root, "JungleFloor", Vector3(140.0, 1.0, L),
		Vector3(0.0, -0.52, mid_z), "verge")

	# --- worn edges where the path meets the jungle ---
	# Two thin strips raised 2 cm above the path. They cost 2 draw calls per
	# piece and do more to sell "this is a trail through a jungle" than
	# anything else of comparable cost.
	for side in [-1.0, 1.0]:
		_box(root, root, "Edge%d" % int(side), Vector3(0.55, 1.0, L),
			Vector3(side * (W * 0.5 - 0.2), -0.48, mid_z), "path_edge")

	# --- the trail: three worn footpaths with grass growing between them ---
	# A real jungle trail has no painted lines and no rails. What it does have,
	# on any track that feet use every day, is bare compacted earth where
	# people walk and grass where they do not — so the lanes mark THEMSELVES:
	# a darker, smoother footpath down the middle of each, and a raised strip
	# of grass and moss between them. That reads as three lanes from 60 m away
	# and as a jungle path up close, which a white line never did.
	#
	# All of it is decoration: the ground collider underneath is unchanged
	# and flat at y = 0, and nothing here stands more than a few centimetres
	# proud of it except grass, which you run through.
	var trail := Node3D.new()
	_add(root, trail, root, "Trail")
	var bed_parts := []
	var detail := []
	var trng := RandomNumberGenerator.new()
	trng.seed = 1709
	for lane in LaneConfig.LANE_COUNT:
		var x := LaneConfig.lane_to_x(lane)
		# The footpath: packed earth, a shade darker, 1.2 cm proud of the dirt
		# so the two never fight over the same pixels.
		bed_parts.append(_part(_box_mesh(Vector3(1.35, 0.03, L)),
			Transform3D(Basis(), Vector3(x, -0.003, mid_z)), "trail_worn"))
		# Roots run ALONG the edge of the footpath, never across it. Dark and
		# lying across a lane is exactly what a jump obstacle looks like from
		# 40 m, and the trail was laying nine of them per piece.
		for r in 2:
			var side := -1.0 if r == 0 else 1.0
			detail.append(_part(_cyl_mesh(0.04, 0.055, trng.randf_range(2.5, 4.5)),
				Transform3D(Basis.from_euler(Vector3(PI * 0.5, trng.randf_range(-0.12, 0.12), 0.0)),
					Vector3(x + side * 0.66, 0.02, -trng.randf_range(3.0, L - 3.0))), "path_edge"))
		# Fallen leaves: a scatter of flat flakes, densest at the path edges.
		for f in 8:
			var fx: float = x + trng.randf_range(-0.8, 0.8)
			detail.append(_part(_box_mesh(Vector3(0.16, 0.012, 0.10)),
				Transform3D(Basis.from_euler(Vector3(0.0, trng.randf_range(0.0, TAU), 0.0)),
					Vector3(fx, 0.016, -trng.randf_range(0.2, L - 0.2))), "litter"))
	# Between the lanes: a low grass verge, with tufts and the odd flower.
	for i in LaneConfig.divider_count():
		var dx := LaneConfig.divider_x(i)
		bed_parts.append(_part(_box_mesh(Vector3(0.62, 0.06, L)),
			Transform3D(Basis(), Vector3(dx, 0.0, mid_z)), "trail_grass"))
		var gz := -0.2
		while gz > -L:
			var base := Vector3(dx + trng.randf_range(-0.26, 0.26), 0.03, gz)
			var yaw0 := trng.randf_range(0.0, TAU)
			var blades := trng.randi_range(3, 5)
			for k in blades:
				var bb := Basis.from_euler(Vector3(trng.randf_range(0.15, 0.5),
					yaw0 + TAU * float(k) / float(blades), 0.0))
				var blade_len := trng.randf_range(0.14, 0.30)
				detail.append(_part(_leaf_mesh(0.08, blade_len),
					Transform3D(bb, base + bb.y * blade_len * 0.5), "moss_tuft"))
			gz -= trng.randf_range(0.28, 0.5)
	_no_shadow(_merged(trail, root, "Beds", bed_parts))
	_no_shadow(_merged(trail, root, "Detail", detail))

	# --- the obstacle pool: ROWS x LANE_COUNT slots, all pre-built ---
	var obstacles := Node3D.new()
	_add(root, obstacles, root, "Obstacles")
	var slots := OBSTACLE_ROWS * LaneConfig.LANE_COUNT
	for i in slots:
		var ob := StaticBody3D.new()
		ob.position = Vector3(0.0, 0.0, mid_z)
		# The player checks for this group to tell an obstacle apart from the
		# ground, which it touches on every single frame.
		# `true` = persistent, i.e. actually saved into the scene file.
		ob.add_to_group("obstacle", true)
		_add(obstacles, ob, root, "Obstacle%d" % i)
		# All six kinds live in every slot; track_chunk.gd shows one and hides
		# the rest. Hidden meshes cost no draw calls, so this is far cheaper
		# than it looks and it means a slot can become any obstacle instantly.
		_obstacle_log(ob, root)
		_obstacle_rock(ob, root)
		_obstacle_tree(ob, root)
		_obstacle_pillar(ob, root)
		_obstacle_vines(ob, root)
		_obstacle_branch(ob, root)

		var oc := CollisionShape3D.new()
		var obs := BoxShape3D.new()
		obs.size = Vector3(1.7, 0.55, 0.9)
		oc.shape = obs
		oc.position = Vector3(0, 0.275, 0)
		# Same reasoning as the landmark above: start switched off.
		oc.disabled = true
		_add(ob, oc, root, "CollisionShape3D")
		ob.visible = false

	# --- mottling on the verge ---
	# The jungle floor is one huge flat slab, and at speed a single flat colour
	# reads as cheap. A handful of very flattened blobs lying on it break that
	# up. Merged into one mesh per side, so two draw calls for the whole effect.
	var patches := Node3D.new()
	_add(root, patches, root, "VergePatches")
	var prng := RandomNumberGenerator.new()
	prng.seed = 31337
	# Both sides in ONE mesh. They share a material, so the second draw call was
	# buying nothing.
	var pparts := []
	for side in [-1.0, 1.0]:
		for i in 7:
			var pr := prng.randf_range(1.8, 3.6)
			var b := Basis.from_euler(Vector3(0.0, prng.randf_range(0.0, TAU), 0.0))
			b = b.scaled(Vector3(1.0, 0.02, 0.7))
			pparts.append(_part(_sphere_mesh(pr, 6, 2),
				Transform3D(b, Vector3(
					side * prng.randf_range(W * 0.5 + 1.0, W * 0.5 + 14.0),
					0.02,
					prng.randf_range(-L + 1.0, -1.0))),
				"verge_patch"))

		# GRASS ALONG THE PATH LIP. The dirt met the greenery on a dead
		# straight line running the whole 30 m, and a straight edge is the one
		# thing that reads as "made of tiles" from a distance. Tufts overlapping
		# the join break it without touching the lanes themselves.
		#
		# This costs no extra draw call: the tufts go into the SAME merged mesh
		# as the patches, so the piece gains a surface for the grass material
		# and loses one to the merge above. Net zero, and it fixes the seam.
		var gz := -0.8
		while gz > -L:
			var tuft_size := prng.randf_range(1.9, 3.0) / 2.4
			var tuft_spin := prng.randf_range(0.0, TAU)
			var tuft_at := Vector3(side * (W * 0.5 + prng.randf_range(-0.35, 0.9)), 0.0, gz)
			pparts.append_array(_grass_tuft(tuft_at, tuft_size, tuft_spin, "foliage_mid"))
			# Spaced out deliberately. At half this spacing the tufts read
			# slightly better but cost 40k triangles across the nine live
			# pieces — a 12% increase on the whole game for one seam. This is
			# the density where the straight edge stops reading and the cost
			# stays under 20k.
			gz -= prng.randf_range(2.8, 4.4)
	_no_shadow(_merged(patches, root, "Verge", pparts))

	# --- understory and canopy: the two layers that make it a jungle ---
	var under := Node3D.new()
	_add(root, under, root, "Understory")
	_build_understory(under, root, W, L)

	var canopy := Node3D.new()
	_add(root, canopy, root, "Canopy")
	_build_canopy(canopy, root, W, L)

	# --- the jungle wall ---
	# A lumpy hedge of overlapping blobs down both sides, merged into ONE mesh
	# per side. Two draw calls per piece buys a dense backdrop that makes the
	# scattered trees read as a jungle rather than a few plants on a lawn.
	#
	# It is deliberately LONGER than the piece (46 m vs 30 m) so that
	# track_chunk.gd can slide it along z each time the piece recycles: the
	# overhang covers the gap, and the repeat stops being visible. Without
	# that, an identical wall every 30 m reads as obvious tiling.
	var wall := Node3D.new()
	_add(root, wall, root, "JungleWall")
	for wvar in WALL_VARIANTS:
		var wgroup := Node3D.new()
		_add(wall, wgroup, root, "Var%d" % wvar)
		wgroup.visible = wvar == 0
		_build_wall_variant(wgroup, root, W, L, 90210 + wvar * 4457)

	# --- the landmark slot ---
	# One per chunk at most. Both looks live in it; track_chunk.gd shows one,
	# or neither. The collision box is what you actually stand on: flat, level,
	# and its top is LANDMARK_TOP.
	var landmarks := Node3D.new()
	_add(root, landmarks, root, "Landmarks")
	var lm := StaticBody3D.new()
	lm.add_to_group("obstacle", true)
	_add(landmarks, lm, root, "Landmark0")
	_landmark_log(lm, root)
	_landmark_ruin(lm, root)
	var lc := CollisionShape3D.new()
	var lbox := BoxShape3D.new()
	lbox.size = Vector3(LANDMARK_W, LANDMARK_TOP, LANDMARK_LEN)
	lc.shape = lbox
	# Box centred so its top face lands exactly on LANDMARK_TOP and its base
	# on the ground, and pushed back half its length so the slot's origin is
	# its NEAR end — which is the end the player meets first.
	lc.position = Vector3(0.0, LANDMARK_TOP * 0.5, -LANDMARK_LEN * 0.5)
	# OFF in the saved scene. randomise() turns it on with set_deferred, which
	# does not land until the END of the first frame — so if it shipped enabled
	# there would be one frame where every chunk has a solid 16 m box sitting
	# at its own origin, and the player spawns inside one.
	lc.disabled = true
	_add(lm, lc, root, "CollisionShape3D")
	lm.visible = false

	# --- the coin pool ---
	# A chunky medallion, not a flat disc: a thick darker rim, a bright face
	# and a raised diamond that catches the light as it turns. One mesh,
	# shared by every coin in the game.
	var coin_mesh := _merge_parts([
		_part(_coin_cyl(0.34, 0.11), Transform3D(), "coin_rim"),
		_part(_coin_cyl(0.27, 0.13), Transform3D(), "coin"),
		_part(_box_mesh(Vector3(0.15, 0.15, 0.15)),
			Transform3D(Basis.from_euler(Vector3(0.0, PI * 0.25, 0.0)), Vector3.ZERO),
			"coin_star"),
	])
	var coins := Node3D.new()
	_add(root, coins, root, "Coins")
	for i in COIN_COUNT:
		var coin := Area3D.new()
		coin.position = Vector3(0.0, 0.9, mid_z)
		_add(coins, coin, root, "Coin%d" % i)

		var mi := MeshInstance3D.new()
		mi.mesh = coin_mesh
		# Tip the disc onto its edge so it faces the runner, then the script
		# spins the parent around Y for the classic coin twirl.
		mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		_add(coin, mi, root, "Mesh")
		_cull_far(mi)

		var cc := CollisionShape3D.new()
		# A sphere a bit larger than the disc: picking coins up should feel
		# generous, not like threading a needle at 20 m/s.
		var cs := SphereShape3D.new()
		cs.radius = 0.55
		cc.shape = cs
		_add(coin, cc, root, "CollisionShape3D")

	# --- the power-up slot: ONE per piece, one of three kinds ---
	# A single slot with three LOOKS inside it, exactly like an obstacle slot:
	# one Area3D and one collision shape, with three merged meshes of which
	# the chunk shows one. Two power-ups on screen at once would stop either
	# being a moment, and three separate Area3Ds would cost three times the
	# nodes for something that is hidden most of the time anyway.
	var pu := Node3D.new()
	_add(root, pu, root, "Powerups")
	var pick := Area3D.new()
	pick.position = Vector3(0.0, 1.05, mid_z)
	_add(pu, pick, root, "Pickup")

	var looks := Node3D.new()
	_add(pick, looks, root, "Looks")

	# The glow: a bubble behind the icon and a shaft of light falling on it
	# (see shaders/pickup_glow.gdshader). A SIBLING of Looks so the bubble
	# does not sway with the icon; track_chunk.gd bobs it and tints it.
	var gst := SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := [
		[Color(0, 0, 0), Vector2(-0.9, -0.9), Vector2(0.9, 0.9)],     # bubble
		[Color(1, 0, 0), Vector2(-0.55, -1.05), Vector2(0.55, 3.9)],  # shaft
	]
	for q in quads:
		var lo: Vector2 = q[1]
		var hi: Vector2 = q[2]
		var corners := [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for k in tri:
				gst.set_color(q[0])
				gst.set_uv(uvs[k])
				gst.add_vertex(Vector3(corners[k].x, corners[k].y, 0.0))
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = load("res://shaders/pickup_glow.gdshader")
	gst.set_material(glow_mat)
	var glow := MeshInstance3D.new()
	glow.mesh = gst.commit()
	# The vertices are moved in the shader, so the mesh's own bounds lie.
	glow.custom_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 7.0, 4.0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(pick, glow, root, "Glow")
	_cull_far(glow)

	# MAGNET — a horseshoe. Reads at a glance even at 20 m/s, which a sphere
	# with a symbol painted on it would not.
	var mag_n := Node3D.new()
	_add(looks, mag_n, root, "Magnet")
	var horse := []
	for sx in [-1.0, 1.0]:
		horse.append(_part(_box_mesh(Vector3(0.17, 0.42, 0.17)),
			Transform3D(Basis(), Vector3(sx * 0.21, -0.20, 0.0)), "magnet"))
		# Pale tips, so the OPEN end is what catches the eye — that is the end
		# that reads as "magnet" rather than as the letter U.
		horse.append(_part(_box_mesh(Vector3(0.18, 0.13, 0.18)),
			Transform3D(Basis(), Vector3(sx * 0.21, -0.46, 0.0)), "magnet_tip"))
	for i in 7:
		var a: float = PI * float(i) / 6.0
		horse.append(_part(_box_mesh(Vector3(0.17, 0.17, 0.17)),
			Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -a)),
				Vector3(-cos(a) * 0.21, sin(a) * 0.21 - 0.01, 0.0)), "magnet"))
	_merged(mag_n, root, "Horseshoe", _scaled(horse, PICKUP_SCALE))

	# SHIELD — a SURF PLANK, standing on its tail and glowing. Pick it up and
	# you ride it: it takes the next crash for you and splinters. (The node
	# keeps its old name; the rules are the shield's, the look is the board.)
	var sh_n := Node3D.new()
	_add(looks, sh_n, root, "Shield")
	# Three-quarter view, nose kicked up: face-on, a flat board read as a
	# blue book. Side-on-ish you see its length, the turned-up nose and the
	# wheels, which is what says "board".
	var pose := Basis.from_euler(Vector3(0.0, deg_to_rad(62.0), 0.0)) \
		* Basis.from_euler(Vector3(deg_to_rad(38.0), 0.0, 0.0))
	_merged(sh_n, root, "Plank", _board_parts(Transform3D(pose, Vector3.ZERO),
		0.62 * PICKUP_SCALE, true, "board_stripe"))

	# SURGE — a violet gem with "2X" on its face. Violet is the one hue not
	# already spoken for; the 2X is what makes it say DOUBLE rather than just
	# "treasure".
	var sg_n := Node3D.new()
	_add(looks, sg_n, root, "Surge")
	var gem := []
	# 8 facets: a cut gem, not a spinning top.
	gem.append(_part(_cyl_mesh(0.0, 0.23, 0.30, 8), Transform3D(Basis(), Vector3(0, 0.15, 0)),
		"surge"))
	gem.append(_part(_cyl_mesh(0.0, 0.23, 0.26, 8),
		Transform3D(Basis.from_euler(Vector3(PI, 0.0, 0.0)), Vector3(0, -0.13, 0)), "surge"))
	# "2X", seven-segment style, standing proud of the front of the gem.
	var gz := 0.20
	var seg := func(size: Vector2, pos: Vector2, ang: float = 0.0) -> void:
		gem.append(_part(_box_mesh(Vector3(size.x, size.y, 0.05)),
			Transform3D(Basis.from_euler(Vector3(0.0, 0.0, ang)), Vector3(pos.x, pos.y, gz)),
			"surge_band"))
	seg.call(Vector2(0.11, 0.035), Vector2(-0.08, 0.09))
	seg.call(Vector2(0.035, 0.08), Vector2(-0.03, 0.05))
	seg.call(Vector2(0.11, 0.035), Vector2(-0.08, 0.0))
	seg.call(Vector2(0.035, 0.08), Vector2(-0.13, -0.045))
	seg.call(Vector2(0.11, 0.035), Vector2(-0.08, -0.09))
	seg.call(Vector2(0.035, 0.22), Vector2(0.08, 0.0), 0.55)
	seg.call(Vector2(0.035, 0.22), Vector2(0.08, 0.0), -0.55)
	_merged(sg_n, root, "Gem", _scaled(gem, PICKUP_SCALE * 1.15))

	# SPRING — a coil with an arrow on top. Every other pickup is a THING; this
	# one is an instruction, because it is the only power-up that changes what
	# your controls do rather than what they earn you.
	var sp_n := Node3D.new()
	_add(looks, sp_n, root, "Spring")
	var coil := []
	for i in 3:
		var cy: float = -0.30 + 0.13 * float(i)
		coil.append(_part(_cyl_mesh(0.24, 0.24, 0.07),
			Transform3D(Basis.from_euler(Vector3(0.0, 0.5 * float(i), 0.0)),
				Vector3(0.0, cy, 0.0)), "spring"))
	# The arrow. A cone is the one shape that means "up" without a label.
	coil.append(_part(_cyl_mesh(0.0, 0.26, 0.30),
		Transform3D(Basis(), Vector3(0.0, 0.26, 0.0)), "spring_tip"))
	coil.append(_part(_cyl_mesh(0.09, 0.09, 0.16),
		Transform3D(Basis(), Vector3(0.0, 0.05, 0.0)), "spring_tip"))
	_merged(sp_n, root, "Coil", _scaled(coil, PICKUP_SCALE))

	var pc := CollisionShape3D.new()
	# Deliberately more generous than a coin. Missing a power-up by 10 cm is
	# far more annoying than missing one coin out of forty.
	var ps := SphereShape3D.new()
	ps.radius = 0.85
	pc.shape = ps
	_add(pick, pc, root, "CollisionShape3D")
	pick.visible = false
	pick.monitoring = false

	# --- THE SKYWAY: the treetop deck, its flanking crowns, and the pad ---
	# All of it ships hidden. A piece only reveals the parts its ROLE calls for
	# (see Role in track_chunk.gd), which is how one pre-built piece can serve
	# as ordinary ground, as the launch, as deck, or as the way back down —
	# without anything ever being created at runtime.
	var sky := Node3D.new()
	_add(root, sky, root, "Skyway")

	# THE DECK. Built once at full chunk length running 0 .. -L, with its top
	# face at DECK_Y. Shorter roles scale and slide this same mesh rather than
	# owning a second copy of it.
	var deck := StaticBody3D.new()
	_add(sky, deck, root, "Deck")
	var deck_parts := []
	# The structural slab. A plain box, because from above the only thing that
	# matters is that the walkable strip has a crisp, readable edge.
	deck_parts.append(_part(_box_mesh(Vector3(W, DECK_THICK, L)),
		Transform3D(Basis(), Vector3(0.0, DECK_Y - DECK_THICK * 0.5, -L * 0.5)),
		"deck_plank"))
	# A BOARDWALK, not a slab: planks laid across in two alternating tones,
	# with a hairline gap between each, which is what makes it read as wood
	# built in the treetops and gives the eye something to feel speed by.
	var plank := 0.48
	var pz := 0.0
	var k := 0
	while pz > -L + 0.01:
		deck_parts.append(_part(_box_mesh(Vector3(W - 0.5, 0.05, plank - 0.05)),
			Transform3D(Basis.from_euler(Vector3(0.0, 0.006 * float((k * 7) % 5 - 2), 0.0)),
				Vector3(0.0, DECK_Y + 0.02, pz - plank * 0.5)),
			"deck_board" if k % 2 == 0 else "deck_board_b"))
		pz -= plank
		k += 1
	# Pale runner boards laid lengthways on top, one under each lane divider.
	# Up here they are the ONLY cue telling you which lane you are in — there
	# is no verge, no trail, and no scenery at head height to judge by.
	for i in LaneConfig.LANE_COUNT - 1:
		deck_parts.append(_part(_box_mesh(Vector3(0.22, 0.06, L)),
			Transform3D(Basis(), Vector3(LaneConfig.divider_x(i), DECK_Y + 0.045, -L * 0.5)),
			"deck_runner"))
	# Log beams along both edges, with a post every 3 m and a lantern on every
	# other one: the rail of a walkway strung between the trees.
	for side in [-1.0, 1.0]:
		var ex: float = side * (W * 0.5 - 0.22)
		deck_parts.append(_part(_cyl_mesh(0.18, 0.18, L),
			Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)),
				Vector3(ex, DECK_Y + 0.1, -L * 0.5)), "bark"))
		var post_z := -1.5
		var n_post := 0
		while post_z > -L:
			deck_parts.append(_part(_box_mesh(Vector3(0.16, 1.0, 0.16)),
				Transform3D(Basis(), Vector3(ex, DECK_Y + 0.55, post_z)), "bark"))
			if n_post % 2 == 0:
				deck_parts.append(_part(_box_mesh(Vector3(0.22, 0.26, 0.22)),
					Transform3D(Basis(), Vector3(ex, DECK_Y + 1.18, post_z)), "lamp"))
				deck_parts.append(_part(_box_mesh(Vector3(0.28, 0.06, 0.28)),
					Transform3D(Basis(), Vector3(ex, DECK_Y + 1.34, post_z)), "bark_dark"))
			post_z -= 3.0
			n_post += 1
	# A leafy fringe down both sides, sitting slightly PROUD of the top face so
	# the deck reads as a living thing rather than a plank bridge in the sky.
	for side in [-1.0, 1.0]:
		var fz := -1.2
		while fz > -L:
			deck_parts.append(_part(_leaf_clump(Vector3(1.05, 0.44, 1.05), side, fz),
				Transform3D(Basis(), Vector3(side * (W * 0.5 - 0.15), DECK_Y - 0.10, fz)),
				"deck_leaf"))
			fz -= 2.4
	_no_shadow(_merged(deck, root, "Mesh", deck_parts))

	var dc := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(W, DECK_THICK, L)
	dc.shape = dbox
	dc.position = Vector3(0.0, DECK_Y - DECK_THICK * 0.5, -L * 0.5)
	# Ships OFF, like every other collider here: a solid slab sitting at the
	# origin of all nine pooled pieces on frame one would be catastrophic.
	dc.disabled = true
	_add(deck, dc, root, "CollisionShape3D")
	# NOT in the "obstacle" group, deliberately. The deck is scenery you stand
	# on. Tagging it as an obstacle would make its leading face lethal, and the
	# whole point of the treetops is that nothing up there can kill you.
	deck.visible = false

	# THE CROWNS. Without these the view from 9 m up is a flat green floor with
	# nothing on it: the jungle wall tops out near 4.8 m and the canopy layer
	# is switched off for this stretch. These are what make it read as a sea of
	# treetops rather than an empty sky.
	var crown_parts := []
	var crng := RandomNumberGenerator.new()
	crng.seed = 31337
	for side in [-1.0, 1.0]:
		var cz := -1.0
		while cz > -L:
			var cx: float = side * crng.randf_range(6.4, 15.0)
			var cy: float = DECK_Y + crng.randf_range(-1.3, 0.5)
			var cr: float = crng.randf_range(1.9, 3.2)
			crown_parts.append(_part(_leaf_clump(Vector3(1.25 * cr, 0.55 * cr, 1.15 * cr), cx, cz),
				Transform3D(Basis(), Vector3(cx, cy, cz)),
				"crown_hi" if crng.randf() < 0.5 else "deck_leaf"))
			cz -= crng.randf_range(4.0, 7.0)
	var crowns := _merged(sky, root, "Crowns", crown_parts)
	_no_shadow(crowns)
	crowns.visible = false

	# THE PAD. Full track width so it cannot be missed or dodged, and tall
	# enough to catch you standing, ducking, or at the top of an ordinary jump.
	var pad := Area3D.new()
	pad.position = Vector3(0.0, 0.0, PAD_Z)
	_add(sky, pad, root, "Pad")
	var pad_parts := []
	pad_parts.append(_part(_box_mesh(Vector3(W, 0.22, 2.4)),
		Transform3D(Basis(), Vector3(0.0, 0.11, 0.0)), "pad"))
	# Chevrons pointing the way you are already going: "up and onward".
	for i in 3:
		var px: float = LaneConfig.lane_to_x(i)
		for arm in [-1.0, 1.0]:
			pad_parts.append(_part(_box_mesh(Vector3(0.9, 0.06, 0.20)),
				Transform3D(Basis.from_euler(Vector3(0.0, arm * 0.7, 0.0)),
					Vector3(px + arm * 0.32, 0.23, 0.0)), "pad_mark"))
	# A low rail at each end so it reads as a sprung mat, not a painted stripe.
	for ez in [-1.15, 1.15]:
		pad_parts.append(_part(_box_mesh(Vector3(W, 0.34, 0.24)),
			Transform3D(Basis(), Vector3(0.0, 0.17, ez)), "pad_mark"))
	_no_shadow(_merged(pad, root, "Mesh", pad_parts))

	var pcol := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(W, PAD_TRIGGER_H, 2.0)
	pcol.shape = pbox
	pcol.position = Vector3(0.0, PAD_TRIGGER_H * 0.5 + 0.05, 0.0)
	pcol.shape = pbox
	_add(pad, pcol, root, "CollisionShape3D")
	pad.visible = false
	pad.monitoring = false

	# --- the scenery pool: trees then rocks ---
	var decor := Node3D.new()
	_add(root, decor, root, "Decor")
	for i in DECOR_COUNT:
		var d := Node3D.new()
		_add(decor, d, root, "Decor%d" % i)
		# A mix, not eight identical trees. Uniformity is most of why the old
		# forest looked bad — the eye spots the repeat instantly.
		# Six kinds now, not four. Bamboo gives the jungle its one non-green
		# plant and its only strong verticals; the flowering bushes are the
		# only colour anywhere in it.
		if i < 3:
			_build_palm(d, root, i)
		elif i < 7:
			_build_broadleaf(d, root, i)
		elif i < 11:
			_build_fern(d, root, i)
		elif i < 14:
			_build_bamboo(d, root, i)
		elif i < 16:
			_build_flower_bush(d, root, i)
		else:
			_build_rock(d, root, i)

	return _save(root, "res://scenes/track_chunk.tscn")


# =============================================================================
#  PLANTS
#
#  Each plant is built as a LIST OF PARTS and then MERGED into a single mesh
#  with one surface per material. gl_compatibility does no batching, so every
#  MeshInstance3D is its own draw call — a palm made of 12 separate nodes costs
#  12 draw calls, and nine chunks of those blew the budget (measured: 1023).
#  Merged, the same palm costs 2. That is what pays for a jungle dense enough
#  to look like one.
# =============================================================================

func _part(mesh: Mesh, xform: Transform3D, mat_name: String, surface: int = 0) -> Dictionary:
	return {"mesh": mesh, "xform": xform, "mat": mat_name, "surface": surface}


func _coin_cyl(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	cm.rings = 1
	return cm


## A cylinder or cone. 14 sides by default: with smooth normals that reads as
## round. It was 6 — a hexagonal pencil — and on a big screen every trunk,
## stalk and log showed its facets. Pass `sides` for the few things that
## SHOULD be faceted (a cut gem).
func _cyl_mesh(top_r: float, bot_r: float, height: float, sides: int = 14) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	return cm


## A sphere, at least 20 x 10. The callers still ask for the counts the
## low-poly look used (6 x 2 is not a sphere, it is a hexagonal diamond);
## they are raised here so the whole game went smooth in one place.
func _sphere_mesh(radius: float, segments: int, rings: int) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = maxi(segments * 2, 20)
	sm.rings = maxi(rings * 2, 10)
	return sm


## A narrow leaf or grass blade, CENTRED on the origin and running up +Y
## (callers place it by its middle, as they did the PrismMesh it replaces).
## The prism was a hard-edged green triangle — lit flat, it glinted like a
## shard of glass. This is a real blade: tapered, gently folded along the
## midrib and drooping at the tip, so it catches the light the way grass does.
var _leaf_meshes := {}


func _leaf_mesh(width: float, length: float) -> ArrayMesh:
	var key := "%.3f/%.3f" % [width, length]
	if not _leaf_meshes.has(key):
		var rows := 3 if length < 0.35 else 5
		var blade := FK.strap(width, length, length * 0.18, width * 0.12, rows)
		_leaf_meshes[key] = _baked(blade, 0, Transform3D(Basis(), Vector3(0.0, -length * 0.5, 0.0)))
	return _leaf_meshes[key]


## Merges parts into ONE MeshInstance3D, one surface per distinct material.
func _merged(parent: Node, root: Node, node_name: String, parts: Array) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _merge_parts(parts)
	_add(parent, mi, root, node_name)
	_cull_far(mi)
	return mi


## The mesh half of _merged(), for when one mesh is shared by many instances
## (every coin in the game draws the same medallion).
func _merge_parts(parts: Array) -> ArrayMesh:
	var by_mat := {}
	for part in parts:
		var key: String = part["mat"]
		if not by_mat.has(key):
			by_mat[key] = []
		by_mat[key].append(part)

	var am := ArrayMesh.new()
	for key in by_mat:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in by_mat[key]:
			st.append_from(_baked(part["mesh"], int(part.get("surface", 0)), part["xform"]),
				0, Transform3D())
		st.set_material(_mats[key])
		st.commit(am)
	return am


## One surface of a mesh with a transform baked in, NORMALS INCLUDED — done
## properly, with the inverse transpose. SurfaceTool.append_from() just runs
## the normals through the plain basis, which is only right for rotation and
## uniform scale. Measured: a sphere squashed to 0.2 height gets its top
## normals pointing 13 degrees above horizontal instead of 80 — so every
## flattened crown, lily pad and leaf blade in the jungle was being lit as if
## it faced sideways, which is most of why the foliage looked like dark, hard
## faceted gems.
func _baked(mesh: Mesh, surface: int, xf: Transform3D) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = xf * verts[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var nb := xf.basis.inverse().transposed()
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in norms.size():
			norms[i] = (nb * norms[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = norms
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in range(0, tans.size(), 4):
			var t := (xf.basis * Vector3(tans[i], tans[i + 1], tans[i + 2])).normalized()
			tans[i] = t.x
			tans[i + 1] = t.y
			tans[i + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = tans
	# EVERY part leaves here INDEXED. The primitive meshes (BoxMesh,
	# CylinderMesh, SphereMesh) are indexed and the ones generated in code are
	# not, and SurfaceTool cannot mix the two: once any indexed part is in a
	# surface, the vertices of the non-indexed ones are kept but never
	# referenced, so they silently vanish. That is how the stela lost its
	# whole stone body (bevelled, non-indexed) to its cylinder cap (indexed).
	if arrays[Mesh.ARRAY_INDEX] == null:
		var seq := PackedInt32Array()
		seq.resize(verts.size())
		for i in verts.size():
			seq[i] = i
		arrays[Mesh.ARRAY_INDEX] = seq
	# A mirroring transform turns every triangle inside out; wind them back.
	if xf.basis.determinant() < 0.0:
		if arrays[Mesh.ARRAY_INDEX] != null:
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, idx.size() - 2, 3):
				var tmp := idx[i + 1]
				idx[i + 1] = idx[i + 2]
				idx[i + 2] = tmp
			arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## A BROAD tropical leaf — an elephant-ear, not a spike: wide shoulders, a
## pointed tip, a fold along the midrib and a droop (see FK.blade).
func _blade(width: float, length: float, origin: Vector3, spin: float,
		tilt: float) -> Dictionary:
	# A real leaf now: pointed tip, broad shoulders, folded along the midrib
	# and drooping at the end, growing OUT of the stalk top at `origin`,
	# leaning `tilt` from upright. It was a flattened 6 x 2 sphere — a
	# hexagonal lozenge — lit as if it faced sideways.
	var dir := Basis.from_euler(Vector3(tilt, spin, 0.0))
	var mesh := FK.blade(width * 1.7, length * 1.7, length * 0.32, width * 0.16, 4, 6)
	return _part(mesh, Transform3D(dir, origin), "leaf_big")


## A tuft of long grass: a dozen soft blades fanning out of one root, each
## leaning further out the further it is from the middle and drooping at the
## tip. It replaced Kenney's grass model, whose hard-edged triangular spikes
## read as green glass along the edge of the path.
var _tuft_blades := {}


func _grass_tuft(at: Vector3, size: float, spin: float, mat_name: String) -> Array:
	var trng := RandomNumberGenerator.new()
	trng.seed = int(absf(at.x) * 97.0 + absf(at.z) * 13.0)
	var out := []
	var n := 11
	for i in n:
		var len_q := snappedf(trng.randf_range(0.30, 0.62) * size, 0.05)
		var key := "%.2f" % len_q
		if not _tuft_blades.has(key):
			_tuft_blades[key] = FK.strap(0.055, len_q, len_q * 0.35, 0.006, 5)
		var yaw := spin + TAU * float(i) / float(n) + trng.randf_range(-0.25, 0.25)
		var lean := trng.randf_range(0.25, 0.85)
		out.append(_part(_tuft_blades[key],
			Transform3D(Basis.from_euler(Vector3(-lean, yaw, 0.0)), at), mat_name))
	return out


## A soft clump of leaves in place of a squashed sphere (see flora_kit.gd).
## Seeded from where it stands so the same spot always grows the same shape,
## and sized to its radii so its outline stays round up close without
## spending triangles on the small ones.
func _leaf_clump(radii: Vector3, x: float, z: float) -> ArrayMesh:
	var big := maxf(radii.x, maxf(radii.y, radii.z))
	var seg := clampi(int(12.0 + big * 4.0), 12, 26)
	var seed_value := absi(int(x * 13.0) * 31 + int(z * 7.0)) % 64
	return FK.clump(radii, seed_value, 0.18, 0.45, seg, maxi(seg / 2, 7))


## Places a leaf so its BASE sits on `origin`, fanned around Y and drooping.
func _leaf_xform(origin: Vector3, spin: float, droop: float, length: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(droop, spin, 0.0))
	return Transform3D(basis, origin) * Transform3D(Basis(), Vector3(0.0, length * 0.5, 0.0))


## THE ROADSIDE PLANTS are sculpted in tools/flora_trees.gd (palms and
## rainforest trees) and tools/flora_small.gd (undergrowth, bamboo, flowers,
## boulders): smooth tapering trunks, pinnate fronds, real leaf blades, soft
## foliage masses. They replaced the Kenney Nature Kit models, which are
## lovely low-poly art — but low-poly is exactly the faceted, blocky look this
## game grew out of (one of the trees was literally called "tree_blocks").
## Each builder returns merge-list parts in the project's own materials, so
## the wind shader, the fog and the draw-call budget work as before.
const FLORA_TREES := "res://tools/flora_trees.gd"
const FLORA_SMALL := "res://tools/flora_small.gd"


func _flora(module: String, fn: String, index: int) -> Array:
	return (load(module) as GDScript).call(fn, index)


## PALM — four species/ages of palm with arching pinnate fronds.
func _build_palm(parent: Node3D, root: Node, index: int) -> void:
	_merged(parent, root, "Palm", _flora(FLORA_TREES, "palm", index))


## BROADLEAF — rainforest trees: buttress roots, limbs and a layered crown.
func _build_broadleaf(parent: Node3D, root: Node, index: int) -> void:
	_merged(parent, root, "Tree", _flora(FLORA_TREES, "broadleaf", index))


## UNDERGROWTH — the floor plants by the trail: elephant ears, ferns, shrubs.
func _build_fern(parent: Node3D, root: Node, index: int) -> void:
	_merged(parent, root, "Undergrowth", _flora(FLORA_SMALL, "undergrowth", index))


## BAMBOO — a clump of jointed culms with sprays of lance leaves.
func _build_bamboo(parent: Node3D, root: Node, index: int) -> void:
	_merged(parent, root, "Bamboo", _flora(FLORA_SMALL, "bamboo", index))


## FLOWERING PATCH — the only colour in an otherwise entirely green jungle.
func _build_flower_bush(parent: Node3D, root: Node, index: int) -> void:
	_merged(parent, root, "FlowerPatch", _flora(FLORA_SMALL, "flower_patch", index))


## ROCK — a mossy boulder.
func _build_rock(parent: Node3D, root: Node, index: int = 0) -> void:
	_merged(parent, root, "Rock", _flora(FLORA_SMALL, "rock", index))


# =============================================================================
#  HUD SCENE
#  A CanvasLayer draws in 2D on top of everything, untouched by the 3D camera,
#  the lighting or the fog.
# =============================================================================

## A readable label. The dark outline is what keeps white text legible over a
## bright sky AND over dark trees, without needing a background panel.
## The HUD's typeface. A SystemFont, so nothing has to be downloaded or
## bundled: Arial Rounded ships with every Mac and has the fat, friendly
## letterforms of a mobile game; the rest of the list is what other systems
## fall back to, in order of how chunky they are.
var _hud_font: SystemFont
var _mono_font: SystemFont


func _font() -> SystemFont:
	if _hud_font == null:
		_hud_font = SystemFont.new()
		_hud_font.font_names = PackedStringArray(["Arial Rounded MT Bold",
			"Arial Rounded MT", "Avenir Next", "Futura", "Helvetica Neue", "Arial"])
		_hud_font.font_weight = 800
		_hud_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _hud_font


## Fixed-width, for the scoreboard, whose columns only line up in one.
func _mono() -> SystemFont:
	if _mono_font == null:
		_mono_font = SystemFont.new()
		_mono_font.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas",
			"DejaVu Sans Mono", "monospace"])
		_mono_font.font_weight = 700
	return _mono_font


## Big outlined text with a drop shadow — the look every mobile runner uses,
## because a thick dark outline keeps white numbers readable over a sunlit
## sky, a dark canopy and bright sand without ever needing a background.
func _hud_label(text: String, size: int, align: int,
		color := Color(1, 1, 1), outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = _font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline if outline > 0 else maxi(6, int(size * 0.2))
	ls.outline_color = Color(0.10, 0.07, 0.03, 0.95)
	ls.shadow_size = 0
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	ls.shadow_offset = Vector2(3, 5)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A rounded plaque to sit a counter on.
func _plaque(bg: Color, radius: int, border := Color(0, 0, 0, 0), border_w := 0,
		pad_x := 20, pad_y := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.anti_aliasing = true
	return sb


func _panel(style: StyleBoxFlat) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


## Adds a node the script finds by %Name, so the HUD can be rearranged in
## the editor without breaking a single path in hud.gd.
func _uadd(parent: Node, node: Node, root: Node, node_name: String) -> Node:
	_add(parent, node, root, node_name)
	node.unique_name_in_owner = true
	return node


## The coin icon, drawn by a gradient instead of an image file: a bright face,
## a darker gold ring, a thin bright lip and a dark edge.
func _coin_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.50, 0.58, 0.66, 0.80, 0.86, 0.93, 1.0])
	g.colors = PackedColorArray([
		Color(1.00, 0.97, 0.62), Color(1.00, 0.84, 0.24), Color(0.86, 0.58, 0.08),
		Color(1.00, 0.80, 0.20), Color(1.00, 0.86, 0.30), Color(0.55, 0.32, 0.04),
		Color(0.35, 0.20, 0.02, 1.0), Color(0.35, 0.20, 0.02, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 96
	t.height = 96
	return t


func _build_hud_scene() -> bool:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))

	var plaque := _plaque(Color(0.05, 0.09, 0.05, 0.62), 22,
		Color(1.0, 0.84, 0.36, 0.85), 3, 22, 4)
	var gold := Color(1.0, 0.84, 0.28)

	# ---- top right: score, distance, coins --------------------------------
	# Stacked in a right-aligned column the way every runner does it, so the
	# two numbers you care about sit in the one corner you glance at.
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -640.0
	right.offset_right = -28.0
	right.offset_top = 22.0
	right.offset_bottom = 320.0
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uadd(hud, right, hud, "TopRight")

	var score_panel := _panel(plaque)
	score_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_uadd(right, score_panel, hud, "ScorePanel")
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 14)
	score_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(score_panel, score_row, hud, "Row")
	# The multiplier rides on the score as a green badge: it is part of the
	# score, so it lives on the score, and it only appears once it is worth
	# something — the badge popping in IS the feedback.
	var badge := _panel(_plaque(Color(0.30, 0.74, 0.18), 16,
		Color(0.95, 1.0, 0.8), 3, 12, 0))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_uadd(score_row, badge, hud, "MultBadge")
	_uadd(badge, _hud_label("x2", 40, HORIZONTAL_ALIGNMENT_CENTER), hud, "Multiplier")
	var score := _hud_label("0", 64, HORIZONTAL_ALIGNMENT_RIGHT)
	score.custom_minimum_size = Vector2(150, 0)
	_uadd(score_row, score, hud, "Score")

	var dist := _hud_label("0 m", 30, HORIZONTAL_ALIGNMENT_RIGHT, Color(0.90, 0.97, 0.84))
	dist.size_flags_horizontal = Control.SIZE_SHRINK_END
	_uadd(right, dist, hud, "Distance")

	var coin_panel := _panel(plaque)
	coin_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_uadd(right, coin_panel, hud, "CoinPanel")
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 10)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(coin_panel, coin_row, hud, "Row")
	var icon := TextureRect.new()
	icon.texture = _coin_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(46, 46)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(coin_row, icon, hud, "Icon")
	var coins := _hud_label("0", 46, HORIZONTAL_ALIGNMENT_RIGHT, gold)
	coins.custom_minimum_size = Vector2(70, 0)
	_uadd(coin_row, coins, hud, "Coins")

	# ---- top left: mode, rival, shield ------------------------------------
	var left := VBoxContainer.new()
	left.offset_left = 28.0
	left.offset_right = 640.0
	left.offset_top = 22.0
	left.offset_bottom = 320.0
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uadd(hud, left, hud, "TopLeft")

	var mode_pill := _panel(_plaque(Color(0.12, 0.36, 0.14, 0.80), 14,
		Color(0.7, 1.0, 0.6, 0.6), 2, 14, 2))
	mode_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_uadd(left, mode_pill, hud, "ModePill")
	_uadd(mode_pill, _hud_label("FREE RUN", 22, HORIZONTAL_ALIGNMENT_LEFT,
		Color(0.86, 1.0, 0.78), 6), hud, "Mode")

	# Who you are chasing, and how far. The whole competitive loop in one
	# plaque: not "your best was 1,240" after the fact, but "AAA is 180
	# points away" while you can still do something about it.
	var chase := _panel(plaque)
	chase.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_uadd(left, chase, hud, "Chase")
	var chase_box := VBoxContainer.new()
	chase_box.add_theme_constant_override("separation", -6)
	chase_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(chase, chase_box, hud, "Box")
	_uadd(chase_box, _hud_label("CHASING AAA", 24, HORIZONTAL_ALIGNMENT_LEFT, gold, 6),
		hud, "ChaseWho")
	_uadd(chase_box, _hud_label("0 TO GO", 36, HORIZONTAL_ALIGNMENT_LEFT), hud, "ChaseGap")


	# ---- bottom left: power-up timers -------------------------------------
	# Bars, not numbers: how much is LEFT is a length you read in your
	# peripheral vision, where a counting number has to be looked at.
	var powers := VBoxContainer.new()
	powers.anchor_top = 1.0
	powers.anchor_bottom = 1.0
	powers.offset_left = 28.0
	powers.offset_right = 560.0
	powers.offset_top = -300.0
	powers.offset_bottom = -28.0
	powers.alignment = BoxContainer.ALIGNMENT_END
	powers.add_theme_constant_override("separation", 10)
	powers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uadd(hud, powers, hud, "Powerups")
	# One row per power-up, each in ITS colour and with ITS icon — the same
	# colour as its glow on the track and its banner when you grab it, so the
	# three are obviously one thing. The plank has no clock: it is a thing you
	# hold until it saves you, so its row says so instead of draining.
	for def in [["Magnet", "MAGNET", Color(1.0, 0.30, 0.22), 0],
			["Double", "2X SCORE", Color(0.82, 0.45, 1.0), 2],
			["Spring", "SPRING", Color(0.35, 0.92, 1.0), 3],
			["Plank", "SURF PLANK", Color(0.35, 0.60, 1.0), 1]]:
		var row := _panel(_plaque(Color(0.05, 0.09, 0.05, 0.70), 22, def[2], 3, 16, 4))
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_uadd(powers, row, hud, "Shield" if def[0] == "Plank" else "Power" + String(def[0]))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add(row, hb, hud, "Row")
		var picon := Control.new()
		picon.set_script(load("res://scripts/power_icon.gd"))
		picon.set("kind", def[3])
		picon.custom_minimum_size = Vector2(44, 44)
		picon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_add(hb, picon, hud, "Icon")
		var name_l := _hud_label(String(def[1]), 26, HORIZONTAL_ALIGNMENT_LEFT, def[2], 6)
		name_l.custom_minimum_size = Vector2(150, 0)
		_add(hb, name_l, hud, "Name")
		if def[0] == "Plank":
			_add(hb, _hud_label("SAVES 1 CRASH", 22, HORIZONTAL_ALIGNMENT_LEFT,
				Color(0.9, 0.95, 1.0), 6), hud, "Note")
			continue
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.step = 0.001
		bar.value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background",
			_plaque(Color(0.0, 0.0, 0.0, 0.55), 10, Color(1, 1, 1, 0.25), 2, 0, 0))
		bar.add_theme_stylebox_override("fill", _plaque(def[2], 10, Color(0,0,0,0), 0, 0, 0))
		_add(hb, bar, hud, "Bar")

	# ---- the pickup flash: a quick wash of the power-up's colour ----------
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	_uadd(hud, flash, hud, "Flash")

	# ---- the near-miss / rival pop, upper middle --------------------------
	var nice := _hud_label("", 60, HORIZONTAL_ALIGNMENT_CENTER, gold, 14)
	nice.anchor_left = 0.0
	nice.anchor_right = 1.0
	# High, in the canopy band above the far end of the trail. At 0.26 it
	# sat right where the next obstacles appear, 25-40 m out.
	nice.anchor_top = 0.11
	nice.anchor_bottom = 0.11
	nice.offset_top = -45.0
	nice.offset_bottom = 45.0
	_uadd(hud, nice, hud, "NearMiss")

	# A second, smaller line under the pop, for what the pop was about.
	var toast := _hud_label("", 34, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1), 9)
	toast.anchor_left = 0.0
	toast.anchor_right = 1.0
	toast.anchor_top = 0.11
	toast.anchor_bottom = 0.11
	toast.offset_top = 44.0
	toast.offset_bottom = 90.0
	_uadd(hud, toast, hud, "Toast")

	# ---- the Expedition Journal: three missions and the rank --------------
	# Shown on the title and game over screens, down the right-hand side, so
	# the next thing to go for is on screen at the moment you decide to run.
	var journal := _panel(_plaque(Color(0.05, 0.10, 0.05, 0.82), 24,
		Color(1.0, 0.84, 0.36, 0.8), 3, 26, 16))
	journal.anchor_left = 1.0
	journal.anchor_right = 1.0
	journal.anchor_top = 0.5
	journal.anchor_bottom = 0.5
	journal.offset_left = -700.0
	journal.offset_right = -40.0
	# If the text is ever wider than the panel, grow LEFT, into the screen,
	# not off its right-hand edge.
	journal.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	journal.offset_top = -120.0
	journal.offset_bottom = 110.0
	journal.visible = false
	_uadd(hud, journal, hud, "Journal")
	var jbox := VBoxContainer.new()
	jbox.add_theme_constant_override("separation", 12)
	jbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(journal, jbox, hud, "Box")
	_add(jbox, _hud_label("EXPEDITION JOURNAL", 30, HORIZONTAL_ALIGNMENT_LEFT, gold, 8),
		hud, "Heading")
	_uadd(jbox, _hud_label("RANK 0", 24, HORIZONTAL_ALIGNMENT_LEFT,
		Color(0.70, 1.0, 0.55), 6), hud, "JournalRank")
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_uadd(jbox, row, hud, "Mission%d" % i)
		var tick := Panel.new()
		tick.custom_minimum_size = Vector2(32, 32)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.add_theme_stylebox_override("panel",
			_plaque(Color(0, 0, 0, 0.4), 9, Color(1, 1, 1, 0.6), 3, 0, 0))
		_add(row, tick, hud, "Tick")
		var mt := _hud_label("", 26, HORIZONTAL_ALIGNMENT_LEFT, Color(1, 1, 1), 6)
		mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_add(row, mt, hud, "Text")
		_add(row, _hud_label("", 24, HORIZONTAL_ALIGNMENT_RIGHT, gold, 6), hud, "Count")

	# ---- the controls hint, low and out of the way ------------------------
	# It used to sit mid-screen, which put two lines of text straight across
	# the far end of the track — exactly where the first obstacles appear.
	# The bottom edge is the one strip nothing ever comes from.
	var hint := _panel(_plaque(Color(0.03, 0.06, 0.03, 0.66), 26,
		Color(1, 1, 1, 0.35), 2, 28, 10))
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -560.0
	hint.offset_right = 560.0
	hint.offset_top = -118.0
	hint.offset_bottom = -40.0
	_uadd(hud, hint, hud, "Hint")
	_add(hint, _hud_label(
		"\u2190 \u2192  SWITCH LANE        \u2191 / SPACE  JUMP        \u2193  SLIDE",
		30, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1), 6), hud, "Label")

	# ---- the danger flash: red at the edges of the screen on a stumble ----
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	dg.colors = PackedColorArray([Color(0.9, 0.05, 0.02, 0.0), Color(0.9, 0.05, 0.02, 0.0),
		Color(0.85, 0.02, 0.0, 0.85)])
	var dt := GradientTexture2D.new()
	dt.gradient = dg
	dt.fill = GradientTexture2D.FILL_RADIAL
	dt.fill_from = Vector2(0.5, 0.5)
	dt.fill_to = Vector2(1.05, 0.5)
	dt.width = 256
	dt.height = 256
	var danger := TextureRect.new()
	danger.texture = dt
	danger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	danger.stretch_mode = TextureRect.STRETCH_SCALE
	danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger.modulate = Color(1, 1, 1, 0)
	_uadd(hud, danger, hud, "Danger")
	# Moved to the back so every counter draws over it.
	hud.move_child(danger, 0)

	# ---- speed lines: streaks at the screen edges near top speed -----------
	var lines := ColorRect.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lm := ShaderMaterial.new()
	lm.shader = load("res://shaders/speed_lines.gdshader")
	lines.material = lm
	_uadd(hud, lines, hud, "SpeedLines")
	hud.move_child(lines, 0)

	# ---- the coach: JUMP / SLIDE / GO for the obstacle in your lane --------
	# Bottom centre, where the controls bar sat for the first few seconds:
	# the one strip of the screen no obstacle ever comes from, just under the
	# runner, so your eyes never leave the track to read it.
	var coach := Control.new()
	coach.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach.set_script(load("res://scripts/coach.gd"))
	_uadd(hud, coach, hud, "Coach")
	var card := _panel(_plaque(Color(0.03, 0.06, 0.03, 0.72), 26, Color(1, 1, 1, 0.35), 3, 34, 6))
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -330.0
	card.offset_right = 330.0
	card.offset_top = -170.0
	card.offset_bottom = -34.0
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_uadd(coach, card, hud, "CoachCard")
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", -8)
	cbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(card, cbox, hud, "Box")
	_uadd(cbox, _hud_label("JUMP", 76, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1), 16),
		hud, "CoachVerb")
	_uadd(cbox, _hud_label("", 28, HORIZONTAL_ALIGNMENT_CENTER, Color(0.92, 0.97, 0.88), 7),
		hud, "CoachSub")
	# A name tag that floats over a power-up, a landmark or the bounce pad the
	# first few times you meet one: WHAT it is, before you decide to go for it.
	var ctag := _panel(_plaque(Color(0.03, 0.06, 0.03, 0.45), 16, Color(1, 1, 1, 0.8), 3, 16, 4))
	ctag.custom_minimum_size = Vector2(240, 0)
	_uadd(coach, ctag, hud, "CoachTag")
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", -4)
	tbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(ctag, tbox, hud, "Box")
	_uadd(tbox, _hud_label("", 32, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1), 8), hud, "TagName")
	_uadd(tbox, _hud_label("", 22, HORIZONTAL_ALIGNMENT_CENTER, Color(0.92, 0.97, 0.86), 5),
		hud, "TagSub")

	# ---- the title screen, shown once when the game opens ------------------
	var title_screen := Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uadd(hud, title_screen, hud, "TitleScreen")
	# A soft dark band behind the logo so it reads over bright sky and leaves.
	var tg := Gradient.new()
	tg.offsets = PackedFloat32Array([0.0, 1.0])
	tg.colors = PackedColorArray([Color(0.02, 0.06, 0.02, 0.55), Color(0.02, 0.06, 0.02, 0.0)])
	var tt := GradientTexture2D.new()
	tt.gradient = tg
	tt.fill_from = Vector2(0.5, 0.0)
	tt.fill_to = Vector2(0.5, 1.0)
	var band := TextureRect.new()
	band.texture = tt
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.anchor_right = 1.0
	band.anchor_bottom = 0.45
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(title_screen, band, hud, "Band")

	var logo := VBoxContainer.new()
	logo.anchor_left = 0.0
	logo.anchor_right = 0.55
	logo.offset_left = 60.0
	logo.offset_top = 50.0
	logo.offset_bottom = 420.0
	logo.add_theme_constant_override("separation", -40)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uadd(title_screen, logo, hud, "Logo")
	var l1 := _hud_label("JUNGLE", 150, HORIZONTAL_ALIGNMENT_CENTER, gold, 30)
	l1.label_settings.shadow_size = 1
	l1.label_settings.shadow_offset = Vector2(8, 12)
	l1.label_settings.shadow_color = Color(0, 0, 0, 0.5)
	_add(logo, l1, hud, "Jungle")
	var l2 := _hud_label("DASH", 190, HORIZONTAL_ALIGNMENT_CENTER, Color(0.50, 0.96, 0.30), 34)
	l2.label_settings.shadow_size = 1
	l2.label_settings.shadow_offset = Vector2(8, 12)
	l2.label_settings.shadow_color = Color(0, 0, 0, 0.5)
	_add(logo, l2, hud, "Dash")
	var tag := _hud_label("run.  jump.  don't get caught.", 34, HORIZONTAL_ALIGNMENT_CENTER,
		Color(1.0, 0.97, 0.88), 9)
	_add(logo, tag, hud, "Tagline")

	var press := _panel(_plaque(Color(0.30, 0.74, 0.18), 36, Color(0.95, 1.0, 0.78), 6, 46, 12))
	press.anchor_left = 0.5
	press.anchor_right = 0.5
	press.anchor_top = 1.0
	press.anchor_bottom = 1.0
	press.offset_left = -330.0
	press.offset_right = 330.0
	press.offset_top = -250.0
	press.offset_bottom = -150.0
	_uadd(title_screen, press, hud, "PressStart")
	_add(press, _hud_label("PRESS SPACE TO RUN", 50, HORIZONTAL_ALIGNMENT_CENTER,
		Color(1, 1, 1), 12), hud, "Label")

	var title_best := _hud_label("", 36, HORIZONTAL_ALIGNMENT_CENTER, gold, 10)
	title_best.anchor_left = 0.0
	title_best.anchor_right = 1.0
	title_best.anchor_top = 1.0
	title_best.anchor_bottom = 1.0
	title_best.offset_top = -134.0
	title_best.offset_bottom = -90.0
	_uadd(title_screen, title_best, hud, "TitleBest")
	var title_help := _hud_label(
		"\u2190 \u2192 lanes     \u2191 jump     \u2193 slide     M  daily challenge     C  coach",
		26, HORIZONTAL_ALIGNMENT_CENTER, Color(0.92, 0.97, 0.88), 7)
	title_help.anchor_left = 0.0
	title_help.anchor_right = 1.0
	title_help.anchor_top = 1.0
	title_help.anchor_bottom = 1.0
	title_help.offset_top = -84.0
	title_help.offset_bottom = -44.0
	_uadd(title_screen, title_help, hud, "TitleHelp")
	# Shown only when the game is running squeezed inside the Godot editor's
	# Game tab (hud.gd checks), where it is drawn a third of its real size.
	var embed_note := _hud_label("", 26, HORIZONTAL_ALIGNMENT_CENTER, Color(1.0, 0.86, 0.35), 7)
	embed_note.anchor_left = 0.0
	embed_note.anchor_right = 1.0
	embed_note.offset_top = 10.0
	embed_note.offset_bottom = 48.0
	embed_note.visible = false
	_uadd(title_screen, embed_note, hud, "EmbedNote")

	# ---- the game over screen, hidden until you die -----------------------
	var over := Control.new()
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.visible = false
	_uadd(hud, over, hud, "GameOver")

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.05, 0.02, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(over, dim, hud, "Dim")

	# Full-rect container that centres its children, rather than
	# PRESET_CENTER: that bakes "centre me" into pixel offsets computed from
	# the container's size while this builder runs — which is zero — and the
	# panel then sits off-centre forever.
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(over, box, hud, "Box")

	_uadd(box, _hud_label("GAME OVER", 96, HORIZONTAL_ALIGNMENT_CENTER, gold, 20),
		hud, "Title")
	_uadd(box, _hud_label("0", 110, HORIZONTAL_ALIGNMENT_CENTER, Color(1, 1, 1), 20),
		hud, "FinalScore")
	_uadd(box, _hud_label("NEW BEST!", 44, HORIZONTAL_ALIGNMENT_CENTER,
		Color(1.0, 0.55, 0.75), 12), hud, "NewBest")
	_uadd(box, _hud_label("0 m    0 coins", 34, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0.90, 0.97, 0.84), 8), hud, "Stats")
	# WHY: what you hit and what to do about it next time.
	_uadd(box, _hud_label("", 34, HORIZONTAL_ALIGNMENT_CENTER, Color(1.0, 0.86, 0.45), 9),
		hud, "Why")

	var board := _panel(_plaque(Color(0.04, 0.08, 0.04, 0.78), 24,
		Color(1.0, 0.84, 0.36, 0.7), 3, 34, 16))
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add(box, board, hud, "Board")
	var result := Label.new()
	result.text = ""
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var rs := LabelSettings.new()
	rs.font = _mono()
	rs.font_size = 30
	rs.font_color = Color(0.96, 0.96, 0.90)
	rs.line_spacing = 4
	result.label_settings = rs
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uadd(board, result, hud, "Result")

	var button := Button.new()
	button.text = "RUN AGAIN"
	button.custom_minimum_size = Vector2(380, 92)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", _font())
	button.add_theme_font_size_override("font_size", 44)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.9))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 1, 0.85))
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.25, 0.04))
	button.add_theme_constant_override("outline_size", 10)
	button.add_theme_stylebox_override("normal",
		_plaque(Color(0.32, 0.76, 0.18), 30, Color(0.95, 1.0, 0.78), 5, 30, 8))
	button.add_theme_stylebox_override("hover",
		_plaque(Color(0.40, 0.86, 0.24), 30, Color(1, 1, 0.9), 5, 30, 8))
	button.add_theme_stylebox_override("pressed",
		_plaque(Color(0.24, 0.60, 0.12), 30, Color(0.95, 1.0, 0.78), 5, 30, 8))
	button.add_theme_stylebox_override("focus",
		_plaque(Color(0.32, 0.76, 0.18), 30, Color(1, 1, 1), 6, 30, 8))
	_uadd(box, button, hud, "RestartButton")

	_uadd(box, _hud_label("", 22, HORIZONTAL_ALIGNMENT_CENTER,
		Color(0.85, 0.92, 0.80), 6), hud, "Footer")

	return _save(hud, "res://scenes/hud.tscn")


# =============================================================================
#  THE CHASERS — Bruno the Stationmaster and Snapper
#
#  Built from boxes like the runner, and built to be seen from BEHIND: you
#  meet them over the monkey's shoulder, so the silver back, the too-small
#  cap and the crocodile's swinging tail are where the detail goes. Every
#  moving part hangs off a named pivot that scripts/chaser.gd swings.
# =============================================================================

func _build_chaser_scene() -> bool:
	var root := Node3D.new()
	root.name = "Chaser"
	root.set_script(load("res://scripts/chaser.gd"))

	# BRUNO, a silverback gorilla in a knuckle-walking charge, and SNAPPER, a
	# Nile crocodile at a high-walk gallop — sculpted in tools/char_gorilla.gd
	# and tools/char_croc.gd as smooth, rounded, anatomically believable
	# animals. They used to be a gorilla in a stationmaster's waistcoat and
	# cap with a lantern, leading a box crocodile on a leash; the costume and
	# the leash went with the boxes, because real animals are what a jungle
	# chase needs. The rig names (ArmL/Elbow, LegL/R, Head; Head/Jaw,
	# Tail0..4, Leg0..3) are what scripts/chaser.gd animates.
	var bruno := Node3D.new()
	_add(root, bruno, root, "Bruno")
	var body := Node3D.new()
	_add(bruno, body, root, "Body")
	(load("res://tools/char_gorilla.gd") as GDScript).build(body, root)

	var croc := Node3D.new()
	_add(root, croc, root, "Snapper")
	var cb := Node3D.new()
	_add(croc, cb, root, "Body")
	(load("res://tools/char_croc.gd") as GDScript).build(cb, root)

	return _save(root, "res://scenes/chaser.tscn")


# =============================================================================
#  MAIN SCENE
# =============================================================================

func _build_main_scene() -> bool:
	var root := Node3D.new()
	root.name = "Main"

	# --- sky, sun and the fog that hides the end of the track ---
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	# THE HORIZON COLOUR IS SHARED THREE WAYS: the sky above the horizon, the
	# ground below it, and the fog. That's what makes the end of the track
	# invisible — geometry fades to exactly the colour of whatever is behind
	# it. Get these out of step and the track's cut-off edge shows up as a
	# coloured wedge at the vanishing point.
	# A MID-TONE teal haze, not a pale one. The old (0.66, 0.75, 0.69) turned
	# the far end of the tunnel of trees into the brightest thing on screen,
	# and every obstacle 40-60 m out was seen against that glare: the stela
	# scored 1.03:1 against it, i.e. invisible. At mid luminance BOTH halves of
	# the palette separate from it — dark things and bright things alike —
	# and a dim blue-green depth reads as deep jungle rather than as fog.
	var horizon := Color(0.34, 0.41, 0.38)

	# A cartoon sky with crisp two-tone clouds — see shaders/sky.gdshader.
	# The whole lower half of it is the horizon colour, deliberately. Fog
	# fades distant geometry TO the fog colour — it does not fade it to
	# "whatever the sky is". So if the sky below the horizon is a different
	# colour, distant trees stay faintly visible against it and popping shows.
	# Making the whole lower sky the fog colour is what makes the far
	# distance genuinely empty.
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("horizon_color", horizon)
	# The lighting keeps the old bright horizon (see the shader).
	sky_mat.set_shader_parameter("sky_low_color", Color(0.66, 0.75, 0.69))
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# The canopy hides much of the sky, so the ambient that used to light
	# the scene from above is largely blocked. Push it back up or the
	# whole jungle floor sinks into mud.
	env.ambient_light_energy = 1.45
	# GREEN SHADE. Pure sky ambient is blue, so everything in shadow — the
	# dappled shade of a tree on a bush, the underside of a leaf — went a
	# cold teal-navy, which read as dark holes in the foliage once the
	# lighting went smooth. Under a real canopy the shade is lit by light
	# bounced off leaves and earth, and it is green-gold. Mixing that in with
	# the sky keeps the shadows the colour of the jungle.
	env.ambient_light_color = Color(0.56, 0.64, 0.42)
	env.ambient_light_sky_contribution = 0.55

	# The track only exists for ~240 m ahead, so without this you would SEE it
	# stop in mid-air. Depth fog fades everything out before that edge.
	# fog_depth_end MUST stay below the track's reach or the seam shows.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	# THE ONE THAT CATCHES EVERYONE: in depth mode the fog amount is still
	# MULTIPLIED by fog_density, and its default is 0.01 — i.e. 1% opaque.
	# Leave it alone and the fog looks completely broken. It must be 1.0.
	env.fog_density = 1.0
	# CLEAR AIR WHERE YOU DECIDE. At top speed you choose what to do about an
	# obstacle 40-60 m out, and the old fog (60 .. 150 m) had already started
	# eating it there — the next row down the track was a grey smudge in a
	# pale glare. Fog now starts past 100 m and is opaque at 200 m, still
	# short of the 216 m of track that always exists, so its end stays hidden.
	env.fog_depth_begin = 100.0     # perfectly clear inside this distance
	env.fog_depth_end = 200.0       # fully opaque here — inside the track
	env.fog_depth_curve = 1.4       #   and eased, so it stays thin for longer
	# Exactly the sky's horizon colour — see the note above.
	env.fog_light_color = horizon
	env.fog_light_energy = 1.0
	# Leave the sky itself alone. Setting this to 1.0 does hide the seam very
	# slightly better, but it replaces the ENTIRE sky dome with one flat
	# colour and you lose the gradient.
	env.fog_sky_affect = 0.0

	# --- ground mist ---
	# fog_height/fog_height_density DO work under gl_compatibility (verified:
	# turning them on changed 91/255 of the average pixel). They add fog BELOW
	# a given height, which is exactly the low haze that sits between jungle
	# trunks in the morning.
	#
	# The density is the trap: at 0.35 the entire scene below the canopy went
	# white and the player vanished. It wants to be tiny.
	# OFF. It softened everything at running height into the same haze —
	# exactly where the obstacles are. Clarity beats atmosphere.
	env.fog_height = 3.5
	env.fog_height_density = 0.0

	var we := WorldEnvironment.new()
	we.environment = env
	_add(root, we, root, "WorldEnvironment")

	# --- colour grade ---
	# The cheapest large win available. ACES tonemapping plus a small
	# saturation push stops the greens reading as flat poster paint.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# ACES already lifts midtones, so exposure has to come DOWN to compensate —
	# leaving it at 1.0+ blows the dirt path out to near-white sand and pushes
	# the greens into neon. Measured by rendering: 1.15 was far too hot.
	env.tonemap_exposure = 0.95
	env.tonemap_white = 1.0

	# GLOW. Verified present in this build for the Compatibility renderer
	# (drivers/gles3/effects/glow.cpp); SSAO is NOT — every SSAO symbol in the
	# binary belongs to the Forward+ renderer, so switching it on here would be
	# a silent no-op.
	#
	# The emissive materials already exist and, without this, are just flat
	# bright colours: the coins, the magnet's pale tips, the surge gem and the
	# trampoline's markings. Glow is what turns them into light sources.
	env.glow_enabled = true
	# Only the genuinely bright things bloom. Lower and the whole sunlit path
	# starts to haze over, which reads as a dirty lens rather than as glow.
	# 1.0 was far too low, and the mistake only showed once the obstacle palette
	# was rebuilt around BRIGHT colours: ob_stone at 0.82 albedo under full sun
	# comfortably exceeds 1.0, so the threshold that was meant to catch glowing
	# pickups started blooming every lit surface in the game. Combined with the
	# note below that is most of what "blurry" was.
	env.glow_hdr_threshold = 1.5
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	# NOTE: this line does nothing on this renderer. The Compatibility backend
	# always screen-blends glow whatever the Environment asks for — so the soft
	# blend intended here was silently the strongest one available, which is
	# why the intensity above had to come down as well. Kept, and labelled,
	# because it WOULD apply if the project ever moved to Forward+.
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Sunlight scattering through the fog: the fog goes warm when you look
	# toward the sun and stays cool away from it, instead of being one flat
	# grey wash at every angle. Verified as a live uniform in the GLES3 scene
	# shader, so it genuinely does something on this renderer.
	# Off now the sun is behind the camera: scatter would brighten the fog
	# BEHIND you, which you never see, and cool the tunnel mouth ahead.
	env.fog_sun_scatter = 0.0
	env.adjustment_enabled = true
	# Pushed hard on purpose. A mobile runner is a toy, not a nature
	# documentary: the reference look is saturated, sunny and bright, and the
	# old grade (1.05) left the jungle looking like a tech demo.
	env.adjustment_saturation = 1.32
	env.adjustment_contrast = 1.10
	env.adjustment_brightness = 1.03

	# AMBIENT OCCLUSION. Only possible because the game now runs on Forward+;
	# on the Compatibility renderer every SSAO symbol in the engine binary was
	# absent. Low-poly art lives or dies on contact shadows — without them
	# every object looks pasted onto the ground rather than sitting on it.
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	# Softer than it was (1.8 / 1.4). Under the old hard toon light the AO
	# only ever showed in creases; on smooth, lumpy foliage at that strength
	# it pooled into black holes wherever two bushes met.
	env.ssao_intensity = 1.2
	env.ssao_power = 1.1
	env.ssao_detail = 0.6

	# --- key light: a warm, fairly high sun ---
	var sun := DirectionalLight3D.new()
	# Lower in the sky than it was (-52). A 1.8 m runner casts 1.8/tan(52) =
	# 1.41 m of shadow at the old angle and 1.8/tan(38) = 2.30 m at this one —
	# 63% more. The shadow is the main thing telling you where the character is
	# relative to the ground, so a longer one is a readability win as much as a
	# prettier one, and low sun through a jungle is what the scene wants anyway.
	#
	# And from BEHIND the camera. It used to shine along (0.70, -0.62, +0.37) —
	# TOWARDS the lens — which put every surface of the runner you can see in
	# its own shadow: the monkey's back scored N.L = -0.37, no sunlight at all,
	# and that, not its palette, is why it read as a dark blob. Over the
	# shoulder, the back you spend the whole game looking at is lit (N.L about
	# +0.64), every obstacle's face is lit as you approach it, and the shadows
	# fall forward onto the rails ahead where you can see them.
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-30.0), 0.0)
	sun.light_color = Color(1.0, 0.94, 0.80)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	# Cartoon shadows are TINTED, not black. Full-strength shadows under toon
	# shading turn the undergrowth into holes; three-quarters keeps the shape
	# and the grounding while letting the colour through.
	sun.shadow_opacity = 0.72
	# FOUR splits over a SHORT range — which is both sharper and cheaper than
	# where this started.
	#
	# Shadow cost is (range x splits x caster triangles). The original was 70 m,
	# 4 splits, 29,005 casters: about 270,000 triangles of shadow work a frame,
	# more than the picture itself cost. Dropping to 2 splits fixed the cost and
	# broke the LOOK — halving the split count doubles the ground each one
	# covers, so the shadow map is spread twice as thin and everything goes
	# soft. A player described the result as "blurry", which it was.
	#
	# The right lever was the other two terms. With the range at 45 m and the
	# undergrowth no longer casting, 4 splits costs about 104,000 — still 61%
	# below the original, while the nearest split now covers ~4.5 m instead of
	# ~7 m, so shadows near the runner are SHARPER than they have ever been.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# Only shadow the first 70 m. Everything past that is deep in fog anyway,
	# and concentrating the shadow map on the near field makes the shadows
	# near the player noticeably crisper.
	# 45 m, not 70. Fog starts at 60 m, so shadows past that were being drawn
	# into haze. This is the cheapest 35% saving available.
	sun.directional_shadow_max_distance = 60.0
	# Keep the first split as tight as before (~4.5 m) while reaching further,
	# so obstacles 30-50 m out sit on their shadows instead of floating.
	sun.directional_shadow_split_1 = 0.075
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.45
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	_add(root, sun, root, "Sun")

	# --- rim light: warm, from ahead, no shadows ---
	# Where the sun used to be. Coming at the camera it catches the EDGES of
	# everything — the monkey's outline, the tops of the rails, the lip of each
	# obstacle — with a thin warm line, which is what separates a shape from a
	# busy background better than any amount of colour.
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-118.0), 0.0)
	fill.light_color = Color(1.0, 0.85, 0.62)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	_add(root, fill, root, "FillLight")

	# --- the player (added BEFORE the track manager so its _ready runs first) ---
	var player: Node3D = load("res://scenes/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3.ZERO
	root.add_child(player)
	player.owner = root

	# --- the endless track ---
	var track := Node3D.new()
	track.set_script(load("res://scripts/track_manager.gd"))
	_add(root, track, root, "TrackManager")
	# So the coach can find the track without a path.
	track.add_to_group("track", true)
	track.set("chunk_scene", load("res://scenes/track_chunk.tscn"))
	track.set("player", player)

	# --- Bruno and Snapper, on your tail ---
	var chaser: Node3D = load("res://scenes/chaser.tscn").instantiate()
	chaser.name = "Chaser"
	root.add_child(chaser)
	chaser.owner = root

	# --- the jungle soundbed ---
	var amb := AudioStreamPlayer.new()
	amb.set_script(load("res://scripts/ambience.gd"))
	_add(root, amb, root, "Ambience")

	# --- the on-screen display ---
	var hud: CanvasLayer = load("res://scenes/hud.tscn").instantiate()
	hud.name = "HUD"
	root.add_child(hud)
	hud.owner = root

	# --- the camera ---
	var cam := Camera3D.new()
	cam.set_script(load("res://scripts/follow_camera.gd"))
	# Where follow_camera.gd will put it anyway, so frame one matches.
	cam.position = Vector3(0.0, 4.4, 7.2)
	cam.fov = 52.0
	cam.current = true
	_add(root, cam, root, "FollowCamera")
	cam.set("target", player)

	# --- air: falling leaves and drifting pollen, carried by the camera ---
	# Emitted in WORLD space from a box out ahead of the lens, so the camera
	# runs through them: at 20 m/s they stream past, which sells speed better
	# than anything painted on the track. Two draw calls between them.
	var leaves := CPUParticles3D.new()
	leaves.amount = 40
	leaves.lifetime = 3.2
	leaves.preprocess = 3.0
	leaves.local_coords = false
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(9.0, 2.5, 14.0)
	leaves.position = Vector3(0.0, 2.5, -18.0)
	leaves.direction = Vector3(0.3, -1.0, 0.0)
	leaves.spread = 35.0
	leaves.initial_velocity_min = 0.4
	leaves.initial_velocity_max = 1.2
	leaves.gravity = Vector3(0.0, -0.9, 0.0)
	leaves.angular_velocity_min = -220.0
	leaves.angular_velocity_max = 220.0
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	# Small: a leaf drifting past close to the lens was a screen-sized
	# yellow triangle that looked like an arrow.
	leaves.scale_amount_min = 0.5
	leaves.scale_amount_max = 0.9
	var lg := Gradient.new()
	lg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	lg.colors = PackedColorArray([Color(0.28, 0.44, 0.14), Color(0.33, 0.36, 0.14),
		Color(0.22, 0.34, 0.12)])
	leaves.color_initial_ramp = lg
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.vertex_color_use_as_albedo = true
	# Without this the ramp colours are read as linear and blow out to cream —
	# 40 cream flakes drifting through the lanes, the colour of a stela.
	leaf_mat.vertex_color_is_srgb = true
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	leaf_mat.roughness = 0.6
	leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	leaf_mat.billboard_keep_scale = true
	# A real little leaf, not a prism: pointed, folded, curled.
	var leaf_mesh := FK.blade(0.12, 0.2, 0.03, 0.015, 2, 4)
	leaf_mesh.surface_set_material(0, leaf_mat)
	leaves.mesh = leaf_mesh
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(cam, leaves, root, "Leaves")

	var pollen := CPUParticles3D.new()
	pollen.amount = 110
	pollen.lifetime = 2.6
	pollen.preprocess = 2.6
	pollen.local_coords = false
	pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pollen.emission_box_extents = Vector3(7.0, 2.0, 12.0)
	pollen.position = Vector3(0.0, 0.5, -14.0)
	pollen.direction = Vector3(0.0, 1.0, 0.0)
	pollen.spread = 180.0
	pollen.initial_velocity_min = 0.05
	pollen.initial_velocity_max = 0.3
	pollen.gravity = Vector3.ZERO
	var pg := Gradient.new()
	pg.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	pg.colors = PackedColorArray([Color(1, 1, 0.8, 0.0), Color(1, 1, 0.8, 0.9),
		Color(1, 1, 0.8, 0.9), Color(1, 1, 0.8, 0.0)])
	pollen.color_ramp = pg
	var dot := Gradient.new()
	dot.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	dot.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var dtex := GradientTexture2D.new()
	dtex.gradient = dot
	dtex.fill = GradientTexture2D.FILL_RADIAL
	dtex.fill_from = Vector2(0.5, 0.5)
	dtex.fill_to = Vector2(0.5, 0.0)
	dtex.width = 16
	dtex.height = 16
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	pm.albedo_texture = dtex
	var pquad := QuadMesh.new()
	# Small, so a mote drifting close to the lens never looks like a
	# power-up's glowing bubble.
	pquad.size = Vector2(0.035, 0.035)
	pquad.material = pm
	pollen.mesh = pquad
	pollen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(cam, pollen, root, "Pollen")

	return _save(root, "res://scenes/main.tscn")


# =============================================================================
#  PROJECT SETTINGS + INPUT MAP
# =============================================================================

func _key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	# physical_keycode = the key's PHYSICAL POSITION, so WASD still works on
	# AZERTY/QWERTZ layouts. Always prefer this over `keycode`.
	ev.physical_keycode = keycode
	return ev


func _action(action_name: String, keys: Array) -> void:
	var events := []
	for k in keys:
		events.append(_key_event(k))
	ProjectSettings.set_setting("input/" + action_name,
		{"deadzone": 0.2, "events": events})


func _write_input_map() -> void:
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_action("duck", [KEY_S, KEY_DOWN, KEY_SHIFT])


func _write_project_settings() -> void:
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main.tscn")
	# Registers GameState as a global singleton. The leading "*" tells Godot to
	# instance the script as a Node and add it to the tree (without it the
	# script is only made available as a class, and GameState.foo won't work).
	ProjectSettings.set_setting("autoload/GameState", "*res://scripts/game_state.gd")
	ProjectSettings.set_setting("autoload/Sfx", "*res://scripts/sfx.gd")
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)

	# The BASE RESOLUTION the 2D layer is laid out at. With stretch mode
	# "canvas_items" the 3D renders at the window's real size — it is only the
	# HUD that is drawn at this size and then scaled to fit.
	#
	# It was never set, so it defaulted to 1152 x 648. On anything bigger the
	# score and the controls hint were being magnified: on a 2560-wide display
	# that is a 2.2x upscale of text, which is exactly what blurry text looks
	# like. At 1920 x 1080 the same display scales by 1.33 and a 1080p window
	# is pixel-perfect.
	ProjectSettings.set_setting("display/window/size/viewport_width", 1920)
	ProjectSettings.set_setting("display/window/size/viewport_height", 1080)

	# ANTI-ALIASING. The project had no [rendering] anti-aliasing section at
	# all, which means msaa_3d was 0 — every edge in a low-poly game is a hard
	# diagonal against a flat colour, and that is the worst case for aliasing.
	# 4x MSAA costs bandwidth rather than shader work and is the single biggest
	# "looks more finished" change available for two lines.
	# Back to 4x. It was dropped to 2x while chasing a stutter, before the
	# shadow work was found — and shadows were costing five times what MSAA
	# does. With that fixed there is budget for the anti-aliasing again, and on
	# a low-poly game every edge is a hard diagonal against a flat colour, which
	# is the worst case there is for aliasing.
	# 2x, not 4x, since the game opens at the screen's full native resolution:
	# on a Retina display the pixels are so small that 2x MSAA plus SMAA
	# (below) is as smooth to the eye, and at 3.9 megapixels 4x was one of the
	# two costs that held full screen to ~60 fps on a 120 Hz display.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 1)
	# Dithers away the banding that flat gradients (the sky, the fog) show on
	# an 8-bit buffer. Essentially free.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_debanding", true)
	# SMAA on top of the MSAA. MSAA only smooths the edges of TRIANGLES; the
	# jaggies left were inside them — the shadow edges, the light/shade line
	# across every leaf, the thin ink outlines, the far fine detail. SMAA is
	# a post-process that finds those stair-steps in the finished picture and
	# blends them, and unlike FXAA it does not smear the whole frame soft.
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", 2)
	# Textures seen at a grazing angle (the trail stretching away) stay sharp
	# instead of turning to mush: 16x anisotropic filtering.
	ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 4)

	# SHADOWS. A bigger shadow map means the stair-stepped edge on every
	# shadow shrinks to a quarter of its area, and the soft filter blurs what
	# is left into a real penumbra instead of a pixelated line.
	# 4096, not 8192: the 8192 map was the other big cost at full screen
	# (measured ~55-95 fps with it, ~120 without). With four splits and the
	# first one only ~4.5 m deep, 4096 is still very sharp at the runner.
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 4096)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 3)
	ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 3)

	# Mesh detail holds out further before the engine swaps in a simpler
	# version of a model (half a pixel of error instead of one).
	ProjectSettings.set_setting("rendering/mesh_lod/lod_change/threshold_pixels", 0.5)

	# HIGH-DPI. On a Retina screen, render at the real pixel count, not at
	# half and scaled up. (Godot's default, pinned here so it can never be
	# switched off by accident: without it the whole game is upscaled 2x,
	# which is precisely what "pixelated" looks like.)
	ProjectSettings.set_setting("display/window/dpi/allow_hidpi", true)

	# FORWARD+. The game started on the Compatibility (OpenGL) renderer for
	# mobile reach, and on a Mac that was the wrong trade: Apple deprecated
	# OpenGL years ago and its driver is slow, while Forward+ runs natively on
	# Metal. It also unlocks the effects this art direction depends on —
	# ambient occlusion, soft-light glow, and the glow blend mode that the
	# Compatibility backend silently ignored. The mobile override stays on
	# Compatibility so a phone export still works.
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "forward_plus")
	ProjectSettings.set_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	var err := ProjectSettings.save()
	if err != OK:
		push_error("ProjectSettings.save failed: %d" % err)
