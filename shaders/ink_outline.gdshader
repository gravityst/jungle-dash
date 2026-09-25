shader_type spatial;
// INK THAT READS AT ANY DISTANCE. Godot's built-in outline grows the mesh by a
// fixed amount in metres, so a line 3.5 cm wide is a clear edge at 5 m and
// less than half a pixel at 40 m — the distance where you actually decide what
// to do about an obstacle. This grows it by a fixed number of PIXELS instead
// (never thinner than the old width up close, never fatter than 14 cm), so
// "outlined means you can hit it" holds all the way down the track.
//
// Same stencil test as the built-in pass: draw only where the object is NOT.
// In the transparent queue (ALPHA below), like the built-in outline pass:
// Godot only lets a shader READ the stencil there, after every opaque object
// has written its own.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_never;
stencil_mode read, compare_not_equal, 1;

uniform vec4 ink : source_color = vec4(0.10, 0.06, 0.03, 1.0);
uniform float min_width = 0.035;
uniform float px_width = 1.6;
uniform float max_width = 0.14;

void vertex() {
	float depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	// Metres per pixel at this depth, on a 720-line reference so the line is
	// the same share of the screen at any resolution.
	float mpp = 2.0 * depth / (PROJECTION_MATRIX[1][1] * 720.0);
	VERTEX += NORMAL * clamp(px_width * mpp, min_width, max_width);
}

void fragment() {
	ALBEDO = ink.rgb;
	ALPHA = 1.0;
}
