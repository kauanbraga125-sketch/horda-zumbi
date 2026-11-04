shader_type canvas_item;
render_mode unshaded;

uniform sampler2D soil_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D sewer_texture : source_color, filter_linear, repeat_disable;
uniform float surface_y = 574.0;
uniform float gallery_offset = 460.0;
uniform float gallery_width = 1330.0;
uniform float gallery_height = 760.0;
uniform float scroll_x = 0.0;
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
	float depth = scene_position.y - surface_y;
	float irregularity = (soft_noise(vec2(x * 0.007, depth * 0.006)) - 0.5) * 100.0;
	float join = smoothstep(gallery_offset - 160.0 + irregularity,
		gallery_offset + 210.0 + irregularity, depth);
	vec4 soil = joined_sample(soil_texture, x, (depth + 105.0) / 1155.0, 1050.0, 160.0);
	vec4 sewer = joined_sample(sewer_texture, x, (depth - gallery_offset) / gallery_height,
		gallery_width, 140.0);
	vec3 color = mix(soil.rgb, sewer.rgb, join);
	// The far wall rises behind the road lip. Its ragged upper edge blends into
	// the cemetery silhouettes, rather than leaving a rectangular black gap.
	float lip = -110.0 + soft_noise(vec2(x * 0.012, 4.2)) * 38.0;
	float opacity = smoothstep(lip - 20.0, lip + 20.0, depth);
	if (opening_mask) {
		float recede = clamp(-depth, 0.0, 140.0) * 0.35;
		float chips = (soft_noise(vec2(depth * 0.04, 7.6)) - 0.5) * 16.0;
		opacity *= smoothstep(shore_edge - recede + chips - 4.0,
			shore_edge - recede + chips + 8.0, scene_position.x);
	}
	if (exit_mode) {
		opacity = smoothstep(gallery_offset - 40.0 + irregularity * 0.4,
			gallery_offset + 65.0 + irregularity * 0.4, depth);
	}
	COLOR = vec4(color, opacity) * COLOR;
}
