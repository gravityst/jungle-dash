# Jungle Dash

A smooth, modern 3D endless runner for **Godot 4.7.2**: a sculpted monkey that
auto-runs down a 3-lane jungle trail, chased by a silverback gorilla and a
crocodile, through an infinite procedurally-generated rainforest.

> **A note on wording:** these instructions are written for Godot, which has no
> "Blueprints" or "Actor classes" — those are Unreal. Godot's equivalents are
> **Scenes** (`.tscn` — a reusable object like the player or a track piece) and
> **GDScript** (`.gd`). Everything you'd tune in a Blueprint graph is exposed in
> Godot's **Inspector** panel instead, so you can change how the game feels
> without touching code.

---

## 1. Run it

**To play: double-click `Play Jungle Dash.command`** in this folder. It opens
the game on its own, full screen, at your screen's full native resolution
(2388 x 1628 on this Mac). `F11` or `Cmd+Ctrl+F` toggles full screen, and
`Cmd+Q` quits.

> **Why not the ▶ button in the editor?** Godot 4.7 runs the game *inside*
> the editor's **Game** tab by default: a small pane in the editor window,
> where the whole picture is drawn at a fraction of its size and can't go full
> screen. That, and not the game, is what looked "extremely low quality". The
> title screen says so when it detects it. To make ▶ open a real window too:
> **Editor → Editor Settings → Run → Window Placement → Game Embed Mode →
> Disabled**. You can also untick *Embed Game on Next Play* in the Game tab's
> toolbar.

To work on it:

1. Open Godot 4.7.2 (`~/Downloads/Godot.app`).
2. **Import** → choose `~/Documents/jungle-dash` → open.
3. Press **▶** (or `F5`).

| Action | Keys | Touch |
|---|---|---|
| Start (title screen) | any key | tap |
| Daily challenge ↔ free run | `M` on the title or game over screen | — |
| Coach on / off / reset for a new player | `C` on the title screen | — |
| Lane left / right | `A`/`D` or `←`/`→` | swipe left / right |
| Jump | `Space`, `W` or `↑` | swipe up |
| **Duck / roll** | `S`, `↓` or `Shift` | **swipe down** |
| **Slam down** (in mid-air) | same | same |
| Restart after dying | `Space`, `W` or `↑` | tap anywhere, or the button |
| Full screen on / off | `F11`, `Alt+Enter` or `Cmd+Ctrl+F` | — |

Swipe works on desktop too — click and drag in the game window. The game opens
maximized, at your screen's full native resolution (Retina included).

**The loop:** run as far as you can, grab coins, and get past whatever the
jungle puts in front of you. Run into something head-on and it's over. Clip the
*side* of something, or catch the top of a hurdle, and you **stumble** instead —
and Bruno the gorilla and Snapper the crocodile are right back on your tail.
Stumble again before they drop back and you're caught. Your best score, the
leaderboard and your Expedition Journal carry across restarts.

---

## 1b. The big remake — what changed and why

Everything below was done in one long session, and verified the same way the
rest of this project is: every visual change was screenshotted from the real
game (`tools/capture.tscn`, `tools/gallery.tscn`), and every rule change has a
test.

**How it looks**

- **Renderer: Forward+ on the desktop** (Compatibility stays for mobile). That
  is what unlocked ambient occlusion and proper glow.
- **Cartoon shading everywhere**: toon diffuse with a crisp light/shade step,
  a rim light, and **ink outlines** on everything you can touch (the monkey,
  obstacles, landmarks, coins, pickups, the chasers) — and on nothing you
  can't, so the game layer separates from the scenery before you read a shape.
- **The sun moved behind the camera.** It used to shine *toward* the lens, so
  the side of the monkey you always see was in its own shadow; that, not its
  colours, was why it read as a dark blob. A warm rim light now comes from
  where the sun was.
- **A cartoon sky** (`shaders/sky.gdshader`): two-tone clouds, with the
  horizon kept exactly on the fog colour so the end of the track stays
  invisible.
- **The trail.** A real jungle track: packed earth footpaths where feet go,
  and raised strips of grass and moss between them where they don't — so the
  three lanes mark themselves without paint or rails. Roots cross the paths
  and fallen leaves scatter them.
- **The camera** sits closer and follows rigidly along the track, so the
  runner is about a quarter of the screen tall at every speed; it looks past
  the runner down the trail, punches its field of view wider on a trampoline
  launch or a surge, and orbits round to show you the crash when you die.
- **Air**: falling leaves and pollen carried past the lens, speed lines at the
  edge of the screen near top speed, gold sparkles on every coin, dust on
  landing.

**Who's in it**

- **The monkey** got an outfit: blue hoodie, red shorts, backwards cap,
  sneakers with red soles, a yellow backpack with a banana in it, ginger fur,
  round ears that read from behind, and a tail that curls out to the side
  instead of hiding the backpack.
- **Bruno and Snapper** (`scripts/chaser.gd`): a silverback gorilla and a
  Nile crocodile. They chase you off the start line, fall back, and come
  roaring in when you stumble. They don't steer: they replay YOUR path a few
  metres behind you, so they jump where you jumped and can never run through
  anything you avoided.

**What's in the way** — all natural, all fitted to their colliders:

| | Obstacles |
|---|---|
| JUMP | a **python** stretched across the trail · a **mossy boulder** |
| DODGE | a tree trunk · an ancient carved **stone stela** |
| DUCK | a **vine curtain** hung from a pale liana · a low branch |
| RIDE | a **fallen giant** tree · a **temple wall** strangled by fig roots |

**How it plays**

- **Stumble, don't die.** Side hits and clipped edges are mistakes, not
  crashes (`test_stumble.tscn`).
- **A title screen**, shown once when the game opens: the monkey waves, Bruno
  lurks, and any key swoops the camera round behind you into the chase.
- **The surf plank.** The shield power-up is now a board you ride — side-on,
  arms out, sparks off the wheels — and it bursts into splinters when it takes
  a crash for you.
- **The Expedition Journal** (`scripts/missions.gd`): three missions at a
  time. Finish all three and your Explorer Rank goes up, adding +1 to your
  score multiplier for good (not in the daily — that stays a level field).
- **A real HUD**: chunky outlined numbers on plaques, a coin counter with a
  coin, a rival plaque ("CHASING KOA — 180 TO GO"), draining power-up bars,
  and a game over screen with the scoreboard.
