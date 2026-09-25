extends RefCounted
## TREES — the verge's palms and rainforest trees, built smooth instead of
## from Kenney's cubes and faceted gems.
##
##   palm(index)       a tropical palm, 4 variants: 0 a coconut palm with a
##                     cluster of nuts, 1 a clumping areca (three slender
##                     stems and a dead frond), 2 a tall leaning palm, 3 a
##                     royal palm with a smooth green crownshaft. Ringed,
##                     tapering trunks on a foot of root nubs; crowns of long
##                     arching PINNATE fronds (a midrib with narrow leaflets
##                     down both sides, drooping toward the tips) round a
##                     spear leaf or two rising from the middle
##   broadleaf(index)  a rainforest tree, 5 variants: 0 an emergent with plank
##                     buttresses and a flat umbrella crown on spoke limbs,
##                     1 a fig with a broad low dome and aerial roots, 2 a
##                     young Cecropia holding rosettes of big lobed leaves out
##                     on candelabra branches, 3 a two-tiered tree hung with
##                     lianas, 4 a strangler fig: a lattice of roots round a
##                     lost host, with a lopsided crown
##   showcase()        one of each along the right verge, for preview_flora
##
## Every builder returns merge-list parts (see flora_kit.gd) and builds the
## same plant every time for the same index.
##
## Crowns are clusters of soft foliage masses (FK.clump) that carry the
## form, with tufts of small ovate leaves hanging from their exposed rims to
## break the outline. The parts of a mass buried inside its neighbours can
## never be seen, so they are dropped, and pay for the leaves.
##
## Shading. The foliage shader draws both faces of a sheet and flips the
## normal on the face seen from behind. Palm leaflets carry (mostly) their
## own face's normal, so from behind the flipped normal is the true normal of
## the back of the leaflet. A crown's tuft leaves hang in its shade, lit by
## the sky alone: they are wound to face out of the crown (the face anyone
## outside it sees) and carry a level normal, whose flip is level too and
## sees the same horizon light, so they shade alike from either side at half
## the triangles of a two-sided leaf. The masses' undersides are flattened
## toward the level for the same reason: tipped up, a normal in shade takes
## the blue of the sky; tipped down, the dark of the ground. The Cecropia's
## big lobes are FK.blade, which builds both faces with their own normals.
##
## Used as:  const FT := preload("res://tools/flora_trees.gd")

const FK := preload("res://tools/flora_kit.gd")
const SM := preload("res://tools/smooth_mesh.gd")

const UV := Vector2(0.5, 0.5)
## Below this height every plant stays inside its footprint radius, so the
## verge planting never reaches into the running lanes.
const LOW_H := 4.0
const GOLDEN := 2.39996

## Leaf-scar ring shading: how far a ring's lip tilts toward the sun, and how
## far the band above it tilts into shadow.
const RING_UP := 0.09
const RING_DN := 0.06
## How far foliage normals are bent toward the sky: light scattered through a
## canopy keeps its underside from going black.
const LIFT := 0.15
## How much of a foliage mass's shading comes from the crown as a whole
## rather than from the mass itself, so a crown reads as one soft volume.
const CROWN_BLEND := 0.35
## How deep FK.clump presses its lumps into a foliage mass. Deeper lumps at
## the resolution the budget allows carve flat facets and crisp self-shadow
## edges: the faceted look this replaces.
const LUMP := 0.14
## A mass's triangles are dropped when all three corners are this deep
## inside a neighbour (as a fraction of its radii): past its deepest lump.
const BURIED := 0.84
## How strongly a foliage mass's normals are dappled (see _dapple).
const DAPPLE := 0.3


# =============================================================================
#  SHOWCASE
# =============================================================================

static func showcase() -> Array:
	var out: Array = []
	_place(out, palm(0), Vector3(6.0, 0.0, -6.0), PI * 0.9)
	_place(out, broadleaf(0), Vector3(10.5, 0.0, -9.5), 0.4)
	_place(out, palm(1), Vector3(7.0, 0.0, -13.0), PI * 1.1)
	_place(out, broadleaf(1), Vector3(7.2, 0.0, -19.5), 1.3)
	_place(out, palm(2), Vector3(12.0, 0.0, -16.5), PI)
	_place(out, broadleaf(2), Vector3(9.0, 0.0, -25.0), 2.1)
	_place(out, palm(3), Vector3(6.5, 0.0, -30.0), 0.5)
	_place(out, broadleaf(3), Vector3(11.5, 0.0, -31.0), 3.3)
	_place(out, broadleaf(4), Vector3(7.5, 0.0, -38.0), 4.4)
	return out


static func _place(out: Array, parts: Array, at: Vector3, spin: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, spin), at)
	for p: Dictionary in parts:
		var q := p.duplicate()
		q["xform"] = xf * (p["xform"] as Transform3D)
		out.append(q)


# =============================================================================
#  PALM
# =============================================================================

## Per-variant settings: trunk-top height, lean, trunk shape (0 lean and
## rise, 1 gentle S, 2 upright), radius above the foot and under the crown,
## fronds, frond length, droop, leaflet pairs, how many young (pale) fronds.
## (Variant 1, the clumping areca, is built by _areca with its own.)
static func _palm_cfg(v: int) -> Dictionary:
	match v:
		0:
			return {"h": 4.75, "lean": 0.55, "shape": 0, "rb": 0.165, "rt": 0.115,
				"fronds": 10, "len": 2.4, "droop": 1.0, "pairs": 20, "young": 3}
		2:
			return {"h": 5.3, "lean": 0.78, "shape": 0, "rb": 0.17, "rt": 0.115,
				"fronds": 12, "len": 2.45, "droop": 1.05, "pairs": 21, "young": 3}
		_:
			return {"h": 5.0, "lean": 0.16, "shape": 2, "rb": 0.19, "rt": 0.14,
				"fronds": 12, "len": 2.25, "droop": 0.85, "pairs": 21, "young": 3,
				"shaft": true}


