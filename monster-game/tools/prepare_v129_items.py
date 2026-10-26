"""Register seven cosmetics to all 167 original skeleton drawings.

Original PNGs stay intact. Native meshes retain cloth motion and occlusion;
rigid accessories follow the eye line without shear or spare far temples.
"""
from pathlib import Path
import argparse,copy,hashlib,io,json,struct
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
from shapely.geometry import Polygon
from prepare_v127_items import geometry,mesh,similarity,transformed
import zstandard

ITEMS=['s_goth','s_comic','s_silver','s_punk','s_vest','s_bat','s_hourglass']
def read_packed(p):
    b=p.read_bytes();return json.loads(zstandard.ZstdDecompressor().decompress(b[4:]))
def write_packed(p,value):
    b=json.dumps(value,separators=(',',':')).encode();p.write_bytes(struct.pack('<I',len(b))+zstandard.ZstdCompressor(level=19).compress(b))
def import_image(root,id):
    path=root/'assets/art/cosmetics_v129'/(id+'.png');im=Image.open(path).convert('RGBA');w,h=im.size
    rel='.godot/imported/'+id+'-v129-lossless.ctex';target=root/rel;payload=target.read_bytes()[56:] if target.exists() else b''
    if not payload:
        b=io.BytesIO();im.save(b,format='WEBP',lossless=True,quality=100,method=3,exact=True);payload=b.getvalue()
    assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')),np.asarray(im))
    target.write_bytes(struct.pack('<4s8I',b'GST2',1,w,h,0,0xffffffff,0,0,0)+struct.pack('<IHHIII',2,w,h,0,5,len(payload))+payload)
    path.with_suffix('.png.import').write_text(f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\npath="res://{rel}"\nmetadata={{"vram_texture":false}}\n\n[deps]\n\nsource_file="res://assets/art/cosmetics_v129/{id}.png"\ndest_files=["res://{rel}"]\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=true\n')
    return im
def eye_centres(im):
    r,g,b,a=np.asarray(im).astype(float).transpose(2,0,1);h,w=r.shape;yy,xx=np.mgrid[:h,:w]
    labels,n=ndi.label((g>75)&(b>75)&(g>r*1.4)&(b>r*1.4)&(a>150)&(xx>w*.48)&(yy<h*.53)&(yy>h*.2));parts=[]
    for k in range(1,n+1):
        y,x=np.where(labels==k)
        if len(x)>12:parts.append((len(x),[float(x.mean()),float(y.mean())]))
    v=sorted(sorted(parts,reverse=True)[:2],key=lambda v:v[1][0]);assert len(v)==2
    return {'near':v[0][1],'far':v[1][1]}
def graphic(im,id,region):
    data=mesh(region);lo=np.array(data['points']).min(axis=0);hi=np.array(data['points']).max(axis=0)
    return {'file':'cosmetics_v129/'+id+'.png','rect':[0,0,*im.size],'contacts':[[.3,.75],[.8,.65]],'bounds':[*lo,*(hi-lo)],'mesh':data}
def component_near(mask,point,radius):
    labels,n=ndi.label(mask);parts=[]
    for k in range(1,n+1):
        y,x=np.where(labels==k)
        if len(x)<3:continue
        centre=np.array([x.mean(),y.mean()]);d=np.linalg.norm(centre-point)
        if d<radius:parts.append((d-len(x)*.006,centre))
    return min(parts,key=lambda v:v[0])[1] if parts else np.array(point)
def mask_from_mesh(data,size):
    im=Image.new('1',size);d=ImageDraw.Draw(im);p=data['points'];ids=data['indices']
    for i in range(0,len(ids),3):d.polygon([tuple(p[j]) for j in ids[i:i+3]],fill=1)
    return np.asarray(im)
def native_frame(root,f,key,cache,wardrobe):
    if f['file'] not in cache:cache[f['file']]=Image.open(root/'assets/art'/f['file']).convert('RGBA')
    x,y,w,h=map(int,f['rect']);p=np.asarray(cache[f['file']].crop((x,y,x+w,y+h)));r,g,b,a=p.astype(float).transpose(2,0,1)
    yy,xx=np.mgrid[:h,:w];W=float(f['head_width']);l,t,rr,bb=f['box'];neck=np.array(f['landmarks']['neck']);hip=np.array(f['landmarks']['hip'])
    skin=(a>60)&(r>135)&(g>95)&(b<g*.94)&(r>g*1.01)
    bone=skin&(xx>l-.14*W)&(xx<rr+.14*W)&(yy>t-.1*W)&(yy<t+1.32*W)
    labels,n=ndi.label(bone)
    if n:
        sizes=np.bincount(labels.ravel());sizes[0]=0;bone=labels==int(sizes.argmax())
    face=ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(bone,iterations=2)),iterations=1)
    for name,radius in [('near',.21),('far',.16)]:
        ex,ey=f['landmarks'][name];face|=(xx-ex)**2+(yy-ey)**2<(radius*W)**2
    purple=(a>0)&(b>g*1.25)&(r>g*1.2)&(b>12)
    labels,n=ndi.label(purple,structure=np.ones((3,3)));bright=purple&(r>90)&(r>b*.72)&(yy<t+2.1*W)
    scores=np.bincount(labels[bright].ravel(),minlength=n+1);scores[0]=0;sizes=np.bincount(labels.ravel(),minlength=n+1)
    selected=scores>np.maximum(3,sizes*.02);selected[0]=False
    cape=selected[labels]&purple&~ndi.binary_dilation(skin,iterations=1)
    bare=mask_from_mesh(wardrobe[key]['meshes']['skull_base_v127'],(w,h))
    gold=(a>100)&(r>145)&(g>85)&(g<r*.9)&(b<g*.72)&(yy>t+.85*W)&(yy<t+2.5*W)&(xx>l-1.2*W)&(xx<l+.8*W)
    clasp=component_near(gold,neck+np.array(f['right'])*.06*W,.38*W)
    belt=component_near(gold,hip-np.array(f['down'])*.18*W,.47*W)
    if np.linalg.norm(belt-clasp)<.22*W:belt=hip
    down=(belt-clasp)/np.linalg.norm(belt-clasp);right=np.array([down[1],-down[0]])
    ly=(xx-clasp[0])*down[0]+(yy-clasp[1])*down[1];lx=(xx-clasp[0])*right[0]+(yy-clasp[1])*right[1]
    roi=(ly>-.13*W)&(ly<np.linalg.norm(belt-clasp)+.05*W)&(abs(lx)<.34*W)
    protected=ndi.binary_dilation(skin|((a>40)&(r>130)&(g>65)&(g<r*.92)&(b<g*.78)),iterations=1)
    torso=geometry(roi&(a>0)&~protected).buffer(.45).difference(geometry(protected))
    foreground=geometry(ndi.binary_dilation(skin,iterations=1)&(yy>t+.85*W)&(a>0))
    bones=geometry(ndi.binary_dilation(skin,iterations=1)&(yy>neck[1]+.18*W)&(a>0))
    iris=geometry(ndi.binary_dilation((a>60)&(g>75)&(b>70)&(r<g*.8)&(yy<t+1.5*W),iterations=2))
    return {'meshes':{'hair_face_v129':mesh(geometry(face&(a>0))),'bone_reveal_v129':mesh(bones),'bat_cape_v129':mesh(geometry(cape)),'bat_cape_v129_bare':mesh(geometry(cape&bare))},'clasp':clasp.tolist(),'belt':belt.tolist(),'torso':torso,'foreground':foreground,'iris':iris,'cape_pixels':int(cape.sum())}
