extends RefCounted
const SM := preload("res://tools/smooth_mesh.gd")


## THE HERO MONKEY, sculpted — no boxes anywhere.
##
## Every part is a real smooth surface with its own correct normals: the head
## is ONE sculpted surface (the muzzle, cheeks and brow are bumps pushed out of
## it), the cream heart-shaped face is a thin patch lying on it with its rim
## tucked under the fur (a crisp edge at any resolution), limbs and tail are
## swept tubes with ball joints at every pivot, and the clothes are soft
## superellipsoids and swept bands.
##
## Parts that move together and share a material are merged into one mesh
## with vertex colours, so the whole figure is about two dozen draw calls.
##
## He faces -Z; the camera is behind him (+Z), so the back view — hood,
## backpack, backwards cap, ears, tail — is the one that has to be lovely.
static func build(body: Node3D, owner: Node) -> void:
	# Fur: soft wrapped light (no black core on the shadow side) and a pale
	# sheen round the edge, not an orange neon rim.
	var fur := _vc(0.92, 0.08, 0.30)
	fur.rim_tint = 0.12
	fur.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	var skin := _vc(0.70, 0.20, 0.35)
	skin.rim_tint = 0.18
	skin.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	var cloth := _vc(0.74, 0.22, 0.30)
	cloth.rim_tint = 0.15
	var shoe := _vc(0.40, 0.45, 0.25)
	shoe.rim_tint = 0.2
	var gloss := _vc(0.30, 0.42, 0.10, 0.0)
	var shine := SM.mat(Color(1.0, 1.0, 1.0), 0.3, 0.1, 0.0, 0.0, 2.2)

	# ---- body: all fixed to Body, so each material group is one mesh --------
	_place(body, owner, "Torso", _torso(), Vector3(0.0, 1.04, 0.0), cloth)
	_place(body, owner, "Clothes", _clothes(), Vector3(0.0, 1.0, 0.0), cloth)
	_place(body, owner, "Backpack", _backpack(), Vector3(0.0, 1.04, 0.28), cloth)
	_place(body, owner, "Tail", _tail(), Vector3(0.3, 0.95, 0.45), fur)
	_place(body, owner, "Head", _head(), HEAD_C, fur)
	_place(body, owner, "Face", _face_mask(), HEAD_C, skin)
	_place(body, owner, "HeadFur", _head_fur(), HEAD_C, fur)
	_place(body, owner, "Cap", _cap(), HEAD_C, cloth)
	_place(body, owner, "Eyes", _face_gloss(), HEAD_C, gloss)
	_place(body, owner, "Catchlights", _catchlights(), HEAD_C, shine)

	# ---- the rig: exact pivots the run / jump / roll animations drive ------
	for side: float in [-1.0, 1.0]:
		var arm := SM.pivot(body, owner, "ArmLeft" if side < 0.0 else "ArmRight",
			Vector3(side * 0.33, 1.14, 0.0))
		_place(arm, owner, "Sleeve", _sleeve(), Vector3(0.0, -0.18, 0.0), cloth)
		var elbow := SM.pivot(arm, owner, "Elbow", Vector3(0.0, -0.36, 0.0))
		_place(elbow, owner, "Forearm", _forearm(), Vector3(0.0, -0.10, 0.0), cloth)
		_place(elbow, owner, "Hand", _hand(-side), Vector3(0.0, -0.27, 0.0), skin)

		var leg := SM.pivot(body, owner, "LegLeft" if side < 0.0 else "LegRight",
			Vector3(side * 0.145, 0.68, 0.0))
		_place(leg, owner, "Shorts", _shorts_leg(side), Vector3(0.0, -0.06, 0.0), cloth)
		_place(leg, owner, "Thigh", _thigh(), Vector3(0.0, -0.21, 0.0), fur)
		var knee := SM.pivot(leg, owner, "Knee", Vector3(0.0, -0.30, 0.0))
		_place(knee, owner, "Shin", _shin(), Vector3(0.0, -0.11, 0.0), fur)
		var ankle := SM.pivot(knee, owner, "Ankle", Vector3(0.0, -0.22, 0.0))
		_place(ankle, owner, "Foot", _sneaker(), Vector3(0.0, -0.09, -0.06), shoe)


# =============================================================================
#  PALETTE AND PROPORTIONS
# =============================================================================
const FUR := Color(0.77, 0.37, 0.14)
const FUR_DARK := Color(0.50, 0.22, 0.08)
const CREAM := Color(0.98, 0.86, 0.66)
const HAND := Color(0.93, 0.78, 0.58)
const BLUSH := Color(0.99, 0.70, 0.60)
const INNER_EAR := Color(0.97, 0.78, 0.66)
const HOODIE := Color(0.13, 0.46, 0.95)
const HOODIE_RIB := Color(0.09, 0.36, 0.80)
const POCKET := Color(0.11, 0.41, 0.88)
const SLEEVE := Color(0.10, 0.38, 0.84)
const LINING := Color(0.55, 0.70, 0.95)
const CUFF := Color(0.07, 0.30, 0.70)
const CORD := Color(0.97, 0.97, 0.96)
const AGLET := Color(0.72, 0.76, 0.82)
const SHORTS := Color(0.93, 0.19, 0.15)
const WAISTBAND := Color(0.80, 0.13, 0.11)
const STRIPE := Color(0.98, 0.97, 0.94)
const CAP := Color(0.94, 0.16, 0.14)
const BRIM := Color(0.62, 0.07, 0.08)
const SNEAKER := Color(0.98, 0.98, 0.97)
const LACE := Color(0.82, 0.85, 0.90)
const SOLE := Color(0.62, 0.07, 0.08)
const MIDSOLE := Color(0.96, 0.95, 0.93)
const TREAD := Color(0.42, 0.05, 0.06)
const PACK := Color(1.0, 0.80, 0.14)
const PACK_LID := Color(1.0, 0.72, 0.10)
const PACK_SEAM := Color(0.78, 0.52, 0.06)
const BUCKLE := Color(0.16, 0.16, 0.19)
const STRAP := Color(0.62, 0.07, 0.08)
const BANANA := Color(1.0, 0.91, 0.32)
const BANANA_TIP := Color(0.36, 0.24, 0.10)
const EYE := Color(0.08, 0.06, 0.05)
const IRIS := Color(0.40, 0.22, 0.10)
const IRIS_LIGHT := Color(0.68, 0.42, 0.18)
const NOSE := Color(0.20, 0.10, 0.07)

const HEAD_C := Vector3(0.0, 1.48, 0.0)
const HEAD_R := Vector3(0.272, 0.25, 0.25)
const TORSO_Y := 1.05
const TORSO_HY := 0.23

# The shoulder yoke: one soft roll from shoulder to shoulder, high at the neck
# and sloping down to the arms (a young monkey, not a coat hanger).
const YOKE_HX := 0.33        # ends tucked inside the sleeve's shoulder ball
const YOKE_Y := 1.15
const YOKE_RISE := 0.12
const YOKE_R0 := 0.150
const YOKE_R1 := 0.074
const YOKE_FLAT := 0.58

# The cap is worn BACKWARDS and pushed back: its axis leans toward +Z, so the
# band rides high on the forehead and low over the nape, where the brim is.
const CAP_TILT := 0.26        # tan of the lean
const CAP_AB := 1.00          # polar angle of the band, radians from the axis
const CAP_LIP := 0.07         # how quickly the band edge tucks into the head
const CAP_TE := 0.013         # thickness of the cap at the band
const CAP_TOP := 1.795        # dome height; the button lands the top on 1.80


# =============================================================================
#  THE FIGURE
# =============================================================================

## The hoodie body ONLY (the rig test boxes the swinging hand against it).
static func _torso() -> Array:
	var colf := func(_u: float, _v: float, p: Vector3) -> Color:
		return HOODIE.lerp(HOODIE_RIB, 1.0 - smoothstep(0.866, 0.878, p.y))
	return _grid(64, 48, _torso_f, colf, Vector3(0.0, TORSO_Y, 0.0))


## Vertical superellipse exponent: rounder over the chest, a flatter, squarer
## bottom so the ribbed hem reads as a hem (and overhangs the shorts).
static func _torso_e(ct: float) -> float:
	return 0.55 if ct >= 0.0 else 0.40


## Torso cross-section at height fraction h (0 hem .. 1 neck): rx, rz, belly.
static func _torso_dims(h: float) -> Vector3:
	var rx := _keys(h, PackedFloat32Array([0.0, 0.221, 0.3, 0.232, 0.62, 0.230, 1.0, 0.20]))
	var rz := _keys(h, PackedFloat32Array([0.0, 0.178, 0.3, 0.190, 0.62, 0.186, 1.0, 0.172]))
	var zo := _keys(h, PackedFloat32Array([0.0, 0.0, 0.3, -0.010, 0.62, -0.004, 1.0, 0.004]))
	# the ribbed hem stands a touch proud of the body
	var rib := 1.0 - smoothstep(0.09, 0.13, h)
	return Vector3(rx + 0.004 * rib, rz + 0.004 * rib, zo)


