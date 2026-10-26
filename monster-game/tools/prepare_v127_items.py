"""Nine fitted cosmetics. Source PNGs remain untouched; all cuts use native UVs."""
import argparse,copy,hashlib,io,json,math,struct
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.measure import find_contours
from skimage.segmentation import watershed
from shapely.geometry import Polygon,Point,box
from shapely.ops import unary_union
from shapely.affinity import affine_transform
from shapely import constrained_delaunay_triangles
import zstandard
HATS=['s_chaos','s_north','s_wizard','s_striped','s_ice']
ITEMS=['z_scientist','z_vampire','z_scarf','z_chain']+HATS
REG={
 'scientist':{'matrix':[[1.4768330160644316,-.0023723503380343493,-236.76310960405738],[.0023723503380343736,1.476833016064432,-57.89884908389513],[0,0,1]],'source_eyes':[[620.0428571428571,597.3492063492064],[709.8783783783783,597.4549549549549]]},
 'cape':{'matrix':[[1.2602136000912132,-.010008432241986345,-37.438287390352684],[.010008432241986519,1.2602136000912134,-168.10037187064188],[0,0,1]],'source_eyes':[[756.9577677224736,587.15987933635],[844.9047619047619,590.9391534391534]]},
 'scarf':{'matrix':[[1.44,0,-131],[0,1.44,-235],[0,0,1]],'source_eyes':[[618.9262589928057,596.7625899280575],[710.5947580645161,595.5141129032259]]},
 'chain':{'matrix':[[1.6440037771482532,-.08498583569405137,-290.9244570349383],[.08498583569405134,1.6440037771482532,-420.5826251180363],[0,0,1]],'source_eyes':[[615.3340961098398,598.9427917620137],[709.4016913319239,596.7209302325581]]},
 'skull':{'sprite_eyes':[[648.8393051031487,667.0716612377851],[776.6236044657097,699.444976076555]]}}
TARGET_IRISES=[[110.71153846153847,107.38461538461539],[139.48717948717947,108.74358974358974]]

def geometry(mask):
 result=None
 for contour in find_contours(np.pad(mask.astype('uint8'),1),.5):
  if len(contour)<4:continue
  p=Polygon(contour[:,::-1]-.5).simplify(.45,preserve_topology=True)
  if not p.is_valid:p=p.buffer(0)
  if not p.is_empty:result=p if result is None else result.symmetric_difference(p)
 return Polygon() if result is None else result

def mesh(g):
 if not g.is_valid:g=g.buffer(0)
 points=[];indices=[];lookup={}
 for t in constrained_delaunay_triangles(g).geoms:
  for point in list(t.exterior.coords)[:3]:
   k=tuple(round(float(v),3) for v in point)
   if k not in lookup:lookup[k]=len(points);points.append(k)
   indices.append(lookup[k])
 return {'points':points,'indices':indices}

def mesh_geometry(data):
 p=data['points'];ids=data['indices']
 return unary_union([Polygon([p[ids[i+j]] for j in range(3)]) for i in range(0,len(ids),3)])

def similarity(source,target):
 a,b=np.array(source);c,d=np.array(target);v=b-a;w=d-c
 angle=math.atan2(w[1],w[0])-math.atan2(v[1],v[0]);s=np.linalg.norm(w)/np.linalg.norm(v)
 basis=np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]])*s
 return basis,c-basis@a

def rig_transform(rig,f):
 right=np.array(f['right']);down=np.array(f['down']);w=f['head_width'];angle=math.atan2(right[1],right[0])+rig['angle'];s=w*rig['scale']
 basis=np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]])*s
 offset=rig['offset'];origin=np.array(f['landmarks']['throat'])+(right*offset[0]+down*offset[1])*w-basis@rig['anchor']
 return basis,origin

def transformed(g,b,o):return affine_transform(g,[b[0,0],b[0,1],b[1,0],b[1,1],o[0],o[1]])

