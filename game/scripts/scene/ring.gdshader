shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled;
// A patience ring over a waiting party: full and green when they just started
// waiting, draining and turning red as patience runs out.
uniform float value : hint_range(0.0, 1.0) = 1.0;
uniform int icon = 0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.x, -p.y) / 6.2831853 + 0.5;
	vec3 good = vec3(0.56, 0.75, 0.42);
	vec3 mid = vec3(0.95, 0.72, 0.30);
	vec3 bad = vec3(0.90, 0.30, 0.25);
	vec3 col = value > 0.5 ? mix(mid, good, (value - 0.5) * 2.0) : mix(bad, mid, value * 2.0);
	float ring = smoothstep(0.98, 0.92, r) * smoothstep(0.62, 0.68, r);
	float filled = step(1.0 - value, a);
	vec3 c = mix(vec3(0.12), col, filled);
	float disc = smoothstep(0.66, 0.6, r);
	// Centre dot pulses when patience is low.
	float pulse = value < 0.3 ? 0.6 + 0.4 * sin(TIME * 10.0) : 1.0;
	ALBEDO = mix(vec3(0.05, 0.045, 0.04), c * pulse, ring);
	ALPHA = max(ring, disc * 0.85);
	if (ALPHA < 0.02) discard;
}