static func _torso_f(u: float, v: float) -> Vector3:
	# rings bunched toward the sides (where the superellipse turns quickly)
	var th := v * PI + 0.2 * sin(v * TAU)
	var ph := u * TAU
	var e := _torso_e(cos(th))
	var ct := _sp(cos(th), e)
	var st := _sp(sin(th), e)
	var y := TORSO_Y + TORSO_HY * ct
	var h := clampf((y - (TORSO_Y - TORSO_HY)) / (2.0 * TORSO_HY), 0.0, 1.0)
	var dm := _torso_dims(h)
	return Vector3(dm.x * st * _sp(cos(ph), 0.85), y, dm.y * st * _sp(sin(ph), 0.85) + dm.z)


## z of the torso's FRONT surface at (x, y).
static func _torso_front_z(x: float, y: float) -> float:
	var ct := clampf((y - TORSO_Y) / TORSO_HY, -1.0, 1.0)
	var e := _torso_e(ct)
	var st := pow(maxf(0.0, 1.0 - pow(absf(ct), 2.0 / e)), e / 2.0)
	var h := clampf((y - (TORSO_Y - TORSO_HY)) / (2.0 * TORSO_HY), 0.0, 1.0)
	var dm := _torso_dims(h)
	var rx := maxf(dm.x * st, 1e-4)
	var q := pow(maxf(0.0, 1.0 - pow(absf(x) / rx, 2.0 / 0.85)), 0.85 / 2.0)
	return dm.z - dm.y * st * q


## Shoulders, the bunched hood, the kangaroo pocket, drawstrings, shorts seat.
static func _clothes() -> Array:
	var parts: Array = []
	# ---- shoulder yoke: one soft roll, high at the neck, sloping to the arms --
	var yp := PackedVector3Array()
	var yr := PackedFloat32Array()
	var yc := PackedColorArray()
	var yu := PackedVector3Array()
	for i in 25:
		var t := float(i) / 24.0 * 2.0 - 1.0
		yp.append(Vector3(t * YOKE_HX, _yoke_cy(t), 0.0))
		yr.append(_yoke_r(t))
		yc.append(HOODIE)
		yu.append(Vector3.UP)
	parts.append(_tube(yp, yr, yc, 36, YOKE_FLAT, yu, 0.78, 0.78))

	# ---- the hood, down: a bunched cowl draped behind the neck ---------------
	parts.append(_hood())

	# ---- kangaroo pocket: a soft patch lying on the belly --------------------
	parts.append(_pocket())

	# ---- drawstrings, hanging from the neckline ------------------------------
	for s: float in [-1.0, 1.0]:
		var cp := PackedVector3Array()
		var cr := PackedFloat32Array()
		var cc := PackedColorArray()
		for i in 9:
			var t := float(i) / 8.0
			var y := lerpf(1.262, 1.085, t)
			var x := s * (0.042 + 0.012 * t)
			var z := minf(_torso_front_z(x, y), _yoke_front_z(x, y)) - 0.006
			cp.append(Vector3(x, y, z))
			cr.append(0.0068)
			cc.append(CORD)
		parts.append(_tube(cp, cr, cc, 10))
		var tip := cp[cp.size() - 1]
		var aglet := PackedVector3Array([tip + Vector3(0.0, 0.004, 0.0), tip + Vector3(0.0, -0.028, -0.002)])
		parts.append(_tube(aglet, PackedFloat32Array([0.0085, 0.0085]),
			PackedColorArray([AGLET, AGLET]), 10))

	# ---- shorts seat: narrower than the hoodie hem and flat in front, so the
	# hem overhangs it; the hips come from the baggy shorts legs. Only a finger
	# of waistband shows under the hem.
	parts.append(_sbox(Vector3(0.0, SEAT_Y, SEAT_Z), SEAT_HALF, 0.7, SHORTS, Basis(), 40, 24))
	var wy := 0.832
	var wk := pow(1.0 - pow(absf((wy - SEAT_Y) / SEAT_HALF.y), 2.0 / 0.7), 0.35)
	parts.append(_hoop(wy, SEAT_HALF.x * wk + 0.002, SEAT_HALF.z * wk + 0.002, 0.0135, WAISTBAND,
		SEAT_Z))
	return _merge(parts)


const SEAT_Y := 0.790
const SEAT_Z := 0.050
const SEAT_HALF := Vector3(0.195, 0.100, 0.115)


static func _yoke_cy(t: float) -> float:
	return YOKE_Y + YOKE_RISE * pow(1.0 - t * t, 1.6)


static func _yoke_r(t: float) -> float:
	return lerpf(YOKE_R0, YOKE_R1, t * t)


## Front surface z of the shoulder yoke near the middle (for the drawstrings).
static func _yoke_front_z(x: float, y: float) -> float:
	var t := clampf(x / YOKE_HX, -1.0, 1.0)
	var rz := _yoke_r(t)
	var q := (y - _yoke_cy(t)) / (rz * YOKE_FLAT)
	if absf(q) >= 1.0:
		return 0.0
	return -rz * sqrt(1.0 - q * q)


## Is p inside the hoodie (torso or shoulder yoke)? Used to lay the straps
## on it without gaps.
static func _in_body(p: Vector3) -> bool:
	var ct := (p.y - TORSO_Y) / TORSO_HY
	if absf(ct) < 1.0:
		var e := _torso_e(ct)
		var st := pow(1.0 - pow(absf(ct), 2.0 / e), e * 0.5)
		var h := clampf((p.y - (TORSO_Y - TORSO_HY)) / (2.0 * TORSO_HY), 0.0, 1.0)
		var dm := _torso_dims(h)
		var rx := dm.x * st
		var rz := dm.y * st
		if rx > 1e-4 and rz > 1e-4:
			if pow(absf(p.x) / rx, 2.0 / 0.85) + pow(absf(p.z - dm.z) / rz, 2.0 / 0.85) <= 1.0:
				return true
	var t := clampf(p.x / YOKE_HX, -1.0, 1.0)
	var yr := _yoke_r(t)
	var slope := 3.2 * YOKE_RISE * t * pow(maxf(1.0 - t * t, 0.0), 0.6) / YOKE_HX
	var ry := yr * YOKE_FLAT * sqrt(1.0 + slope * slope)
	return pow((p.y - _yoke_cy(t)) / ry, 2.0) + pow(p.z / yr, 2.0) <= 1.0


## The hoodie's surface seen from inside point `c` along `dir`, pushed out by `off`.
static func _lay(c: Vector3, dir: Vector3, off: float) -> Vector3:
	var d := dir.normalized()
	var last_in := 0.0
	var r := 0.0
	while r < 0.45:
		r += 0.004
		if _in_body(c + d * r):
			last_in = r
	var lo := last_in
	var hi := last_in + 0.004
	for _k in 12:
		var mid := (lo + hi) * 0.5
		if _in_body(c + d * mid):
			lo = mid
		else:
			hi = mid
	return c + d * ((lo + hi) * 0.5 + off)


## The hood, down: a soft bunched cowl lying on the upper back behind the
## neck. Thick at the back and flattened against the shoulders (not a round
## neck pillow), with soft folds, and a hollow along its top where it opens,
## showing the lighter lining as a crescent.
static func _hood() -> Array:
	var ctrl := PackedVector3Array([
		Vector3(-0.128, 1.288, -0.112), Vector3(-0.186, 1.300, -0.008),
		Vector3(-0.172, 1.296, 0.118), Vector3(-0.096, 1.288, 0.194),
		Vector3(0.0, 1.282, 0.218), Vector3(0.096, 1.288, 0.194),
		Vector3(0.172, 1.296, 0.118), Vector3(0.186, 1.300, -0.008),
		Vector3(0.128, 1.288, -0.112)])
	var nf := func(u: float, v: float) -> Vector3:
		var e := 0.0015
		var vv := clampf(v, 0.004, 0.996)
		var du := _hood_pt(ctrl, vv, (u + e) * TAU) - _hood_pt(ctrl, vv, (u - e) * TAU)
		var dv := _hood_pt(ctrl, vv + e, u * TAU) - _hood_pt(ctrl, vv - e, u * TAU)
		var n := du.cross(dv).normalized()
		var away := _hood_pt(ctrl, vv, u * TAU) - _crom(ctrl, vv)
		return n if n.dot(away) >= 0.0 else -n
	var f := func(u: float, v: float) -> Vector3:
		return _hood_pt(ctrl, v, u * TAU)
	var colf := func(u: float, v: float, _p: Vector3) -> Color:
		return SLEEVE.lerp(LINING, smoothstep(0.30, 0.62, _hood_groove(v, u * TAU)))
	return _grid(32, 90, f, colf, Vector3(0.0, 1.29, 0.0), nf)


