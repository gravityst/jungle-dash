extends RefCounted
const SM := preload("res://tools/smooth_mesh.gd")
## SNAPPER THE CROCODILE — a Nile crocodile in a "high walk", sculpted from
## smooth lofted surfaces instead of boxes.
##
## Every body part is a LOFT: a run of cross-sections (superellipses, so the
## back can be broad, the skull table flat and the belly flat) swept along the
## body, resampled by arc length so the surface is evenly (and, on top, densely)
## tessellated. Normals are taken from the finished surface (central
## differences), so squashes, bends and sculpted bumps all shade correctly.
## The eye turrets, the brows and the nasal disc are raised out of the skull
## surface itself, so they flow into the head with no seam.
## The skin is painted per vertex — olive back, dark crossbands, mottled flanks,
## cream belly, yellow mouth — so each moving part is ONE mesh; the teeth and
## the eyes have their own materials (ivory enamel, glossy eye).
## The armour (keeled osteoderms, nuchal plates, the double tail crest) is
## modelled plate by plate and merged into the same meshes.
## A cellular-noise normal map, projected triplanar, gives the hide its scales.
##
## Rig read by scripts/chaser.gd: Head, Head/Jaw, Tail0..Tail4, Leg0..Leg3.

const C_BACK := Color(0.30, 0.34, 0.20)
const C_BAND := Color(0.18, 0.22, 0.12)
const C_FLANK := Color(0.46, 0.44, 0.26)
const C_BELLY := Color(0.78, 0.74, 0.52)
const C_TOOTH := Color(0.86, 0.76, 0.52)
const C_TOOTH_ROOT := Color(0.70, 0.60, 0.38)
const C_GUM := Color(0.19, 0.16, 0.10)
const C_MOUTH := Color(0.86, 0.74, 0.42)
const C_TONGUE := Color(0.70, 0.55, 0.30)
const C_CREST_TIP := Color(0.44, 0.47, 0.30)
const C_EYE := Color(0.75, 0.72, 0.20)
const C_IRIS_RIM := Color(0.42, 0.38, 0.08)
const C_PUPIL := Color(0.02, 0.02, 0.015)
const C_CLAW := Color(0.17, 0.14, 0.10)
const C_NOSTRIL := Color(0.04, 0.035, 0.025)

# Loft tessellation is this much denser on the upper surface (seen from the
# chase camera, high behind) than underneath.
const TOP_DENSITY := 0.8

# Cross-section stations: [z, half-width, y-middle, top, bottom, px, pt, pb],
# in ascending z.
# px/pt/pb are superellipse powers for the sides, the top and the underside:
# 1 = round, lower = squarer (a flat belly, a flat skull table).

# The trunk and neck, in body space. The neck rises to meet the skull table.
const TRUNK := [
	[-0.70, 0.150, 0.258, 0.104, 0.110, 0.80, 0.80, 0.70],
	[-0.62, 0.166, 0.258, 0.110, 0.118, 0.80, 0.80, 0.68],
	[-0.50, 0.205, 0.258, 0.121, 0.136, 0.75, 0.75, 0.60],
	[-0.32, 0.256, 0.258, 0.140, 0.150, 0.72, 0.72, 0.55],
	[-0.12, 0.278, 0.258, 0.152, 0.154, 0.70, 0.72, 0.50],
	[0.10, 0.280, 0.256, 0.150, 0.152, 0.70, 0.72, 0.50],
	[0.30, 0.262, 0.252, 0.143, 0.144, 0.72, 0.72, 0.55],
	[0.44, 0.226, 0.244, 0.128, 0.124, 0.75, 0.74, 0.58],
	[0.52, 0.207, 0.240, 0.122, 0.115, 0.76, 0.73, 0.61],
	[0.60, 0.191, 0.236, 0.116, 0.108, 0.77, 0.72, 0.62],
]
const TRUNK_Z := [-0.80, 0.70, 0.08, 0.10]   # z0, z1, front cap, rear cap

# Skull and upper jaw, in Head space. The jaw line undulates gently in plan
# view — a hint of the rosette at the tip, the notch the big lower tooth sits
# in, the bulge over the long upper teeth. The table slopes down at the back
# into the neck.
const SKULL := [
	[-0.640, 0.064, -0.012, 0.046, 0.009, 0.70, 0.70, 0.35],
	[-0.600, 0.071, -0.012, 0.050, 0.009, 0.62, 0.70, 0.30],
	[-0.565, 0.070, -0.012, 0.050, 0.009, 0.60, 0.70, 0.30],
	[-0.530, 0.066, -0.012, 0.048, 0.009, 0.58, 0.70, 0.30],
	[-0.490, 0.072, -0.012, 0.048, 0.009, 0.55, 0.70, 0.30],
	[-0.430, 0.086, -0.012, 0.053, 0.009, 0.55, 0.66, 0.30],
	[-0.360, 0.100, -0.012, 0.059, 0.010, 0.55, 0.62, 0.30],
	[-0.290, 0.114, -0.012, 0.067, 0.011, 0.55, 0.56, 0.32],
	[-0.230, 0.128, -0.012, 0.078, 0.020, 0.56, 0.50, 0.42],
	[-0.170, 0.145, -0.012, 0.092, 0.052, 0.60, 0.46, 0.60],
	[-0.100, 0.160, -0.012, 0.098, 0.084, 0.68, 0.50, 0.72],
	[-0.030, 0.156, -0.010, 0.088, 0.100, 0.75, 0.58, 0.80],
]
const SKULL_Z := [-0.672, 0.07, 0.032, 0.13]

# Lower jaw, in Jaw space (hinge at the origin; Head z = Jaw z - 0.24): a V of
# bone as wide as the upper jaw, pale below, the mouth floor on top.
const JAW := [
	[-0.385, 0.065, -0.002, 0.006, 0.026, 0.65, 0.45, 0.70],
	[-0.335, 0.069, -0.002, 0.006, 0.028, 0.60, 0.40, 0.70],
	[-0.290, 0.066, -0.002, 0.006, 0.030, 0.58, 0.38, 0.70],
	[-0.250, 0.070, -0.002, 0.006, 0.032, 0.58, 0.35, 0.70],
	[-0.190, 0.084, -0.002, 0.006, 0.036, 0.58, 0.35, 0.70],
	[-0.120, 0.098, -0.002, 0.006, 0.043, 0.60, 0.35, 0.72],
	[-0.050, 0.112, -0.002, 0.006, 0.054, 0.60, 0.35, 0.75],
	[0.010, 0.123, -0.002, 0.006, 0.064, 0.60, 0.35, 0.75],
]
const JAW_Z := [-0.42, 0.09, 0.035, 0.08]
const JAW_DZ := 0.24   # Head z = Jaw z - JAW_DZ

