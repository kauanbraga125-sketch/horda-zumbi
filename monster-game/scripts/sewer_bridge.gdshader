shader_type canvas_item;
render_mode unshaded;

uniform sampler2D soil_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D sewer_texture : source_color, filter_linear, repeat_disable;
uniform float surface_y = 574.0;
uniform float gallery_offset = 460.0;
uniform float gallery_width = 1330.0;
uniform float gallery_height = 760.0;
uniform float scroll_x = 0.0;
uniform float soil_scroll_x = 0.0;
uniform float throat_depth = 180.0;
uniform float effect_time = 0.0;
uniform float shore_edge = 800.0;
uniform bool opening_mask = false;
uniform bool exit_mode = false;
varying vec2 scene_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float cloud_noise(vec2 p) {
	return (soft_noise(p) + 0.5 * soft_noise(p * 2.07 + vec2(13.4, 8.2))
		+ 0.25 * soft_noise(p * 4.13 + vec2(7.1, 19.6))) / 1.75;
}

vec4 joined_sample(sampler2D image, float x, float y, float width, float overlap) {
	float stride = width - overlap;
	float at = mod(x, stride);
	vec4 current = texture(image, vec2(at / width, clamp(y, 0.0, 1.0)));
	vec4 previous = texture(image, vec2((at + stride) / width, clamp(y, 0.0, 1.0)));
	return mix(previous, current, smoothstep(0.0, overlap, at));
}

void vertex() {
	scene_position = VERTEX;
}

void fragment() {
	float x = scene_position.x + scroll_x;
	float soil_x = scene_position.x + soil_scroll_x;
	float depth = scene_position.y - surface_y;
	float irregularity = (soft_noise(vec2(x * 0.007, depth * 0.006)) - 0.5) * 100.0;
	float join = smoothstep(gallery_offset - 20.0 + irregularity * 0.25,
		gallery_offset + 8.0 + irregularity * 0.25, depth);
	vec4 soil = joined_sample(soil_texture, soil_x, (depth + 105.0) / 1155.0, 1050.0, 160.0);
	vec4 sewer = joined_sample(sewer_texture, x, (depth - gallery_offset) / gallery_height,
		gallery_width, 140.0);
	// The opening is air, not a stone panel at the height of the road. The
	// already-existing wall is deeper, with an irregular spatial reveal.
	float broken_top = throat_depth + soft_noise(vec2(soil_x * 0.008, 3.8)) * 64.0;
	// A short, solid rock edge sits behind a separate moving cloud bank.
	// A long alpha ramp made the masonry look like a transparent ghost.
	float wall = smoothstep(broken_top, broken_top + 28.0, depth);
	vec3 fog = mix(vec3(0.20392, 0.12549, 0.28627), vec3(0.055, 0.038, 0.095),
		smoothstep(24.0, throat_depth + 180.0, depth));
	vec3 color = mix(fog, mix(soil.rgb, sewer.rgb, join), wall);
	float opacity = mix(smoothstep(2.0,throat_depth+120.0,depth)*0.78,1.0,wall);
	if (!exit_mode && depth > 0.0 && depth < gallery_offset + 115.0) {
		vec2 p = vec2((scene_position.x + scroll_x * 0.22) * 0.0042, depth * 0.010);
		float drift = effect_time * 0.055;
		float curl = soft_noise(p * 0.48 + vec2(drift * 0.36, 7.3));
		float mass = cloud_noise(p + vec2(-drift, drift * 0.24 + curl * 0.7));
		float wisps = cloud_noise(p * vec2(1.8, 1.3) + vec2(drift * 0.7, -drift * 0.38));
		float crest = throat_depth * 0.68 + (curl - 0.5) * 105.0;
		float upper_bank = exp(-pow((depth - crest) / (82.0 + curl * 45.0), 2.0));
		float lip_bank = exp(-pow((depth - broken_top - 2.0) / 66.0, 2.0));
		float lower_bank = exp(-pow((depth - gallery_offset + 5.0 - (curl - 0.5) * 60.0) / 98.0, 2.0));
		float volume = smoothstep(0.23, 0.76, mass * 0.78 + wisps * 0.30);
		float envelope = smoothstep(3.0, 55.0, depth)
			* (1.0 - smoothstep(gallery_offset - 5.0, gallery_offset + 110.0, depth));
		float mist = clamp((upper_bank * (0.40 + volume * 0.78)
			+ lip_bank * 0.68 + lower_bank * (0.25 + volume * 0.45)) * envelope, 0.0, 0.985);
		vec3 cloud = mix(vec3(0.15, 0.17, 0.25), vec3(0.36, 0.32, 0.44),
			clamp(volume * 0.72 + wisps * 0.36, 0.0, 1.0));
		cloud = mix(cloud, vec3(0.16, 0.24, 0.28), smoothstep(throat_depth, throat_depth + 180.0, depth) * 0.35);
		float combined = mist + opacity * (1.0 - mist);
		color = (cloud * mist + color * opacity * (1.0 - mist)) / max(combined, 0.0001);
		opacity = combined;
	}
	if (opening_mask) {
		float chips = (soft_noise(vec2(depth * 0.04, 7.6)) - 0.5) * 16.0;
		opacity *= smoothstep(shore_edge + chips - 4.0,
			shore_edge + chips + 8.0, scene_position.x);
	}
	if (exit_mode) {
		opacity = smoothstep(gallery_offset - 40.0 + irregularity * 0.4,
			gallery_offset + 65.0 + irregularity * 0.4, depth);
	}
	COLOR = vec4(color, opacity) * COLOR;
}
