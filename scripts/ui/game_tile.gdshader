shader_type canvas_item;
render_mode unshaded;

uniform vec2 tile_size = vec2(126.0);
uniform float padding = 20.0;
uniform vec4 accent : source_color = vec4(0.72, 0.52, 0.98, 1.0);
uniform vec4 hit_color : source_color = vec4(0.72, 0.52, 0.98, 1.0);
uniform float activation : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform bool judgment_mode = false;

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 extent = tile_size + vec2(padding * 2.0);
	vec2 p = (UV - 0.5) * extent;
	float radius = tile_size.x * 0.145;
	float d = rounded_box(p, tile_size * 0.5 - vec2(0.8), radius);
	float inside = 1.0 - smoothstep(-0.7, 0.7, d);
	float rim = 1.0 - smoothstep(0.1, 1.3, abs(d + 0.65));
	float vertical = clamp(p.y / tile_size.y + 0.5, 0.0, 1.0);
	float diagonal = clamp((p.x - p.y) / tile_size.x + 0.4, 0.0, 1.0);
	float feedback_weight = judgment_mode ? smoothstep(0.0, 0.07, flash) : 0.0;
	vec3 phase_color = mix(accent.rgb, hit_color.rgb, feedback_weight);
	vec3 surface = mix(vec3(0.116, 0.115, 0.154), vec3(0.094, 0.095, 0.131), vertical);
	surface += accent.rgb * activation * (0.025 + 0.045 * diagonal);
	float surface_flash = flash * (judgment_mode ? 0.22 : 0.96);
	surface = mix(surface, hit_color.rgb * (0.90 + 0.20 * diagonal), surface_flash);
	// A restrained inner reflection; the tile stays quiet between notes.
	float inner_light = exp(-abs(d) * 0.10) * inside;
	surface += phase_color * inner_light * activation * 0.11;
	surface += hit_color.rgb * inner_light * flash * 0.22;
	vec3 edge = mix(vec3(0.34, 0.33, 0.43), phase_color, max(activation * 0.85, feedback_weight * 0.85));
	edge = mix(edge, mix(hit_color.rgb, vec3(1.0), 0.57), flash);
	edge += vec3(0.13) * activation * (1.0 - vertical);
	vec3 color = mix(surface, edge, rim);
	float halo = exp(-max(d, 0.0) * 0.16) * (1.0 - inside);
	float halo_alpha = halo * (activation * 0.055 + flash * 0.43);
	COLOR = vec4(mix(hit_color.rgb, color, inside), max(inside, halo_alpha));
}
