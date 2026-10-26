"""Register transparent source cells and pack them without repainting characters."""
from pathlib import Path
import hashlib,json,io,os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'tools/art_sources/v132'
OUT=ROOT/'assets/art/adventure_v132'

def png(file, im):
    b=io.BytesIO();im.save(b,format='PNG',optimize=True);data=b.getvalue()
    with file.open('wb',buffering=0) as f:
        for start in range(0,len(data),262144):
            block=data[start:start+262144];assert f.write(block)==len(block)
        os.fsync(f.fileno())
    assert file.read_bytes()==data
    check=Image.open(file);check.load()

def pack_subjects(name):
    im=Image.open(SRC/(name+'-generated.png')).convert('RGBA')
    a=np.asarray(im);labels,n=ndimage.label(a[:,:,3]>48);counts=np.bincount(labels.ravel())
    ids=[int(i) for i in np.flatnonzero(counts>15000) if i]
    assert len(ids)==16,(name,len(ids))
    items=[]
    for i in ids:
        yy,xx=np.nonzero(labels==i)
        box=(max(0,int(xx.min())-4),max(0,int(yy.min())-4),min(im.width,int(xx.max())+5),min(im.height,int(yy.max())+5))
        pixels=np.array(im.crop(box));mask=ndimage.binary_dilation(labels==i,iterations=4)[box[1]:box[3],box[0]:box[2]]
        pixels[:,:,3]=np.where(mask,pixels[:,:,3],0)
        items.append((box,Image.fromarray(pixels)))
    items.sort(key=lambda x:(round(((x[0][1]+x[0][3])/2)/(im.height/4)-.5),(x[0][0]+x[0][2])/2))
    out=Image.new('RGBA',(1024,1024));crops=[]
    anchors=[(270,187),(568,207),(880,166),(1198,184),(269,518),(568,518),(883,534),(1194,513)]
    for index,(box,part) in enumerate(items):
        row,col=divmod(index,4)
        group=items[row*4:row*4+4]
        factor=min(228/max(p.width for b,p in group),228/max(p.height for b,p in group))
        if name=='helpers' and index<8:
            factor=.60
            anchor=(anchors[index][0]-box[0],anchors[index][1]-box[1])
            paste=(col*256+round(174-anchor[0]*factor),row*256+round(128-anchor[1]*factor))
        else:
            paste=(col*256+(256-round(part.width*factor))//2,row*256+(256-round(part.height*factor))//2)
        part=part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.LANCZOS)
        assert paste[0]>=col*256 and paste[1]>=row*256 and paste[0]+part.width<=(col+1)*256 and paste[1]+part.height<=(row+1)*256,(name,index,paste,part.size)
        out.alpha_composite(part,paste);crops.append({'row':row,'col':col,'source_box':box,'factor':factor,'paste':paste,'size':part.size})
    file=OUT/(name+'.png');png(file,out)
    m=json.loads((OUT/'manifest.json').read_text());m[name]={'cell':256,'frames':16,'crops':crops,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
    (OUT/'manifest.json').write_text(json.dumps(m,indent=2));print('REGISTERED_ATLAS',name,file.stat().st_size)

def pack_civil():
    im=Image.open(SRC/'civil-generated.png').convert('RGBA')
    labels,n=ndimage.label(np.asarray(im)[:,:,3]>40)
    sizes=np.bincount(labels.ravel());ids=np.argsort(sizes[1:])[-16:]+1
    boxes=[]
    for i in ids:
        ys,xs=np.nonzero(labels==i)
        boxes.append((max(0,int(xs.min())-4),max(0,int(ys.min())-4),min(im.width,int(xs.max())+5),min(im.height,int(ys.max())+5)))
    boxes.sort(key=lambda b:(round(((b[1]+b[3])/2)/(im.height/4)-.5),(b[0]+b[2])/2))
    assert len(boxes)==16
    out=Image.new('RGBA',(1024,1024));crops=[]
    for row in range(4):
        parts=[im.crop(b) for b in boxes[row*4:row*4+4]]
        factor=min(228/max(p.width for p in parts),228/max(p.height for p in parts))
        for col,p in enumerate(parts):
            p=p.resize((round(p.width*factor),round(p.height*factor)),Image.Resampling.LANCZOS)
            # Fixed centre/baseline, one shared scale per animation clip.
            pos=(col*256+(256-p.width)//2,row*256+242-p.height)
            out.alpha_composite(p,pos);crops.append({'row':row,'col':col,'source_box':boxes[row*4+col],'factor':factor,'paste':pos,'size':p.size})
    file=OUT/'civil.png';buffer=io.BytesIO();out.save(buffer,format='PNG',optimize=True);data=buffer.getvalue()
    with file.open('wb',buffering=0) as f:
        for start in range(0,len(data),262144):
            block=data[start:start+262144];written=f.write(block);assert written==len(block)
        os.fsync(f.fileno())
    assert file.read_bytes()==data
    check=Image.open(file);check.load()
    m=json.loads((OUT/'manifest.json').read_text());m['civil']={'cell':256,'frames':16,'crops':crops,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
    (OUT/'manifest.json').write_text(json.dumps(m,indent=2))
    print('CIVIL_ATLAS_READY',file.stat().st_size)

if __name__=='__main__':
    pack_subjects('fleet');pack_subjects('helpers');pack_civil()
