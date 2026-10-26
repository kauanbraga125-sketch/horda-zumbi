"""Refresh replacement-cape source cuts, including upward airborne tails."""
from prepare_v113_cosmetics import ART,OUT,mesh
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
import numpy as np,json,struct,zstandard

packed=(OUT/'fitting.bin').read_bytes()
frames=json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]));sheets={}
for key,f in frames.items():
    if f['kind']!=1:continue
    file=f['file']
    if file not in sheets:sheets[file]=Image.open(ART/file).convert('RGBA')
    x,y,cw,ch=map(int,f['rect']);p=np.asarray(sheets[file].crop((x,y,x+cw,y+ch))).astype(float)
    r,g,b,a=p.transpose(2,0,1);yy,xx=np.mgrid[:ch,:cw]
    l,t,rr,bb=f['box'];w=f['head_width'];neck=np.array(f['landmarks']['neck']);hip=np.array(f['landmarks']['hip']);td=(hip-neck)/np.linalg.norm(hip-neck);tr=np.array([td[1],-td[0]])
    skin=(a>80)&(r>140)&(g>115)&(b<g*.91)&(r>g*1.02)
    magenta=(a>20)&(r>g*1.7)&(b>g*1.5)&(r>b*.5)
    along=(xx-neck[0])*td[0]+(yy-neck[1])*td[1];across=(xx-neck[0])*tr[0]+(yy-neck[1])*tr[1]
    guard=(abs(across)<.38*w)&(along>-.12*w)&(along<1.30*w)
    cape_area=(xx<neck[0]+(yy-neck[1])*td[0]/max(.1,td[1])-.12*w)&(yy<t+2.2*w)
    remove=ndi.binary_dilation(magenta&cape_area,iterations=7)&~ndi.binary_dilation(skin,iterations=4)&~guard
    bare=f['meshes']['bare'];mask=Image.new('1',(cw,ch));draw=ImageDraw.Draw(mask)
    for i in range(0,len(bare['indices']),3):draw.polygon([tuple(bare['points'][j])for j in bare['indices'][i:i+3]],fill=1)
    keep=np.asarray(mask)&~remove
    labels,n=ndi.label(keep&(a>5));sizes=np.bincount(labels.ravel());discard=(sizes[labels]<max(10,.015*w*w))&(yy<t+1.25*w)&(labels>0)
    keep&=~ndi.binary_dilation(discard,iterations=1)
    f['meshes']['bare_cape']=mesh(keep)
data=json.dumps(frames,separators=(',',':')).encode();(OUT/'fitting.bin').write_bytes(struct.pack('<I',len(data))+zstandard.ZstdCompressor(level=19).compress(data))
print('Updated cape masks for 167 skeleton frames')
