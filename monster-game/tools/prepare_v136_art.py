"""Deterministically split/scale imagegen originals; no repainting of characters."""
import argparse, json, shutil, hashlib, io, os
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
ORIGINAL=ROOT/'tools/art_sources/v136'
OUT=ROOT/'assets/art/v136'
BIRDS=['pipoco','fiapo','ferrugem','agourinho','barao']

def write_image(im,path,**options):
    buf=io.BytesIO();im.save(buf,format='WEBP',**options);data=buf.getvalue()
    assert len(data)>100
    tmp=path.with_suffix('.writing')
    with tmp.open('wb') as f:
        for offset in range(0,len(data),65536):
            f.write(data[offset:offset+65536]);f.flush();os.fsync(f.fileno())
    assert tmp.read_bytes()==data
    tmp.replace(path)
    assert path.read_bytes()==data
    Image.open(path).verify()

def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    entries={}
    for name in BIRDS:
        im=Image.open(ORIGINAL/(name+'.png')).convert('RGBA')
        assert im.size==(1536,1024) and im.getchannel('A').getextrema()[0]==0
        # Remove disconnected fragments crossing a neighbouring cell boundary.
        clean=Image.new('RGBA',im.size)
        for i in range(6):
            x=(i%3)*512;y=(i//3)*512
            cell=np.array(im.crop((x,y,x+512,y+512)))
            labels,count=ndimage.label(cell[:,:,3]>12)
            sizes=np.bincount(labels.ravel());sizes[0]=0
            mask=ndimage.binary_dilation(labels==int(sizes.argmax()),iterations=2)
            cell[:,:,3]=np.where(mask,cell[:,:,3],0)
            clean.paste(Image.fromarray(cell),(x,y))
        im=clean
        write_image(im.resize((1152,768),Image.Resampling.LANCZOS),OUT/(name+'.webp'),lossless=True,method=6)
        entries[name]={'file':name+'.webp','columns':3,'rows':2,'cell':384,'frames':6}
    im=Image.open(ORIGINAL/'sewer_background.png').convert('RGB')
    im.thumbnail((1792,1024),Image.Resampling.LANCZOS)
    write_image(im,OUT/'sewer.webp',quality=94,method=6)
    im=Image.open(ORIGINAL/'sewer_exit.png').convert('RGB');im.thumbnail((1792,1024),Image.Resampling.LANCZOS)
    write_image(im,OUT/'sewer_exit.webp',quality=94,method=6)
    boxes={
      'sewer_props':{'jetski':[8,108,558,420],'ramp':[559,100,1098,440],'rubble':[1101,200,1536,455],
         'pipe':[8,518,655,957],'barrel':[674,501,1010,977],'buoy':[1074,591,1535,952]},
      'hatch_props':{'egg':[45,0,508,524],'egg_crack':[552,0,1018,525],'egg_open':[1052,0,1536,530],
         'nest':[0,535,590,1019],'feather':[591,525,1018,1018],'fusion':[1020,540,1536,1024]}}
    for sheet,parts in boxes.items():
        im=Image.open(ORIGINAL/(sheet+'.png')).convert('RGBA')
        for name,box in parts.items():
            crop=im.crop(box)
            region=crop.getchannel('A').point(lambda a:255 if a>10 else 0).getbbox()
            assert region,name
            crop=crop.crop(region);crop.thumbnail((600,512),Image.Resampling.LANCZOS)
            write_image(crop,OUT/(name+'.webp'),lossless=True,method=6)
            entries[name]={'file':name+'.webp','source':sheet+'.png','box':box,'trim':region,'size':list(crop.size)}
    (OUT/'layout.json').write_text(json.dumps(entries,indent=2)+'\n')
    print(json.dumps({'assets':len(entries)+1,'bytes':sum(p.stat().st_size for p in OUT.iterdir())}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--inputs',type=Path);a=p.parse_args()
    if a.inputs:
        ORIGINAL.mkdir(parents=True,exist_ok=True)
        data=json.loads(a.inputs.read_text())
        for name,record in data.items():
            shutil.copyfile(record['file'],ORIGINAL/(name+'.png'))
        (ORIGINAL/'PROMPTS.json').write_text(json.dumps({k:v['prompt'] for k,v in data.items()},ensure_ascii=False,indent=2)+'\n')
    prepare()