def generated(root,name):
 path=root/'assets/art/cosmetics_v127'/(name+'.png');im=Image.open(path).convert('RGBA');p=np.asarray(im);w,h=im.size;rel='.godot/imported/'+name+'-v127-lossless.ctex';target=root/rel;target.parent.mkdir(parents=True,exist_ok=True)
 payload=target.read_bytes()[56:] if target.exists() else b''
 if not payload or not np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')),p):
  s=io.BytesIO();im.save(s,format='WEBP',lossless=True,quality=100,method=3,exact=True);payload=s.getvalue()
 assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')),p)
 target.write_bytes(struct.pack('<4s8I',b'GST2',1,w,h,0,0xffffffff,0,0,0)+struct.pack('<IHHIII',2,w,h,0,5,len(payload))+payload)
 path.with_suffix('.png.import').write_text(f'''[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\npath="res://{rel}"\nmetadata={{"vram_texture": false}}\n\n[deps]\n\nsource_file="res://assets/art/cosmetics_v127/{name}.png"\ndest_files=["res://{rel}"]\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=true\n''')
 ys,xs=np.where(p[:,:,3]>10);g=geometry(p[:,:,3]>0)
 graphic={'file':'cosmetics_v127/'+name+'.png','rect':[0,0,w,h],'contacts':[[.3,.75],[.8,.65]],'bounds':[int(xs.min()),int(ys.min()),int(xs.max()-xs.min()+1),int(ys.max()-ys.min()+1)],'mesh':mesh(g)}
 return graphic,g,{'name':name,'png_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'rgba_sha256':hashlib.sha256(p.tobytes()).hexdigest(),'lossless':True}

def prepare(root):
 art=root/'assets/art';folder=art/'cosmetics_v127';before=json.loads((root/'tests/v127_before_graphics.json').read_text());graphics=copy.deepcopy(before);packed=(art/'cosmetics_v113/fitting.bin').read_bytes();frames=json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]));canonical=frames['z_run_6'];right=np.array(canonical['right']);down=np.array(canonical['down']);W=canonical['head_width'];reports=[];fronts={}
 for name,id in [('scientist','z_scientist'),('cape','z_vampire'),('scarf','z_scarf'),('chain','z_chain'),('skull',None)]:
  graphic,g,report=generated(root,name);reports.append(report)
  if name=='skull':
   eyes=REG[name]['sprite_eyes'];graphic['registered_eyes']={'near':eyes[0],'far':eyes[1]}
   # Only the rear cranium and crown are new; original expressions stay live.
   crown=box(-100,-100,1400,570).union(box(-100,-100,540,700));solid=crown.buffer(-14)
   inner=mesh(g.intersection(solid));outer=mesh(g.intersection(crown.difference(solid)))
   graphic['mesh']={'points':inner['points']+outer['points'],'indices':inner['indices']+[i+len(inner['points']) for i in outer['indices']],'alpha':[1.0]*len(inner['points'])+[float(np.clip(crown.boundary.distance(Point(p))/14,0,1)) for p in outer['points']]}
   (folder/'skull.json').write_text(json.dumps(graphic,separators=(',',':')));continue
  mat=np.array(REG[name]['matrix']);points=(mat@np.column_stack([REG[name]['source_eyes'],np.ones(2)]).T).T[:,:2];basis,origin=similarity(points,TARGET_IRISES)
  if name=='scientist':
   anchor=points[0];delta=(basis@anchor+origin-np.array(canonical['landmarks']['scalp']))/W
   graphic['hair_fit']={'anchor':anchor.tolist(),'scale':float(np.linalg.norm(basis[:,0])/W),'offset':[float(delta@right),float(delta@down)],'angle':float(math.atan2(basis[1,0],basis[0,0])-math.atan2(right[1],right[0]))};graphic['source_mesh']='scientist_base_v127';graphic['reveal_source']='scientist_details_v127'
  else:
   anchor=np.array({'cape':[833,735],'scarf':[465,737],'chain':[555,829]}[name]);delta=(basis@anchor+origin-np.array(canonical['landmarks']['throat']))/W
   graphic['wardrobe_rig']={'anchor':anchor.tolist(),'scale':float(np.linalg.norm(basis[:,0])/W),'offset':[float(delta@right),float(delta@down)],'angle':float(math.atan2(basis[1,0],basis[0,0])-math.atan2(right[1],right[0]))};graphic.update(frame_front=True,layered_neck=True,native_occlusion=True)
   fronts[id]=g.intersection(Polygon([(510,585),(1000,585),(1000,800),(785,800),(590,710),(510,675)])) if name=='cape' else g.intersection(box(448,660,830,900)) if name=='scarf' else g
  graphics[id]=graphic;print('texture',name,flush=True)
 for id in HATS:
  g=graphics[id];g.pop('preserve_source',None);g['source_mesh']='skull_base_v127';g['skull_underlay']=True;height=-.12 if id=='s_wizard' else -.06 if id=='s_striped' else .02;g['skull_fit']=[[-.66,height],[.54,height]]
 outlines=json.loads((art/'zombie-fluid-v73.json').read_text())['frames'];cache={};layers={}
 for key,f in frames.items():
  if f['file'] not in cache:cache[f['file']]=np.asarray(Image.open(art/f['file']).convert('RGBA'))
  x,y,w,h=map(int,f['rect']);r,g,b,a=cache[f['file']][y:y+h,x:x+w].astype(float).transpose(2,0,1);yy,xx=np.mgrid[:h,:w];W=f['head_width'];l,t,rr,bb=f['box'];lm=f['landmarks'];near=np.array(lm['near']);far=np.array(lm['far']);chin=np.array(lm['chin']);clip=Polygon(outlines[int(key.rsplit('_',1)[1])]['outline']) if key.startswith('z_other_') else box(0,0,w,h);opaque=geometry(a>0).intersection(clip);layer={'meshes':{},'front':{}}
  if f['kind']==0:
   skin=(g>r*1.02)&(g>b*1.2)&(a>10);neck_y=lm['neck'][1];head=(yy<neck_y-.14*W)&(xx>l-.72*W)&(xx<rr+.35*W);purple=(r>g*1.12)&(b>g*1.16)&(b>r*.60)&(a>5)&head;labels,n=ndi.label(purple);hair=np.zeros_like(purple)
   for label,s in enumerate(ndi.find_objects(labels),1):
    if s is not None and (s[0].start<t+.14*W or (s[1].start<l+.08*W and s[0].start<neck_y-.30*W)):hair|=labels==label
   old=ndi.binary_dilation(hair,iterations=max(2,round(W*.022)))&head
   for p,rx,ry in [(near,.24,.16),(far,.15,.13)]:old &= ~((((xx-p[0])/(W*rx))**2+((yy-p[1])/(W*ry))**2)<1)
   mouth=(yy>chin[1]-.24*W)&(yy<chin[1]+.08*W)&(xx>near[0]-.20*W)&(xx<rr+.08*W);old &= ~mouth
   layer['meshes']['scientist_base_v127']=mesh(opaque.difference(geometry(old)))
   face=ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(skin,iterations=1)),iterations=2);details=((face&(yy>near[1]-.11*W)&(yy<neck_y-.15*W))|(face&(xx<l+.34*W)&(yy>t+.25*W)&(yy<neck_y-.14*W)))&~old
   for p,rx,ry in [(near,.235,.15),(far,.14,.115)]:details |= ((((xx-p[0])/(W*rx))**2+((yy-p[1])/(W*ry))**2)<1)&~old
   layer['meshes']['scientist_details_v127']=mesh(opaque.intersection(geometry(details)))
   jaw=Polygon([(l-.12*W,t-.12*W),(rr+.20*W,t-.12*W),(rr+.20*W,bb-.03*W),(near[0]+.12*W,bb+.015*W),(l+.36*W,bb-.12*W),(l-.12*W,bb-.19*W)])
   arms=skin&(yy>bb-.03*W)&(yy<t+2.35*W);arms=ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(arms,iterations=1)),iterations=2);throat=np.array(lm['throat']);arms &= ~((((xx-throat[0])/(.16*W))**2+((yy-throat[1])/(.12*W))**2)<1)
   occluder=opaque.intersection(jaw).union(geometry(arms).difference(jaw.buffer(-.5)).intersection(opaque))
   for id in ['z_vampire','z_scarf','z_chain']:
    basis,origin=rig_transform(graphics[id]['wardrobe_rig'],f);inv=np.linalg.inv(basis);layer['front'][id]=mesh(fronts[id].difference(transformed(occluder,inv,-inv@origin)))
  else:
   ivory=(r>140)&(g>105)&(b<g*.96)&(r>g*1.015)&(a>10)&(xx>l-.25*W)&(xx<rr+.20*W)&(yy>t-.20*W)&(yy<bb+.25*W);face=ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(ivory,iterations=1)),iterations=2);face_g=geometry(face)
   cloth=ndi.binary_closing((b>g*1.22)&(r>g*1.18)&(a>8),iterations=2)&(a>0);roi=(xx>l-.98*W)&(xx<rr+.18*W)&(yy<t+1.14*W);marker=np.zeros((h,w),dtype=np.int32);marker[cloth&~roi]=2
   for sx,sy in [(l-.35*W,t+.23*W),(l-.25*W,t+.60*W),(l+.25*W,t-.15*W)]:
    candidate=cloth&roi&(((xx-sx)**2+(yy-sy)**2)<(.22*W)**2)
    if candidate.any():
     ys,xs=np.where(candidate);i=np.argmin((xs-sx)**2+(ys-sy)**2);marker[ys[i],xs[i]]=1
   marker[cloth&(yy>near[1]+.28*W)]=2;labels=watershed(255-ndi.gaussian_filter(np.maximum(r,b),.6),marker,mask=cloth);hood=ndi.binary_dilation(labels==1,iterations=2)&~ndi.binary_erosion(labels==2,iterations=1);keep=opaque.difference(geometry(hood)).union(opaque.intersection(face_g))
   if keep.geom_type=='MultiPolygon':
    bones=geometry((r>140)&(g>105)&(b<g*.96)&(r>g*1.015)&(a>10));lower=box(-1,near[1]+.36*W,w+1,h+1);largest=max(keep.geoms,key=lambda p:p.area);keep=unary_union([p for p in keep.geoms if p==largest or p.intersects(lower) or p.intersects(bones)])
   layer['meshes']['skull_base_v127']=mesh(keep);layer['meshes']['skull_base_v127_cape']=mesh(keep.intersection(mesh_geometry(f['meshes']['cape_only'])))
  layers[key]=layer
  if len(layers)%40==0:print('frames',len(layers),flush=True)
 payload=json.dumps(layers,separators=(',',':')).encode();(folder/'layers.bin').write_bytes(struct.pack('<I',len(payload))+zstandard.ZstdCompressor(level=12).compress(payload));(art/'cosmetics_v113/graphics.json').write_text(json.dumps(graphics,separators=(',',':')))
 assert {k:v for k,v in graphics.items() if k not in ITEMS}=={k:v for k,v in before.items() if k not in ITEMS}
 refs=root/'tools/art_sources/v127';(refs/'registration.json').write_text(json.dumps(REG,indent=2));report={'frames':len(layers),'item_frame_occlusions':288,'other_items_preserved':26,'new_art':reports,'original_fitting_sha256':hashlib.sha256(packed).hexdigest()};(refs/'preparation.json').write_text(json.dumps(report,indent=2));print('V127_PREPARATION_OK',json.dumps(report),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);prepare(p.parse_args().source)
