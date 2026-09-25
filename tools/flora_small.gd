extends RefCounted
## SMALL FLORA — the jungle floor right beside the trail, in smooth procedural
## shapes. It replaces the Kenney bushes, grass, box bamboo, flowers and rocks
## (faceted gems and stacked cubes) with plants that have believable botany
## and soft, rounded forms.
##
##   undergrowth(i)   i % 4:  0 elephant ear (taro)       1 arching forest fern
##                            2 calathea (prayer plant)   3 sedge tuft (+ ground orchid)
##   bamboo(i)        i % 3:  0 tall, the culm tips nodding over in arches
##                            1 dense and upright         2 a young clump leaning wide
##   flower_patch(i)  i % 2:  0 heliconia (lobster-claw)  1 yellow hibiscus, red eye
##   rock(i)          i % 2:  0 a mossy boulder           1 a pair of mossy stones
##   showcase()       one of each along the right verge, for preview_flora
##
## Every builder returns merge-list parts (FK.part dictionaries; "mat" names a
## material in res://materials/), built in the plant's own space with its base
## on y = 0, and is seeded from its index: the same index always grows the
## same plant.
##
## THE WIND. The foliage shader sways each vertex by its WORLD height, at a
## rate set per material. shrub and shrub_dark sway alike, and so do leaf_big
## and leaf_big_pale; the two pairs sway differently. So a leaf and the stalk
## it sits on always come from ONE pair, and anything in a non-swaying
## material (flowers, bamboo, stone) never hangs from a swaying stalk.
##
## THE FACES. Broad leaves, fronds and grass are single sheets: the foliage
## shader is cull_disabled and flips the normal on the back face, so one sheet
## lights correctly from both sides at half the triangles. Petals, bracts and
## bamboo leaves use standard materials that cull back faces, so they are
## built double-sided.

const FK := preload("res://tools/flora_kit.gd")
const SM := preload("res://tools/smooth_mesh.gd")

## Elephant-ear outline: polar radius (x the joint-to-tip length) at each angle
## from the tip, down the right half to the sinus between the basal lobes at
## PI. Interpolated with Catmull-Rom, and mirrored for the left half.
const _HEART_A := [0.0, 0.3, 0.68, 1.1, 1.62, 2.12, 2.52, 2.86, PI]
const _HEART_R := [1.0, 0.75, 0.65, 0.60, 0.59, 0.63, 0.63, 0.47, 0.13]
## Where that outline is sampled (one half, tip to sinus): closer together at
## the drip tip and round the lobes, where it turns fastest.
const _HEART_S := [0.0, 0.13, 0.3, 0.52, 0.8, 1.1, 1.42, 1.74, 2.04, 2.32, 2.58, 2.84, PI]

const _BAMBOO_BUDGET := 2390


# =============================================================================
#  PUBLIC BUILDERS
# =============================================================================

## The jungle floor by the trail: 1.6-2.2 m across (inside a 1.2 m footprint
## radius), 0.8-1.25 m tall, under 1200 triangles.
static func undergrowth(index: int) -> Array:
	match posmod(index, 4):
		0:
			return _fit(_elephant_ear(index), 1.19)
		1:
			return _fit(_fern(index), 1.19)
		2:
			return _fit(_calathea(index), 1.19)
	return _fit(_sedge(index), 1.19)


## A clump of 6-8 bamboo culms, 3.5-5 m tall, leaning out into a vase. Each
## culm is a smooth 12-sided tube with a pale node ridge every 0.36-0.5 m up
## to 84% of its length; from the upper nodes, twigs carry drooping hands of
## lance leaves, and more hang from the culm's nodding tip. Culms and nodes
## take what they need of the 2400-triangle budget; the leaves get the rest.
##   kind 0: tall (4.3-4.8 m), the tips arching right over
##   kind 1: dense and upright, eight thinner culms, the crown heavy with leaf
##   kind 2: young and open, the culms leaning wide, lighter in leaf
static func bamboo(index: int) -> Array:
	var rng := _rng(index, 53)
	var kind := posmod(index, 3)
	var count: int = [6, 8, 6][kind]
	var len_lo: float = [5.0, 3.85, 3.8][kind]
	var len_hi: float = [5.5, 4.3, 4.45][kind]
	var r_lo: float = [0.062, 0.047, 0.045][kind]
	var r_hi: float = [0.08, 0.058, 0.056][kind]
	var nod_lo: float = [75.0, 14.0, 26.0][kind]
	var nod_hi: float = [105.0, 30.0, 48.0][kind]
	var arch0: float = [0.66, 0.55, 0.45][kind]
	var lean_lo: float = [3.0, 1.0, 9.0][kind]
	var lean_hi: float = [6.0, 3.0, 15.0][kind]
	var d_lo: float = [0.06, 0.07, 0.12][kind]
	var d_hi: float = [0.24, 0.24, 0.32][kind]
	var spray_from: float = [0.52, 0.42, 0.56][kind]
	var leafy: float = [1.0, 1.0, 0.62][kind]
	var parts: Array = []
	var used := 0
	var st_node := _begin()
	var sprays: Array = []     # [node position, branch azimuth]
	var whips: Array = []      # [points along the nodding tip, outward direction]
	var spin := rng.randf() * TAU
	for c in count:
		var az := spin + TAU * (float(c) + rng.randf_range(-0.3, 0.3)) / float(count)
		var dist := rng.randf_range(d_lo, d_hi)
		var base := Vector3(cos(az) * dist, -0.06, sin(az) * dist)
		var out_az := az + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(out_az), 0.0, sin(out_az))
		var length := rng.randf_range(len_lo, len_hi)
		var r0 := lerpf(r_lo, r_hi, inverse_lerp(len_lo, len_hi, length)) * rng.randf_range(0.92, 1.08)
		var lean := deg_to_rad(rng.randf_range(lean_lo, lean_hi))
		var nod := deg_to_rad(rng.randf_range(nod_lo, nod_hi))
		# The centreline, by arc length: straight, then bowing out and over.
		# Below 4 m nothing may leave the clump's footprint, so a culm that
		# would is straightened until it fits.
		var line: Array = []
		for attempt in 16:
			line = _culm_line(base, out, length, lean, nod, arch0)
			if _culm_fits(line):
				break
			lean *= 0.85
			nod *= 0.9
		# The tube: straight below, its rings closer together round the arch.
		var ks: Array = [0, 18, 28, 33, 37, 40] if kind == 0 else [0, 20, 30, 36, 40]
		var pts: Array = []
		var rads: Array = []
		var ts: Array = []
		for k: int in ks:
			var t := float(k) / 40.0
			pts.append(line[k])
			rads.append(r0 * _culm_taper(t))
			ts.append(t)
		parts.append(FK.part(SM.tube(pts, rads, 12, false), Transform3D(), "bamboo"))
		used += 24 * (ks.size() - 1)
		# SM.tube's ring frame starts from its first span's tangent x UP; the
		# node ridges use the same phase, so their 12 corners line up with
		# the culm's and meet it in a clean ring.
		var ref := ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized().cross(Vector3.UP).normalized()
		# The nodes, 0.36 m apart near the ground lengthening to 0.5 m, up to
		# 84% of the culm. Each in the upper part carries a branch, on
		# alternate sides from node to node, mostly out from the clump.
		var s := rng.randf_range(0.2, 0.28)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		while s < length * 0.84:
			var t := s / length
			var at := _along(pts, rads, ts, t)
			var pos: Vector3 = at[0]
			var dir: Vector3 = at[1]
			var rad: float = at[2]
			_node_ridge(st_node, pos, dir, rad, ref)
			used += 12
			if t > spray_from:
				sprays.append([pos + dir * 0.012, out_az + side * (0.95 + rng.randf_range(-0.35, 0.35))])
				side = -side
			s += lerpf(0.36, 0.5, clampf((s - 0.3) / 1.4, 0.0, 1.0)) * rng.randf_range(0.94, 1.06)
		var whip: Array = []
		for k: int in [33, 36, 38, 40]:
			whip.append(line[k])
		whips.append([whip, out])
	_add(parts, st_node, "bamboo_node")
	# The twigs, then hands of leaves on them and along the nodding tips:
	# whatever the culms left of the budget.
	var hands: Array = []      # [position, outward direction, droop]
	var st_twig := _begin()
	for sp: Array in sprays:
		var node: Vector3 = sp[0]
		var baz: float = sp[1]
		var bh := Vector3(cos(baz), 0.0, sin(baz))
		var el := deg_to_rad(rng.randf_range(10.0, 30.0))
		var end := node + (bh * cos(el) + Vector3.UP * sin(el)) * rng.randf_range(0.45, 0.72)
		end = _pull_in(end, 0.9 if end.y < 4.3 else 1.7)
		_sliver(st_twig, node, end, 0.008)
		used += 2
		# Three hands along the twig, so its leaves make a layered spray
		# out from the culm rather than a tassel at its end.
		for f: float in [0.35, 0.68, 1.0]:
			hands.append([node.lerp(end, f), (end - node).slide(Vector3.UP).normalized(), 0.55 + 0.4 * f])
	for w: Array in whips:
		var wo: Vector3 = w[1]
		for p: Vector3 in (w[0] as Array):
			# Leaves hang from the tip only where they cannot drop out of
			# the footprint below 4 m.
			if p.y > 4.2 or Vector2(p.x, p.z).length() < 1.0:
				hands.append([p, wo, 1.2])
	_add(parts, st_twig, "bamboo")
	var n_leaves := int(float(_BAMBOO_BUDGET - used) * 0.5 * leafy)
	var st := _begin()
	for hi in hands.size():
		var hd: Array = hands[hi]
		var pos: Vector3 = hd[0]
		var hdir: Vector3 = hd[1]
		var droop: float = hd[2]
		var cnt := floori(float(n_leaves) / float(hands.size())) + (1 if hi < n_leaves % hands.size() else 0)
		for l in cnt:
			# A hand: the leaves fanned out round the twig's direction, each
			# hanging from its base.
			var f := (float(l) + 0.5) / float(cnt) - 0.5
			var dh := hdir.rotated(Vector3.UP, f * deg_to_rad(110.0) + rng.randf_range(-0.25, 0.25))
			var dip := deg_to_rad(minf(rng.randf_range(24.0, 52.0) * droop, 75.0))
			var ll := rng.randf_range(0.28, 0.4)
			var lb := pos + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.04, 0.02),
				rng.randf_range(-0.03, 0.03))
			var tipp := lb + (dh * cos(dip) - Vector3.UP * sin(dip)) * ll
			if tipp.y < 4.08 and Vector2(tipp.x, tipp.z).length() > 1.12:
				if lb.y > 4.14:
					# Up in the crown: hang it less steeply, so its tip stays
					# above 4 m, where the crown may spread.
					dip = minf(dip, asin(clampf((lb.y - 4.1) / ll, 0.0, 1.0)))
				else:
					dh = -dh
			var ld := dh * cos(dip) - Vector3.UP * sin(dip)
			_lance1(st, lb, ld, ll, rng.randf_range(0.05, 0.065), rng.randf_range(-0.6, 0.6))
	_add(parts, st, "bamboo_leaf")
	return parts


