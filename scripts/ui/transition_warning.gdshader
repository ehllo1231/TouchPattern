shader_type canvas_item;
render_mode unshaded;

uniform float halo_power = 1.0;
varying vec4 lamp;
const vec2 CORNERS[4] = {vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0)};

void vertex() {
	lamp = COLOR;
}

void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	// The mask is rasterized at 4x. Filter its silhouette at two radii to
	// spread light around each tube, including the stem and dot.
	float close_glow = 0.0;
	float wide_glow = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 offset = TEXTURE_PIXEL_SIZE * CORNERS[i];
		close_glow += 0.25 * textureLod(TEXTURE, UV + offset * 4.0, 3.4).a;
		wide_glow += 0.25 * textureLod(TEXTURE, UV + offset * 11.0, 4.8).a;
	}
	float power = lamp.a;
	float halo = min(0.82, close_glow * 1.15 + wide_glow * 0.95) * halo_power;
	// The center stays legible through the dip; the color spill blooms at lock-on.
	float tube = mask.a * power;
	float alpha = tube + (1.0 - tube) * halo;
	vec3 core = mix(lamp.rgb, vec3(1.0), 0.83);
	vec3 color = mix(lamp.rgb, core, mask.r * tube / max(alpha, 0.0001));
	COLOR = vec4(color, alpha);
}