# Teeth: [z in Head space, visible length, base radius]. Upper and lower
# alternate so they interlock; the 4th lower tooth is the big one, standing in
# the notch outside the upper jaw.
const UPPER_TEETH := [
	[-0.648, 0.010, 0.0052],
	[-0.624, 0.017, 0.0064],
	[-0.600, 0.015, 0.0062],
	[-0.577, 0.011, 0.0055],
	[-0.503, 0.014, 0.0060],
	[-0.480, 0.020, 0.0068],
	[-0.456, 0.026, 0.0078],
	[-0.430, 0.024, 0.0076],
	[-0.402, 0.018, 0.0067],
	[-0.375, 0.016, 0.0063],
	[-0.348, 0.014, 0.0059],
	[-0.322, 0.012, 0.0056],
	[-0.298, 0.010, 0.0052],
	[-0.276, 0.008, 0.0047],
]
const LOWER_TEETH := [
	[-0.636, 0.011, 0.0055],
	[-0.612, 0.014, 0.0060],
	[-0.589, 0.012, 0.0057],
	[-0.531, 0.030, 0.0084],
	[-0.491, 0.013, 0.0058],
	[-0.467, 0.014, 0.0060],
	[-0.442, 0.016, 0.0064],
	[-0.415, 0.017, 0.0065],
	[-0.388, 0.015, 0.0062],
	[-0.361, 0.013, 0.0059],
	[-0.335, 0.012, 0.0056],
	[-0.310, 0.010, 0.0052],
	[-0.287, 0.008, 0.0047],
]

# The eyeball, in Head space (x mirrored): sunk into the outer face of its
# turret so only the upper-outer third shows.
const EYE_C := Vector3(0.090, 0.092, -0.152)
const EYE_R := 0.018
const EYE_GAZE := Vector3(0.85, 0.45, -0.28)
# Half-angles of the almond-shaped opening between the lids, from the gaze.
const EYE_AH := 1.05
const EYE_AV := 0.55

const TAIL_LEN := 1.58
const TAIL_SEG := 0.32
# A gentle droop at each tail joint, so the tail sweeps down to the ground.
# (chaser.gd only writes rotation.y, which keeps this.)
const TAIL_DROOP := [0.05, 0.035, 0.035, 0.035, 0.03]

# The dorsal shield, per column: lateral fraction, half-width, half-length,
# height, keel.
const DORSAL := [
	[0.130, 0.035, 0.031, 0.010, 0.006],
	[0.390, 0.035, 0.031, 0.011, 0.010],
	[0.635, 0.031, 0.029, 0.011, 0.012],
	[0.850, 0.022, 0.023, 0.009, 0.006],
]


static func build(body: Node3D, owner: Node) -> void:
	var skin := _skin_mat()
	_build_trunk(body, owner, skin)
	_build_head(body, owner, skin, _eye_mat(), _tooth_mat())
	_build_tail(body, owner, skin)
	_build_legs(body, owner, skin)


# =============================================================================
#  MATERIALS
# =============================================================================

## Wet reptile hide: the characters' soft material, a touch glossier, painted
## by vertex colour, with a scale pattern in the normals.
static func _skin_mat() -> StandardMaterial3D:
	var m := SM.mat(Color(1.0, 1.0, 1.0), 0.52, 0.25, 0.16, 0.009)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.rim_tint = 0.85
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.045
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 4.0
	tex.noise = noise
	m.normal_enabled = true
	m.normal_texture = tex
	m.normal_scale = 0.5
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 2.0
	m.uv1_scale = Vector3(2.8, 2.8, 2.8)
	return m


static func _eye_mat() -> StandardMaterial3D:
	var m := SM.mat(Color(1.0, 1.0, 1.0), 0.28, 0.45, 0.0, 0.004)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


## Ivory enamel: no rim, no ink of its own, and a low sheen so the teeth never
## mirror the blue sky. It still writes the characters' stencil value, so the
## hide's ink outline (drawn after all opaque geometry) never paints over them.
static func _tooth_mat() -> StandardMaterial3D:
	var m := SM.mat(Color(1.0, 1.0, 1.0), 0.45, 0.15, 0.0, 0.0)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	m.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	m.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	m.stencil_reference = 1
	return m


# =============================================================================
#  TRUNK
# =============================================================================

static func _build_trunk(body: Node3D, owner: Node, skin: Material) -> void:
	var acc := _acc()
	var col := func(p: Vector3, n: Vector3) -> Color:
		return _skin_col(p, n, p.z, 0.26, 0.3)
	var nu := 96
	var nv := 120
	var pts := _loft_pts(TRUNK, TRUNK_Z, nu, nv)
	# Shoulder and hip muscle swelling the flanks where the limbs root in.
	for k in pts.size():
		var p := pts[k]
		var sw := 0.030 * _bump(p.z, -0.32, 0.10) * _bump(p.y, 0.215, 0.06) \
			+ 0.038 * _bump(p.z, 0.33, 0.11) * _bump(p.y, 0.22, 0.065)
		pts[k] = Vector3(p.x + signf(p.x) * sw, p.y, p.z)
	_emit(acc, pts, nu, nv, col)
	# Post-occipital pair, then the nuchal shield: four big plates in a square
	# and a small one either side.
	for s: float in [-1.0, 1.0]:
		_trunk_scute(acc, -0.535, 0.20 * s, 0.020, 0.018, 0.010, 0.006)
		_trunk_scute(acc, -0.455, 0.30 * s, 0.032, 0.031, 0.013, 0.009)
		_trunk_scute(acc, -0.385, 0.26 * s, 0.034, 0.031, 0.013, 0.009)
		_trunk_scute(acc, -0.420, 0.70 * s, 0.019, 0.021, 0.010, 0.008)
	# The dorsal shield: transverse rows of keeled plates, six abreast and
	# nearly touching, the outer keels the tallest so ridge lines run down the
	# back; a ragged row beside them, then two irregular rows of oval flank
	# scales. Every plate is jittered a little in size, height and place.
	var row := 0
	var z := -0.29
	while z < 0.55:
		var hwr := _prof(TRUNK, z)[1] / 0.278
		var shift := 0.012 * sin(float(row) * 1.7)
		for s: float in [-1.0, 1.0]:
			var si := 0 if s < 0.0 else 1
			for c in 4:
				var d: Array = DORSAL[c]
				var key := c * 2 + si
				if c == 3 and (z > 0.45 or _hash3(row, key, 21) < 0.25):
					continue
				var jz := (_hash3(row, key, 5) - 0.5) * 0.008
				var jf := (_hash3(row, key, 9) - 0.5) * 0.03 + shift
				var js := 0.87 + 0.26 * _hash3(row, key, 13)
				var jh := 0.85 + 0.3 * _hash3(row, key, 17)
				var f0: float = d[0]
				var hx: float = d[1]
				var hz: float = d[2]
				var h: float = d[3]
				var keel: float = d[4]
				_trunk_scute(acc, z + jz, (f0 + jf) * s, hx * js * hwr, hz * js, h * jh, keel * jh)
			# oval flank scales
			if z > -0.24 and z < 0.42:
				for q in 2:
					var key := 10 + q * 2 + si
					if _hash3(row, key, 29) < 0.22:
						continue
					var fz := z + 0.033 * float((row + q) % 2) + (_hash3(row, key, 31) - 0.5) * 0.012
					var ff := (0.925 + 0.05 * float(q)) + (_hash3(row, key, 37) - 0.5) * 0.02
					var js := 0.85 + 0.3 * _hash3(row, key, 41)
					_trunk_scute(acc, fz, ff * s, 0.018 * js, 0.022 * js, 0.0055 * js, 0.0, 1.0)
		z += 0.066
		row += 1
	SM.add(body, owner, "Trunk", _commit(acc), Transform3D.IDENTITY, skin)


