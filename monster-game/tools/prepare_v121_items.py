"""Pack closed beanie/wizard art and fit all three pieces around intact heads.

The electric hood keeps its original atlas pixels. Its foreground UV mesh
excludes the dark lining; the original character is never cut for these items.
"""
import argparse, hashlib, io, json, struct
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from prepare_v113_cosmetics import mesh

SPECS = {
    'z_beanie': ('beanie', [(300, 910), (1270, 650)], [[-.54, .05], [.50, -.17]]),
    'z_sorcerer': ('sorcerer', [(380, 944), (1280, 838)], [[-.76, -.12], [.65, -.22]]),
}

def pack(source, runtime, item_id, spec):
    name, contact_points, targets = spec
    original = Image.open(source/'tools/art_sources/v121'/(name+'-generated.png')).convert('RGBA')
    yy,xx=np.where(np.asarray(original)[:,:,3]>8)
    box=(max(0,int(xx.min())-12),max(0,int(yy.min())-12),min(original.width,int(xx.max())+13),min(original.height,int(yy.max())+13))
    image=original.crop(box); image=image.resize((512,round(image.height*512/image.width)),Image.Resampling.LANCZOS)
    output=source/'assets/art/cosmetics_v121'/(name+'.png'); output.parent.mkdir(exist_ok=True)
    image.save(output,optimize=True)
    alpha=np.asarray(image)[:,:,3];yy,xx=np.where(alpha>8)
    contacts=[[(x-box[0])/(box[2]-box[0]),(y-box[1])/(box[3]-box[1])] for x,y in contact_points]
    graphic=dict(file='cosmetics_v121/'+name+'.png',rect=[0,0,*image.size],contacts=contacts,skull_fit=targets,preserve_source=True,mesh=mesh(alpha>8),bounds=[int(xx.min()),int(yy.min()),int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1)])
    stream=io.BytesIO();image.save(stream,format='WEBP',lossless=True,quality=100,method=6,exact=True);payload=stream.getvalue()
    assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')),np.asarray(image))
    imported='.godot/imported/'+name+'-v121-lossless.ctex';target=runtime/imported;target.parent.mkdir(parents=True,exist_ok=True)
    w,h=image.size
    target.write_bytes(struct.pack('<4s8I',b'GST2',1,w,h,0,0xffffffff,0,0,0)+struct.pack('<IHHIII',2,w,h,0,5,len(payload))+payload)
    output.with_suffix('.png.import').write_text(f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://{imported}"
metadata={{"vram_texture": false}}

[deps]

source_file="res://assets/art/cosmetics_v121/{name}.png"
dest_files=["res://{imported}"]

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
''')
    return graphic,dict(id=item_id,size=image.size,bytes=target.stat().st_size,rgba_sha256=hashlib.sha256(np.asarray(image).tobytes()).hexdigest(),lossless=True)

def main(a):
    source=a.source.resolve();path=source/'assets/art/cosmetics_v113/graphics.json';graphics=json.loads(path.read_text());protected={k:v for k,v in graphics.items() if k not in [*SPECS,'z_electric']}
    reports=[]
    for item_id,spec in SPECS.items():
        graphics[item_id],report=pack(source,a.runtime,item_id,spec);reports.append(report)
    hood=graphics['z_electric']
    hood.pop('source_mesh',None)
    hood['preserve_source']=True
    hood['contacts']=[[260/388,117/339],[285/388,317/339]]
    hood['skull_fit']=[[.18,-.28],[.08,.64]]
    hood['behind_body']=True
    x,y,w,h=hood['rect'];pixels=np.asarray(Image.open(source/'assets/art'/hood['file']).convert('RGBA'))[y:y+h,x:x+w]
    r,g,b,a=pixels.astype(float).transpose(2,0,1);yy,xx=np.mgrid[:h,:w]
    # The opaque lining is behind the uncut character. The yellow cloth,
    # complete black outline and tips cover the hair as a single foreground.
    lining=(r<180)&(g<135)&(b<85)&(yy>108)&(xx>155)
    labels,count=ndi.label(lining)
    opening=labels==labels[225,275]
    assert labels[225,275]>0
    cloth=(a>8)&~ndi.binary_erosion(opening,iterations=1)
    crown=mesh(cloth&(yy>=88)&(yy<=178)&(xx>=90)&(xx<=330)&((xx<275)|(yy<235-.37*xx)))
    crown['uv_points']=[list(p) for p in crown['points']]
    crown['points']=[[px,178-(178-py)*1.7] for px,py in crown['points']]
    # Keep the ear silhouettes and the rear hanging cloth in their original
    # proportions. Only the existing crown cloth expands over the skull.
    ears=((xx<180)&(yy<145)&(yy<-.45*xx+190))|((xx>245)&(yy<130)&(yy<.5*xx-35))
    rest=mesh(cloth&(ears|((xx<190)&(yy>178))))
    offset=len(crown['points'])
    crown['points']+=rest['points'];crown['uv_points']+=rest['points'];crown['indices']+=[i+offset for i in rest['indices']]
    hood['front_mesh']=crown
    hood.pop('skull_cover',None);hood.pop('cloth_uv',None)
    path.write_text(json.dumps(graphics,separators=(',',':')))
    assert {k:v for k,v in graphics.items() if k not in [*SPECS,'z_electric']}==protected
    print(json.dumps(dict(art=reports,hood_uses_original_texture=True,original_characters_uncut=True,existing_fitting_file_modified=False,other_graphics_unchanged=len(protected))))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--runtime',type=Path,required=True);main(p.parse_args())
