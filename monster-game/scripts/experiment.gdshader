shader_type canvas_item;
render_mode unshaded;
uniform float amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 liquid : source_color = vec4(0.42,0.95,0.73,1.0);
void fragment() {
 vec2 uv=UV;
 vec2 p=(uv-0.5)*vec2(1.0,1.8);
 float d=length(max(abs(p)-vec2(0.34,0.74),vec2(0.0)))-0.15;
 float pane=1.0-smoothstep(-0.01,0.008,d);
 float wave=sin(uv.x*15.0+TIME*2.1)*0.012+sin(uv.x*27.0-TIME*1.3)*0.005;
 float level=0.985-clamp(amount,0.0,1.0)*0.97+wave;
 float fill=smoothstep(level-0.005,level+0.005,uv.y)*step(0.001,amount);
 vec3 col=mix(vec3(0.12,0.22,0.26),liquid.rgb*(0.62+0.38*(1.0-uv.y)),fill);
 float foam=(1.0-smoothstep(0.0,0.018,abs(uv.y-level)))*step(0.001,amount);
 col+=foam*liquid.rgb*0.45;
 for(int i=0;i<6;i++) {
  float f=float(i); vec2 b=vec2(0.15+fract(f*0.381)*0.7,0.99-fract(TIME*(0.08+f*0.009)+f*0.217)*0.97);
  float r=0.011+fract(f*0.38)*0.012;
  float bubble=1.0-smoothstep(r,r+0.005,length((uv-b)*vec2(1.0,1.9)));
  col+=bubble*fill*0.4;
 }
 col+=exp(-pow((uv.x-0.12)*38.0,2.0))*0.22;
 COLOR=vec4(col,(0.12+fill*0.85)*pane);
}
