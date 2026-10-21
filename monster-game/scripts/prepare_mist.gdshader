shader_type canvas_item;
render_mode unshaded;

uniform float age = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ritual_color : source_color = vec4(0.55, 0.95, 0.75, 1.0);
uniform float front_layer = 0.0;

float hash21(vec2 p) {
    vec2 q = fract(p * vec2(0.1031, 0.11369));
    q += dot(q, q.yx + 19.19);
    return fract((q.x + q.y) * q.x * q.y);
}
float cloud_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
               mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}
float clouds(vec2 p) {
    return cloud_noise(p) * 0.57 + cloud_noise(p * 2.03 + vec2(4.2, 8.1)) * 0.28
         + cloud_noise(p * 4.07 + vec2(11.3, 2.9)) * 0.15;
}
void fragment() {
    vec2 uv = UV;
    float flow = age * 0.65;
    vec2 p = vec2(uv.x * 5.0, uv.y * 3.4);
    float curl = clouds(p + vec2(-flow * 0.6, flow * 0.35));
    float detail = clouds(p * 1.3 + vec2(curl * 1.5 - flow, -flow));
    float center_y = mix(0.57, 0.83, front_layer) + sin(uv.x * 9.0 + flow * 1.4 + curl * 3.0) * 0.075;
    float band = exp(-pow((uv.y - center_y) / mix(0.27, 0.14, front_layer), 2.0));
    float sides = smoothstep(0.0, 0.16, uv.x) * (1.0 - smoothstep(0.84, 1.0, uv.x));
    float edge = smoothstep(0.02, 0.18, uv.y) * (1.0 - smoothstep(0.92, 1.0, uv.y));
    float density = smoothstep(0.24, 0.78, detail) * band;
    float ribbon = pow(max(0.0, 1.0 - abs((uv.y - center_y) * 9.0 + sin(uv.x * 13.0 + curl * 4.0 - flow * 2.0) * 0.35)), 3.0);
    vec3 shade = mix(vec3(0.12, 0.055, 0.20), ritual_color.rgb, 0.40 + curl * 0.48);
    shade += ritual_color.rgb * ribbon * 0.24;
    float alpha = (density * 0.60 + ribbon * band * 0.11) * sides * edge * strength;
    COLOR = vec4(shade, alpha * mix(1.0, 0.70, front_layer));
}
