"""Register generated ships, extract their cockpit stencil and pack raw game art.

No previous character, cosmetic or background asset is modified.
The magenta in the source is an explicit mask authored by imagegen.
"""
from pathlib import Path
from PIL import Image
import hashlib, io, json, os
import numpy as np
from scipy.ndimage import label, binary_dilation

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'tools/art_sources/v133'
OUT = ROOT / 'assets/art/space_v133'

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('wb') as f:
        for at in range(0, len(data), 262144):
            f.write(data[at:at+262144]); f.flush()
        os.fsync(f.fileno())
    assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(data).digest()

def png(path, image):
    b = io.BytesIO(); image.save(b, 'PNG', optimize=True); write(path,b.getvalue())
    with Image.open(path) as verify: verify.load(); assert verify.size == image.size

def main():
    source = Image.open(SRC/'pilots-generated.png').convert('RGBA')
    w,h = source.size
    specifications = {}
    for index,kind in enumerate(['tour_bus','fighter']):
        piece = source.crop((0,index*h//2,w,(index+1)*h//2))
        box = piece.getchannel('A').getbbox(); piece = piece.crop(box)
        # A common 640x400 frame keeps the full hull and exhaust together.
        scale = min(600/piece.width,360/piece.height)
        piece = piece.resize((round(piece.width*scale),round(piece.height*scale)),Image.Resampling.LANCZOS)
        atlas = Image.new('RGBA',(640,400)); atlas.alpha_composite(piece,((640-piece.width)//2,(400-piece.height)//2))
        a = np.array(atlas)
        mask = (a[:,:,0]>160)&(a[:,:,2]>150)&(a[:,:,1]<85)&(a[:,:,3]>40)
        labels,count = label(mask)
        sizes = np.bincount(labels.ravel()); sizes[0]=0
        ordered = np.argsort(sizes)[::-1]
        main = labels==ordered[0]
        mask = np.isin(labels,[i for i in ordered[:2] if sizes[i]>sizes[ordered[0]]*.08]) if kind=='tour_bus' else main
        assert mask.sum()>900, f'Cockpit stencil missing: {kind}'
        # Edge matting removes the deliberately solid chroma, including AA fringe.
        mask = binary_dilation(mask,iterations=1)
        a[mask,3]=0
        foreground = Image.fromarray(a)
        stencil = Image.fromarray((mask*255).astype('uint8'))
        yy,xx = np.where(main)
        rect = [int(xx.min()),int(yy.min()),int(xx.max()+1-xx.min()),int(yy.max()+1-yy.min())]
        # Actual alpha mask backs the cabin; no second painted set of passengers.
        interior = Image.new('RGBA',(640,400),(25,43,58,0)); interior.putalpha(stencil)
        png(OUT/(kind+'-front.png'),foreground); png(OUT/(kind+'-inside.png'),interior)
        specifications[kind]={'canvas':[640,400],'window':rect,'window_pixels':int(mask.sum()),'facing':'right'}
    vortex = Image.open(SRC/'vortex-generated.png').convert('RGBA')
    vortex.thumbnail((768,512),Image.Resampling.LANCZOS); png(OUT/'vortex.png',vortex)
    write(OUT/'layout.json',json.dumps({'version':'0.10.33','ships':specifications},indent=2).encode())
    print(json.dumps(specifications))

if __name__=='__main__': main()
