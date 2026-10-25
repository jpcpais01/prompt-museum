shader_type canvas_item;
// Each collection's "painting": flowing silk of its own colour, domain-warped
// by a few sines and seeded per collection so no two walls look alike. The
// node's StyleBox alpha is the mask, so rounded corners come for free.
// `focus` lifts the light and runs a sheen across, like a PS5 tile.

uniform vec4 tint : source_color = vec4(0.49, 0.36, 1.0, 1.0);
uniform float seed = 0.0;
uniform float focus = 0.0;
uniform float animate = 1.0;
uniform vec2 ratio = vec2(1.0, 1.0);

vec3 hue_shift(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	float t = TIME * 0.12 * animate + seed * 7.0;
	vec2 p = (UV - 0.5) * ratio * 2.4;
	p += 0.55 * vec2(sin(p.y * 1.7 + t + seed), cos(p.x * 1.4 - t * 0.8 + seed * 2.0));
	p += 0.35 * vec2(sin(p.y * 2.9 - t * 1.3), cos(p.x * 3.1 + t * 1.1));
	float f = sin(p.x * 2.2 + p.y * 1.3 + seed * 3.0) * 0.5 + 0.5;
	float g = sin(length(p) * 3.0 - t * 2.0) * 0.5 + 0.5;
	vec3 a = tint.rgb;
	vec3 b = hue_shift(tint.rgb, 0.9);
	vec3 c = hue_shift(tint.rgb, -0.7) * 0.35;
	vec3 col = mix(c, mix(a, b, g), smoothstep(0.1, 0.95, f));
	col += pow(f * g, 6.0) * 0.6;
	// darken the bottom so titles always read
	col *= mix(1.0, 0.32, smoothstep(0.35, 1.0, UV.y));
	col *= 0.78 + 0.32 * focus;
	// sheen
	float s = UV.x + UV.y * 0.6 - mod(TIME * 0.35, 3.0) + 0.5;
	col += exp(-s * s * 60.0) * 0.22 * focus;
	COLOR = vec4(col, COLOR.a);
}
