extends RefCounted
const SM := preload("res://tools/smooth_mesh.gd")
## BRUNO — the silverback who chases you.
##
## Sculpted, not assembled. Every part of him (torso, head, each arm, each
## leg) is ONE smooth surface: a handful of soft shapes (eggs, tapered
## limbs) melted into each other with a smooth blend, the way clay is
## smoothed with a thumb, then turned into a mesh whose normals come
## straight from the shape — so there are no seams, no creases where two
## balls meet, and the light rolls over the muscle like it should.
##
## JOINTS. The torso owns a ball socket at each shoulder and hip, centred
## exactly on the limb's pivot; the limb's top is a slightly smaller ball on
## the same centre, hidden inside it. However far the limb swings, it turns
## inside its socket: nothing pops out, and no gap opens. Each arm is
## sculpted whole (shoulder to knuckles) and only then cut at the elbow into
## the upper arm and the forearm, so the two halves meet edge to edge with
## no seam at all (chaser.gd never bends the elbow).
##
## Colour is painted onto the surface (vertex colour), not built from
## separate coloured pieces: the silver saddle over the lower back and rump,
## fading into black up towards the shoulder blades and down the flanks and
## thighs, with the hair streaking down and out from the spine; the tops of
## the torso and head a shade lighter so the form reads from the chase
## camera (only on parts that never swing, so the light never moves with a
## limb); the face, chest, fingers and soles leathery skin.
##
## He is seen mostly from above and behind, so the shoulder mass, the
## sloping back, the silver saddle and the peaked crest carry the design.
## Faces -Z. Rig (animated by scripts/chaser.gd): LegL/LegR, ArmL/ArmR (+
## Elbow, Hand), Head.

## Albedo is sRGB: black fur at 0.10 renders as a flat hole under the
## game's tonemapper, so the base sits a touch higher and the sheen (rim)
## does the rest. The greys lean a hair green/blue, because the warm sun plus
## the blue sky tint neutral greys plum.
const FUR := Color(0.15, 0.15, 0.145)
const FUR_TOP := Color(0.26, 0.265, 0.255)
const SILVER := Color(0.46, 0.455, 0.41)
const CROWN := Color(0.19, 0.14, 0.105)
const SKIN := Color(0.125, 0.113, 0.108)
const SKIN_DARK := Color(0.06, 0.05, 0.05)
const EYE := Color(0.10, 0.06, 0.035)

## The rig's joints (right side; the left mirrors x).
const SHOULDER := Vector3(0.64, 1.46, -0.30)
const HIP := Vector3(0.24, 0.66, 0.08)
const HEAD_POS := Vector3(0.0, 1.60, -0.56)
const ELBOW_Y := -0.62
## Sockets: the torso's ball at each joint, and the limb's own (smaller)
## ball inside it.
const SHOULDER_SOCKET := 0.198
const SHOULDER_BALL := 0.19
const HIP_SOCKET := 0.18
const HIP_BALL := 0.173
## The head is sculpted at 1:1 and shown a touch larger, pushed forward of
## the pivot so the face clears the chest.
const HEAD_SCALE := 1.12
const HEAD_OFFSET := Vector3(0.0, -0.06, -0.06)

## Which part a surface belongs to, for painting.
const PART_TORSO := 0
const PART_HEAD := 1
const PART_ARM := 2
const PART_LEG := 3

# Primitive record layout (an Array, so the whole sculpt is plain data).
const P_KIND := 0     # 0 ellipsoid, 1 tapered capsule (round cone)
const P_OP := 1       # 0 blend in, 1 carve out
const P_K := 2        # blend radius, metres
const P_COL := 3
const P_SKIN := 4     # 0 fur .. 1 bare skin (no light lift, no silver)
const P_BC := 5       # bounding sphere centre / radius (for skipping)
const P_BR := 6
const P_C := 7        # ellipsoid centre, radii, inverse rotation
const P_R := 8
const P_INV := 9
const P_A := 10       # round cone ends and radii
const P_B := 11
const P_R1 := 12
const P_R2 := 13

# Sculpt result layout.
const S_VERTS := 0
const S_NORMALS := 1
const S_COLORS := 2
const S_INDEX := 3


