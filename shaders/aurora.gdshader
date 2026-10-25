shader_type canvas_item;
// The museum's backdrop: three soft light pools drifting on slow lissajous
// paths over deep ink, a silk ribbon of light across the top, a vignette and
// a whisper of dither so the gradients never band. A handful of ALU per pixel
// and no textures, so it costs next to nothing even on a full phone screen.

uniform vec4 c1 : source_color = vec4(0.49, 0.36, 1.0, 1.0);
uniform vec4 c2 : source_color = vec4(0.24, 0.84, 0.96, 1.0);
uniform vec4 c3 : source_color = vec4(1.0, 0.42, 0.6, 1.0);
uniform vec4 base : source_color = vec4(0.039, 0.043, 0.075, 1.0);
uniform float strength = 1.0;
uniform float speed = 1.0;
uniform vec2 aspect = vec2(0.5625, 1.0);

float pool(vec2 uv, vec2 c, float r) {
	vec2 d = (uv - c) * aspect;
	return exp(-dot(d, d) / (r * r));
}

void fragment() {
	float t = TIME * 0.05 * speed;
	vec2 uv = UV;
	vec3 col = base.rgb;
	vec2 p1 = vec2(0.22 + 0.18 * sin(t * 1.3), 0.12 + 0.10 * cos(t * 0.9));
	vec2 p2 = vec2(0.82 + 0.14 * cos(t * 1.1 + 1.7), 0.32 + 0.14 * sin(t * 0.7 + 0.4));
	vec2 p3 = vec2(0.42 + 0.22 * sin(t * 0.8 + 3.1), 0.86 + 0.08 * cos(t * 1.2 + 2.0));
	col += c1.rgb * pool(uv, p1, 0.42) * 0.36;
	col += c2.rgb * pool(uv, p2, 0.36) * 0.20;
	col += c3.rgb * pool(uv, p3, 0.40) * 0.16;
	// silk ribbon: a bright fold that breathes across the upper screen
	float wave = uv.y - 0.2 - 0.06 * sin(uv.x * 4.0 + t * 6.0) - 0.03 * sin(uv.x * 9.0 - t * 4.0);
	float ribbon = exp(-wave * wave * 160.0) * (0.6 + 0.4 * sin(uv.x * 3.0 + t * 5.0));
	col += mix(c1.rgb, c2.rgb, uv.x) * ribbon * 0.10;
	col = mix(base.rgb, col, strength);
	// vignette
	vec2 v = (uv - 0.5) * vec2(1.1, 1.0);
	col *= 1.0 - dot(v, v) * 0.55;
	// dither
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) / 255.0;
	COLOR = vec4(col, 1.0);
}
