"""Mechanical atlas packing and render-layer measurements; originals remain intact."""
from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np,json,io,os
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tools/art_sources/v139';OUT=ROOT/'assets/art/v139'

def fullwrite(path,data):
    with path.open('wb',buffering=0) as out:
        rest=memoryview(data)
        while rest:
            n=out.write(rest);assert n and n>0;rest=rest[n:]
        os.fsync(out.fileno())
    assert path.read_bytes()==data

def save(im,path):
    stream=io.BytesIO();im.save(stream,'WEBP',lossless=True,method=6)
    fullwrite(path,stream.getvalue());Image.open(path).load()

def split(name,cols,rows,cell):
    im=Image.open(SOURCE/(name+'.png'));im.load();im=im.convert('RGBA')
    assert im.getchannel('A').getextrema()[0]==0,name
    return [im.crop((round(x*im.width/cols),round(y*im.height/rows),round((x+1)*im.width/cols),round((y+1)*im.height/rows))).resize(cell,Image.Resampling.LANCZOS) for y in range(rows) for x in range(cols)]

def atlas(name,frames,cols):
    cell=frames[0].size;rows=(len(frames)+cols-1)//cols
    im=Image.new('RGBA',(cols*cell[0],rows*cell[1]))
    for i,f in enumerate(frames):im.paste(f,((i%cols)*cell[0],(i//cols)*cell[1]))
    save(im,OUT/(name+'.webp'));return {'cell':list(cell),'columns':cols,'rows':rows,'frames':len(frames)}

def eyes(frame,kind):
    a=np.asarray(frame);r,g,b,alpha=[a[:,:,i].astype(float) for i in range(4)]
    mask=((r>205)&(g>65)&(g<r*.84)&(b<105)) if kind==0 else ((r<100)&(g>140)&(b>140))
    mask&=(alpha>150)&(np.indices(mask.shape)[0]<frame.height*.80)
    labels,n=ndimage.label(ndimage.binary_dilation(mask,iterations=3));parts=[]
    for i in range(1,n+1):
        yy,xx=np.where((labels==i)&mask)
        if len(xx)>=3:parts.append((len(xx),float(xx.mean()),float(yy.mean())))
    parts.sort(reverse=True);assert parts,kind;near=parts[0]
    others=[c for c in parts[1:] if c[1]>near[1]+10 and abs(c[2]-near[2])<40]
    far=max(others) if others else (0,near[1]+30,near[2]+6)
    return [[round(x,3),round(y,3)] for _,x,y in [near,far]]

def body_mesh(near,far,neck,kind):
    # Geometry separates the body from the head; it never removes facial pixels.
    width=np.linalg.norm(np.array(far)-near)/(.38 if kind==0 else .37)
    cutoff=neck[1]+width*.04;left=near[0]-width*.96
    step=6;nx=384//step+1;points=[[x,y] for y in range(0,385,step) for x in range(0,385,step)];indices=[]
    for y in range(384//step):
        for x in range(384//step):
            first=y*nx+x
            for tri in [(first,first+1,first+nx),(first+1,first+nx+1,first+nx)]:
                cx,cy=np.mean([points[i] for i in tri],axis=0)
                if cy<cutoff and (kind==0 or cx>left):continue
                indices.extend(tri)
    return {'points':points,'indices':indices}

def main():
    OUT.mkdir(parents=True,exist_ok=True);layout={}
    for kind,name in enumerate(['zombie_riders','skeleton_riders']):
        if not (SOURCE/(name+'.png')).exists():continue
        frames=split(name,4,3,(384,384));entry=atlas(name,frames,4);entry['poses']=[]
        source_near=np.array([259.908,136.333] if kind==0 else [243.391,119.507]);source_far=np.array([317.07,142.419] if kind==0 else [265.133,124.933]);source_neck=np.array([211.77,198.44] if kind==0 else [225.76,149.76])
        for index,frame in enumerate(frames):
            near,far=eyes(frame,kind);a=source_far-source_near;b=np.array(far)-near
            angle=np.arctan2(b[1],b[0])-np.arctan2(a[1],a[0]);scale=np.linalg.norm(b)/np.linalg.norm(a)
            rotation=np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])*scale
            neck=np.array(near)+rotation@(source_neck-source_near)
            hip=[174,280] if kind==0 else [215,280]
            entry['poses'].append({'near':near,'far':far,'hip':hip,'neck':neck.round(3).tolist(),'height':360,'body_mesh':body_mesh(near,far,neck,kind)})
        layout[name]=entry
    for name,cols,rows,cell in [('flood',4,4,(320,448)),('fugitives',4,3,(512,384))]:
        if not (SOURCE/(name+'.png')).exists():continue
        frames=split(name,cols,rows,cell);entry=atlas(name,frames,cols)
        entry['bounds']=[list(f.getchannel('A').point(lambda x:255 if x>60 else 0).getbbox()) for f in frames]
        layout[name]=entry
    old=Image.open(ROOT/'assets/art/v138/survivors.webp').convert('RGBA')
    anchors=[]
    for i in range(12):
        frame=old.crop(((i%4)*320,(i//4)*320,(i%4+1)*320,(i//4+1)*320))
        box=frame.getchannel('A').point(lambda v:255 if v>60 else 0).getbbox()
        anchors.append({'waterline':box[3]-10})
    layout['survivor_anchors']=anchors
    fullwrite(OUT/'layout.json' ,(json.dumps(layout,separators=(',',':'))+'\n').encode())
    print('V139_ART_OK',list(layout),sum(p.stat().st_size for p in OUT.iterdir()))
if __name__=='__main__':main()
