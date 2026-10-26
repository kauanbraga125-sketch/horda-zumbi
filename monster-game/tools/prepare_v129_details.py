"""Finalize native expressions, limb occlusion and cloth-only palette weights."""
from pathlib import Path
import argparse,json,time
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.measure import find_contours
from skimage.morphology import convex_hull_image
from shapely import build_area
from shapely.geometry import MultiLineString,Polygon
from prepare_v127_items import mesh,mesh_geometry,similarity,transformed
from prepare_v129_items import read_packed,write_packed,mask_from_mesh,posed_mesh

def repair_head_poses(root,frames,cache):
    detected={}
    for key,f in frames.items():
        if f['kind']!=1:continue
        if f['file'] not in cache:cache[f['file']]=Image.open(root/'assets/art'/f['file']).convert('RGBA')
        x,y,w,h=map(int,f['rect']);r,g,b,a=np.asarray(cache[f['file']].crop((x,y,x+w,y+h))).astype(float).transpose(2,0,1)
        labels,n=ndi.label((g>65)&(b>65)&(r<g*.8)&(a>80));parts=[]
        for i in range(1,n+1):
            ys,xs=np.where(labels==i)
            if len(xs)>2 and ys.mean()<h*.65:parts.append((len(xs),[float(xs.mean()),float(ys.mean())]))
        detected[key]=[v[1] for v in sorted(sorted(parts,reverse=True)[:2],key=lambda v:v[1][0])]
    idle=[]
    for key,pts in detected.items():
        if key.startswith('s_idle_') and len(pts)==2:
            f=frames[key];l,t,_,_=f['box'];idle.append((np.array(pts)-[l,t])/f['head_width'])
    assert idle
    template=np.median(idle,axis=0);poses={}
    for key,pts in detected.items():
        f=frames[key];old=np.array([f['landmarks']['near'],f['landmarks']['far']]);reason=''
        if len(pts)==2:
            target=np.array(pts)
            if np.max(np.linalg.norm(target-old,axis=1))<=4:continue
            reason='Eye apertures outside the old colour-search window'
        elif key.startswith('s_idle_'):
            l,t,_,_=f['box'];target=template*f['head_width']+[l,t]
            if len(pts)==1:
                which=0 if pts[0][0]<target[:,0].mean() else 1;target[which]=pts[0]
            reason='Closed eyelids: retain the registered eye sockets, not jaw fallback points'
        else:continue
        delta=target[1]-target[0];right=delta/np.linalg.norm(delta);down=np.array([-right[1],right[0]])
        pose={'near':target[0].tolist(),'far':target[1].tolist(),'right':right.tolist(),'down':down.tolist(),'reason':reason}
        poses[key]=pose;f['landmarks']['near']=pose['near'];f['landmarks']['far']=pose['far'];f['right']=pose['right'];f['down']=pose['down']
    (root/'assets/art/cosmetics_v129/head_poses.json').write_text(json.dumps(poses,separators=(',',':')))
    print('HEAD_POSES_REPAIRED',len(poses),','.join(poses),flush=True)
    return poses

def geometry(mask):
    # Build all nested rings together; repeated pairwise XOR grew quadratically
    # on the antialiased cloth bands. GEOS retains the same native eye holes.
    rings=[]
    for contour in find_contours(np.pad(mask.astype('uint8'),1),.5):
        if len(contour)>3:rings.append((contour[:,::-1]-.5).tolist())
    if not rings:return Polygon()
    result=build_area(MultiLineString(rings))
    return result.simplify(.45,preserve_topology=True)

def weighted_cloth(mask,strength):
    inner=mask&(strength>.90);outer=mask&~inner
    solid=mesh(geometry(inner));band=mesh(geometry(outer))
    values=np.clip((strength-.01)/.89,0,1);h,w=mask.shape
    alpha=[]
    for x,y in band['points']:
        ix=int(np.clip(round(x),0,w-1));iy=int(np.clip(round(y),0,h-1));alpha.append(float(values[iy,ix]))
    return {'points':solid['points']+band['points'],'indices':solid['indices']+[i+len(solid['points']) for i in band['indices']],'alpha':[1.0]*len(solid['points'])+alpha}