static func build(body: Node3D, owner: Node) -> void:
	var fur := _fur_material()

	# ---- Torso: shoulders, back, saddle, belly, rump, and the sockets ---
	SM.add(body, owner, "Torso",
		_mesh(_sculpt(_torso_prims(), 0.017, Transform3D(), PART_TORSO, 0.0)),
		Transform3D(), fur)

	# ---- Head, carried low and forward --------------------------------
	var head := SM.pivot(body, owner, "Head", HEAD_POS)
	var hs := HEAD_SCALE
	var head_xf := Transform3D(Basis.from_scale(Vector3(hs, hs, hs)), HEAD_OFFSET)
	SM.add(head, owner, "Skull",
		_mesh(_sculpt(_head_prims(), 0.0095, Transform3D(Basis(), HEAD_POS) * head_xf, PART_HEAD, 0.0)),
		head_xf, fur)
	var eye_mat := SM.mat(EYE, 0.18, 0.4, 0.0, 0.0)
	var glint_mat := SM.mat(Color(1.0, 0.97, 0.9), 0.3, 0.0, 0.0, 0.0, 1.6)
	for s: float in [-1.0, 1.0]:
		var ec := HEAD_OFFSET + Vector3(s * 0.062, -0.014, -0.170) * hs
		SM.add(head, owner, "Eye" + _side_name(s), SM.ellipsoid(Vector3.ONE * 0.019 * hs, 24, 14),
			Transform3D(Basis(), ec), eye_mat)
		SM.add(head, owner, "Glint" + _side_name(s), SM.ellipsoid(Vector3.ONE * 0.0035 * hs, 10, 6),
			Transform3D(Basis(), ec + Vector3(s * 0.004, 0.008, -0.0175) * hs), glint_mat)

	# ---- Arms: shoulder -> elbow -> knuckles on the ground --------------
	for s: float in [-1.0, 1.0]:
		var shoulder := Vector3(s * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		var arm := SM.pivot(body, owner, "Arm" + _side_name(s), shoulder)
		var whole := _sculpt(_arm_prims(s), 0.0125, Transform3D(Basis(), shoulder), PART_ARM, s)
		var halves := _split(whole, ELBOW_Y)
		SM.add(arm, owner, "UpperArm", halves[0], Transform3D(), fur)
		var elbow := SM.pivot(arm, owner, "Elbow", Vector3(0.0, ELBOW_Y, 0.0))
		SM.add(elbow, owner, "Forearm", halves[1], Transform3D(), fur)
		var m := Marker3D.new()
		m.name = "Hand"
		m.position = Vector3(0.0, -0.64, -0.1)
		elbow.add_child(m)
		m.owner = owner

	# ---- Legs: short, thick and bowed ----------------------------------
	for s: float in [-1.0, 1.0]:
		var hip := Vector3(s * HIP.x, HIP.y, HIP.z)
		var leg := SM.pivot(body, owner, "Leg" + _side_name(s), hip)
		SM.add(leg, owner, "Leg",
			_mesh(_sculpt(_leg_prims(s), 0.016, Transform3D(Basis(), hip), PART_LEG, s)),
			Transform3D(), fur)


static func _side_name(s: float) -> String:
	return "L" if s < 0.0 else "R"


# =============================================================================
#  THE SCULPT — the shapes each part is made of
# =============================================================================

static func _torso_prims() -> Array:
	var p: Array = []
	# The trunk: one long egg along the spine, which slopes from the high
	# shoulders down to the rump, the way a knuckle-walker carries himself.
	p.append(_ell(Vector3(0.0, 1.20, -0.10), Vector3(0.35, 0.30, 0.46), Vector3(deg_to_rad(32.0), 0.0, 0.0), 0.1, FUR))
	# The huge upper back: trapezius rising to the back of the skull — the
	# widest, highest mass on him.
	p.append(_ell(Vector3(0.0, 1.50, -0.25), Vector3(0.44, 0.23, 0.30), Vector3(deg_to_rad(18.0), 0.0, 0.0), 0.16, FUR))
	# Shoulder girdle: the width that carries out to the sockets.
	p.append(_ell(Vector3(0.0, 1.40, -0.33), Vector3(0.50, 0.22, 0.24), Vector3.ZERO, 0.14, FUR))
	for s: float in [-1.0, 1.0]:
		# The shoulder socket (the deltoid cap), centred on the arm's pivot.
		p.append(_ell(Vector3(s * SHOULDER.x, SHOULDER.y, SHOULDER.z), Vector3.ONE * SHOULDER_SOCKET, Vector3.ZERO, 0.13, FUR))
		# Shoulder blades, faint under the hair.
		p.append(_ell(Vector3(s * 0.21, 1.57, -0.11), Vector3(0.15, 0.08, 0.16), Vector3(deg_to_rad(40.0), 0.0, s * deg_to_rad(-14.0)), 0.07, FUR))
		# The lats, flaring out under the shoulders: the V of his back.
		p.append(_ell(Vector3(s * 0.29, 1.24, -0.06), Vector3(0.16, 0.22, 0.20), Vector3(deg_to_rad(20.0), 0.0, 0.0), 0.1, FUR))
	# Chest: broad, the skin showing through down the middle.
	p.append(_ell(Vector3(0.0, 1.18, -0.52), Vector3(0.33, 0.30, 0.20), Vector3(deg_to_rad(-10.0), 0.0, 0.0), 0.12, SKIN, 0.7))
	# The two broad plates of the pectorals across the upper chest.
	for s: float in [-1.0, 1.0]:
		p.append(_ell(Vector3(s * 0.17, 1.30, -0.58), Vector3(0.20, 0.15, 0.12), Vector3(0.0, 0.0, s * deg_to_rad(-12.0)), 0.1, SKIN, 0.55))
	# Neck: short and thick, buried in the shoulders; it ends inside the
	# skull, so the trapezius runs straight up into the back of the head.
	p.append(_cone(Vector3(0.0, 1.42, -0.34), Vector3(0.0, 1.53, -0.49), 0.20, 0.15, 0.1, FUR))
	# The pot belly, slung forward and low.
	p.append(_ell(Vector3(0.0, 0.86, -0.25), Vector3(0.26, 0.25, 0.28), Vector3.ZERO, 0.15, FUR))
	# The rump: one broad rounded mass over the legs.
	p.append(_ell(Vector3(0.0, 0.93, 0.18), Vector3(0.33, 0.27, 0.21), Vector3(deg_to_rad(28.0), 0.0, 0.0), 0.15, FUR))
	# Hip sockets, centred on the legs' pivots.
	for s: float in [-1.0, 1.0]:
		p.append(_ell(Vector3(s * HIP.x, HIP.y, HIP.z), Vector3.ONE * HIP_SOCKET, Vector3.ZERO, 0.12, FUR))
	# A shallow furrow down the spine, between the long back muscles: a
	# chain of rods riding just OUTSIDE the curve of the back, fat in the
	# middle (so they bite a centimetre or two in) and thin at the ends (so
	# the furrow fades out rather than stopping).
	var spine: Array[Vector3] = [Vector3(0.0, 1.717, -0.10), Vector3(0.0, 1.482, 0.123),
		Vector3(0.0, 1.3115, 0.272), Vector3(0.0, 1.135, 0.406)]
	var sr: Array[float] = [0.03, 0.05, 0.05, 0.03]
	for i in 3:
		p.append(_carve(_cone(spine[i], spine[i + 1], sr[i], sr[i + 1], 0.04, FUR)))
	return p


static func _head_prims() -> Array:
	var p: Array = []
	# Braincase, and the tall peaked crest (the sagittal crest) rising to
	# its point at the back — the helmet shape of a silverback's head.
	p.append(_ell(Vector3(0.0, 0.0, 0.04), Vector3(0.162, 0.155, 0.175), Vector3.ZERO, 0.1, FUR))
	p.append(_ell(Vector3(0.0, 0.125, 0.085), Vector3(0.085, 0.14, 0.15), Vector3(deg_to_rad(-18.0), 0.0, 0.0), 0.13, FUR))
	# Cheeks and jowls.
	p.append(_ell(Vector3(0.0, -0.06, -0.06), Vector3(0.185, 0.13, 0.14), Vector3.ZERO, 0.08, FUR))
	# The bare face: the mask round the eyes.
	p.append(_ell(Vector3(0.0, -0.02, -0.135), Vector3(0.12, 0.105, 0.07), Vector3.ZERO, 0.035, SKIN, 1.0))
	# Muzzle, pushed forward past the nose, and the lower lip meeting it in
	# a crease: the mouth.
	p.append(_ell(Vector3(0.0, -0.105, -0.192), Vector3(0.125, 0.078, 0.098), Vector3.ZERO, 0.05, SKIN, 1.0))
	p.append(_ell(Vector3(0.0, -0.178, -0.178), Vector3(0.10, 0.046, 0.09), Vector3.ZERO, 0.012, SKIN, 1.0))
	p.append(_ell(Vector3(0.0, -0.185, -0.10), Vector3(0.125, 0.065, 0.11), Vector3.ZERO, 0.04, FUR))
	# The nose: a raised pad running down from between the eyes to a broad
	# bulb, with the wings of the nostrils flaring out either side.
	p.append(_cone(Vector3(0.0, 0.012, -0.205), Vector3(0.0, -0.045, -0.246), 0.018, 0.032, 0.025, SKIN, 1.0))
	p.append(_ell(Vector3(0.0, -0.062, -0.248), Vector3(0.05, 0.03, 0.03), Vector3.ZERO, 0.02, SKIN, 1.0))
	for s: float in [-1.0, 1.0]:
		p.append(_ell(Vector3(s * 0.05, -0.07, -0.238), Vector3(0.028, 0.023, 0.025), Vector3(0.0, 0.0, s * deg_to_rad(20.0)), 0.014, SKIN, 1.0))
	# Small ears, set back on the sides.
	for s: float in [-1.0, 1.0]:
		p.append(_ell(Vector3(s * 0.168, -0.02, 0.05), Vector3(0.03, 0.045, 0.035), Vector3.ZERO, 0.02, SKIN, 1.0))
	# The back of the head runs down into the neck, deep under the shoulders.
	p.append(_cone(Vector3(0.0, -0.04, 0.09), Vector3(0.0, -0.17, 0.24), 0.15, 0.15, 0.08, FUR))
	# Carved: the eye sockets, and the nostrils opening down and forward.
	for s: float in [-1.0, 1.0]:
		p.append(_carve(_ell(Vector3(s * 0.062, -0.01, -0.192), Vector3(0.04, 0.032, 0.036), Vector3.ZERO, 0.014, SKIN_DARK, 1.0)))
		p.append(_carve(_ell(Vector3(s * 0.032, -0.083, -0.272), Vector3(0.019, 0.012, 0.02), Vector3(0.0, 0.0, s * deg_to_rad(25.0)), 0.008, SKIN_DARK, 1.0)))
	# Then the heavy shelf of brow, added AFTER the sockets are carved, so it
	# overhangs them and the eyes sit deep in its shadow: one continuous
	# ridge arching over each eye, dipping a little between them, and
	# thinning out into the temples.
	for s: float in [-1.0, 1.0]:
		var temple := Vector3(s * 0.108, 0.034, -0.138)
		var arch := Vector3(s * 0.062, 0.055, -0.172)
		var glabella := Vector3(0.0, 0.042, -0.198)
		p.append(_cone(temple, arch, 0.022, 0.032, 0.03, SKIN, 1.0))
		p.append(_cone(arch, glabella, 0.032, 0.031, 0.03, SKIN, 1.0))
	return p


## The whole arm, shoulder-local (the pivot at the origin): cut in two at the
## elbow afterwards.
static func _arm_prims(s: float) -> Array:
	var p: Array = []
	# The ball that turns in the torso's shoulder socket.
	p.append(_ell(Vector3.ZERO, Vector3.ONE * SHOULDER_BALL, Vector3.ZERO, 0.1, FUR))
	# Upper arm: a massive column, the biceps in front and the long triceps
	# behind, narrowing a little into the elbow.
	p.append(_cone(Vector3(0.0, -0.02, 0.0), Vector3(s * 0.01, -0.62, 0.012), 0.188, 0.13, 0.06, FUR))
	p.append(_ell(Vector3(s * 0.01, -0.31, -0.055), Vector3(0.12, 0.19, 0.10), Vector3.ZERO, 0.07, FUR))
	p.append(_ell(Vector3(s * 0.015, -0.33, 0.05), Vector3(0.13, 0.20, 0.11), Vector3.ZERO, 0.07, FUR))
	# The point of the elbow.
	p.append(_ell(Vector3(0.0, -0.63, 0.07), Vector3(0.075, 0.08, 0.06), Vector3.ZERO, 0.05, FUR))
	# Forearm: swelling out below the elbow, massive, narrowing to the wrist.
	p.append(_cone(Vector3(0.0, -0.62, 0.012), Vector3(0.0, -1.20, -0.03), 0.122, 0.094, 0.05, FUR))
	p.append(_ell(Vector3(s * 0.02, -0.85, -0.01), Vector3(0.145, 0.19, 0.135), Vector3.ZERO, 0.08, FUR))
	# The hand, curled into a knuckle-walking fist: the backs of the middle
	# finger bones planted on the ground, the palm facing back. The back of
	# the hand is furred; the fingers are bare, calloused skin.
	p.append(_ell(Vector3(0.0, -1.30, -0.05), Vector3(0.12, 0.115, 0.085), Vector3.ZERO, 0.045, FUR, 0.35))
	for i in 4:
		var x := (-0.084 + 0.056 * float(i)) * s
		var drop := 0.004 * absf(float(i) - 1.5)
		var mcp := Vector3(x, -1.325 + drop, -0.118)
		var pip := Vector3(x, -1.421, -0.124)
		var dip := Vector3(x, -1.421, -0.034)
		p.append(_cone(mcp, pip, 0.036, 0.034, 0.014, SKIN, 1.0))
		p.append(_cone(pip, dip, 0.034, 0.031, 0.012, SKIN, 1.0))
	# The thumb, tucked along the inside of the fist.
	p.append(_cone(Vector3(-s * 0.10, -1.24, -0.05), Vector3(-s * 0.118, -1.335, -0.105), 0.034, 0.03, 0.02, SKIN, 1.0))
	return p


static func _leg_prims(s: float) -> Array:
	var p: Array = []
	var knee := Vector3(s * 0.07, -0.28, -0.12)
	var ankle := Vector3(s * 0.03, -0.55, 0.0)
	# The ball that turns in the torso's hip socket.
	p.append(_ell(Vector3.ZERO, Vector3.ONE * HIP_BALL, Vector3.ZERO, 0.1, FUR))
	# Thigh, forward to a bent knee; shin back down to the ankle; calf.
	p.append(_cone(Vector3(0.0, -0.02, 0.0), knee, HIP_BALL, 0.105, 0.06, FUR))
	p.append(_ell(Vector3(s * 0.03, -0.15, -0.06), Vector3(0.14, 0.14, 0.13), Vector3.ZERO, 0.06, FUR))
	p.append(_ell(knee + Vector3(0.0, 0.0, -0.035), Vector3(0.09, 0.085, 0.07), Vector3.ZERO, 0.04, FUR))
	p.append(_cone(knee, ankle, 0.10, 0.075, 0.05, FUR))
	p.append(_ell(Vector3(s * 0.05, -0.38, -0.01), Vector3(0.095, 0.12, 0.09), Vector3.ZERO, 0.05, FUR))
	# The foot: long, broad, flat on the ground, leathery sole, long toes,
	# and the big toe splayed inward like a thumb.
	p.append(_ell(Vector3(0.0, -0.598, -0.07), Vector3(0.10, 0.055, 0.17), Vector3.ZERO, 0.05, FUR))
	p.append(_ell(Vector3(0.0, -0.592, 0.05), Vector3(0.065, 0.06, 0.065), Vector3.ZERO, 0.04, FUR))
	for i in 4:
		var x := (0.058 - 0.031 * float(i)) * s
		p.append(_cone(Vector3(x, -0.62, -0.17), Vector3(x * 1.12, -0.627, -0.262 + 0.014 * float(i)), 0.027, 0.025, 0.018, SKIN, 1.0))
	p.append(_cone(Vector3(-s * 0.062, -0.622, -0.10), Vector3(-s * 0.128, -0.624, -0.19), 0.034, 0.03, 0.024, SKIN, 1.0))
	return p


# =============================================================================
#  PRIMITIVES
# =============================================================================

static func _ell(c: Vector3, r: Vector3, rot: Vector3, k: float, col: Color, skin: float = 0.0) -> Array:
	var b := Basis.from_euler(rot)
	var pr: Array = []
	pr.resize(14)
	pr[P_KIND] = 0
	pr[P_OP] = 0
	pr[P_K] = k
	pr[P_COL] = col
	pr[P_SKIN] = skin
	pr[P_BC] = c
	pr[P_BR] = maxf(r.x, maxf(r.y, r.z))
	pr[P_C] = c
	pr[P_R] = r
	pr[P_INV] = b.inverse()
	pr[P_A] = Vector3.ZERO
	pr[P_B] = Vector3.ZERO
	pr[P_R1] = 0.0
	pr[P_R2] = 0.0
	return pr


static func _cone(a: Vector3, b: Vector3, r1: float, r2: float, k: float, col: Color, skin: float = 0.0) -> Array:
	var pr: Array = []
	pr.resize(14)
	pr[P_KIND] = 1
	pr[P_OP] = 0
	pr[P_K] = k
	pr[P_COL] = col
	pr[P_SKIN] = skin
	pr[P_BC] = (a + b) * 0.5
	pr[P_BR] = a.distance_to(b) * 0.5 + maxf(r1, r2)
	pr[P_C] = Vector3.ZERO
	pr[P_R] = Vector3.ONE
	pr[P_INV] = Basis()
	pr[P_A] = a
	pr[P_B] = b
	pr[P_R1] = r1
	pr[P_R2] = r2
	return pr


static func _carve(pr: Array) -> Array:
	pr[P_OP] = 1
	return pr


static func _prim_d(pr: Array, p: Vector3) -> float:
	var kind: int = pr[P_KIND]
	if kind == 0:
		var c: Vector3 = pr[P_C]
		var r: Vector3 = pr[P_R]
		var inv: Basis = pr[P_INV]
		var q := inv * (p - c)
		var k0 := (q / r).length()
		var k1 := (q / (r * r)).length()
		if k1 < 1e-9:
			return -minf(r.x, minf(r.y, r.z))
		return k0 * (k0 - 1.0) / k1
	var a: Vector3 = pr[P_A]
	var b: Vector3 = pr[P_B]
	var r1: float = pr[P_R1]
	var r2: float = pr[P_R2]
	# Inigo Quilez's exact round cone.
	var ba := b - a
	var l2 := ba.dot(ba)
	var rr := r1 - r2
	var a2 := l2 - rr * rr
	var il2 := 1.0 / l2
	var pa := p - a
	var y := pa.dot(ba)
	var z := y - l2
	var xv := pa * l2 - ba * y
	var x2 := xv.dot(xv)
	var y2 := y * y * l2
	var z2 := z * z * l2
	var kk := signf(rr) * rr * rr * x2
	if signf(z) * a2 * z2 > kk:
		return sqrt(x2 + z2) * il2 - r2
	if signf(y) * a2 * y2 < kk:
		return sqrt(x2 + y2) * il2 - r1
	return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1


## The sculpt's signed distance at p: shapes blended in, then carved out.
static func _field(prims: Array, p: Vector3) -> float:
	var d := 1e9
	for pr: Array in prims:
		var k: float = pr[P_K]
		var bc: Vector3 = pr[P_BC]
		var br: float = pr[P_BR]
		var lb := p.distance_to(bc) - br - 0.01
		var op: int = pr[P_OP]
		if op == 0:
			if lb > d + k:
				continue
			var s := _prim_d(pr, p)
			var h := clampf(0.5 + 0.5 * (s - d) / k, 0.0, 1.0)
			d = lerpf(s, d, h) - k * h * (1.0 - h)
		else:
			if lb > k - d:
				continue
			var s2 := _prim_d(pr, p)
			var h2 := clampf(0.5 + 0.5 * (s2 + d) / k, 0.0, 1.0)
			d = -(lerpf(s2, -d, h2) - k * h2 * (1.0 - h2))
	return d


## The same blend, but carrying the colour and skin weight along.
static func _field_color(prims: Array, p: Vector3) -> Array:
	var d := 1e9
	var col := FUR
	var skin := 0.0
	for pr: Array in prims:
		var k: float = pr[P_K]
		var bc: Vector3 = pr[P_BC]
		var br: float = pr[P_BR]
		var lb := p.distance_to(bc) - br - 0.01
		var op: int = pr[P_OP]
		var pc: Color = pr[P_COL]
		var ps: float = pr[P_SKIN]
		if op == 0:
			if lb > d + k:
				continue
			var s := _prim_d(pr, p)
			var h := clampf(0.5 + 0.5 * (s - d) / k, 0.0, 1.0)
			d = lerpf(s, d, h) - k * h * (1.0 - h)
			col = pc.lerp(col, h)
			skin = lerpf(ps, skin, h)
		else:
			if lb > k - d:
				continue
			var s2 := _prim_d(pr, p)
			var h2 := clampf(0.5 + 0.5 * (s2 + d) / k, 0.0, 1.0)
			d = -(lerpf(s2, -d, h2) - k * h2 * (1.0 - h2))
			col = pc.lerp(col, h2)
			skin = lerpf(ps, skin, h2)
	return [col, skin]


## Gradient by forward differences from d, the value already known at p.
static func _grad(prims: Array, p: Vector3, d: float) -> Vector3:
	var e := 0.0008
	var g := Vector3(
		_field(prims, p + Vector3(e, 0.0, 0.0)) - d,
		_field(prims, p + Vector3(0.0, e, 0.0)) - d,
		_field(prims, p + Vector3(0.0, 0.0, e)) - d)
	return g / e


# =============================================================================
#  MESHING — the sculpt's surface, extracted as a smooth triangle mesh
# =============================================================================

## Samples the shape on a grid (`cell` metres), finds the surface (surface
## nets), snaps every vertex exactly onto it, and takes the normal from the
## shape itself. `to_body` places the sculpt on the body at rest (for
## painting); `part` and `side` say what is being painted.
static func _sculpt(prims: Array, cell: float, to_body: Transform3D, part: int, side: float) -> Array:
	# Bounds from the blended shapes.
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for pr: Array in prims:
		var op: int = pr[P_OP]
		if op != 0:
			continue
		var bc: Vector3 = pr[P_BC]
		var br: float = pr[P_BR] + 0.02
		lo = lo.min(bc - Vector3(br, br, br))
		hi = hi.max(bc + Vector3(br, br, br))
	lo -= Vector3(cell, cell, cell) * 2.0
	hi += Vector3(cell, cell, cell) * 2.0
	var nx := int(ceilf((hi.x - lo.x) / cell)) + 1
	var ny := int(ceilf((hi.y - lo.y) / cell)) + 1
	var nz := int(ceilf((hi.z - lo.z) / cell)) + 1
	# Sample in blocks: one probe at each block's centre says whether the
	# surface can pass through it at all. Only blocks near the surface are
	# sampled finely (with only the shapes that reach them); the rest just
	# take the probe's value, whose sign is all the mesher needs there.
	var vals := PackedFloat32Array()
	vals.resize(nx * ny * nz)
	var state := PackedByteArray()
	state.resize(nx * ny * nz)
	state.fill(0)
	var bs := 4
	var nbx := int(ceilf(float(nx - 1) / float(bs)))
	var nby := int(ceilf(float(ny - 1) / float(bs)))
	var nbz := int(ceilf(float(nz - 1) / float(bs)))
	for bk in nbz:
		var k0 := bk * bs
		var k1 := mini(k0 + bs, nz - 1)
		for bj in nby:
			var j0 := bj * bs
			var j1 := mini(j0 + bs, ny - 1)
			for bi in nbx:
				var i0 := bi * bs
				var i1 := mini(i0 + bs, nx - 1)
				var centre := lo + Vector3(float(i0 + i1), float(j0 + j1), float(k0 + k1)) * (0.5 * cell)
				var half := (Vector3(float(i1 - i0), float(j1 - j0), float(k1 - k0)) * (0.5 * cell)).length()
				var dc := _field(prims, centre)
				var near := absf(dc) <= half * 1.3 + cell * 2.5
				var sub: Array = []
				if near:
					for pr: Array in prims:
						var bc: Vector3 = pr[P_BC]
						var br: float = pr[P_BR]
						var pk: float = pr[P_K]
						if centre.distance_to(bc) - br - half <= pk + cell * 3.0:
							sub.append(pr)
				for k in range(k0, k1 + 1):
					for j in range(j0, j1 + 1):
						for i in range(i0, i1 + 1):
							var id := i + j * nx + k * nx * ny
							if near:
								if state[id] != 2:
									vals[id] = _field(sub, lo + Vector3(float(i), float(j), float(k)) * cell)
									state[id] = 2
							elif state[id] == 0:
								vals[id] = dc
								state[id] = 1

	# One vertex per cell that the surface passes through.
	var sx := 1
	var sy := nx
	var sz := nx * ny
	var corner_off := PackedInt32Array([0, sx, sy, sx + sy, sz, sx + sz, sy + sz, sx + sy + sz])
	var corner_pos: Array[Vector3] = []
	for c in 8:
		corner_pos.append(Vector3(float(c & 1), float((c >> 1) & 1), float((c >> 2) & 1)))
	var edges: Array[Vector2i] = []
	for c in 8:
		for bit: int in [1, 2, 4]:
			if (c & bit) == 0:
				edges.append(Vector2i(c, c | bit))
	var cnx := nx - 1
	var cny := ny - 1
	var cnz := nz - 1
	var cell_v := PackedInt32Array()
	cell_v.resize(cnx * cny * cnz)
	cell_v.fill(-1)
	var verts := PackedVector3Array()
	var cv := PackedFloat32Array()
	cv.resize(8)
	for k in cnz:
		for j in cny:
			for i in cnx:
				var base := i + j * sy + k * sz
				var inside := 0
				for c in 8:
					var v := vals[base + corner_off[c]]
					cv[c] = v
					if v < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var acc := Vector3.ZERO
				var cnt := 0
				for e: Vector2i in edges:
					var va := cv[e.x]
					var vb := cv[e.y]
					if (va < 0.0) != (vb < 0.0):
						var t := va / (va - vb)
						acc += corner_pos[e.x].lerp(corner_pos[e.y], t)
						cnt += 1
				var local := acc / float(cnt)
				cell_v[i + j * cnx + k * cnx * cny] = verts.size()
				verts.append(lo + (Vector3(float(i), float(j), float(k)) + local) * cell)

	# Snap each vertex onto the true surface; normal from the shape.
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for vi in verts.size():
		var p := verts[vi]
		var n := Vector3.UP
		for it in 3:
			var d := _field(prims, p)
			var g := _grad(prims, p, d)
			var gl := g.length_squared()
			if gl < 1e-8:
				break
			n = g / sqrt(gl)
			if it == 2 or absf(d) < 0.00005:
				break
			var step := g * (d / gl)
			if step.length() > cell:
				step = step.normalized() * cell
			p -= step
		verts[vi] = p
		normals[vi] = n
		var cs := _field_color(prims, p)
		var skin: float = cs[1]
		var col: Color = cs[0]
		colors[vi] = _paint(p, to_body * p, n, col, skin, part, side)

	# Faces: a quad across every grid edge the surface crosses.
	var tri_idx := PackedInt32Array()
	for k in range(1, nz - 1):
		for j in range(1, ny - 1):
			for i in range(1, nx - 1):
				var here := i + j * sy + k * sz
				var v0 := vals[here]
				var c00 := i + j * cnx + k * cnx * cny
				# Edge along +X: shared by cells (i, j-1..j, k-1..k).
				if (v0 < 0.0) != (vals[here + sx] < 0.0):
					_quad(cell_v[c00 - cnx - cnx * cny], cell_v[c00 - cnx * cny], cell_v[c00],
						cell_v[c00 - cnx], verts, normals, tri_idx)
				if (v0 < 0.0) != (vals[here + sy] < 0.0):
					_quad(cell_v[c00 - 1 - cnx * cny], cell_v[c00 - cnx * cny], cell_v[c00],
						cell_v[c00 - 1], verts, normals, tri_idx)
				if (v0 < 0.0) != (vals[here + sz] < 0.0):
					_quad(cell_v[c00 - 1 - cnx], cell_v[c00 - cnx], cell_v[c00],
						cell_v[c00 - 1], verts, normals, tri_idx)

	var out: Array = []
	out.resize(4)
	out[S_VERTS] = verts
	out[S_NORMALS] = normals
	out[S_COLORS] = colors
	out[S_INDEX] = tri_idx
	return out


## Two triangles for one quad, split along the shorter diagonal and wound
## to face outward.
static func _quad(a: int, b: int, c: int, d: int, verts: PackedVector3Array,
		normals: PackedVector3Array, tri_idx: PackedInt32Array) -> void:
	if a < 0 or b < 0 or c < 0 or d < 0:
		return
	var tris: Array[Vector3i] = []
	if verts[a].distance_squared_to(verts[c]) < verts[b].distance_squared_to(verts[d]):
		tris.append(Vector3i(a, b, c))
		tris.append(Vector3i(a, c, d))
	else:
		tris.append(Vector3i(a, b, d))
		tris.append(Vector3i(b, c, d))
	for t: Vector3i in tris:
		var pa := verts[t.x]
		var pb := verts[t.y]
		var pc := verts[t.z]
		var n := normals[t.x] + normals[t.y] + normals[t.z]
		# Godot's front faces wind clockwise as seen from outside.
		if (pb - pa).cross(pc - pa).dot(n) > 0.0:
			tri_idx.append(t.x)
			tri_idx.append(t.z)
			tri_idx.append(t.y)
		else:
			tri_idx.append(t.x)
			tri_idx.append(t.y)
			tri_idx.append(t.z)


## An indexed mesh from a sculpt.
static func _mesh(sc: Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sc[S_VERTS]
	arrays[Mesh.ARRAY_NORMAL] = sc[S_NORMALS]
	arrays[Mesh.ARRAY_COLOR] = sc[S_COLORS]
	arrays[Mesh.ARRAY_INDEX] = sc[S_INDEX]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Cuts a sculpt in two across the plane y = cut: [above, below], the part
## below moved so the cut sits at its origin (it hangs from a joint there).
## Every triangle goes wholly to one side, and the two halves share the
## vertices along the cut, so they meet edge to edge with no seam.
static func _split(sc: Array, cut: float) -> Array[ArrayMesh]:
	var verts: PackedVector3Array = sc[S_VERTS]
	var normals: PackedVector3Array = sc[S_NORMALS]
	var colors: PackedColorArray = sc[S_COLORS]
	var idx: PackedInt32Array = sc[S_INDEX]
	var out: Array[ArrayMesh] = []
	for half in 2:
		var shift := Vector3.ZERO if half == 0 else Vector3(0.0, -cut, 0.0)
		var index_map := PackedInt32Array()
		index_map.resize(verts.size())
		index_map.fill(-1)
		var hv := PackedVector3Array()
		var hn := PackedVector3Array()
		var hc := PackedColorArray()
		var hi := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			var cy := (verts[a].y + verts[b].y + verts[c].y) / 3.0
			if (cy >= cut) != (half == 0):
				continue
			for vi: int in [a, b, c]:
				if index_map[vi] < 0:
					index_map[vi] = hv.size()
					hv.append(verts[vi] + shift)
					hn.append(normals[vi])
					hc.append(colors[vi])
				hi.append(index_map[vi])
		var part: Array = []
		part.resize(4)
		part[S_VERTS] = hv
		part[S_NORMALS] = hn
		part[S_COLORS] = hc
		part[S_INDEX] = hi
		out.append(_mesh(part))
	return out


# =============================================================================
#  PAINT — colour on the surface
# =============================================================================

## q is the point in the sculpt's own space, p the same point on the body at
## rest, n its normal; base / skin_weight come from the shapes.
static func _paint(q: Vector3, p: Vector3, n: Vector3, base: Color, skin_weight: float,
		part: int, side: float) -> Color:
	var col := base
	var skin := skin_weight
	if part == PART_LEG:
		# The soles of the feet (facing the ground, at the ground) are bare.
		var sole := (1.0 - smoothstep(-0.85, -0.45, n.y)) * (1.0 - smoothstep(0.03, 0.09, p.y))
		col = col.lerp(SKIN, sole)
		skin = maxf(skin, sole)
	if part == PART_HEAD:
		# Hair grows over the top of the brow and the forehead: only the
		# front and underside of the ridge are bare.
		var hairy := smoothstep(0.3, 0.75, n.y) * smoothstep(0.0, 0.05, q.y) * skin
		col = col.lerp(FUR, hairy)
		skin -= hairy
	var fur := 1.0 - skin

	# Light lift: the tops of the torso and head (which never swing) a shade
	# lighter so the form reads from above — but not on the shoulder
	# sockets, where an arm swinging out would show the lift as a patch. The
	# limbs get only a touch on their outer side, which stays put however
	# far they swing.
	var lift := 0.12
	if part == PART_TORSO:
		# ...nor round the base of the skull, where the head (which nods a
		# little) sinks into the shoulders: dark on both sides, no collar.
		var ds := minf(p.distance_to(SHOULDER), p.distance_to(Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z)))
		var dh := p.distance_to(Vector3(0.0, 1.58, -0.50))
		lift += smoothstep(-0.2, 0.95, n.y) * 0.6 * smoothstep(0.19, 0.36, ds) * smoothstep(0.18, 0.34, dh)
	elif part == PART_HEAD:
		lift += smoothstep(-0.2, 0.95, n.y) * 0.6 * smoothstep(-0.02, 0.1, q.y)
	else:
		lift += 0.16 * smoothstep(0.0, 0.9, n.x * side)
	col = col.lerp(FUR_TOP, lift * fur)

	# Hair: fine streaks running the way the hair lies, and slow clumping.
	var streak := 0.5
	var sil := 0.0
	if part == PART_TORSO:
		# Around the back: phi runs from the shoulders (0) over the lower
		# back and down the rump; the hair lies down and out from the spine.
		var d := p - Vector3(0.0, 1.0, -0.1)
		var phi := atan2(d.z, d.y)
		var arc := phi * 0.55
		var across := absf(p.x) - 0.32 * arc
		streak = _noise(Vector3(across * 34.0, arc * 6.0, p.x * 2.0)) * 0.65 \
			+ _noise(Vector3(across * 58.0 + 7.0, arc * 10.0, 1.3)) * 0.35
		sil = _saddle(p, n, phi)
	elif part == PART_HEAD:
		streak = _noise(Vector3(q.x * 40.0, q.y * 14.0 - q.z * 20.0, q.z * 12.0))
	else:
		streak = _noise(Vector3(q.x * 44.0, q.y * 7.0, q.z * 44.0)) * 0.7 \
			+ _noise(Vector3(q.x * 70.0 + 3.0, q.y * 11.0, q.z * 70.0)) * 0.3
		if part == PART_LEG:
			# A dim wash of silver over the top of the thigh, carrying the
			# saddle down over the hips.
			sil = 0.16 * (1.0 - smoothstep(0.06, 0.26, -q.y)) \
				* smoothstep(-0.6, 0.3, n.x * side * 0.6 + n.z * 0.8)
	var clump := _noise(p * 6.0 + Vector3(11.0, 5.0, 2.0))
	col = col * lerpf(1.0, (0.94 + 0.12 * streak) * (0.97 + 0.06 * clump), fur)

	# The crown: a faint warm brown on top of the crest.
	if part == PART_HEAD:
		col = col.lerp(CROWN, smoothstep(0.06, 0.2, q.y) * 0.22 * fur)

	# THE SILVER SADDLE.
	if sil > 0.0:
		var w := clampf(sil * fur * (0.86 + 0.28 * streak), 0.0, 0.74)
		col = col.lerp(SILVER * (0.86 + 0.26 * streak), w)
	col.a = 1.0
	return col


## How silver the hair is at p on the torso (0..1): one continuous falloff
## along the spine — brightest over the lower back, gone by the shoulder
## blades and before the underside of the rump — wrapping round the sides,
## with a ragged edge, and a dim wash over the hips.
static func _saddle(p: Vector3, n: Vector3, phi: float) -> float:
	var d := p - Vector3(0.0, 1.0, -0.1)
	var psi := rad_to_deg(atan2(absf(d.x), sqrt(d.y * d.y + d.z * d.z)))
	var ph := rad_to_deg(phi)
	var ragged := (_noise(p * 7.0 + Vector3(3.1, 1.7, 5.3)) - 0.5) * 18.0
	var along := smoothstep(10.0, 44.0, ph + ragged * 0.6) * (1.0 - smoothstep(98.0, 130.0, ph + ragged * 0.6))
	var lat := 1.0 - smoothstep(30.0, 70.0, psi + ragged)
	var w := along * lat * lerpf(0.72, 1.0, 1.0 - smoothstep(0.0, 50.0, absf(ph - 58.0)))
	# The hips: a dim wash down over the sockets, meeting the thighs'.
	var hip := Vector3(signf(p.x) * 0.25, 0.76, 0.14)
	w = maxf(w, 0.16 * (1.0 - smoothstep(0.12, 0.30, p.distance_to(hip))) * smoothstep(0.05, 0.2, absf(p.x)))
	# Only on hair that faces back, up or out — never the belly.
	return w * smoothstep(-0.95, 0.15, n.y * 0.55 + n.z * 0.85)


static func _hash(x: int, y: int, z: int) -> float:
	var h := float(x) * 127.1 + float(y) * 311.7 + float(z) * 74.7
	var s := sin(h) * 43758.5453
	return s - floorf(s)


## Smooth value noise, 0..1.
static func _noise(p: Vector3) -> float:
	var ix := int(floorf(p.x))
	var iy := int(floorf(p.y))
	var iz := int(floorf(p.z))
	var fx := p.x - floorf(p.x)
	var fy := p.y - floorf(p.y)
	var fz := p.z - floorf(p.z)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var x00 := lerpf(_hash(ix, iy, iz), _hash(ix + 1, iy, iz), fx)
	var x10 := lerpf(_hash(ix, iy + 1, iz), _hash(ix + 1, iy + 1, iz), fx)
	var x01 := lerpf(_hash(ix, iy, iz + 1), _hash(ix + 1, iy, iz + 1), fx)
	var x11 := lerpf(_hash(ix, iy + 1, iz + 1), _hash(ix + 1, iy + 1, iz + 1), fx)
	return lerpf(lerpf(x00, x10, fy), lerpf(x01, x11, fy), fz)


# =============================================================================
#  MATERIAL
# =============================================================================

## Fur: matte and soft, with barely any gloss (so it never reads as vinyl)
## and a rim of light round the edge — the sheen of long black hair — that
## lifts him off the dark jungle. The ink line is thick enough to stay a
## solid line at chase distance. The colour (fur, silver, skin) comes from
## the painted vertices.
static func _fur_material() -> StandardMaterial3D:
	var m := SM.mat(Color.WHITE, 0.86, 0.06, 0.5, 0.015)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m
