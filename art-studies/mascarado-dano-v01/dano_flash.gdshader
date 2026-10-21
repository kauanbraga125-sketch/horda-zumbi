shader_type canvas_item;

uniform float hit_flash: hint_range(0.0,1.0) = 0.0;
uniform vec4 flash_color: source_color = vec4(1.0,0.70,0.64,1.0);

varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * item_tint;
	pixel.rgb = mix(pixel.rgb, flash_color.rgb, hit_flash * 0.72);
	COLOR = pixel;
}
