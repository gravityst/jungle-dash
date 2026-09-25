extends Node
## HEADLESS SCENE AUDIT — the stand-in for looking at the game.
##
## Every number here is measured by loading the real scenes and walking their
## meshes, so it runs with --headless and opens NO window.
##
## Surfaces are what matter for performance: gl_compatibility does no batching,
## so one visible surface == one draw call.

func _ready() -> void:
	_audit_player()
	_audit_chunk()
	await _scene_size()
	await _hud_report()
	_contrast_report()
	_obstacle_contrast_report()
	_audio_report()
	get_tree().quit(0)


## Node count is the number that proves the pooling works: if it grows as you
## run, something is being created at runtime and the game will eventually die
## of it. The scene has to be RUNNING to be counted — instantiate() alone does
## not call _ready(), so the track manager has not built its nine chunks yet
## and you would measure the scene file (64) rather than the game (~1200).
func _scene_size() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	# Deferred: the window root is still busy walking its own children while
	# _ready() runs, and a direct add_child() there fails outright — which
	# leaves the track manager unbuilt and silently reports the scene-file
	# count (64) instead of the live one.
	get_tree().root.add_child.call_deferred(main)
	for i in 3:
		await get_tree().process_frame
	print("\n===== SCENE SIZE =====")
	print("  live nodes: %d  (constant — pooled, nothing spawns at runtime)"
		% _count_nodes(main))
	main.free()


## Confirms every sound actually loaded and has audio in it. A zero-length or
## missing stream is silent in exactly the same way as a sound that never gets
## triggered, so it is worth checking separately.
func _audio_report() -> void:
	print("\n===== AUDIO =====")
	var names := ["coin", "jump", "land", "duck", "crash", "powerup", "launch",
			"shield", "ambient"]
	for n in names:
		var path := "res://audio/%s.wav" % n
		var st := load(path) as AudioStreamWAV
		if st == null:
			print("    %-8s *** FAILED TO LOAD ***" % n)
			continue
		# get_length() is authoritative. Do NOT compute it from data.size():
		# Godot may import a WAV as IMA-ADPCM, which is ~4x smaller, and the
		# byte maths then reports a sound four times shorter than it is.
		var fmt_names := {0: "8-bit", 1: "16-bit", 2: "IMA-ADPCM", 3: "QOA"}
		var fmt: String = fmt_names.get(st.format, "format %d" % st.format)
		print("    %-8s %6.2f s  %-10s %s  loop=%s" % [
			n, st.get_length(), fmt, "stereo" if st.stereo else "mono",
			st.loop_mode != AudioStreamWAV.LOOP_DISABLED])
	print("  all synthesised — see README. Drop a real recording in with the")
	print("  same filename and nothing else needs to change.")


func _mesh_stats(node: Node, only_visible: bool = true) -> Dictionary:
	var surfaces := 0
	var tris := 0
	var meshes := 0
	for child in _walk(node):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if only_visible and not mi.is_visible_in_tree():
			continue
		meshes += 1
		for si in mi.mesh.get_surface_count():
			surfaces += 1
			var arrays := mi.mesh.surface_get_arrays(si)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.size() > 0:
				tris += idx.size() / 3
			else:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				tris += verts.size() / 3
	return {"meshes": meshes, "surfaces": surfaces, "tris": tris}


func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func _audit_player() -> void:
	var p: Node3D = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	var visual: Node3D = p.get_node("Visual/Body")   # the lean pivot holds the figure
	var st := _mesh_stats(visual)

	# Silhouette: the union of every visual part's world AABB.
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for child in _walk(visual):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var ab := mi.global_transform * mi.mesh.get_aabb()
		lo = lo.min(ab.position)
		hi = hi.max(ab.position + ab.size)

	print("\n===== PLAYER =====")
	print("  visual parts   : %d meshes, %d surfaces, %d triangles" % [
		st["meshes"], st["surfaces"], st["tris"]])
	print("  silhouette     : %.2f wide x %.2f tall x %.2f deep" % [
		hi.x - lo.x, hi.y - lo.y, hi.z - lo.z])
	print("  feet at y      : %.3f (want 0.00)" % lo.y)
	print("  top at y       : %.3f (want ~1.80)" % hi.y)
	print("  head:body ratio: %.2f  (stylised reads well around 0.28-0.34)" % _head_ratio(visual, hi.y - lo.y))
	var pivots := ["ArmLeft", "ArmRight", "LegLeft", "LegRight"]
	for name in pivots:
		var n := visual.get_node_or_null(name)
		print("  pivot %-9s: %s" % [name, "present" if n != null else "*** MISSING ***"])
	p.queue_free()


