shader_type canvas_item;
// SPEED LINES — thin white streaks racing outward from the vanishing point,
// only toward the edges of the screen, so the middle where you are actually
// looking stays clean. Faded in by `strength`, which the HUD drives from how
// close you are to top speed and whether a double-score surge is running.

uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Where the track vanishes on screen.
uniform vec2 centre = vec2(0.5, 0.40);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 d = SCREEN_UV - centre;
	// Correct for the screen's shape so the streaks are truly radial.
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d);
	float a = atan(d.y, d.x) / TAU + 0.5;

	// The circle is cut into thin wedges; about half of them carry a streak.
	float wedges = 110.0;
	float id = floor(a * wedges);
	float h = hash(id);
	float lit = step(0.5, h);

	// Each streak travels outward on its own clock.
	float t = fract(TIME * (0.9 + h * 1.4) + h * 7.0);
	float head = mix(0.30, 1.20, t);
	float len = 0.10 + 0.14 * hash(id + 3.1);
	float along = smoothstep(head - len, head, r) * (1.0 - step(head, r));
	// Thin across: bright only near the middle of its wedge.
	float across = 1.0 - smoothstep(0.0, 0.18, abs(fract(a * wedges) - 0.5));
	// Nothing near the middle of the screen, where the track and everything
	// on it is: streaks there cross the lanes you are reading.
	float edge = smoothstep(0.42, 0.70, r);

	COLOR = vec4(1.0, 1.0, 0.96, along * across * edge * lit * strength * 0.6);
}