## The only colour in the jungle: a low leafy clump with real flowers.
## 1.3-1.7 m wide, 0.8-1.0 m tall.
static func flower_patch(index: int) -> Array:
	if posmod(index, 2) == 0:
		return _fit(_heliconia(index), 1.19)
	return _fit(_hibiscus(index), 1.19)


## A weathered, mossy boulder: 2.0-2.4 m across, about 0.7 m high.
static func rock(index: int) -> Array:
	if posmod(index, 2) == 0:
		return _boulder(index)
	return _stone_pair(index)


## One of each, laid out along the right verge (x 5..14, z 0..-40) for
## tools/preview_flora. SMALL_FOCUS=<kind>:<index> (e.g. bamboo:1) swaps that
## plant into the nearest slot, for the close-up shot.
static func showcase() -> Array:
	var items: Array = [
		["undergrowth", 0], ["undergrowth", 1], ["undergrowth", 2], ["undergrowth", 3],
		["flower_patch", 0], ["flower_patch", 1], ["rock", 0], ["rock", 1],
		["bamboo", 0], ["bamboo", 1], ["bamboo", 2],
	]
	var slots: Array = [
		Vector3(6.3, 0.0, -6.0), Vector3(9.5, 0.0, -9.0), Vector3(6.4, 0.0, -12.5),
		Vector3(9.8, 0.0, -16.0), Vector3(6.4, 0.0, -19.5), Vector3(9.6, 0.0, -23.0),
		Vector3(6.8, 0.0, -27.0), Vector3(9.8, 0.0, -31.0),
		Vector3(13.0, 0.0, -12.5), Vector3(13.2, 0.0, -22.0), Vector3(12.8, 0.0, -34.0),
	]
	if OS.get_environment("SMALL_SWEEP") != "":
		_sweep(int(OS.get_environment("SMALL_SWEEP")))
	var focus := OS.get_environment("SMALL_FOCUS")
	if focus != "":
		for i in items.size():
			var it: Array = items[i]
			if "%s:%d" % [it[0], it[1]] == focus:
				var tmp: Vector3 = slots[0]
				slots[0] = slots[i]
				slots[i] = tmp
	var out: Array = []
	var total := 0
	for i in items.size():
		var it: Array = items[i]
		var kind: String = it[0]
		var idx: int = it[1]
		var ps: Array = []
		match kind:
			"undergrowth":
				ps = undergrowth(idx)
			"bamboo":
				ps = bamboo(idx)
			"flower_patch":
				ps = flower_patch(idx)
			_:
				ps = rock(idx)
		total += _stats("%s(%d)" % [kind, idx], ps)
		var xf := Transform3D(Basis(Vector3.UP, 0.7 * float(i)), slots[i])
		for p: Dictionary in ps:
			var q := p.duplicate()
			q["xform"] = xf * (p["xform"] as Transform3D)
			out.append(q)
	print("SMALL total triangles %d" % total)
	return out


# =============================================================================
#  UNDERGROWTH
# =============================================================================

## ELEPHANT EAR (Colocasia / taro): six big heart-shaped leaves on long
## arching stalks, and in the middle a new leaf still furled into a pale
## spindle. The two oldest leaves are darker, lower, further out and hang
## steeply; the mature ones are held higher, with a pale midrib and the two
## veins that run back into the basal lobes. Every blade is cupped along its
## midrib, domed from the stalk joint and wavy at the margin. Each stalk is
## in its own leaf's material, so stalk and blade sway as one.
static func _elephant_ear(index: int) -> Array:
	var rng := _rng(index, 11)
	var parts: Array = []
	var st_old := _begin()
	var st_leaf := _begin()
	var st_pale := _begin()
	var n := 6
	var spin := rng.randf() * TAU
	for i in n:
		var az := spin + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(n)
		var h := Vector3(cos(az), 0.0, sin(az))
		var old_leaf := i % 3 == 0
		var lt: float
		var reach: float
		var top: float
		var tilt: float
		if old_leaf:
			lt = rng.randf_range(0.64, 0.72)
			reach = rng.randf_range(0.42, 0.5)
			top = rng.randf_range(0.5, 0.6)
			tilt = deg_to_rad(rng.randf_range(16.0, 26.0))
		else:
			lt = rng.randf_range(0.6, 0.68)
			reach = rng.randf_range(0.24, 0.34)
			top = rng.randf_range(0.78, 0.94)
			tilt = deg_to_rad(rng.randf_range(-6.0, 10.0))
		if i == 5:
			lt *= 0.74
			reach *= 0.75
			top *= 0.82
		# The blade's frame: tip (+Y) out and hanging `tilt` below the
		# horizontal, upper face (+Z) to the sky.
		var y_dir := h * cos(tilt) - Vector3.UP * sin(tilt)
		var z_dir := Vector3.UP * cos(tilt) + h * sin(tilt)
		var b := Basis(y_dir.normalized(), rng.randf_range(-0.3, 0.3)) * _frame(y_dir, z_dir)
		var att := h * reach + Vector3.UP * top
		_heart_leaf(st_old if old_leaf else st_leaf, null if old_leaf or i == 5 else st_pale,
			Transform3D(b, att), lt, rng.randf_range(0.14, 0.22), rng.randf_range(0.14, 0.2),
			rng.randf() * TAU)
		# The stalk rises from the crown, leans out and meets the blade's
		# underside at the joint.
		var lean := deg_to_rad(rng.randf_range(26.0, 40.0))
		var te := Vector3.UP * cos(lean) + h * sin(lean)
		var p0 := h * 0.04 + Vector3(0.0, -0.04, 0.0)
		var p3 := att - b.z * 0.012
		var p1 := p0 + Vector3.UP * top * 0.45 + h * 0.03
		var p2 := p3 - te * top * 0.34
		parts.append(FK.part(SM.tube([p0, _bez3(p0, p1, p2, p3, 0.5), p3], [0.032, 0.024, 0.016], 12, false),
			Transform3D(), "shrub" if old_leaf else "leaf_big"))
	# The new leaf, still rolled into a spindle on top of its stalk.
	var ya := spin + TAU * (0.5 + rng.randf_range(-0.15, 0.15)) / float(n)
	var yh := Vector3(cos(ya), 0.0, sin(ya))
	var j0 := yh * 0.1 + Vector3.UP * rng.randf_range(0.66, 0.74)
	var ydir := (Vector3.UP + yh * 0.35).normalized()
	parts.append(FK.part(SM.tube([yh * 0.03 + Vector3(0.0, -0.04, 0.0), yh * 0.05 + Vector3.UP * 0.36, j0,
		j0 + ydir * 0.11, j0 + ydir * 0.3], [0.026, 0.021, 0.017, 0.03, 0.002], 12, false),
		Transform3D(), "leaf_big_pale"))
	_add(parts, st_old, "shrub")
	_add(parts, st_leaf, "leaf_big")
	_add(parts, st_pale, "leaf_big_pale")
	return parts


## The taro leaf's outline radius at angle `th` (0 = tip, PI = sinus), on a
## Catmull-Rom curve through _HEART_A/_HEART_R. Its ends are extrapolated, so
## the mirrored halves meet at a point: a drip tip, and a notched sinus.
static func _heart_radius(th: float) -> float:
	var n := _HEART_A.size()
	var k := 0
	while k < n - 2 and th > float(_HEART_A[k + 1]):
		k += 1
	var a0: float = _HEART_A[k]
	var a1: float = _HEART_A[k + 1]
	var t := clampf((th - a0) / (a1 - a0), 0.0, 1.0)
	var r1: float = _HEART_R[k]
	var r2: float = _HEART_R[k + 1]
	var r0: float = float(_HEART_R[k - 1]) if k > 0 else 2.0 * r1 - r2
	var r3: float = float(_HEART_R[k + 2]) if k + 2 < n else 2.0 * r2 - r1
	return cubic_interpolate(r1, r2, r0, r3, t)


## A peltate taro leaf: heart-shaped, two rounded basal lobes, pointed drip
## tip, built as a polar fan round the joint where the stalk meets it from
## below. Local frame: joint at the origin, tip toward +Y, upper face +Z. It
## domes down from the joint like an umbrella, cups up along the midrib, its
## tip hangs by `droop` and its margin rolls in slow waves. With `st_vein`,
## a pale midrib and the two lobe veins lie on its upper face.
static func _heart_leaf(st: SurfaceTool, st_vein: SurfaceTool, xf: Transform3D, lt: float,
		droop: float, fold: float, phase: float) -> void:
	var ang: Array = []
	for k in _HEART_S.size():
		ang.append(float(_HEART_S[k]))
	for k in range(_HEART_S.size() - 2, 0, -1):
		ang.append(-float(_HEART_S[k]))
	var segs := ang.size()
	var fr: Array = [0.0, 0.42, 0.76, 1.0]
	var P: Array = []
	for j in fr.size():
		var f: float = fr[j]
		var row: Array = []
		for i in (1 if j == 0 else segs):
			var th: float = ang[i]
			var r := lt * _heart_radius(absf(th)) * f * (1.0 + 0.03 * sin(2.0 * th + phase))
			var x := r * sin(th)
			var y := r * cos(th)
			var rho := r / lt
			var z := -0.07 * lt * rho * rho
			z -= droop * lt * pow(maxf(y, 0.0) / lt, 2.0)
			z += fold * absf(x) + 0.22 * x * x / lt
			z += 0.035 * lt * sin(th * 5.0 + phase) * rho * rho * rho
			row.append(xf * Vector3(x, y, z))
		P.append(row)
	var N := _polar_normals(P, xf.basis.z.normalized(), Vector3.ZERO, false)
	_emit_polar(st, P, N, 0, fr.size() - 1, false, 0.0)
	if st_vein == null:
		return
	# The midrib from the joint to the tip, and the two veins from the joint
	# back into the basal lobes: thin ribbons just proud of the upper face.
	var centre: Vector3 = (P[0] as Array)[0]
	var cn: Vector3 = (N[0] as Array)[0]
	for i: int in [0, 9, segs - 9]:
		for j in fr.size() - 1:
			var a: Vector3 = centre if j == 0 else (P[j] as Array)[i]
			var bb: Vector3 = (P[j + 1] as Array)[i]
			var na: Vector3 = cn if j == 0 else (N[j] as Array)[i]
			var nb: Vector3 = (N[j + 1] as Array)[i]
			var along := (bb - a).normalized()
			var w0 := 0.012 if i == 0 else 0.008
			var wa := lerpf(w0, 0.003, float(j) / 3.0)
			var wb := lerpf(w0, 0.003, float(j + 1) / 3.0)
			var sa := na.cross(along).normalized()
			var sb := nb.cross(along).normalized()
			var a0 := a + na * 0.004
			var b0 := bb + nb * 0.004
			_tri(st_vein, a0 - sa * wa, b0 - sb * wb, b0 + sb * wb, na, nb, nb)
			_tri(st_vein, a0 - sa * wa, b0 + sb * wb, a0 + sa * wa, na, nb, na)