func _head_ratio(visual: Node3D, total_h: float) -> float:
	var head: Node3D = visual.get_node_or_null("Head")
	if head == null or not (head is MeshInstance3D):
		return 0.0
	var ab := (head as MeshInstance3D).mesh.get_aabb()
	return ab.size.y / maxf(total_h, 0.001)


## How many recycles to sample the scenery over.
##
## This was 60, and 60 is not enough to mean anything: sampled with five
## different seed bases it returned 25, 29, 27, 29 and 28, so a perfectly
## healthy build could look like it had lost a fifth of its variety purely by
## chance. I read exactly that as a regression once. At 240 it settles on the
## real answer and stops moving.
const SCENERY_SAMPLES := 240

## What the shuffle can actually produce, measured by sweeping until the count
## stopped rising (it is identical at 240 and at 600). Reporting the number
## against its CEILING is the difference between "36" and "36 out of 36".
const SCENERY_CEILING := 36


func _audit_chunk() -> void:
	var c: Node3D = load("res://scenes/track_chunk.tscn").instantiate()
	add_child(c)

	# Randomise first. Straight out of the scene file EVERY obstacle variant
	# and EVERY scenery variant is visible at once, which massively overstates
	# the cost — in play all but one of each is hidden.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	c.randomise(rng, 0.6, false)

	var total := _mesh_stats(c)
	print("\n===== ONE TRACK CHUNK (30 m) =====")
	print("  visible total  : %d surfaces, %d triangles" % [total["surfaces"], total["tris"]])
	for group in ["Ground", "JungleFloor", "Trail", "Understory", "Canopy",
			"JungleWall", "VergePatches", "Decor", "Obstacles", "Coins",
			"Powerups", "Skyway"]:
		var n := c.get_node_or_null(group)
		if n == null:
			continue
		var st := _mesh_stats(n)
		print("    %-14s %3d surfaces  %7d tris" % [group, st["surfaces"], st["tris"]])
	print("  x9 live chunks : ~%d surfaces, ~%d triangles" % [
		total["surfaces"] * 9, total["tris"] * 9])

	# A treetop piece should come out CHEAPER than an ordinary one: it hides
	# the whole decorative canopy and every obstacle, and adds back only a deck
	# and some flanking crowns. If this ever goes the other way, the set-piece
	# has started costing frames instead of saving them.
	c.randomise(rng, 0.6, false, true, c.Role.DECK)
	var deck_stats := _mesh_stats(c)
	print("  a TREETOP piece: %d surfaces, %d triangles  (%+d surfaces vs normal)" % [
		deck_stats["surfaces"], deck_stats["tris"],
		deck_stats["surfaces"] - total["surfaces"]])
	c.randomise(rng, 0.6, false)
	# What is ACTUALLY drawn. Geometry is culled at CULL_DISTANCE, so most of
	# the pooled ring is never rendered — quoting the nine-chunk total as the
	# cost overstates it by about 40%, which is the difference between "heavy
	# for a phone" and "fine".
	var cull := 212.0
	var in_frame: float = cull / LaneConfig.CHUNK_LENGTH
	# Shadow casters are drawn AGAIN once per shadow split, so they are a
	# multiplier on the figure above, not a footnote to it.
	var casters := 0
	var caster_tris := 0
	for n in _walk(c):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		casters += 1
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			caster_tris += ix.size() / 3 if ix.size() > 0 else 0
	print("  shadow casters : %d meshes, %d triangles per piece" % [casters, caster_tris])
	print("                   (re-drawn once per shadow split, over 45 m)")

	print("  IN FRAME       : ~%d surfaces, ~%d triangles" % [
		int(round(total["surfaces"] * in_frame)),
		int(round(total["tris"] * in_frame))])
	print("  (only ~%.1f of the 9 pooled pieces are inside the %.0f m cull" % [in_frame, cull])
	print("   distance at any moment; the rest are pooled but never drawn)")

	# How much variety does the scenery actually have? Randomise repeatedly and
	# count how many distinct looks come up.
	var seen := {}
	for i in SCENERY_SAMPLES:
		rng.seed = i * 7919
		c.randomise(rng, 0.5, false)
		var key := ""
		for layer_name in ["Understory", "JungleWall"]:
			var layer: Node3D = c.get_node_or_null(layer_name)
			if layer == null:
				continue
			for vi in layer.get_child_count():
				if (layer.get_child(vi) as Node3D).visible:
					key += "%s%d/" % [layer_name.substr(0, 1), vi]
			key += "m%d " % int(signf(layer.scale.x))
		seen[key] = true
	print("\n===== SCENERY VARIETY =====")
	print("  distinct verge/wall combinations in %d recycles: %d of a possible %d"
		% [SCENERY_SAMPLES, seen.size(), SCENERY_CEILING])
	print("  (one strip slid + mirrored would give 2; more means the 30 m")
	print("   repeat is genuinely hard to spot)")
	if seen.size() < SCENERY_CEILING * 0.9:
		print("  *** below 90%% of the ceiling — the shuffle has lost range ***")
	c.queue_free()


