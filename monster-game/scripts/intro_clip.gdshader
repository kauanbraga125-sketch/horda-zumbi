shader_type canvas_item;
varying vec2 world_point;
uniform float floor_line = 615.0;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() { if (world_point.y > floor_line) { discard; } }