## One keeled plate on the trunk at length z, lateral fraction f of the
## half-width (0 spine, +-1 the widest line). e squares the outline.
static func _trunk_scute(acc: Array, z: float, f: float, hx: float, hz: float,
		h: float, keel: float, e: float = 0.5) -> void:
	var xf := _loft_frame(TRUNK, TRUNK_Z, z, f)
	xf.origin -= xf.basis.y * 0.004
	var up := xf.basis.y
	var o := xf.origin
	var col := func(p: Vector3, n: Vector3) -> Color:
		var c := _skin_col(p, n, p.z, 0.26, 0.3)
		var hh := (p - o).dot(up)
		return c.lerp(C_BAND, 0.18 + 0.25 * _ss(0.004, -0.004, hh))
	_scute(acc, xf, hx, hz, h, keel, 0.018, e, 0.45, col)


# =============================================================================
#  HEAD AND JAW
# =============================================================================

static func _build_head(body: Node3D, owner: Node, skin: Material, eye_mat: Material,
		tooth_mat: Material) -> void:
	var head := SM.pivot(body, owner, "Head", Vector3(0.0, 0.28, -0.60))
	var acc := _acc()
	var hcol := func(p: Vector3, n: Vector3) -> Color:
		return _head_col(p, n)
	var nu := 144
	var nv := 190
	var pts := _loft_pts(SKULL, SKULL_Z, nu, nv)
	# The eye turrets, the brows and the nasal disc rise out of the skull
	# surface itself, blended in, so there is no seam or crease.
	for j in nv + 1:
		var r := _cap_ring(SKULL, SKULL_Z, pts[j * nu].z)
		if r[3] < 1e-4:
			continue
		for i in nu:
			var k := j * nu + i
			var p := pts[k]
			var w := _ss(r[2] + 0.3 * r[3], r[2] + 0.75 * r[3], p.y)
			if w > 0.0:
				pts[k] = Vector3(p.x, p.y + w * _skull_disp(p.x, p.z), p.z)
	_emit(acc, pts, nu, nv, hcol)

	# Nostrils: two bean-shaped slits on the nasal disc, angled out and back.
	var ncol := func(_p: Vector3, _n: Vector3) -> Color:
		return C_NOSTRIL
	for s: float in [-1.0, 1.0]:
		var a := _on_skull(0.0065 * s, -0.625, -0.0016)
		var b := _on_skull(0.0150 * s, -0.615, -0.0016)
		var c := _on_skull(0.0180 * s, -0.601, -0.0016)
		_tube(acc, [a, b, c], [0.0024, 0.0036, 0.0022], 10, 4, 3, ncol)
	# The lids: a thick skin hood round each eyeball, open in an almond.
	for s: float in [-1.0, 1.0]:
		_eyelids(acc, Vector3(EYE_C.x * s, EYE_C.y, EYE_C.z),
			Vector3(EYE_GAZE.x * s, EYE_GAZE.y, EYE_GAZE.z).normalized())
	SM.add(head, owner, "Skull", _commit(acc), Transform3D.IDENTITY, skin)

	# The eyes: yellow-green, sunk in their turrets, looking out, up and a
	# little ahead, with an upright slit pupil.
	var eacc := _acc()
	for s: float in [-1.0, 1.0]:
		var ec := Vector3(EYE_C.x * s, EYE_C.y, EYE_C.z)
		var gaze := Vector3(EYE_GAZE.x * s, EYE_GAZE.y, EYE_GAZE.z).normalized()
		var ecol := func(p: Vector3, _n: Vector3) -> Color:
			var k := (p - ec).normalized().dot(gaze)
			return C_IRIS_RIM.lerp(C_EYE, _ss(0.1, 0.7, k))
		_ellipsoid(eacc, Vector3(EYE_R, EYE_R, EYE_R), Transform3D(Basis(), ec), 32, 20, ecol)
		# The slit pupil: a thin lens lying on the eyeball, upright, well inside
		# the lid opening.
		var bx := Vector3.UP.cross(gaze).normalized()
		var by := gaze.cross(bx).normalized()
		var pcol := func(_p: Vector3, _n: Vector3) -> Color:
			return C_PUPIL
		var slit: Array = []
		for k in 5:
			var a := lerpf(-0.46, 0.46, float(k) / 4.0)
			slit.append(ec + (gaze * cos(a) + by * sin(a)) * (EYE_R - 0.0004))
		_tube(eacc, slit, [0.0005, 0.0017, 0.0021, 0.0017, 0.0005], 10, 4, 3, pcol)
	SM.add(head, owner, "Eyes", _commit(eacc), Transform3D.IDENTITY, eye_mat)

	# ---- the lower jaw, hinged under the back of the snout -----------------
	var jaw := SM.pivot(head, owner, "Jaw", Vector3(0.0, -0.02, -JAW_DZ))
	var jacc := _acc()
	var jcol := func(p: Vector3, n: Vector3) -> Color:
		return _jaw_col(p, n)
	_emit(jacc, _loft_pts(JAW, JAW_Z, 64, 110), 64, 110, jcol)
	SM.add(jaw, owner, "Mesh", _commit(jacc), Transform3D.IDENTITY, skin)

	# ---- teeth: cones rooted in the gums, interlocking along the lip --------
	var tacc := _acc()
	var ltacc := _acc()
	for s: float in [-1.0, 1.0]:
		var si := 0 if s < 0.0 else 1
		var bow := Vector3(s * 0.0012, 0.0, -0.001)
		var n := 0
		for row: Array in UPPER_TEETH:
			n += 1
			var tz: float = row[0]
			var tl: float = row[1]
			var rb: float = row[2]
			tz += (_hash3(n, si, 11) - 0.5) * 0.004
			tl *= 0.88 + 0.24 * _hash3(n, si, 23)
			var rs := _cap_ring(SKULL, SKULL_Z, tz)
			var rj := _cap_ring(JAW, JAW_Z, tz + JAW_DZ)
			var ex := rs[1] - 0.003
			var exit := Vector3(s * ex, _edge_y(rs, ex, false), tz)
			var tx := maxf(ex + 0.0025, rj[1] + 0.0015)
			var tip := Vector3(s * tx, exit.y - tl, tz + 0.0045)
			_tooth(tacc, exit + Vector3(-s * 0.002, 0.0065, 0.0), exit, tip, rb, bow)
		n = 0
		for row: Array in LOWER_TEETH:
			n += 1
			var zh: float = row[0]
			var tl: float = row[1]
			var rb: float = row[2]
			zh += (_hash3(n, si, 41) - 0.5) * 0.004
			tl *= 0.88 + 0.24 * _hash3(n, si, 53)
			var zj := zh + JAW_DZ
			var rj := _cap_ring(JAW, JAW_Z, zj)
			var rs := _cap_ring(SKULL, SKULL_Z, zh)
			var ex := rj[1] - 0.003
			var exit := Vector3(s * ex, _edge_y(rj, ex, true), zj)
			var tx := maxf(ex + 0.0025, rs[1] + 0.0015)
			var tip := Vector3(s * tx, exit.y + tl, zj + 0.0045)
			_tooth(ltacc, exit + Vector3(-s * 0.002, -0.0065, 0.0), exit, tip, rb, bow)
	SM.add(head, owner, "Teeth", _commit(tacc), Transform3D.IDENTITY, tooth_mat)
	SM.add(jaw, owner, "Teeth", _commit(ltacc), Transform3D.IDENTITY, tooth_mat)