## How deep the hood's opening hollows its top at (s along, th round).
static func _hood_groove(s: float, th: float) -> float:
	var mid := smoothstep(0.08, 0.5, minf(s, 1.0 - s))
	var w := 1.0 - pow((th - 1.15) / (0.45 + 0.45 * mid), 2.0)
	if w <= 0.0:
		return 0.0
	return w * w * mid


static func _hood_pt(ctrl: PackedVector3Array, s: float, th: float) -> Vector3:
	var c := _crom(ctrl, s)
	var tg := (_crom(ctrl, s + 0.002) - _crom(ctrl, s - 0.002)).normalized()
	var out := Vector3(c.x, 0.0, c.z)
	out = (out - tg * out.dot(tg)).normalized()
	var up := out.cross(tg).normalized()
	var sc := clampf(s, 0.0, 1.0)
	var mid := pow(sin(sc * PI), 1.3)
	var r := 0.034 + 0.044 * mid
	r *= 1.0 + 0.13 * mid * pow(sin(sc * PI * 9.0), 2.0)
	# the ends close smoothly (they tuck into the yoke at the collarbones)
	var endw := clampf(minf(sc, 1.0 - sc) / 0.05, 0.0, 1.0)
	var k := sqrt(1.0 - pow(1.0 - endw, 2.0)) * (1.0 - 0.50 * _hood_groove(sc, th))
	return c + out * (0.64 * r * cos(th) * k) + up * (r * sin(th) * k)


## Catmull-Rom through control points at s in 0..1 (uniform per span).
static func _crom(ctrl: PackedVector3Array, s: float) -> Vector3:
	var n := ctrl.size()
	var x := clampf(s, 0.0, 1.0) * float(n - 1)
	var i := mini(int(x), n - 2)
	var t := x - float(i)
	var p1 := ctrl[i]
	var p2 := ctrl[i + 1]
	var p0 := ctrl[i - 1] if i > 0 else p1 * 2.0 - p2
	var p3 := ctrl[i + 2] if i + 2 < n else p2 * 2.0 - p1
	return p1.cubic_interpolate(p2, p0, p3, t)


static func _pocket() -> Array:
	var f := func(s: float, w: float) -> Vector3:
		# s across (0..1), w down (0 top .. 1 bottom). Slightly trapezoid.
		var yy := lerpf(1.015, 0.885, w)
		var half := lerpf(0.105, 0.145, w)
		var xx := (s - 0.5) * 2.0 * half
		var z := _torso_front_z(xx, yy)
		var edge := minf(minf(s, 1.0 - s), minf(w, 1.0 - w))
		var lift := 0.012 * smoothstep(0.0, 0.14, edge) - 0.004
		return Vector3(xx, yy, z - lift)
	return _grid(28, 16, f, POCKET, Vector3(0.0, 0.95, 0.2))


## The backpack: a puffy yellow pack with a deeper-yellow lid, red straps and
## grab loop, and a banana stuffed under the lid. Deliberately NO pair of
## features on its back — two spots and a pocket on a square read as a face
## staring at the camera.
static func _backpack() -> Array:
	var parts: Array = []
	parts.append(_sbox(PACK_C, PACK_HALF, 0.55, PACK, Basis(), 48, 32))
	# lower pocket: same yellow, a soft raised panel with a seam along its top
	var pk_c := Vector3(0.0, 0.925, 0.0)
	pk_c.z = PACK_C.z + _sbox_z(0.0, pk_c.y - PACK_C.y, PACK_HALF, 0.55) + 0.013 - PK_HALF.z
	parts.append(_sbox(pk_c, PK_HALF, 0.5, PACK, Basis(), 32, 18))
	var zp := PackedVector3Array()
	var zr := PackedFloat32Array()
	var zc := PackedColorArray()
	for i in 17:
		var x := (float(i) / 16.0 * 2.0 - 1.0) * 0.118
		zp.append(pk_c + Vector3(x, 0.056, _sbox_z(x, 0.056, PK_HALF, 0.5) + 0.0005))
		zr.append(0.0042)
		zc.append(PACK_SEAM)
	parts.append(_tube(zp, zr, zc, 8))
	# the lid: a deeper-yellow flap over the top third, a little proud of the
	# bag, with a darker seam along its lower edge
	parts.append(_sbox(LID_C, LID_HALF, 0.42, PACK_LID, Basis(), 48, 22))
	var lp := PackedVector3Array()
	var lr := PackedFloat32Array()
	var lc := PackedColorArray()
	for i in 23:
		var x := (float(i) / 22.0 * 2.0 - 1.0) * 0.176
		lp.append(LID_C + Vector3(x, -0.054, _sbox_z(x, -0.054, LID_HALF, 0.42) + 0.0008))
		lr.append(0.0046)
		lc.append(PACK_SEAM)
	parts.append(_tube(lp, lr, lc, 8))
	# a grab loop on top
	parts.append(_torus(0.032, 0.0085, STRAP, Transform3D(
		Basis(Vector3.RIGHT, 0.25), Vector3(0.0, LID_C.y + LID_HALF.y - 0.006, 0.272)), 20, 8))
	# shoulder straps: flat bands laid ON the hoodie — out of the lid, up the
	# back, under the hood, over the shoulder, down the chest, and curving out
	# to disappear under the arms
	for s: float in [-1.0, 1.0]:
		var ctrl := PackedVector3Array([Vector3(s * 0.118, 1.150, 0.250)])
		for a_deg: float in [16.0, 34.0, 54.0, 74.0, 96.0, 124.0]:
			var a := deg_to_rad(a_deg)
			var x := s * lerpf(0.122, 0.150, smoothstep(0.0, 96.0, a_deg))
			ctrl.append(_lay(Vector3(x, 1.10, 0.0), Vector3(0.0, sin(a), cos(a)), 0.0105))
		for q: Vector2 in [Vector2(0.157, 1.16), Vector2(0.172, 1.05), Vector2(0.198, 0.965)]:
			ctrl.append(Vector3(s * q.x, q.y, _torso_front_z(s * q.x, q.y) - 0.0105))
		ctrl.append(Vector3(s * 0.214, 0.910, -0.110))
		var sp := _spline(ctrl, 6)
		var sr := PackedFloat32Array()
		var sc := PackedColorArray()
		var su := PackedVector3Array()
		for i in sp.size():
			var p := sp[i]
			sr.append(0.029)
			sc.append(STRAP)
			su.append((p - Vector3(s * 0.05, minf(p.y, 1.10), 0.0)).normalized())
		parts.append(_tube(sp, sr, sc, 16, 0.30, su, 0.5, 0.5))
		# a little adjuster buckle on the chest
		var k := 0
		var best := 1e9
		for i in range(1, sp.size() - 1):
			if sp[i].z < -0.1 and absf(sp[i].y - 1.10) < best:
				best = absf(sp[i].y - 1.10)
				k = i
		var bz := su[k]
		var by := (sp[k - 1] - sp[k + 1]).normalized()
		var bx := by.cross(bz).normalized()
		by = bz.cross(bx)
		parts.append(_sbox(sp[k] + bz * 0.009, Vector3(0.036, 0.016, 0.007), 0.3, BUCKLE,
			Basis(bx, by, bz), 16, 8))
	# a banana poking out from under the lid, leaning out to the LEFT (the
	# tail balances it on the right)
	var bc := PackedVector3Array([
		Vector3(-0.080, 1.10, 0.272), Vector3(-0.100, 1.19, 0.282),
		Vector3(-0.130, 1.272, 0.296), Vector3(-0.168, 1.334, 0.314),
		Vector3(-0.210, 1.366, 0.332)])
	var bp := _spline(bc, 6)
	var br := PackedFloat32Array()
	var bcol := PackedColorArray()
	for i in bp.size():
		var t := float(i) / float(bp.size() - 1)
		br.append(lerpf(0.032, 0.027, t) * (1.0 - 0.55 * smoothstep(0.80, 1.0, t)))
		bcol.append(BANANA.lerp(BANANA_TIP, smoothstep(0.86, 0.93, t)))
	parts.append(_tube(bp, br, bcol, 18, 1.0, PackedVector3Array(), 1.0, 0.5))
	return _merge(parts)


const PACK_C := Vector3(0.0, 1.030, 0.280)
const PACK_HALF := Vector3(0.186, 0.198, 0.108)
const PK_HALF := Vector3(0.138, 0.070, 0.034)
const LID_C := Vector3(0.0, 1.146, 0.286)
const LID_HALF := Vector3(0.193, 0.076, 0.117)


