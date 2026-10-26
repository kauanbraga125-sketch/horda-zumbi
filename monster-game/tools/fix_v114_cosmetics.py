"""Repair UV masks and layers without changing approved character PNGs."""
import json,struct
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
import zstandard
from shapely.geometry import Polygon
from prepare_v113_cosmetics import ART,OUT,mesh

def raster(data,size):
 result=Image.new('1',size);draw=ImageDraw.Draw(result)
 for i in range(0,len(data['indices']),3):draw.polygon([tuple(data['points'][j])for j in data['indices'][i:i+3]],fill=1)
 return np.asarray(result)

def bounds(mask):
 y,x=np.where(mask)
 return [int(x.min()),int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)]

def main():
 raw=(OUT/'fitting.bin').read_bytes();frames=json.loads(zstandard.ZstdDecompressor().decompress(raw[4:]));sheets={}
 outlines=json.loads((ART/'zombie-fluid-v73.json').read_text())['frames']
 audit={'frames':len(frames),'protected_body_pixels':0,'protected_hood_pixels':0,'protected_limb_pixels':0,'pngs_modified':0}
 for key,f in frames.items():
  if f['file']not in sheets:sheets[f['file']]=np.asarray(Image.open(ART/f['file']).convert('RGBA'))
  x,y,cw,ch=map(int,f['rect']);p=sheets[f['file']][y:y+ch,x:x+cw].astype(float)
  r,g,b,a=p.transpose(2,0,1);yy,xx=np.mgrid[:ch,:cw]
  l,t,rr,bb=f['box'];w=f['head_width'];neck=np.array(f['landmarks']['neck'])
  hip=np.array(f['landmarks']['hip']);td=(hip-neck)/np.linalg.norm(hip-neck);tr=np.array([td[1],-td[0]])
  face=raster(f['meshes']['face'],(cw,ch))
  head=((xx>l-.64*w)&(xx<rr+.30*w)&(yy<t+.84*w))if f['kind']==0 else((xx>l-.96*w)&(xx<rr+.28*w)&(yy<t+1.12*w)&(yy<t+.70*w+(xx-(l-.75*w))*.44))
  protected_body=yy>neck[1]-.12*w;bare=(~head)|face|protected_body
  rim=(np.array(f['landmarks']['rim_l'])+np.array(f['landmarks']['rim_r']))*.5;down=np.array(f['down'])
  above=((xx-rim[0])*down[0]+(yy-rim[1])*down[1])<.035*w;hat=(~(head&above))|face|protected_body
  remove=np.zeros((ch,cw),dtype=bool)
  if f['kind']==1:
   skin=(a>80)&(r>140)&(g>115)&(b<g*.91)&(r>g*1.02);magenta=(a>20)&(r>g*1.7)&(b>g*1.5)&(r>b*.5)
   along=(xx-neck[0])*td[0]+(yy-neck[1])*td[1];across=(xx-neck[0])*tr[0]+(yy-neck[1])*tr[1]
   torso=(abs(across)<.38*w)&(along>-.12*w)&(along<1.30*w)
   # Vivid cape cloth can swing to either side in the air. Identify its
   # colour-connected pieces, while guarding the hood, torso and bones.
   cloth=magenta&~head&~torso&~ndi.binary_dilation(skin,iterations=2)
   labels,count=ndi.label(cloth)
   vivid=cloth&(r>110)&(b>80)
   chosen=np.zeros_like(cloth)
   for label in np.unique(labels[vivid]):
    if label and np.count_nonzero(labels==label)>max(20,.01*w*w):chosen|=labels==label
   # Purple boots/gloves share the cape's hue. Preserve their entire outline
   # around the visible limb bones, including the toes beyond each ankle.
   limbs=ndi.binary_dilation(skin&(yy>t+.8*w),iterations=max(6,round(.36*w)))
   remove=ndi.binary_dilation(chosen,iterations=7)&~limbs&~ndi.binary_dilation(skin,iterations=4)&~torso&~head
   assert not np.any(remove&limbs)
   audit['protected_limb_pixels']+=int((limbs&(a>0)).sum())
   assert not np.any(remove&head)
   audit['protected_hood_pixels']+=int((head&(a>0)).sum())
  alpha=ndi.binary_dilation(a>0,iterations=2)
  clip=Polygon(outlines[int(key[8:])]['outline'])if key.startswith('z_other_')and'outline'in outlines[int(key[8:])]else None
  for name,keep in [('bare',bare),('hat',hat),('bare_cape',bare&~remove),('hat_cape',hat&~remove),('cape_only',~remove)]:f['meshes'][name]=mesh(keep&alpha,clip)
  assert np.all(bare[protected_body])and np.all(hat[protected_body])
  audit['protected_body_pixels']+=int((protected_body&(a>0)).sum());f['bounds']=bounds(a>0)
 data=json.dumps(frames,separators=(',',':')).encode();(OUT/'fitting.bin').write_bytes(struct.pack('<I',len(data))+zstandard.ZstdCompressor(level=19).compress(data))
 graphics=json.loads((OUT/'graphics.json').read_text())
 for id,f in graphics.items():
  if f['file']not in sheets:sheets[f['file']]=np.asarray(Image.open(ART/f['file']).convert('RGBA'))
  x,y,cw,ch=map(int,f['rect']);a=sheets[f['file']][y:y+ch,x:x+cw,3];f['bounds']=bounds(a>0)
  if id in ['z_vampire','s_bat']:
   yy,xx=np.mgrid[:ch,:cw];f['front_mesh']=mesh((a>0)&(xx>cw*.69)&(yy<ch*.28))
 (OUT/'graphics.json').write_text(json.dumps(graphics,separators=(',',':')))
 print(json.dumps(dict(audit,fitting_bytes=(OUT/'fitting.bin').stat().st_size)),flush=True)

if __name__=='__main__':main()