## FOREST FERN: a dozen pinnate fronds arching out from one crown — the
## young ones near-upright and pale, the old ones low, long and darker. Each
## frond is a slender rachis lined with 17 pairs of narrow, overlapping
## leaflets that lengthen to a third of the way up, then taper to the tip.
static func _fern(index: int) -> Array:
	var rng := _rng(index, 23)
	var parts: Array = []
	var sts: Array = [_begin(), _begin(), _begin()]
	var mats: Array = ["leaf_big_pale", "leaf_big", "shrub"]
	var n := 13
	var spin := rng.randf() * TAU
	for f in n:
		var age := (f * 7) % 3          # 0 young, 1 mature, 2 old
		var az := spin + TAU * (float(f) + rng.randf_range(-0.35, 0.35)) / float(n)
		var h := Vector3(cos(az), 0.0, sin(az))
		var length: float
		var e0: float
		var e1: float
		match age:
			0:
				length = rng.randf_range(1.0, 1.15)
				e0 = deg_to_rad(rng.randf_range(80.0, 86.0))
				e1 = deg_to_rad(rng.randf_range(5.0, 25.0))
			1:
				length = rng.randf_range(1.25, 1.4)
				e0 = deg_to_rad(rng.randf_range(72.0, 80.0))
				e1 = deg_to_rad(rng.randf_range(-25.0, -5.0))
			_:
				length = rng.randf_range(1.22, 1.36)
				e0 = deg_to_rad(rng.randf_range(58.0, 68.0))
				e1 = deg_to_rad(rng.randf_range(-50.0, -30.0))
		var base := h * 0.05 + Vector3(0.0, 0.02, 0.0)
		# Frond 0 of each age doubles as the tallest, so the crown has a top.
		_frond(sts[age] as SurfaceTool, base, h, length, e0, e1,
			rng.randf_range(-0.35, 0.35), 0.22 * length / 1.2, 17)
	for k in 3:
		_add(parts, sts[k] as SurfaceTool, mats[k] as String)
	return parts


static func _frond(st: SurfaceTool, base: Vector3, h: Vector3, length: float, e0: float,
		e1: float, roll: float, pmax: float, pairs: int) -> void:
	# The rachis: integrate a bend that grows toward the tip.
	var steps := 48
	var pts: Array = [base]
	var p := base
	for k in steps:
		var u := (float(k) + 0.5) / float(steps)
		var th := lerpf(e0, e1, pow(u, 1.4))
		p += (h * cos(th) + Vector3.UP * sin(th)) * length / float(steps)
		pts.append(p)
	var side0 := Vector3.UP.cross(h).normalized()
	# The rachis itself, a thin strip tapering to the tip.
	var rs := 8
	for k in rs:
		var i0 := floori(float(k * steps) / float(rs))
		var i1 := floori(float((k + 1) * steps) / float(rs))
		var a: Vector3 = pts[i0]
		var b: Vector3 = pts[i1]
		var tng := (b - a).normalized()
		var sa := side0.rotated(tng, roll * float(k) / float(rs))
		var sb := side0.rotated(tng, roll * float(k + 1) / float(rs))
		var wa := lerpf(0.007, 0.0015, float(k) / float(rs))
		var wb := lerpf(0.007, 0.0015, float(k + 1) / float(rs))
		var na := tng.cross(sa).normalized()
		var nb := tng.cross(sb).normalized()
		_tri(st, a - sa * wa, b - sb * wb, b + sb * wb, na, nb, nb)
		_tri(st, a - sa * wa, b + sb * wb, a + sa * wa, na, nb, na)
	for k in pairs:
		var u := lerpf(0.08, 0.975, float(k) / float(pairs - 1))
		var fi := u * float(steps)
		var i0 := mini(int(fi), steps - 1)
		var pos: Vector3 = (pts[i0] as Vector3).lerp(pts[i0 + 1], fi - float(i0))
		var tng: Vector3 = ((pts[i0 + 1] as Vector3) - (pts[i0] as Vector3)).normalized()
		var side := side0.rotated(tng, roll * u)
		var up := tng.cross(side).normalized()
		# Leaflets are longest a third of the way up and taper to the tip;
		# narrow, widest a quarter of the way out, overlapping the next pair.
		var prof := pow(sin(PI * pow(clampf((u - 0.02) / 0.98, 0.0, 1.0), 0.72)), 0.85)
		var lp := maxf(pmax * prof, 0.03)
		var wp := maxf(lp * 0.3, 0.014)
		for sgn: float in [-1.0, 1.0]:
			var g := deg_to_rad(54.0)
			var d := (tng * cos(g) + side * sgn * sin(g) - up * 0.3).normalized()
			var across := up.cross(d).normalized()
			var up_p := d.cross(across).normalized()
			if up_p.dot(up) < 0.0:
				up_p = -up_p
			var b0 := pos + side * sgn * 0.004
			var tip := b0 + d * lp - up_p * lp * 0.12
			var sh := b0 + d * lp * 0.3 + up_p * wp * 0.16
			var lft := sh + across * wp * 0.5
			var rgt := sh - across * wp * 0.5
			_leaflet(st, b0, lft, tip, rgt, up_p)


## Two triangles folded along their shared midvein, for fern leaflets:
## base, left shoulder, tip, right shoulder.
static func _leaflet(st: SurfaceTool, b0: Vector3, lft: Vector3, tip: Vector3, rgt: Vector3,
		up: Vector3) -> void:
	var n1 := (lft - b0).cross(tip - b0).normalized()
	if n1.dot(up) < 0.0:
		n1 = -n1
	var n2 := (tip - b0).cross(rgt - b0).normalized()
	if n2.dot(up) < 0.0:
		n2 = -n2
	# Shaded mostly by the frond's own up, so the two halves of a leaflet
	# don't flash light and dark alternately down the frond like a zip.
	var nm := (n1 + n2 + up * 3.0).normalized()
	var nl := (n1 * 0.4 + up).normalized()
	var nr := (n2 * 0.4 + up).normalized()
	_tri(st, b0, lft, tip, nm, nl, nm)
	_tri(st, b0, tip, rgt, nm, nm, nr)


## CALATHEA (prayer plant): a vase of sixteen elliptic, wavy-edged leaves on
## slender stalks, the way they carpet the rainforest floor. Each leaf bends
## at the joint atop its stalk and arches out; the old ones spread low, the
## young ones stand up in the middle. The mature leaves are dark with a paler
## feathered band down the midrib; the young ones are fresh green all over.
static func _calathea(index: int) -> Array:
	var rng := _rng(index, 37)
	var parts: Array = []
	var st_dark := _begin()
	var st_mid := _begin()
	var st_young := _begin()
	var n := 18
	var spin := rng.randf() * TAU
	for i in n:
		var young := i < 3
		var outer := i >= 10
		var az := spin + float(i) * 2.39996 + rng.randf_range(-0.2, 0.2)
		var h := Vector3(cos(az), 0.0, sin(az))
		var base := h * rng.randf_range(0.02, 0.09) + Vector3(0.0, -0.02, 0.0)
		var pl: float
		var pe: float
		var be0: float
		var bend: float
		var bl: float
		var bw: float
		if young:
			pl = rng.randf_range(0.5, 0.6)
			pe = deg_to_rad(rng.randf_range(78.0, 86.0))
			be0 = deg_to_rad(rng.randf_range(58.0, 72.0))
			bend = deg_to_rad(rng.randf_range(15.0, 30.0))
			bl = rng.randf_range(0.34, 0.4)
			bw = rng.randf_range(0.075, 0.088)
		elif outer:
			pl = rng.randf_range(0.2, 0.3)
			pe = deg_to_rad(rng.randf_range(44.0, 56.0))
			be0 = deg_to_rad(rng.randf_range(8.0, 24.0))
			bend = deg_to_rad(rng.randf_range(28.0, 46.0))
			bl = rng.randf_range(0.5, 0.58)
			bw = rng.randf_range(0.11, 0.125)
		else:
			pl = rng.randf_range(0.32, 0.44)
			pe = deg_to_rad(rng.randf_range(60.0, 72.0))
			be0 = deg_to_rad(rng.randf_range(28.0, 46.0))
			bend = deg_to_rad(rng.randf_range(25.0, 42.0))
			bl = rng.randf_range(0.46, 0.54)
			bw = rng.randf_range(0.1, 0.115)
		var joint := base + (h * cos(pe) + Vector3.UP * sin(pe)) * pl
		# Keep the leaf tip inside the footprint.
		var tip := joint + _arch_tip(h, bl, be0, be0 - bend)
		var hr := Vector2(tip.x, tip.z).length()
		if hr > 1.12:
			bl *= maxf(0.6, 1.0 - (hr - 1.12) / bl)
		parts.append(FK.part(SM.tube([base, joint], [0.01, 0.007], 12, false), Transform3D(),
			"leaf_big" if young else "shrub_dark"))
		_calathea_blade(st_young if young else st_dark, st_young if young else st_mid, joint, h, bl, bw,
			be0, be0 - bend, rng.randf_range(-0.4, 0.4), rng.randf() * TAU)
	_add(parts, st_dark, "shrub_dark")
	_add(parts, st_mid, "shrub")
	_add(parts, st_young, "leaf_big")
	return parts