## z of a superellipsoid's back (+z) surface at (x, y), relative to its centre.
static func _sbox_z(x: float, y: float, half: Vector3, e: float) -> float:
	var k := 1.0 - pow(absf(x / half.x), 2.0 / e) - pow(absf(y / half.y), 2.0 / e)
	return half.z * pow(maxf(k, 0.0), e * 0.5)


## A long monkey tail: out from under the hoodie just below the pack, across
## to the RIGHT at hip height (above the swinging forearm, clear of the pack),
## then up the side into a question-mark curl, tapering to a cream tuft.
static func _tail() -> Array:
	var ctrl := PackedVector3Array([
		Vector3(0.02, 0.800, 0.12), Vector3(0.06, 0.805, 0.27),
		Vector3(0.16, 0.835, 0.385), Vector3(0.32, 0.875, 0.435),
		Vector3(0.47, 0.935, 0.435), Vector3(0.56, 1.050, 0.415),
		Vector3(0.588, 1.190, 0.395), Vector3(0.548, 1.310, 0.378),
		Vector3(0.462, 1.348, 0.368), Vector3(0.396, 1.302, 0.366),
		Vector3(0.396, 1.222, 0.368), Vector3(0.452, 1.192, 0.376)])
	var pts := _spline(ctrl, 8)
	var rad := PackedFloat32Array()
	var col := PackedColorArray()
	for i in pts.size():
		var t := float(i) / float(pts.size() - 1)
		rad.append(lerpf(0.042, 0.020, pow(t, 0.8)) + 0.012 * smoothstep(0.80, 0.985, t))
		col.append(FUR.lerp(CREAM, smoothstep(0.78, 0.93, t)))
	return _tube(pts, rad, col, 22)


# ---- head ---------------------------------------------------------------------

## The head's radius in direction d: a slightly wide egg with a muzzle, cheeks,
## a soft brow and eye sockets sculpted into the one surface.
static func _head_r(d: Vector3) -> float:
	var r := 1.0 / sqrt(pow(d.x / HEAD_R.x, 2.0) + pow(d.y / HEAD_R.y, 2.0)
		+ pow(d.z / HEAD_R.z, 2.0))
	r += 0.088 * _bump(d, Vector3(0.0, -0.37, -0.93), 0.42, 0.29)
	r += 0.010 * _bump(d, Vector3(0.0, 0.43, -0.90), 0.55, 0.15)
	r += 0.012 * _bump(d, Vector3(0.0, 0.25, 1.0), 0.8, 0.7)
	for s: float in [-1.0, 1.0]:
		r += 0.020 * _bump(d, Vector3(s * 0.60, -0.30, -0.74), 0.42, 0.36)
		r -= 0.012 * _bump(d, _eye_dir(s), 0.24, 0.27)
	return r


static func _head_pt(d: Vector3) -> Vector3:
	return HEAD_C + d * _head_r(d)


static func _head_n(d: Vector3) -> Vector3:
	var t1 := d.cross(Vector3.UP)
	if t1.length_squared() < 1e-6:
		t1 = d.cross(Vector3.RIGHT)
	t1 = t1.normalized()
	var t2 := d.cross(t1).normalized()
	var e := 0.002
	var a := _head_pt((d + t1 * e).normalized()) - _head_pt((d - t1 * e).normalized())
	var b := _head_pt((d + t2 * e).normalized()) - _head_pt((d - t2 * e).normalized())
	var n := a.cross(b).normalized()
	return n if n.dot(d) > 0.0 else -n


## A point on the face, from "face coordinates" (x across, y up, on the unit sphere).
static func _face_dir(fx: float, fy: float) -> Vector3:
	return Vector3(fx, fy, -sqrt(maxf(0.0, 1.0 - fx * fx - fy * fy))).normalized()


static func _eye_dir(s: float) -> Vector3:
	return _face_dir(s * 0.30, 0.09)


## Ginger fur with a darker crown, blended softly over many vertices (fur
## does not have hard edges; the cream face is its own crisp patch).
static func _head_col(d: Vector3) -> Color:
	# a paler nape under the brim, so it is not a black gap above the hood
	var nape := smoothstep(0.35, 0.75, d.z) * smoothstep(-0.15, -0.55, d.y)
	return FUR.lerp(FUR_DARK, smoothstep(0.42, 0.72, d.y) * 0.9).lerp(CREAM, 0.35 * nape)


## Face coordinates inside the heart-shaped face mask: < 0 inside.
static func _mask_sdf(fx: float, fy: float) -> float:
	var m := Vector2(fx / 0.50, (fy + 0.36) / 0.34).length() - 1.0
	m *= 0.36
	for s: float in [-1.0, 1.0]:
		m = minf(m, Vector2(fx - s * 0.30, fy - 0.09).length() - 0.345)
	return m


const MASK_O := Vector2(0.0, -0.08)
const MASK_LIFT := 0.0042


## Distance from MASK_O to the mask outline, in direction psi.
static func _mask_edge(psi: float) -> float:
	var dir := Vector2(cos(psi), sin(psi))
	var lo := 0.0
	var hi := 0.0
	while hi < 1.2:
		hi += 0.02
		var q := MASK_O + dir * hi
		if _mask_sdf(q.x, q.y) > 0.0:
			break
		lo = hi
	for _k in 12:
		var mid := (lo + hi) * 0.5
		var q := MASK_O + dir * mid
		if _mask_sdf(q.x, q.y) > 0.0:
			hi = mid
		else:
			lo = mid
	return (lo + hi) * 0.5


## The cream face: a thin patch lying on the sculpted head, heart-shaped (two
## rounds round the eyes and the muzzle below), its rim tucked under the fur so
## the edge is a clean crisp line at any resolution. Rosy cheeks.
static func _face_mask() -> Array:
	var f := func(u: float, v: float) -> Vector3:
		return _mask_point(u, v)
	var nf := func(u: float, v: float) -> Vector3:
		var q := _mask_fxy(u, v)
		return _head_n(_face_dir(q.x, q.y))
	var colf := func(u: float, v: float, _p: Vector3) -> Color:
		var q := _mask_fxy(u, v)
		var blush := 0.0
		for s: float in [-1.0, 1.0]:
			blush = maxf(blush, 1.0 - smoothstep(0.03, 0.14, (q - Vector2(s * 0.40, -0.19)).length()))
		return CREAM.lerp(BLUSH, blush * 0.5)
	return _grid(104, 36, f, colf, HEAD_C, nf)


static func _mask_fxy(u: float, v: float) -> Vector2:
	var psi := u * TAU
	var rho := v / 0.9 if v < 0.9 else 1.0 + (v - 0.9) / 0.1 * 0.035
	return MASK_O + Vector2(cos(psi), sin(psi)) * (_mask_edge(psi) * rho)


static func _mask_point(u: float, v: float) -> Vector3:
	var q := _mask_fxy(u, v)
	var d := _face_dir(q.x, q.y)
	var lift := MASK_LIFT if v < 0.9 else lerpf(MASK_LIFT, -0.006, (v - 0.9) / 0.1)
	return _head_pt(d) + _head_n(d) * lift


static func _head() -> Array:
	var f := func(u: float, v: float) -> Vector3:
		var th := v * PI
		var ph := u * TAU
		var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
		return _head_pt(d)
	var colf := func(_u: float, _v: float, p: Vector3) -> Color:
		return _head_col((p - HEAD_C).normalized())
	return _grid(96, 64, f, colf, HEAD_C)


## Ears (round cupped shells, facing the camera behind) and the brows.
static func _head_fur() -> Array:
	var parts: Array = []
	for s: float in [-1.0, 1.0]:
		# The ear's convex back faces +Z (turned outward) so it reads from
		# behind as a round ear with volume; the pale dished inside shows from
		# the front. Its inner edge is sunk well into the head.
		var xf := Transform3D(Basis(Vector3.UP, s * deg_to_rad(EAR_TURN)), EAR_C * Vector3(s, 1.0, 1.0))
		parts.append(_xf(_ear(), xf))
		# friendly raised brows
		var bp := PackedVector3Array()
		var br := PackedFloat32Array()
		var bc := PackedColorArray()
		for i in 11:
			var t := float(i) / 10.0
			var d := _face_dir(s * (0.16 + 0.26 * t), 0.44 + 0.055 * sin(t * PI) - 0.03 * t)
			bp.append(_head_pt(d) + _head_n(d) * 0.004)
			br.append(lerpf(0.011, 0.015, sin(t * PI)) * (1.0 - 0.3 * t))
			bc.append(FUR_DARK)
		parts.append(_tube(bp, br, bc, 12))
	return _merge(parts)


