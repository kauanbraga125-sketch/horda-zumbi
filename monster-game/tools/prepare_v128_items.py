"""Eight individual worn fits. Generated PNGs and character PNGs stay intact.

Only UV geometry selects the new accessories from the fitted source drawings.
The four existing hats retain their artwork and receive separate scalp contacts.
"""
from pathlib import Path
import argparse, copy, hashlib, io, json, math, struct
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from shapely.geometry import Polygon, Point, box
from shapely.affinity import scale, rotate
from prepare_v127_items import geometry, mesh
import zstandard

ITEMS = ['s_ice','s_north','s_wizard','s_striped','s_ghostpirate','s_space','s_crown','s_plague']

def eye_samples(f):
    points=[]
    for eye,radius in [('near',.15),('far',.085)]:
        center=np.array(f['landmarks'][eye]);points.append(center)
        for ring in [.5,1.0]:
            for angle in np.linspace(0,2*math.pi,16,endpoint=False):
                points.append(center+np.array([math.cos(angle),math.sin(angle)])*f['head_width']*radius*ring)
    return np.array(points)

def hat_transform(graphic,f,depth):
    right=np.array(f['right']);down=np.array(f['down']);w=f['head_width'];size=np.array(graphic['rect'][2:])
    a=np.array(graphic['contacts'][0])*size;b=np.array(graphic['contacts'][1])*size
    back=np.array(f['landmarks']['scalp'])+(right*graphic['skull_fit'][0][0]+down*depth)*w
    front=np.array(f['landmarks']['scalp'])+(right*graphic['skull_fit'][1][0]+down*depth)*w
    v=b-a;to=front-back;angle=np.arctan2(to[1],to[0])-np.arctan2(v[1],v[0]);s=np.linalg.norm(to)/np.linalg.norm(v)
    basis=np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])*s
    return basis,back-basis@a

def protects_eyes(graphic,f,depth,alpha):
    basis,origin=hat_transform(graphic,f,depth)
    coords=np.floor((eye_samples(f)-origin)@np.linalg.inv(basis).T).astype(int)
    for x,y in coords:
        if 0<=x<alpha.shape[1]-1 and 0<=y<alpha.shape[0]-1 and alpha[y:y+2,x:x+2].max()>8:return False
    return True

def prepare_depths(root,graphics,ids):
    data=(root/'assets/art/cosmetics_v113/fitting.bin').read_bytes()
    frames=json.loads(zstandard.ZstdDecompressor().decompress(data[4:]));frames={k:v for k,v in frames.items() if v['kind']==1}
    for id in ids:
        graphic=graphics[id];alpha=np.asarray(Image.open(root/'assets/art'/graphic['file']).convert('RGBA'))[:,:,3]
        desired=graphic['skull_fit'][0][1];depths={}
        for key,f in frames.items():
            depth=desired
            while not protects_eyes(graphic,f,depth,alpha):
                depth=round(depth-.005,5)
                assert depth>-.40,(id,key)
            depths[key]=depth
        # A conservative neighbouring envelope keeps the band steady through
        # adjacent drawings, while every frame remains within its eye margin.
        clips={k.rsplit('_',1)[0] for k in depths}
        for clip in clips:
            keys=sorted([k for k in depths if k.rsplit('_',1)[0]==clip],key=lambda k:int(k.rsplit('_',1)[1]))
            values=np.array([depths[k] for k in keys]);smooth=values.copy()
            for i in range(len(keys)):
                for j in range(len(keys)):
                    distance=abs(i-j)
                    if clip.endswith(('run','idle','push','capture','panic')):distance=min(distance,len(keys)-distance)
                    smooth[i]=min(smooth[i],values[j]+.018*distance)
            for k,d in zip(keys,smooth):depths[k]=round(float(d),5)
        assert all(protects_eyes(graphic,frames[k],d,alpha) for k,d in depths.items())
        graphic['scalp_depth']=depths
        print('DEPTHS',id,min(depths.values()),max(depths.values()),flush=True)