## One calathea blade from `base`, rising at `e0` toward `h` and arching over
## to `e1`: elliptic, round-based, drawn to a short point, gently folded up
## along the midrib and rippled at the margin. Five points across; the two
## middle strips (the feathered band down the midrib, its edge zig-zagging
## from station to station) go to `st_mid`, the margins to `st_edge`.
static func _calathea_blade(st_edge: SurfaceTool, st_mid: SurfaceTool, base: Vector3, h: Vector3,
		length: float, hw: float, e0: float, e1: float, twist: float, phase: float) -> void:
	var us: Array = [0.0, 0.1, 0.27, 0.47, 0.67, 0.85, 1.0]
	var side0 := Vector3.UP.cross(h).normalized()
	var g: Array = []
	var hints: Array = []
	var p := base
	var u_prev := 0.0
	for k in us.size():
		var u: float = us[k]
		if k > 0:
			for s in 3:
				var um := lerpf(u_prev, u, (float(s) + 0.5) / 3.0)
				var thm := lerpf(e0, e1, pow(um, 1.4))
				p += (h * cos(thm) + Vector3.UP * sin(thm)) * (u - u_prev) * length / 3.0
		var th := lerpf(e0, e1, pow(u, 1.4))
		var t := h * cos(th) + Vector3.UP * sin(th)
		var side := side0.rotated(t, twist * u)
		var nrm := t.cross(side).normalized()
		var w := hw * pow(sin(PI * pow(u, 0.8)), 0.7)
		var a := 0.4 if k % 2 == 0 else 0.62
		var rip := 0.12 * w * sin(u * 11.0 + phase)
		var fold := 0.22
		g.append([p + side * w + nrm * (w * fold + rip), p + side * w * a + nrm * w * a * fold * 0.6, p,
			p - side * w * a + nrm * w * a * fold * 0.6, p - side * w + nrm * (w * fold - rip)])
		hints.append(nrm)
		u_prev = u
	var nm := _grid_normals(g, hints)
	for r in g.size() - 1:
		var r0: Array = g[r]
		var r1: Array = g[r + 1]
		var n0: Array = nm[r]
		var n1: Array = nm[r + 1]
		for c in 4:
			var st := st_mid if c == 1 or c == 2 else st_edge
			_tri(st, r0[c], r1[c], r1[c + 1], n0[c], n1[c], n1[c + 1])
			_tri(st, r0[c], r1[c + 1], r0[c + 1], n0[c], n1[c + 1], n0[c + 1])


## SEDGE TUFT: a dense fountain of keeled, arching blades with two small
## offsets beside it — mostly fresh pale green, some older and darker — and
## on alternate indices two slender spikes of pink ground orchids
## (Spathoglottis, the roadside orchid of the tropics), each crowned with a
## cluster of open flowers.
static func _sedge(index: int) -> Array:
	var rng := _rng(index, 41)
	var parts: Array = []
	var st_new := _begin()
	var st_old := _begin()
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	var bloom := posmod(floori(float(index) / 4.0), 2) == 0
	var tufts: Array = [
		[Vector3(0.0, 0.0, 0.0), 38 if bloom else 44, 1.0, 0.1],
		[Vector3(0.62, 0.0, 0.3), 8 if bloom else 9, 0.68, 0.05],
		[Vector3(-0.42, 0.0, 0.56), 8 if bloom else 9, 0.62, 0.05],
	]
	for t: Array in tufts:
		var c: Vector3 = spin * (t[0] as Vector3)
		var cnt: int = t[1]
		var sz: float = t[2]
		var spread: float = t[3]
		for b in cnt:
			var az := rng.randf() * TAU
			var h := Vector3(cos(az), 0.0, sin(az))
			# Inner blades stand up, outer ones fall out over the edge.
			var outer := rng.randf()
			var e0 := deg_to_rad(88.0 - lerpf(4.0, 42.0, outer))
			var e1 := e0 - deg_to_rad(lerpf(40.0, 105.0, outer) + rng.randf_range(-10.0, 10.0))
			var length := sz * rng.randf_range(0.72, 1.2) * lerpf(0.95, 1.1, outer)
			var base := c + h * spread * outer + Vector3(0.0, -0.02, 0.0)
			# Keep the arching tips inside the 1.2 m footprint.
			var tip := base + _arch_tip(h, length, e0, e1)
			var hr := Vector2(tip.x, tip.z).length()
			if hr > 1.1:
				length *= 1.1 / hr
			var st := st_old if rng.randf() < 0.3 else st_new
			var us: Array = [0.0, 0.28, 0.55, 0.8, 1.0]
			var ws: Array = []
			var wid := rng.randf_range(0.034, 0.052)
			for u: float in us:
				ws.append(wid * 0.5 * pow(1.0 - pow(u, 2.2), 0.6) * (0.75 + 0.25 * sin(PI * u)))
			_arch_sheet(st, base, h, length, e0, e1, rng.randf_range(-1.0, 1.0), 0.45, us, ws)
	_add(parts, st_new, "leaf_big_pale")
	_add(parts, st_old, "leaf_big")
	if bloom:
		var st_f := _begin()
		for s in 2:
			var az := rng.randf() * TAU
			var h := Vector3(cos(az), 0.0, sin(az))
			var c := h * 0.05
			var top := rng.randf_range(0.98, 1.1) - 0.12 * float(s)
			var p0 := c + Vector3(0.0, -0.02, 0.0)
			var p2 := c + h * 0.2 + Vector3.UP * top
			var p1 := c + h * 0.04 + Vector3.UP * top * 0.55
			parts.append(FK.part(SM.tube([p0, p1, p2], [0.01, 0.008, 0.006], 12, false),
				Transform3D(), "flower_pink"))
			var axis := (p2 - p1).normalized()
			# Six flowers crowding the top of the spike, a bud at its tip,
			# each facing out round the spike and a little up.
			for k in 6:
				var fp := p2 - axis * (0.012 + 0.04 * float(k))
				var fa := az + float(k) * 2.4 + rng.randf_range(-0.3, 0.3)
				var fd := (Vector3(cos(fa), 0.0, sin(fa)) + Vector3.UP * 0.4).normalized()
				var fr := 0.028 if k == 0 else rng.randf_range(0.05, 0.06)
				_corolla(st_f, st_f, Transform3D(_frame_z(fd), fp + fd * (0.012 + fr * 0.2)),
					fr, 0.012, 0.32, rng.randf() * TAU, 2, 1)
		_add(parts, st_f, "flower_pink")
	return parts


# =============================================================================
#  FLOWER PATCHES
# =============================================================================

