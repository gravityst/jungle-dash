shader_type spatial;
// cull_disabled: the broad leaves and fronds are thin slabs, so without this
// you see straight through them from one side.
// diffuse_burley, not toon: the toon step drew a hard black line across every
// leaf mass where light met shade, which on smooth foliage is exactly the
// "pixely" edge. Burley rolls the light round the form like real leaves.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 albedo : source_color = vec3(0.2, 0.5, 0.2);

// How far the tips move, in metres.
uniform float sway_amp = 0.10;
uniform float sway_speed = 1.1;
// Below mask_start nothing moves at all; by mask_start + mask_range it moves
// fully. This is what keeps trunks and stalks planted while their leaves sway.
uniform float mask_start = 0.6;
uniform float mask_range = 3.0;
// Per-plant colour jitter, so a merged mass of ONE material stops reading as
// one flat colour.
uniform float tint_amount = 0.12;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float mask = clamp((wp.y - mask_start) / mask_range, 0.0, 1.0);
	mask *= mask;   // squared: the base stays put, the tips do the moving

	float t = TIME * sway_speed;
	// Phase from WORLD POSITION. Without this every plant sways in lockstep
	// and the whole jungle wobbles like jelly.
	float phase = wp.x * 0.42 + wp.z * 0.31;

	// Two frequencies: a slow broad sway plus a faster flutter. A single sine
	// reads as mechanical.
	float sx = sin(t + phase) * 0.70 + sin(t * 2.7 + phase * 2.1) * 0.30;
	float sz = cos(t * 0.83 + phase * 1.3) * 0.70 + cos(t * 3.1 + phase) * 0.30;

	VERTEX.x += sx * sway_amp * mask;
	VERTEX.z += sz * sway_amp * mask * 0.6;
	// Lean costs a little height, which stops it looking like sliding.
	VERTEX.y -= abs(sx) * sway_amp * mask * 0.18;
}

void fragment() {
	// Cheap per-clump tint, keyed to world position so it stays put as the
	// player runs past.
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = fract(sin(dot(floor(wp.xz * 0.30), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = albedo * (1.0 + (n - 0.5) * tint_amount);
	// Leaves are waxy: a soft broad sheen where the sun glances off them.
	ROUGHNESS = 0.62;
	SPECULAR = 0.28;
	// Sun shining THROUGH the leaves from behind — the glow that makes a
	// rainforest canopy look lit from within instead of painted green.
	BACKLIGHT = albedo * 0.55;
}
