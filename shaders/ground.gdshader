shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec3 albedo : source_color = vec3(0.46, 0.33, 0.20);
// How dark the canopy shadows get.
uniform float dapple_strength = 0.34;
// Pattern size. Smaller = broader patches.
uniform float dapple_scale = 0.085;
// Large-scale tonal drift, so the dirt is never one flat colour.
uniform float variation = 0.14;
// Dapple fades out with distance so it does not fight the depth fog.
// Gone before the 40-60 m where you read obstacles: flowing dapple near
// the runner sells speed, but out there it was +-34% blotches right behind
// things only 5-10 px tall.
uniform float fade_start = 12.0;
uniform float fade_end = 45.0;
// Fine speckle, for gravel. 0 = off (plain dirt). It fades out with distance
// along with the dapple, because a pattern this small shimmers once it gets
// smaller than a pixel.
uniform float grain = 0.0;
uniform float grain_scale = 9.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// WORLD space, not UV. The chunks teleport ~270 m when they recycle, so a
	// UV-space pattern would slide with them and the ground would visibly
	// swim. Keyed to world position it simply stays where it is and flows
	// past the player, which is also what makes it read as cast light.
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Two octaves: one sine of noise reads as fog, two read as leaf shadow.
	float n = vnoise(wp.xz * dapple_scale) * 0.65
			+ vnoise(wp.xz * dapple_scale * 2.7) * 0.35;
	float shade = smoothstep(0.34, 0.72, n);

	float tone = vnoise(wp.xz * 0.035) - 0.5;

	float fade = 1.0 - smoothstep(fade_start, fade_end, length(VERTEX));
	float lit = mix(1.0, mix(1.0 - dapple_strength, 1.0 + dapple_strength * 0.22, shade), fade);

	// Smooth noise only. A hashed grid reads as square pixels up close, which
	// looks like a texture from 1998 rather than stones.
	float speck = (vnoise(wp.xz * grain_scale) - 0.5) * 0.9
				+ (vnoise(wp.xz * grain_scale * 2.3 + 17.0) - 0.5) * 0.7;
	float grit = 1.0 + speck * grain * fade;

	ALBEDO = albedo * lit * grit * (1.0 + tone * variation);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
