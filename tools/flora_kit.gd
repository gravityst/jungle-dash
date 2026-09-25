extends RefCounted
## FLORA KIT — smooth building blocks for the jungle, the scenery's version of
## smooth_mesh.gd. The old jungle was built from 6-sided cylinders and 6 x 2
## "spheres" (which are really hexagonal diamonds), lit with a hard toon step:
## every leaf mass was a gem and every trunk a pencil. These replace them.
##
##   clump(radii, seed)          a soft mass of foliage: an egg with lumps
##                               pressed into it, shaded like leaves not rock
##   boulder(radii, seed)        the same idea, crisper, with a flat bottom
##   blade(width, length)        a broad tropical leaf: pointed, folded, drooping
##   strap(width, length)        a long narrow leaf: palm leaflet, grass, bamboo
##   trunk(points, radii)        a smooth tapering tube (SM.tube)
##   part(mesh, xform, mat)      one entry for build_scenes' merge lists
##
## Every shape is built at its REAL size with its real normals, so place them
## with rotation and position only. A non-uniform scale in the transform bends
## the surface but not the normals, and the light lands in the wrong place.
##
## Used as:  const FK := preload("res://tools/flora_kit.gd")

const SM := preload("res://tools/smooth_mesh.gd")

static var _noises := {}


## A merge-list entry, the same shape build_scenes.gd's _part() makes:
## {"mesh", "xform", "mat" (a material name in res://materials/), "surface"}.
static func part(mesh: Mesh, xform: Transform3D, mat_name: String) -> Dictionary:
	return {"mesh": mesh, "xform": xform, "mat": mat_name, "surface": 0}


## A soft clump of foliage with semi-axes `radii`. Lumps are pressed INWARD
## only (up to `lump` of the radius), so a clump never pokes out past the
## ellipsoid it replaces — safe to drop in wherever a blob used to be.
## `softness` blends the lumpy surface's normals toward the round egg's: 0
## shades every lump like a rock, 1 shades the whole thing as one smooth egg.
## About 0.5 reads as a mass of leaves.
static func clump(radii: Vector3, seed_value: int = 0, lump: float = 0.16,
		softness: float = 0.5, seg: int = 18, rings: int = 10) -> ArrayMesh:
	return _lumpy(radii, seed_value, lump, softness, seg, rings, 1.35, 1.0)


## A boulder: a crisper, lumpier clump whose underside is sliced flat so it
## sits on the ground instead of balancing on a point. `sink` is how much of
## the lower half is cut away (0 = none, 1 = sliced at the middle).
static func boulder(radii: Vector3, seed_value: int = 0, lump: float = 0.22,
		sink: float = 0.55) -> ArrayMesh:
	return _lumpy(radii, seed_value, lump, 0.22, 20, 12, 1.1, sink)


## A broad tropical leaf (elephant-ear / philodendron). The base is at the
## origin and the blade runs up local +Y for `length`; it is `width` across
## at its widest (local X). Its upper face looks down local +Z, the midrib is
## folded so the edges lift toward that face, and the tip droops away from it
## by `droop` metres. Both faces are built, so it reads from either side.
static func blade(width: float, length: float, droop: float = 0.18,
		fold: float = 0.10, cols: int = 6, rows: int = 8) -> ArrayMesh:
	return _leaf(width, length, droop, fold, cols, rows, 0.78, 0.85)


## A long narrow leaf: a palm leaflet, a grass blade, a bamboo leaf. Same
## frame as blade(); narrower shoulders and a longer taper to the tip.
static func strap(width: float, length: float, droop: float = 0.25,
		fold: float = 0.05, rows: int = 8) -> ArrayMesh:
	return _leaf(width, length, droop, fold, 2, rows, 0.45, 1.3)


