"""Pack a closed pirate hat and fit the original eyewear with two rigid lenses.

The old character, fitting and eyewear PNGs remain unchanged. A small UV grid
lets the bridge and temples follow the head without skewing the lens regions.
"""
import argparse,hashlib,io,json,struct
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_v113_cosmetics import mesh

RIGS={
 'z_cyber':dict(near=[231,125],far=[374,73],scale=.00225,bridge=[323,345],temple=[20,103],temple_target=[-.43,.24]),
 'z_goggles':dict(near=[229,119],far=[353,72],scale=.00215,bridge=[306,316],temple=[20,130],temple_target=[-.41,.24]),
}

def grid(w,h,rig,front=False,cyber=False):
    xs=sorted(set([float(x) for x in range(0,w,8)]+[float(w),100.,*map(float,rig['bridge'])]))
    ys=[float(y) for y in range(0,h,8)]+[float(h)]
    points=[[x,y] for y in ys for x in xs];indices=[];stride=len(xs)
    for row in range(len(ys)-1):
        for col in range(len(xs)-1):
            a=row*stride+col;b=a+1;c=a+stride;d=c+1
            for triangle in [[a,b,c],[b,d,c]]:
                x=sum(points[i][0] for i in triangle)/3;y=sum(points[i][1] for i in triangle)/3
                if front and (x<100 or (cyber and 180<x<345 and y<54-.07*(x-180))):continue
                indices+=triangle
    return dict(points=points,indices=indices)

def pack_hat(source,runtime):
    master=Image.open(source/'tools/art_sources/v122/pirate-generated.png').convert('RGBA')
    yy,xx=np.where(np.asarray(master)[:,:,3]>8)
    box=(max(0,int(xx.min())-12),max(0,int(yy.min())-12),min(master.width,int(xx.max())+13),min(master.height,int(yy.max())+13))
    image=master.crop(box);image=image.resize((512,round(image.height*512/image.width)),Image.Resampling.LANCZOS)
    output=source/'assets/art/cosmetics_v122/pirate.png';output.parent.mkdir(exist_ok=True);image.save(output,optimize=True)
    alpha=np.asarray(image)[:,:,3];yy,xx=np.where(alpha>8)
    contacts=[[(x-box[0])/(box[2]-box[0]),(y-box[1])/(box[3]-box[1])] for x,y in [(390,903),(1360,747)]]
    graphic=dict(file='cosmetics_v122/pirate.png',rect=[0,0,*image.size],contacts=contacts,skull_fit=[[-.59,.03],[.53,-.13]],preserve_source=True,mesh=mesh(alpha>8),bounds=[int(xx.min()),int(yy.min()),int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1)])
    stream=io.BytesIO();image.save(stream,format='WEBP',lossless=True,quality=100,method=6,exact=True);payload=stream.getvalue()
    assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')),np.asarray(image))
    imported='.godot/imported/pirate-v122-lossless.ctex';target=runtime/imported;w,h=image.size
    target.write_bytes(struct.pack('<4s8I',b'GST2',1,w,h,0,0xffffffff,0,0,0)+struct.pack('<IHHIII',2,w,h,0,5,len(payload))+payload)
    output.with_suffix('.png.import').write_text(f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://{imported}"
metadata={{"vram_texture": false}}

[deps]

source_file="res://assets/art/cosmetics_v122/pirate.png"
dest_files=["res://{imported}"]

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
''')
    return graphic,dict(id='z_pirate',size=image.size,bytes=target.stat().st_size,rgba_sha256=hashlib.sha256(np.asarray(image).tobytes()).hexdigest(),lossless=True)

def main(a):
    path=a.source/'assets/art/cosmetics_v113/graphics.json';graphics=json.loads(path.read_text())
    protected={k:v for k,v in graphics.items() if k not in ['z_pirate',*RIGS]}
    graphics['z_pirate'],report=pack_hat(a.source,a.runtime)
    for id,rig in RIGS.items():
        g=graphics[id];w,h=g['rect'][2:];g['eye_rig']=rig;g['behind_body']=True;g['layered_eyes']=True
        g['contacts']=[[rig['near'][0]/w,rig['near'][1]/h],[rig['far'][0]/w,rig['far'][1]/h]]
        g['mesh']=grid(w,h,rig);g['front_mesh']=grid(w,h,rig,True,id=='z_cyber')
    path.write_text(json.dumps(graphics,separators=(',',':')))
    assert {k:v for k,v in graphics.items() if k not in ['z_pirate',*RIGS]}==protected
    print(json.dumps(dict(art=[report],original_eyewear_textures_unchanged=True,original_character_pngs_modified=0,existing_fitting_file_modified=False,other_graphics_unchanged=len(protected))))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--runtime',type=Path,required=True);main(p.parse_args())
