shader_type canvas_item;
render_mode unshaded;
uniform vec2 pane_origin;
uniform vec2 pane_size;
uniform float amount = 0.5;
uniform float clock = 0.0;
uniform float energy = 0.0;
uniform float speed = 1.0;
uniform vec4 liquid : source_color;
uniform float creature = 0.0;
varying vec2 local_point;
void vertex() {
 VERTEX.x+=sin(UV.y*7.0+clock*1.7)*creature*1.2;
 local_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
 vec2 uv=(local_point-pane_origin)/pane_size;
 float wave=(sin(uv.x*10.0+clock*2.1*speed)+0.45*sin(uv.x*23.0-clock*3.2*speed))*(0.009+energy*0.018)*min(amount*15.0,1.0);
 float line=clamp(1.0-amount+wave,-0.03,1.03);
 vec4 tex=texture(TEXTURE,UV);
 float wet=smoothstep(line,line+0.015,uv.y)*step(0.001,amount);
 vec2 q=abs(uv-vec2(0.5))-vec2(0.38,0.42);
 float edge=1.0-smoothstep(-0.03,0.02,length(max(q/vec2(0.12,0.08),vec2(0.0)))-1.0);
 COLOR=vec4(mix(tex.rgb,tex.rgb*liquid.rgb+liquid.rgb*0.2,0.19),tex.a*wet*edge*step(0.0,uv.y)*step(uv.y,1.0));
}