## Where every HUD label actually lands, and whether any two overlap.
##
## Worth measuring rather than eyeballing: a Control's rect is only correct
## once it has been laid out inside a sized parent, and this project has
## already shipped a score that was silently 100 px off centre because the
## anchors were baked while the container still had zero size.
func _hud_report() -> void:
	var hud: CanvasLayer = load("res://scenes/hud.tscn").instantiate()
	get_tree().root.add_child.call_deferred(hud)
	for i in 3:
		await get_tree().process_frame
	print("\n===== HUD LAYOUT =====")
	var rects := {}
	var spans := {}
	for child in hud.find_children("*", "Label", true, false):
		var l := child as Label
		if l == null or not l.is_visible_in_tree():
			continue
		var r: Rect2 = l.get_global_rect()
		rects[l.name] = r
		spans[l.name] = _span_of(l, r)
		print("  %-10s x %6.0f .. %-6.0f  y %6.0f .. %-6.0f  \"%s\"" % [
			l.name, r.position.x, r.end.x, r.position.y, r.end.y,
			l.text.split("\n")[0].substr(0, 22)])
	# Compare where the TEXT actually sits, not the label's rect. Most of these
	# labels are stretched the full width of the screen and differ only by
	# alignment, so comparing rects would report the score and the coin counter
	# as colliding when they sit in opposite corners.
	var names := rects.keys()
	var clashes := 0
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			if a.intersects(b) and _overlaps_1d(spans[names[i]], spans[names[j]]):
				print("  *** %s OVERLAPS %s ***" % [names[i], names[j]])
				clashes += 1
	print("  %d labels, %d actually overlapping" % [names.size(), clashes])
	print("  (positions are relative to the headless viewport, so judge the")
	print("   RELATIONSHIPS here, not the absolute pixel values)")
	hud.queue_free()


## The horizontal span the label's TEXT occupies inside its rect, given how it
## is aligned.
func _span_of(l: Label, r: Rect2) -> Vector2:
	var w: float = minf(l.get_minimum_size().x, r.size.x)
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_RIGHT:
			return Vector2(r.end.x - w, r.end.x)
		HORIZONTAL_ALIGNMENT_CENTER:
			var mid: float = r.position.x + r.size.x * 0.5
			return Vector2(mid - w * 0.5, mid + w * 0.5)
		_:
			return Vector2(r.position.x, r.position.x + w)


func _overlaps_1d(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y and b.x < a.y


## Relative luminance and WCAG-style contrast, used to check the character
## actually separates from what it runs against.
func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a) + 0.05
	var lb := _lum(b) + 0.05
	return maxf(la, lb) / minf(la, lb)


