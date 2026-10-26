"""Repair atlas bounds, rigid attachment fits and front/rear accessory layers.

Existing character and accessory PNGs remain unchanged. Six new sprites are
imported losslessly; native meshes split collars around the original body.
"""
import argparse
import copy
import hashlib
import io
import json
import struct
import zstandard
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from shapely.geometry import Polygon
from prepare_v113_cosmetics import mesh

CELLS = {
    'z_scientist': ('zombie_style.png', [0,430,454,865]),
    'z_vampire': ('zombie_style.png', [454,430,930,865]),
    'z_scarf': ('zombie_style.png', [930,430,1430,865]),
    'z_chain': ('zombie_style.png', [1430,430,1784,865]),
    's_chaos': ('skeleton_head.png', [0,0,454,430]),
    's_north': ('skeleton_head.png', [454,0,904,430]),
    's_wizard': ('skeleton_head.png', [904,0,1380,430]),
    's_striped': ('skeleton_head.png', [1380,0,1784,430]),
    's_ice': ('skeleton_head.png', [0,430,454,865]),
}
NEW_HATS = {
    's_chaos': [[480,965],[1110,875]],
    's_north': [[430,925],[1210,905]],
    's_wizard': [[530,840],[1220,756]],
    's_striped': [[360,1040],[1110,1010]],
    's_ice': [[380,860],[1270,800]],
}


