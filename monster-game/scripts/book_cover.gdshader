shader_type canvas_item;
uniform float blink : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec4 base = texture(TEXTURE,UV);
	vec2 eye = (UV-vec2(.55,.375))/vec2(.18,.08);
	float mask = (1.0-smoothstep(.85,1.0,length(eye)))*smoothstep(1.0-blink-.08,1.0-blink+.08,abs(eye.y));
	vec3 lid = mix(vec3(.18,.035,.21),vec3(.34,.075,.32),clamp(.5+eye.y*.5,0.0,1.0));
	if (UV.x > .956 && UV.y > .47 && UV.y < .79) { base.a = 0.0; }
	COLOR = vec4(mix(base.rgb,lid,mask*blink),base.a)*COLOR;
}