static func palm(index: int) -> Array:
	var v := posmod(index, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40177 + index * 7919
	var wood := _st()
	var old_st := _st()
	var young_st := _st()
	var parts: Array = []
	if v == 1:
		_areca(wood, old_st, rng, parts)
		parts.append(FK.part(wood.commit(), Transform3D(), "bark"))
		parts.append(FK.part(old_st.commit(), Transform3D(), "frond"))
		return parts
	var cfg := _palm_cfg(v)
	var crown := _palm_stem(wood, old_st, young_st, rng, cfg)
	if v == 0:
		# A tight cluster of nuts tucked under the frond bases. Their stalks
		# grow from the trunk's top, so they hang still while the fronds
		# above them sway (bark, like the trunk).
		var top: Vector3 = crown[0]
		var r_top: float = crown[1]
		var na: float = float(crown[2]) + 0.9
		var nut := SM.ellipsoid(Vector3(0.085, 0.1, 0.085), 8, 6)
		var hub := top + Vector3(cos(na), 0.0, sin(na)) * (r_top + 0.06) + Vector3.DOWN * 0.2
		for q in 4:
			var qa := na + float(q) * 1.57 + rng.randf_range(-0.2, 0.2)
			var at := hub + Vector3(cos(qa), 0.0, sin(qa)) * 0.085 \
				+ Vector3.DOWN * (0.05 * float(q % 2) + rng.randf_range(0.0, 0.03))
			_append(wood, nut, Transform3D(Basis(Vector3(sin(qa), 0.0, -cos(qa)), 0.3), at))
	parts.append(FK.part(wood.commit(), Transform3D(), "bark"))
	parts.append(FK.part(young_st.commit(), Transform3D(), "frond_light"))
	parts.append(FK.part(old_st.commit(), Transform3D(), "frond"))
	return parts


## 1 — a clumping areca: three slender ringed stems from one foot, splaying
## out and turning up, each with a few upright arching fronds, and one dead
## frond hanging straw-brown against a stem.
static func _areca(wood: SurfaceTool, fronds: SurfaceTool, rng: RandomNumberGenerator,
		parts: Array) -> void:
	var az0 := rng.randf_range(0.0, TAU)
	var hs: Array[float] = [3.4, 4.0, 3.7]
	var nf: Array[int] = [5, 5, 4]
	var tall := Vector3.ZERO
	var tall_r := 0.0
	var tall_az := 0.0
	for s in 3:
		var az := az0 + TAU * float(s) / 3.0 + rng.randf_range(-0.3, 0.3)
		var cfg := {"h": hs[s] + rng.randf_range(-0.1, 0.1), "lean": rng.randf_range(0.36, 0.46),
			"shape": 0, "rb": 0.085, "rt": 0.062, "fronds": nf[s], "len": 1.75,
			"droop": 0.85, "pairs": 13, "young": 0, "arch": true, "nubs": false,
			"gap": 0.62, "spears": 1, "lw": 0.045,
			"foot": Vector3(cos(az), 0.0, sin(az)) * 0.12, "az": az}
		var crown := _palm_stem(wood, fronds, fronds, rng, cfg)
		if s == 1:
			tall = crown[0]
			tall_r = crown[1]
			tall_az = crown[2]
	# The dead frond: limp, hanging against the tallest stem. Static, like the
	# stem it hugs.
	var dead := _st()
	var da := tall_az + 1.2
	var dd := Vector3(cos(da), 0.0, sin(da))
	var buf: Array = []
	for attempt in 10:
		buf.clear()
		_frond(buf, tall + dd * (tall_r * 1.2) + Vector3.DOWN * 0.08, da,
			-0.3 - 0.12 * float(attempt), 0.9, 1.3, 10, 0.36, 0.045, 0.0, 0.0, 0.3, 0.1,
			tall + Vector3.UP * 0.1, true)
		if _fits(buf, 0.88):
			break
	_flush(dead, buf)
	parts.append(FK.part(dead.commit(), Transform3D(), "trunk"))


## One palm stem (see _palm_cfg for `cfg`). Its trunk, root nubs and leaf-base
## boss go into `wood`; its fronds into `young_st` (the youngest few) and
## `old_st`. Returns [crown top, radius under the crown, first frond azimuth].
static func _palm_stem(wood: SurfaceTool, old_st: SurfaceTool, young_st: SurfaceTool,
		rng: RandomNumberGenerator, cfg: Dictionary) -> Array:
	var h: float = cfg["h"]
	var rb: float = cfg["rb"]
	var rt: float = cfg["rt"]
	var shaft: bool = cfg.get("shaft", false)
	var nubs: bool = cfg.get("nubs", true)
	var gap: float = cfg.get("gap", 0.45)
	var az_l: float = cfg.get("az", 0.0)
	var foot: Vector3 = cfg.get("foot", Vector3.ZERO)
	# The trunk's line: [foot, lean direction, side direction, height, lean,
	# shape, wobble, phase].
	var ax: Array = [foot, Vector3(cos(az_l), 0.0, sin(az_l)), Vector3(-sin(az_l), 0.0, cos(az_l)),
		h, float(cfg["lean"]), int(cfg["shape"]), rng.randf_range(0.04, 0.08), rng.randf_range(0.0, TAU)]
	var bottle := 0.22 if shaft else 0.0

	# --- the trunk: one row per leaf-scar ring, a little irregular, fading
	# in above the foot; then the swollen boss of old leaf bases.
	var y0 := 0.36 if nubs else -0.1
	var top_y := h - 1.36 if shaft else h - 0.25
	var ys: Array[float] = [y0]
	var rings: Array[float] = [0.0]
	var y := y0 + gap * rng.randf_range(0.7, 1.0)
	while y < top_y - 0.22:
		if shaft and y > h - 1.75:
			break
		ys.append(y)
		rings.append(rng.randf_range(0.55, 1.0) * (0.35 + 0.65 * smoothstep(0.3, 2.2, y)))
		y += gap * rng.randf_range(0.8, 1.2)
	if shaft:
		# A crisp dark join just under the crownshaft's foot.
		ys.append(h - 1.6)
		rings.append(1.3)
	ys.append(top_y)
	rings.append(0.0)
	var pts: Array = []
	var radii: Array = []
	for yy in ys:
		pts.append(_palm_pt(ax, yy))
		radii.append(_palm_radius(yy, h, rb, rt, bottle))
	var r_top: float = radii[radii.size() - 1]
	var top := _palm_pt(ax, h)
	if not shaft:
		# The boss of old leaf bases, capped low so the young fronds and the
		# spear leaves rise out of it rather than round a bald dome.
		var by: Array[float] = [h - 0.1, h + 0.06, h + 0.16]
		var bk: Array[float] = [1.3, 1.38, 0.95]
		for q in 3:
			pts.append(_palm_pt(ax, by[q]))
			radii.append(r_top * bk[q])
			rings.append(0.0)
	if nubs:
		var fins: Array = []
		var a0 := rng.randf_range(0.0, TAU)
		for i in 4:
			fins.append([a0 + TAU * float(i) / 4.0 + rng.randf_range(-0.3, 0.3),
				rng.randf_range(0.1, 0.15), rng.randf_range(0.26, 0.34), rb * 0.22])
		_flare(wood, fins, _palm_radius(0.0, h, rb, rt, bottle), _ring0(pts, radii), 2, 2)
	_ringed_tube(wood, pts, radii, rings, 12)

	if shaft:
		# A smooth green crownshaft, swaying with the fronds it holds: its
		# foot a flared lip over the trunk (in shade: the dark join), a slight
		# bulge, then narrowing into the crown.
		var cs_y: Array[float] = [h - 1.52, h - 1.42, h - 1.12, h - 0.7, h - 0.3, h + 0.02, h + 0.24]
		var cs_k: Array[float] = [1.42, 1.62, 1.5, 1.58, 1.46, 1.2, 0.78]
		var cs_p: Array = []
		var cs_r: Array = []
		for q in cs_y.size():
			cs_p.append(_palm_pt(ax, cs_y[q]))
			cs_r.append(r_top * cs_k[q])
		_tube(old_st, cs_p, cs_r, 12, true)

	# --- the fronds, placed by the golden angle, youngest (highest, most
	# upright) first. Rooted near the crown's axis, so the wind's sway of the
	# crown never pulls one off the trunk.
	var n_f: int = cfg["fronds"]
	var flen: float = cfg["len"]
	var droop: float = cfg["droop"]
	var pairs: int = cfg["pairs"]
	var young: int = cfg["young"]
	var arch: bool = cfg.get("arch", false)
	var lw: float = cfg.get("lw", 0.05)
	var az0 := rng.randf_range(0.0, TAU)
	var centre := top + Vector3.UP * 0.1
	for f in n_f:
		var a := float(f) / float(n_f - 1)
		var az := az0 + float(f) * GOLDEN
		var dir := Vector3(cos(az), 0.0, sin(az))
		# Young fronds rise from the top; old ones leave the boss's sides, so
		# their stalks clothe it.
		var base := top + dir * (r_top * lerpf(0.1, 0.45, a)) + Vector3.UP * lerpf(0.2, -0.12, a)
		var e0 := lerpf(0.95, -0.05, a) + rng.randf_range(-0.07, 0.07)
		var bend := (lerpf(0.55, 1.6, a) + rng.randf_range(-0.1, 0.1)) * droop
		# The leaflets make a V near the frond's base and hang in an inverted
		# V toward its tip, as a coconut frond's do.
		var v_in := lerpf(0.62, 0.42, a)
		var v_out := lerpf(-0.2, -0.6, a)
		if arch:
			# An areca's fronds rise steeply and arch over, leaflets held up.
			e0 = lerpf(1.3, 0.8, a) + rng.randf_range(-0.07, 0.07)
			bend = (lerpf(0.9, 1.7, a) + rng.randf_range(-0.1, 0.1)) * droop
			v_in = 0.72
			v_out = 0.2
		var ln := flen * lerpf(0.7, 1.0, sqrt(a)) * rng.randf_range(0.94, 1.05)
		var curl := rng.randf_range(-0.22, 0.22)
		var buf: Array = []
		for _attempt in 14:
			buf.clear()
			_frond(buf, base, az, e0, bend, ln, pairs, ln * 0.3, lw, v_in, v_out, 0.45,
				curl, centre, false)
			if _fits(buf, 0.88):
				break
			e0 += 0.06
			bend *= 0.92
		_flush(young_st if f < young else old_st, buf)

	# --- the spear: the next frond, still furled, standing up out of the
	# middle of the crown.
	var n_sp: int = cfg.get("spears", 2)
	for s in n_sp:
		var tilt := Vector3(rng.randf_range(-0.14, 0.14), 1.0, rng.randf_range(-0.14, 0.14)).normalized()
		var sp := FK.strap(0.07, rng.randf_range(0.85, 1.2) * (0.8 if arch else 1.0), 0.05, 0.045, 4)
		_append(young_st, sp, Transform3D(FK.aim_y(tilt, rng.randf_range(0.0, TAU)),
			top + Vector3.UP * (0.02 + 0.07 * float(s))))
	return [top, r_top, az0]


## The trunk's centre line at height y (see _palm_stem for `ax`): shape 0
## leans out from the foot and turns back up toward the light (the classic
## coconut curve), shape 1 is a gentle S, shape 2 nearly upright. A small
## sideways wander on top.
static func _palm_pt(ax: Array, y: float) -> Vector3:
	var h: float = ax[3]
	var lean: float = ax[4]
	var shape: int = ax[5]
	var t := clampf(y / h, 0.0, 1.0)
	var off := 0.0
	if shape == 0:
		off = lean * (1.0 - pow(1.0 - t, 2.0))
	elif shape == 1:
		off = lean * (0.75 * sin(PI * t) + 0.4 * t * t)
	else:
		off = lean * t * t
	var side: float = float(ax[6]) * sin(t * 5.0 + float(ax[7])) * t
	return (ax[0] as Vector3) + (ax[1] as Vector3) * off + (ax[2] as Vector3) * side \
		+ Vector3.UP * y


static func _palm_radius(y: float, h: float, rb: float, rt: float, bottle: float) -> float:
	var t := clampf(y / h, 0.0, 1.0)
	var r := lerpf(rb, rt, pow(t, 0.8))
	r += bottle * rb * pow(sin(PI * clampf(t * 1.15, 0.0, 1.0)), 2.0)
	# A modest swelling at the foot, where the roots go into the soil.
	r += rb * 0.5 * exp(-maxf(y, 0.0) / 0.2)
	return r


## A palm trunk through `pts`, ringed with leaf scars. At every row whose
## `rings` value is above zero the shading snaps from bright (the scar's lip,
## tilted toward the sun) to shadow (the band above it, tilted away), so a
## ring costs ONE row of triangles, not the three a modelled ridge would.
## The top is closed with a short rounded cone.
static func _ringed_tube(st: SurfaceTool, pts: Array, radii: Array, rings: Array,
		sides: int) -> void:
	var n := pts.size()
	var tans: Array[Vector3] = []
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		tans.append((b - a).normalized())
	var dirs := _frames(tans, sides)
	for i in n - 1:
		var j := i + 1
		var si := _slope(pts, radii, i)
		var sj := _slope(pts, radii, j)
		var pi_: Vector3 = pts[i]
		var pj: Vector3 = pts[j]
		var ri: float = radii[i]
		var rj: float = radii[j]
		var ki: float = rings[i]
		var kj: float = rings[j]
		for k in sides:
			var k2 := (k + 1) % sides
			var d0: Vector3 = dirs[i][k]
			var d1: Vector3 = dirs[i][k2]
			var e0: Vector3 = dirs[j][k]
			var e1: Vector3 = dirs[j][k2]
			# Bottom of the band: in the shade above ring i.
			var n0 := (d0 - tans[i] * (si + RING_DN * ki)).normalized()
			var n1 := (d1 - tans[i] * (si + RING_DN * ki)).normalized()
			# Top of the band: the lip under ring j, catching the light.
			var m0 := (e0 - tans[j] * (sj - RING_UP * kj)).normalized()
			var m1 := (e1 - tans[j] * (sj - RING_UP * kj)).normalized()
			_quad(st, [pi_ + d0 * ri, n0], [pj + e0 * rj, m0], [pj + e1 * rj, m1],
				[pi_ + d1 * ri, n1])
	_cap(st, pts[n - 1], tans[n - 1], dirs[n - 1], radii[n - 1], _slope(pts, radii, n - 1))


# --- fronds ------------------------------------------------------------------

## One pinnate palm frond, as triangles into `buf` (see _push). The midrib
## leaves `base` along azimuth `az` at elevation `e0` and arches down through
## `bend` radians over `length`. `pairs` leaflets a side: the longest `lmax`,
## `lw` wide, raised `v_in` radians above the frond's plane near its base and
## `v_out` at the tip. `sag` is how far each leaflet's tip hangs, per metre of
## it. `limp` hangs every leaflet straight down: a dead frond.
static func _frond(buf: Array, base: Vector3, az: float, e0: float, bend: float,
		length: float, pairs: int, lmax: float, lw: float, v_in: float, v_out: float,
		sag: float, curl: float, centre: Vector3, limp: bool) -> void:
	var segs := 7
	var pts: Array[Vector3] = [base]
	var p := base
	for k in segs:
		var u := (float(k) + 0.5) / float(segs)
		var th := e0 - bend * pow(u, 1.5)
		var a2 := az + curl * u
		p += Vector3(cos(a2) * cos(th), sin(th), sin(a2) * cos(th)) * (length / float(segs))
		pts.append(p)
	var tans: Array[Vector3] = []
	for k in segs + 1:
		tans.append((pts[mini(k + 1, segs)] - pts[maxi(k - 1, 0)]).normalized())
	var side := Vector3.UP.cross(Vector3(cos(az), 0.0, sin(az))).normalized()

	# The midrib: a narrow ribbon, broad at the base and a thread at the tip,
	# rounded by its normals.
	var edges: Array = []
	for k in segs + 1:
		var t := tans[k]
		var s := (side - t * side.dot(t)).normalized()
		var up := t.cross(s)
		var hw := lerpf(0.06, 0.01, pow(float(k) / float(segs), 0.6))
		edges.append([pts[k] + s * hw, pts[k] - s * hw, (up + s * 0.6).normalized(),
			(up - s * 0.6).normalized()])
	for k in segs:
		var ea: Array = edges[k]
		var eb: Array = edges[k + 1]
		_push(buf, ea[0], eb[0], eb[1], ea[2], eb[2], eb[3])
		_push(buf, ea[0], eb[1], ea[1], ea[2], eb[3], ea[3])

	# Leaflets, both sides, angled forward toward the tip.
	var u0 := 0.14
	for i in pairs:
		var w := (float(i) + 0.5) / float(pairs)
		var u := u0 + (1.0 - u0) * w
		var fi := u * float(segs)
		var k := mini(int(fi), segs - 1)
		var fr := fi - float(k)
		var at := pts[k].lerp(pts[k + 1], fr)
		var t := tans[k].lerp(tans[k + 1], fr).normalized()
		var s := (side - t * side.dot(t)).normalized()
		var up := t.cross(s)
		var prof := 0.32 + 0.68 * pow(sin(PI * (0.1 + 0.85 * w)), 0.7)
		var ll := lmax * prof
		var vv := lerpf(v_in, v_out, w)
		var fw := lerpf(0.62, 0.95, w)
		for sgn: float in [-1.0, 1.0]:
			# A little scatter per leaflet, so a frond is not a comb. Hashed
			# from where it grows: the same frond always gets the same.
			var j1 := _hash(float(i) + az * 7.1 + sgn * 0.37)
			var j2 := _hash(float(i) * 1.7 + az * 3.3 + sgn * 1.9)
			var d: Vector3
			if limp:
				d = (s * sgn * 0.35 + Vector3.DOWN + t * 0.3).normalized()
			else:
				var v2 := vv + j1 * 0.2
				var f2 := fw + j2 * 0.14
				var d0 := s * (sgn * cos(v2)) + up * sin(v2)
				d = (d0 * cos(f2) + t * sin(f2)).normalized()
			var l2 := ll * (1.0 + 0.14 * j2)
			var drop := l2 * sag * lerpf(0.5, 1.0, w)
			_leaflet(buf, at + s * (sgn * 0.01), d, t, up, l2, lw * lerpf(0.75, 1.0, prof),
				drop, centre)


## One leaflet: a narrow strap, widest a quarter of the way out and tapering
## to a long point, bent at its shoulder so the rest of it hangs. Two
## triangles.
static func _leaflet(buf: Array, b: Vector3, d: Vector3, t: Vector3, up: Vector3,
		ll: float, lw: float, drop: float, centre: Vector3) -> void:
	var m := b + d * (ll * 0.24) + Vector3.DOWN * (drop * 0.08)
	var tip := b + d * ll + Vector3.DOWN * drop
	var n := _facing(d.cross(t), up)
	var x := n.cross((m - b).normalized()).normalized()
	var ml := m + x * (lw * 0.5)
	var mr := m - x * (lw * 0.5)
	var n1 := _facing((ml - b).cross(mr - b), n)
	var n2 := _facing((tip - ml).cross(mr - ml), n)
	var out := (m - centre).normalized()
	var s1 := (n1 * 0.75 + out * 0.25).normalized()
	var s2 := (n2 * 0.75 + out * 0.25).normalized()
	var s12 := (s1 + s2).normalized()
	_push(buf, b, ml, mr, s1, s12, s12)
	_push(buf, ml, tip, mr, s12, s2, s12)


## A repeatable pseudo-random number in -0.5..0.5 from x.
static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898 + 4.1414) * 43758.5453, 1.0) - 0.5


