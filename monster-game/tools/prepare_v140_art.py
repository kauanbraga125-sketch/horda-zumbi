"""Extract real connected cels, register hips, and isolate animation textures.

No artwork is synthesized here: these operations separate the generated sprites
and establish explicit geometry instead of assuming an evenly spaced source grid.
"""
from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np,json,io,os,importlib.util
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT/'tools/art_sources/v140';OUT=ROOT/'assets/art/v140'
spec=importlib.util.spec_from_file_location('v139',ROOT/'tools/prepare_v139_art.py');old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)

def save(im,name):
 stream=io.BytesIO();im.save(stream,'WEBP',lossless=True,method=6);old.fullwrite(OUT/name,stream.getvalue());Image.open(OUT/name).load()

def components(im,minimum=2500):
 a=np.array(im);labels,n=ndimage.label(a[:,:,3]>96);parts=[]
 for i,s in enumerate(ndimage.find_objects(labels),1):
  if s is None:continue
  mask=labels[s]==i
  if mask.sum()<minimum:continue
  y,x=s;full=labels==i;full=ndimage.binary_dilation(full,iterations=2)
  q=a.copy();q[:,:,3]*=full.astype(np.uint8)
  box=(max(0,x.start-2),max(0,y.start-2),min(im.width,x.stop+2),min(im.height,y.stop+2))
  parts.append({'image':Image.fromarray(q).crop(box),'box':box,'area':int(mask.sum())})
 return parts