const EAR_C := Vector3(0.328, 1.505, 0.035)
const EAR_TURN := 22.0
const EAR_R := Vector2(0.104, 0.110)
const EAR_T := 0.030       # half-thickness of the rim / back
const EAR_DISH := 0.050    # how deep the front is dished


## One ear as ONE cupped shell: a convex back (+Z) with a soft light-to-dark
## fur gradient for volume, a thick rounded rim, and a dished front whose pale
## inner ear is painted in (no separate disc and ring, so no inner ink rings).
static func _ear() -> Array:
	var f := func(u: float, v: float) -> Vector3:
		var th := v * PI
		var ph := u * TAU
		var c := cos(th)
		var z: float
		if c >= 0.0:
			z = EAR_T * pow(c, 0.7)
		else:
			z = -EAR_T * pow(-c, 0.7) + EAR_DISH * c * c
		return Vector3(EAR_R.x * sin(th) * cos(ph), EAR_R.y * sin(th) * sin(ph), z)
	var colf := func(_u: float, v: float, _p: Vector3) -> Color:
		var c := cos(v * PI)
		if c >= 0.0:
			return FUR_DARK.lerp(FUR, 0.55 * c)
		return FUR_DARK.lerp(INNER_EAR, smoothstep(0.52, 0.76, -c))
	return _grid(40, 34, f, colf, Vector3.ZERO)


## Eye position / orientation: sat on the face, looking mostly forward.
static func _eye_xf(s: float) -> Transform3D:
	var d := _eye_dir(s)
	var n := _head_n(d)
	var ez := (n + Vector3(0.0, 0.0, -0.7)).normalized()
	var ey := (Vector3.UP - ez * ez.dot(Vector3.UP)).normalized()
	var ex := ey.cross(ez)
	return Transform3D(Basis(ex, ey, ez), _head_pt(d) - n * 0.013)


const EYE_R := Vector3(0.057, 0.067, 0.032)


## One eye, its pole looking straight out of the face (so the rings are
## concentric round the pupil): a black pupil, a warm brown iris that is
## lighter at the bottom, and a dark rim.
static func _eye() -> Array:
	var f := func(u: float, v: float) -> Vector3:
		var th := v * PI
		var ph := u * TAU
		return Vector3(sin(th) * cos(ph) * EYE_R.x, sin(th) * sin(ph) * EYE_R.y, cos(th) * EYE_R.z)
	var nf := func(u: float, v: float) -> Vector3:
		var th := v * PI
		var ph := u * TAU
		var d := Vector3(sin(th) * cos(ph), sin(th) * sin(ph), cos(th))
		return Vector3(d.x / EYE_R.x, d.y / EYE_R.y, d.z / EYE_R.z).normalized()
	var colf := func(u: float, v: float, _p: Vector3) -> Color:
		var th := rad_to_deg(v * PI)
		var low := clampf(-sin(u * TAU), 0.0, 1.0)
		var iris := IRIS.lerp(IRIS_LIGHT, 0.85 * low * smoothstep(20.0, 38.0, th))
		return EYE.lerp(iris, smoothstep(14.0, 19.0, th) * (1.0 - smoothstep(42.0, 49.0, th)))
	return _grid(40, 36, f, colf, Vector3.ZERO, nf)


## Big glossy eyes, the nose and the smile — the glossy dark bits.
static func _face_gloss() -> Array:
	var parts: Array = []
	for s: float in [-1.0, 1.0]:
		parts.append(_xf(_eye(), _eye_xf(s)))
	# nose: a small soft heart-ish button on top of the muzzle
	var nd := _face_dir(0.0, -0.20)
	var nn := _head_n(nd)
	var nz := nn
	var ny := (Vector3.UP - nz * nz.dot(Vector3.UP)).normalized()
	var nb := Basis(ny.cross(nz), ny, nz)
	parts.append(_ell(_head_pt(nd) - nn * 0.006, Vector3(0.036, 0.021, 0.020), NOSE, nb, 24, 14))
	# the smile
	var mp := PackedVector3Array()
	var mr := PackedFloat32Array()
	var mc := PackedColorArray()
	for i in 15:
		var t := float(i) / 14.0 * 2.0 - 1.0
		var d := _face_dir(t * 0.15, -0.44 + 0.085 * t * t)
		mp.append(_head_pt(d) + _head_n(d) * (MASK_LIFT + 0.0008))
		mr.append(lerpf(0.0085, 0.005, t * t))
		mc.append(NOSE)
	parts.append(_tube(mp, mr, mc, 10))
	return _merge(parts)


## Catchlights, mirrored per eye (a big one upper-outer, a small one
## lower-inner) and sat ON the eye's surface, so both eyes sparkle from any
## title-screen angle.
static func _catchlights() -> Array:
	var parts: Array = []
	for s: float in [-1.0, 1.0]:
		var xf := _eye_xf(s)
		for spec: Vector3 in [Vector3(-0.24 * s, 0.40, 0.0135), Vector3(0.30 * s, -0.34, 0.0065)]:
			var zl := EYE_R.z * sqrt(maxf(0.0, 1.0 - spec.x * spec.x - spec.y * spec.y))
			var pl := Vector3(spec.x * EYE_R.x, spec.y * EYE_R.y, zl)
			var nl := Vector3(pl.x / (EYE_R.x * EYE_R.x), pl.y / (EYE_R.y * EYE_R.y),
				pl.z / (EYE_R.z * EYE_R.z)).normalized()
			var bz := (xf.basis * nl).normalized()
			var bx := (xf.basis.x - bz * xf.basis.x.dot(bz)).normalized()
			var by := bz.cross(bx)
			parts.append(_ell(xf * pl - bz * spec.z * 0.08, Vector3(spec.z, spec.z, spec.z * 0.4),
				Color(1.0, 1.0, 1.0), Basis(bx, by, bz), 16, 10))
	return _merge(parts)


# ---- cap ------------------------------------------------------------------------

static func _cap_axes() -> Array:
	var a := Vector3(0.0, 1.0, CAP_TILT).normalized()
	var f := (Vector3(0.0, 0.0, -1.0) - a * a.dot(Vector3(0.0, 0.0, -1.0))).normalized()
	return [a, f, a.cross(f)]


static func _cap_t(alpha: float, top: float) -> float:
	if alpha <= CAP_AB:
		var rho := alpha / CAP_AB
		return CAP_TE + (top - CAP_TE) * (1.0 - rho * rho) * (1.0 - 0.25 * rho * rho)
	var w := clampf((alpha - CAP_AB) / CAP_LIP, 0.0, 1.0)
	return lerpf(CAP_TE, -0.02, smoothstep(0.0, 1.0, w))


static func _cap_pt(u: float, v: float, top: float) -> Vector3:
	var ax: Array = _cap_axes()
	var a: Vector3 = ax[0]
	var f: Vector3 = ax[1]
	var sd: Vector3 = ax[2]
	var alpha: float
	if v <= 0.84:
		alpha = v / 0.84 * CAP_AB
	else:
		alpha = CAP_AB + (v - 0.84) / 0.16 * CAP_LIP
	var psi := u * TAU
	var d := a * cos(alpha) + (f * cos(psi) + sd * sin(psi)) * sin(alpha)
	return HEAD_C + d * (_head_r(d) + _cap_t(alpha, top))


## The dome's thickness at the crown that lands its top on CAP_TOP.
static func _cap_top() -> float:
	var top := 0.07
	for _it in 4:
		var hi := -1e9
		for j in 12:
			for i in 24:
				hi = maxf(hi, _cap_pt(float(i) / 24.0, float(j) / 40.0, top).y)
		top += CAP_TOP - hi
	return top


static func _cap() -> Array:
	var parts: Array = []
	var top := _cap_top()
	var f := func(u: float, v: float) -> Vector3:
		return _cap_pt(u, v, top)
	parts.append(_grid(64, 40, f, CAP, HEAD_C))
	# six panel seams running up to the button
	var ax: Array = _cap_axes()
	var a: Vector3 = ax[0]
	var fr: Vector3 = ax[1]
	var sd: Vector3 = ax[2]
	for k in 6:
		var psi := TAU * (float(k) + 0.5) / 6.0
		var sp := PackedVector3Array()
		var sr := PackedFloat32Array()
		var sc := PackedColorArray()
		for i in 13:
			var alpha := lerpf(0.10, CAP_AB * 0.985, float(i) / 12.0)
			var d := a * cos(alpha) + (fr * cos(psi) + sd * sin(psi)) * sin(alpha)
			sp.append(HEAD_C + d * (_head_r(d) + _cap_t(alpha, top) + 0.0012))
			sr.append(0.0042)
			sc.append(BRIM)
		parts.append(_tube(sp, sr, sc, 8))
	# the button
	var bpos := HEAD_C + a * (_head_r(a) + _cap_t(0.0, top) - 0.004)
	parts.append(_ell(bpos, Vector3(0.03, 0.014, 0.03), CAP,
		Basis(Vector3.RIGHT, atan(CAP_TILT)), 24, 12))
	# the snapback opening at the front (worn backwards, so it shows on the brow)
	var op := PackedVector3Array()
	var orr := PackedFloat32Array()
	var oc := PackedColorArray()
	for i in 15:
		var t := float(i) / 14.0
		var psi := PI * 1.0 + (t - 0.5) * 0.9
		var alpha := CAP_AB - 0.20 * sin(t * PI)
		var d := a * cos(alpha) + (fr * cos(psi + PI) + sd * sin(psi + PI)) * sin(alpha)
		op.append(HEAD_C + d * (_head_r(d) + _cap_t(alpha, top) + 0.001))
		orr.append(0.009)
		oc.append(BRIM)
	parts.append(_tube(op, orr, oc, 10))
	parts.append(_brim())
	return _merge(parts)


