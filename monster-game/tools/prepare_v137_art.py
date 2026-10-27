"""Split new imagegen originals into aligned, transparent game animation cells."""
from pathlib import Path
from PIL import Image
import io,os,json

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tools/art_sources/v137'
OUT=ROOT/'assets/art/v137'

def save(im,path):
    buf=io.BytesIO();im.save(buf,'WEBP',lossless=True,method=6);data=buf.getvalue()
    with path.open('wb') as f:
        for offset in range(0,len(data),65536):f.write(data[offset:offset+65536]);f.flush()
        os.fsync(f.fileno())
    assert path.read_bytes()==data
    Image.open(path).verify()

def sheet(name,cols,rows,cell):
    source=Image.open(SOURCE/(name+'.png')).convert('RGBA')
    atlas=Image.new('RGBA',(cols*cell[0],rows*cell[1]))
    for y in range(rows):
        for x in range(cols):
            box=(round(x*source.width/cols),round(y*source.height/rows),round((x+1)*source.width/cols),round((y+1)*source.height/rows))
            frame=source.crop(box).resize(cell,Image.Resampling.LANCZOS)
            atlas.paste(frame,(x*cell[0],y*cell[1]))
    save(atlas,OUT/(name+'.webp'))
    return {'file':name+'.webp','columns':cols,'rows':rows,'cell':cell,'frames':cols*rows}

def main():
    OUT.mkdir(exist_ok=True)
    entries={'survivors':sheet('survivors',3,3,(320,320)),
             'runners':sheet('runners',4,3,(256,342)),
             'wave':sheet('wave',4,2,(320,426))}
    source=Image.open(SOURCE/'hazards.png').convert('RGBA')
    for name,box in {'pipe_mount':(0,0,768,512),'wreck':(768,0,1536,512),'gate_mount':(0,512,768,1024),'floating_barrel':(768,512,1536,1024)}.items():
        im=source.crop(box)
        bounds=im.getchannel('A').point(lambda a:255 if a>25 else 0).getbbox()
        assert bounds
        im=im.crop(bounds);im.thumbnail((640,448),Image.Resampling.LANCZOS)
        save(im,OUT/(name+'.webp'))
        entries[name]={'file':name+'.webp','size':list(im.size),'source_box':box,'trim':bounds}
    (OUT/'layout.json').write_text(json.dumps(entries,indent=2)+'\n')
    print(json.dumps({'assets':len(entries),'bytes':sum(p.stat().st_size for p in OUT.iterdir())}))

if __name__=='__main__':main()