## Height added to the skull's upper surface at (x, z): the eye turrets, the
## bony brow (palpebral) over the upper-inner side of each eye, and the low
## nasal disc round the nostrils.
static func _skull_disp(x: float, z: float) -> float:
	var ax := absf(x)
	var dx := (ax - 0.082) / 0.034
	var dz := (z + 0.152) / 0.046
	var tur := 0.023 * _ss(1.15, 0.45, sqrt(dx * dx + dz * dz))
	var bx := (ax - 0.068) / 0.017
	var bz := (z + 0.150) / 0.036
	var brow := 0.008 * _ss(1.0, 0.2, sqrt(bx * bx + bz * bz))
	var nx := x / 0.031
	var nz := (z + 0.611) / 0.029
	var disc := 0.007 * _ss(1.1, 0.45, sqrt(nx * nx + nz * nz))
	return tur + brow + disc


## The lids round one eye: a skin shell just outside the eyeball, open in an
## almond round the gaze, its margin rolled in to touch the eye. Most of it is
## buried in the turret; what shows is the upper and lower lid.
static func _eyelids(acc: Array, ec: Vector3, gaze: Vector3) -> void:
	var bx := Vector3.UP.cross(gaze).normalized()
	var by := gaze.cross(bx).normalized()
	var col := func(p: Vector3, n: Vector3) -> Color:
		var d := (p - ec).normalized()
		var a0 := _almond(atan2(d.dot(by), d.dot(bx)))
		var c := _head_col(p, n)
		return c.lerp(C_GUM, 0.55 * _ss(a0 + 0.3, a0, acos(clampf(d.dot(gaze), -1.0, 1.0))))
	var nu := 48
	var nv := 18
	var pts := PackedVector3Array()
	for j in nv + 1:
		for i in nu:
			var ph := TAU * float(i) / float(nu)
			var a0 := _almond(ph)
			var ang: float
			var rad: float
			if j == 0:
				ang = a0 - 0.14
				rad = EYE_R * 0.95
			elif j == 1:
				ang = a0 - 0.03
				rad = EYE_R + 0.0010
			elif j == 2:
				ang = a0 + 0.07
				rad = EYE_R + 0.0028
			else:
				var t := float(j - 3) / float(nv - 3)
				ang = lerpf(a0 + 0.2, PI, t)
				rad = EYE_R + 0.0036
			var dir := gaze * cos(ang) + (bx * cos(ph) + by * sin(ph)) * sin(ang)
			pts.append(ec + dir * rad)
	_emit(acc, pts, nu, nv, col)


## Half-angle of the lid opening from the gaze, at angle ph round it
## (0 = horizontal, towards the back of the head for the right eye).
static func _almond(ph: float) -> float:
	var c := cos(ph) / EYE_AH
	var s := sin(ph) / EYE_AV
	return 1.0 / sqrt(c * c + s * s)


## A point on the skull's upper surface (turrets and disc included) at (x, z),
## pushed `dy` along y.
static func _on_skull(x: float, z: float, dy: float) -> Vector3:
	var r := _cap_ring(SKULL, SKULL_Z, z)
	var y := _edge_y(r, x, true)
	y += _ss(r[2] + 0.3 * r[3], r[2] + 0.75 * r[3], y) * _skull_disp(x, z)
	return Vector3(x, y + dy, z)


## y of cross-section r where |x| is given, on its upper or lower half.
static func _edge_y(r: PackedFloat32Array, x: float, top: bool) -> float:
	var c := pow(clampf(absf(x) / maxf(r[1], 1e-5), 0.0, 1.0), 1.0 / r[5])
	var sn := sqrt(maxf(0.0, 1.0 - c * c))
	if top:
		return r[2] + r[3] * pow(sn, r[6])
	return r[2] - r[4] * pow(sn, r[7])


## One conical tooth: buried from root to exit (the gum line), then tapering
## to a fine point at tip, bowed slightly out and forward so it curves back.
static func _tooth(acc: Array, root: Vector3, exit: Vector3, tip: Vector3, rb: float,
		bow: Vector3) -> void:
	var axis := tip - exit
	var tl := axis.length()
	var ax := axis / tl
	var col := func(p: Vector3, _n: Vector3) -> Color:
		var t := (p - exit).dot(ax) / tl
		return C_TOOTH_ROOT.lerp(C_TOOTH, _ss(-0.05, 0.5, t))
	_tube(acc, [root, exit, exit.lerp(tip, 0.35) + bow * 0.7, exit.lerp(tip, 0.68) + bow, tip],
		[rb * 0.9, rb, rb * 0.7, rb * 0.4, rb * 0.07], 10, 2, 3, col)


static func _head_col(p: Vector3, n: Vector3) -> Color:
	var c := _skin_col(p * 1.4, n, p.z, 0.14, 0.12)
	# A dark gum line along the upper jaw where the teeth come out.
	var side := 1.0 - 0.7 * absf(n.y)
	var lip := _ss(-0.005, -0.017, p.y) * side * _ss(-0.19, -0.25, p.z)
	c = c.lerp(C_GUM, lip * 0.65)
	# The palate, inside the mouth (not the lip that shows outside the jaw).
	var inner := _ss(0.0, 0.012, _cap_ring(SKULL, SKULL_Z, p.z)[1] - 0.005 - absf(p.x))
	var pal := _ss(-0.35, -0.75, n.y) * _ss(-0.215, -0.245, p.z) * _ss(-0.008, -0.018, p.y)
	return c.lerp(C_MOUTH, pal * inner)


static func _jaw_col(p: Vector3, n: Vector3) -> Color:
	var c := _skin_col(p * 1.4 + Vector3(0.0, 0.0, 4.0), n, p.z, 0.14, 0.08)
	c = c.lerp(C_BELLY, 0.3 * _ss(0.4, -0.2, n.y))
	var hw := _cap_ring(JAW, JAW_Z, p.z)[1]
	# The gum line along the top edge.
	var lip := _ss(-0.009, 0.001, p.y) * _ss(0.9, 0.2, n.y) * _ss(0.0, 0.004, absf(p.x) - (hw - 0.012))
	c = c.lerp(C_GUM, lip * 0.6)
	# The mouth floor: warm yellow, the tongue a deeper patch in the middle.
	var inner := _ss(0.0, 0.010, hw - 0.006 - absf(p.x))
	var mouth := _ss(0.45, 0.8, n.y) * _ss(-0.006, 0.002, p.y) * inner
	var tongue := _ss(0.55, 0.25, absf(p.x) / maxf(hw, 1e-4)) * _ss(-0.33, -0.2, p.z) * _ss(0.06, -0.04, p.z)
	return c.lerp(C_MOUTH.lerp(C_TONGUE, tongue), mouth)


# =============================================================================
#  TAIL
# =============================================================================

## Tail cross-section at distance d down the tail, placed at local z.
static func _tail_row(d: float, zl: float) -> Array:
	var q := clampf(1.0 - d / TAIL_LEN, 0.0, 1.0)
	var hw := 0.21 * pow(q, 1.25) + 0.004
	var top := 0.124 * pow(q, 0.72) + 0.004
	var bot := 0.114 * pow(q, 0.78) + 0.004
	return [zl, hw, 0.0, top, bot, lerpf(0.9, 0.75, q), 0.72, 0.62]


