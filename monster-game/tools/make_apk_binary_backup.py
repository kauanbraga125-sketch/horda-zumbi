"""Preserve a signed APK delta and verify all public sources against its build report."""
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
    report=json.loads(a.apk.with_suffix('.json').read_text());assert sha(old)==report['base_apk_sha256']
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
    manifest={'version':report['version'],'code':report['code'],'base':{'url':a.base_url,'bytes':len(old),'sha256':sha(old)},'apk':{'name':a.apk.name,'bytes':len(new),'sha256':sha(new)},'literal':{'bytes':len(literal),'sha256':sha(literal),'parts':parts},'operations':ops,'physical_device_tested':False}
    tree=json.loads(a.tree.read_text())['tree'];source=[]
    paths={Path(i['path']).relative_to('monster-game').as_posix() for i in tree if i['type']=='blob' and i['path'].startswith('monster-game/') and i['path']!='monster-game/project.binary'}
    for p in a.source.rglob('*'):
        if p.is_file() and p.relative_to(a.source).parts[0] in ['tools','tests'] and p.name in ['save_full_recovery_v130.py','make_v130_binary_backup.py']:paths.add(p.relative_to(a.source).as_posix())
    paths.add('startup_integrity.json')
    paths.update(a.extra_source)
    for name in sorted(paths):
        p=a.source/name;data=p.read_bytes();source.append({'path':'monster-game/'+name,'bytes':len(data),'sha256':sha(data)})
    manifest['source_files']=source
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'literal_bytes':len(literal),'reused_bytes':len(new)-len(literal),'operations':len(ops),'parts':len(parts),'source_files':len(source),'sha256':sha(new)}))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['base','apk','output','source','tree']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--base-url',required=True)
    p.add_argument('--extra-source',action='append',default=[])
    main(p.parse_args())
