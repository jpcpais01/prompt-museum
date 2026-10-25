shader_type canvas_item;
// The download ring: a gradient arc that sweeps to `progress`, a soft glow
// under it and a bright head, all from one quad and a few distance tests.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 a : source_color = vec4(0.55, 0.42, 1.0, 1.0);
uniform vec4 b : source_color = vec4(0.24, 0.84, 0.96, 1.0);
uniform float thickness = 0.075;
uniform float spin = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.x, -p.y) / 6.28318 + 0.5;
	ang = fract(ang - 0.5);
	float radius = 0.78;
	float d = abs(r - radius);
	float track = smoothstep(thickness, thickness - 0.02, d);
	// indeterminate shimmer when spin > 0
	float prog = progress;
	float head = fract(TIME * 0.6);
	float on = spin > 0.5 ? step(fract(ang - head + 1.0), 0.25) : step(ang, prog);
	vec3 grad = mix(a.rgb, b.rgb, ang);
	vec3 col = vec3(1.0, 1.0, 1.0) * 0.07 * track;
	float alpha = 0.07 * track;
	float arc = track * on;
	col = mix(col, grad, arc);
	alpha = max(alpha, arc);
	float glow = exp(-d * d * 90.0) * on * 0.5;
	col += grad * glow;
	alpha = max(alpha, glow);
	COLOR = vec4(col, alpha * COLOR.a);
}