## A box of full size `size` whose edges and corners are rounded off with
## radius `r` — flat faces, soft edges, the way worn stone and sawn wood
## catch the light. Built as a sphere pulled apart into the eight corners,
## so every normal is exact: flat on the faces, cylindrical along the edges,
## spherical at the corners. `k` is the steps per quarter-round.
static func bevel_box(size: Vector3, r: float, k: int = 3) -> ArrayMesh:
	var half := size * 0.5
	r = minf(r, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3(r, r, r)
	# Longitudes: four quarters, each boundary angle present twice (once per
	# side) so the straight faces appear between the duplicates.
	var cols: Array = []     # [phi, sign_x, sign_z]
	for q in 4:
		for i in k + 1:
			var ph := (float(q) + float(i) / float(k)) * PI * 0.5
			var mid := (float(q) + 0.5) * PI * 0.5
			cols.append([ph, signf(cos(mid)), signf(sin(mid))])
	# ...and the first column again at the end, which closes the +X face.
	cols.append([TAU, 1.0, 1.0])
	var rows: Array = []     # [theta, sign_y]
	for h in 2:
		for i in k + 1:
			rows.append([(float(h) + float(i) / float(k)) * PI * 0.5, 1.0 if h == 0 else -1.0])
	var grid: Array = []
	# The top face: a row collapsed to its centre, fanning out to the corners.
	var top: Array = []
	for col: Array in cols:
		top.append([Vector3(0.0, half.y, 0.0), Vector3.UP])
	grid.append(top)
	for row: Array in rows:
		var th: float = row[0]
		var line: Array = []
		for col: Array in cols:
			var ph: float = col[0]
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var off := Vector3(float(col[1]) * inner.x, float(row[1]) * inner.y,
				float(col[2]) * inner.z)
			line.append([off + d * r, d])
		grid.append(line)
	var bottom: Array = []
	for col: Array in cols:
		bottom.append([Vector3(0.0, -half.y, 0.0), Vector3.DOWN])
	grid.append(bottom)
	var nseg := cols.size() - 1
	var nring := grid.size() - 1
	return SM._param_surface(nseg, nring, func(u: float, v: float) -> Array:
		return grid[roundi(v * float(nring))][roundi(u * float(nseg))])


## A smooth tapering trunk, limb or stalk through `points`.
static func trunk(points: Array, radii: Array, sides: int = 12) -> ArrayMesh:
	return SM.tube(points, radii, sides, true)


## Smooths a polyline (and its radii) with a Catmull-Rom spline, `per` samples
## per span, so a trunk built from straight segments bends instead of kinking
## at every joint. Returns [points, radii]. Passes through every input point.
static func spline(points: Array, radii: Array, per: int = 3) -> Array:
	var n := points.size()
	if n < 3:
		return [points, radii]
	var out_p: Array = []
	var out_r: Array = []
	for i in n - 1:
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / float(per)
			out_p.append(p1.cubic_interpolate(p2, p0, p3, t))
			out_r.append(lerpf(float(radii[i]), float(radii[i + 1]), t))
	out_p.append(points[n - 1])
	out_r.append(radii[n - 1])
	return [out_p, out_r]


## A rotation that turns local +Y to point along `dir`, spun `roll` radians
## about it. For standing blades and trunk segments along a direction.
static func aim_y(dir: Vector3, roll: float = 0.0) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z) * Basis(Vector3.UP, roll)


# -----------------------------------------------------------------------------

static func _noise(seed_value: int) -> FastNoiseLite:
	var key := seed_value % 64
	if not _noises.has(key):
		var n := FastNoiseLite.new()
		n.seed = 9001 + key * 131
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 1.0
		n.fractal_octaves = 2
		n.fractal_gain = 0.45
		_noises[key] = n
	return _noises[key]