## The brim, sticking out BEHIND (+Z) over the nape, curved down at its sides.
static func _brim() -> Array:
	var ax: Array = _cap_axes()
	var a: Vector3 = ax[0]
	var fr: Vector3 = ax[1]
	var db := a * cos(CAP_AB) - fr * sin(CAP_AB)
	var pb := HEAD_C + db * (_head_r(db) + CAP_TE * 0.5)
	var droop := deg_to_rad(6.0)
	var out := (-fr * cos(droop) - a * sin(droop)).normalized()
	var bx := Vector3.RIGHT
	var by := out.cross(bx).normalized()
	var f := func(u: float, v: float) -> Vector3:
		var th := v * PI - PI * 0.5
		var ph := u * TAU - PI
		var ct := _sp(cos(th), 0.45)
		var st := _sp(sin(th), 0.45)
		var xl := 0.172 * ct * _sp(cos(ph), 0.75)
		var zl := 0.160 * ct * _sp(sin(ph), 0.75) + 0.035
		var yl := -0.011 * st - 0.85 * xl * xl
		return pb + bx * xl + by * yl + out * zl
	return _grid(48, 12, f, BRIM, pb + out * 0.035)


# ---- limbs ----------------------------------------------------------------------

## The sleeve: a full soft deltoid at the shoulder that blends into the yoke,
## tapering to the elbow, where the fabric bunches in two soft ripples.
static func _sleeve() -> Array:
	var p := PackedVector3Array()
	var r := PackedFloat32Array()
	var c := PackedColorArray()
	for i in 25:
		var t := float(i) / 24.0
		p.append(Vector3(0.0, -0.36 * t, 0.0))
		var rr := _keys(t, PackedFloat32Array([0.0, 0.088, 0.22, 0.083, 0.5, 0.075, 0.78, 0.070,
			1.0, 0.068]))
		var w := clampf((t - 0.72) / 0.28, 0.0, 1.0)
		rr += 0.0055 * pow(sin(w * TAU), 2.0)
		r.append(rr)
		c.append(SLEEVE)
	return _tube(p, r, c, 30)


static func _forearm() -> Array:
	var parts: Array = []
	var p := PackedVector3Array()
	var r := PackedFloat32Array()
	var c := PackedColorArray()
	for i in 7:
		var t := float(i) / 6.0
		p.append(Vector3(0.0, -0.15 * t, 0.0))
		r.append(lerpf(0.066, 0.060, t))
		c.append(SLEEVE)
	parts.append(_tube(p, r, c, 30))
	# ribbed cuff, flaring a touch
	var cp := PackedVector3Array()
	var cr := PackedFloat32Array()
	var cc := PackedColorArray()
	for i in 7:
		var t := float(i) / 6.0
		cp.append(Vector3(0.0, lerpf(-0.138, -0.198, t), 0.0))
		cr.append(lerpf(0.0615, 0.068, smoothstep(0.0, 1.0, t)) + 0.0012 * sin(t * PI * 6.0))
		cc.append(CUFF)
	parts.append(_tube(cp, cr, cc, 30, 1.0, PackedVector3Array(), 1.0, 0.35))
	return _merge(parts)


## A soft cartoon fist. `inner` is +1 when the body is toward +X.
## Kept within |x| <= 0.066 of the wrist line (the rig test boxes it).
static func _hand(inner: float) -> Array:
	var o := Vector3(0.0, -0.27, 0.0)
	var parts: Array = []
	# wrist, up into the cuff
	parts.append(_tube(PackedVector3Array([o + Vector3(0.0, 0.10, 0.0), o + Vector3(0.0, 0.03, 0.0)]),
		PackedFloat32Array([0.043, 0.047]), PackedColorArray([HAND, HAND]), 20))
	# palm
	parts.append(_sbox(o + Vector3(0.0, -0.004, 0.0), Vector3(0.052, 0.062, 0.058), 0.72, HAND,
		Basis(), 28, 18))
	# four curled fingers along the bottom, knuckles forward
	for k in 4:
		var z := -0.037 + 0.0247 * float(k)
		var c := o + Vector3(inner * 0.006, -0.056 + 0.004 * absf(float(k) - 1.5), z)
		parts.append(_tube(PackedVector3Array([c + Vector3(-0.026, 0.004, 0.0),
			c + Vector3(0.026, -0.002, 0.0)]), PackedFloat32Array([0.0205, 0.0195]),
			PackedColorArray([HAND, HAND]), 14))
	# thumb, wrapping over the front of the fist on the body side
	parts.append(_tube(PackedVector3Array([o + Vector3(inner * 0.036, 0.026, -0.030),
		o + Vector3(inner * 0.044, -0.006, -0.048), o + Vector3(inner * 0.026, -0.030, -0.056)]),
		PackedFloat32Array([0.022, 0.020, 0.018]), PackedColorArray([HAND, HAND, HAND]), 14))
	return _merge(parts)


## Baggy knee-length shorts leg, flaring toward a darker hem, with the white
## side stripe running from the hip down to the hem.
const SHORTS_TOP := 0.06
const SHORTS_HEM := -0.25


static func _shorts_r(y: float) -> float:
	var t := clampf((SHORTS_TOP - y) / (SHORTS_TOP - SHORTS_HEM), 0.0, 1.0)
	return lerpf(0.110, 0.126, pow(t, 1.3))


static func _shorts_leg(side: float) -> Array:
	var parts: Array = []
	var p := PackedVector3Array()
	var r := PackedFloat32Array()
	var c := PackedColorArray()
	for i in 13:
		var t := float(i) / 12.0
		var y := lerpf(SHORTS_TOP, SHORTS_HEM, t)
		p.append(Vector3(0.0, y, 0.0))
		r.append(_shorts_r(y))
		c.append(SHORTS.lerp(WAISTBAND, smoothstep(0.86, 0.93, t)))
	parts.append(_tube(p, r, c, 34, 1.0, PackedVector3Array(), 1.0, 0.28))
	# a white side stripe, sporty: over the hip (following the rounded top)
	# and down to the hem band
	var sp := PackedVector3Array()
	var sr := PackedFloat32Array()
	var sc := PackedColorArray()
	var su := PackedVector3Array()
	for i in 13:
		var t := float(i) / 12.0
		var y := lerpf(SHORTS_TOP + 0.075, SHORTS_HEM + 0.035, t)
		var rr := _shorts_r(y)
		var x := rr
		var n := Vector3(side, 0.0, 0.0)
		if y > SHORTS_TOP:
			var dy := y - SHORTS_TOP
			x = sqrt(maxf(rr * rr - dy * dy, 0.0))
			n = Vector3(side * x, dy, 0.0).normalized()
		sp.append(Vector3(0.0, SHORTS_TOP, 0.0) + (n * (rr + 0.0015) if y > SHORTS_TOP
			else Vector3(side * (rr + 0.0015), y - SHORTS_TOP, 0.0)))
		sr.append(0.016)
		sc.append(STRIPE)
		su.append(n)
	parts.append(_tube(sp, sr, sc, 12, 0.3, su, 0.4, 0.2))
	return _merge(parts)


static func _thigh() -> Array:
	return _tube(PackedVector3Array([Vector3(0.0, -0.12, 0.0), Vector3(0.0, -0.21, 0.0),
		Vector3(0.0, -0.30, 0.0)]), PackedFloat32Array([0.084, 0.078, 0.071]),
		PackedColorArray([FUR, FUR, FUR]), 26)


