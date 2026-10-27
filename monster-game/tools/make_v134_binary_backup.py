"""Store a byte-exact signed APK delta against the public verified 0.10.33."""
import argparse,hashlib,json,struct
from pathlib import Path
from zipfile import ZipFile

def sha(data):return hashlib.sha256(data).hexdigest()
def payload(data,info):
    off=info.header_offset
    assert data[off:off+4]==b'PK\x03\x04'
    names,extra=struct.unpack_from('<HH',data,off+26)
    return off+30+names+extra

def main(a):
    old=a.base.read_bytes();new=a.apk.read_bytes()
    assert sha(old)=='b48aa9368244a2ea53f8064cb766e8a3111a74f060ad705ff19557c2ed3cb851'
    literal=bytearray();ops=[]
    def add(kind,offset,length):
        if not length:return
        if ops and ops[-1][0]==kind and ops[-1][1]+ops[-1][2]==offset:ops[-1][2]+=length
        else:ops.append([kind,offset,length])
    def lit(data):
        offset=len(literal);literal.extend(data);add(1,offset,len(data))
    with ZipFile(a.base) as oz,ZipFile(a.apk) as nz:
        originals={i.filename:i for i in oz.infolist()};cursor=0
        for i in sorted(nz.infolist(),key=lambda i:i.header_offset):
            start=payload(new,i);end=start+i.compress_size
            lit(new[cursor:start]);previous=originals.get(i.filename)
            if previous:
                p=payload(old,previous)
                if previous.compress_size==i.compress_size and old[p:p+i.compress_size]==new[start:end]:add(0,p,i.compress_size)
                else:lit(new[start:end])
            else:lit(new[start:end])
            cursor=end
        lit(new[cursor:])
    reconstructed=b''.join((old if kind==0 else literal)[offset:offset+length] for kind,offset,length in ops)
    assert reconstructed==new
    out=a.output;out.mkdir(parents=True,exist_ok=True);parts=[]
    for offset in range(0,len(literal),2*1024*1024):
        data=bytes(literal[offset:offset+2*1024*1024]);path=Path('payload')/('apk-%03d.bin'%len(parts))
        (out/path).parent.mkdir(exist_ok=True);(out/path).write_bytes(data)
        parts.append({'path':path.as_posix(),'bytes':len(data),'sha256':sha(data)})
    manifest={'version':'0.10.34','code':137,'base':{'url':'https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.33/Horda-Zumbi-v0.10.33-TESTE-1M-ESPACO-REVISADO-ARM64.apk','bytes':len(old),'sha256':sha(old)},'apk':{'name':a.apk.name,'bytes':len(new),'sha256':sha(new)},'literal':{'bytes':len(literal),'sha256':sha(literal),'parts':parts},'operations':ops,'physical_device_tested':False}
    import subprocess
    repo=a.source.parent
    tracked=subprocess.check_output(['git','ls-files','-z'],cwd=repo).decode().split('\0')
    added=subprocess.check_output(['git','ls-files','--others','--exclude-standard','-z'],cwd=repo).decode().split('\0')
    paths={n for n in tracked+added if n.startswith('monster-game/') or n in ['README.md','.github/workflows/horda-v01034.yml','.github/workflows/noite-da-horda-android.yml']}
    source=[]
    for name in sorted(paths):
        p=repo/name
        if not p.is_file() or p.name=='project.binary':continue
        data=p.read_bytes();source.append({'path':name,'bytes':len(data),'sha256':sha(data)})
    manifest['source_files']=source
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'literal_bytes':len(literal),'reused_bytes':len(new)-len(literal),'operations':len(ops),'parts':len(parts),'source_files':len(source),'sha256':sha(new)}))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['base','apk','output','source']:p.add_argument('--'+name,type=Path,required=True)
    main(p.parse_args())