## True when nothing in `buf` dips below LOW_H further than `r_max` from the
## plant's foot, or below the ground.
static func _fits(buf: Array, r_max: float) -> bool:
	for i in range(0, buf.size(), 6):
		for q in 3:
			var p: Vector3 = buf[i + q]
			if p.y < -0.25:
				return false
			if p.y < LOW_H and Vector2(p.x, p.z).length() > r_max:
				return false
	return true


# =============================================================================
#  BROADLEAF
# =============================================================================

static func broadleaf(index: int) -> Array:
	var v := posmod(index, 5)
	var greens: Array[String] = ["foliage", "foliage_mid", "foliage_light"]
	var leaf_mat: String = greens[posmod(index, 3)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 60013 + index * 6151
	var wood := _st()
	var leaves := _st()
	var masses: Array = []
	var parts: Array = []
	var tufts := 30
	match v:
		0:
			_emergent(wood, masses, rng)
		1:
			_fig(wood, masses, rng)
			tufts = 28
		2:
			_cecropia(wood, leaves, rng)
		3:
			var vine := _st()
			_liana_tree(wood, vine, masses, rng)
			parts.append(FK.part(vine.commit(), Transform3D(), "liana"))
			tufts = 12
		_:
			_strangler(wood, masses, rng)
	if not masses.is_empty():
		_canopy(leaves, masses, rng, 0.3, tufts)
	parts.append(FK.part(wood.commit(), Transform3D(), "trunk_dark"))
	parts.append(FK.part(leaves.commit(), Transform3D(), leaf_mat))
	return parts


## 0 — the tall emergent: big plank buttresses, a long straight bole and a
## flat umbrella crown held out on limbs that fan from the top of the bole
## like the spokes of an umbrella, a billowing cluster at the end of each
## spoke round a low central one.
static func _emergent(wood: SurfaceTool, masses: Array, rng: RandomNumberGenerator) -> void:
	var line := _trunk_line(1.6, 6.45, 0.25, 0.1, Vector2(0.1, 0.08), rng.randf_range(0.0, TAU), 5)
	var tp: Array = line[0]
	_flare(wood, _fins(rng, 5, 0.62, 0.78, 1.2, 1.55, 0.055), 0.34, _ring0(tp, line[1]), 3, 3)
	_tube(wood, tp, line[1], 12, false)
	var ca := rng.randf_range(0.0, TAU)
	for i in 5:
		var az := ca + TAU * float(i) / 5.0 + rng.randf_range(-0.15, 0.15)
		var dh := Vector3(cos(az), 0.0, sin(az))
		var c := dh * rng.randf_range(1.15, 1.25) + Vector3.UP * rng.randf_range(6.1, 6.3)
		_billow(masses, c, Vector3(0.6, 0.36, 0.56), 1 if i % 2 == 0 else 0, dh, rng)
		_limb(wood, tp[3 + i % 2], c - dh * 0.3 + Vector3.DOWN * 0.05, 0.08, 0.035, 2,
			false, Vector2(0.5, 0.55))
	var top: Vector3 = tp[tp.size() - 1]
	masses.append([Vector3(top.x, 6.45, top.z), Vector3(0.66, 0.4, 0.64)])


## A billowing cluster of foliage: a mass at c with semi-axes r and `n`
## smaller, rounder ones pushed out of its upper, outer shoulder, each lifted
## clear of the lanes if need be.
static func _billow(masses: Array, c: Vector3, r: Vector3, n: int, out: Vector3,
		rng: RandomNumberGenerator) -> void:
	masses.append([_fit(c, r), r])
	var a0 := rng.randf_range(-1.0, 1.0)
	for i in n:
		var side := out.rotated(Vector3.UP, a0 + (float(i) - float(n - 1) * 0.5) * 1.6)
		var k := rng.randf_range(0.66, 0.78)
		var rs := Vector3(r.x * k, maxf(r.y, r.x * 0.62) * k, r.z * k)
		var at := c + (side * 0.62 + out * 0.2) * r.x + Vector3.UP * (r.y * rng.randf_range(0.35, 0.6))
		masses.append([_fit(at, rs), rs])


## 1 — the fig: a short, massive trunk on a flare of surface roots, stout
## limbs, and a broad low dome wider than it is tall — a ring of billows
## round a central crown, with one hanging lower close in by the trunk —
## and aerial roots dropping from the limbs, the older ones to the ground.
static func _fig(wood: SurfaceTool, masses: Array, rng: RandomNumberGenerator) -> void:
	var line := _trunk_line(0.55, 4.85, 0.34, 0.19, Vector2(0.09, 0.07), rng.randf_range(0.0, TAU), 5)
	var tp: Array = line[0]
	_flare(wood, _fins(rng, 6, 0.42, 0.55, 0.38, 0.55, 0.07), 0.45, _ring0(tp, line[1]), 4, 2)
	_tube(wood, tp, line[1], 12, false)
	var ca := rng.randf_range(0.0, TAU)
	var n_root := 0
	for i in 5:
		var az := ca + TAU * float(i) / 5.0 + rng.randf_range(-0.15, 0.15)
		var dh := Vector3(cos(az), 0.0, sin(az))
		var pad := Vector3(0.58, 0.46, 0.55)
		var c := _fit(dh * 1.02 + Vector3.UP * 4.6, pad)
		_billow(masses, c, pad, 1 if i == 0 or i == 2 else 0, dh, rng)
		if i == 1 or i == 3:
			continue
		var from: Vector3 = tp[3]
		var to := c - dh * 0.25 + Vector3.DOWN * 0.1
		var bow := Vector2(0.3, 0.75)
		_limb(wood, from, to, 0.11, 0.05, 2, false, bow)
		# An aerial root from where the limb passes 0.8 m out.
		var ctrl := _limb_ctrl(from, to, bow)
		var at := to
		for k in 20:
			var q := _bez(from, ctrl, to, float(k) / 19.0)
			if Vector2(q.x, q.z).length() > 0.8:
				at = q
				break
		var wig := Vector3(-dh.z, 0.0, dh.x) * rng.randf_range(-0.06, 0.06)
		if n_root < 2:
			var foot := Vector3(at.x * 1.03, -0.12, at.z * 1.03)
			_tube(wood, [at, at.lerp(foot, 0.5) + wig, foot], [0.035, 0.045, 0.065], 12, false)
		else:
			_tube(wood, [at, at + Vector3.DOWN * 0.8 + wig, at + Vector3.DOWN * 1.7],
				[0.025, 0.02, 0.012], 12, true)
		n_root += 1
	masses.append([Vector3(0.0, 5.0, 0.0), Vector3(0.85, 0.52, 0.8)])
	var ai := ca + TAU * 2.5 / 5.0
	masses.append([Vector3(cos(ai), 0.0, sin(ai)) * 0.36 + Vector3.UP * 4.0, Vector3(0.52, 0.42, 0.5)])


## 2 — a young Cecropia: a slim, slightly wandering stem with a few thin
## candelabra branches that run out and curve up, each ending (as the stem
## does) in a rosette of big lobed leaves held out and drooping. Open and
## airy, the stem showing all the way up.
static func _cecropia(wood: SurfaceTool, leaves: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var line := _trunk_line(0.3, 4.6, 0.1, 0.045, Vector2(0.18, 0.12), rng.randf_range(0.0, TAU), 7)
	var tp: Array = line[0]
	_flare(wood, _fins(rng, 4, 0.14, 0.2, 0.3, 0.4, 0.028), 0.15, _ring0(tp, line[1]), 2, 2)
	_tube(wood, tp, line[1], 12, true)
	var az := rng.randf_range(0.0, TAU)
	var starts: Array[int] = [4, 4, 5, 5, 6]
	var tips: Array = []
	for b in 5:
		var from: Vector3 = tp[starts[b]]
		var reach := rng.randf_range(0.8, 1.0)
		var to := Vector3(from.x + cos(az) * reach, maxf(from.y + rng.randf_range(0.5, 0.75), 4.35),
			from.z + sin(az) * reach)
		_limb(wood, from, to, 0.045, 0.022, 3, true, Vector2(0.85, 0.15))
		tips.append(to)
		az += 2.4 + rng.randf_range(-0.25, 0.25)
	tips.append(tp[tp.size() - 1])
	for t: Vector3 in tips:
		_rosette(leaves, t, rng, 7)


## A rosette of big lobed leaves radiating from `at`, held out and drooping,
## lifted where one would hang into the lanes.
static func _rosette(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator, n: int) -> void:
	var a0 := rng.randf_range(0.0, TAU)
	for i in n:
		var az := a0 + TAU * float(i) / float(n) + rng.randf_range(-0.15, 0.15)
		var ln := rng.randf_range(0.55, 0.7)
		var pitch := rng.randf_range(0.0, 0.3)
		var droop := ln * rng.randf_range(0.28, 0.4)
		var mesh: ArrayMesh = null
		var xf := Transform3D()
		for _attempt in 6:
			var d := Vector3(cos(az) * cos(pitch), -sin(pitch), sin(az) * cos(pitch))
			var z := (Vector3.UP - d * d.y).normalized()
			xf = Transform3D(Basis(d.cross(z), d, z), at + Vector3(cos(az), 0.0, sin(az)) * 0.03)
			mesh = FK.blade(ln * 0.36, ln, droop, 0.035, 2, 5)
			if _mesh_fits(mesh, xf, 0.98):
				break
			pitch -= 0.15
			droop *= 0.85
		_append(st, mesh, xf)


## 3 — the liana tree: modest buttresses and a crown in two clear tiers, a
## lower one on limbs from mid-trunk and an upper one on the leader, with
## woody lianas: one spiralling up the bole, one hanging from the lower tier
## to root in the ground, one swagged in a U between two billows of the lower
## tier and one looping from the upper tier down past the lower.
static func _liana_tree(wood: SurfaceTool, vine: SurfaceTool, masses: Array,
		rng: RandomNumberGenerator) -> void:
	var line := _trunk_line(1.1, 6.2, 0.23, 0.11, Vector2(0.13, 0.1), rng.randf_range(0.0, TAU), 6)
	var tp: Array = line[0]
	var trr: Array = line[1]
	var fins := _fins(rng, 4, 0.48, 0.6, 0.85, 1.05, 0.05)
	_flare(wood, fins, 0.3, _ring0(tp, trr), 2, 3)
	_tube(wood, tp, trr, 12, false)
	var ca := rng.randf_range(0.0, TAU)
	# The lower tier: three billows on limbs from mid-trunk.
	var low: Array = []
	for i in 3:
		var az := ca + TAU * float(i) / 3.0 + rng.randf_range(-0.2, 0.2)
		var dh := Vector3(cos(az), 0.0, sin(az))
		var pad := Vector3(0.56, 0.42, 0.54)
		var c := _fit(dh * 1.1 + Vector3.UP * 4.5, pad)
		_billow(masses, c, pad, 1 if i < 2 else 0, dh, rng)
		low.append([c, pad, az])
		_limb(wood, tp[3], c - dh * 0.25 + Vector3.DOWN * 0.05, 0.085, 0.04, 2, false)
	# The upper tier, turned half a step, round the leader, and a crown on top.
	var high: Array = []
	for i in 2:
		var az := ca + TAU * (float(i) + 0.5) / 3.0 + rng.randf_range(-0.2, 0.2)
		var dh := Vector3(cos(az), 0.0, sin(az))
		var pad := Vector3(0.6, 0.44, 0.57)
		var c := dh * 0.78 + Vector3.UP * rng.randf_range(5.9, 6.05)
		masses.append([c, pad])
		high.append([c, pad, az])
	var top: Vector3 = tp[tp.size() - 1]
	masses.append([Vector3(top.x, 6.35, top.z), Vector3(0.66, 0.42, 0.64)])

	# (a) Up the bole: rooted between two buttresses, one turn round the
	# trunk, then into the lower tier.
	var f0: float = (fins[0] as Array)[0]
	var f1: float = (fins[1] as Array)[0]
	var mid := f0 + fposmod(f1 - f0, TAU) * 0.5
	var lp: Array = [Vector3(cos(mid) * 0.46, -0.08, sin(mid) * 0.46),
		Vector3(cos(mid) * 0.36, 0.55, sin(mid) * 0.36)]
	for k in 4:
		var y := lerpf(1.2, 3.9, float(k) / 3.0)
		var ax := _axis_at(tp, trr, y)
		var ang := mid + TAU * float(k) / 3.0 * 0.9
		lp.append((ax[0] as Vector3) + Vector3(cos(ang), 0.0, sin(ang)) * (float(ax[1]) + 0.035))
	var l0: Array = low[0]
	lp.append((l0[0] as Vector3) + Vector3.DOWN * 0.1 - Vector3(cos(float(l0[2])), 0.0, sin(float(l0[2]))) * 0.3)
	var lr: Array = []
	for k in lp.size():
		lr.append(lerpf(0.065, 0.05, float(k) / float(lp.size() - 1)))
	_tube(vine, lp, lr, 12, false)
	# (b) From the lower tier down to root in the ground, a slack S.
	var l1: Array = low[1]
	var a1: float = l1[2]
	var hang := Vector3(cos(a1), 0.0, sin(a1)) * 0.84 + Vector3.UP * ((l1[0] as Vector3).y - 0.2)
	var dirt := Vector3(cos(a1 + 0.45), 0.0, sin(a1 + 0.45)) * 0.8 + Vector3.DOWN * 0.1
	var hp: Array = []
	var hr: Array = []
	for k in 6:
		var t := float(k) / 5.0
		var sway := Vector3(-sin(a1), 0.0, cos(a1)) * (0.18 * sin(PI * t))
		hp.append(hang.lerp(dirt, t) + sway)
		hr.append(lerpf(0.05, 0.065, t))
	_tube(vine, hp, hr, 12, false)
	_liana_leaves(vine, hp[1], rng, 2)
	# (c) A swag between two billows of the lower tier, drooping in a deep U
	# (close in by the trunk, where it may hang lower), and (d) a long loop
	# from the upper tier down past the lower one.
	var swags: Array = [[(low[0] as Array)[0], (low[1] as Array)[0], 0.95],
		[(high[0] as Array)[0], (low[2] as Array)[0], 0.75]]
	for sw: Array in swags:
		var p0: Vector3 = (sw[0] as Vector3) + Vector3.DOWN * 0.1
		var p1: Vector3 = (sw[1] as Vector3) + Vector3.DOWN * 0.1
		p0 -= Vector3(p0.x, 0.0, p0.z).normalized() * 0.3
		p1 -= Vector3(p1.x, 0.0, p1.z).normalized() * 0.3
		var outw := Vector3(p0.x + p1.x, 0.0, p0.z + p1.z).normalized()
		var sag: float = sw[2]
		var sp: Array = []
		var sr: Array = []
		for k in 6:
			var t := float(k) / 5.0
			var bell := 4.0 * t * (1.0 - t)
			sp.append(p0.lerp(p1, t) + Vector3.DOWN * (sag * bell) + outw * (0.3 * bell))
			sr.append(lerpf(0.06, 0.048, bell))
		_tube(vine, sp, sr, 12, false)
		_liana_leaves(vine, (sp[2] as Vector3).lerp(sp[3], 0.5), rng, 2)


## A few small leaves where a liana hangs lowest.
static func _liana_leaves(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator, n: int) -> void:
	for i in n:
		var az := rng.randf_range(0.0, TAU)
		var out := Vector3(cos(az), 0.0, sin(az))
		var d := (out * 0.7 + Vector3.DOWN * 0.7).normalized()
		var face := _facing(Vector3.UP - d * d.y, out)
		var pts := _ovate(at + out * 0.05, d, face, 0.22, 0.11)
		if _leaf_fits(pts, 1.0):
			_leaf4(st, pts, face, (out + Vector3.UP * 0.12).normalized())


## 4 — the strangler fig: its roots have braided a lattice round a host tree
## that has since rotted away, spiralling round it in opposite senses, fusing
## where they touch and flaring into roots at the ground; up top they become
## the limbs of a lopsided crown, heavy on one side, with a gap through it.
static func _strangler(wood: SurfaceTool, masses: Array, rng: RandomNumberGenerator) -> void:
	# What is left of the host, showing through the gaps in the lattice.
	_tube(wood, [Vector3(0.0, -0.1, 0.0), Vector3(0.0, 1.6, 0.0), Vector3(0.02, 3.3, 0.01),
		Vector3(0.04, 4.7, 0.0)], [0.17, 0.165, 0.15, 0.12], 12, true)
	var la := rng.randf_range(0.0, TAU)
	var dh := Vector3(cos(la), 0.0, sin(la))
	var pp := Vector3(-sin(la), 0.0, cos(la))
	# The heavy side, and across a gap, a smaller lobe on the other.
	_billow(masses, dh * 1.05 + pp * 0.45 + Vector3.UP * 5.4, Vector3(0.58, 0.44, 0.55), 1, dh, rng)
	_billow(masses, dh * 1.3 - pp * 0.35 + Vector3.UP * 5.85, Vector3(0.56, 0.42, 0.52), 0, dh, rng)
	_billow(masses, dh * 0.45 + pp * 0.05 + Vector3.UP * 6.1, Vector3(0.6, 0.44, 0.56), 1, pp, rng)
	masses.append([_fit(dh * 0.8 - pp * 0.8 + Vector3.UP * 5.25, Vector3(0.5, 0.4, 0.48)), Vector3(0.5, 0.4, 0.48)])
	_billow(masses, -dh * 0.95 + pp * 0.3 + Vector3.UP * 5.0, Vector3(0.5, 0.4, 0.48), 1, -dh, rng)
	# Each root stem, from its foot in the soil up round the host, then out
	# to one of the crown's masses as its limb.
	var a0 := rng.randf_range(0.0, TAU)
	var ys: Array[float] = [-0.2, 0.04, 0.32, 0.72, 1.3, 2.4, 3.55, 4.55]
	var stems: Array = []
	var taken: Array[int] = []
	for s in 3:
		var phi0 := a0 + TAU * float(s) / 3.0 + rng.randf_range(-0.2, 0.2)
		var turn := (0.5 + rng.randf_range(0.0, 0.12)) * (1.0 if s % 2 == 0 else -1.0)
		var sp: Array = []
		var sr: Array = []
		for y in ys:
			var t := (y + 0.2) / 4.75
			var fl := pow(1.0 - smoothstep(-0.2, 1.3, y), 2.0)
			var spread := 0.215 + 0.7 * fl - 0.02 * smoothstep(3.5, 4.55, y)
			var ang := phi0 + turn * TAU * t
			sp.append(Vector3(cos(ang) * spread, y, sin(ang) * spread))
			sr.append(lerpf(0.05, 0.105, smoothstep(-0.2, 0.6, y)) - 0.025 * smoothstep(1.5, 4.55, y))
		stems.append(sp.duplicate())
		# The stem becomes the limb of the nearest free mass round the host.
		var last: Vector3 = sp[sp.size() - 1]
		var best := 0
		var best_d := INF
		for mi: int in [0, 2, 3, 5, 6]:
			var mp: Vector3 = (masses[mi] as Array)[0]
			var dd := Vector2(mp.x, mp.z).normalized().distance_to(Vector2(last.x, last.z).normalized())
			if dd < best_d and not taken.has(mi):
				best_d = dd
				best = mi
		taken.append(best)
		var mc: Vector3 = (masses[best] as Array)[0]
		var mr: Vector3 = (masses[best] as Array)[1]
		sp.append(last.lerp(mc, 0.45) + Vector3.UP * 0.25)
		sp.append(mc + Vector3.DOWN * (mr.y * 0.3) - Vector3(mc.x, 0.0, mc.z).normalized() * 0.15)
		sr.append(0.065)
		sr.append(0.045)
		_tube(wood, sp, sr, 12, false)
	# Short root bridges, fused between neighbouring stems.
	var bh: Array[float] = [1.8, 3.1]
	for b in 2:
		var pa := _at_height(stems[b], ys, bh[b])
		var pb := _at_height(stems[b + 1], ys, bh[b] + 0.2)
		_tube(wood, [pa, pb], [0.05, 0.05], 12, false)


## A stem's point at height y, from its points at heights `ys`.
static func _at_height(sp: Array, ys: Array[float], y: float) -> Vector3:
	for i in ys.size() - 1:
		if y <= ys[i + 1]:
			return (sp[i] as Vector3).lerp(sp[i + 1], (y - ys[i]) / (ys[i + 1] - ys[i]))
	return sp[ys.size() - 1]


## A trunk line's centre and radius at height y: [Vector3, float].
static func _axis_at(tp: Array, trr: Array, y: float) -> Array:
	for i in tp.size() - 1:
		var a: Vector3 = tp[i]
		var b: Vector3 = tp[i + 1]
		if y <= b.y or i == tp.size() - 2:
			var t := clampf((y - a.y) / maxf(b.y - a.y, 1e-4), 0.0, 1.0)
			return [a.lerp(b, t), lerpf(float(trr[i]), float(trr[i + 1]), t)]
	return [tp[0], trr[0]]


## Buttress fins: [angle, reach, height, half_thickness], evenly spread with
## some jitter.
static func _fins(rng: RandomNumberGenerator, n: int, reach0: float, reach1: float,
		h0: float, h1: float, thick: float) -> Array:
	var out: Array = []
	var a0 := rng.randf_range(0.0, TAU)
	var jit := 0.2 * TAU / float(n)
	for i in n:
		out.append([a0 + TAU * float(i) / float(n) + rng.randf_range(-jit, jit),
			rng.randf_range(reach0, reach1), rng.randf_range(h0, h1), thick])
	return out


# --- crown -------------------------------------------------------------------

## The foliage: soft, lumpy masses (FK.clump) that carry the crown's form,
## each shaded partly as itself and partly as the crown as a whole (see
## CROWN_BLEND), their normals dappled a little so the light breaks up
## across them the way it does over clusters of leaves. Triangles buried
## inside a neighbouring mass are dropped. Then `tufts` small bunches of
## three ovate leaves, hanging out and down from the masses' exposed rims
## and sides, break the outline. `masses` holds [centre, radii].
static func _canopy(st: SurfaceTool, masses: Array, rng: RandomNumberGenerator,
		leaf_len: float, tufts: int) -> void:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	var spins: Array = []
	for m: Array in masses:
		var c: Vector3 = m[0]
		var r: Vector3 = m[1]
		lo = lo.min(c - r)
		hi = hi.max(c + r)
		spins.append(Basis(Vector3.UP, rng.randf_range(0.0, TAU)))
	var cc := (lo + hi) * 0.5
	var cr := ((hi - lo) * 0.5).max(Vector3(0.3, 0.3, 0.3))
	for mi in masses.size():
		var c: Vector3 = (masses[mi] as Array)[0]
		var r: Vector3 = (masses[mi] as Array)[1]
		var spin: Basis = spins[mi]
		var mesh := FK.clump(r, rng.randi_range(0, 63), LUMP, 0.5, 12, 8)
		var arr := mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in range(0, vs.size(), 3):
			var p0 := c + spin * vs[i]
			var p1 := c + spin * vs[i + 1]
			var p2 := c + spin * vs[i + 2]
			if (p1 - p0).cross(p2 - p0).length_squared() < 1e-10:
				continue
			if _inside(masses, spins, mi, p0, BURIED) and _inside(masses, spins, mi, p1, BURIED) \
					and _inside(masses, spins, mi, p2, BURIED):
				continue
			_tri_to(st, p0, p1, p2, _crown_n(spin * ns[i] + _dapple(p0), p0, cc, cr),
				_crown_n(spin * ns[i + 1] + _dapple(p1), p1, cc, cr),
				_crown_n(spin * ns[i + 2] + _dapple(p2), p2, cc, cr),
				spin * (ns[i] + ns[i + 1] + ns[i + 2]))

	# Where the tufts can go: points on each mass's rim and sides that are
	# out in the open (not inside a neighbour) and face out of the crown.
	var spots: Array = []
	for mi in masses.size():
		var c: Vector3 = (masses[mi] as Array)[0]
		var r: Vector3 = (masses[mi] as Array)[1]
		var spin: Basis = spins[mi]
		var n_c := int(round(_ell_area(r) * 6.0))
		var off := rng.randf_range(0.0, TAU)
		for i in n_c:
			var yy := lerpf(0.25, -0.85, (float(i) + 0.5) / float(n_c))
			var az := off + float(i) * GOLDEN
			var rr := sqrt(1.0 - yy * yy)
			var dd := Vector3(rr * cos(az), yy, rr * sin(az))
			var p := c + spin * (dd * r * 0.96)
			var ne := (spin * Vector3(dd.x / r.x, dd.y / r.y, dd.z / r.z)).normalized()
			var out := Vector3(p.x - cc.x, 0.0, p.z - cc.z)
			if _inside(masses, spins, mi, p, 1.0) or Vector3(ne.x, 0.0, ne.z).dot(out) < -0.05:
				continue
			spots.append([p, ne, yy, mi])
	# An even pick of `tufts` of them.
	var step := maxf(float(spots.size()) / float(maxi(tufts, 1)), 1.0)
	var f := rng.randf_range(0.0, step)
	while f < float(spots.size()):
		var sp: Array = spots[int(f)]
		f += step
		var p: Vector3 = sp[0]
		var ne: Vector3 = sp[1]
		var yy: float = sp[2]
		var mi: int = sp[3]
		var out_h := Vector3(ne.x, 0.0, ne.z)
		if out_h.length() < 0.15:
			out_h = Vector3(p.x - cc.x, 0.0, p.z - cc.z)
		out_h = out_h.normalized()
		# The tuft hangs out and down from the rim, more steeply the lower
		# it grows; its three leaves spread round that axis like a bunch.
		var tilt := lerpf(0.3, 1.15, clampf((0.25 - yy) / 1.1, 0.0, 1.0)) + rng.randf_range(-0.12, 0.12)
		var axis := (out_h * cos(tilt) + Vector3.DOWN * sin(tilt)).normalized()
		var ref := out_h.cross(axis).normalized()
		var spin0 := rng.randf_range(0.0, TAU)
		var ln0 := leaf_len * rng.randf_range(0.85, 1.15)
		for q in 3:
			var side := ref.rotated(axis, spin0 + TAU * float(q) / 3.0)
			var ln := ln0 * (1.0 - 0.12 * float(q))
			var spread := 0.62
			for _attempt in 3:
				var d := (axis * cos(spread) + side * sin(spread)).normalized()
				# Its front is the face that looks out of the crown: the one
				# anyone outside it sees.
				var face := _facing(side - d * side.dot(d), out_h)
				var pts := _ovate(p, d, face, ln, ln * 0.52)
				if _leaf_fits(pts, 0.98) and not _inside(masses, spins, mi, pts[3], 0.92):
					_leaf4(st, pts, face, (out_h + Vector3.UP * 0.12 + _dapple(pts[3])).normalized())
					break
				spread *= 0.6
				ln *= 0.8


## A small, repeatable sideways wobble for a normal at p, so light breaks up
## across a foliage mass in patches about the size of a cluster of leaves.
## Sideways only: tipped up, a normal in shade takes the blue of the sky.
static func _dapple(p: Vector3) -> Vector3:
	var q := p * 2.7
	return Vector3(_hash(q.x * 1.3 + q.y * 7.1 + q.z * 3.7), 0.0,
		_hash(q.x * 2.9 + q.y * 4.1 + q.z * 1.1)) * DAPPLE


## A foliage normal: the mass's own, partly the crown's, the lower half
## flattened toward the horizontal and all of it bent to the sky. Light
## scattered through a canopy keeps its underside from going black, and in
## the mass's own shadow a downward normal would only see the dark ground.
static func _crown_n(n: Vector3, p: Vector3, cc: Vector3, cr: Vector3) -> Vector3:
	var g := ((p - cc) / (cr * cr)).normalized()
	var m := n.normalized() * (1.0 - CROWN_BLEND) + g * CROWN_BLEND
	if m.y < 0.0:
		m.y *= 0.3
	return (m.normalized() + Vector3.UP * LIFT).normalized()


## Approximate surface area of an ellipsoid (Knud Thomsen's formula).
static func _ell_area(r: Vector3) -> float:
	var p := 1.6
	return 4.0 * PI * pow((pow(r.x * r.y, p) + pow(r.x * r.z, p) + pow(r.y * r.z, p)) / 3.0, 1.0 / p)


## True when p lies inside any mass but `me`, scaled by k.
static func _inside(masses: Array, spins: Array, me: int, p: Vector3, k: float) -> bool:
	for oi in masses.size():
		if oi == me:
			continue
		var o: Array = masses[oi]
		var sp: Basis = spins[oi]
		var q := (sp.transposed() * (p - (o[0] as Vector3))) / (o[1] as Vector3)
		if q.length() < k:
			return true
	return false


## Raises a foliage mass centred at c with semi-axes r just enough that the
## part of it outside `r_max` of the trunk's foot stays `margin` above LOW_H
## (room for the leaves hanging from its rim).
static func _fit(c: Vector3, r: Vector3, r_max: float = 0.98, margin: float = 0.26) -> Vector3:
	var rx := maxf(r.x, r.z)
	var dist := Vector2(c.x, c.z).length()
	if dist + rx <= r_max or c.y - r.y >= LOW_H + margin:
		return c
	var k := clampf((r_max - dist) / rx, 0.0, 1.0)
	return Vector3(c.x, maxf(c.y, LOW_H + margin + r.y * sqrt(1.0 - k * k) + 0.01), c.z)


## True when a leaf's points stay out of the lanes below LOW_H.
static func _leaf_fits(pts: Array, r_max: float) -> bool:
	for q: Vector3 in pts:
		if q.y < LOW_H + 0.03 and Vector2(q.x, q.z).length() > r_max - 0.02:
			return false
		if q.y < -0.2:
			return false
	return true


## True when every vertex of `mesh` placed by `xf` stays out of the lanes.
static func _mesh_fits(mesh: Mesh, xf: Transform3D, r_max: float) -> bool:
	var vs: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in vs:
		var q := xf * v
		if q.y < LOW_H + 0.02 and Vector2(q.x, q.z).length() > r_max:
			return false
	return true


## The six corners of a small ovate leaf: base, left shoulder, left upper,
## tip, right upper, right shoulder. Widest a third of the way out, folded
## up a little along the midrib, the tip curling under.
static func _ovate(b: Vector3, d: Vector3, face: Vector3, ln: float, wd: float) -> Array:
	var x := face.cross(d).normalized()
	var f := wd * 0.12
	return [b,
		b + d * (ln * 0.3) + x * (wd * 0.5) + face * f,
		b + d * (ln * 0.66) + x * (wd * 0.36) + face * (f * 0.6 - ln * 0.05),
		b + d * ln - face * (ln * 0.14),
		b + d * (ln * 0.66) - x * (wd * 0.36) + face * (f * 0.6 - ln * 0.05),
		b + d * (ln * 0.3) - x * (wd * 0.5) + face * f]


## Emits an ovate leaf (see _ovate) as four one-sided triangles facing
## `face`, carrying the normal `n` tilted a little with each half's fold.
## For the leaves that hang in a crown's shade: given a level `n`, the
## flipped normal the shader uses from behind is level too, and sees the same
## horizon light, so the leaf shades alike from either side.
static func _leaf4(st: SurfaceTool, pts: Array, face: Vector3, n: Vector3) -> void:
	var x := ((pts[1] as Vector3) - (pts[5] as Vector3)).normalized()
	var nl := (n - x * 0.25).normalized()
	var nr := (n + x * 0.25).normalized()
	_tri_to(st, pts[0], pts[1], pts[5], n, nl, nr, face)
	_tri_to(st, pts[1], pts[2], pts[4], nl, nl, nr, face)
	_tri_to(st, pts[1], pts[4], pts[5], nl, nr, nr, face)
	_tri_to(st, pts[2], pts[3], pts[4], nl, n, nr, face)


# --- wood --------------------------------------------------------------------

## The foot of a trunk: buttress fins, surface roots or root nubs flaring out
## of a round core `rc0` wide at the ground, lofted as ONE surface that ends
## exactly on the trunk tube's first ring `ring` ([points, normals], see
## _ring0), so the trunk grows out of it with no seam and no collar.
##
## Each fin is [angle, reach, height, half_thickness]: it stands `height` up
## the trunk and runs `reach` out beyond the core along the ground, its
## crest a concave sweep between the two. Every ring of the loft has
## 12 * `sub` points; the top ring sits on the tube's ring (and its chords).
## Lower down, the points gather onto the fins — each fin's root, tip corners
## and tip — with the rest spread round the gaps, always in order of angle,
## so the surface can never fold over itself; the shape itself is a polar
## function (a round core, planks with rounded ends, filleted into it).
static func _flare(st: SurfaceTool, fins: Array, rc0: float, ring: Array, sub: int,
		rows: int) -> void:
	var rp: Array = ring[0]
	var rn: Array = ring[1]
	var n0 := rp.size()
	var m := n0 * sub
	var c := Vector3.ZERO
	for p: Vector3 in rp:
		c += p
	c /= float(n0)
	var top := c.y
	var r_top := ((rp[0] as Vector3) - c).length()
	var top_row: Array = []
	var top_n: Array = []
	for i in n0:
		var a: Vector3 = rp[i]
		var b: Vector3 = rp[(i + 1) % n0]
		var na: Vector3 = rn[i]
		var nb: Vector3 = rn[(i + 1) % n0]
		for q in sub:
			var f := float(q) / float(sub)
			top_row.append(a.lerp(b, f))
			top_n.append(na.lerp(nb, f).normalized())
	# Where each point sits round the top ring (unwrapped), and which way the
	# ring runs. Everything below is worked out mirrored so angles increase.
	var home: Array[float] = []
	for k in m:
		var d: Vector3 = (top_row[k] as Vector3) - c
		var a := atan2(d.z, d.x)
		if k > 0:
			a = home[k - 1] + wrapf(a - home[k - 1], -PI, PI)
		home.append(a)
	var sgn := 1.0 if home[m - 1] > home[0] else -1.0
	var hm: Array[float] = []
	for k in m:
		hm.append(home[k] * sgn)
	var sorted: Array = []
	for f: Array in fins:
		sorted.append([fposmod(float(f[0]) * sgn, TAU), f[1], f[2], f[3]])
	sorted.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var fa: Array[float] = []
	for f: Array in sorted:
		fa.append(float(f[0]))

	var grid: Array = []
	for j in rows:
		var y := -0.12 if j == 0 else top * pow(float(j) / float(rows), 1.5)
		var yc := maxf(y, 0.0)
		var rc := lerpf(rc0, r_top, smoothstep(0.0, top, yc))
		var ext: Array[float] = []
		var thk: Array[float] = []
		var emax := 0.0
		for f: Array in sorted:
			var u := clampf(yc / float(f[2]), 0.0, 1.0)
			var e := float(f[1]) * (1.0 - sqrt(u))
			if y < 0.0:
				e = float(f[1]) * 1.06
			ext.append(e)
			thk.append(float(f[3]) * smoothstep(0.0, 0.12, e) * lerpf(1.0, 0.75, u))
			emax = maxf(emax, e)
		var star := _align(_star(fa, ext, thk, rc, m), hm)
		var bw := smoothstep(0.03, 0.25, emax)
		var row: Array = []
		for k in m:
			var th := lerpf(hm[k], star[k], bw)
			var r := _flare_r(th, rc, fa, ext, thk)
			row.append(Vector3(c.x + cos(th * sgn) * r, y, c.z + sin(th * sgn) * r))
		grid.append(row)
	grid.append(top_row)

	var nrm: Array = []
	for j in rows + 1:
		var row: Array = []
		for k in m:
			if j == rows:
				row.append(top_n[k])
				continue
			var dc: Vector3 = (grid[j][(k + 1) % m] as Vector3) - (grid[j][(k - 1 + m) % m] as Vector3)
			var dy: Vector3 = (grid[j + 1][k] as Vector3) - (grid[maxi(j - 1, 0)][k] as Vector3)
			var n := dy.cross(dc) * sgn
			row.append(n.normalized() if n.length_squared() > 1e-12 else Vector3.UP)
		nrm.append(row)
	for j in rows:
		for k in m:
			var k2 := (k + 1) % m
			_quad(st, [grid[j][k], nrm[j][k]], [grid[j + 1][k], nrm[j + 1][k]],
				[grid[j + 1][k2], nrm[j + 1][k2]], [grid[j][k2], nrm[j][k2]])


## The flare's cross-section at angle th: a round core of radius rc, with a
## plank of half-thickness thk[f] running ext[f] out along each fin angle,
## its end rounded and its root filleted into the core.
static func _flare_r(th: float, rc: float, fa: Array[float], ext: Array[float],
		thk: Array[float]) -> float:
	var r := rc
	for f in fa.size():
		if ext[f] < 0.002:
			continue
		var d := absf(wrapf(th - fa[f], -PI, PI))
		if d > PI * 0.5:
			continue
		var side := thk[f] / maxf(sin(d), 1e-4)
		r = _smax(r, _smin(rc + ext[f], side, 0.05), 0.07)
	return r


## Sample angles round a flare ring (increasing, one full turn): five on each
## fin — its two roots, two tip corners and its tip — and the rest spread
## over the gaps between fins in proportion to their size.
static func _star(fa: Array[float], ext: Array[float], thk: Array[float], rc: float,
		m: int) -> Array[float]:
	var nf := fa.size()
	var ac: Array[float] = []
	var ar: Array[float] = []
	for f in nf:
		var prev := fposmod(fa[f] - fa[(f - 1 + nf) % nf], TAU)
		var nxt := fposmod(fa[(f + 1) % nf] - fa[f], TAU)
		if nf == 1:
			prev = TAU
			nxt = TAU
		var lim := 0.4 * minf(prev, nxt)
		var kk := smoothstep(0.0, 0.12, ext[f])
		var a_root := minf(atan2(thk[f] * 1.25, rc) + 0.14 * kk, lim)
		var a_tip := clampf(atan2(thk[f], rc + ext[f]), 0.004, a_root * 0.6)
		ac.append(a_tip)
		ar.append(a_root)
	var free := m - 5 * nf
	var arcs: Array[float] = []
	var total := 0.0
	for f in nf:
		var g := TAU if nf == 1 else fposmod(fa[(f + 1) % nf] - fa[f], TAU)
		g = maxf(g - ar[f] - ar[(f + 1) % nf], 0.001)
		arcs.append(g)
		total += g
	# Largest-remainder split of the free points between the gaps.
	var alloc: Array[int] = []
	var rema: Array[float] = []
	var used := 0
	for f in nf:
		var exact := float(free) * arcs[f] / total
		alloc.append(floori(exact))
		rema.append(exact - floorf(exact))
		used += alloc[f]
	while used < free:
		var best := 0
		for f in nf:
			if rema[f] > rema[best]:
				best = f
		alloc[best] += 1
		rema[best] = -1.0
		used += 1
	var out: Array[float] = []
	for f in nf:
		var a := fa[f]
		out.append_array([a - ar[f], a - ac[f], a, a + ac[f], a + ar[f]])
		for q in alloc[f]:
			out.append(a + ar[f] + arcs[f] * float(q + 1) / float(alloc[f] + 1))
	return out


## Turns a ring of increasing sample angles so that, point for point, they
## sit as close as possible to the home angles `hm` (so the loft between
## rows does not twist).
static func _align(star: Array[float], hm: Array[float]) -> Array[float]:
	var m := star.size()
	var best: Array[float] = []
	var best_err := INF
	for o in m:
		var cand: Array[float] = []
		for k in m:
			var idx := k + o
			cand.append(star[idx % m] + TAU * float(floori(float(idx) / float(m))))
		var shift := TAU * roundf((cand[0] - hm[0]) / TAU)
		var err := 0.0
		for k in m:
			err += absf(cand[k] - shift - hm[k])
		if err < best_err:
			best_err = err
			best.clear()
			for k in m:
				best.append(cand[k] - shift)
	return best


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


static func _smax(a: float, b: float, k: float) -> float:
	return -_smin(-a, -b, k)


## The first ring of the tube _tube / _ringed_tube builds through `pts`:
## [points, normals], so a flare can end exactly on it.
static func _ring0(pts: Array, radii: Array, sides: int = 12) -> Array:
	var p0: Vector3 = pts[0]
	var t0 := ((pts[1] as Vector3) - p0).normalized()
	var tans: Array[Vector3] = [t0]
	var dirs: Array = _frames(tans, sides)[0]
	var s := _slope(pts, radii, 0)
	var r0: float = radii[0]
	var ps: Array = []
	var ns: Array = []
	for d: Vector3 in dirs:
		ps.append(p0 + d * r0)
		ns.append((d - t0 * s).normalized())
	return [ps, ns]


## A gently wandering trunk from y0 to y1, returned as [points, radii]. It
## leaves the ground straight up, so it meets its flare squarely.
static func _trunk_line(y0: float, y1: float, r0: float, r1: float, wander: Vector2,
		ph: float, steps: int) -> Array:
	var pts: Array = []
	var radii: Array = []
	for i in steps + 1:
		var t := float(i) / float(steps)
		pts.append(Vector3(wander.x * sin(t * 3.1 + ph) * t * t, lerpf(y0, y1, t),
			wander.y * sin(t * 2.3 + ph * 1.7) * t * t))
		radii.append(lerpf(r0, r1, pow(t, 0.9)))
	return [pts, radii]


## A limb from `from` (inside its parent) to `to`, tapering from r0 to r1:
## a quadratic curve whose control point is `bow.x` of the way out and
## `bow.y` of the way up (0.3, 0.75: leaves steeply and arcs out; 0.85, 0.1:
## runs out and curves up at the end).
static func _limb(st: SurfaceTool, from: Vector3, to: Vector3, r0: float, r1: float,
		segs: int, cap: bool, bow: Vector2 = Vector2(0.3, 0.75)) -> void:
	var ctrl := _limb_ctrl(from, to, bow)
	var pts: Array = []
	var radii: Array = []
	for i in segs + 1:
		var t := float(i) / float(segs)
		pts.append(_bez(from, ctrl, to, t))
		radii.append(lerpf(r0, r1, t))
	_tube(st, pts, radii, 12, cap)


static func _limb_ctrl(from: Vector3, to: Vector3, bow: Vector2) -> Vector3:
	return from + Vector3(to.x - from.x, 0.0, to.z - from.z) * bow.x \
		+ Vector3.UP * ((to.y - from.y) * bow.y)


static func _bez(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a * (1.0 - t) * (1.0 - t) + b * (2.0 * (1.0 - t) * t) + c * (t * t)


# =============================================================================
#  MESH HELPERS
# =============================================================================

static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Copies surface 0 of `mesh` into `st`, placed by `xf` (rotation, position,
## uniform scale), dropping degenerate triangles (a sphere's poles).
static func _append(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var b := xf.basis
	for i in range(0, vs.size(), 3):
		var p0 := xf * vs[i]
		var p1 := xf * vs[i + 1]
		var p2 := xf * vs[i + 2]
		if (p1 - p0).cross(p2 - p0).length_squared() < 1e-12:
			continue
		var n0 := (b * ns[i]).normalized()
		var n1 := (b * ns[i + 1]).normalized()
		var n2 := (b * ns[i + 2]).normalized()
		_tri_to(st, p0, p1, p2, n0, n1, n2, n0 + n1 + n2)


## A smooth tube through `pts` without end caps (ends are buried in the ground,
## a trunk or a foliage mass), its normals leaning with the taper. `cap`
## closes the far end with a short rounded cone.
static func _tube(st: SurfaceTool, pts: Array, radii: Array, sides: int = 12,
		cap: bool = false) -> void:
	var n := pts.size()
	var tans: Array[Vector3] = []
	for i in n:
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, n - 1)]
		tans.append((b - a).normalized())
	var dirs := _frames(tans, sides)
	var rings: Array = []
	for i in n:
		var s := _slope(pts, radii, i)
		var ring: Array = []
		for k in sides:
			var d: Vector3 = dirs[i][k]
			ring.append([(pts[i] as Vector3) + d * float(radii[i]), (d - tans[i] * s).normalized()])
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			_quad(st, rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2])
	if cap:
		_cap(st, pts[n - 1], tans[n - 1], dirs[n - 1], radii[n - 1], _slope(pts, radii, n - 1))


## Closes a tube's last ring with a low rounded cone.
static func _cap(st: SurfaceTool, c: Vector3, t: Vector3, dirs: Array, r: float, slope: float) -> void:
	var sides := dirs.size()
	var tip := c + t * (r * 0.6)
	for k in sides:
		var k2 := (k + 1) % sides
		var d0: Vector3 = dirs[k]
		var d1: Vector3 = dirs[k2]
		_tri(st, c + d0 * r, c + d1 * r, tip, (d0 - t * slope).normalized(),
			(d1 - t * slope).normalized(), t)


## Parallel-transport frames along a line: for each point, `sides` unit
## directions round it, so a tube never twists or pinches.
static func _frames(tans: Array[Vector3], sides: int) -> Array:
	var nrm := tans[0].cross(Vector3.FORWARD)
	if nrm.length_squared() < 1e-6:
		nrm = tans[0].cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	var out: Array = []
	for i in tans.size():
		if i > 0:
			var ax := tans[i - 1].cross(tans[i])
			if ax.length_squared() > 1e-10:
				nrm = nrm.rotated(ax.normalized(), tans[i - 1].angle_to(tans[i]))
		var bin := tans[i].cross(nrm).normalized()
		var row: Array = []
		for k in sides:
			var a := TAU * float(k) / float(sides)
			row.append(nrm * cos(a) + bin * sin(a))
		out.append(row)
	return out


## How fast the radius changes along the line at point i (per metre).
static func _slope(pts: Array, radii: Array, i: int) -> float:
	var n := pts.size()
	var i0 := maxi(i - 1, 0)
	var i1 := mini(i + 1, n - 1)
	var ds := ((pts[i1] as Vector3) - (pts[i0] as Vector3)).length()
	return (float(radii[i1]) - float(radii[i0])) / maxf(ds, 1e-4)


## `v` normalized and turned to agree with `ref` (or `ref` if v is nothing).
static func _facing(v: Vector3, ref: Vector3) -> Vector3:
	if v.length_squared() < 1e-12:
		return ref.normalized()
	var n := v.normalized()
	return -n if n.dot(ref) < 0.0 else n


## A quad of [position, normal] corners a-b-c-d, as two triangles.
static func _quad(st: SurfaceTool, a: Array, b: Array, c: Array, d: Array) -> void:
	_tri(st, a[0], b[0], c[0], a[1], b[1], c[1])
	_tri(st, a[0], c[0], d[0], a[1], c[1], d[1])


## One triangle, wound so its FRONT face is the side its normals point to
## (Godot's front faces wind clockwise seen from outside).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	_tri_to(st, a, b, c, na, nb, nc, na + nb + nc)


## One triangle whose FRONT face looks along `front`, whatever its normals.
static func _tri_to(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, front: Vector3) -> void:
	if (c - a).cross(b - a).dot(front) < 0.0:
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.set_uv(UV)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_uv(UV)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_uv(UV)
	st.add_vertex(c)


## Queues a triangle (3 corners, 3 normals) in a buffer, so a frond can be
## checked against the footprint before it is committed.
static func _push(buf: Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3,
		nb: Vector3, nc: Vector3) -> void:
	buf.append_array([a, b, c, na, nb, nc])


static func _flush(st: SurfaceTool, buf: Array) -> void:
	for i in range(0, buf.size(), 6):
		_tri(st, buf[i], buf[i + 1], buf[i + 2], buf[i + 3], buf[i + 4], buf[i + 5])