## HELICONIA (lobster-claw): four green pseudostems — the rolled leaf sheaths
## a heliconia stands on — each opening into a fan of broad paddle leaves
## held up like a banana's, and from three of them an upright spike of big
## boat-shaped pink bracts, gold-tipped, stepping alternately up a pink stem.
## Beside them on every fourth index, a little cluster of yellow parasol
## mushrooms (Leucocoprinus, gold from cap to stem).
static func _heliconia(index: int) -> Array:
	var rng := _rng(index, 61)
	var parts: Array = []
	var st_leaf := _begin()
	var st_pink := _begin()
	var st_gold := _begin()
	var spin := rng.randf() * TAU
	var stems: Array = []
	for s in 4:
		var az := spin + TAU * (float(s) + rng.randf_range(-0.2, 0.2)) / 4.0
		var hb := Vector3(cos(az), 0.0, sin(az))
		var sb := hb * rng.randf_range(0.05, 0.14)
		var top := sb + hb * 0.06 + Vector3.UP * rng.randf_range(0.2, 0.28)
		parts.append(FK.part(SM.tube([sb + Vector3(0.0, -0.03, 0.0), top], [0.028, 0.02], 12, false),
			Transform3D(), "leaf_big"))
		stems.append([sb, top, az])
	for s in 4:
		var sd: Array = stems[s]
		var top: Vector3 = sd[1]
		var az: float = sd[2]
		var nl := 3 if s < 3 else 2
		for l in nl:
			# Two leaves splay to either side of the shoot, the third (the
			# youngest) stands up in the middle.
			var la := az + ([-1.2, 1.2, 0.0][l] as float) + rng.randf_range(-0.35, 0.35)
			var h := Vector3(cos(la), 0.0, sin(la))
			var young := l == 2
			var length := rng.randf_range(0.76, 0.88) * (0.86 if young else 1.0)
			var e0 := deg_to_rad(rng.randf_range(78.0, 86.0) if young else rng.randf_range(58.0, 72.0))
			var e1 := deg_to_rad(rng.randf_range(24.0, 40.0) if young else rng.randf_range(-24.0, 8.0))
			var us: Array = [0.0, 0.2, 0.3, 0.42, 0.54, 0.66, 0.78, 0.89, 1.0]
			var ws: Array = []
			var wmax := rng.randf_range(0.12, 0.14) * (0.85 if young else 1.0)
			for u: float in us:
				if u <= 0.2:
					ws.append(0.012)
				else:
					var v := (u - 0.2) / 0.8
					ws.append(maxf(wmax * pow(sin(PI * pow(v, 0.75)), 0.6), 0.012 * (1.0 - v)))
			var tip := top + _arch_tip(h, length, e0, e1)
			var hr := Vector2(tip.x, tip.z).length()
			if hr > 1.1:
				length *= 1.1 / hr
			_arch_sheet(st_leaf, top - Vector3.UP * 0.03, h, length, e0, e1,
				rng.randf_range(-0.5, 0.5), 0.3, us, ws)
	_add(parts, st_leaf, "leaf_big")
	for k in 3:
		var sd: Array = stems[k]
		var sb: Vector3 = sd[0]
		var az: float = sd[2] + rng.randf_range(-0.3, 0.3)
		var hb := Vector3(cos(az), 0.0, sin(az))
		# The spike rises from inside its sheath, not from bare soil.
		var top := rng.randf_range(0.94, 1.02) - 0.06 * float(k)
		var base := sb + Vector3(0.0, -0.02, 0.0)
		var tip := sb + hb * rng.randf_range(0.16, 0.26) + Vector3.UP * top
		var mid := sb + hb * 0.03 + Vector3.UP * top * 0.46
		parts.append(FK.part(SM.tube([base, mid, tip], [0.013, 0.011, 0.007], 12, false),
			Transform3D(), "flower_pink"))
		var axis := (tip - mid).normalized()
		var plane := Vector3.UP.cross(hb).normalized().rotated(axis, rng.randf_range(-0.4, 0.4))
		var nb := 4
		for i in nb:
			var f := float(i) / float(nb - 1)
			var sgn := 1.0 if i % 2 == 0 else -1.0
			var at := mid.lerp(tip, 0.1 + 0.84 * f)
			var alpha := deg_to_rad(lerpf(60.0, 44.0, f))
			var d := (axis * cos(alpha) + plane * sgn * sin(alpha)).normalized()
			var z_up := (axis - d * axis.dot(d)).normalized()
			_bract(st_pink, st_gold, Transform3D(_frame(d, z_up), at + plane * sgn * 0.007),
				lerpf(0.29, 0.15, f))
	if posmod(index, 4) == 0:
		var ma := spin + rng.randf_range(0.0, TAU)
		var mc := Vector3(cos(ma), 0.0, sin(ma)) * 0.62
		var sizes: Array = [0.1, 0.075, 0.062]
		for m in sizes.size():
			var off := Vector3(rng.randf_range(-0.09, 0.09), 0.0, rng.randf_range(-0.09, 0.09))
			_mushroom(st_gold, parts, mc + off * float(m), float(sizes[m]),
				rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
	_add(parts, st_pink, "flower_pink")
	_add(parts, st_gold, "flower_gold")
	return parts


## One lobster-claw bract: a pointed boat, keel down, opening up toward the
## stem tip, the end curling up into a beak. Local frame: base at the origin,
## running up +Y, opening toward +Z. The beak is gold.
static func _bract(st_pink: SurfaceTool, st_gold: SurfaceTool, xf: Transform3D, length: float) -> void:
	var ss: Array = [0.0, 0.3, 0.6, 0.82, 1.0]
	var g: Array = []
	var hints: Array = []
	for s: float in ss:
		var w := 0.2 * length * pow(1.0 - pow(s, 1.8), 0.6)
		var d := 0.2 * length * pow(1.0 - pow(s, 1.4), 0.8)
		var zc := 0.28 * length * s * s
		var y := s * length
		g.append([xf * Vector3(-w, y, zc), xf * Vector3(0.0, y, zc - d), xf * Vector3(w, y, zc)])
		hints.append(xf.basis.z.normalized())
	var nm := _grid_normals(g, hints)
	_emit_grid(st_pink, g.slice(0, 4), nm.slice(0, 4), true, 0.0015)
	_emit_grid(st_gold, g.slice(3), nm.slice(3), true, 0.0015)


## A little yellow parasol mushroom: a smooth domed cap with a turned-under
## rim on a slim stem.
static func _mushroom(st: SurfaceTool, parts: Array, at: Vector3, size: float, tx: float,
		tz: float) -> void:
	var up := Vector3(tx, 1.0, tz).normalized()
	var b := _frame(up, Vector3.FORWARD)
	var stem_top := at + up * size * 1.5
	parts.append(FK.part(SM.tube([at + Vector3(0.0, -0.02, 0.0), stem_top],
		[size * 0.13, size * 0.1], 12, false), Transform3D(), "flower_gold"))
	var prof: Array = [Vector2(0.0, 0.62), Vector2(0.6, 0.46), Vector2(0.94, 0.06),
		Vector2(0.5, 0.0)]
	var segs := 8
	var P: Array = []
	for j in prof.size():
		var q: Vector2 = prof[j]
		var row: Array = []
		for i in (1 if j == 0 else segs):
			var ph := TAU * float(i) / float(segs)
			row.append(stem_top + b * Vector3(cos(ph) * q.x * size, q.y * size, sin(ph) * q.x * size))
		P.append(row)
	var N := _polar_normals(P, Vector3.ZERO, stem_top + up * size * 0.1, true)
	_emit_polar(st, P, N, 0, prof.size() - 1, false, 0.0)


## HIBISCUS: a dense rounded bush — a few small, deep, lumpy cores lost in
## the shadow of two layers of leaves — carrying seven big golden flowers,
## each five broad petals round a red eye, with the staminal column standing
## out of it. The flowers sit in the leaf skin on the sunny top and front,
## facing out and up. Core and leaves are one material, so a gap between the
## leaves reads as shadowed foliage.
static func _hibiscus(index: int) -> Array:
	var rng := _rng(index, 71)
	var parts: Array = []
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	var masses: Array = [
		[Vector3(0.0, 0.46, 0.0), Vector3(0.5, 0.44, 0.46)],
		[Vector3(0.36, 0.3, 0.24), Vector3(0.36, 0.3, 0.34)],
		[Vector3(-0.34, 0.28, -0.2), Vector3(0.38, 0.28, 0.34)],
	]
	for m: Array in masses:
		var c: Vector3 = spin * (m[0] as Vector3)
		m[0] = c
		var mesh := _clean(FK.clump((m[1] as Vector3) * 0.74, rng.randi_range(0, 63), 0.35, 0.15, 8, 4))
		parts.append(FK.part(mesh, Transform3D(Basis(), c), "shrub"))
	var st_leaf := _begin()
	_foliage_skin(st_leaf, rng, masses, 62, 0.14, 0.2, 0.64, 0.84, 0.8)
	_foliage_skin(st_leaf, rng, masses, 104, 0.15, 0.22, 0.64, 0.86, 0.96)
	_add(parts, st_leaf, "shrub")
	var st_petal := _begin()
	var st_eye := _begin()
	var nf := 7
	var placed: Array = []
	var tries := 0
	while placed.size() < nf and tries < 600:
		tries += 1
		var m: Array = masses[0 if placed.size() < 4 else rng.randi_range(1, 2)]
		var c: Vector3 = m[0]
		var r: Vector3 = m[1]
		var ph := TAU * float(placed.size()) / float(nf) * 2.0 + rng.randf_range(-0.6, 0.6)
		var el := rng.randf_range(0.3, 1.2)
		var d := Vector3(cos(ph) * cos(el), sin(el), sin(ph) * cos(el))
		var p := c + d * r * 0.97
		var ok := p.y > 0.25
		for q: Vector3 in placed:
			if q.distance_to(p) < 0.3:
				ok = false
		if not ok:
			continue
		placed.append(p)
		var ns := Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized()
		var fd := (ns * 0.7 + Vector3.UP).normalized()
		_bloom(st_petal, st_eye, Transform3D(_frame_z(fd), p + fd * 0.01),
			rng.randf_range(0.14, 0.16), 0.06, 0.5, rng.randf() * TAU)
	_add(parts, st_petal, "flower_gold")
	_add(parts, st_eye, "flower_pink")
	return parts


## Covers foliage masses ([centre, radii] pairs, axis-aligned) with `count`
## small ovate leaves, `lo`..`hi` long and `wk` as wide as long, their bases
## at `depth` of the way out to the mass's surface. Each leaf lies out over
## the surface, pointing outward and down the slope with some scatter, its
## face turned a little to the sky. Nothing reaches past `limit` from the
## plant's axis.
static func _foliage_skin(st: SurfaceTool, rng: RandomNumberGenerator, masses: Array, count: int,
		lo: float, hi: float, wk: float, limit: float, depth: float) -> void:
	var made := 0
	var tries := 0
	while made < count and tries < count * 12:
		tries += 1
		var m: Array = masses[0 if rng.randf() < 0.45 else rng.randi_range(1, masses.size() - 1)]
		var c: Vector3 = m[0]
		var r: Vector3 = m[1]
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 1.0), rng.randf_range(-1.0, 1.0))
		if d.length_squared() > 1.0 or d.length_squared() < 0.04:
			continue
		d = d.normalized()
		var p := c + d * r * depth
		if p.y < 0.1:
			continue
		var ns := Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized()
		var downhill := ns * ns.y - Vector3.UP
		var rnd := ns.cross(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0))).normalized()
		var dir := (ns * 0.45 + downhill * 0.6 + rnd * 0.5).normalized()
		var ll := rng.randf_range(lo, hi)
		var base := p - ns * 0.04
		var tipp := base + dir * ll
		if Vector2(tipp.x, tipp.z).length() > limit or tipp.y < 0.03:
			continue
		_leaf4(st, base, dir, ns + Vector3.UP * 0.35, ll, ll * wk * rng.randf_range(0.9, 1.1), ll * 0.16)
		made += 1


## A small ovate leaf in four triangles: a hexagon inscribed in an ellipse
## (sides nearly parallel through the middle, so no hard shoulder), pointed
## at both ends, folded along the midrib, the tip dropping `droop` metres
## away from the upper face. Its normals roll off toward the margin, so it
## shades as a soft convex leaf rather than a flat shard.
static func _leaf4(st: SurfaceTool, base: Vector3, dir: Vector3, face_hint: Vector3,
		length: float, wid: float, droop: float) -> void:
	var d := dir.normalized()
	var face := (face_hint - d * face_hint.dot(d)).normalized()
	var side := face.cross(d).normalized()
	var lift := face * wid * 0.12
	var tip := base + d * length - face * droop
	var l1 := base + d * length * 0.26 + side * wid * 0.47 + lift - face * droop * 0.08
	var r1 := base + d * length * 0.26 - side * wid * 0.47 + lift - face * droop * 0.08
	var l2 := base + d * length * 0.64 + side * wid * 0.43 + lift - face * droop * 0.42
	var r2 := base + d * length * 0.64 - side * wid * 0.43 + lift - face * droop * 0.42
	var nmid := _up_normal(base, l2, r2, face)
	var nbase := (nmid + face).normalized()
	var ntip := (nmid * 1.4 + d * 0.5).normalized()
	var nl1 := (nmid + side * 0.55).normalized()
	var nl2 := (nmid + side * 0.5 + d * 0.2).normalized()
	var nr1 := (nmid - side * 0.55).normalized()
	var nr2 := (nmid - side * 0.5 + d * 0.2).normalized()
	_tri(st, base, l1, l2, nbase, nl1, nl2)
	_tri(st, base, l2, tip, nbase, nl2, ntip)
	_tri(st, base, tip, r2, nbase, ntip, nr2)
	_tri(st, base, r2, r1, nbase, nr2, nr1)


## The normal of triangle a-b-c, on the side `face` looks from.
static func _up_normal(a: Vector3, b: Vector3, c: Vector3, face: Vector3) -> Vector3:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return face
	n = n.normalized()
	return -n if n.dot(face) < 0.0 else n


## A hibiscus flower facing local +Z, centred on the origin: a shallow
## trumpet of five broad, lopsided petals (four rim points each, so they
## overlap in a pinwheel) with deep notches between them; a five-rayed red
## eye in the throat; and the staminal column standing out of the middle.
static func _bloom(st_petal: SurfaceTool, st_eye: SurfaceTool, xf: Transform3D, radius: float,
		depth: float, notch: float, phase: float) -> void:
	var shape: Array = [notch, 0.9, 1.0, 0.88]
	var at: Array = [0.0, 0.3, 0.56, 0.8]
	var ctr := xf * Vector3(0.0, 0.0, -depth)
	var row: Array = []
	for p in 5:
		for q in 4:
			var ph := phase + TAU * (float(p) + float(at[q])) / 5.0
			var r := radius * float(shape[q])
			var z := -depth * 0.12 if q == 0 else depth * 0.2
			row.append(xf * Vector3(cos(ph) * r, sin(ph) * r, z))
	var P: Array = [[ctr], row]
	var N := _polar_normals(P, xf.basis.z.normalized(), Vector3.ZERO, false)
	_emit_polar(st_petal, P, N, 0, 1, true, 0.0015)
	# The eye: a star whose rays run up the middle of each petal.
	var face := xf.basis.z.normalized()
	var eye: Array = []
	for k in 10:
		var ray := k % 2 == 1
		var ph := phase + TAU * (floorf(float(k) * 0.5) + (0.53 if ray else 0.0)) / 5.0
		var r := radius * (0.42 if ray else 0.17)
		var z := -depth * (1.0 - r / radius) + 0.004
		eye.append(xf * Vector3(cos(ph) * r, sin(ph) * r, z))
	var ec := ctr + face * 0.004
	for k in 10:
		_tri(st_eye, ec, eye[k], eye[(k + 1) % 10], face, face, face)
	# The staminal column, curving out and up.
	var up := (xf.basis.y - face * xf.basis.y.dot(face)).normalized()
	var col_tip := ctr + face * radius * 0.95 + up * radius * 0.2
	var sw := xf.basis.x.normalized() * 0.006
	_tri2(st_eye, ctr - sw, ctr + sw, col_tip, up, up, up, 0.0005)


