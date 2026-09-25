extends RefCounted
## SMOOTH SHAPES for the characters — the opposite of a box.
##
## Everything here is generated with CORRECT normals for its own shape. That
## matters: squashing a sphere by scaling its transform gives an ellipsoid
## whose normals still point like a sphere's, so the light lands in the wrong
## place and the shading looks lumpy. These build the real surface instead.
##
##   ellipsoid(radii)                a smooth egg / body / head
##   rounded_box(half, e)            a box with soft edges (e=0 box .. 1 ellipsoid)
##   tube(points, radii)             a smooth swept tube: tails, limbs, snouts
##   capsule(radius, height)         a pill
##   mat(color, ...)                 the characters' soft, polished material
##   add(parent, owner, name, mesh, xform, mat)   put a mesh in the scene
##
## Used as:  const SM := preload("res://tools/smooth_mesh.gd")

const DEFAULT_SEG := 32
const DEFAULT_RINGS := 18


## An ellipsoid with radii r, centred on the origin.
static func ellipsoid(r: Vector3, seg: int = DEFAULT_SEG, rings: int = DEFAULT_RINGS) -> ArrayMesh:
	return _param_surface(seg, rings, func(u: float, v: float) -> Array:
		var th := v * PI              # 0 at top .. PI at bottom
		var ph := u * TAU
		var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
		var p := d * r
		var n := Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized()
		return [p, n])


## A rounded box ("superellipsoid"): half-extents `half`, and `e` from about
## 0.15 (a box with soft edges) to 1.0 (an ellipsoid).
static func rounded_box(half: Vector3, e: float = 0.3, seg: int = DEFAULT_SEG,
		rings: int = DEFAULT_RINGS) -> ArrayMesh:
	var sgn_pow := func(c: float, p: float) -> float:
		return signf(c) * pow(absf(c), p)
	return _param_surface(seg, rings, func(u: float, v: float) -> Array:
		var th := v * PI - PI * 0.5   # -PI/2 .. PI/2 (latitude)
		var ph := u * TAU - PI
		var ct: float = sgn_pow.call(cos(th), e)
		var st: float = sgn_pow.call(sin(th), e)
		var cp: float = sgn_pow.call(cos(ph), e)
		var sp: float = sgn_pow.call(sin(ph), e)
		var p := Vector3(half.x * ct * cp, -half.y * st, half.z * ct * sp)
		# Normal of the implicit surface, (sign * |c|^(2-e)) / half.
		var ct2: float = sgn_pow.call(cos(th), 2.0 - e)
		var st2: float = sgn_pow.call(sin(th), 2.0 - e)
		var cp2: float = sgn_pow.call(cos(ph), 2.0 - e)
		var sp2: float = sgn_pow.call(sin(ph), 2.0 - e)
		var n := Vector3(ct2 * cp2 / half.x, -st2 / half.y, ct2 * sp2 / half.z)
		if n.length_squared() < 1e-10:
			n = p
		return [p, n.normalized()])


## A smooth tube through `points`, with a radius at each point, capped with
## half-spheres at both ends so it reads as one soft limb.
static func tube(points: Array, radii: Array, sides: int = 20, caps: bool = true) -> ArrayMesh:
	var n := points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Parallel-transport frames, so the tube never twists or pinches.
	var tangents: Array[Vector3] = []
	for i in n:
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, n - 1)]
		tangents.append((b - a).normalized())
	var normal := tangents[0].cross(Vector3.UP)
	if normal.length_squared() < 1e-6:
		normal = tangents[0].cross(Vector3.RIGHT)
	normal = normal.normalized()
	var rings: Array = []
	for i in n:
		if i > 0:
			var axis := tangents[i - 1].cross(tangents[i])
			if axis.length_squared() > 1e-10:
				var ang := tangents[i - 1].angle_to(tangents[i])
				normal = normal.rotated(axis.normalized(), ang)
		var binormal := tangents[i].cross(normal).normalized()
		var ring: Array = []
		for k in sides + 1:
			var a := TAU * float(k) / float(sides)
			var dir := normal * cos(a) + binormal * sin(a)
			ring.append([points[i] + dir * float(radii[i]), dir])
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			var q := [rings[i][k], rings[i + 1][k], rings[i + 1][k + 1], rings[i][k + 1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[idx][1])
				st.set_uv(Vector2(float(k) / float(sides), float(i) / float(n - 1)))
				st.add_vertex(q[idx][0])
	var mesh := st.commit()
	if caps:
		for end in [0, n - 1]:
			var r: float = radii[end]
			var cap := ellipsoid(Vector3(r, r, r), sides, maxi(6, sides / 2))
			mesh = merge_into(mesh, cap, Transform3D(Basis(), points[end]))
	return mesh


## A pill: radius r, total height h, standing on its middle.
static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 28
	c.rings = 10
	return c


## Adds `extra` (placed by xf — rotation/uniform scale only) to `base`'s first
## surface. Used to cap tubes; for real merging use SurfaceTool per material.
static func merge_into(base: ArrayMesh, extra: Mesh, xf: Transform3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(base, 0, Transform3D())
	st.append_from(extra, 0, xf)
	return st.commit()


## THE CHARACTER MATERIAL: soft, rounded light (Burley diffuse, not the toon
## step the scenery uses), a gentle specular sheen, a rim of light round the
## edge that reads as fur or fabric catching the sun, and a thin dark ink
## outline so the character still pops off the jungle.
static func mat(color: Color, roughness: float = 0.62, specular: float = 0.35,
		rim: float = 0.3, ink: float = 0.012, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.roughness = roughness
	m.metallic_specular = specular
	m.rim_enabled = rim > 0.0
	m.rim = rim
	m.rim_tint = 0.5
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if ink > 0.0:
		m.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
		m.stencil_outline_thickness = ink
		m.stencil_color = Color(0.08, 0.05, 0.03, 1.0)
	return m


## Puts a mesh into the scene under `parent`, owned by `owner` so it is saved.
static func add(parent: Node, owner: Node, node_name: String, mesh: Mesh,
		xf: Transform3D, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = material
	parent.add_child(mi)
	mi.owner = owner
	return mi


## An empty pivot node (a joint), owned for saving.
static func pivot(parent: Node, owner: Node, node_name: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = node_name
	p.position = pos
	parent.add_child(p)
	p.owner = owner
	return p


## Builds a triangle surface from a parametric function f(u, v) -> [pos, normal],
## u and v in 0..1.
static func _param_surface(seg: int, rings: int, f: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for j in rings + 1:
		var row: Array = []
		for i in seg + 1:
			row.append(f.call(float(i) / float(seg), float(j) / float(rings)))
		grid.append(row)
	for j in rings:
		for i in seg:
			var q := [grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(q[idx][1])
				st.set_uv(Vector2(float(i) / float(seg), float(j) / float(rings)))
				st.add_vertex(q[idx][0])
	return st.commit()