static func _lumpy(radii: Vector3, seed_value: int, lump: float, softness: float,
		seg: int, rings: int, freq: float, sink: float) -> ArrayMesh:
	var noise := _noise(seed_value)
	var off := Vector3(float(seed_value % 17) * 3.1, float(seed_value % 29) * 1.7, 0.0)
	var floor_y := -radii.y * (1.0 - sink) if sink < 1.0 else -radii.y
	# Positions first, on the same (u, v) grid SM uses, so its winding holds.
	var pos: Array = []
	var dirs: Array = []
	for j in rings + 1:
		var prow: Array = []
		var drow: Array = []
		var th := float(j) / float(rings) * PI
		for i in seg + 1:
			var ph := float(i % seg) / float(seg) * TAU
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var n := noise.get_noise_3dv(d * freq + off)          # about -1..1
			var k := 1.0 - lump * clampf(0.5 + 0.8 * n, 0.0, 1.0)
			var p := d * radii * k
			if sink < 1.0 and p.y < floor_y:
				p.y = floor_y
			prow.append(p)
			drow.append(d)
		pos.append(prow)
		dirs.append(drow)
	# Normals from the real surface (central differences), blended toward the
	# plain ellipsoid's.
	var grid: Array = []
	for j in rings + 1:
		var row: Array = []
		for i in seg + 1:
			var d: Vector3 = dirs[j][i]
			var egg := Vector3(d.x / radii.x, d.y / radii.y, d.z / radii.z).normalized()
			var ip := (i + 1) % seg
			var im := (i - 1 + seg) % seg
			var du: Vector3 = pos[j][ip] - pos[j][im]
			var dv: Vector3 = pos[mini(j + 1, rings)][i] - pos[maxi(j - 1, 0)][i]
			var surf := dv.cross(du)
			if surf.length_squared() < 1e-12:
				surf = egg
			surf = surf.normalized()
			if surf.dot(egg) < 0.0:
				surf = -surf
			var p: Vector3 = pos[j][i]
			# The sliced floor is flat: point it straight down.
			if sink < 1.0 and p.y <= floor_y + 1e-4:
				surf = Vector3.DOWN
			row.append([p, surf.lerp(egg, softness).normalized()])
		grid.append(row)
	return SM._param_surface(seg, rings, func(u: float, v: float) -> Array:
		return grid[roundi(v * float(rings))][roundi(u * float(seg))])


## The leaf generator behind blade() and strap(). `shoulder` sets where the
## blade is widest (0..1 along it) through a power curve; `taper` sharpens
## the tip.
static func _leaf(width: float, length: float, droop: float, fold: float,
		cols: int, rows: int, shoulder: float, taper: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width * 0.5
	var thick := minf(0.008, width * 0.04)
	var grid: Array = []
	for r in rows + 1:
		var s := float(r) / float(rows)
		# Width profile: 0 at the base, widest near `shoulder`, 0 at the tip.
		var w := half * pow(sin(PI * pow(s, shoulder)), taper)
		var row: Array = []
		for c in cols + 1:
			var t := float(c) / float(cols) * 2.0 - 1.0       # -1 .. 1 across
			var x := t * w
			var y := s * length
			var z := -droop * s * s + fold * absf(t) * w / maxf(half, 1e-4)
			row.append(Vector3(x, y, z))
		grid.append(row)
	# Upper face (+Z side) and lower face, each with its own normals.
	for face in [1.0, -1.0]:
		for r in rows:
			for c in cols:
				var q: Array = [grid[r][c], grid[r + 1][c], grid[r + 1][c + 1], grid[r][c + 1]]
				var nq: Array = []
				for k in 4:
					nq.append(_leaf_normal(grid, rows, cols, r + (1 if k == 1 or k == 2 else 0),
						c + (1 if k >= 2 else 0)) * face)
				# Godot's front faces wind CLOCKWISE as seen from outside; seen
				# from +Z, q0 -> q1 -> q2 is clockwise.
				var order: Array = [0, 1, 2, 0, 2, 3] if face > 0.0 else [0, 2, 1, 0, 3, 2]
				for idx: int in order:
					st.set_normal(nq[idx])
					st.set_uv(Vector2(0.5, 0.5))
					var p: Vector3 = q[idx]
					st.add_vertex(p + nq[idx] * thick * 0.5)
	return st.commit()


static func _leaf_normal(grid: Array, rows: int, cols: int, r: int, c: int) -> Vector3:
	var a: Vector3 = grid[mini(r + 1, rows)][c] - grid[maxi(r - 1, 0)][c]
	var b: Vector3 = grid[r][mini(c + 1, cols)] - grid[r][maxi(c - 1, 0)]
	var n := b.cross(a)
	if n.length_squared() < 1e-12:
		return Vector3.BACK
	n = n.normalized()
	if n.z < 0.0:
		n = -n
	return n