## A five-petalled flower facing local +Z, centred on the origin: a shallow
## trumpet whose rim is five petals. `per` points per petal; `notch` is the
## radius between petals (0.3 a starry orchid). With two rings the throat is
## drawn into `st_eye`.
static func _corolla(st_petal: SurfaceTool, st_eye: SurfaceTool, xf: Transform3D, radius: float,
		depth: float, notch: float, phase: float, per: int, rings: int) -> void:
	var segs := 5 * per
	var shape: Array = [notch, 1.0, 0.97] if per == 3 else [notch, 1.0]
	var fr: Array = [0.0, 0.36, 1.0] if rings == 2 else [0.0, 1.0]
	var fz: Array = [-depth, -depth * 0.3, 0.0] if rings == 2 else [-depth, 0.0]
	var last := fr.size() - 1
	var P: Array = []
	for j in fr.size():
		var row: Array = []
		for i in (1 if j == 0 else segs):
			var ph := phase + TAU * float(i) / float(segs)
			var k: float = shape[i % per] if j == last else 1.0
			var r := radius * float(fr[j]) * k
			var z: float = fz[j]
			if j == last and i % per != 0:
				z += depth * 0.15
			row.append(xf * Vector3(cos(ph) * r, sin(ph) * r, z))
		P.append(row)
	var N := _polar_normals(P, xf.basis.z.normalized(), Vector3.ZERO, false)
	if rings == 2:
		_emit_polar(st_eye, P, N, 0, 1, true, 0.0015)
		_emit_polar(st_petal, P, N, 1, 2, true, 0.0015)
	else:
		_emit_polar(st_petal, P, N, 0, 1, true, 0.0015)


# =============================================================================
#  ROCKS
# =============================================================================

## A broad boulder sunk into the ground, a few of its faces fractured flat,
## with moss grown over the damp side of its crown — a patchy sheet thinning
## to nothing at its edge, and soft cushions on it — and a small stone at
## its foot.
static func _boulder(index: int) -> Array:
	var rng := _rng(index, 83)
	var parts: Array = []
	var nz := _noise(index)
	var st_rock := _begin()
	var st_moss := _begin()
	var yaw := rng.randf() * TAU
	var rot := _tilt(rng, yaw, 0.1)
	var radii := Vector3(1.12, 0.64, 0.84)
	var centre := Vector3(0.0, 0.1, 0.0)
	var cuts := _cuts(rng, radii, 5)
	_rock_body(st_rock, centre, radii, rot, nz, cuts, 24, 7, deg_to_rad(112.0))
	var damp := rng.randf() * TAU
	var axis := Vector3(sin(0.5) * cos(damp), cos(0.5), sin(0.5) * sin(damp))
	var th0 := deg_to_rad(rng.randf_range(38.0, 46.0))
	_moss_patch(st_moss, centre, radii, rot, nz, cuts, axis, th0, 32, 3, 0.045)
	_cushions(st_moss, rng, centre, radii, rot, nz, cuts, axis, th0, 2, 0.05)
	# The small stone, tucked against the boulder's narrow side.
	var pr := Vector3(0.3, 0.21, 0.26)
	var side := rot * Vector3(0.0, 0.0, 1.0 if rng.randf() < 0.5 else -1.0)
	var pa := atan2(side.z, side.x) + rng.randf_range(-0.4, 0.4)
	var pc := Vector3(cos(pa), 0.0, sin(pa)) * 0.84 + Vector3(0.0, 0.03, 0.0)
	_rock_body(st_rock, pc, pr, _tilt(rng, rng.randf() * TAU, 0.15), _noise(index + 17),
		_cuts(rng, pr, 2), 10, 3, deg_to_rad(110.0))
	_add(parts, st_rock, "stone_dark")
	_add(parts, st_moss, "moss")
	return _fit(parts, 1.19)


## Two weathered stones leaning together, the big one moss-grown on its
## damp side, the small one with just a patch. (No cushions: on the pair's
## rounder crown they read as dents.)
static func _stone_pair(index: int) -> Array:
	var rng := _rng(index, 89)
	var parts: Array = []
	var st_rock := _begin()
	var st_moss := _begin()
	var yaw := rng.randf() * TAU
	var dir := Vector3(cos(yaw), 0.0, sin(yaw))
	var specs: Array = [
		[-dir * 0.3 + Vector3(0.0, 0.08, 0.0), Vector3(0.84, 0.58, 0.6), 22, 6, 12, 28, 0.05, 0, 1.0],
		[dir * 0.64 + Vector3(0.0, 0.02, 0.0), Vector3(0.46, 0.4, 0.42), 14, 5, 14, 14, 0.03, 0, 0.62],
	]
	for s: Array in specs:
		var c: Vector3 = s[0]
		var r: Vector3 = s[1]
		var nz := _noise(index + int(s[4]))
		var cuts := _cuts(rng, r, 3)
		var rot := _tilt(rng, yaw + rng.randf_range(-0.3, 0.3), 0.14)
		_rock_body(st_rock, c, r, rot, nz, cuts, int(s[2]), int(s[3]), deg_to_rad(112.0))
		var damp := rng.randf() * TAU
		var axis := Vector3(sin(0.45) * cos(damp), cos(0.45), sin(0.45) * sin(damp))
		var th0 := deg_to_rad(rng.randf_range(42.0, 50.0)) * float(s[8])
		var mseg: int = s[5]
		_moss_patch(st_moss, c, r, rot, nz, cuts, axis, th0, mseg, 3 if mseg > 16 else 2, float(s[6]))
		_cushions(st_moss, rng, c, r, rot, nz, cuts, axis, th0, int(s[7]), float(s[6]) * 1.1)
	_add(parts, st_rock, "stone_dark")
	_add(parts, st_moss, "moss")
	return _fit(parts, 1.19)


## A yaw, then a small random tilt (up to `amount` radians), so a stone's
## flat crown is never parallel with the ground.
static func _tilt(rng: RandomNumberGenerator, yaw: float, amount: float) -> Basis:
	var ax := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
	if ax.length_squared() < 1e-4:
		ax = Vector3.RIGHT
	return Basis(ax.normalized(), rng.randf_range(0.3, 1.0) * amount) * Basis(Vector3.UP, yaw)


## A few flat facets for a boulder: planes that shave the rounded body, the
## way weathering and old fractures leave real stones.
static func _cuts(rng: RandomNumberGenerator, radii: Vector3, n: int) -> Array:
	var out: Array = []
	# A flattened crown, tilted a little.
	var top := Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)).normalized()
	out.append([top, radii.y * rng.randf_range(0.8, 0.88)])
	for i in n - 1:
		var a := rng.randf() * TAU
		var nrm := Vector3(cos(a), rng.randf_range(0.1, 0.5), sin(a)).normalized()
		var reach := Vector3(absf(nrm.x) * radii.x, absf(nrm.y) * radii.y, absf(nrm.z) * radii.z).length()
		out.append([nrm, reach * rng.randf_range(0.8, 0.88)])
	return out


## A point on a boulder in the unit direction `d` from its centre (its own
## frame): a squarish egg, lumped by noise and shaved by the facet planes.
static func _rock_fn(d: Vector3, radii: Vector3, nz: FastNoiseLite, cuts: Array) -> Vector3:
	var q := d.abs()
	var m := pow(pow(q.x, 2.2) + pow(q.y, 2.2) + pow(q.z, 2.2), 1.0 / 2.2)
	var p := d / maxf(m, 1e-4) * radii
	p *= 1.0 + 0.13 * nz.get_noise_3dv(d * 1.0) \
		+ 0.045 * nz.get_noise_3dv(d * 2.6 + Vector3(7.1, 3.3, 1.9)) \
		+ 0.012 * nz.get_noise_3dv(d * 7.0 + Vector3(1.7, 9.3, 4.1))
	for c: Array in cuts:
		var cn: Vector3 = c[0]
		var cd: float = c[1]
		p -= cn * _softplus(p.dot(cn) - cd, 0.025)
	return p


static func _rock_normal(d: Vector3, radii: Vector3, nz: FastNoiseLite, cuts: Array) -> Vector3:
	var t1 := d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.UP).normalized()
	var t2 := d.cross(t1).normalized()
	var e := 0.012
	var a := _rock_fn((d + t1 * e).normalized(), radii, nz, cuts) - _rock_fn((d - t1 * e).normalized(), radii, nz, cuts)
	var b := _rock_fn((d + t2 * e).normalized(), radii, nz, cuts) - _rock_fn((d - t2 * e).normalized(), radii, nz, cuts)
	var n := a.cross(b).normalized()
	if n.dot(d) < 0.0:
		n = -n
	return n


static func _rock_body(st: SurfaceTool, centre: Vector3, radii: Vector3, rot: Basis,
		nz: FastNoiseLite, cuts: Array, segs: int, rings: int, theta_max: float) -> void:
	var P: Array = []
	for j in rings + 1:
		var th := theta_max * pow(float(j) / float(rings), 0.92)
		var row: Array = []
		for i in (1 if j == 0 else segs):
			var ph := TAU * float(i) / float(segs)
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var p := centre + rot * _rock_fn(d, radii, nz, cuts)
			p.y = maxf(p.y, -0.24)
			row.append(p)
		P.append(row)
	var N := _polar_normals(P, Vector3.ZERO, centre, true)
	_emit_polar(st, P, N, 0, rings, false, 0.0)


## Two unit vectors square to `a` and to each other.
static func _perp(a: Vector3) -> Array:
	var e1 := a.cross(Vector3.FORWARD if absf(a.z) < 0.9 else Vector3.RIGHT).normalized()
	return [e1, a.cross(e1).normalized()]