static func _build_tail(body: Node3D, owner: Node, skin: Material) -> void:
	var parent: Node3D = body
	for i in 5:
		var pos := Vector3(0.0, 0.24, 0.50) if i == 0 else Vector3(0.0, 0.0, TAIL_SEG)
		var seg := SM.pivot(parent, owner, "Tail%d" % i, pos)
		seg.rotation.x = float(TAIL_DROOP[i])
		var d0 := TAIL_SEG * float(i)
		var last := i == 4
		var zend := TAIL_LEN - d0 - 0.03 if last else TAIL_SEG
		var st: Array = []
		var zl := 0.0
		while zl < zend - 0.001:
			st.append(_tail_row(d0 + zl, zl))
			zl += 0.04
		st.append(_tail_row(d0 + zend, zend))
		# Round ends centred on the joints: in plan view each end is a circle
		# round the pivot, so a swing never opens a gap.
		var first_row: Array = st[0]
		var last_row: Array = st[st.size() - 1]
		var c0: float = first_row[1]
		var c1: float = 0.03 if last else float(last_row[1])
		var zr := [-c0, zend + c1, c0, c1]
		var col := func(p: Vector3, n: Vector3) -> Color:
			return _skin_col(p + Vector3(0.0, 0.24, 0.5 + d0), n, d0 + p.z, 0.21,
				lerpf(0.3, 0.75, _ss(0.0, 0.5, d0 + p.z)))
		var acc := _acc()
		_emit(acc, _loft_pts(st, zr, 64, 48), 64, 48, col)
		# The crests: a double row of tall pointed plates, merging into one.
		for k in 4:
			var cz := 0.04 + 0.08 * float(k)
			var d := d0 + cz
			if d > TAIL_LEN - 0.06 or cz > zend:
				continue
			if d < 0.80:
				var h := lerpf(0.030, 0.052, _ss(0.0, 0.3, d)) * (1.0 - 0.25 * d)
				for s: float in [-1.0, 1.0]:
					var xf := _loft_frame(st, zr, cz, 0.56 * s)
					var b := Basis(Vector3.BACK, -0.32 * s) * Basis(Vector3.RIGHT, 0.18)
					_crest(acc, Transform3D(b, xf.origin - Vector3(0.0, 0.012, 0.0)), h, col)
				# small plates between the crests
				var mx := _loft_frame(st, zr, cz, 0.0)
				mx.origin -= mx.basis.y * 0.004
				_scute(acc, mx, 0.024, 0.032, 0.008, 0.006, 0.016, 0.55, 0.5, col)
			else:
				var h1 := 0.046 * (1.0 - (d - 0.80) / 0.85) + 0.012
				var xf1 := _loft_frame(st, zr, cz, 0.0)
				var b1 := Basis(Vector3.RIGHT, 0.2)
				_crest(acc, Transform3D(b1, xf1.origin - Vector3(0.0, 0.010, 0.0)), h1, col)
		SM.add(seg, owner, "Mesh", _commit(acc), Transform3D.IDENTITY, skin)
		parent = seg


## One upright, pointed tail-crest plate of height h, standing on the local
## origin: dark at its root, its upper edges lighter so they catch the sun.
static func _crest(acc: Array, xf: Transform3D, h: float, col: Callable) -> void:
	var o := xf.origin
	var up := xf.basis.y
	var ccol := func(p: Vector3, n: Vector3) -> Color:
		var c: Color = col.call(p, n)
		var hh := (p - o).dot(up)
		c = c.lerp(C_BAND, 0.4 * _ss(0.018, 0.004, hh))
		return c.lerp(C_CREST_TIP, 0.6 * _ss(0.014, 0.042, hh))
	_scute(acc, xf, 0.017, 0.037, h, 0.004, 0.02, 0.85, 1.0, ccol, 1.25)


# =============================================================================
#  LEGS
# =============================================================================

static func _build_legs(body: Node3D, owner: Node, skin: Material) -> void:
	for i in 4:
		var s := -1.0 if i % 2 == 0 else 1.0
		var front := i < 2
		var pos := Vector3(0.30 * s, 0.20, -0.32 if front else 0.32)
		var piv := SM.pivot(body, owner, "Leg%d" % i, pos)
		var acc := _acc()
		var off := Vector3(float(i) * 3.7, 0.0, float(i) * 1.3)
		var col := func(p: Vector3, n: Vector3) -> Color:
			return _limb_col(p, n, off)
		var ccol := func(_p: Vector3, _n: Vector3) -> Color:
			return C_CLAW
		if front:
			_front_leg(acc, s, col, ccol)
		else:
			_hind_leg(acc, s, col, ccol)
		SM.add(piv, owner, "Mesh", _commit(acc), Transform3D.IDENTITY, skin)


## High-walk forelimb: upper arm out and back to the elbow, forearm down to a
## slim wrist and a flat hand; five short fingers, claws on the inner three.
static func _front_leg(acc: Array, s: float, col: Callable, ccol: Callable) -> void:
	var ctrl := [Vector3(-s * 0.07, 0.03, 0.0), Vector3(s * 0.02, 0.0, 0.02),
		Vector3(s * 0.085, -0.040, 0.046), Vector3(s * 0.117, -0.078, 0.056),
		Vector3(s * 0.128, -0.122, 0.028), Vector3(s * 0.134, -0.160, -0.004)]
	var rad := [0.050, 0.045, 0.034, 0.037, 0.028, 0.020]
	_tube(acc, ctrl, rad, 24, 6, 6, col)
	for q in 3:
		_limb_scute(acc, ctrl, rad, 1, 0.2 + 0.3 * float(q), 0.15, s, 0.012, col)
		_limb_scute(acc, ctrl, rad, 1, 0.35 + 0.3 * float(q), 0.75, s, 0.010, col)
	var palm := Vector3(s * 0.137, -0.186, -0.028)
	_ellipsoid(acc, Vector3(0.028, 0.011, 0.030),
		Transform3D(Basis(Vector3.UP, -0.25 * s), palm), 20, 10, col)
	for k in 5:
		var a := s * (-0.52 + 0.26 * float(k))
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var fl: float = [0.026, 0.032, 0.036, 0.033, 0.028][k]
		var b := palm + dir * 0.020 + Vector3(0.0, -0.001, 0.0)
		var e := b + dir * fl + Vector3(0.0, -0.005, 0.0)
		_tube(acc, [b, b.lerp(e, 0.5) + Vector3(0.0, 0.003, 0.0), e],
			[0.0110, 0.0088, 0.0064], 12, 3, 4, col)
		if k < 3:
			_claw(acc, e, dir, 0.026, 0.0058, ccol)


