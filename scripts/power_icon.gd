extends Control
## A little drawn icon for a power-up's HUD row: the same shape and colour as
## the thing floating on the track, so the row and the pickup are obviously
## the same thing. Drawn with _draw() rather than loaded, so nothing has to be
## downloaded or painted.

## 0 magnet, 1 surf plank, 2 double score, 3 spring — the Pickup order.
@export var kind: int = 0

const COLORS := [Color(1.0, 0.30, 0.22), Color(0.35, 0.60, 1.0),
	Color(0.82, 0.45, 1.0), Color(0.35, 0.92, 1.0)]


func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var col: Color = COLORS[clampi(kind, 0, 3)]
	var ink := Color(0.08, 0.05, 0.02)
	match kind:
		0:  # horseshoe magnet with white tips
			draw_arc(c + Vector2(0, -2), 13.0, PI, TAU, 16, ink, 12.0, true)
			draw_arc(c + Vector2(0, -2), 13.0, PI, TAU, 16, col, 8.0, true)
			for sx in [-1.0, 1.0]:
				draw_rect(Rect2(c + Vector2(sx * 13.0 - 5.0, -2.0), Vector2(10, 12)), ink)
				draw_rect(Rect2(c + Vector2(sx * 13.0 - 4.0, -1.0), Vector2(8, 5)), col)
				draw_rect(Rect2(c + Vector2(sx * 13.0 - 4.0, 4.0), Vector2(8, 5)), Color.WHITE)
		1:  # surf plank, tilted, with a yellow stripe
			draw_set_transform(c, -0.5, Vector2.ONE)
			draw_rect(Rect2(Vector2(-8, -19), Vector2(16, 38)), ink)
			draw_rect(Rect2(Vector2(-6, -17), Vector2(12, 34)), col)
			draw_rect(Rect2(Vector2(-1.5, -15), Vector2(3, 30)), Color(1.0, 0.84, 0.2))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		2:  # gem with 2X
			var pts := PackedVector2Array([c + Vector2(0, -19), c + Vector2(17, 0),
				c + Vector2(0, 19), c + Vector2(-17, 0)])
			draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, ink, 2.5, true)
			var f := get_theme_default_font()
			draw_string(f, c + Vector2(-11, 6), "2X", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		3:  # spring coil with an up arrow
			var zig := PackedVector2Array()
			for i in 6:
				zig.append(c + Vector2(-9.0 if i % 2 == 0 else 9.0, 16.0 - 5.0 * float(i)))
			draw_polyline(zig, ink, 7.0, true)
			draw_polyline(zig, col, 4.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(9, -10),
				c + Vector2(-9, -10)]), Color.WHITE)
