shader_type canvas_item;
render_mode unshaded;
uniform float amount : hint_range(0.0,1.0) = 0.5;
uniform vec4 liquid : source_color = vec4(0.4,1.0,0.25,1.0);
uniform float clock = 0.0;
uniform float energy = 0.0;
uniform float speed = 1.0;
float surface(float x) {
 float waves=(sin(x*10.0+clock*2.1*speed)+0.45*sin(x*23.0-clock*3.2*speed))*(0.009+energy*0.018);
 return clamp(1.0-amount+waves*min(amount*15.0,1.0),-0.03,1.03);
}
float window_mask(vec2 uv) {
 vec2 q=abs(uv-vec2(0.5))-vec2(0.38,0.42);
 float d=length(max(q/vec2(0.12,0.08),vec2(0.0)))-1.0;
 return 1.0-smoothstep(-0.03,0.02,d);
}
void fragment() {
 vec2 uv=UV;float mask=window_mask(uv);float line=surface(uv.x);
 float filled=smoothstep(line-0.006,line+0.006,uv.y)*step(0.001,amount);
 float depth=clamp((uv.y-line)/max(amount,0.03),0.0,1.0);
 vec3 base=mix(liquid.rgb*1.03,liquid.rgb*0.21,depth*0.85);
 float rim=(1.0-smoothstep(0.002,0.018,abs(uv.y-line)))*filled;
 base+=rim*mix(liquid.rgb,vec3(1.0),0.68)*0.75;
 float caustic=pow(0.5+0.5*sin(uv.x*24.0+sin(uv.y*18.0-clock)*1.4+clock*0.8),9.0);
 base+=liquid.rgb*caustic*0.14;
 float bubbles=0.0;
 for(int i=0;i<14;i++) {
  float n=float(i);float life=fract(clock*(0.11+0.015*mod(n,4.0))*speed+n*0.173);
  float y=1.02-life*max(amount,0.06);float x=0.12+0.76*fract(sin(n*76.21)*431.71)+sin(clock*1.5+n)*0.024;
  vec2 d=(uv-vec2(x,y))*vec2(0.62,1.0);float rad=0.009+0.007*mod(n,3.0);
  bubbles+=max(0.0,1.0-abs(length(d)-rad)/0.0035)*smoothstep(0.0,0.14,life)*(1.0-smoothstep(0.85,1.0,life));
  float popping=clamp((life-0.82)/0.18,0.0,1.0);
  vec2 pd=(uv-vec2(x,surface(x)))*vec2(0.62,1.8);
  bubbles+=max(0.0,1.0-abs(length(pd)-(rad+popping*0.024))/0.004)*step(0.82,life)*(1.0-popping)*0.65;
 }
 base+=vec3(0.75,0.95,1.0)*bubbles*0.6;
 float glass=pow(1.0-clamp(abs(uv.x-0.14)*22.0,0.0,1.0),3.0)*0.27+pow(1.0-clamp(abs(uv.x-0.88)*40.0,0.0,1.0),3.0)*0.16;
 vec3 empty=vec3(0.025,0.07,0.13)+vec3(0.25,0.6,0.65)*glass;
 COLOR=vec4(mix(empty,base,filled)+glass*0.3,mask*mix(0.82,0.97,filled));
}