def posed_mesh(region,basis,origin):
    value=mesh(region);inv=np.linalg.inv(basis);value['uv_points']=[list(inv@(np.array(p)-origin)) for p in value['points']];return value
def prepare(root):
    art=root/'assets/art';folder=art/'cosmetics_v129';folder.mkdir(exist_ok=True)
    before=json.loads((root/'tests/v129_before_graphics.json').read_text());graphics=copy.deepcopy(before);regions={};eyes={};report={'items':[]}
    for id in ['s_goth','s_comic','s_vest','s_hourglass']:
        im=import_image(root,id);eyes[id]=eye_centres(im)
        if id=='s_goth':
            region=Polygon([(817,364),(883,379),(912,364),(1051,421),(1065,434),(1135,417),(1135,449),(1110,490),(1079,497),(1058,485),(1053,449),(1036,446),(1003,475),(949,474),(916,461),(904,430),(875,420),(861,399),(817,381)])
        elif id=='s_comic':
            outer=Polygon([(793,418),(839,432),(847,388),(875,403),(894,405),(975,444),(992,454),(1020,445),(1045,430),(1044,460),(1027,479),(1018,504),(1003,513),(988,499),(982,477),(959,482),(920,498),(889,499),(865,491),(849,472),(839,452),(789,436)])
            near=Polygon([(871,422),(892,427),(922,444),(948,463),(953,469),(936,477),(918,481),(896,477),(881,467),(874,453)])
            far=Polygon([(994,477),(1007,470),(1026,461),(1024,482),(1012,497),(1006,500)])
            region=outer.difference(near.union(far))
            r,g,b,a=np.asarray(im).astype(float).transpose(2,0,1);yy,xx=np.mgrid[:im.height,:im.width]
            source_iris=geometry((g>75)&(b>75)&(g>r*1.4)&(b>r*1.4)&(a>100)&(xx>im.width*.48)&(yy<im.height*.53)).buffer(3)
            region=region.difference(source_iris)
        elif id=='s_vest':
            region=Polygon([(766,490),(790,495),(821,509),(848,523),(871,553),(879,576),(900,580),(927,578),(942,594),(941,627),(919,647),(904,659),(898,694),(889,713),(853,694),(825,682),(794,663),(754,643),(736,622),(741,595),(760,574),(774,552),(774,529)])
        else:
            region=Polygon([(839,606),(849,606),(857,613),(877,616),(885,624),(887,638),(878,659),(875,670),(884,687),(888,707),(879,721),(818,722),(811,713),(812,695),(822,675),(824,664),(814,647),(811,631),(817,620),(837,618)])
        regions[id]=region;graphics[id]=graphic(im,id,region)
        if id in ['s_goth','s_comic']:graphics[id]['registered_head']=eyes[id]
        else:graphics[id].update(frame_native=True,native_bounds=True,native_occlusion=True)
        report['items'].append({'id':id,'sha256':hashlib.sha256((folder/(id+'.png')).read_bytes()).hexdigest(),'eyes':eyes[id]})
    for id,rig in {'s_silver':{'anchor':[300,100],'scale':.00515,'offset':[.14,.035],'angle':-.07},'s_punk':{'anchor':[268,186],'scale':.00485,'offset':[.015,.025],'angle':-.13}}.items():
        graphics[id].update(hair_fit=rig,source_mesh='skull_base_v127',skull_underlay=True,reveal_source='hair_face_v129')
    graphics['s_bat'].update(native_cape=True,native_bounds=True,native_occlusion=True)
    graphics['s_comic'].update(frame_native=True,native_bounds=True)
    frames=read_packed(art/'cosmetics_v113/fitting.bin');wardrobe=read_packed(art/'cosmetics_v127/layers.bin');layers={};cache={};samples={}
    for key,f in frames.items():
        if f['kind']!=1:continue
        data=native_frame(root,f,key,cache,wardrobe);native={}
        for id in ['s_vest','s_hourglass','s_comic']:
            basis,origin=similarity([[930,551],[840,706]],[data['clasp'],data['belt']])
            if id=='s_comic':basis,origin=similarity([eyes[id]['near'],eyes[id]['far']],[f['landmarks']['near'],f['landmarks']['far']])
            if id=='s_hourglass':
                down=np.array(data['belt'])-data['clasp'];down/=np.linalg.norm(down);right=np.array([down[1],-down[0]])
                basis=np.column_stack([right,down])*(.0035*f['head_width']);centre=np.array(data['clasp'])+(down*.34+right*.02)*f['head_width'];origin=centre-basis@np.array([849,666])
            posed=transformed(regions[id],basis,origin)
            posed=posed.intersection(data['torso']) if id=='s_vest' else posed.difference(data['iris'] if id=='s_comic' else data['foreground'])
            native[id]=posed_mesh(posed,basis,origin);assert native[id]['points'],(key,id)
        layers[key]={'meshes':data['meshes'],'items':native,'body':{'clasp':data['clasp'],'belt':data['belt']}}
        samples[key]={'cape_pixels':data['cape_pixels'],'clasp':data['clasp'],'belt':data['belt']}
        if len(layers)%25==0:print('NATIVE_FRAMES',len(layers),flush=True)
    assert len(layers)==167
    assert all(graphics[k]==v for k,v in before.items() if k not in ITEMS)
    (art/'cosmetics_v113/graphics.json').write_text(json.dumps(graphics,separators=(',',':')));write_packed(folder/'layers.bin',layers)
    report.update(native_frames=167,original_character_pngs_changed=0,unchanged_other_items=28,measurements=samples)
    (root/'tools/art_sources/v129/preparation.json').write_text(json.dumps(report,indent=2))
    from prepare_v129_details import finish
    finish(root)
    print('V129_PREPARATION_OK',flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);prepare(p.parse_args().source.resolve())