def finish(root):
    art=root/'assets/art';folder=art/'cosmetics_v129';frames=read_packed(art/'cosmetics_v113/fitting.bin');layers=read_packed(folder/'layers.bin');wardrobe=read_packed(art/'cosmetics_v127/layers.bin');cache={};coverage={}
    poses=repair_head_poses(root,frames,cache)
    graphic=json.loads((art/'cosmetics_v113/graphics.json').read_text())['s_comic'];comic=mesh_geometry(graphic['mesh']);rig=graphic['registered_head']
    started=time.monotonic()
    for number,(key,layer) in enumerate(layers.items()):
        f=frames[key]
        if f['file'] not in cache:cache[f['file']]=Image.open(art/f['file']).convert('RGBA')
        x,y,w,h=map(int,f['rect']);p=np.asarray(cache[f['file']].crop((x,y,x+w,y+h))).astype(float);r,g,b,a=p.transpose(2,0,1);yy,xx=np.mgrid[:h,:w];W=f['head_width'];l,t,rr,bb=f['box'];neck=f['landmarks']['neck']
        # Include shaded grey bones too. The shipped texture can differ by a
        # few colour levels from its source PNG at antialiased outlines.
        skin=(a>25)&(r>110)&(g>85)&(b<g*1.03)&(r>g*.94)
        bone=ndi.binary_dilation(skin,iterations=3)&(yy>neck[1]+.14*W)&(a>0)
        layer['meshes']['bone_reveal_v129']=mesh(geometry(bone))
        iris=ndi.binary_dilation((a>25)&(g>65)&(b>65)&(r<g*.88)&(yy<t+1.6*W),iterations=3)&(a>0)
        face_skin=skin&(xx>l-.14*W)&(xx<rr+.14*W)&(yy>t-.10*W)&(yy<t+1.32*W)
        labels,n=ndi.label(face_skin)
        if n:
            sizes=np.bincount(labels.ravel());sizes[0]=0;face_skin=labels==int(sizes.argmax())
        original_face=convex_hull_image(face_skin)&(a>0)
        purple_lining=(r>g*1.4)&(b>g*1.3)&(b>r*.65)&(b>30)&(r>35)
        original_face&=~purple_lining
        layer['meshes']['hair_face_v129']=mesh(geometry(original_face|iris))
        basis,origin=similarity([rig['near'],rig['far']],[f['landmarks']['near'],f['landmarks']['far']])
        layer['items']['s_comic']=posed_mesh(transformed(comic,basis,origin).difference(geometry(iris)),basis,origin)
        # Hue/brightness weights affect the pink cloak and its matching hood;
        # the purple boots and gloves keep their original colours. Transition
        # bands interpolate vertex alpha instead of cutting across the cloth.
        hue=np.clip((r/np.maximum(b,1)-.80)/.28,0,1);hue=hue*hue*(3-2*hue)
        light=np.clip((r-45)/55,0,1);light=light*light*(3-2*light)
        strength=ndi.gaussian_filter(hue*light,.6)
        fabric=(a>0)&(b>g*1.25)&(r>g*1.2)&(b>18)&(strength>.01)&~ndi.binary_dilation(skin,iterations=1)
        bare=mask_from_mesh(wardrobe[key]['meshes']['skull_base_v127'],(w,h))
        layer['meshes']['bat_cape_v129']=weighted_cloth(fabric,strength)
        layer['meshes']['bat_cape_v129_bare']=weighted_cloth(fabric&bare,strength)
        coverage[key]=int(fabric.sum())
        if number%10==0:print('DETAIL_FRAME',number,key,round(time.monotonic()-started,1),flush=True)
    write_packed(folder/'layers.bin',layers)
    (root/'tools/art_sources/v129/detail-validation.json').write_text(json.dumps({'frames':len(layers),'repaired_head_poses':list(poses),'native_eye_apertures':True,'shaded_bones_preserved':True,'cloth_hue_palette':True,'cloth_pixels':coverage},indent=2))
    print('V129_DETAILS_OK',len(layers),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);finish(p.parse_args().source.resolve())