def prepare(root):
    art=root/'assets/art'; folder=art/'cosmetics_v128'
    graphics=json.loads((root/'tests/v128_before_graphics.json').read_text())
    before=copy.deepcopy(graphics); report=[]
    # Each band has its own width and depth. The contact band lies below the
    # round crown so the item wraps the head instead of sitting on its tip.
    fits={
      's_ice':[[-.50,.12],[.46,.12]],
      's_north':[[-.60,.19],[.52,.19]],
      's_wizard':[[-.60,.10],[.50,.10]],
      's_striped':[[-.57,.13],[.50,.13]],
    }
    for id,fit in fits.items():graphics[id]['skull_fit']=fit
    for id in ITEMS[4:]:
        path=folder/(id+'.png');im=Image.open(path).convert('RGBA')
        p=np.asarray(im).astype(float);r,g,b,a=p.transpose(2,0,1);h,w=a.shape;yy,xx=np.mgrid[:h,:w]
        opaque=geometry(a>0)
        cyan=(g>110)&(b>110)&(r<100)&(g>r*1.7)&(a>150)&(yy>480)&(yy<680)&(xx>560)
        labels,n=ndi.label(cyan);eyes=[]
        for k in range(1,n+1):
            ey,ex=np.where(labels==k)
            if len(ex)>100:eyes.append((len(ex),[float(ex.mean()),float(ey.mean())]))
        eyes=sorted(sorted(eyes,reverse=True)[:2],key=lambda v:v[1][0])
        assert len(eyes)==2,(id,eyes)
        if id=='s_ghostpirate':
            roi=(xx>365)&(xx<920)&(yy>260)&(yy<610)
            teal=(g>r*1.18)&(b>r*1.18)&(g>b*.70)&(a>5)&roi
            gold=(r>120)&(g>55)&(r>g*1.04)&(g>b*1.55)&(a>5)&roi&((yy<475)|(xx>822)|(xx<520))
            solid=ndi.binary_fill_holes(ndi.binary_closing(teal|gold,iterations=3))
            region=geometry(solid).buffer(4).intersection(opaque)
            # Everything below this seam is original animated skull/hood.
            seam=Polygon([(350,240),(940,240),(940,620),(825,600),(812,566),(795,546),(768,520),(723,491),(674,472),(631,469),(588,480),(549,503),(521,533),(506,557),(478,547),(350,580)])
            region=region.intersection(seam)
        elif id=='s_crown':
            sat=(np.maximum.reduce([r,g,b])-np.minimum.reduce([r,g,b]))/np.maximum(np.maximum.reduce([r,g,b]),1)
            roi=(xx>435)&(xx<865)&(yy>310)&(yy<560)
            color=(sat>.63)&(r>95)&(r>g*1.02)&(a>5)&roi
            solid=ndi.binary_fill_holes(ndi.binary_closing(color,iterations=2))
            region=geometry(solid).buffer(4).intersection(opaque)
            # Follow the actual underside of the front band. Warm shadows in
            # the reference skull are not gold and must not become geometry.
            seam=Polygon([(420,300),(870,300),(870,558),(812,547),(789,532),(747,510),(700,489),(654,475),(610,467),(570,469),(532,476),(490,489),(465,502),(420,520)])
            region=region.intersection(seam)
        elif id=='s_space':
            outer=Polygon([(420,310),(780,310),(855,415),(855,610),(790,699),(754,730),(713,744),(668,736),(627,717),(593,694),(566,667),(529,640),(490,618),(453,590),(425,535)])
            opening=Polygon([(620,496),(656,482),(698,486),(743,501),(781,521),(810,546),(817,581),(807,621),(786,661),(758,690),(716,714),(680,702),(644,677),(616,647),(596,613),(593,571),(600,531)])
            region=opaque.intersection(outer).difference(opening)
        else:
            outline=Polygon([(460,448),(515,480),(571,497),(612,473),(651,466),(699,475),(752,501),(794,516),(813,507),(827,545),(830,594),(820,623),(850,661),(874,719),(877,781),(859,804),(841,779),(786,730),(724,707),(672,712),(620,694),(579,654),(563,599),(535,570),(508,554),(464,524),(451,500)])
            near=rotate(scale(Point(675,565).buffer(1,resolution=64),50,57),-12)
            far=rotate(scale(Point(795,591).buffer(1,resolution=64),20,31),15)
            region=opaque.intersection(outline).difference(near.union(far))
        # Remove isolated antialias specks, while retaining genuine small gems.
        if region.geom_type=='MultiPolygon':
            from shapely.ops import unary_union
            region=unary_union([v for v in region.geoms if v.area>6])
        drawing=mesh(region)
        if id=='s_space':
            # The chin ring tucks up under the jaw. Keep its painted outline
            # through UVs while clearing the original animated shirt collar.
            drawing['uv_points']=copy.deepcopy(drawing['points'])
            drawing['points']=[list(v) for v in drawing['points']]
            for point in drawing['points']:
                t=float(np.clip((point[1]-650.0)/100.0,0,1))
                point[1]-=12.0*t*t*(3.0-2.0*t)
        coordinates=np.array(drawing['points']);lo=coordinates.min(axis=0);hi=coordinates.max(axis=0)
        bounds=[lo[0],lo[1],hi[0],hi[1]]
        graphic={
          'file':'cosmetics_v128/'+id+'.png','rect':[0,0,w,h],
          'contacts':[[.30,.75],[.80,.65]],
          'bounds':[bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]],
          'mesh':drawing,
          'registered_head':{'near':eyes[0][1],'far':eyes[1][1]},
        }
        if id!='s_plague':graphic.update(source_mesh='skull_base_v127',skull_underlay=True)
        else:graphic['expose_cranium']=True
        graphics[id]=graphic
        # The PNG is embedded untouched. Import as lossless WebP in a Godot
        # CompressedTexture2D container, matching the verified prior builder.
        rel='.godot/imported/'+id+'-v128-lossless.ctex'
        existing=root/rel;encoded=existing.read_bytes()[56:] if existing.exists() else b''
        if not encoded or not np.array_equal(np.asarray(Image.open(io.BytesIO(encoded)).convert('RGBA')),np.asarray(im)):
            payload=io.BytesIO();im.save(payload,format='WEBP',lossless=True,quality=100,method=3,exact=True);encoded=payload.getvalue()
        assert np.array_equal(np.asarray(Image.open(io.BytesIO(encoded)).convert('RGBA')),np.asarray(im))
        (root/rel).write_bytes(struct.pack('<4s8I',b'GST2',1,w,h,0,0xffffffff,0,0,0)+struct.pack('<IHHIII',2,w,h,0,5,len(encoded))+encoded)
        path.with_suffix('.png.import').write_text(f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\npath="res://{rel}"\nmetadata={{"vram_texture":false}}\n\n[deps]\n\nsource_file="res://assets/art/cosmetics_v128/{id}.png"\ndest_files=["res://{rel}"]\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=true\n')
        report.append({'item':id,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'eyes':graphic['registered_head'],'bounds':graphic['bounds'],'vertices':len(graphic['mesh']['points']),'lossless':True})
        print('PREPARED',id,len(graphic['mesh']['points']),flush=True)
    prepare_depths(root,graphics,fits)
    assert all(graphics[k]==v for k,v in before.items() if k not in ITEMS)
    (art/'cosmetics_v113/graphics.json').write_text(json.dumps(graphics,separators=(',',':')))
    (root/'tools/art_sources/v128/preparation.json').write_text(json.dumps({'items':report,'existing_hat_fits':fits,'other_items_unchanged':27},indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);prepare(p.parse_args().source)
