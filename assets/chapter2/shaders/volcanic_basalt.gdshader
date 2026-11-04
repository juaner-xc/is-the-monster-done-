shader_type spatial;
render_mode cull_disabled;
uniform bool walk_surface = false;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float line_distance(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float grain=noise(p*2.7)*0.55+noise(p*8.1)*0.25+noise(p*0.19)*0.20;
 float d=line_distance(p,vec2(-73,20),vec2(-39,20));
 d=min(d,line_distance(p,vec2(-39,20),vec2(-39,-95)));
 d=min(d,line_distance(p,vec2(-61,-14),vec2(-17,-14)));
 float road=walk_surface?1.0:1.0-smoothstep(2.2,4.0,d+noise(p*0.4)*1.1);
 vec2 cell=fract(p*0.84+vec2(noise(p*0.15),noise(p*0.13))*0.8);
 float edge=min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y));
 float joint=1.0-smoothstep(0.015,0.06,edge);
 vec3 rock=mix(vec3(0.055,0.048,0.042),vec3(0.16,0.14,0.115),grain);
 vec3 path=mix(vec3(0.17,0.15,0.125),vec3(0.30,0.27,0.225),grain);
 ALBEDO=mix(rock,path,road)*(1.0-joint*0.40);
 ROUGHNESS=0.97;
 float fissure=pow(1.0-abs(noise(p*0.36)*2.0-1.0),24.0)*(1.0-road);
 EMISSION=vec3(0.35,0.04,0.002)*fissure*0.35;
}
