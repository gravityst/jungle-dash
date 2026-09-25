shader_type sky;
// A CARTOON SKY: a deep blue dome with crisp two-tone clouds.
//
// THE ONE RULE: at and below the horizon this outputs EXACTLY horizon_color,
// which is also the fog colour. The track only exists for ~240 m ahead and the
// fog hides where it stops; if the sky behind that point is even slightly a
// different colour, the fogged-out end of the track shows up as a wedge at the
// vanishing point. So the clouds and the blue both fade to that colour in a
// band just above the horizon, and everything below it is the colour itself.
//
// No TIME anywhere, on purpose. A sky shader that reads TIME has to re-bake
// the radiance map every frame, and the ambient light and every reflection in
// the scene come from that map. The sky sits at infinity, so running forward
// never moves it anyway: animated clouds would cost a lot and barely show.

uniform vec3 top_color : source_color = vec3(0.14, 0.46, 0.94);
uniform vec3 horizon_color : source_color = vec3(0.34, 0.41, 0.38);
// The bright horizon the sky had before the haze went dark. The LIGHTING
// (ambient and reflections, baked from the sky into the radiance map) still
// uses this, so darkening the visible haze at the end of the tunnel of trees
// did not darken every shaded face in the game.
uniform vec3 sky_low_color : source_color = vec3(0.66, 0.75, 0.69);
uniform vec3 cloud_lit : source_color = vec3(1.0, 1.0, 0.98);
uniform vec3 cloud_shade : source_color = vec3(0.74, 0.82, 0.93);
// Higher = fewer clouds.
uniform float cloud_cover = 0.52;
// Elevation (as sin of the angle) over which everything blends into the
// horizon colour.
uniform float horizon_band = 0.04;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.48;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float e = d.y;
	// The radiance pass lights the scene; the visible pass is what you see.
	// Only the visible pass gets the dark haze (and it is what the fog must
	// match — THE ONE RULE above holds there).
	vec3 hz = AT_CUBEMAP_PASS ? sky_low_color : horizon_color;
	if (e <= 0.0) {
		COLOR = hz;
	} else {
		vec3 col = mix(sky_low_color, top_color, pow(smoothstep(0.0, 0.6, e), 0.65));

		// Clouds on a flat ceiling, so they shrink and bunch toward the
		// horizon the way real ones do.
		vec2 uv = d.xz / max(e, 0.08) * 0.55;
		float n = fbm(uv);
		// Crisp edges: the toon look is a hard step, not a soft blur.
		float body = smoothstep(cloud_cover, cloud_cover + 0.025, n);
		// A lit crown on each cloud, offset toward the sun side, for the
		// two-tone look of a painted cloud.
		float crown = smoothstep(cloud_cover + 0.09, cloud_cover + 0.115,
			fbm(uv + vec2(0.06, 0.09)));
		vec3 cloud = mix(cloud_shade, cloud_lit, crown);
		col = mix(col, cloud, body * smoothstep(0.03, 0.2, e));

		// The rule: fade EVERYTHING to the exact fog colour at the horizon.
		COLOR = mix(hz, col, smoothstep(0.0, horizon_band, e));
	}
}
