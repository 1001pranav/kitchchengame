shader_type spatial;
// Oak floorboards laid along z, in world space so tiles line up seamlessly.
uniform vec3 base : source_color = vec3(0.23, 0.14, 0.085);
uniform vec3 dark : source_color = vec3(0.14, 0.085, 0.05);
uniform float plank_w = 0.11;
uniform float plank_l = 0.9;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float col = floor(wpos.x / plank_w);
	float off = hash(vec2(col, 3.0)) * plank_l;
	float row = floor((wpos.z + off) / plank_l);
	float h = hash(vec2(col, row));
	vec3 c = mix(base, dark, h * 0.55);
	float grain = sin((wpos.z + off) * 60.0 + h * 20.0 + sin(wpos.x * 90.0) * 1.5) * 0.5 + 0.5;
	c *= 0.92 + 0.08 * grain;
	float fx = fract(wpos.x / plank_w);
	float fz = fract((wpos.z + off) / plank_l);
	float seam = smoothstep(0.0, 0.04, fx) * smoothstep(1.0, 0.96, fx) * smoothstep(0.0, 0.01, fz) * smoothstep(1.0, 0.99, fz);
	ALBEDO = c * mix(0.45, 1.0, seam);
	ROUGHNESS = 0.45 + 0.2 * h;
	SPECULAR = 0.35;
}