- **A starter leaderboard**, so there's someone to chase on your first run.
- **Test runs no longer touch your save.** Running the test suite used to
  overwrite the real leaderboard with the test's AAA–EEE rows. Anything
  launched from `tools/` now can't save, and the one test that is about saving
  writes to its own file. (Your old, polluted save was kept as
  `save.cfg.test-pollution-backup` in the game's user data folder.)

### 1c. The clarity pass — "what do I do about THAT?"

Subway Surfers is instantly readable: you always know what to jump, what to
slide under, what to go round, and what's a power-up. This pass made Jungle
Dash the same, without giving up the realistic jungle. It started with four
independent diagnoses from real screenshots (camera and fog, obstacles,
power-ups, onboarding), each measured, not guessed.

**One look per action.** The shape tells you what to press:

| Press | It looks like | The jungle version |
|---|---|---|
| **JUMP** | a low, wide lump with a bright top | a python basking on a fallen log · a dark boulder crusted with pale lichen |
| **SLIDE** | a GATE: two posts, a dark mass above, a thin pale line where the gap starts | a deadfall trunk hung between two snags · a curtain of vines on a liana |
| **GO ROUND** | a column that runs up out of the picture | a 6 m strangler fig (pale roots on a dark trunk) · a 3.3 m carved stone stela |

Early in a run you only meet the first look of each, so you learn three
shapes before you meet six. The deadfall is the standard slide because it is
the jump's log, lifted: low log = jump, high log = slide. Coins arc OVER jump
obstacles and thread UNDER slide gates, so the coins show you the move too.

**You can see them coming.** The camera sits higher, further back and with a
longer lens, so the stretch 20-60 m ahead — where you decide at speed — takes
about twice the screen it did. The fog starts past 100 m instead of 60, the
ground mist is gone, and the glaring pale end of the tunnel of trees is now a
deep teal haze that both dark and bright obstacles stand out against.
Obstacles' ink outlines stay about 1.6 px wide at any distance. Things on the
path that looked like obstacles (roots lying across the lanes, orange leaf
litter, gold flowers) are gone.

**Power-ups look special.** Bigger, bobbing instead of spinning, each in a
glowing bubble with a shaft of light falling on it, and each with ONE colour
used everywhere it appears: red magnet, blue surf plank, violet double score,
cyan spring. Grab one and a banner says what it does ("MAGNET! Coins fly to
you • 7 s"), the screen flashes its colour, and you can see it on the monkey
(a magnet in his hand, springs on his sneakers, the plank under his feet).

**The coach** (`scripts/coach.gd`). A card at the bottom of the screen for the
obstacle in YOUR lane: **READY** ("JUMP", in white) about 1.5 s out, then
**NOW** ("JUMP!", in colour) inside the press window, with the key to press.
The NOW moments are proven, not guessed: `tools/test_coach.tscn` does exactly
what the card says, instantly or up to 0.35 s late, at the starting speed and
at top speed, against every jump and slide obstacle, and requires a clean pass
every time. It learns: after you've cleared a kind three times it leaves that
kind alone, and comes back (briefly) if you start hitting it. On your first
runs, full-width lesson rows teach each move once. Name tags float over a
power-up, a landmark or the bounce pad the first few times you see one. And
every crash says WHY on the game over screen — "Came down on the boulder —
jump a moment LATER".

### 1d. The high-res pass — smooth, not blocky

"The gorilla, the monkey and the alligator look pixelated... the entire game is
too pixelated, it should be high res, 4K and modern, not blocky and pixely."

It wasn't the resolution. On a Retina Mac the game was already drawing at
native pixels. It *looked* pixelated because everything in it was **faceted**:
characters built from cubes, trunks that were 6-sided pencils, leaf masses made
of 6 x 2 "spheres" (hexagonal diamonds), Kenney low-poly models (one tree was
literally named `tree_blocks`), all lit with a hard toon step that drew a
jagged line across every shape. So the fix was the art, the lighting and the
anti-aliasing, together:

**The characters are sculpted, not stacked** (`tools/char_*.gd`, built on
`tools/smooth_mesh.gd`). Each was made by an agent that built it, rendered it
from the in-game camera and close up (`tools/preview_char.tscn`), looked,
fixed, and then went through an art director's critique and a second pass.
- **The monkey**: one sculpted head with muzzle, brows, eye sockets and
  glossy eyes; a backwards cap with panel seams; a hoodie with a cowl hood,
  drawstrings, pocket and ribbed cuffs; baggy shorts with a side stripe; a
  puffy yellow backpack with a banana; chunky sneakers with treads; a
  question-mark tail. Same rig as before, so every animation and test still
  fits. The elbows now bend the right way. They always bent backwards; the
  box arms hid it.
- **Bruno** is a real silverback now, with no waistcoat, cap or lantern. He has
  a domed crest, heavy brow, shoulder hump, a silver saddle that fades in down
  the back, knuckle-walking fists, and joints that turn inside sockets so
  nothing seams when he runs.
- **Snapper** is a Nile crocodile with no collar or leash. He has rows of
  osteoderm scutes, a double tail crest, a long snout with interlocking
  ivory teeth, lidded eyes with slit pupils on raised turrets, and splayed
  clawed legs.

**The jungle is smooth** (`tools/flora_kit.gd`, `tools/flora_trees.gd`,
`tools/flora_small.gd`):
- **Roadside plants.** Every roadside plant is procedural now:
  - palms with ringed, curving trunks and arching pinnate fronds
  - rainforest trees with buttress roots and layered, leafy crowns
  - jointed bamboo with sprays of lance leaves
  - elephant ears, ferns, flowering heliconia and mossy boulders
- **Canopy trees** are one smooth spline-bent tube each, instead of five
  stacked hexagonal cylinders. Crowns and bushes are soft, lumpy clumps of
  leaves instead of hexagonal gems.
- **Leaves and grass.** Leaves are real blades (pointed, folded, drooping),
  and grass is tufts of soft blades instead of green glass shards.
- **Boxes and the boulder.** Every box big enough to show an edge has a
  rounded bevel that catches a line of light. The boulder obstacle is a
  smooth weathered stone that keeps its exact hitbox.

**The light is smooth.**
- **Shading.** Soft (Burley) shading replaced the toon step. Leaves are
  waxy and let the sun glow through them from behind.
- **A normals bug, fixed.** Godot's `SurfaceTool.append_from()` doesn't
  transform normals correctly for squashed shapes. Measured: a leaf mass
  flattened to 0.2 had its top lit as if it faced sideways. Every merged mesh
  now bakes its transform with the inverse-transpose (`_baked()`), which is
  why the crowns and bushes suddenly shade like volumes.
- **Colour of the shade.** Shade is green-gold (light bounced off leaves)
  instead of sky-blue, and ambient occlusion is gentler, so foliage never
  pools into black holes.

**The picture is sharp.**
- **Anti-aliasing.** SMAA on top of 2x MSAA smooths the stair-steps MSAA
  can't reach: shadow edges, terminators and thin outlines.
- **Shadows.** A 4096 shadow map with soft filtering, plus 16x anisotropic
  filtering and a finer mesh LOD threshold.
- **Window.** The game opens **maximized at the screen's native resolution**
  (Retina and 4K included). `F11` goes full screen.

**The monkey sprints.** The old run cycle was a jog: body upright, short
stride, both feet always down. From the chase camera, which sits straight
behind, eight frames of it looked almost identical, so the monkey seemed to
glide. The new cycle has:
- a 14° forward lean and a 13 cm bounce with a moment where both feet are off
  the ground
- high knees, and heels kicked up so the white soles flash at the camera
- arms pumping from the shoulder, with the elbows now bending the right way
- a roll over each planted foot
- four steps a second at the starting pace (`STRIDE_RATE` in `player.gd`)

It was designed with forward kinematics against the real rig, so the planted
sole sits on the ground through the whole stance (test_gait measured exactly
what the design predicted). `tools/anim_strip.tscn` renders any animation as
a filmstrip from the chase camera, the side and behind.

Performance after all of it: about 2.4-2.9M triangles a frame, ~144 fps
uncapped in a 1080p-class window on an M2 Max. Full screen at the Retina
display's native 2388 x 1628 is 2.1x the pixels, and there 4x MSAA and an
8192 shadow map held it to about 60 fps: uneven on a 120 Hz screen, which
reads as lag. Both were dropped a step (2x MSAA plus SMAA, 4096 shadows),
which measured about 120 fps in A/B runs. Those runs were noisy, and Godot
can't read GPU timings on Metal, so treat the figures as approximate.

---

## 2. What's in the project

```
jungle-dash/
├── project.godot            settings + key bindings
├── assets/nature/           27 downloaded CC0 models (.glb) + credits
├── audio/                   6 synthesised sounds (.wav)
├── shaders/                 foliage wind, ground dapple, cartoon sky, speed lines
├── materials/               shared materials (.tres)
├── scenes/
│   ├── player.tscn          the character
│   ├── track_chunk.tscn     ONE 30 m piece of track — the thing that repeats
│   ├── chaser.tscn          Bruno the gorilla and Snapper the crocodile
│   └── main.tscn            the game: sky, sun, player, chasers, track, camera
├── scripts/
│   ├── chaser.gd            Bruno and Snapper: the chase you see
│   ├── coach.gd             the coach: JUMP / SLIDE / GO, name tags, why you crashed
│   ├── power_icon.gd        the little drawn power-up icons in the HUD
│   ├── missions.gd          the Expedition Journal: three missions and a rank
│   ├── lane_config.gd       ← lane maths. THE single source of truth.
│   ├── game_state.gd        ← score, coins, alive-or-dead. An AUTOLOAD.
│   ├── player.gd            running, lanes, jumping, dying, animation
│   ├── follow_camera.gd     smooth chase camera
│   ├── track_chunk.gd       fills one piece with obstacles, coins and scenery
│   ├── track_manager.gd     spawns ahead, recycles behind
│   ├── hud.gd               score, coins and the game over screen
│   ├── sfx.gd               ← sound effects. An AUTOLOAD.
│   └── ambience.gd          the looping jungle soundbed
└── tools/                   developer scripts + tests. Safe to delete.
```

`scenes/hud.tscn` is the on-screen display; it's already inside `main.tscn`.

---

## 3. Lanes: one source of truth

`scripts/lane_config.gd` holds the lane maths, and **both the player and the
track read from it**. That's what guarantees your requirement that the player
stays aligned to the lanes — there is only one definition of where a lane is, so
they physically cannot drift apart.

```gdscript
const LANE_COUNT: int = 3
const LANE_WIDTH: float = 2.5
const CHUNK_LENGTH: float = 30.0
```

Change `LANE_WIDTH` there and the player's lane positions, the grass strips, the
obstacle placement and the ground width **all follow automatically**. Set
`LANE_COUNT` to 5 and you get a five-lane game with no other edits.

*(Verified: across 800 generated obstacle rows, the worst misalignment between an
obstacle and its lane centre was 0.000000 m.)*

---

## 4. How the endless track works

There is no long level. There are **nine 30-metre pieces on a treadmill.**

```
        recycled ──────────────────────────────┐
            ▲                                  │
            │                                  ▼
   [8][7][6][5][4][3][2][1][0]   ←── player runs this way (-Z)
    ↑                        ↑
  far end (~210 m ahead)   just behind the player
```

Each physics frame, `track_manager.gd` asks one question: *is the piece nearest
behind the player now completely behind it, plus a safety margin?* If yes, that
piece is moved to the far end and re-rolled with new obstacles and scenery.

**Nothing is ever created or destroyed while the game runs.** Every obstacle and
tree already exists inside `track_chunk.tscn` from the start; recycling just
moves, resizes and hides them. This is called *pooling*, and it's why the frame
rate stays flat instead of hitching every few seconds.

*(Verified: over a 600 m run the scene node count stayed at exactly 624 from
first frame to last, and the pieces never left a gap.)*

### Landmarks — the jungle's trains

Subway Surfers has trains: long things that block a lane for many metres and
that you **ride on top of**. The jungle version is a **fallen forest giant** —
a rainforest tree lying along the trail, splintered end towards you, bracket
fungus down its flanks — or a run of **temple wall** the jungle has swallowed,
fig roots draped over it. 16 m long, one lane wide, top at 1.10 m. About 38%
of pieces carry one, never two in a row.

**Riding needs no special case anywhere in the player.** The existing death
rule already does it: a hit kills you *unless* the surface normal points upward
(`land_forgiveness` 0.7). The flat top reports a normal of exactly (0, 1, 0) so
you stand on it; the blunt end face reports (0, 0, 1) so running into it kills
you. Step *off* the side and you fall free; step *into* the side from the lane
beside it and you **stumble** back to the lane you came from (see Dying).

**Why the top is at 1.10 m.** The jump apex is 1.32 m, so that leaves 0.22 m of
clearance. Measured: the mount window is ~0.27 s wide at *both* 12 and 20 m/s —
going faster means pressing earlier, not more precisely. Raise the top and the
window collapses: 1.20 m still works, 1.25 m gives you 21 ms, and at 1.32 m it
never mounts at all. You need roughly 0.11 m of apex clearance for the capsule
to settle, so 1.10 has exactly double the margin.

While riding, `is_on_floor()` stays true and the height holds at 1.1009 m with
**zero** standard deviation. Jumping from up there reaches 1.32 m above the new
surface, identical to the trail. Ducking works. Even the mid-air slam at 26 m/s
does not punch through.

**Coins run along the roof**, so riding pays rather than merely being possible.

#### Two fairness rules that are not optional

1. **A reserved through-lane.** Whenever a landmark is present, one other lane
   is kept clear for its whole length.
2. **Landmarks only ever go in an EDGE lane.** This one cost a bot three lives
   before I found it. A landmark in the MIDDLE lane cuts the two outer lanes
   off from each other for 16 m — a player caught in the wrong outer lane with
   anything at all in front of them is dead with no counterplay, because
   reaching the safe lane means crossing a wall. Rule 1 alone does not save
   you: it guarantees a safe lane *exists*, not that you can *get to it*.
   Keeping landmarks on an edge leaves the other two lanes adjacent, so you can
   always cross.

Fixing that took the test bot from dying at 352 m to surviving every seed.

### The six obstacles

There are three FAMILIES, and which family something belongs to is readable
from its **shape alone** — which is the point, because you have well under a
second to decide:

| | Obstacles | What saves you | Shape language |
|---|---|---|---|
| **JUMP** | python basking on a fallen log, lichen-topped boulder | `Space` / `W` / `↑` | a low wide lump (0.8 m) with a bright top |
| **DODGE** | strangler fig, carved stone stela | change lane | a column running up out of the picture |
| **DUCK** | fallen trunk (deadfall), vine curtain | `S` / `↓` / `Shift` | a gate on two posts, pale line where the gap starts |

(In the code they keep their old names — `Log`, `Rock`, `Tree`, `Pillar`,
`Vines`, `Branch` — so nothing that refers to them had to change.)

The **art and the collider always match**, and `test_silhouette` checks it in
both directions: art must never look taller than what hits you (you would go
round something you could have jumped) nor LOWER (you would jump into
something you could not clear). For a slide gate only the art inside the
collider's width counts — its posts stand in the grass at the lane edge on
purpose, with no collider, to make it read as a gate.

The duck is pure geometry, not a special case: the collider on a slide gate
has its **underside at 1.10 m**. A standing player is 1.8 m and hits it;
ducking shrinks the capsule to 0.9 m and you pass beneath. That 0.2 m of
clearance *is* the mechanic — change `Duck Height` on the player and
you change how forgiving it is.

Ducking lasts `Duck Time` (0.55 s) and pops back up on its own. You tap it, you
don't hold it, and you can't duck in mid-air — otherwise a jump would double as
a duck and the family distinction would collapse.

### Authored patterns

The rows used to be rolled **independently**, and that's precisely why the
track felt generated: nothing related what the first row asked of you to where
the second row wanted you to be. A piece had no shape — just two unrelated
events 15 m apart.

There are ten authored shapes now (`PATTERNS` in `track_chunk.gd`), each a
small deliberate idea: *centre spine* puts a dodge on each edge so holding
still is correct; *jump to the spine* makes you jump in the middle lane and
then leaves the middle lane as the only one open. About **45%** of pieces use
one, past the first 110 m. The rest roll exactly as they always did — the
random path is untouched, because ten recognisable shapes every time would be
worse than noise.

Cells name a **family**, not an obstacle: `HOP`, `ROUND`, `UNDER`, `GAP`. So an
authored shape doesn't come with an authored appearance — you meet the same
shape as a log one run and a boulder the next. Each is also mirrored on a coin
flip, which doubles the set for free.

#### Every difficulty gate used to fire 216 m late

A piece is recycled once it's `keep_behind` past you and reappears at the far
end of the ring — about **216 m ahead**. It was being built with the difficulty
*where you are standing*, not the difficulty *where you'll be when you reach
it*. So every gate in the game — pattern unlocks, obstacle density, everything
driven off `difficulty()` — fired 216 m later than the number written next to
it.

The visible cost was that the authored patterns, the whole feature that stops
the track feeling generated, had a **median first sighting of 728 m**. Most
players never got there. With the bot driving, they now first appear at
**24–174 m**.

`difficulty_for_roll()` is one line and it lines every gate up with its own
number. It's the same bug as the treetop distance, one layer deeper: not "the
number is wrong" but "the number is measured from the wrong place".

#### Difficulty paces them, and they never repeat back to back

Each pattern carries a `min_diff` — the point on the 0–1 difficulty scale
(distance / 900 m) where it unlocks. Three simple shapes are available the
moment patterns switch on; the ones that block two lanes, or ask for a jump and
then a lane change, arrive later. Without that, a player meets the hardest
shape in the table as readily as the gentlest one on their first run, which
isn't difficulty, it's dice.

The manager also remembers the last shape and won't deal it twice running — two
identical pieces in a row is the fastest way to make ten authored patterns feel
like one. The stored name deliberately *excludes* the mirror flag, because a
shape and its mirror are the same shape to a player.

Measured over 400 rolls each: **3 shapes at difficulty 0.15, all 10 at 1.0,
zero back-to-back repeats.** There's also a static check that at least three
patterns are unlocked at the gate — set every `min_diff` above it and the
feature would silently never fire at all.

#### The five rules, which are code and not prose

`test_track.tscn` validates the table **statically**, before any piece is
rolled — a broken pattern might only surface one run in a hundred, and "we
didn't happen to see it" isn't "it isn't there".

1. Exactly `ROWS` rows of exactly `LANE_COUNT` cells.
2. **Every row has a gap.** Blocking all three lanes makes a run impossible.
3. **No jump in the last row.** A held jump carries about 19 m — *more* than
   the 15 m between rows — so it would fly off the end of the piece into
   whatever the next one starts with, which no piece can see.
4. **Every jump lands on clear road.** If row 0 lane L is a `HOP`, row 1 lane L
   must be `GAP`, or the jump you were told to make drops you onto the thing
   behind it.
5. **No full-width chicane.** One gap at one edge then only the other edge
   demands two lane changes in the 0.75 s that 15 m buys at top speed, and one
   change alone costs 0.37 s.

Rules 3, 4 and 5 are the ones that actually strand a player, and the original
design obeyed all three **by accident** — nothing was written down to stop an
eleventh pattern breaking them. The validator was checked by feeding it four
deliberately broken shapes; it caught all four with the right message each.

> This design was picked from three competing ones, each required to supply a
> reachability proof per pattern and then adversarially verified. The other two
> both stranded players — one shipped a row of `[TREE, LOG, TREE]`, the first
> row in the game's history with **no empty lane at all**.

Patterns stand aside entirely when a piece is `safe`, when it's part of the
treetop set-piece, and **whenever a landmark is present** — a landmark is 16 m
of solid object in one lane, and an authored shape knows nothing about it.

### The landing lane is always clear

This was the single worst bug in the game, and it was reported by a player as
*"very narrow margin for error when jumping, very easy to time it wrong."*
That turned out to be almost right and completely misleading — the margin
wasn't narrow, it was often **zero**.

The press window is fine. Measured against the real colliders, you have
**475 ms** to press for a log and **450 ms** for a boulder at top speed. A
person lands within about 60 ms of where they meant to, so that's generous.

The problem was what happened **after**:

| | |
|---|---|
| A jump lasts | **0.717 s** |
| which at the 20 m/s cap carries | **14.3 m** |
| and the obstacle rows are | **15 m apart** |

So you touch down **0.7 m** — thirty-five *thousandths* of a second — before
the next row. Hold the key and the jump carries 19 m, so you're still in the
air when you arrive. You cannot duck in mid-air (the duck key slams you down
instead) and you cannot change lane in 0.035 s. **Anything in that lane was
unavoidable.**

Authored patterns already forbade it, but they're only about half the pieces.
The randomly-rolled half had no such rule. Measured with the guarantee
switched off: **148 of 302 jumps — 49% — landed on something solid.** Nearly
every other jump was a death the player could do nothing about.

`_clear_landing_lanes()` now empties the landing lane, and it has to work
**across the piece boundary** too: a jumpable in the last row sits 15 m from
the *next* piece's first row, which is the identical trap. Pieces can't see
each other, so `TrackManager` carries the lanes forward — exactly as it does
for landmarks and patterns.

> Worth the detour: the obvious fix was "make the jump bigger", and it would
> have been aimed at a problem that did not exist. Measuring the press window
> first is what pointed at the landing instead.

### Obstacles are always passable

`track_chunk.gd` rolls 2 rows per piece. The rule it can never break is that
**at least one lane in every row stays open** — it picks at most `LANE_COUNT - 1`
lanes to block. Jumpable obstacles dominate early, because jumping is the first
thing a player learns; ducking and the dodge-only blockers get more common as
`difficulty` climbs from 0 to 1 over the first 900 m.

*(Verified: 800 generated rows, minimum free lanes = 1. Never zero. And a robot
player ran **3597 m of a possible 3600 m in five minutes** without getting stuck.)*

### The four layers

A jungle reads as a jungle because of what's stacked around you, not because
of any one plant. Each layer is a **single merged mesh per side per chunk**, so
the whole thing costs a few draw calls rather than hundreds:

| Layer | What it is | Why it matters |
|---|---|---|
| **Canopy** | two sub-layers: *arch* trees almost on the verge leaning 20–30° so their crowns carry out over the trail, and *back* trees 9–17 m out and much taller that fill the top corners | Makes the trail a *tunnel*. One ring of trees reads as foliage in the middle distance; it takes both layers to read as a roof. |
| **Understory** | broad tropical leaves, shrub mass, bare saplings | Fills the ground right up to the dirt. Real jungle has no bare earth. |
| **Individual plants** | palms, broadleaf trees, ferns, rocks | Midground variety, 16 per chunk |
| **Jungle wall** | lumpy mass of blobs set well back | Closes off the distance so you can't see out |

**The sightline is guaranteed, not hoped for.** The camera sits at y = 3.5 and
looks *down* the trail, so the ray to anything standing on the track only ever
descends — it never rises above 3.5 at any distance. So geometry whose lowest
point stays above the camera physically cannot hide an obstacle. Two constants
enforce it: `CANOPY_MIN_Y = 7.8` and `CANOPY_CORRIDOR_X = 5.2`. Any crown over
the corridor is pushed up until its underside clears 7.8 m; a trunk segment that
would cross into the corridor below that height stands vertical instead. Measured
on the built scene: the lowest canopy vertex anywhere over the lanes sits at
y 5.37, which is 1.87 m of clear air above the camera.

Two more things had to be true or it fell apart:

- **The canopy casts no shadow.** A canopy that size drops a solid blanket over
  the whole trail and the dirt turns black — that was the very first render.
  Dropping it out of the shadow pass keeps the enclosure you can *see* while
  letting the sun still light the path, and it halves what the canopy costs.
- **Ambient had to go up** (1.0 → 1.45), because the canopy now hides most of
  the sky that used to light the scene from above.

And the leaves: a `PrismMesh` comes to a point, which is right for a fern or a
palm frond and completely wrong for an elephant-ear — those rendered as green
*stars*. The broad understory leaves are very flattened low-poly spheres
instead, which gives the wide rounded blade that actually says "tropical".

### Shaders

Two custom shaders in `shaders/`, both of which work fine under
gl_compatibility:

- **`foliage.gdshader`** — wind. Amplitude is masked by world height, so
  trunks and stalks stay planted while tips move: canopy crowns sway 26 cm,
  ankle-height shrubs barely twitch. The phase comes from **world position**;
  without that every plant sways in lockstep and the jungle wobbles like jelly.
  Two frequencies are layered, because a single sine reads as mechanical.
- **`ground.gdshader`** — dappled canopy light. The canopy is deliberately out
  of the shadow pass, which left a dense roof casting no pattern at all on the
  ground below it. This fakes it with world-space noise, so the dapple flows
  past as you run and is immune to chunks teleporting when they recycle. It
  also breaks up the flat dirt slab and fades out with distance so it does not
  fight the fog.

### Scenery variety

The verge and the wall each carry **three differently-seeded variants** as
hidden children; the chunk shows one at random on every recycle, on top of
sliding and mirroring it. Hidden variants cost no draw calls — only the visible
one is drawn.

This matters more than it sounds: with a single strip slid and mirrored there
are exactly **2** possible looks, and a player passes ~50 chunks in two minutes.
`audit.tscn` now counts the combinations; it reports **28 distinct** ones over
60 recycles.

### Ground mist

`fog_height` and `fog_height_density` **do** work under gl_compatibility —
worth knowing, because they're widely assumed not to. They add fog *below* a
given height, which is exactly the low haze that sits between jungle trunks.

The density is the trap: at `0.35` the entire scene below the canopy went white
and the player vanished. It wants to be tiny — `0.022` at a height of `3.5`.

### Why you can't see the end of the track

The track only exists for ~210 m, so without help you'd watch it stop in mid-air.
Three things hide that, and they only work together:

1. **Depth fog** fades geometry out between 60 m and 150 m.
2. **`fog_density = 1.0`.** This is the one that catches everyone: in depth mode
   the fog amount is still multiplied by `fog_density`, whose default is `0.01`.
   Leave it alone and your fog is 1% opaque and looks broken.
3. **The horizon colour is shared three ways** — sky, ground and fog all use the
   same colour. Fog fades distant things *to the fog colour*, not "to whatever is
   behind them", so if those disagree the cut-off edge shows as a coloured wedge.

There's also a wide **JungleFloor** slab either side of the track. Without it
you'd see sky through the gap beside the track, and the only fix for that would
be flattening the whole sky to the fog colour — which makes the track look like
it floats in mist.

---

## 4b. The gameplay loop

Everything about "am I alive and how am I doing" lives in one place:
`scripts/game_state.gd`, registered as an **autoload** (Godot's word for a
singleton). Any script can reach it by typing `GameState.` — no dragging node
references around — and, crucially, **it survives a restart**, which is how your
best score carries over while the level is rebuilt from scratch.

It doesn't get polled. It *announces* changes, and the HUD listens:

```gdscript
signal score_changed(new_score: int)
signal coins_changed(new_coins: int)
signal died
signal restarted
```

### Score

`score = metres run x POINTS_PER_METRE + coins x POINTS_PER_COIN` (1 and 25).

Distance is measured from how far the player **actually moved**, not from
`speed x delta` — so being shoved by an obstacle doesn't pay out.

### Coins

Coins are pooled `Area3D` pickups inside each track piece — eight per piece,
never created or destroyed, just moved and switched on and off like everything
else. A run is placed in a lane that is **clear in the next obstacle row**, so
chasing coins leads you somewhere safe rather than into a block. Greed and
survival point the same way.

Two non-obvious things make them work:

- **`visible = false` does not stop an Area3D detecting you.** Only
  `monitoring = false` does. (Same trap as `CollisionShape3D.disabled` for solid
  obstacles.)
- **Switching `monitoring` off must be deferred.** Writing it directly inside
  the `body_entered` handler is *rejected* by Godot with
  `Function blocked during in/out signal`, and the coin then pays out twice.
  Since the deferred write doesn't land until the end of the frame, `visible`
  is used as the immediate "already collected" guard.

### The three power-ups

One slot per piece, one power-up at a time, and only about one piece in five
carries anything at all. Two on screen at once would stop either being a
moment.

| | Looks like | What it does | Lasts |
|---|---|---|---|
| **Magnet** | red horseshoe | every coin within 11 m flies to you | 7 s |
| **Shield** | surf plank | you ride it; it takes one crash for you | until used |
| **Surge** | violet gem | every point counts double | 9 s |
| **Spring** | cyan coil | a second jump, in mid-air | 10 s |

They are weighted: shield 32%, magnet 28%, surge 20%, spring 20%. The shield is
the most common because it's the one that helps a player who is struggling.

Each one does a different *kind* of thing — collect, survive, score, move. A
fifth that just paid out more would be a colour, not a power-up.

#### The spring is capped for a reason

The second jump is **70% of the first**, and that number is load-bearing. A
first jump peaks at 1.39 m; a second of `0.70 × 8.5 = 5.95` m/s launched from
there adds `5.95²/52 = 0.68` m, for a ceiling of about 2.07 m.

That has to stay **under** the things you're meant to go *around* — the stone
idol at 2.40 m and the tree at 2.60 m. Land on top of one and the crash check
forgives you (it forgives any upward-facing contact), so you'd end up standing
on a dodge-only obstacle, which nothing in the game is designed for.
`test_powerups.tscn` measures the real apex and fails above 2.35 m. It also
checks that a third press does nothing: one extra jump per landing, not a
helicopter.

#### The shield is the interesting one

It looks like a **surf plank**, and while you hold one the monkey rides it —
side-on, arms out for balance, sparks off the tail wheels — in place of
running. When it saves you it bursts into splinters. The rules below are
unchanged; only the look is new.

Surviving the hit is only half the job. The obstacle is still **solid**, so a
shield that only cancelled your death would leave you pinned flat against the
tree, unable to move — worse than dying. So when a shield saves you, the thing
that hit you has its collider switched **off**, and you get 0.9 s of
invulnerability to physically get clear. Nothing has to switch the collider
back on: every obstacle is rebuilt from scratch when its piece recycles.

That 0.9 s is measured, not guessed: at the 12 m/s starting speed it carries
you 10.8 m, and the deepest obstacle in the game is 1.15 m front to back.

### The coin magnet

The one power-up, and the only thing in the game that glows. It's a red
horseshoe floating at shoulder height; run through it and for **7 seconds**
every coin within **11 m** flies to you, including coins in lanes you're not
in. That's the point — it's the only time the game lets you collect something
without steering to it.

| Knob | Where | Default |
|---|---|---|
| How long it lasts | `MAGNET_SECONDS` in `game_state.gd` | 7.0 s |
| How far it reaches | `MAGNET_RANGE` | 11.0 m |
| How hard it pulls | `MAGNET_PULL` | 26 m/s |
| How long a surge lasts | `SURGE_SECONDS` | 9.0 s |
| What a surge multiplies by | `SURGE_FACTOR` | 2 |
| How long shield cover lasts | `Invuln Time` on the player | 0.9 s |
| How often ANY power-up appears | `PICKUP_CHANCE` in `track_chunk.gd` | 0.20 |
| Which kind you get | `PICKUP_WEIGHTS` | shield .40 / magnet .35 / surge .25 |

Three decisions worth knowing about:

- **A second magnet replaces the timer, it doesn't add to it.** Otherwise a
  lucky run stacks into a minute of free coins and the power-up stops being a
  moment.
- **It never spawns in a lane the next obstacle row blocks**, and never inside
  a landmark. A reward you can't reach without dying is a punishment.
- **The timer freezes when you die** rather than burning down behind the game
  over screen.

`tools/test_powerups.tscn` checks all of that, including the pull itself: it
parks one coin 6 m to the player's side — far outside the 0.55 m pickup radius,
well inside the 11 m magnet range — and requires that coin to be **left behind
with the magnet off and collected with it on**.

> That test started out comparing coin totals across two runs of the track and
> was flaky, because the track is randomly seeded and doesn't rewind between
> runs, so the two halves were never looking at the same coins. Testing one
> coin you placed yourself takes the track out of the question.

### Dying has a beat now

Time drops to **35% for 0.35 seconds** the moment you crash, so the hit lands
as an event rather than the game simply stopping. Short on purpose: long enough
to read what got you and to let the camera shake register, never long enough to
stand between you and pressing restart.

Two things about it are easy to get wrong and are worth knowing:

- The countdown is measured off the **system clock**, not `delta` — `delta` is
  exactly the thing being slowed, so counting down with it would make the
  effect last 1/0.35 times as long as intended.
- The code that ENDS it has to run *before* the "are we still playing?" guard
  in `GameState._process`. The slowdown starts at the moment of death, so by
  the time it needs ending the game is already not running. Put it after the
  guard and time never speeds back up — the whole game stays in slow motion
  with no clue as to why.

`test_juice.tscn` checks 1.00 → 0.35 → 1.00, and separately that restarting
*during* the slowdown clears it. A leaked `Engine.time_scale` doesn't crash
anything, which is exactly why it would survive for months.

### Footsteps

The game used to be **silent while you ran**, which is a strange thing to
notice only after everything else is working. There are two footfall sounds now
— soft earth, a couple of semitones apart so a run doesn't sound like one
sample on a loop — and they're driven by the **animation's own playback
position**, not a timer.

That matters because the stride rate follows speed: at the 20 m/s cap the cycle
plays 1.67× faster than at the start. A fixed timer would drift out of step
with the feet within a second or two. Reading `current_animation_position` and
watching it cross the cycle's two CONTACT keys means the sound and the feet
*cannot* disagree.

`test_juice.tscn` counts them: **10 steps in 3 s at 12 m/s, 17 at 20 m/s**, and
zero while airborne. `Sfx.plays` is a per-sound tally that exists purely so a
headless test can check audio at all — it's the one part of a game you can't
verify by looking at the scene.

### How the jump feels

Four things shape it, and three of them are invisible until they're missing:

| | What it does |
|---|---|
| **Coyote time** (0.12 s) | you can still jump for a moment after running off an edge |
| **Jump buffer** (0.14 s) | pressing jump just before you land still jumps |
| **Hang time** | gravity eases to 55% near the top of the arc |
| **Hold to go higher** | keeping the key down lifts the apex from 1.67 m to 2.21 m |

`jump_velocity` was raised from 8.5 to 9.2 on player feedback: at 8.5 the apex
was 1.49 m, which clears a landmark roof at 1.10 m by only 39 cm — so anything
short of a perfect jump clipped the edge. It's 1.67 m now.

That change does not stand alone. The ceiling applies to the **total**, so
raising the base jump forced the spring's second jump down from 0.70 to 0.58:
at 0.70 the combined apex measured **2.45 m**, over the line, which would land
you on the roof of the stone idol. Two constants that look independent are not.

**Hang time** is another one worth knowing about. The top of a jump is where
you're reading the track and deciding what to do, and a pure parabola gives you
least time exactly there. Easing gravity near the apex doesn't make the jump
meaningfully higher — about 10 cm — it makes it *legible*.

**Hold-to-jump-higher is deliberately the opposite way round** from the usual
platformer trick. Normally a tap gives a short hop and holding gives the full
jump. In a runner that's a trap: almost every jump needs to be near maximum, so
a mistimed tap is a death with no lesson in it. I built it that way first and
measured it — a quick tap apexed at **0.93 m against a 0.78 m boulder**, 15 cm
of margin for a player who did nothing wrong. So a tap now gives the full
ordinary jump and holding buys extra on top. Nothing that jumps in *code* (the
swipe handler, the test bot) is affected, because there's no key held down.

**The ceiling is a height cap, not a strength setting.** Holding the key
through a spring-assisted double jump reached **3.06 m** — each half was
guarded by a test and the *combination* by neither. Scaling the second jump
down cannot fix it: a held first jump already peaks at 2.21 m, so staying under
the ceiling would mean adding almost nothing, making the power-up useless
exactly when you're playing well. The mid-air jump is now clamped to the
remaining head room above the ground you left, so the spring always gives you a
real second jump and never one that puts you on a roof. Measured: tap 1.67,
hold 2.21, spring 2.22, **hold + spring 2.30**.

Both ceilings are tested. Holding, and the spring's double jump, must stay
under **2.35 m** — the stone idol is 2.40 m and the tree 2.60 m, and landing on
top of a dodge-only obstacle is behaviour nothing in the game accounts for.

### Playing against your friends

The problem with "I got 2,400" is that it's a claim about a track nobody else
ever ran. So there are two modes, swapped with **M** on the game over screen:

| | |
|---|---|
| **Free run** | a fresh random track every time |
| **Daily** | the same track for everyone, all day |

The daily seed comes from the date alone, so two people running today's
challenge meet the same obstacles in the same order. That is the whole feature
— everything else is presentation. `test_compete.tscn` checks it directly:
two daily runs must fingerprint **identical**, two free runs must not.

The seed is `date × 2654435761 mod 2^31` rather than just the date digits,
because consecutive numbers make visibly similar tracks and "today felt a lot
like yesterday" would undermine the point.

#### The board chases you while you run

Five names, kept separately per mode — a daily score and a free-play score
aren't the same currency, so mixing them into one table would be meaningless.

The HUD shows **`CHASING ABC 180`**: not the name at the top, but the nearest
score still ahead of you, and how far. Pass it and the screen says **`PASSED
ABC`** and the line moves to the next one up. That turns a scoreboard from
something you read afterwards into something you're doing during the run.

On the game over screen your row is marked with `>`, you can type three letters
to rename it, and there's a line you can screenshot:

> `Jungle Dash daily 2026-09-20 - 1240 pts, 890 m, 87 coins`

The daily board clears itself when the date changes, because yesterday's scores
were set on a course that no longer exists.

> `GameState.record_runs` exists so the tests — which kill the player
> deliberately and repeatedly — don't fill a real person's scoreboard with
> entries nobody earned.

### It tells you how to play now

The game never explained itself. A runner has exactly three verbs, so the HUD
shows them in the middle of the screen at the start of every run and fades them
the moment you touch a control — or after five seconds if you don't. Once you
have shown you know, the reminder is clutter.

### Coin layouts

Coins are the only thing in the game that *asks* you to move rather than
forcing you to, so they're the one bit of level design here that's purely an
invitation. There are four layouts:

| | When |
|---|---|
| **Arc** | over something jumpable — the reward sits on the path the obstacle already forces |
| **Roof run** | along a landmark, so riding one pays |
| **Weave** | alternating between two lanes |
| **Line** | everything else |

The weave uses **two coins per lane**, and that isn't arbitrary: at the 20 m/s
cap two coins is 4 m, or 0.2 s — almost exactly how long a lane change takes —
so it reads as one continuous movement rather than a series of stops. Both
lanes come from the *safe* list, so following the coins is always the right
move.

### Close calls

Clear an obstacle that was in **your own lane** — jump the log, duck the vine —
and you get **+10 points**, a whoosh, and a `NICE!` flash. The game counts them
and the game-over screen reports them.

The rule is deliberately strict. A narrow column, 0.9 m wide against a 2.5 m
lane, rides with the runner; an obstacle entering it is in your lane at your
depth, and if it then *leaves* while you are still alive, you got past
something that was genuinely in the way. Passing an obstacle one lane over was
never dangerous, so it pays nothing — rewarding that would make the bonus
meaningless. `test_juice.tscn` checks both halves: the same obstacle pays 1
close call in your lane and 0 from one lane over.

It is worth less than a coin on purpose. This is a bonus for playing well, not
a reason to go looking for danger.

### The treetop run

Every 900 m the jungle opens into a clearing, a bright green trampoline spans
the whole track, and it throws you **9.1 m into the air** onto a walkway of
treetops. You run along it for about five and a half seconds — coins, no
obstacles, nothing up there that can hurt you — and then the deck runs out and
you glide back down to clear ground.

It is a **rest**, not a challenge. That was the design goal and it is enforced
by the code: the deck is deliberately **not** in the `obstacle` group, so its
edges can never kill you, and the whole six-piece sequence is rolled with no
obstacles, no landmark and no power-up.

| Piece | What it does |
|---|---|
| `APPROACH` | clear run-in, and the leaf canopy switched off |
| `LAUNCH` | the trampoline, and the deck starting 11.5 m past it |
| `DECK` ×3 | full-length walkway, coins, nothing else |
| `NARROW` | the walkway shrinks to a single lane |
| `EXIT` | 6 m of deck, then it runs out and you drop home |

The narrow stretch sits in the **middle** on purpose: first would ask something
of you before you'd found your feet up there, last would overlap the drop home.
A line of coins runs down the middle lane, which tells you where to be before
you arrive rather than after.

#### It was a hole first, and a hole cannot work

The obvious version of "something to do up here" is a gap in the walkway that
you jump. I built that, and it is **impossible to make fair**, for a reason
worth writing down:

The runner is **1.80 m tall** and the deck is a **0.80 m slab**. To get *past*
the far edge of a hole you have to fall until your **head** clears the slab —
about 2.6 m, which is roughly **9 m of travel** at the 20 m/s cap. No hole that
is jumpable at the 12 m/s starting pace (a jump carries 8.6 m) is anywhere near
that wide. So anyone who missed it was guaranteed to slam into the far edge and
stop dead. The test bot lost 3–4 m every single run to exactly that, which is
how it was caught.

Note which way round it goes, too: the **faster** you are, the more likely you
are to hit, because you cover more ground before you've dropped clear.

Narrowing sideways has none of that. Miss it and the walkway ends up *beside*
you rather than in front of you, so there's nothing to collide with — you drop
to the jungle floor and carry on. `test_canopy.tscn` checks the walkway is
exactly one lane, centred, with 0.85 m of clearance from an outer lane, and
that **forward speed never drops below 100%** anywhere on the treetop run.

The first one arrives at about **473 m** — roughly 25 seconds in — and they
repeat every 900 m after that. `Canopy First` and `Canopy Every` on the
TrackManager control those separately, and `Canopy Runs` turns them off.

> Those used to be one number, and the first run was about **1115 m** in:
> roughly a minute of never dying. The best thing in the game sat behind a wall
> almost nobody would get through, which is the same as not having built it.
> `test_canopy.tscn` now runs at the shipping settings and fails if the first
> one is further than 700 m — a test that overrides the spacing proves the
> treetops work, not that anyone will ever see them.

#### The one number the whole thing balances on

`DECK_LEAD` — how far past the trampoline the walkway starts — is 11.5 m, and
it was chosen by **simulating the engine's actual 60 Hz physics loop**, not by
algebra. Launched at 22 m/s your feet cross the 7 m deck height somewhere
between 5.4 m past the pad (at the 12 m/s starting speed) and 9.0 m past it (at
the 20 m/s cap), and drop back through 7 m between 14.0 m and 23.3 m past.

So the edge has to sit **after the last of those crossings and before the first
of those landings** — anywhere in 9.0–14.0 m. At 11.5 m your feet clear the
edge by 1.28 m in the worst case and 2.12 m in the best, across the entire
speed range, with one fixed constant and no speed compensation.

> Don't use `v²/2g` for this. The continuous-maths answer is 9.31 m; the engine
> actually delivers 9.12 m, because it integrates `v -= g*dt` then `y += v*dt`
> once per frame. 18 cm of optimism is enough to put the deck edge in the wrong
> place.

#### Two bugs that this feature was always going to have

Both were predicted by review before a line was written, and both are now
covered by `test_canopy.tscn` section C:

1. **A buffered jump silently eats the launch.** An `Area3D`'s `body_entered`
   fires from the physics server's query flush, which runs *before*
   `_physics_process`. So on the frame after you touch the trampoline
   `is_on_floor()` is still true — which refills the coyote timer, and the jump
   line `velocity.y = jump_velocity` is a plain **assignment**. A 22 m/s launch
   would be overwritten with an 8.5 m/s hop. `_launch_lock` closes that window.
2. **Holding the duck key slams you straight back down.** A mid-air duck sets
   `velocity.y = -26`. Since duck is also the slide key, players hold it — so
   the launch has to refuse the slam for the whole rise, not just the first few
   frames. That is what `_launched` is for, and it must survive the *false
   landing* the first bug creates.

The test measures the apex twice, once launched cleanly and once while mashing
jump and duck every single frame. Both must reach 9.1 m. Before the fixes the
mashed run reached 0.36 m.

#### Why the leaf canopy switches off

`_build_canopy` runs from z +8 down to `-(length + 14)`, so **every piece's
leaves overhang about 16 m into the piece in front of it**. Hiding the canopy
only on the treetop pieces is not enough — the piece *before* the launch still
has foliage hanging exactly where you fly up through. That is why there is an
`APPROACH` piece whose only job is to be clear.

Switching it off also makes a treetop piece *cheaper* than a normal one, and
`audit.tscn` measures both so this is a fact rather than a hope: **69 surfaces
against 83**, because it drops the canopy (10 surfaces, ~6,200 triangles) and
every obstacle, and adds back a deck and some flanking crowns for less. The
most spectacular part of the game is also the cheapest to draw.

### Dying

After `move_and_slide()`, the player looks at what it actually touched:

```gdscript
for i in get_slide_collision_count():
    var hit := get_slide_collision(i)
    if not hit.get_collider().is_in_group("obstacle"):
        continue                         # the ground is in this list constantly
    if hit.get_normal().y > land_forgiveness:
        continue                         # landed on top — that's allowed
    GameState.die()
```

`get_normal()` points out of the surface you touched. Straight up (y near 1)
means you landed on a low hurdle, which is forgiven. The threshold is `0.7`.

**Not every other hit kills you any more.** There are three answers now:

| The normal points… | It means | What happens |
|---|---|---|
| mostly up (y > 0.7) | you landed on top | nothing — you're standing on it |
| **sideways** (\|x\| > 0.6), or **half up** (y > 0.35) | you steered into its side, or clipped its top edge | you **stumble** |
| back down the track at you | you ran into its face | **crash** |

A stumble throws you back into the lane you came from (you were standing there
a moment ago, so it is clear at your depth) — or, for a clipped edge, switches
that obstacle off so you tumble over it — and costs you 8% of your speed. It
also puts **Bruno** on your tail for 6 seconds (`HEAT_SECONDS`). Stumble again
inside that window and he catches you: the run ends with **CAUGHT!** instead of
**WIPEOUT!**. A surf plank, if you are riding one, is spent instead.

`tools/test_stumble.tscn` pins all of it down: a side hit survives and returns
you to your lane, a second one while he is hot catches you, one after he drops
back is forgiven, a clipped edge tumbles you over, a head-on hit still crashes,
and a plank saves a catch.

### Speeding up

`forward_speed` climbs from `Start Speed` toward `Max Speed` at `Speed Ramp`
metres per second, per second — 12 → 24 m/s over about 55 seconds by default.
Independently, the track's own `difficulty()` ramps obstacle density over the
first 900 m, so the game gets harder in two ways at once.

### Game over and restart

`GameState.die()` records your best score and flips the phase to DEAD. The
player skids to a halt, the animation freezes mid-stride, and the HUD shows the
panel. Restart calls `get_tree().reload_current_scene()`, which throws the level
away and rebuilds it — track, player, camera, all of it — while the autoload
(and your best score) survives untouched.

---

## 4b2. The feel

The behaviours that make an endless runner feel like *Subway Surfers* are
mostly in the player, not the scenery:

- **The runner banks into lane changes.** A 24° lean that builds and releases
  with the actual sideways speed, not with the key press. Set `Lean Degrees` to
  0 and the character slides sideways like a chess piece — it is the single
  most recognisable part of the feel.
- **Lane changes are snappy.** `Lane Switch Sharpness` is 19, up from 12. The
  switch is over in about a fifth of a second.
- **You can slam down in mid-air.** Ducking while airborne forces you straight
  back to the ground at 26 m/s and rolls on landing. Without it, a mistimed
  jump means waiting helplessly to land on the thing about to kill you; with
  it you always have an option.
- **Ducking is a forward roll**, not a crouch.
- **Coins arc over jumpable obstacles.** If a row has a log or boulder in it,
  the coin run is thrown over that obstacle in that lane instead of laid flat
  somewhere safe — so jumping well and collecting well become the same action.
- **The score multiplier** climbs one step every 400 m, to a cap of x5. It
  applies to what you earn *while it is active*, so reaching x3 does not
  retroactively re-score your first kilometre.

**Why the figure hangs off a `Body` pivot.** The run animation already drives
`Visual:rotation` for the stride sway. If the lean wrote that same property,
one would simply overwrite the other every frame. On separate nodes they
compose: sway from the animation, bank from the movement.

**Why the roll needs two tracks.** `Body`'s origin is at the FEET, so rotating
it alone swings the character through the floor like a clock hand. To tumble
about its middle the position has to counter-rotate — for a point `c` above the
origin, rotating by θ moves it to `(c·cosθ, c·sinθ)`, so shifting back by
`(c - c·cosθ, -c·sinθ)` pins it. `c = 0.42` puts the pivot at hip height, so
the roll peaks at 0.84 m — about the 0.9 m the collision capsule shrinks to,
which is why what you see matches what the physics is doing.

---

## 4c. Sound

Every sound in `audio/` was **synthesised, not recorded** — generated as plain
16-bit WAVs by a short Python script. No sample library, nothing downloaded. If
you would rather have real recordings, drop a file with the same name into
`audio/` and nothing else needs to change.

| File | What it is |
|---|---|
| `coin.wav` | a two-note chime, B5 into E6, with a high shimmer on top |
| `jump.wav` | a rising blip with a touch of air |
| `land.wav` | a low thud with grit |
| `duck.wav` | a cloth swoosh |
| `crash.wav` | impact plus debris |
| `ambient.wav` | 5.65 s looping bed — wind, insects, four bird calls |

Two details worth knowing:

- **Coins rise in pitch.** Each coin in quick succession plays a semitone above
  the last, resetting after half a second without one. That is what makes
  collecting a line of them feel like a *run* rather than a stutter.
- **Sounds play through a pool of 10 players, not one.** With a single player
  each coin cuts the previous one off; the pool lets them ring out and overlap.

`ambient.wav` is imported **uncompressed** while the effects are QOA. Its loop
point is a hand-made crossfade between the tail and the head, and a lossy codec
can drop a click right on top of it. Its loop is switched on in `ambience.gd`
at runtime rather than in the import settings, because Godot loads the resource
with `loop_mode = 0` regardless of what `edit/loop_mode` in the `.import` file
says — verified with `audit.tscn`.

---

## 4d. The high score is permanent

`best_score` is saved to `user://save.cfg` the moment you beat it, so it
survives quitting the game, not just restarting a run. On a Mac that file is in
`~/Library/Application Support/Godot/app_userdata/JungleDash/`.

---

## 5. Tuning it — no coding required

Click a node, look at the **Inspector** on the right. You can drag these while
the game is running.

**Player**

| Setting | Default | Effect |
|---|---|---|
| Start Speed | 12.0 | Speed at the start of a run |
| Max Speed | 24.0 | The fastest it ever gets |
| Speed Ramp | 0.22 | Extra m/s gained per second. `0` = constant speed |
| Land Forgiveness | 0.7 | Landing on a hurdle is OK. `1.1` = any touch kills |
| Lane Switch Sharpness | 12.0 | Snappier lane changes |
| Jump Velocity | 8.5 | Jump height (apex is ~1.32 m) |
| Duck Time | 0.55 | How long a duck lasts |
| Duck Height | 0.9 | Ducked height. Must clear the 1.05 m underside of the vines |
| Gravity | 26.0 | Heavier, more arcade |
| Fall Gravity Multiplier | 1.6 | Falling faster than rising — kills floaty jumps |
| Coyote Time | 0.12 | Grace period to jump after leaving a ledge |
| Jump Buffer Time | 0.14 | Early jump presses still count |

**TrackManager**

| Setting | Default | Effect |
|---|---|---|
| Chunk Count | 9 | Live pieces. 9 × 30 m = 270 m of track |
| Keep Behind | 24.0 | Track kept behind you. **Must exceed the camera's ~8 m** or the ground vanishes from under it |
| Safe Start Chunks | 2 | Obstacle-free pieces at the start |
| **Spawn Obstacles** | on | **Untick for an empty track** — great while tuning the camera or the feel |
| Difficulty Distance | 900.0 | Metres to ramp from easiest to hardest |
| Random Seed | 0 | `0` = different every run. Any other number = the *same* track every time, which is invaluable when comparing a change |

**FollowCamera**

| Setting | Default | Effect |
|---|---|---|
| Offset | (0, 3.5, 6.2) | Height and distance behind |
| Lateral Follow | 0.5 | `0` = never slides sideways, `1` = always directly behind. `0.5` keeps all three lanes framed |
| Follow Sharpness | 6.0 | How fast it catches up |

**Scoring** lives in `scripts/game_state.gd` (an autoload has no Inspector, so
you edit the two numbers at the top of the file):

| Constant | Default | Effect |
|---|---|---|
| `POINTS_PER_METRE` | 1.0 | Points for distance |
| `POINTS_PER_COIN` | 25 | Make this big enough that coins are worth a detour |

> Because the camera eases rather than snaps, it settles about
> `forward_speed ÷ follow_sharpness` further back than `Offset` — ~2 m at the
> defaults. Raise `Forward Speed` a lot and you should raise `Follow Sharpness`
> to match.

---

## 6. Building the track by hand, step by step

The project already works. This is how you'd make the track part yourself.

### 6a. The chunk scene

1. **Scene → New Scene → Other Node → Node3D**. Rename it `TrackChunk`.
   Attach `res://scripts/track_chunk.gd`.
2. Add a **StaticBody3D** child called `Ground`.
   - Give it a **MeshInstance3D** child named `Mesh`: **BoxMesh**, size
     `(9.1, 1, 30)`, position `(0, -0.5, -15)`.
     *(9.1 = 3 lanes × 2.5 + 1.6 of shoulder. -0.5 puts the top face at y = 0.)*
   - Give it a **CollisionShape3D** child: **BoxShape3D**, same size and position.
3. Add a **MeshInstance3D** directly under the root called `JungleFloor`:
   BoxMesh `(140, 1, 30)` at `(0, -0.52, -15)`, dark green material. No collision.
4. Add a **Node3D** called `LaneMarkings`, with two **MeshInstance3D** children:
   BoxMesh `(0.12, 0.02, 30)` at `(-1.25, 0.01, -15)` and `(+1.25, 0.01, -15)`.
5. Add a **Node3D** called `Obstacles`. Inside it make **six** **StaticBody3D**
   children named `Obstacle0` … `Obstacle5`, each with:
   - a **MeshInstance3D** named `Mesh` — BoxMesh `(1.6, 0.6, 1.0)` at `(0, 0.3, 0)`
   - a **CollisionShape3D** — BoxShape3D, same size and position
   *(Six = 2 rows × 3 lanes. The script resizes and repositions them at runtime.)*
6. Add a **Node3D** called `Decor` with **twelve** **Node3D** children. Put a
   tree in the first eight (a **CylinderMesh** trunk plus two more CylinderMeshes
   with **Top Radius = 0**, which makes a cone) and a low-poly **SphereMesh**
   rock in the last four. Set every mesh's **Radial Segments** to `6` for the
   faceted look.
7. Save as `res://scenes/track_chunk.tscn`.

### 6b. Wiring it into the level

1. Open `main.tscn`. Add a **Node3D** called `TrackManager`, attach
   `res://scripts/track_manager.gd`.
2. In the Inspector set **Chunk Scene** to `track_chunk.tscn`, and **Player** to
   your Player node.
3. Delete any old static ground — the manager makes its own.
4. On the **WorldEnvironment**, switch **Fog → Enabled** on, set **Mode** to
   `Depth`, **Density** to `1.0` (not the 0.01 default!), **Depth Begin** `60`,
   **Depth End** `150`, and set **Light Color** to the same colour as the sky's
   horizon.

### 6c. Wiring up the gameplay loop

1. **Make GameState global.** Project → Project Settings → **Globals** tab →
   **Autoload**. Set Path to `res://scripts/game_state.gd`, Node Name to
   `GameState`, click **Add**. Any script can now say `GameState.score`.
   *(This has to exist before the engine starts. If you ever see
   "Identifier not found: GameState", it's because a script was compiled before
   the autoload was registered — restart Godot.)*

2. **Tag the obstacles.** Select each `Obstacle` node in `track_chunk.tscn`,
   open the **Node** panel (next to Inspector) → **Groups** → type `obstacle` →
   **Add**. Do the same for the Player with the group `player`.
   *(Groups added in the editor are saved. Groups added in code are NOT, unless
   you pass `true` as the second argument — that one cost me an afternoon.)*

3. **Add the coins.** In `track_chunk.tscn` add a **Node3D** called `Coins`,
   and inside it eight **Area3D** children. Give each a **MeshInstance3D**
   (CylinderMesh, radius `0.32`, height `0.07`, **Radial Segments** `10`,
   rotated `90°` on X) and a **CollisionShape3D** (**SphereShape3D**, radius
   `0.55` — generous, so pickups feel good at speed).

4. **Build the HUD.** Add a **CanvasLayer** called `HUD`, attach
   `res://scripts/hud.gd`, and give it:
   - a **Label** called `Score`, anchored across the top, left-aligned
   - a **Label** called `Coins`, anchored across the top, right-aligned
   - a **Control** called `GameOver` (Full Rect, **Mouse → Filter = Ignore**,
     visibility off) containing a dark **ColorRect**, a **VBoxContainer**
     called `Box` (Full Rect, **Alignment = Center**) holding a `Title` label,
     a `Result` label and a `RestartButton`.

   For readable text over a bright sky, on each Label use the Inspector's
   **Theme Overrides**: set **Font Size**, **Colors → Font Color** to white,
   **Font Outline Color** to black, and **Constants → Outline Size** to `8`.

5. **Drop the HUD into `main.tscn`** alongside the Player, TrackManager and
   camera. That's the whole loop wired up.

---

## 7. If something goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| Ground vanishes under the camera | `Keep Behind` is smaller than the camera distance | Raise it above ~10 |
| You can see the track stop in mid-air | `fog_density` left at its 0.01 default | Set it to 1.0 |
| The track looks like it floats in mist | Sky flattened to the fog colour with no ground slab | Keep the wide `JungleFloor` |
| An invisible wall kills you | `visible = false` does **not** disable collision | Set `CollisionShape3D.disabled` too |
| Resizing one obstacle resizes them all | Godot shares sub-resources across every copy of a scene | `track_chunk.gd` calls `.duplicate()` on each shape and mesh at startup |
| Obstacles go solid one frame late | `disabled` is set with `set_deferred` | That's deliberate — a direct change from a collision signal silently desyncs |
| Jumps get eaten crossing a seam | `floor_snap_length` too short for 12 m/s | Already `0.5` on the Player |
| Player drifts between lanes on its own | A drag event with no touch-down | Already fixed; `test_swipe.gd` guards it |
| The run is impossible | A row blocked every lane | `_roll_row()` caps blocked lanes at `LANE_COUNT - 1` |
| Coins are never collected, camera loses its target | `add_to_group()` defaults to **non-persistent**, so the group is not saved into the scene | Pass `true`: `add_to_group("player", true)` |
| A coin pays out twice | `monitoring` written directly inside `body_entered` — Godot rejects it | Use `set_deferred("monitoring", false)`, and guard on `visible` |
| A hidden coin still collects | `visible = false` doesn't stop an Area3D | Turn `monitoring` off as well |
| "Identifier not found: GameState" | The autoload must exist **before the engine starts**; registering it mid-run isn't enough | Run `build_scenes.gd` twice on a fresh project — it tells you |
| Game over panel sits off-centre | `PRESET_CENTER` baked offsets from a zero-size container | Use `PRESET_FULL_RECT` + `ALIGNMENT_CENTER` |

---

## 8. The `tools/` folder

Developer scripts. **The game does not use any of them — delete the folder if you like.**

| File | What it does |
|---|---|
| `build_scenes.gd` | Rebuilds materials, all three scenes and the input map from scratch |
| `make_audio.py` | Synthesises the power-up, launch, shield, whoosh and footstep sounds (plain Python) |
| `export_view.gd` | Dumps a treetop section AND an ordinary stretch of track to JSON, to be viewed in a browser |
| `export_runner.gd` | Dumps the character rig and its baked animations, same idea |
| `test_probe.gd` | Player mechanics: run speed, lane slide, clamping, jump height, camera framing |
| `test_anim.gd` | Animations actually move the limbs, and the jump pose doesn't restart mid-air |
| `test_swipe.gd` | Swipe controls, including the phantom-lane-change guard |
| `test_track.gd` | Track continuity, pooling, obstacle fairness, lane alignment, shape sharing |
| `test_gameplay.gd` | Score, speed ramp, coin pickup, dying, landing forgiveness, restart |
| `test_feel.gd` | Banking, mid-air slam, the roll, the score multiplier |
| `test_landmark.gd` | Landmark generation, fairness, riding one, the end still killing |
| `test_gait.gd` | Measures the run cycle in-engine: sole height, left/right foot gap, knee speed, limb clipping |
| `test_jumpwindow.gd` | The press window, and that a jump never lands on something solid |
| `test_silhouette.gd` | Every obstacle's art against its own collider — the mesh must not lie about the gap |
| `test_compete.gd` | The daily seed gives everyone the same track; the board sorts, caps and chases |
| `test_juice.gd` | Close calls (in-lane vs next-lane), the landing squash, and the roll replaying |
| `test_powerups.gd` | All three power-ups: the slot, placement fairness, the magnet pull, the shield save, the surge |
| `test_canopy.gd` | Deck geometry per piece, the launch surviving mashed input, and a full round trip |
| `test_autoplay.gd` | Drives a robot player over three fixed seeds; bars the MEDIAN distance |
| `test_stumble.gd` | Side hits and clipped edges stumble; a second stumble while Bruno is hot catches you |
| `test_missions.gd` | The journal: missions tick, pages turn, the rank sticks, robots never tick a box |
| `test_coach.gd` | The coach names the right action, acting on its NOW cue always clears cleanly, it learns and remembers, robots are never coached |
| `capture.gd` | **Screenshots of the real game** in a window, the robot driving — see below |
| `gallery.gd` | Lines up every obstacle (or both landmarks, or the effects) in front of the camera for a screenshot |
| `audit.gd` | **Measures the game without opening a window** — see below |
| `autopilot.gd` | The robot player used by the test above |
| `smooth_mesh.gd` | The shape library for the characters: ellipsoids, rounded boxes, swept tubes, all with correct normals; the soft ink-lined character material |
| `char_monkey.gd` · `char_gorilla.gd` · `char_croc.gd` | The three sculpted characters. Each has `build(body, owner)` on the rig the animations expect |
| `flora_kit.gd` | The jungle's building blocks: leaf clumps, boulders, leaf blades, grass straps, spline trunks, bevelled boxes |
| `flora_trees.gd` · `flora_small.gd` | The roadside plants: palms, rainforest trees, undergrowth, bamboo, flowers, boulders |
| `preview_char.gd` | Renders one character alone from the in-game camera and close up (`PREVIEW_CHAR=monkey PREVIEW_POSE=run`) |
| `preview_flora.gd` | Same, for a flora module's showcase along a verge (`PREVIEW_FLORA=trees`) |
| `anim_strip.gd` | Renders one of the runner's real animations as a filmstrip from the chase camera, the side and behind (`STRIP_ANIM=run`) |

Run one with:

```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path ~/Documents/jungle-dash res://tools/test_track.tscn
```

To **see** the game without playing it, `capture` opens a window, lets the
robot drive, and saves PNGs at the frames you name. `--audio-driver Dummy`
keeps it silent. `CAP_TITLE=1 CAP_START=150` starts on the title screen and
presses start at frame 150; `CAP_SHIELD=30` hands the runner a surf plank;
`CAP_NOBOT=1` lets it crash.

```bash
CAP_FRAMES="120,420" CAP_OUT="$HOME/Desktop" CAP_SEED=4242 ~/Downloads/Godot.app/Contents/MacOS/Godot --path ~/Documents/jungle-dash --audio-driver Dummy --resolution 1280x720 res://tools/capture.tscn
```

Anything launched from `tools/` can never write to your save file.

> **A section that dies must not report PASSED.** A runtime error inside an
> `await`ed function aborts *that function* and lets the caller carry on — so
> `test_jumpwindow` printed `ALL JUMP CHECKS PASSED` while an entire section
> had died on line 82 and never ran a single assertion. Each section now marks
> itself finished and the verdict checks the marks. Silence is not success.

> **A profiler that measures a dead game measures nothing.** `profile_frames`
> loaded the real scene with no bot and no input, so the runner died in the
> first few seconds and 84% of its samples were of a stationary corpse. I then
> wrote a *second* probe an hour later and reproduced the identical mistake —
> five of six runs reported "no patterns seen", because the player never got
> far enough to meet one. Any probe that needs the game to be RUNNING has to
> attach `tools/autopilot.gd` and drive it.

> **Never read a property to decide whether to `set_deferred` it.** Skipping
> redundant collider toggles looked like free performance. It is not: a
> deferred write has not LANDED when you read the property back, so the read
> returns the stale value. Call `randomise()` twice before the frame ends —
> which the track manager does when it builds all nine pieces at once — and the
> second call sees the old state, skips, and the first call's pending write
> wins. The result was an obstacle that was **invisible and still lethal**.
> `test_track` caught it within a minute. Guarding `visible` IS safe, because
> that one applies immediately.

> **A test that ignores a dimension invents bugs.** The coin-placement check
> started by comparing only x and z, and reported **216 coins "buried inside an
> obstacle"**. Every one was a coin arcing *over* a log — directly above it in
> plan view and entirely correct. Comparing all three axes against the
> obstacle's real collider gives 0. A test that cries wolf is worse than no
> test, because the next real failure looks like more noise.

> **Match the file you are editing.** Two of these test scenes use a `_chk()`
> helper and two append to `_fails` directly. Pasting the wrong idiom in gives
> you a parse error, which — see below — hangs rather than fails.

> **A parse error makes a headless test HANG, not fail.** If a test scene's
> script doesn't compile, Godot reports the error and then sits there forever
> with no scene to run — it never exits, so there's no failure to notice and
> nothing in the output but the banner. It has cost me two long stalls. When a
> test seems to run forever, check for this first:
>
> ```bash
> ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path ~/Documents/jungle-dash res://tools/test_juice.tscn 2>&1 | grep "Parse Error"
> ```
>
> Worth knowing the second-order trap too: Godot's `print()` is **block
> buffered** when you redirect it to a file, so watching the file for progress
> tells you nothing until the process exits. `printerr()` goes to stderr and
> shows up immediately, which is what finally located it.

> **Seed your generators in tests.** `test_track.gd` re-rolled a piece with an
> unseeded `RandomNumberGenerator` and then raycast down at a switched-off
> obstacle. About a third of runs failed — not because of a bug, but because a
> landmark had spawned in that lane, and the ray was stopping on the landmark's
> roof. An unseeded generator turns a test into a coin flip and trains you to
> ignore it.

> Each test is a tiny **scene**, not a `--script` run. That matters: `--script`
> compiles the entry script before autoloads are resolvable, so anything that
> mentions `GameState` — directly or through a script it depends on — fails to
> compile. Running a scene works exactly the way the real game does.

---

## 8b. Checking your work without opening a window

`--headless` uses a dummy renderer, so you cannot screenshot from it, and every
windowed render steals focus from whatever you are doing. `tools/audit.tscn`
exists so you can still *measure* the game:

```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path ~/Documents/jungle-dash res://tools/audit.tscn
```

It loads the real scenes and walks their meshes, reporting:

- **Surfaces per chunk — these ARE draw calls**, because gl_compatibility does
  no batching. It calls `randomise()` first, so the figure is the real in-play
  one; straight from the scene file every hidden obstacle and scenery variant
  counts and you get a number three times too big.
- **Triangles**, broken down by layer, so you can see what is actually
  expensive.
- **The player's silhouette and head:body ratio**, which is how the character's
  proportions got fixed — see below.
- **Contrast of every character colour against the dirt and the foliage.**

The surface count it reports (~747) lines up with the draw calls measured from
an actual render (~716), so it is a fair substitute for looking.

---

## 9. Measured performance

**Now (Forward+, after the remake and the clarity pass), on an Apple M2 Max:**
the game draws about **105 frames per second at 1920×1080** (118 before the
clarity pass pushed the fog and shadows further out). Before that it drew
**118 frames per second at both 1280×720 and 1920×1080** — the display's
refresh rate, so it is waiting on the screen, not on work. About 780 draw
calls and ~350k triangles a frame; the CPU side of rendering costs 0.75 ms.
Measure it yourself with `tools/profile_frames.tscn` (run it windowed, with
`--audio-driver Dummy`). Much of what follows was measured on the old
Compatibility renderer and is kept for the reasoning, which still holds.

On this machine (Apple silicon, `gl_compatibility`, 1152×648):

| | |
|---|---|
| Surfaces in frame (= draw calls) | **~443** |
| Triangles in frame | **~215,000** |
| Surfaces across all 9 pooled pieces | ~738 |
| Triangles across all 9 pooled pieces | ~358,000 |
| Scene nodes | **1595, constant** — never grows, however far you run |
| Physics | 1 ms/frame |
| CPU render | 2.5 ms/frame (of a 16.7 ms budget for 60 fps) |

The first three are measured every time you run `tools/audit.tscn`. The last
two came from a windowed profile taken before the art changed, so treat them as
indicative rather than current — re-measuring them means opening a window.

**Shadows were costing more than the picture.** The sun ran 4 shadow splits
over 70 m, and every caster inside that range is re-drawn once *per split* — so
the jungle was being rendered five times a frame in total. Measured: 35 of the
41 visible meshes on a piece were casters, 29,005 triangles of them, which
works out at roughly **270,000 triangles of shadow work per frame against the
215,000 the actual picture costs**.

| | original | first attempt | shipped |
|---|---|---|---|
| splits | 4 | 2 | **4** |
| range | 70 m | 45 m | **45 m** |
| caster triangles / piece | 29,005 | 17,405 | **17,405** |
| shadow work per frame | ~270,000 | ~52,000 | **~104,000** |

**61% less than the original, and sharper than it too** — the nearest split now
covers about 4.5 m instead of 7 m.

The middle column is a mistake worth keeping on the page. Halving the split
count did cut the cost by 81%, and it also **halved the shadow resolution**,
because each split then has to cover twice the ground. A player reported the
result as "blurry", which it was. Cost is `range × splits × casters`, and only
two of those three terms were safe to touch: the range and the caster count
were carrying the waste, the split count was carrying the quality. The undergrowth stopped casting — it was 39% of all
the shadow work in the game, and it's ankle-high scrub whose shadow falls on
more scrub. The player's shadow and the obstacles' shadows carry the
information about where things are, and both are untouched. `audit.tscn`
reports the caster count now, because a number nobody prints is a number that
grows.

**Read the top two rows, not the bottom two.** This README used to quote the
nine-piece total as the cost, and that overstates it by about 40%. Geometry is
culled at 162 m, so only ~5.4 of the nine pooled pieces are ever drawn — the
rest exist so the track never has to allocate anything, not so they can be
rendered. `audit.tscn` now reports both figures.

**If you need it cheaper, there is one knob.** `DENSITY` at the top of
`build_scenes.gd` scales the scattered decor, which is the single largest slice
of the in-frame cost at ~42%. Measured:

| `DENSITY` | In frame | |
|---|---|---|
| `1.0` | 443 surfaces, 215k triangles | the desktop look |
| `0.6` | 378 surfaces, 141k triangles | a third cheaper, for a phone |

Change it and rebuild. There is deliberately nothing to win in the understory
or canopy — those are already built from 6-segment, 2-ring spheres, about as
cheap as a sphere gets, so the only way to shrink them is to remove plants.

**Honest note on the triangle count.** It went 80k → 254k when the jungle got
dense, and 254k → 335k when the hand-modelled Kenney plants replaced the
procedural ones (they are better-looking and denser; the trade was deliberate).
That is comfortable on desktop, but it is a lot for an older phone, and
`gl_compatibility` is a mobile-facing renderer. If you need to claw it back, in
order of value for effort:

1. `DENSITY` (above). One number, measured, no visible change to anything but
   how many plants there are.

   > Do **not** just drop `CULL_DISTANCE`. 162 m is not a round number, it is a
   > measured one: at 150 m objects are still 11/255 visible and clipping them
   > shows as a shimmer at the vanishing point; at 162 m they are 0/255. Pull
   > the cull in without pulling `fog_depth_end` in to match and you get
   > popping.
2. Reduce `DECOR_COUNT` (16) and the understory density.
3. The canopy and jungle-wall spheres are already down to 2 rings; the
   understory blades are the next biggest block.

**Every plant is ONE mesh.** A palm is a leaning trunk, seven fronds and a
knot of coconuts — twelve pieces. Built as twelve `MeshInstance3D` nodes it
cost twelve draw calls, and nine chunks of those measured **1023 draw calls**.
Merging each plant's parts into a single mesh with `SurfaceTool.append_from()`
— one surface per material — brought the same plant down to **2**. That is what
paid for a jungle dense enough to look like one: measured 1023 → 527 while
*increasing* the plant count per chunk from 12 to 16.

The same trick builds the jungle wall and the verge mottling: each is one
merged mesh per side, two draw calls for an entire backdrop.

That node count is the headline. Nine track pieces, 54 obstacles, 108 trees and
rocks, 72 coins, a player and a HUD — all created once at startup and recycled
forever. Run for five minutes or five hours and it stays at 870.

`gl_compatibility` does **no mesh batching** — every visible mesh is its own draw
call — so scenery and obstacles stop drawing past 162 m via
`visibility_range_end`. The fog has essentially hidden them by then, which buys
~16% fewer draw calls (455 → 382).

To be precise about the trade: culling isn't *pixel*-identical. Comparing
culled and un-culled renders of the same seed, a patch of about 60×20 pixels at
the vanishing point differs by at most 10/255, averaging 0.0005 across the
frame. That's below what you can see, and it doesn't grow if you push the fog
nearer — but it isn't zero. If you'd rather have the pixels than the frames,
set `CULL_DISTANCE` to `0.0` in `tools/build_scenes.gd` and rebuild.

---

---

## 9b. Is the game actually fair?

Worth knowing, because it's the one thing that isn't obvious from the code.

Obstacle rows are **15 m apart**, so the warning you get is `15 / speed`
seconds. A person needs roughly 0.25 s to react plus 0.35 s for the lane change
to finish — about **0.6 s** in total:

| Top speed | Warning | Verdict |
|---|---|---|
| 12 m/s (start) | 1.25 s | easy |
| **20 m/s (default max)** | **0.75 s** | **comfortable** |
| 24 m/s | 0.62 s | right on the edge |
| 30 m/s | 0.50 s | not reactable — you die to things you never saw |

The rows also used to be unevenly spaced (`[-8, -20]`, giving gaps of 12 m and
18 m). Only the *smallest* gap matters, so that one tight pair was setting the
difficulty of the whole game; spacing them evenly bought 25% more reaction time
for nothing.

A robot player with perfect reactions runs `tools/test_autoplay.gd`: three
fixed seeds, 6000 frames each (100 s at 60 Hz). It currently **survives every
seed without dying once**, finishing each at 1855 m.

That number is worth understanding, because it looks like a suspicious
coincidence and isn't one: 1855 m is the *ceiling*. Starting at 12 m/s and
ramping at 0.22 m/s², the runner takes 36.4 s to reach the 20 m/s cap and then
holds it — which works out to exactly 1855 m in 100 s. So three identical
distances isn't the bot getting stuck, it's the bot never dying. If a change
made the track unfair, these numbers would drop immediately.

The bar is on the **median**, not the best or the worst: one seed producing a
nasty run is data, not a regression, but two of three is.

---

## 9b2. Why you cannot screenshot this game

`--headless` uses a dummy rasteriser, and `RenderingServer.frame_post_draw`
never fires under it — so a `SubViewport` render returns nothing and the scene
simply hangs waiting. There is genuinely no way to get an image out of Godot
without opening a window.

What headless **can** do is read the exact vertices the renderer would have
drawn. So `tools/export_view.tscn` and `tools/export_runner.tscn` dump them —
geometry in world space coloured by the real materials, and the character rig
with its animations baked frame by frame out of the real `AnimationPlayer` —
and they get drawn somewhere else. Nothing is reconstructed or approximated:
every triangle is one the game would put on screen.

```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path ~/Documents/jungle-dash res://tools/export_view.tscn
```

---

## 9c. The art

Worth knowing what the choices were, since they're all in `build_scenes.gd`:

- **The jungle is sculpted in code, smooth rather than low-poly.** It used to
  be Kenney Nature Kit models (CC0, still in `assets/nature/` with their
  licence), recoloured into the game's palette. They are lovely low-poly art,
  but low-poly is exactly the faceted look the game grew out of. Every plant
  is now procedural (`tools/flora_*.gd`), in the project's own materials, so
  the wind shader, the fog and the one-mesh-per-plant draw-call budget all
  work as before. See section 1d.
- **The path is dirt, not grass.** Warm earth against cool green separates the
  playable lanes from the scenery instantly. That's a gameplay win as much as a
  visual one — the old light-green-on-green had almost no contrast.
- **The runner's colours are measured, not chosen.** Both things it runs
  across sit at nearly the same mid luminance — dirt 0.348, foliage 0.365 — so
  a mid-tone garment has nothing to separate against. The old teal top scored
  1.40 contrast against the path and 1.35 against the leaves; under ~1.6 is
  invisible, and the torso, pack and legs were ALL under it. The fix is to use
  only the extremes: every mass is now bright (luminance > 0.67) or dark
  (< 0.17), and they **alternate** down the figure — bright torso, dark arms,
  dark legs, bright shoes — so the moving parts read against the still ones.
  Everything now scores **2.05 or better** against both. `audit.tscn`
  re-checks it on every build, and it has caught a regression for real: the
  monkey's cap started out red, which is inherently mid-luminance and scored
  1.01 against the dirt — invisible. It's cream with a red band now.
- **The legs have knees now, and that was not a style choice.** The old run
  swung two rigid legs to equal and opposite angles. Foot height off a rigid
  leg is `hip - length x cos(angle)`, and cosine is an **even** function — so
  two legs at opposite angles sit at *exactly the same height* at every instant
  of the cycle. Measured, the two feet were never more than **0.086 m** apart
  vertically, against a pelvis bob of 0.100 m: the dominant motion was both
  feet rising and falling together. That is a pogo stick, and no amount of
  keyframing fixes it while the leg is one rigid rod.

  With `Knee` and `Ankle` pivots and a proper contact/absorb/pass/toe-off/tuck
  cycle the gap is **0.285 m**, and `tools/test_gait.tscn` re-measures it —
  along with whether the soles actually reach the ground (the old cycle's
  lowest sole was 7 cm up; the monkey hovered) and whether any limb passes
  through the body.
- **The run used to lean backwards.** `Visual:rotation.x` was `+0.10`, and for
  a node whose up axis is +Y a positive X rotation tips it *away* from where it
  is going. Six degrees of it, for the whole run. It is `-0.10` now.
- **Stride rate follows speed.** The cycle is authored for the 12 m/s starting
  pace; at the 20 m/s cap it plays 1.67x faster. Without that the monkey takes
  the same number of steps to cover far more ground, which reads as skating.
- **The head is 29% of total height.** It was 20%, which reads as a
  small-headed adult and turns to mush at the ~100 px the character actually
  occupies. Stylised runners land at 28-34%.
- **The scenery variety metric was lying, and it took a false alarm to notice.**
  `audit.tscn` used to count distinct verge/wall combinations over 60 recycles.
  Sampled with five different seed bases that returns 25, 29, 27, 29 and 28 — so
  a perfectly healthy build can look like it has lost a fifth of its variety
  purely by chance, and I read exactly that as a regression I had caused. At
  240 recycles it settles on **36, and 36 is the ceiling** (identical at 600).
  The audit now samples 240, reports the number against that ceiling, and says
  so loudly if it ever drops below 90% of it. A number that moves on its own is
  not a measurement.
- **Three layers of depth.** Path, then individual plants 6–13 m out, then a
  wall of green behind them. Put the wall in the same band as the plants and it
  just swallows them.
- **Glow was blooming the entire sunlit scene.** `glow_hdr_threshold` was left
  at Godot's default of 1.0, which was harmless until the obstacle palette was
  rebuilt around BRIGHT colours — `ob_stone` at 0.82 albedo under full sun
  comfortably exceeds 1.0, so a threshold meant to catch glowing pickups began
  blooming every lit surface. Two things made it worse than it looked: the
  brightening was deliberate and recent, and `glow_blend_mode` **does nothing
  on this renderer** (Compatibility always screen-blends), so the gentle blend
  asked for was silently the strongest one available. Threshold 1.5, intensity
  0.35, bloom off.
- **Anti-aliasing went 4x → 2x → 4x.** It was dropped while chasing a stutter,
  *before* the shadow work was found — and shadows were costing five times what
  MSAA does. Fixing the real culprit paid for the anti-aliasing to come back.
- **The HUD was being magnified.** With stretch mode `canvas_items` the 3D
  renders at the window's true size but the 2D layer is laid out at the base
  resolution and scaled — and the base was never set, so it defaulted to
  1152x648. On a 2560-wide display that is a 2.2x upscale of text. It is
  1920x1080 now, so a 1080p window is pixel-perfect and a 1440p one scales by
  1.33 instead.
- **Glow is on; SSAO is not, and cannot be.** The emissive materials — coins,
  the magnet's pale tips, the surge gem, the trampoline's markings — were just
  flat bright colours until glow was enabled. SSAO would be the bigger win, but
  this game runs on the **Compatibility** renderer, and there is not one single
  GLES3 SSAO symbol in the engine binary: every one belongs to Forward+.
  Switching it on would have been a silent no-op. `drivers/gles3/effects/glow.cpp`
  does exist, which is why glow is real here and ambient occlusion is not.
- **Anti-aliasing was off entirely.** The project had no `[rendering]`
  anti-aliasing section, so `msaa_3d` defaulted to 0 — and every edge in a
  low-poly game is a hard diagonal against a flat colour, which is the worst
  case there is. MSAA plus debanding is two lines.

  It shipped at 4x and is now **2x**: MSAA costs memory bandwidth rather than
  shader work, and on a machine already dropping frames that is the wrong thing
  to spend. 2x removes most of the stair-stepping for about half the cost.
  Raise it again once the frame rate has room.
- **The sun sits lower, at 38 degrees.** A 1.8 m runner casts `1.8/tan(52)` =
  1.41 m of shadow at the old angle and `1.8/tan(38)` = 2.30 m now — 63% more.
  The shadow is the main cue for where the character is relative to the ground,
  so a longer one is a readability win as much as a prettier one.
- **The bamboo was drawn with the wrong material.** `crops_bambooStageB` has a
  single green surface, so the "is this wood or foliage" sort sent the whole
  plant — stalks included — to the leaf material, and the bamboo colour was
  never used by anything in the game.
- **The obstacles were camouflaged, and nobody had measured them.** The
  character's colours are chosen by contrast measurement against both
  backgrounds — dirt at luminance 0.348 and foliage at 0.365 — and every part
  scores 2.05 or better. That same test had *never* been pointed at the
  obstacles. When it finally was, **seven of eight failed**, and the hanging
  vines scored **1.00 against the jungle**: identical brightness, so the thing
  you had to duck was invisible.

  Obstacles now have their own palette (`ob_wood`, `ob_stone`, `ob_vine` and
  their bright counterparts), separate from the scenery that shares their
  shapes — which is what allows them to be tuned for visibility without
  recolouring the jungle behind them. Same rule as the character: DARK
  (luminance under 0.199) or BRIGHT (over 0.62), never the mid band, so every
  obstacle is a dark mass with bright trim or the reverse. Worst score is now
  **1.81**, and `test_track.tscn` fails the build if any of them drops below
  1.60.
- **The art has to tell the truth about the collider.** The hanging vines'
  strands were built down to y **0.716** while their collider stops at
  **1.050** — so the gap you had to duck through *looked* a third of a metre
  smaller than it was. That never shows up as a death, which is why nothing
  caught it for the entire life of the project; it just made every duck feel
  like a guess. `test_silhouette.tscn` now measures every obstacle's mesh
  against its own collider and fails if a duckable's art hangs below the gap or
  a ground obstacle's art stands above its box.
- **The landmark was wearing the scenery's clothes.** The obstacle palette rule
  — dark under 0.199 or bright over 0.62, never the mid band — was applied to
  the six one-metre obstacles and *not* to the 16 m landmark, which is the
  biggest lethal object in the game and turns up on 38% of pieces. Five of its
  six materials sat squarely in the forbidden band; the blunt end you crash
  into scored **1.18** and the mossy top you are meant to aim a jump at scored
  **1.08**. It was never in the audit's list, so it passed every test while
  failing the project's own rule on every surface it has.
- **Coins on the treetop deck were invisible.** Gold on warm tan planks, both
  sunlit, measured **1.06**. They are the *entire* content of the treetop run
  and on the narrow stretch a line of them is how you learn which lane to be in.
  The deck is dark timber now and the same coin scores **3.65**. The audit
  checks surface *pairings* now, not just everything against the ground —
  a coin on a deck is never seen against dirt, so measuring it against dirt
  said nothing.
- **The magnet made the same mistake the cap did.** Red cannot be bright: its
  luminance is dominated by a green channel it doesn't have, so it sits in the
  mid band and vanishes against the path. The README already told that story
  about the monkey's cap; the magnet had it too, at **1.07**. Bright orange.
- **Landings have weight now.** A hard landing squashes the runner to about
  82% of its height and springs back over 0.22 s, scaled by how fast it was
  falling — a gentle hop barely registers, dropping off the 7 m treetop deck
  is a real thud. Squash-and-stretch is the oldest trick in animation and it
  costs nothing: it writes only `Visual.scale`, which no animation touches.
- **The dirt used to meet the greenery on a dead straight line** running the
  full 30 m of every piece, which is the single thing that most reads as "made
  of tiles" from a distance. Grass tufts overlapping the join break it. They go
  into the *same* merged mesh as the verge patches, so they cost no extra draw
  call — and the density is set where the seam stops reading, because twice as
  many looked slightly better and cost 40,000 triangles.
- **The colour grade is subtle.** ACES tonemapping lifts midtones, so exposure
  has to come *down* to compensate — at 1.15 the dirt blew out to near-white
  sand and the greens went neon. 0.88 is the measured sweet spot.

---

## 9d. Where the art came from (and what you may do with it)

- **Every model in the game is made in code**: the characters in
  `tools/char_*.gd`, the plants in `tools/flora_*.gd`, everything else in
  `tools/build_scenes.gd`. There is nothing to license. The game used to use
  the [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) (**CC0 /
  public domain**) for its plants. Those files are still in `assets/nature/`
  with their licence, but no scene uses them any more (see section 1d for why).
- **The characters are procedural on purpose.** Nobody offers a CC0 rigged,
  animated monkey (Quaternius' packs have no primates), and an unrigged
  download would have been a statue sliding down the track. So all three are
  sculpted from smooth parametric surfaces onto a pivot rig, and every limb
  still animates.
- **Every sound is synthesised**, not recorded or downloaded — generated from
  maths with nothing but Python's standard library, so there is nothing to
  license. `tools/make_audio.py` builds the power-up chime and shows how the
  rest were made: a rising major arpeggio, because rising intervals read as
  "you gained something" and the crash sound falls for the same reason.

The upshot: **the whole project is yours to publish.** Nothing in it has an
attribution requirement or a non-commercial clause.

---

## 10. What to build next

The long list from the remake's brainstorm, in the order it would pay off:

- **Ramps onto taller landmarks** — a fallen trunk leaning up onto a higher
  one, so there's a roof you can only reach by running up. Needs the crest of
  the ramp to not fling you into the air (move_and_slide projects your speed
  up the slope); test it at 12, 16 and 20 m/s.
- **A toucan ride** (the jetpack): grab a feather and get carried over the
  trail for a stretch of sky-high coins.
- **A trading post** for the coins you bank: other monkeys and hats.
- **Time of day**: golden hour and then a firefly night as the run goes on.
- **A jaguar** as the chaser, if you'd rather it be a real jungle animal.

1. **A fourth power-up.** The slot already takes one: add a value to
   `enum Pickup`, a weight to `PICKUP_WEIGHTS`, a look under `Looks` in
   `build_scenes.gd`, and a branch in `_on_pickup_touched`. Nothing else needs
   to change — the placement, fairness and HUD all work off the table. A
   double-jump or a brief slow-motion would both fit.

   > If you try slow-motion, be careful: the jump and the duck are **timed**,
   > not distance-based, so slowing forward speed silently shortens how far a
   > jump carries you and breaks every reaction margin in section 9b. Slow the
   > whole game with `Engine.time_scale` instead of just the runner.
2. **Something to do on the treetops.** Right now they're a pure rest, which is
   deliberate — but a gap to jump, or a branch to duck, would work as long as
   the fall stays harmless.
3. **More chunk variety.** Give `TrackManager` an array of chunk scenes — a
   bridge, a ruin, a river — and pick randomly when recycling.
4. **A real character model.** Import a `.glb`, put it under `Visual`, delete the
   placeholder boxes. `player.gd` keeps working as long as the animations are
   still called `run` and `jump`.
5. **A floating origin** — only if you want sessions longer than a few hours.
   World coordinates grow forever, and eventually floats get coarse. The fix is
   to shift everything back toward zero periodically. **The obvious version of
   this doesn't work:** moving a shared parent node leaves every child's *local*
   position just as large, so the precision problem is unchanged. Each node's own
   `position` has to be rewritten — player, camera and every chunk root.