## Can you SEE the obstacles?
##
## Exactly the same test the character gets, and for exactly the same reason:
## the runner meets every obstacle against one of two backgrounds — the dirt
## path it stands on, or the wall of jungle behind it — and both sit at almost
## the same mid luminance (0.348 and 0.365). Anything in that same mid band has
## nothing to separate against and reads as part of the scenery.
##
## The obstacles were never measured this way. The character was.
func _obstacle_contrast_report() -> void:
	var dirt := Color(0.46, 0.33, 0.20)
	var leaf := Color(0.17, 0.44, 0.19)
	print("\n===== OBSTACLES vs BACKGROUND =====")
	print("  (the thing you must not hit has to be the thing you notice)")
	# The material that carries each obstacle's SILHOUETTE — the big mass you
	# read at distance, not the trim.
	var parts := {
		"log": "ob_wood", "log ends": "ob_wood_pale",
		"rock": "ob_stone", "tree trunk": "ob_wood",
		"idol": "ob_stone", "idol trim": "ob_stone_dark",
		"vines": "ob_vine", "leaves": "ob_leaf",
		# The LANDMARK is the biggest lethal object in the game and was never
		# in this list — it used the scenery palette and scored 1.07-1.28 on
		# every surface, including the blunt end you crash into and the mossy
		# top you are meant to aim a jump at.
		"magnet": "magnet", "deck": "deck_plank", "coin": "coin",
	}
	var worst := 99.0
	var worst_name := ""
	for label in parts:
		var res := load("res://materials/%s.tres" % parts[label])
		if res == null:
			continue
		var col: Color = res.albedo_color if res is StandardMaterial3D \
			else res.get_shader_parameter("albedo")
		var cd: float = _contrast(col, dirt)
		var cl: float = _contrast(col, leaf)
		# An obstacle is met against the path OR the jungle, so what matters is
		# the WORSE of the two, not the better.
		var weakest: float = minf(cd, cl)
		if weakest < worst:
			worst = weakest
			worst_name = label
		print("    %-11s vs dirt %.2f   vs leaf %.2f   %s" % [
			label, cd, cl, "" if weakest >= 1.6 else "<-- disappears"])
	print("  worst: %s at %.2f (want 1.60+ against BOTH)" % [worst_name, worst])

	# Some things are never met against the path or the jungle at all. A coin
	# on the treetop deck is seen against the DECK, and measuring it against
	# the dirt says nothing useful about whether you can see it.
	print("  --- against the surface they actually sit on ---")
	for pair in [["coin", "deck_plank", "coin on the treetop deck"],
			["coin", "ground", "coin over the path"],
			["ob_wood_pale", "ob_wood", "a log end against its own bark"]]:
		var a := load("res://materials/%s.tres" % pair[0])
		var b := load("res://materials/%s.tres" % pair[1])
		if a == null or b == null:
			continue
		var ca: Color = a.albedo_color if a is StandardMaterial3D \
			else a.get_shader_parameter("albedo")
		var cb: Color = b.albedo_color if b is StandardMaterial3D \
			else b.get_shader_parameter("albedo")
		var c: float = _contrast(ca, cb)
		print("    %-28s %.2f %s" % [pair[2], c, "" if c >= 1.6 else "<-- disappears"])


func _contrast_report() -> void:
	var dirt := Color(0.46, 0.33, 0.20)
	var leaf := Color(0.17, 0.44, 0.19)
	print("\n===== CHARACTER vs BACKGROUND CONTRAST =====")
	print("  (the runner crosses dirt AND foliage, so it must separate from both)")
	var parts := {
		"top": "player_top", "pack": "player_pack", "cap": "player_accent",
		"pants": "player_pants", "hands": "player_shoe", "face": "player_skin",
	}
	for label in parts:
		var path := "res://materials/%s.tres" % parts[label]
		var res := load(path)
		var col: Color = res.albedo_color if res is StandardMaterial3D else res.get_shader_parameter("albedo")
		print("    %-6s %-22s vs dirt %.2f   vs leaf %.2f" % [
			label, str(col).substr(0, 22), _contrast(col, dirt), _contrast(col, leaf)])
	print("  anything under ~1.6 against BOTH is a part that disappears")


func _count_nodes(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count_nodes(c)
	return total