## A sheet of moss grown over one side of a stone: a patch round `axis` (the
## stone's own frame) reaching `th0` from it, its edge wandering in slow
## lobes, `thick` metres deep in the middle and thinning to nothing at the
## edge, so it grows out of the stone instead of sitting on it like a lid.
static func _moss_patch(st: SurfaceTool, centre: Vector3, radii: Vector3, rot: Basis,
		nz: FastNoiseLite, cuts: Array, axis: Vector3, th0: float, segs: int, rings: int,
		thick: float) -> void:
	var a := axis.normalized()
	var e: Array = _perp(a)
	var e1: Vector3 = e[0]
	var e2: Vector3 = e[1]
	var P: Array = []
	for j in rings + 1:
		var f := float(j) / float(rings)
		var row: Array = []
		for i in (1 if j == 0 else segs):
			var ph := TAU * float(i) / float(segs)
			var q := Vector2(cos(ph), sin(ph))
			var edge := th0 * (1.0 + 0.34 * nz.get_noise_2d(q.x * 0.9 + 40.0, q.y * 0.9 - 12.0)
				+ 0.12 * nz.get_noise_2d(q.x * 2.2 - 20.0, q.y * 2.2 + 7.0))
			var th := edge * pow(f, 0.8)
			var d := (a * cos(th) + (e1 * q.x + e2 * q.y) * sin(th)).normalized()
			var p := _rock_fn(d, radii, nz, cuts)
			var n := _rock_normal(d, radii, nz, cuts)
			var t := thick * (1.0 - f * f) * (0.8 + 0.4 * nz.get_noise_3dv(d * 3.5 + Vector3(3.0, 1.0, 2.0))) \
				+ 0.008
			row.append(centre + rot * (p + n * t))
		P.append(row)
	var N := _polar_normals(P, Vector3.ZERO, centre, true)
	_emit_polar(st, P, N, 0, rings, false, 0.0)


## Soft cushions of moss on the patch: `n` low domes, draped over the stone
## so their edges sink into the moss sheet all round.
static func _cushions(st: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3, radii: Vector3,
		rot: Basis, nz: FastNoiseLite, cuts: Array, axis: Vector3, th0: float, n: int,
		moss_t: float) -> void:
	var a := axis.normalized()
	var e: Array = _perp(a)
	var e1: Vector3 = e[0]
	var e2: Vector3 = e[1]
	for k in n:
		var ph := rng.randf() * TAU
		var th := th0 * rng.randf_range(0.05, 0.45)
		var d0 := (a * cos(th) + (e1 * cos(ph) + e2 * sin(ph)) * sin(th)).normalized()
		var p0 := _rock_fn(d0, radii, nz, cuts)
		var n0 := _rock_normal(d0, radii, nz, cuts)
		var t: Array = _perp(n0)
		var t1: Vector3 = t[0]
		var t2: Vector3 = t[1]
		var rad := rng.randf_range(0.14, 0.2)
		var hgt := rng.randf_range(0.045, 0.065)
		var prof: Array = [Vector2(0.0, 1.0), Vector2(0.55, 0.8), Vector2(1.0, -0.45)]
		var P: Array = []
		for j in prof.size():
			var pr: Vector2 = prof[j]
			var row: Array = []
			for i in (1 if j == 0 else 10):
				var ang := TAU * float(i) / 10.0
				var wob := 1.0 + 0.18 * sin(ang * 3.0 + ph)
				var off := (t1 * cos(ang) + t2 * sin(ang)) * rad * pr.x * wob
				var dd := (p0 + off).normalized()
				var ps := _rock_fn(dd, radii, nz, cuts)
				var ns := _rock_normal(dd, radii, nz, cuts)
				row.append(centre + rot * (ps + ns * (moss_t + hgt * pr.y)))
			P.append(row)
		var N := _polar_normals(P, Vector3.ZERO, centre + rot * (p0 - n0 * rad), true)
		_emit_polar(st, P, N, 0, prof.size() - 1, false, 0.0)


# =============================================================================
#  BAMBOO PARTS
# =============================================================================

## A culm's centreline as 41 points by arc length: rising from `base`,
## leaning `lean` out toward `out`, then from `arch0` of the way up bowing
## over by `nod` more, so the tip nods.
static func _culm_line(base: Vector3, out: Vector3, length: float, lean: float, nod: float,
		arch0: float) -> Array:
	var pts: Array = [base]
	var p := base
	for k in 40:
		var u := (float(k) + 0.5) / 40.0
		var th := lean + nod * pow(smoothstep(arch0, 1.0, u), 1.3)
		p += (Vector3.UP * cos(th) + out * sin(th)) * length / 40.0
		pts.append(p)
	return pts


## True if everything of a culm below 4 m stays inside the clump's footprint.
static func _culm_fits(line: Array) -> bool:
	for p: Vector3 in line:
		if p.y < 4.0 and Vector2(p.x, p.z).length() > 1.04:
			return false
	return true


## How thick a culm is (x its base radius) a fraction `t` of the way up.
static func _culm_taper(t: float) -> float:
	return 1.0 - 0.2 * t - 0.45 * pow(t, 4.0)


## A bamboo node: a ridge round the culm — a 12-sided cone flaring out from
## inside the culm to 1.09 x its radius, so what shows is a 2 cm band that
## swells out of the culm and ends in a crisp step, lit from above like the
## sheath scar on a real culm. (A cone takes 12 triangles; a collar 24.)
static func _node_ridge(st: SurfaceTool, pos: Vector3, dir: Vector3, rad: float, ref: Vector3) -> void:
	var e1 := (ref - dir * ref.dot(dir)).normalized()
	var e2 := dir.cross(e1).normalized()
	var apex := pos + dir * 0.24
	var rr := rad * 1.09
	var ring: Array = []
	var nrm: Array = []
	for i in 12:
		var a := TAU * float(i) / 12.0
		var radial := e1 * cos(a) + e2 * sin(a)
		ring.append(pos + radial * rr)
		nrm.append((radial * 0.24 + dir * rr).normalized())
	for i in 12:
		var i2 := (i + 1) % 12
		var na: Vector3 = nrm[i]
		var nb: Vector3 = nrm[i2]
		_tri(st, apex, ring[i], ring[i2], (na + nb).normalized(), na, nb)


## Pulls a point in toward the plant's axis until it is within `lim` of it.
static func _pull_in(p: Vector3, lim: float) -> Vector3:
	var hr := Vector2(p.x, p.z)
	if hr.length() > lim:
		hr = hr.normalized() * lim
	return Vector3(hr.x, p.y, hr.y)


## A thin twig from `a` to `b`: one triangle, both faces, `w` wide at `a`,
## turned so it is seen from the side.
static func _sliver(st: SurfaceTool, a: Vector3, b: Vector3, w: float) -> void:
	var d := (b - a).normalized()
	var s := Vector3.UP - d * d.y
	if s.length_squared() < 1e-6:
		s = Vector3.RIGHT
	s = s.normalized() * (w * 0.5)
	var n := d.cross(s).normalized()
	n = (n + Vector3.UP * 0.8).normalized()
	_tri_facing(st, a - s, a + s, b, d.cross(s), n)
	_tri_facing(st, a - s, a + s, b, -d.cross(s), n)


## A narrow lance leaf (bamboo) as ONE triangle each side: at 10-60 m a
## triangle reads as a leaf, and that doubles the leaves the budget buys.
## Both faces are lit with the same sky-leaning normal, so a leaf seen from
## below is as bright as one seen from above (bamboo_leaf is a plain
## material, with no translucency to light its underside).
static func _lance1(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, wid: float,
		roll: float) -> void:
	var d := dir.normalized()
	var face := Vector3.UP - d * d.y
	if face.length_squared() < 1e-6:
		face = Vector3.RIGHT
	face = face.normalized().rotated(d, roll)
	var side := face.cross(d).normalized()
	var b0 := base + d * 0.02
	var tip := base + d * length - face * (length * 0.08)
	var l := b0 + side * (wid * 0.5) + d * (length * 0.08)
	var r := b0 - side * (wid * 0.5) + d * (length * 0.08)
	var n := (l - tip).cross(r - tip).normalized()
	if n.y < 0.0:
		n = -n
	n = (n + Vector3.UP * 0.3).normalized()
	_tri_facing(st, l, tip, r, face, n)
	_tri_facing(st, l, tip, r, -face, n)


# =============================================================================
#  SHEETS AND LEAVES
# =============================================================================

## A strap or paddle leaf rising from `base` at `e0` above the horizontal
## toward `h` and bending over to `e1` at the tip. `ws` is the half-width at
## each station `us` (0..1 along it); the cross-section is folded along the
## midrib by `fold` (edges lifted toward the upper face), and the blade
## twists by `twist` radians base to tip. Single-sided: foliage materials only.
static func _arch_sheet(st: SurfaceTool, base: Vector3, h: Vector3, length: float, e0: float,
		e1: float, twist: float, fold: float, us: Array, ws: Array) -> void:
	var side0 := Vector3.UP.cross(h).normalized()
	var g: Array = []
	var hints: Array = []
	var p := base
	var u_prev := 0.0
	for k in us.size():
		var u: float = us[k]
		if k > 0:
			for s in 3:
				var um := lerpf(u_prev, u, (float(s) + 0.5) / 3.0)
				var thm := lerpf(e0, e1, pow(um, 1.5))
				p += (h * cos(thm) + Vector3.UP * sin(thm)) * (u - u_prev) * length / 3.0
		var th := lerpf(e0, e1, pow(u, 1.5))
		var t := h * cos(th) + Vector3.UP * sin(th)
		var side := side0.rotated(t, twist * u)
		var nrm := t.cross(side).normalized()
		var w: float = ws[k]
		g.append([p + side * w + nrm * w * fold, p, p - side * w + nrm * w * fold])
		hints.append(nrm)
		u_prev = u
	_emit_grid(st, g, _grid_normals(g, hints), false, 0.0)


## Where the tip of an _arch_sheet ends up, relative to its base.
static func _arch_tip(h: Vector3, length: float, e0: float, e1: float) -> Vector3:
	var p := Vector3.ZERO
	for k in 8:
		var th := lerpf(e0, e1, pow((float(k) + 0.5) / 8.0, 1.5))
		p += (h * cos(th) + Vector3.UP * sin(th)) * length / 8.0
	return p


# =============================================================================
#  MESH HELPERS
# =============================================================================

