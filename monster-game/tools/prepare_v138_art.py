"""Prepare drawn seated poses and registered transparent animation atlases."""
from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np
import json,io,os
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tools/art_sources/v138';OUT=ROOT/'assets/art/v138'
def save(im,path):
    stream=io.BytesIO();im.save(stream,'WEBP',lossless=True,method=6);data=stream.getvalue()
    with path.open('wb') as f:
        for offset in range(0,len(data),65536):f.write(data[offset:offset+65536])
        f.flush();os.fsync(f.fileno())
    assert path.read_bytes()==data
def split(name,cols,rows,cell):
    source=Image.open(SOURCE/(name+'.png')).convert('RGBA');frames=[]
    assert source.getchannel('A').getextrema()[0]==0
    for y in range(rows):
        for x in range(cols):
            box=(round(x*source.width/cols),round(y*source.height/rows),round((x+1)*source.width/cols),round((y+1)*source.height/rows))
            frame=source.crop(box).resize(cell,Image.Resampling.LANCZOS)
            if name=='survivors':
                # Remove only tiny pieces of a neighbouring cell touching a
                # cell boundary; keep the character, buoy and interior spray.
                a=np.array(frame);labels,n=ndimage.label(a[:,:,3]>40);sizes=np.bincount(labels.ravel());largest=int(sizes[1:].argmax()+1)
                borders=set(labels[0,:])|set(labels[-1,:])|set(labels[:,0])|set(labels[:,-1])
                for label in borders:
                    if label and label!=largest and sizes[label]<sizes[largest]*.04:a[labels==label,3]=0
                frame=Image.fromarray(a)
            frames.append(frame)
    return frames
def atlas(name,frames,cols):
    cell=frames[0].size;rows=(len(frames)+cols-1)//cols;out=Image.new('RGBA',(cols*cell[0],rows*cell[1]))
    for i,frame in enumerate(frames):out.paste(frame,((i%cols)*cell[0],(i//cols)*cell[1]))
    save(out,OUT/(name+'.webp'));return {'cell':list(cell),'columns':cols,'rows':rows,'frames':len(frames)}
def eyes(frame,kind):
    a=np.asarray(frame);r,g,b,alpha=[a[:,:,i].astype(float) for i in range(4)]
    mask=((r>205)&(g>65)&(g<r*.84)&(b<105)) if kind==0 else ((r<100)&(g>140)&(b>140))
    mask&=(alpha>150)&(np.indices(mask.shape)[0]<frame.height*.77)
    labels,count=ndimage.label(ndimage.binary_dilation(mask,iterations=4));components=[]
    for i in range(1,count+1):
        yy,xx=np.where((labels==i)&mask)
        if len(xx)>=3:components.append((len(xx),float(xx.mean()),float(yy.mean())))
    components.sort(reverse=True);assert components,(kind,components);near=components[0]
    choices=[c for c in components[1:] if c[1]>near[1]+12 and abs(c[2]-near[2])<32]
    pair=[near,max(choices)] if choices else [near,(0,near[1]+32,near[2]+6)]
    return [[round(x,3),round(y,3)] for _,x,y in pair]
def bare_mesh(frame,near,far,kind):
    a=np.asarray(frame);w=np.linalg.norm(np.asarray(far)-near)/(.38 if kind==0 else .37)
    cutoff=near[1]+w*(.12 if kind==0 else .38);left=near[0]-w*(1.90 if kind==0 else .77);right=far[0]+w*.25
    r,g,b,alpha=[a[:,:,i].astype(float) for i in range(4)];yy,xx=np.indices(alpha.shape)
    hair=(b>g*1.12)&(r>g*1.05)&(alpha>20)&(yy<cutoff)&(xx>left)&(xx<right)
    hair=ndimage.binary_dilation(hair,iterations=6)
    points=[];indices=[];step=8;nx=frame.width//step+1
    for y in range(0,frame.height+1,step):
        for x in range(0,frame.width+1,step):points.append([x,y])
    for y in range(frame.height//step):
        for x in range(frame.width//step):
            first=y*nx+x
            for tri in [(first,first+1,first+nx),(first+1,first+nx+1,first+nx)]:
                xx,yy=np.mean([points[i] for i in tri],axis=0).astype(int)
                if hair[min(yy,frame.height-1),min(xx,frame.width-1)]:continue
                indices.extend(tri)
    return {'points':points,'indices':indices}
def main():
    OUT.mkdir(parents=True,exist_ok=True);layout={}
    for kind,name in enumerate(['zombie_riders','skeleton_riders']):
        frames=split(name,4,4,(384,384));entry=atlas(name,frames,4);entry['poses']=[]
        for i,frame in enumerate(frames):
            near,far=eyes(frame,kind);hip=[184,278] if kind==0 else [215,276];width=np.linalg.norm(np.asarray(far)-near)/(.38 if kind==0 else .37)
            neck=[near[0]-width*.36,near[1]+width*.48]
            entry['poses'].append({'near':near,'far':far,'hip':hip,'neck':neck,'height':360,'bare_mesh':bare_mesh(frame,near,far,kind)})
        layout[name]=entry
    for name,cols,rows,cell in [('flood',4,4,(384,384)),('runner_woman',4,2,(256,342)),('runner_worker',4,2,(256,342)),('survivors',4,3,(320,320)),('rotor',4,2,(256,256))]:
        frames=split(name,cols,rows,cell);entry=atlas(name,frames,cols)
        if name.startswith('runner_'):entry['feet']=[frame.getchannel('A').point(lambda v:255 if v>80 else 0).getbbox()[3] for frame in frames]
        layout[name]=entry
    im=Image.open(SOURCE/'jetski.png').convert('RGBA');box=im.getchannel('A').point(lambda v:255 if v>30 else 0).getbbox();im=im.crop(box);im.thumbnail((1000,420),Image.Resampling.LANCZOS);save(im,OUT/'jetski.webp');layout['jetski']={'size':list(im.size)}
    (OUT/'layout.json').write_text(json.dumps(layout,separators=(',',':'))+'\n');print('V138_ART_OK',len(layout),sum(p.stat().st_size for p in OUT.iterdir()))
if __name__=='__main__':main()
