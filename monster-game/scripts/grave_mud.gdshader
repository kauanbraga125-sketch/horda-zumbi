shader_type canvas_item;
render_mode unshaded;
uniform sampler2D cleaned : filter_linear, repeat_disable;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=UV;
 float n=noise(uv*8.0)*0.6+noise(uv*25.0)*0.3+noise(uv*80.0)*0.1;
 float clean=texture(cleaned,uv).r;
 float alpha=1.0-smoothstep(0.22,0.8,clean);
 float edge=1.0-smoothstep(0.40,0.50,max(abs(uv.x-0.5),abs(uv.y-0.5)) + (n-0.5)*0.06);
 vec3 soil=mix(vec3(0.17,0.12,0.10),vec3(0.36,0.27,0.17),n);
 float moss=smoothstep(0.6,0.85,noise(uv*13.0+vec2(3.2,1.7)))*0.45;
 soil=mix(soil,vec3(0.22,0.34,0.12),moss);
 COLOR=vec4(soil,alpha*edge);
}