def packed(name,frames,columns=4):
 cell=frames[0].size;out=Image.new('RGBA',(columns*cell[0],((len(frames)+columns-1)//columns)*cell[1]))
 for i,f in enumerate(frames):out.paste(f,((i%columns)*cell[0],(i//columns)*cell[1]))
 save(out,name+'.webp');return {'cell':list(cell),'columns':columns,'rows':(len(frames)+columns-1)//columns,'frames':len(frames)}

def riders(kind,name):
 im=Image.open(SRC/(name+'.png')).convert('RGBA');parts=components(im);assert len(parts)==12,(name,len(parts))
 parts.sort(key=lambda p:p['box'][1]);parts=[p for row in range(3) for p in sorted(parts[row*4:row*4+4],key=lambda p:p['box'][0])]
 scale=320/max(p['image'].height for p in parts[:8]);frames=[];poses=[];bodies=[];arms=[]
 for i,p in enumerate(parts):
  raw=p['image'];arr=np.array(raw);r,g,b,alpha=[arr[:,:,j].astype(float) for j in range(4)];yy,xx=np.indices(r.shape)
  if kind==0:
   mask=(r>g*1.3)&(g>b*1.13)&(r>55)&(r<190)&(alpha>150)&(yy>raw.height*.50)&(xx<raw.width*.68)
   py,px=np.where(mask);hip=np.array([np.median(px)+6,np.median(py)-15])
  else:
   mask=(r>170)&(g>130)&(b>65)&(b<g*.96)&(alpha>150)&(yy>raw.height*.57)&(xx<raw.width*.78)
   py,px=np.where(mask);assert len(px)>10,(name,i)
   hip=np.array([np.median(px)-26,np.percentile(py,20)-5])
  size=tuple(max(1,round(v*scale)) for v in raw.size);piece=raw.resize(size,Image.Resampling.LANCZOS)
  anchor=np.array([174,285]);offset=np.rint(anchor-hip*scale).astype(int)
  frame=Image.new('RGBA',(448,448));frame.paste(piece,tuple(offset))
  near,far=old.eyes(frame,kind)
  if kind==0 and i==10:near,far=[266,267],[296,263]
  near=np.array(near,dtype=float);far=np.array(far,dtype=float);direction=(far-near);direction/=np.linalg.norm(direction);down=np.array([-direction[1],direction[0]])
  width=float(np.linalg.norm(far-near)/(.38 if kind==0 else .37));width=np.clip(width,100,170)
  neck=near-direction*(.34 if kind==0 else .38)*width+down*.48*width
  head_poly=[near+direction*x*width+down*y*width for x,y in [(-2.0,-2.0),(1.5,-2.0),(1.5,.40),(.35,.60),(-.50,.35),(-2.0,.10)]]
  body=frame.copy();maskhead=Image.new('L',frame.size,0);draw=ImageDraw.Draw(maskhead);draw.polygon([tuple(p) for p in head_poly],fill=255)
  ba=np.array(body);ba[:,:,3]=np.where(np.array(maskhead)>0,0,ba[:,:,3]);body=Image.fromarray(ba)
  # Hands/forearms in front of a tucked head, kept in an explicit local patch.
  arm=Image.new('RGBA',frame.size)
  if i>=8:
   floor=int(near[1]+width*.27);left=int(near[0]-width*.55);right=min(448,int(near[0]+width*.66));bottom=min(448,floor+int(width*.31))
   arm.paste(frame.crop((max(0,left),max(0,floor),right,bottom)),(max(0,left),max(0,floor)))
  frames.append(frame);bodies.append(body);arms.append(arm)
  poses.append({'near':near.round(3).tolist(),'far':far.round(3).tolist(),'neck':neck.round(3).tolist(),'hip':anchor.tolist(),'height':360,'head_width':float(width),'source_bounds':list(p['box']),'registered':True})
 entry=packed(name,frames);packed(name+'_body',bodies);packed(name+'_arms',arms);entry['poses']=poses
 return entry

def main():
 OUT.mkdir(parents=True,exist_ok=True);layout={}
 for k,n in enumerate(['zombie_riders','skeleton_riders']):layout[n]=riders(k,n)
 source=Image.open(ROOT/'tools/art_sources/v139/flood.png').convert('RGBA');bycol=[]
 for col in range(4):
  crop=source.crop((col*source.width//4,0,(col+1)*source.width//4,source.height));parts=components(crop,10000);assert len(parts)==4
  parts.sort(key=lambda p:p['box'][1]);bycol.append(parts)
 frames=[]
 for row in range(4):
  for col in range(4):
   raw=bycol[col][row]['image'];raw=raw.resize((304,416),Image.Resampling.LANCZOS)
   cel=Image.new('RGBA',(320,448));cel.paste(raw,(8,16));frames.append(cel)
 layout['flood']=packed('flood',frames);layout['flood']['isolated_cels']=True;layout['flood']['waterline']=432
 props=components(Image.open(SRC/'props.png').convert('RGBA'),20000);assert len(props)==4,len(props)
 props.sort(key=lambda p:p['box'][1]);top=sorted(props[:2],key=lambda p:p['box'][0]);bottom=sorted(props[2:],key=lambda p:p['box'][0])
 for name,p in zip(['ramp','spike','pump_base','gate'],top+bottom):
  im=p['image'];save(im,name+'.webp');layout[name]={'size':list(im.size),'bounds':list(p['box'])}
 # Isolate full original civilian/vehicle cels without using uniform row cuts.
 parts=components(Image.open(ROOT/'tools/art_sources/v139/fugitives.png').convert('RGBA'),5000);assert len(parts)==12,len(parts)
 parts.sort(key=lambda p:p['box'][1]);parts=[p for row in range(3) for p in sorted(parts[row*4:row*4+4],key=lambda p:p['box'][0])]
 frames=[]
 for p in parts:
  raw=p['image'];factor=480/raw.width;raw=raw.resize((480,round(raw.height*factor)),Image.Resampling.LANCZOS)
  f=Image.new('RGBA',(512,384));f.paste(raw,(16,368-raw.height));frames.append(f)
 layout['fugitives']=packed('fugitives',frames);layout['fugitives']['bounds']=[[16,0,496,368] for _ in frames]
 parts=components(Image.open(SRC/'captives.png').convert('RGBA'),5000);assert len(parts)==8,len(parts)
 parts.sort(key=lambda p:p['box'][1]);parts=[p for row in range(2) for p in sorted(parts[row*4:row*4+4],key=lambda p:p['box'][0])]
 frames=[]
 for p in parts:
  raw=p['image'];factor=280/max(raw.size);size=tuple(round(v*factor) for v in raw.size);raw=raw.resize(size,Image.Resampling.LANCZOS)
  f=Image.new('RGBA',(320,320));f.paste(raw,((320-size[0])//2,(320-size[1])//2));frames.append(f)
 layout['captives']=packed('captives',frames)
 parts=components(Image.open(SRC/'civil_boat.png').convert('RGBA'),5000);part=max(parts,key=lambda p:p['area'])['image'];save(part,'civil_boat.webp');layout['civil_boat']={'size':list(part.size)}
 # Static rotor and existing survivor/civilian cels also get independent textures at runtime.
 old.fullwrite(OUT/'layout.json',(json.dumps(layout,separators=(',',':'))+'\n').encode())
 print('V140_ART_OK',[(k,v.get('frames',1)) for k,v in layout.items()])
if __name__=='__main__':main()