static func _rng(index: int, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = salt * 1000003 + index * 7919 + 424242
	return r


static func _noise(seed_value: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = 5077 + seed_value * 131
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n


static func _softplus(e: float, k: float) -> float:
	if e / k > 20.0:
		return e
	return k * log(1.0 + exp(e / k))


static func _bez3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


## A basis whose +Y points along `y_dir` and whose +Z leans toward `z_hint`.
static func _frame(y_dir: Vector3, z_hint: Vector3) -> Basis:
	var y := y_dir.normalized()
	var z := z_hint - y * z_hint.dot(y)
	if z.length_squared() < 1e-8:
		z = Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT
		z = z - y * z.dot(y)
	z = z.normalized()
	return Basis(y.cross(z), y, z)


## A basis whose +Z points along `z_dir` (a flower's face).
static func _frame_z(z_dir: Vector3) -> Basis:
	var z := z_dir.normalized()
	var ref := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## Position, direction and radius a fraction `t` of the way up a polyline
## tube (the same straight spans SM.tube draws).
static func _along(pts: Array, rads: Array, ts: Array, t: float) -> Array:
	var k := 0
	while k < ts.size() - 2 and t > float(ts[k + 1]):
		k += 1
	var f := clampf((t - float(ts[k])) / (float(ts[k + 1]) - float(ts[k])), 0.0, 1.0)
	var a: Vector3 = pts[k]
	var b: Vector3 = pts[k + 1]
	return [a.lerp(b, f), (b - a).normalized(), lerpf(float(rads[k]), float(rads[k + 1]), f)]


## If the plant reaches further than `limit` from its axis anywhere below
## 4 m, shrinks the whole of it (uniformly, so every normal still holds)
## until it does not.
static func _fit(parts: Array, limit: float) -> Array:
	var reach := 0.0
	for p: Dictionary in parts:
		var mesh: Mesh = p["mesh"]
		var xf: Transform3D = p["xform"]
		var vs: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in vs:
			var w := xf * v
			if w.y < 4.0:
				reach = maxf(reach, Vector2(w.x, w.z).length())
	if reach <= limit:
		return parts
	var k := limit / reach
	var sx := Transform3D(Basis().scaled(Vector3(k, k, k)), Vector3.ZERO)
	for p: Dictionary in parts:
		p["xform"] = sx * (p["xform"] as Transform3D)
	return parts


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Commits a SurfaceTool into a part, if anything was drawn into it.
static func _add(parts: Array, st: SurfaceTool, mat_name: String) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() > 0 and mesh.surface_get_array_len(0) > 0:
		parts.append(FK.part(mesh, Transform3D(), mat_name))


static func _vtx(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(p)


## One triangle, wound CLOCKWISE as seen from the side its normals face
## (Godot's front face), whatever order its corners come in. Slivers of no
## area are dropped: they cost a triangle and draw nothing.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-12:
		return
	if face.dot(na + nb + nc) > 0.0:
		_vtx(st, a, na)
		_vtx(st, c, nc)
		_vtx(st, b, nb)
	else:
		_vtx(st, a, na)
		_vtx(st, b, nb)
		_vtx(st, c, nc)


## One triangle, front face toward `facing`, every corner lit with normal `n`
## (which may point anywhere: for a leaf lit the same from both sides).
static func _tri_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, facing: Vector3,
		n: Vector3) -> void:
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-12:
		return
	if face.dot(facing) > 0.0:
		_vtx(st, a, n)
		_vtx(st, c, n)
		_vtx(st, b, n)
	else:
		_vtx(st, a, n)
		_vtx(st, b, n)
		_vtx(st, c, n)


## Both faces of a triangle, pushed `off` apart along the normals.
static func _tri2(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, off: float) -> void:
	_tri(st, a + na * off, b + nb * off, c + nc * off, na, nb, nc)
	_tri(st, a - na * off, b - nb * off, c - nc * off, -na, -nb, -nc)


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, two_sided: bool, off: float) -> void:
	if two_sided:
		_tri2(st, a, b, c, na, nb, nc, off)
	else:
		_tri(st, a, b, c, na, nb, nc)


## Normals for a grid (rows of points), from the surface itself, each row
## turned toward its hint.
static func _grid_normals(g: Array, hints: Array) -> Array:
	var rows := g.size()
	var out: Array = []
	for r in rows:
		var row: Array = g[r]
		var up_row: Array = g[mini(r + 1, rows - 1)]
		var dn_row: Array = g[maxi(r - 1, 0)]
		var hint: Vector3 = hints[r]
		var cols := row.size()
		var nrow: Array = []
		for c in cols:
			var a: Vector3 = (up_row[c] as Vector3) - (dn_row[c] as Vector3)
			var b: Vector3 = (row[mini(c + 1, cols - 1)] as Vector3) - (row[maxi(c - 1, 0)] as Vector3)
			var n := b.cross(a)
			if n.length_squared() < 1e-14:
				n = hint
			n = n.normalized()
			if n.dot(hint) < 0.0:
				n = -n
			nrow.append(n)
		out.append(nrow)
	return out


static func _emit_grid(st: SurfaceTool, g: Array, nm: Array, two_sided: bool, off: float) -> void:
	for r in g.size() - 1:
		var r0: Array = g[r]
		var r1: Array = g[r + 1]
		var n0: Array = nm[r]
		var n1: Array = nm[r + 1]
		for c in r0.size() - 1:
			_face(st, r0[c], r1[c], r1[c + 1], n0[c], n1[c], n1[c + 1], two_sided, off)
			_face(st, r0[c], r1[c + 1], r0[c + 1], n0[c], n1[c + 1], n0[c + 1], two_sided, off)


## Normals for a polar grid: P[0] = [centre], P[j] = a closed ring. Oriented
## toward `hint`, or (radial) away from `origin`.
static func _polar_normals(P: Array, hint: Vector3, origin: Vector3, radial: bool) -> Array:
	var rings := P.size()
	var segs := (P[1] as Array).size()
	var centre: Vector3 = (P[0] as Array)[0]
	var N: Array = [[]]
	var csum := Vector3.ZERO
	for j in range(1, rings):
		var row: Array = P[j]
		var nrow: Array = []
		for i in segs:
			var a: Vector3 = (row[(i + 1) % segs] as Vector3) - (row[(i + segs - 1) % segs] as Vector3)
			var outer: Vector3 = (P[j + 1] as Array)[i] if j + 1 < rings else row[i]
			var inner: Vector3 = centre if j == 1 else (P[j - 1] as Array)[i]
			var n := a.cross(outer - inner)
			var ref := ((row[i] as Vector3) - origin) if radial else hint
			if n.length_squared() < 1e-14:
				n = ref
			n = n.normalized()
			if n.dot(ref) < 0.0:
				n = -n
			nrow.append(n)
			if j == 1:
				csum += n
		N.append(nrow)
	var cref := (centre - origin) if radial else hint
	N[0] = [csum.normalized() if csum.length_squared() > 1e-10 else cref.normalized()]
	return N


## Emits the rings j0..j1 of a polar grid (j0 = 0 includes the centre fan).
static func _emit_polar(st: SurfaceTool, P: Array, N: Array, j0: int, j1: int,
		two_sided: bool, off: float) -> void:
	var segs := (P[1] as Array).size()
	var c: Vector3 = (P[0] as Array)[0]
	var cn: Vector3 = (N[0] as Array)[0]
	for j in range(j0, j1):
		for i in segs:
			var i2 := (i + 1) % segs
			if j == 0:
				var r1: Array = P[1]
				var n1: Array = N[1]
				_face(st, c, r1[i], r1[i2], cn, n1[i], n1[i2], two_sided, off)
			else:
				var ra: Array = P[j]
				var rb: Array = P[j + 1]
				var na: Array = N[j]
				var nb: Array = N[j + 1]
				_face(st, ra[i], rb[i], rb[i2], na[i], nb[i], nb[i2], two_sided, off)
				_face(st, ra[i], rb[i2], ra[i2], na[i], nb[i2], na[i2], two_sided, off)


## Drops zero-area triangles (the poles of FK's clumps) from a flat mesh.
static func _clean(mesh: ArrayMesh) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var st := _begin()
	for i in range(0, vs.size() - 2, 3):
		if (vs[i + 1] - vs[i]).cross(vs[i + 2] - vs[i]).length_squared() < 1e-12:
			continue
		for k in 3:
			_vtx(st, vs[i + k], ns[i + k])
	return st.commit()


## SMALL_SWEEP=<n>: builds indices 0..n-1 of every builder (twice, to check
## each index grows the same plant) and prints the worst case of each.
static func _sweep(n: int) -> void:
	for kind: String in ["undergrowth", "bamboo", "flower_patch", "rock"]:
		var worst := [0, 0.0, 10.0, 0, 0.0, 0.0, 0.0]   # tris, reach, min y, mats, max y, min w, max w
		worst[5] = 99.0
		var same := true
		for i in n:
			var sig: Array = []
			for rep_k in 2:
				var ps: Array = []
				match kind:
					"undergrowth":
						ps = undergrowth(i)
					"bamboo":
						ps = bamboo(i)
					"flower_patch":
						ps = flower_patch(i)
					_:
						ps = rock(i)
				var tris := 0
				var mats := {}
				var reach := 0.0
				var lo := Vector3(INF, INF, INF)
				var hi := Vector3(-INF, -INF, -INF)
				var sum := 0.0
				for p: Dictionary in ps:
					mats[p["mat"]] = true
					var xf: Transform3D = p["xform"]
					var vs: PackedVector3Array = (p["mesh"] as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					tris += int(vs.size() / 3.0)
					for v: Vector3 in vs:
						var w := xf * v
						lo = lo.min(w)
						hi = hi.max(w)
						sum += w.x * 1.3 + w.y * 0.7 + w.z
						if w.y < 4.0:
							reach = maxf(reach, Vector2(w.x, w.z).length())
				sig.append(sum)
				if rep_k == 0:
					var wid := maxf(hi.x - lo.x, hi.z - lo.z)
					worst[0] = maxi(int(worst[0]), tris)
					worst[1] = maxf(float(worst[1]), reach)
					worst[2] = minf(float(worst[2]), lo.y)
					worst[3] = maxi(int(worst[3]), mats.size())
					worst[4] = maxf(float(worst[4]), hi.y)
					worst[5] = minf(float(worst[5]), wid)
					worst[6] = maxf(float(worst[6]), wid)
			if absf(float(sig[0]) - float(sig[1])) > 1e-3:
				same = false
		print("SWEEP %-13s x%d  max tris %d  max mats %d  max reach<4m %.2f  min y %.2f  max y %.2f  width %.2f..%.2f  deterministic %s" % [
			kind, n, worst[0], worst[3], worst[1], worst[2], worst[4], worst[5], worst[6], str(same)])


## Prints a builder's triangle count, materials, size, and how far it
## reaches from its origin below 4 m; returns the triangle count.
static func _stats(label: String, parts: Array) -> int:
	var tris := 0
	var mats := {}
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var reach := 0.0
	var sum := 0.0
	for p: Dictionary in parts:
		var mesh: Mesh = p["mesh"]
		var xf: Transform3D = p["xform"]
		mats[p["mat"]] = true
		var arr := mesh.surface_get_arrays(int(p.get("surface", 0)))
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		tris += int(vs.size() / 3.0)
		for v: Vector3 in vs:
			var w := xf * v
			lo = lo.min(w)
			hi = hi.max(w)
			sum += w.x * 1.3 + w.y * 0.7 + w.z
			if w.y < 4.0:
				reach = maxf(reach, Vector2(w.x, w.z).length())
	print("SMALL %-16s tris=%5d mats=%d %s  size %.2f x %.2f x %.2f  reach<4m %.2f  y %.2f..%.2f  sum %.4f" % [
		label, tris, mats.size(), str(mats.keys()), hi.x - lo.x, hi.z - lo.z, hi.y - lo.y,
		reach, lo.y, hi.y, sum])
	return tris
