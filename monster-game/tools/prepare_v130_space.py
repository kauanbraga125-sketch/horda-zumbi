"""Pack the original generated art into registered, transparent game atlases.

No character artwork is repainted. Sources and crop registrations are retained.
"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tools/art_sources/v130'
OUT = ROOT / 'assets/art/space_v130'

def pack(name, size):
    image = Image.open(SOURCE / (name+'-generated.png')).convert('RGBA')
    alpha = np.asarray(image)[:,:,3]
    occupancy = (alpha>40).sum(axis=1)
    rows=[0]
    for i in range(1,4):
        ideal=round(image.height*i/4)
        candidates=range(ideal-32,ideal+33)
        rows.append(min(candidates,key=lambda v:(occupancy[v],abs(v-ideal))))
    rows.append(image.height)
    crops=[]; result=Image.new('RGBA',(size*4,size*4))
    for row in range(4):
        cells=[]
        for col in range(4):
            region=(round(image.width*col/4),rows[row],round(image.width*(col+1)/4),rows[row+1])
            part=image.crop(region)
            box=part.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
            assert box, (name,row,col)
            # Preserve soft outlines/glows inside each separated source cell.
            box=(max(0,box[0]-4),max(0,box[1]-4),min(part.width,box[2]+4),min(part.height,box[3]+4))
            part=part.crop(box)
            cells.append(part)
            crops.append({'row':row,'column':col,'region':region,'crop':box})
        # NPC clips share a single scale, so breathing does not resize the body.
        factor=min((size-28)/max(p.width for p in cells),(size-28)/max(p.height for p in cells)) if name=='npc' else None
        for col,part in enumerate(cells):
            scale=factor or min((size-24)/part.width,(size-24)/part.height)
            part=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.LANCZOS)
            at=(col*size+(size-part.width)//2,row*size+(size-part.height)//2)
            result.alpha_composite(part,at)
    path=OUT / ('npcs.png' if name=='npc' else 'props.png')
    result.save(path,optimize=True)
    return {'cell':size,'frames':16,'crops':crops,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    manifest={name:pack(name,256) for name in ['npc','props']}
    for name in ['orbit','nebula']:
        image=Image.open(SOURCE/(name+'-generated.png')).convert('RGB')
        image=image.resize((1600,900),Image.Resampling.LANCZOS)
        image.save(OUT/(name+'.webp'),quality=91,method=6)
    manifest['npc_clips']={'astronaut_float':[0,1,2,3],'astronaut_panic':[4,5,6,7],'parasite_float':[8,9,10,11],'parasite_attack':[12,13,14,15]}
    manifest['props']={'ufo':[0,1],'brain':[2,3],'meteors':[4,5,6],'coffin':7,'satellite':[8,9],'pod':[10,11],'ghost_ship':[12,13],'egg':[14,15]}
    manifest['style']='Original generated cartoon art; visual homages to space-horror films and games.'
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    (SOURCE/'registration.json').write_text(json.dumps(manifest,indent=2))
    print('SPACE_ART_READY',[(p.name,p.stat().st_size) for p in OUT.iterdir()])

if __name__=='__main__':main()
