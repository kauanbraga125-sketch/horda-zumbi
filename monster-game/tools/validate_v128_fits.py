"""Independent texture-space eye clearance and measured-animation checks."""
from pathlib import Path
import argparse, json
import numpy as np
from PIL import Image
import zstandard
from prepare_v128_items import hat_transform, protects_eyes
from prepare_v127_items import mesh_geometry
from shapely.geometry import Point

def validate(root):
    art=root/'assets/art';graphics=json.loads((art/'cosmetics_v113/graphics.json').read_text())
    data=(art/'cosmetics_v113/fitting.bin').read_bytes();frames=json.loads(zstandard.ZstdDecompressor().decompress(data[4:]));frames={k:v for k,v in frames.items() if v['kind']==1};failures=[];checks=0
    for id in ['s_chaos','s_ice','s_north','s_wizard','s_striped']:
        graphic=graphics[id];alpha=np.asarray(Image.open(art/graphic['file']).convert('RGBA'))[:,:,3]
        for key,f in frames.items():
            depth=graphic.get('scalp_depth',{}).get(key,graphic['skull_fit'][0][1]);checks+=1
            if not protects_eyes(graphic,f,depth,alpha):failures.append({'item':id,'frame':key,'error':'eye clearance'})
    for id in ['s_ghostpirate','s_space','s_crown','s_plague']:
        graphic=graphics[id];shape=mesh_geometry(graphic['mesh'])
        for eye in ['near','far']:
            p=graphic['registered_head'][eye];checks+=1
            if shape.distance(Point(p))<4:failures.append({'item':id,'eye':eye,'error':'iris aperture'})
    report={'skeleton_frames':len(frames),'eye_clearance_checks':checks,'failures':failures}
    print(json.dumps(report))
    if failures:raise SystemExit(1)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);validate(p.parse_args().source)