## High-walk hindlimb: a big thigh out and forward to the knee, the shank down
## and back to a slim ankle and a long, flat, four-toed, webbed foot.
static func _hind_leg(acc: Array, s: float, col: Callable, ccol: Callable) -> void:
	var ctrl := [Vector3(-s * 0.07, 0.04, 0.0), Vector3(s * 0.03, 0.005, -0.02),
		Vector3(s * 0.10, -0.040, -0.050), Vector3(s * 0.138, -0.078, -0.062),
		Vector3(s * 0.150, -0.122, -0.030), Vector3(s * 0.156, -0.160, 0.000)]
	var rad := [0.072, 0.064, 0.048, 0.047, 0.034, 0.024]
	_tube(acc, ctrl, rad, 24, 6, 6, col)
	for q in 3:
		_limb_scute(acc, ctrl, rad, 1, 0.15 + 0.32 * float(q), 0.1, s, 0.014, col)
		_limb_scute(acc, ctrl, rad, 1, 0.3 + 0.32 * float(q), 0.7, s, 0.012, col)
	var sole := Vector3(s * 0.160, -0.1865, -0.036)
	var yaw := Basis(Vector3.UP, -0.2 * s)
	_ellipsoid(acc, Vector3(0.030, 0.011, 0.056), Transform3D(yaw, sole), 20, 10, col)
	var bases: Array[Vector3] = []
	var ends: Array[Vector3] = []
	for k in 4:
		var a := s * (-0.28 + 0.22 * float(k))
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var fl: float = [0.042, 0.052, 0.056, 0.050][k]
		var b := sole + dir * 0.040 + Vector3(0.0, 0.0005, 0.0)
		var e := b + dir * fl + Vector3(0.0, -0.005, 0.0)
		_tube(acc, [b, b.lerp(e, 0.5) + Vector3(0.0, 0.003, 0.0), e],
			[0.0120, 0.0095, 0.0066], 12, 3, 4, col)
		if k < 3:
			_claw(acc, e, dir, 0.024, 0.006, ccol)
		bases.append(b)
		ends.append(e)
	# the webbing between the toes: a thin membrane at toe height
	for k in 3:
		_web(acc, bases[k], bases[k].lerp(ends[k], 0.55), bases[k + 1],
			bases[k + 1].lerp(ends[k + 1], 0.55), 0.0022, col)


## A curved, pointed claw from the end of a toe.
static func _claw(acc: Array, at: Vector3, dir: Vector3, cl: float, r: float, ccol: Callable) -> void:
	var a := at - dir * 0.004
	var b := at + dir * cl * 0.55 + Vector3(0.0, 0.0005, 0.0)
	var c := at + dir * cl + Vector3(0.0, -0.004, 0.0)
	_tube(acc, [a, b, c], [r, r * 0.6, r * 0.12], 8, 3, 3, ccol)


## A small raised scale on a limb tube: on segment seg of ctrl at t, turned
## ang radians from the top towards the outside.
static func _limb_scute(acc: Array, ctrl: Array, rad: Array, seg: int, t: float, ang: float,
		s: float, sz: float, col: Callable) -> void:
	var c := _cr(ctrl, seg, t)
	var tg := (_cr(ctrl, seg, t + 0.02) - _cr(ctrl, seg, t - 0.02)).normalized()
	var r1: float = rad[seg]
	var r2: float = rad[seg + 1]
	var rr := lerpf(r1, r2, t * t * (3.0 - 2.0 * t))
	var up := (Vector3.UP - tg * tg.y).normalized()
	var side := tg.cross(up).normalized()
	if side.x * s < 0.0:
		side = -side
	var n := (up * cos(ang) + side * sin(ang)).normalized()
	var fwd := (tg - n * tg.dot(n)).normalized()
	var o := c + n * (rr - 0.0015)
	var sc := func(p: Vector3, nn: Vector3) -> Color:
		var k: Color = col.call(p, nn)
		return k.lerp(C_BAND, 0.3 * _ss(0.002, -0.002, (p - o).dot(n)))
	_scute(acc, Transform3D(Basis(n.cross(fwd), n, fwd), o), sz * 0.8, sz, sz * 0.42, sz * 0.22,
		0.008, 0.6, 0.5, sc)


## A thin membrane spanning from the line a0-a1 to the line b0-b1, th thick in
## the middle and closing to an edge at both ends.
static func _web(acc: Array, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, th: float,
		col: Callable) -> void:
	var nu := 12
	var nv := 8
	var pts := PackedVector3Array()
	for j in nv + 1:
		var t := float(j) / float(nv)
		var pa := a0.lerp(a1, t)
		var pb := b0.lerp(b1, t)
		var cen := (pa + pb) * 0.5
		var u := (pb - pa) * 0.5
		var w := th * sqrt(sin(PI * t))
		for i in nu:
			var ph := TAU * float(i) / float(nu)
			pts.append(cen + u * cos(ph) + Vector3.UP * (w * sin(ph)))
	_emit(acc, pts, nu, nv, col)


# =============================================================================
#  COLOUR
# =============================================================================

## The hide: olive back with dark crossbands (period along d), mottled
## olive flanks, cream belly low down, fine speckle.
static func _skin_col(p: Vector3, n: Vector3, d: float, period: float, band_amt: float) -> Color:
	var up := n.y
	var bw := 0.5 + 0.5 * cos(d * TAU / period)
	var band := _ss(0.35, 0.85, bw) * band_amt
	var m := _vnoise(p * 12.0)
	var m2 := _vnoise(p * 34.0 + Vector3(5.3, 1.7, 9.1))
	var c := C_BACK.lerp(C_BAND, clampf(band + _ss(0.58, 0.8, m) * 0.5, 0.0, 1.0))
	var flank := _ss(0.6, 0.0, up)
	var fc := C_FLANK.lerp(C_BAND, clampf(_ss(0.58, 0.78, m) * 0.75 + band * 0.3, 0.0, 1.0))
	c = c.lerp(fc, flank * 0.45)
	var belly := _ss(-0.45, -0.85, up)
	c = c.lerp(C_BELLY, belly)
	return c.lerp(Color(0.0, 0.0, 0.0), (m2 - 0.5) * 0.16)


## Limbs: olive, blotched darker, the same from above as the back; cream only
## underneath.
static func _limb_col(p: Vector3, n: Vector3, off: Vector3) -> Color:
	var m := _vnoise(p * 16.0 + off)
	var m2 := _vnoise(p * 40.0 + off * 1.7 + Vector3(2.1, 7.3, 1.1))
	var c := C_BACK.lerp(C_BAND, clampf(_ss(0.5, 0.8, m) * 0.75, 0.0, 1.0))
	c = c.lerp(C_FLANK, 0.25 * _ss(0.2, -0.4, n.y))
	c = c.lerp(C_BELLY, _ss(-0.4, -0.85, n.y))
	return c.lerp(Color(0.0, 0.0, 0.0), (m2 - 0.5) * 0.18)


static func _ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _bump(x: float, c: float, w: float) -> float:
	var q := (x - c) / w
	return exp(-q * q)


static func _hash3(x: int, y: int, z: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	h = ((h ^ (h >> 13)) & 0x7fffffff) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 1023) / 1023.0


## Smooth value noise, 0..1.
static func _vnoise(p: Vector3) -> float:
	var ix := floori(p.x)
	var iy := floori(p.y)
	var iz := floori(p.z)
	var fx := p.x - float(ix)
	var fy := p.y - float(iy)
	var fz := p.z - float(iz)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := lerpf(_hash3(ix, iy, iz), _hash3(ix + 1, iy, iz), fx)
	var b := lerpf(_hash3(ix, iy + 1, iz), _hash3(ix + 1, iy + 1, iz), fx)
	var c := lerpf(_hash3(ix, iy, iz + 1), _hash3(ix + 1, iy, iz + 1), fx)
	var e := lerpf(_hash3(ix, iy + 1, iz + 1), _hash3(ix + 1, iy + 1, iz + 1), fx)
	return lerpf(lerpf(a, b, fy), lerpf(c, e, fy), fz)


