shader_type canvas_item;
// SCREEN_UV belongs to the 640x400 cabin viewport, shared by body and clothing.
uniform sampler2D window_mask : filter_linear, repeat_disable;
void fragment() {
	COLOR.a *= texture(window_mask, SCREEN_UV).a;
}
