"""Check both eye margins against all five hat textures in all skeleton frames."""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
import zstandard


def validate(root):
    graphics=json.loads((root/'assets/art/cosmetics_v113/graphics.json').read_text())
    packed=(root/'assets/art/cosmetics_v113/fitting.bin').read_bytes()
    frames=json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]))
    results=[];failures=[]
    for name in ['s_chaos','s_north','s_wizard','s_striped','s_ice']:
        graphic=graphics[name]
        alpha=np.asarray(Image.open(root/'assets/art'/graphic['file']).convert('RGBA'))[:,:,3]
        tested=0
        for key,frame in frames.items():
            if frame['kind']!=1:continue
            tested+=1
            width=frame['head_width'];right=np.array(frame['right']);down=np.array(frame['down'])
            scalp=np.array(frame['landmarks']['scalp']);size=np.array(graphic['rect'][2:])
            a=np.array(graphic['contacts'][0])*size;b=np.array(graphic['contacts'][1])*size
            rear=np.array(graphic['skull_fit'][0]);front=np.array(graphic['skull_fit'][1])
            back=scalp+(right*rear[0]+down*rear[1])*width
            forward=scalp+(right*front[0]+down*front[1])*width
            source=b-a;target=forward-back
            angle=math.atan2(target[1],target[0])-math.atan2(source[1],source[0])
            scale=np.linalg.norm(target)/np.linalg.norm(source)
            basis=np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]])*scale
            origin=back-basis@a;inverse=np.linalg.inv(basis)
            largest=0
            for eye,radius in [('near',.15),('far',.085)]:
                center=np.array(frame['landmarks'][eye])
                points=[center]
                for ring in [.5,1.0]:
                    for angle in np.linspace(0,2*math.pi,16,endpoint=False):
                        points.append(center+np.array([math.cos(angle),math.sin(angle)])*width*radius*ring)
                for point in points:
                    x,y=np.floor(inverse@(point-origin)).astype(int)
                    if 0<=x<alpha.shape[1]-1 and 0<=y<alpha.shape[0]-1:
                        largest=max(largest,int(alpha[y:y+2,x:x+2].max()))
            if largest>8:failures.append({'item':name,'frame':key,'alpha':largest})
        results.append({'item':name,'frames':tested})
    report={'items':results,'frame_item_checks':sum(v['frames'] for v in results),'failures':failures}
    print(json.dumps(report),flush=True)
    if failures:raise SystemExit(1)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True)
    validate(parser.parse_args().source)