## The shin: a soft knee at the top, a real calf bulging behind a third of
## the way down, and a slim ankle so the sneaker collar reads.
static func _shin() -> Array:
	var p := PackedVector3Array()
	var r := PackedFloat32Array()
	var c := PackedColorArray()
	for i in 12:
		var t := float(i) / 11.0
		var calf := exp(-pow((t - 0.32) / 0.22, 2.0))
		p.append(Vector3(0.0, -0.22 * t, 0.0065 * calf - 0.004 * exp(-pow(t / 0.10, 2.0))))
		r.append(_keys(t, PackedFloat32Array([0.0, 0.069, 0.10, 0.071, 0.32, 0.078, 0.62, 0.064,
			1.0, 0.050])))
		c.append(FUR)
	return _tube(p, r, c, 28)


# ---- sneaker ------------------------------------------------------------------

## Sneaker upper height / half width along its length (w: 0 toe .. 1 heel).
static func _shoe_h(w: float) -> float:
	return 0.054 + 0.082 * smoothstep(0.30, 0.86, w)


static func _shoe_hx(w: float) -> float:
	return 0.083 + 0.007 * sin(PI * clampf((1.0 - w) * 1.25, 0.0, 1.0))


static func _shoe_f(u: float, v: float) -> Vector3:
	var th := v * PI - PI * 0.5
	var ph := u * TAU - PI
	var ct := _sp(cos(th), 0.72)
	var st := _sp(sin(th), 0.72)
	var xh := ct * _sp(cos(ph), 0.55)
	var yh := -st
	var zh := ct * _sp(sin(ph), 0.55)
	var w := (zh + 1.0) * 0.5
	return Vector3(xh * _shoe_hx(w), -0.124 + (yh + 1.0) * 0.5 * _shoe_h(w), -0.062 + zh * 0.148)


## Chunky white sneaker on a red sole. Sole bottom at ankle-local y = -0.16.
static func _sneaker() -> Array:
	var parts: Array = []
	# red outsole, a white midsole on it, and darker tread lugs underneath that
	# are what actually touch y = -0.16 (you see them every time a foot kicks back)
	parts.append(_sbox(Vector3(0.0, -0.1385, -0.062), Vector3(0.100, 0.0175, 0.158), 0.45, SOLE,
		Basis(), 40, 14))
	parts.append(_sbox(Vector3(0.0, -0.1195, -0.062), Vector3(0.095, 0.0105, 0.151), 0.40,
		MIDSOLE, Basis(), 40, 10))
	parts.append(_sbox(Vector3(0.0, -0.1545, 0.040), Vector3(0.076, 0.0055, 0.040), 0.4, TREAD,
		Basis(), 24, 8))
	for z: float in [-0.052, -0.110, -0.166]:
		var hw := 0.084 if z > -0.15 else 0.066
		parts.append(_sbox(Vector3(0.0, -0.1545, z), Vector3(hw, 0.0055, 0.019), 0.4, TREAD,
			Basis(), 24, 8))
	parts.append(_grid(40, 24, _shoe_f, SNEAKER, Vector3(0.0, -0.08, -0.06)))
	# heel tab, the flash of red you see from behind on every stride
	parts.append(_sbox(Vector3(0.0, 0.004, 0.094), Vector3(0.030, 0.034, 0.011), 0.5, SOLE,
		Basis(Vector3.RIGHT, -0.28), 20, 10))
	# padded collar round the ankle
	parts.append(_torus(0.056, 0.019, SOLE, Transform3D(
		Basis(Vector3.RIGHT, PI * 0.5 - 0.12), Vector3(0.0, 0.002, 0.022)), 32, 12))
	# tongue
	parts.append(_sbox(Vector3(0.0, -0.008, -0.044), Vector3(0.037, 0.030, 0.008), 0.5, SNEAKER,
		Basis(Vector3.RIGHT, -0.60), 20, 10))
	# laces
	for w: float in [0.43, 0.53, 0.63]:
		var z := -0.062 + (w * 2.0 - 1.0) * 0.148
		var y := -0.124 + _shoe_h(w) + 0.003
		parts.append(_tube(PackedVector3Array([Vector3(-0.034, y - 0.009, z), Vector3(0.0, y, z),
			Vector3(0.034, y - 0.009, z)]), PackedFloat32Array([0.0062, 0.0070, 0.0062]),
			PackedColorArray([LACE, LACE, LACE]), 10))
	# a red swoosh on each side
	for sgn: float in [-1.0, 1.0]:
		var sp := PackedVector3Array()
		var sr := PackedFloat32Array()
		var sc := PackedColorArray()
		var su := PackedVector3Array()
		for i in 10:
			var t := float(i) / 9.0
			var w := lerpf(0.80, 0.30, t)
			var yf := 0.30 + 0.30 * sin(t * PI * 0.85)
			var zz := -0.062 + (w * 2.0 - 1.0) * 0.148
			var shrink := pow(maxf(0.0, 1.0 - pow(absf(w * 2.0 - 1.0), 2.0 / 0.55)), 0.55 * 0.5)
			sp.append(Vector3(sgn * (_shoe_hx(w) * shrink + 0.0005), -0.124 + yf * _shoe_h(w), zz))
			sr.append(lerpf(0.013, 0.006, t))
			sc.append(SOLE)
			su.append(Vector3(sgn, 0.0, 0.0))
		parts.append(_tube(sp, sr, sc, 12, 0.3, su, 0.5, 0.5))
	return _merge(parts)


# =============================================================================
#  MESH TOOLKIT (vertex-coloured, indexed, correct normals)
#  A "part" is [verts, normals, colours, indices].
# =============================================================================

## The character material, taking its colour from the vertices.
static func _vc(rough: float, spec: float, rim: float, ink: float = 0.012) -> StandardMaterial3D:
	var m := SM.mat(Color(1.0, 1.0, 1.0), rough, spec, rim, ink)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


## Adds a part as a MeshInstance3D at `pos` (the part is given in parent space).
static func _place(parent: Node, owner: Node, node_name: String, part: Array, pos: Vector3,
		material: Material) -> MeshInstance3D:
	var local := _xf(part, Transform3D(Basis(), -pos))
	return SM.add(parent, owner, node_name, _mesh(local), Transform3D(Basis(), pos), material)


static func _mesh(part: Array) -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = part[0]
	arr[Mesh.ARRAY_NORMAL] = part[1]
	arr[Mesh.ARRAY_COLOR] = part[2]
	arr[Mesh.ARRAY_INDEX] = part[3]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _merge(parts: Array) -> Array:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var idx := PackedInt32Array()
	for part: Array in parts:
		var off := vs.size()
		var pv: PackedVector3Array = part[0]
		var pn: PackedVector3Array = part[1]
		var pc: PackedColorArray = part[2]
		var pi: PackedInt32Array = part[3]
		vs.append_array(pv)
		ns.append_array(pn)
		cs.append_array(pc)
		for k in pi:
			idx.append(k + off)
	return [vs, ns, cs, idx]


## Transforms a part (normals by the inverse transpose, so even a squash is right).
static func _xf(part: Array, t: Transform3D) -> Array:
	var pv: PackedVector3Array = part[0]
	var pn: PackedVector3Array = part[1]
	var nb := t.basis.inverse().transposed()
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	vs.resize(pv.size())
	ns.resize(pn.size())
	for k in pv.size():
		vs[k] = t * pv[k]
		ns[k] = (nb * pn[k]).normalized()
	return [vs, ns, part[2], part[3]]


## Triangulates a rows x cols vertex grid, winding every triangle so it faces
## the way its normals do (Godot's front faces are clockwise).
static func _tris(vs: PackedVector3Array, ns: PackedVector3Array, cs: PackedColorArray,
		rows: int, cols: int) -> Array:
	var idx := PackedInt32Array()
	for j in rows - 1:
		for i in cols - 1:
			var a := j * cols + i
			var b := (j + 1) * cols + i
			var c := (j + 1) * cols + i + 1
			var d := j * cols + i + 1
			for k in 2:
				var i1 := b if k == 0 else c
				var i2 := c if k == 0 else d
				var p0 := vs[a]
				var g := (vs[i2] - p0).cross(vs[i1] - p0)
				if g.length_squared() < 1e-16:
					continue
				if g.dot(ns[a] + ns[i1] + ns[i2]) >= 0.0:
					idx.append(a)
					idx.append(i1)
					idx.append(i2)
				else:
					idx.append(a)
					idx.append(i2)
					idx.append(i1)
	return [vs, ns, cs, idx]