def generated(root, name):
    path=root/'assets/art/cosmetics_v126'/(name+'.png')
    image=Image.open(path).convert('RGBA');pixels=np.asarray(image)
    w,h=image.size;relative='.godot/imported/'+name+'-v126-lossless.ctex'
    target=root/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    payload=target.read_bytes()[56:] if target.exists() else b''
    if not payload or not np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')),pixels):
        stream=io.BytesIO();image.save(stream,format='WEBP',lossless=True,quality=100,method=6,exact=True)
        payload=stream.getvalue()
    assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')),pixels)
    (root/relative).write_bytes(struct.pack('<4s8I',b'GST2',1,w,h,0,0xffffffff,0,0,0)+struct.pack('<IHHIII',2,w,h,0,5,len(payload))+payload)
    path.with_suffix('.png.import').write_text(f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://{relative}"
metadata={{"vram_texture": false}}

[deps]

source_file="res://assets/art/cosmetics_v126/{name}.png"
dest_files=["res://{relative}"]

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
''')
    yy,xx=np.where(pixels[:,:,3]>10)
    graphic={'file':'cosmetics_v126/'+name+'.png','rect':[0,0,w,h],
             'bounds':[int(xx.min()),int(yy.min()),int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1)],
             'mesh':mesh(pixels[:,:,3]>0)}
    return graphic,{'item':name,'size':[w,h],'png_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'rgba_sha256':hashlib.sha256(pixels.tobytes()).hexdigest(),'lossless':True}


def local(graphic, point):
    return [point[0]-graphic['rect'][0],point[1]-graphic['rect'][1]]


def foreground_layers(root):
    folder=root/'assets/art/cosmetics_v113'
    packed=(folder/'fitting.bin').read_bytes()
    frames=json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]))
    layers={};sources={}
    for key,frame in frames.items():
        if frame['kind']!=0:continue
        file=frame['file']
        if file not in sources:sources[file]=np.asarray(Image.open(root/'assets/art'/file).convert('RGBA'))
        x,y,w,h=map(int,frame['rect']);r,g,b,a=sources[file][y:y+h,x:x+w].astype(float).transpose(2,0,1)
        yy,xx=np.mgrid[:h,:w];width=float(frame['head_width'])
        skin=(g>r*1.02)&(g>b*1.2)&(a>10)
        labels,count=ndi.label(skin)
        l,t,rr,bb=map(int,frame['box'])
        frequencies=np.bincount(labels[max(0,t):min(h,bb+1),max(0,l):min(w,rr+1)].ravel(),minlength=count+1)
        frequencies[0]=0;head_label=int(frequencies.argmax())
        head=labels==head_label
        limbs=skin & ~head
        head=ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(head,iterations=1)),iterations=2)
        limbs=ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(limbs,iterations=1)),iterations=2)
        chin=frame['landmarks']['chin']
        foreground=limbs | (head & (yy<chin[1]+.02*width))
        foreground &= yy>frame['landmarks']['near'][1]-.08*width
        chin=frame['landmarks']['chin'];near=frame['landmarks']['near']
        foreground |= (yy>chin[1]-.23*width)&(yy<chin[1]+.06*width)&(xx>near[0]-.20*width)&(xx<frame['box'][2]+.08*width)
        foreground &= ndi.binary_dilation(a>0,iterations=2)
        layers[key]={'body_foreground':mesh(foreground)}
    payload=json.dumps(layers,separators=(',',':')).encode()
    (root/'assets/art/cosmetics_v126/layers.bin').write_bytes(struct.pack('<I',len(payload))+zstandard.ZstdCompressor(level=19).compress(payload))


def prepare(root):
    folder=root/'assets/art/cosmetics_v113'
    before=json.loads((root/'tests/v126_before_graphics.json').read_text())
    graphics=copy.deepcopy(before)
    textures={}
    reports=[]
    for key,(file,cell) in CELLS.items():
        if key in NEW_HATS or key=='z_scientist':
            graphic,report=generated(root,'scientist' if key=='z_scientist' else key)
            w,h=graphic['rect'][2:]
            if key=='z_scientist':
                graphic['contacts']=[[.30,.75],[.80,.65]]
                graphic['hair_fit']={'anchor':[1040,700],'scale':.00155,'offset':[.15,.05],'angle':-.06}
                graphic['source_mesh']='clown_clean_face';graphic['reveal_source']='clown_clean_face'
            else:
                graphic['contacts']=[[p[0]/w,p[1]/h] for p in NEW_HATS[key]]
                height=-.08 if key=='s_wizard' else -.04 if key=='s_striped' else .08
                graphic['skull_fit']=[[-.51,height],[.51,height]]
                graphic['preserve_source']=True
            graphics[key]=graphic;reports.append(report)
            continue
        if file not in textures:textures[file]=np.asarray(Image.open(folder/file).convert('RGBA'))
        sheet=textures[file];x0,y0,x1,y1=cell
        source=sheet[y0:y1,x0:x1]
        yy,xx=np.where(source[:,:,3]>20)
        # Include the complete accessory, rather than a hand-cut rectangle
        # that truncated the scarf's right collar and several hat tips.
        x=max(x0,x0+int(xx.min())-2);y=max(y0,y0+int(yy.min())-2)
        right=min(x1,x0+int(xx.max())+3);bottom=min(y1,y0+int(yy.max())+3)
        pixels=sheet[y:bottom,x:right];r,g,b,a=pixels.astype(float).transpose(2,0,1)
        h,w=a.shape;opaque=a>0
        graphic={'file':'cosmetics_v113/'+file,'rect':[x,y,w,h], 'bounds':[0,0,w,h]}
        contacts=[]
        old=before[key]
        for point in old['contacts']:
            absolute=[old['rect'][0]+point[0]*old['rect'][2],old['rect'][1]+point[1]*old['rect'][3]]
            p=local(graphic,absolute);contacts.append([p[0]/w,p[1]/h])
        graphic['contacts']=contacts
        graphic['mesh']=mesh(opaque)
        graphic['clothes_reveal']='body_foreground'
        if key=='z_vampire':
            graphic['body_rig']={'anchor':local(graphic,[878,529]),'scale':.0032,'offset':[.23,.015]}
            graphic['front_mesh']=mesh(opaque,Polygon([(790-x,465-y),(930-x,465-y),(930-x,573-y),(850-x,562-y),(790-x,527-y)]))
        elif key=='z_scarf':
            graphic['body_rig']={'anchor':local(graphic,[1301,600]),'scale':.0025,'offset':[.08,-.035]}
            # Rear loop and tails draw behind the body. Only the lower,
            # rounded front of the collar crosses the chest.
            graphic['front_mesh']=mesh(opaque,Polygon([(1195-x,610-y),(1240-x,595-y),(1405-x,600-y),(1405-x,735-y),(1208-x,735-y)]))
            graphic['layered_neck']=True
        elif key=='z_chain':
            graphic['neck_rig']={'rear':local(graphic,[1480,528]),'front':local(graphic,[1702,536]),'rear_offset':[.0,-.22],'front_offset':[.48,-.10]}
            graphic['front_mesh']=mesh(opaque,Polygon([(1570-x,590-y),(1780-x,560-y),(1780-x,830-y),(1515-x,830-y),(1515-x,660-y)]))
            graphic['layered_neck']=True
            graphic['behind_body']=True
        graphics[key]=graphic
    foreground_layers(root)
    assert {k:v for k,v in graphics.items() if k not in CELLS}=={k:v for k,v in before.items() if k not in CELLS}
    (folder/'graphics.json').write_text(json.dumps(graphics,separators=(',',':')))
    print(json.dumps({'changed_items':list(CELLS),'other_items_preserved':len(graphics)-len(CELLS),'existing_pngs_changed':0,'new_art':reports}),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True)
    prepare(parser.parse_args().source)
