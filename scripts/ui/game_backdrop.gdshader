shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = UV - vec2(0.5, 0.38);
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float bloom = exp(-dot(p * vec2(1.8, 1.4), p * vec2(1.8, 1.4)) * 5.0);
	float vignette = smoothstep(0.2, 0.78, distance(UV, vec2(0.5)));
	vec3 base = vec3(0.060, 0.059, 0.087);
	base += vec3(0.021, 0.012, 0.040) * bloom;
	base -= vec3(0.014, 0.012, 0.014) * vignette;
	COLOR = vec4(base, 1.0);
}