# =============================================================================
#  GEOMETRY — lofts, tubes, plates, all through one indexed-grid emitter
# =============================================================================

static func _acc() -> Array:
	return [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array()]


static func _commit(acc: Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = acc[0]
	arrays[Mesh.ARRAY_NORMAL] = acc[1]
	arrays[Mesh.ARRAY_COLOR] = acc[2]
	arrays[Mesh.ARRAY_INDEX] = acc[3]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Appends a closed-around grid of points ((nv + 1) rings of nu) to acc:
## normals from the finished surface itself, outward; colours from col(p, n);
## triangles wound so their fronts face out.
static func _emit(acc: Array, pts: PackedVector3Array, nu: int, nv: int, col: Callable) -> void:
	var cnt := pts.size()
	var nrm := PackedVector3Array()
	nrm.resize(cnt)
	for j in nv + 1:
		var jn := mini(j + 1, nv)
		var jp := maxi(j - 1, 0)
		for i in nu:
			var du := pts[j * nu + (i + 1) % nu] - pts[j * nu + (i + nu - 1) % nu]
			var dv := pts[jn * nu + i] - pts[jp * nu + i]
			nrm[j * nu + i] = du.cross(dv)
	# Outward = away from each ring's centre, summed over the whole surface.
	var score := 0.0
	for j in nv + 1:
		var cen := Vector3.ZERO
		for i in nu:
			cen += pts[j * nu + i]
		cen /= float(nu)
		for i in nu:
			score += nrm[j * nu + i].dot(pts[j * nu + i] - cen)
	var sgn := 1.0 if score >= 0.0 else -1.0
	for k in cnt:
		var v := nrm[k]
		nrm[k] = v.normalized() * sgn if v.length_squared() > 1e-24 else Vector3.ZERO
	# Poles (a ring shrunk to a point): the normal is the axis, which is what
	# the neighbouring ring's normals add up to.
	for j: int in [0, nv]:
		var spread := 0.0
		for i in nu:
			spread = maxf(spread, pts[j * nu + i].distance_squared_to(pts[j * nu]))
		if spread < 1e-14:
			var jj := 1 if j == 0 else nv - 1
			var sum := Vector3.ZERO
			for i in nu:
				sum += nrm[jj * nu + i]
			var axis := sum.normalized()
			for i in nu:
				nrm[j * nu + i] = axis
	var vv: PackedVector3Array = acc[0]
	var nn: PackedVector3Array = acc[1]
	var cc: PackedColorArray = acc[2]
	var ii: PackedInt32Array = acc[3]
	var base := vv.size()
	vv.append_array(pts)
	nn.append_array(nrm)
	for k in cnt:
		var c: Color = col.call(pts[k], nrm[k])
		cc.append(c)
	# Godot's front faces: (b - a) x (c - a) points against the outward normal.
	var w := 0.0
	for j in nv:
		for i in nu:
			var pa := pts[j * nu + i]
			var pb := pts[(j + 1) * nu + i]
			var pc := pts[(j + 1) * nu + (i + 1) % nu]
			w += (pb - pa).cross(pc - pa).dot(nrm[j * nu + i] + nrm[(j + 1) * nu + i])
	var keep := w < 0.0
	for j in nv:
		for i in nu:
			var i1 := (i + 1) % nu
			var a := base + j * nu + i
			var b := base + (j + 1) * nu + i
			var c := base + (j + 1) * nu + i1
			var d := base + j * nu + i1
			if keep:
				ii.append_array(PackedInt32Array([a, b, c, a, c, d]))
			else:
				ii.append_array(PackedInt32Array([a, c, b, a, d, c]))
	acc[0] = vv
	acc[1] = nn
	acc[2] = cc
	acc[3] = ii


static func _spow(x: float, p: float) -> float:
	return signf(x) * pow(absf(x), p)


## Smooth (C1 Hermite) interpolation of the station rows at z.
static func _prof(st: Array, z: float) -> PackedFloat32Array:
	var n := st.size()
	var first: Array = st[0]
	var lastr: Array = st[n - 1]
	var w := first.size()
	var out := PackedFloat32Array()
	out.resize(w)
	if z <= float(first[0]) or z >= float(lastr[0]):
		var src: Array = first if z <= float(first[0]) else lastr
		for k in w:
			out[k] = float(src[k])
		out[0] = z
		return out
	var i := 0
	while i < n - 2 and z > float((st[i + 1] as Array)[0]):
		i += 1
	var ra: Array = st[i]
	var rb: Array = st[i + 1]
	var za := float(ra[0])
	var h := float(rb[0]) - za
	var t := (z - za) / h
	var t2 := t * t
	var t3 := t2 * t
	var h00 := 2.0 * t3 - 3.0 * t2 + 1.0
	var h10 := t3 - 2.0 * t2 + t
	var h01 := -2.0 * t3 + 3.0 * t2
	var h11 := t3 - t2
	for k in range(1, w):
		out[k] = h00 * float(ra[k]) + h10 * h * _slope(st, i, k) \
			+ h01 * float(rb[k]) + h11 * h * _slope(st, i + 1, k)
	out[0] = z
	return out


static func _slope(st: Array, i: int, k: int) -> float:
	var r0: Array = st[maxi(i - 1, 0)]
	var r1: Array = st[mini(i + 1, st.size() - 1)]
	return (float(r1[k]) - float(r0[k])) / (float(r1[0]) - float(r0[0]))


## The cross-section at z, with ellipsoidal end caps: zr = [z0, z1, cap0, cap1].
static func _cap_ring(st: Array, zr: Array, z: float) -> PackedFloat32Array:
	var z0: float = zr[0]
	var z1: float = zr[1]
	var c0: float = zr[2]
	var c1: float = zr[3]
	var r := _prof(st, clampf(z, z0 + c0, z1 - c1))
	var f := 1.0
	if z < z0 + c0:
		var q := (z0 + c0 - z) / c0
		f = sqrt(maxf(0.0, 1.0 - q * q))
	elif z > z1 - c1:
		var q := (z - (z1 - c1)) / c1
		f = sqrt(maxf(0.0, 1.0 - q * q))
	r[0] = z
	r[1] *= f
	r[3] *= f
	r[4] *= f
	return r


## A point on cross-section r at angle t (0 = +x side, PI/2 = top).
static func _ring_pt(r: PackedFloat32Array, t: float) -> Vector3:
	var c := cos(t)
	var s := sin(t)
	var y := r[3] * _spow(s, r[6]) if s >= 0.0 else r[4] * _spow(s, r[7])
	return Vector3(r[1] * _spow(c, r[5]), r[2] + y, r[0])


## nu points round cross-section r, spaced evenly by arc length (weighted so
## the upper surface gets more of them), starting at the +x side.
static func _ring_even(r: PackedFloat32Array, nu: int) -> PackedVector3Array:
	var dense := nu * 4
	var dp := PackedVector3Array()
	for i in dense + 1:
		dp.append(_ring_pt(r, TAU * float(i) / float(dense)))
	var cum := PackedFloat32Array()
	cum.resize(dense + 1)
	var tot := 0.0
	var ylo := r[2] - 0.2 * r[4]
	var yhi := r[2] + 0.6 * r[3]
	for i in dense:
		var ym := (dp[i].y + dp[i + 1].y) * 0.5
		var wgt := 1.0 + (TOP_DENSITY * _ss(ylo, yhi, ym) if yhi > ylo else 0.0)
		tot += dp[i].distance_to(dp[i + 1]) * wgt
		cum[i + 1] = tot
	var out := PackedVector3Array()
	if tot < 1e-9:
		for i in nu:
			out.append(dp[0])
		return out
	var k := 0
	for i in nu:
		var target := tot * float(i) / float(nu)
		while k < dense - 1 and cum[k + 1] < target:
			k += 1
		var sl := cum[k + 1] - cum[k]
		var f := 0.0 if sl <= 0.0 else (target - cum[k]) / sl
		out.append(dp[k].lerp(dp[k + 1], f))
	return out


static func _loft_pts(st: Array, zr: Array, nu: int, nv: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var z0: float = zr[0]
	var z1: float = zr[1]
	for j in nv + 1:
		var v := float(j) / float(nv)
		var z := z0 + (z1 - z0) * (0.5 - 0.5 * cos(PI * v))
		pts.append_array(_ring_even(_cap_ring(st, zr, z), nu))
	return pts


## A frame on a loft's upper surface at length z, lateral fraction f of the
## half-width: origin on the skin, y = the outward normal, z = along the body.
static func _loft_frame(st: Array, zr: Array, z: float, f: float) -> Transform3D:
	var r := _cap_ring(st, zr, z)
	var t := acos(clampf(_spow(f, 1.0 / r[5]), -1.0, 1.0))
	var e := 0.002
	var p := _ring_pt(r, t)
	var da := _ring_pt(r, t + e) - _ring_pt(r, t - e)
	var db := _ring_pt(_cap_ring(st, zr, z + e), t) - _ring_pt(_cap_ring(st, zr, z - e), t)
	var n := da.cross(db).normalized()
	if n.dot(p - Vector3(0.0, r[2], z)) < 0.0:
		n = -n
	var fwd := (db - n * db.dot(n)).normalized()
	var side := n.cross(fwd).normalized()
	return Transform3D(Basis(side, n, fwd), p)


static func _ellipsoid(acc: Array, r: Vector3, xf: Transform3D, nu: int, nv: int,
		col: Callable) -> void:
	var pts := PackedVector3Array()
	for j in nv + 1:
		var th := PI * float(j) / float(nv)
		for i in nu:
			var ph := TAU * float(i) / float(nu)
			pts.append(xf * Vector3(r.x * sin(th) * cos(ph), r.y * cos(th), r.z * sin(th) * sin(ph)))
	_emit(acc, pts, nu, nv, col)


## Point t (0..1) along Catmull-Rom segment k of ctrl — the same curve _tube
## sweeps.
static func _cr(ctrl: Array, k: int, t: float) -> Vector3:
	var n := ctrl.size()
	var p0: Vector3 = ctrl[maxi(k - 1, 0)]
	var p1: Vector3 = ctrl[k]
	var p2: Vector3 = ctrl[k + 1]
	var p3: Vector3 = ctrl[mini(k + 2, n - 1)]
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)


## A smooth tube through ctrl (Catmull-Rom), a radius per point, round caps.
static func _tube(acc: Array, ctrl: Array, rad: Array, sides: int, sub: int, capn: int,
		col: Callable) -> void:
	var n := ctrl.size()
	var cs: Array[Vector3] = []
	var rs: Array[float] = []
	for k in n - 1:
		var r1: float = rad[k]
		var r2: float = rad[k + 1]
		for q in sub:
			var t := float(q) / float(sub)
			cs.append(_cr(ctrl, k, t))
			rs.append(lerpf(r1, r2, t * t * (3.0 - 2.0 * t)))
	var pl: Vector3 = ctrl[n - 1]
	var rl: float = rad[n - 1]
	cs.append(pl)
	rs.append(rl)
	var m := cs.size()
	var tg: Array[Vector3] = []
	for k in m:
		tg.append((cs[mini(k + 1, m - 1)] - cs[maxi(k - 1, 0)]).normalized())
	var nrm := tg[0].cross(Vector3.UP)
	if nrm.length_squared() < 1e-6:
		nrm = tg[0].cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	# Rings: [centre, normal, radius, tangent], front cap, body, back cap.
	var rings: Array = []
	var nb: Array[Vector3] = []
	for k in m:
		if k > 0:
			var ax := tg[k - 1].cross(tg[k])
			if ax.length_squared() > 1e-12:
				nrm = nrm.rotated(ax.normalized(), tg[k - 1].angle_to(tg[k]))
		nb.append(nrm)
	for q in capn:
		var al := 0.5 * PI * float(q) / float(capn)
		rings.append([cs[0] - tg[0] * rs[0] * cos(al), nb[0], rs[0] * sin(al), tg[0]])
	for k in m:
		rings.append([cs[k], nb[k], rs[k], tg[k]])
	for q in range(capn - 1, -1, -1):
		var al := 0.5 * PI * float(q) / float(capn)
		rings.append([cs[m - 1] + tg[m - 1] * rs[m - 1] * cos(al), nb[m - 1], rs[m - 1] * sin(al),
			tg[m - 1]])
	var pts := PackedVector3Array()
	for rg: Array in rings:
		var c: Vector3 = rg[0]
		var nv3: Vector3 = rg[1]
		var rr: float = rg[2]
		var tv: Vector3 = rg[3]
		var bv := tv.cross(nv3).normalized()
		for i in sides:
			var a := TAU * float(i) / float(sides)
			pts.append(c + (nv3 * cos(a) + bv * sin(a)) * rr)
	_emit(acc, pts, sides, rings.size() - 1, col)


## A raised armour plate in frame xf (x across, y out of the skin, z along):
## a rounded dome of half-size hx by hz and height h with a keel ridge down its
## middle, and a skirt that dives `sink` under the skin so it sits IN the hide.
## e squares the outline (1 = oval), pexp shapes the dome (0.5 round, 1 peaked),
## rp its crown (2 = domed, towards 1 = a pointed cone).
static func _scute(acc: Array, xf: Transform3D, hx: float, hz: float, h: float, keel: float,
		sink: float, e: float, pexp: float, col: Callable, rp: float = 2.0) -> void:
	var nu := 12
	var nv := 7
	var pts := PackedVector3Array()
	for j in nv + 1:
		var r := 1.25 * float(j) / float(nv)
		for i in nu:
			var ph := TAU * float(i) / float(nu)
			var a := _spow(cos(ph), e)
			var b := _spow(sin(ph), e)
			var rr := minf(r, 1.0)
			var x := hx * a * rr
			var z := hz * b * rr
			var y: float
			if r <= 1.0:
				var q := 1.0 - pow(r, rp)
				var zr := z / hz
				y = h * pow(q, pexp) \
					+ keel * sqrt(maxf(0.0, 1.0 - zr * zr)) * exp(-pow(x / (0.32 * hx), 2.0))
			else:
				y = -sink * (r - 1.0) / 0.25
			pts.append(xf * Vector3(x, y, z))
	_emit(acc, pts, nu, nv, col)
