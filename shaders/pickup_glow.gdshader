shader_type spatial;
// THE POWER-UP GLOW: a soft bubble behind the icon, and a shaft of light
// falling on it through the canopy. It is the cue Subway Surfers leans on —
// "this one is special" — and it is what reads from 60 m, where the icon
// itself is a few pixels across.
//
// One mesh, two quads, told apart by vertex COLOR.r:
//   0 = the bubble: faces the camera, sits a little BEHIND the icon so the
//       opaque icon always draws in front of it
//   1 = the shaft: turns about Y only, so it stays upright, from the ground
//       to just under the canopy
//
// MIX blending, not additive: added over the orange trail, a blue or cyan
// glow washes out to lavender; mixed, it keeps its hue. Output stays under
// 1.0, so it never trips the bloom and haloes the whole lane.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float kind;

void vertex() {
	kind = COLOR.r;
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (kind < 0.5) {
		// Full billboard, pushed 0.6 m away from the camera.
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		vec3 back = INV_VIEW_MATRIX[2].xyz;
		float pulse = 1.0 + 0.06 * sin(TIME * 3.4);
		vec3 world = origin + (right * VERTEX.x + up * VERTEX.y) * pulse - back * 0.6;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	} else {
		// Upright billboard: face the camera, but only by turning about Y.
		vec3 to_cam = INV_VIEW_MATRIX[3].xyz - origin;
		to_cam.y = 0.0;
		vec3 fwd = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
		vec3 world = origin + right * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	}
}

void fragment() {
	vec3 col = tint.rgb;
	float a = 0.0;
	if (kind < 0.5) {
		vec2 d2 = (UV - 0.5) * 2.0;
		float d = length(d2);
		float inside = 1.0 - smoothstep(0.92, 1.0, d);
		float core = mix(0.42, 0.14, smoothstep(0.0, 0.9, d));
		// A bright rim, so it reads as a bubble and not a smudge.
		float ring = smoothstep(0.76, 0.84, d) * (1.0 - smoothstep(0.88, 0.96, d));
		// Slow rays turning round it.
		float ang = atan(d2.y, d2.x) + TIME * 0.7;
		float rays = pow(max(0.0, cos(ang * 4.0)), 8.0) * (1.0 - smoothstep(0.3, 0.95, d));
		a = (core + ring * 0.6 + rays * 0.18) * inside;
		col = mix(col, vec3(1.0), ring * 0.55 + (1.0 - smoothstep(0.0, 0.35, d)) * 0.35);
	} else {
		// The shaft: brightest where it lands, fading upward, soft sides,
		// with motes drifting down it.
		float side = 1.0 - smoothstep(0.25, 0.5, abs(UV.x - 0.5));
		float fall = pow(1.0 - UV.y, 1.6);
		vec2 cell = floor(UV * vec2(4.0, 14.0) + vec2(0.0, TIME * 1.5));
		float mote = step(0.93, fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453));
		a = (0.30 * fall + mote * 0.35 * (1.0 - UV.y)) * side;
		col = mix(col, vec3(1.0), 0.35);
	}
	ALBEDO = min(col, vec3(1.0));
	ALPHA = clamp(a, 0.0, 0.9);
}
