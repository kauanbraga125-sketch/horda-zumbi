"""Keep atlas sizes, frames and alpha; encode a compact or lossless APK cache.

Reads Godot's imported pixels rather than assuming importer settings. Optional
existing caches are reused only when they satisfy the pixel checks below.
"""
from pathlib import Path
from zipfile import ZipFile
from concurrent.futures import ThreadPoolExecutor,as_completed
from PIL import Image
from scipy.ndimage import maximum_filter
import argparse,re,io,json,os
def main(a):
    a.output.mkdir(parents=True,exist_ok=True)
    z=ZipFile(a.resources);jobs=[]
    excluded={'assets/icon-monsters-v51.png','assets/art/results_v110/souls.png'}
    for name in z.namelist():
        if not name.endswith('.png.import')or name[:-7]in excluded:continue
        rel=name[:-7];cfg=z.read(name).decode();path=re.search(r'path="res://([^"]+)"',cfg).group(1);blob=z.read(path)
        assert blob[:4]==b'GST2' and int.from_bytes(blob[36:40],'little')in [1,2]and int.from_bytes(blob[44:48],'little')==0,path
        jobs.append((rel,blob[56:]))
    def encode(job):
        rel,payload=job;im=Image.open(io.BytesIO(payload)).convert('RGBA');original=im.copy()
        pixels=__import__('numpy').asarray(im);np=__import__('numpy');guard=maximum_filter(pixels[:,:,3],size=9)>0
        exact=a.profile=='lossless' or any(key in rel for key in ['menu-play','menu-missions','menu-logo','portrait.png','market-art-v82'])or (a.source/rel).stat().st_size<65000
        quality=92 if any(key in rel for key in ['parallax','background','tunnel','terrain','cosmetics_v113','polish_v101','profile_v104','experiment_v105','menu_v102','results_v110'])else 85
        data=None
        if a.reuse:
            cached=a.reuse/(rel+'.webp')
            if cached.is_file():
                proposed=cached.read_bytes();decoded=np.asarray(Image.open(io.BytesIO(proposed)).convert('RGBA'))
                if decoded.shape==pixels.shape and np.array_equal(pixels[:,:,3],decoded[:,:,3])and (not exact or np.array_equal(pixels[guard],decoded[guard])):data=proposed
        if data is None:
            keep=pixels.copy();keep[~guard,:3]=0
            buf=io.BytesIO();Image.fromarray(keep).save(buf,format='WEBP',lossless=exact,quality=100 if exact else quality,method=4,alpha_quality=100,exact=True);data=buf.getvalue()
        decoded=np.asarray(Image.open(io.BytesIO(data)).convert('RGBA'))
        assert np.array_equal(pixels[:,:,3],decoded[:,:,3])
        if exact:assert np.array_equal(pixels[guard],decoded[guard])
        dest=a.output/(rel+'.webp');dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_suffix('.tmp');tmp.write_bytes(data);os.replace(tmp,dest)
        return dict(source=rel,bytes=len(data),lossless=exact,quality=100 if exact else quality,alpha_exact=True,visible_and_guard_rgba_exact=bool(np.array_equal(pixels[guard],decoded[guard])),width=im.width,height=im.height)
    rows=[]
    with ThreadPoolExecutor(max_workers=4)as ex:
        for f in as_completed([ex.submit(encode,j)for j in jobs]):rows.append(f.result())
    report=dict(profile=a.profile,textures=len(rows),bytes=sum(r['bytes']for r in rows),original_dimensions=True,animation_frames_removed=0,images=sorted(rows,key=lambda r:r['source']))
    (a.output/'report.json').write_text(json.dumps(report,indent=2));print({k:v for k,v in report.items()if k!='images'})
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--resources',type=Path,required=True);p.add_argument('--source',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--output',type=Path,required=True);p.add_argument('--profile',choices=['compact','lossless'],required=True);p.add_argument('--reuse',type=Path);main(p.parse_args())
