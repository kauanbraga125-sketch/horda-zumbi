shader_type canvas_item;
render_mode unshaded;

uniform float seed = 0.0;
uniform float motion = 0.002;
uniform vec2 eye_a = vec2(-1.0);
uniform vec2 eye_b = vec2(-1.0);
uniform vec2 eye_radius = vec2(0.025, 0.018);
uniform vec4 spirit : source_color = vec4(0.54, 0.97, 0.81, 1.0);
uniform float eye_light = 0.0;
uniform float blink_strength = 0.0;

void fragment() {
	vec2 uv = UV;
	float clock = TIME + seed;
	uv.x += sin(clock * 1.35 + uv.y * 4.0) * motion * (1.0-smoothstep(0.15, 0.95, uv.y));
	uv.y = (uv.y - 0.94) / (1.0 + sin(clock * 1.05) * 0.003) + 0.94;
	vec4 pixel = texture(TEXTURE, uv);
	float a = exp(-dot((uv-eye_a)/eye_radius,(uv-eye_a)/eye_radius) * 1.8);
	float b = exp(-dot((uv-eye_b)/eye_radius,(uv-eye_b)/eye_radius) * 1.8);
	float eyes = clamp(a+b, 0.0, 1.0);
	float phase = mod(clock, 6.7);
	float blink = smoothstep(6.20,6.29,phase) * (1.0-smoothstep(6.33,6.46,phase));
	pixel.rgb *= 1.0-eyes*blink*blink_strength;
	pixel.rgb += spirit.rgb * eyes * eye_light * (0.6+0.4*sin(clock*1.8));
	COLOR = pixel * COLOR;
}
