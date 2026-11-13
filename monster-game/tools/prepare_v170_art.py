"""Technically pack the approved generated artwork as small raw WebP sprites.

No artwork is painted or generated here: only atlas extraction and encoding.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image


def prepare(root, source_map):
    sources = json.loads(source_map.read_text())
    out = root / 'assets/art/v170'
    out.mkdir(parents=True, exist_ok=True)
    records = []

    def encode(name, image, key, maximum=720, crop=None):
        image = image.convert('RGBA')
        image.thumbnail((maximum, maximum), Image.Resampling.LANCZOS)
        path = out / (name+'.webp')
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path, 'WEBP', quality=88, method=6)
        source = sources[key]
        records.append({'file':name+'.webp','size':list(image.size),'bytes':path.stat().st_size,
                        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                        'source_library_id':source['library_file_id'],
                        'source_sha256':hashlib.sha256(Path(source['path']).read_bytes()).hexdigest(),
                        'source_crop':list(crop) if crop else None})

    def trim(image, padding=5):
        box = image.getchannel('A').point(lambda a: 255 if a>8 else 0).getbbox()
        assert box, 'Empty sprite'
        box = (max(0,box[0]-padding),max(0,box[1]-padding),min(image.width,box[2]+padding),min(image.height,box[3]+padding))
        return image.crop(box), box

    for key in ['background','nest','fusion','crate_sheet','eggs_sheet','frames_sheet']:
        image = Image.open(sources[key]['path']).convert('RGBA')
        if key=='background':encode(key,image,key,1600)
        elif key in ['nest','fusion']:
            sprite,box=trim(image);encode(key,sprite,key,720 if key=='nest' else 1000,box)
        elif key=='crate_sheet':
            w,h=image.width//2,image.height//2
            cells=[image.crop((i%2*w,i//2*h,(i%2+1)*w,(i//2+1)*h)) for i in range(4)]
            boxes=[trim(cell)[1] for cell in cells]
            box=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
            for i,cell in enumerate(cells):encode('crate_'+str(i),cell.crop(box),key,600,box)
        elif key=='eggs_sheet':
            w,h=image.width//3,image.height//2
            for i in range(6):
                sprite,box=trim(image.crop((i%3*w,i//3*h,(i%3+1)*w,(i//3+1)*h)),9)
                encode('egg_'+str(i) if i<5 else 'gear',sprite,key,400 if i<5 else 220,box)
        else:
            columns=[0,image.width//2,image.width];rows=[0,round(image.height*.40),round(image.height*.68),image.height]
            for i,name in enumerate(['panel','selected','row','header','button','badge']):
                sprite,box=trim(image.crop((columns[i%2],rows[i//2],columns[i%2+1],rows[i//2+1])))
                encode(name,sprite,key,720,box)
    avatars={'pipoco':(210,120,1110,1050),'fiapo':(400,110,1070,790),'ferrugem':(360,240,1110,970),
             'agourinho':(350,300,1080,1040),'barao':(350,70,1080,810)}
    for key in ['harvester','spectral','symbiote','orbital','pipoco','fiapo','ferrugem','agourinho','barao']:
        image=Image.open(sources[key]['path']).convert('RGBA');encode('book/'+key,image,key,900)
        if key in avatars:encode('portrait/'+key,image.crop(avatars[key]),key,300,avatars[key])
    manifest={'version':'0.10.70','generation_mode':'builtin imagegen','reference_library_id':sources['concept']['library_file_id'],
              'direction':'Approved purple/gold/cyan laboratory; separate empty machines, four crate frames, five rarity eggs, nine book illustrations.',
              'runtime_format':'WebP with alpha; lazy portraits and bounded one-sprite-per-frame prewarm','assets':records}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'sprites':len(records),'encoded_bytes':sum(r['bytes'] for r in records)}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--sources',type=Path,required=True)
    p.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    a=p.parse_args();prepare(a.project,a.sources)