## A parametric surface f(u, v) -> point, u around (0..1), v across (0..1).
## Normals come from `nf` if given, otherwise from the surface itself
## (central differences), oriented away from `center`.
static func _grid(seg: int, rings: int, f: Callable, col: Variant, center: Vector3,
		nf: Callable = Callable()) -> Array:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var e := 0.0006
	var score := 0.0
	for j in rings + 1:
		var v := float(j) / float(rings)
		for i in seg + 1:
			var u := float(i) / float(seg)
			var p: Vector3 = f.call(u, v)
			var n: Vector3
			if nf.is_valid():
				n = nf.call(u, v)
			else:
				var vv := clampf(v, 0.004, 0.996)
				var du: Vector3 = f.call(u + e, vv) - f.call(u - e, vv)
				var dv: Vector3 = f.call(u, vv + e) - f.call(u, vv - e)
				n = du.cross(dv).normalized()
				score += n.dot(p - center)
			vs.append(p)
			ns.append(n)
			if col is Color:
				cs.append(col)
			else:
				var cf: Callable = col
				cs.append(cf.call(u, v, p))
	if score < 0.0:
		for k in ns.size():
			ns[k] = -ns[k]
	return _tris(vs, ns, cs, rings + 1, seg + 1)


static func _ell(c: Vector3, r: Vector3, col: Color, b: Basis = Basis(), seg: int = 32,
		rings: int = 20) -> Array:
	var f := func(u: float, v: float) -> Vector3:
		var th := v * PI
		var ph := u * TAU
		return Vector3(sin(th) * cos(ph) * r.x, cos(th) * r.y, sin(th) * sin(ph) * r.z)
	var nf := func(u: float, v: float) -> Vector3:
		var th := v * PI
		var ph := u * TAU
		var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
		return Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized()
	return _xf(_grid(seg, rings, f, col, Vector3.ZERO, nf), Transform3D(b, c))


## A superellipsoid: e ~0.3 soft box .. 1.0 ellipsoid.
static func _sbox(c: Vector3, half: Vector3, e: float, col: Color, b: Basis = Basis(),
		seg: int = 32, rings: int = 20) -> Array:
	var f := func(u: float, v: float) -> Vector3:
		var th := v * PI - PI * 0.5
		var ph := u * TAU - PI
		var ct := _sp(cos(th), e)
		return Vector3(half.x * ct * _sp(cos(ph), e), -half.y * _sp(sin(th), e),
			half.z * ct * _sp(sin(ph), e))
	var nf := func(u: float, v: float) -> Vector3:
		var th := v * PI - PI * 0.5
		var ph := u * TAU - PI
		var ct2 := _sp(cos(th), 2.0 - e)
		var n := Vector3(ct2 * _sp(cos(ph), 2.0 - e) / half.x, -_sp(sin(th), 2.0 - e) / half.y,
			ct2 * _sp(sin(ph), 2.0 - e) / half.z)
		if n.length_squared() < 1e-12:
			n = Vector3(0.0, -signf(sin(th)), 0.0)
		return n.normalized()
	return _xf(_grid(seg, rings, f, col, Vector3.ZERO, nf), Transform3D(b, c))


## A torus in the XY plane (facing Z), placed by xf.
static func _torus(big: float, small: float, col: Color, xf: Transform3D, seg: int = 36,
		rings: int = 14) -> Array:
	var f := func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var b := v * TAU
		return Vector3((big + small * cos(b)) * cos(a), (big + small * cos(b)) * sin(a),
			small * sin(b))
	var nf := func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var b := v * TAU
		return Vector3(cos(b) * cos(a), cos(b) * sin(a), sin(b))
	return _xf(_grid(seg, rings, f, col, Vector3.ZERO, nf), xf)


## A closed ring round the body at height y (ellipse rx x rz), tube radius r.
static func _hoop(y: float, rx: float, rz: float, r: float, col: Color, zo: float = 0.0) -> Array:
	var f := func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var b := v * TAU
		var radial := Vector3(cos(a) / rx, 0.0, sin(a) / rz).normalized()
		return Vector3(rx * cos(a), y, rz * sin(a) + zo) + radial * (r * cos(b)) + Vector3.UP * (r * sin(b))
	var nf := func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var b := v * TAU
		var radial := Vector3(cos(a) / rx, 0.0, sin(a) / rz).normalized()
		return radial * cos(b) + Vector3.UP * sin(b)
	return _grid(64, 10, f, col, Vector3(0.0, y, zo), nf)


## A smooth swept tube with rounded (ellipsoidal) end caps. `flat` squashes the
## cross-section along `ups` (per-point) — used for straps and stripes.
## cap0 / cap1 scale the depth of each end cap (0 = flat end).
static func _tube(pts: PackedVector3Array, rad: PackedFloat32Array, col: PackedColorArray,
		sides: int = 24, flat: float = 1.0, ups: PackedVector3Array = PackedVector3Array(),
		cap0: float = 1.0, cap1: float = 1.0) -> Array:
	var n := pts.size()
	var tan := PackedVector3Array()
	for i in n:
		tan.append((pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized())
	var nor := PackedVector3Array()
	if ups.size() == n:
		for i in n:
			nor.append((ups[i] - tan[i] * ups[i].dot(tan[i])).normalized())
	else:
		var cur := tan[0].cross(Vector3.UP)
		if cur.length_squared() < 1e-6:
			cur = tan[0].cross(Vector3.RIGHT)
		cur = cur.normalized()
		for i in n:
			if i > 0:
				var axis := tan[i - 1].cross(tan[i])
				if axis.length_squared() > 1e-12:
					cur = cur.rotated(axis.normalized(), tan[i - 1].angle_to(tan[i]))
			cur = (cur - tan[i] * cur.dot(tan[i])).normalized()
			nor.append(cur)
	var cr := maxi(5, int(float(sides) / 3.0))
	var rows := cr + n + cr
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	for row in rows:
		var i: int
		var beta: float
		var axis_out: Vector3
		var dep: float
		var body := false
		if row < cr:
			i = 0
			beta = PI * 0.5 * float(row) / float(cr)
			axis_out = -tan[0]
			dep = rad[0] * cap0
		elif row < cr + n:
			i = row - cr
			beta = PI * 0.5
			axis_out = tan[i]
			dep = 0.0
			body = true
		else:
			i = n - 1
			beta = PI * 0.5 * float(rows - 1 - row) / float(cr)
			axis_out = tan[n - 1]
			dep = rad[n - 1] * cap1
		var r := rad[i]
		var ra := r * flat
		var rb := r
		var nn := nor[i]
		var bb := tan[i].cross(nn).normalized()
		var c := pts[i]
		var sb := sin(beta)
		var cb := cos(beta)
		var slope := 0.0
		if body:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, n - 1)
			var dl := pts[i0].distance_to(pts[i1])
			if dl > 1e-6:
				slope = (rad[i1] - rad[i0]) / dl
		for s in sides + 1:
			var th := TAU * float(s) / float(sides)
			var ca := cos(th)
			var sa := sin(th)
			vs.append(c + nn * (ra * ca * sb) + bb * (rb * sa * sb) + axis_out * (dep * cb))
			var q: Vector3
			if body:
				q = (nn * (ca / ra) + bb * (sa / rb)).normalized()
				q = (q - tan[i] * slope).normalized()
			else:
				q = (nn * (ca * sb / ra) + bb * (sa * sb / rb)
					+ axis_out * (cb / maxf(dep, 1e-4))).normalized()
			ns.append(q)
			cs.append(col[i])
	return _tris(vs, ns, cs, rows, sides + 1)


## Catmull-Rom through control points, `per` samples per span.
static func _spline(ctrl: PackedVector3Array, per: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := ctrl.size()
	for i in n - 1:
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p0 := ctrl[i - 1] if i > 0 else p1 * 2.0 - p2
		var p3 := ctrl[i + 2] if i + 2 < n else p2 * 2.0 - p1
		for k in per:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(k) / float(per)))
	out.append(ctrl[n - 1])
	return out


## Smooth 0..1 bump on the unit sphere around direction c, footprint wa x wb.
static func _bump(d: Vector3, c: Vector3, wa: float, wb: float) -> float:
	var cn := c.normalized()
	if d.dot(cn) <= 0.0:
		return 0.0
	var e1 := Vector3.UP.cross(cn).normalized()
	var e2 := cn.cross(e1).normalized()
	var a := d.dot(e1) / wa
	var b := d.dot(e2) / wb
	var t2 := a * a + b * b
	if t2 >= 1.0:
		return 0.0
	var q := 1.0 - t2
	return q * q * (3.0 - 2.0 * q)


## Piecewise Catmull-Rom through [x0, y0, x1, y1, ...].
static func _keys(x: float, k: PackedFloat32Array) -> float:
	var m := k.size()
	if x <= k[0]:
		return k[1]
	var i := 0
	while i + 2 < m:
		if x <= k[i + 2]:
			var t := (x - k[i]) / (k[i + 2] - k[i])
			var pre := k[i + 1] if i == 0 else k[i - 1]
			var post := k[i + 3] if i + 4 >= m else k[i + 5]
			return cubic_interpolate(k[i + 1], k[i + 3], pre, post, t)
		i += 2
	return k[m - 1]


static func _sp(c: float, p: float) -> float:
	return signf(c) * pow(absf(c), p)
