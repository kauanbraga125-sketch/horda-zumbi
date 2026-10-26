"""Recreate the exact signed APK and verify all public sources; no private key."""
import argparse,hashlib,json,os,shutil,urllib.request
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED

def sha(data):return hashlib.sha256(data).hexdigest()
def checked(data,item):
    assert len(data)==item['bytes'] and sha(data)==item['sha256'],item.get('path',item.get('name','data'))
    return data

def main(a):
    here=Path(__file__).resolve().parent;repo=here.parent;m=json.loads((here/'manifest.json').read_text())
    a.out.mkdir(parents=True,exist_ok=True)
    if a.base:old=a.base.read_bytes()
    else:
        with urllib.request.urlopen(m['base']['url'],timeout=120) as response:old=response.read()
    checked(old,m['base'])
    literal=b''.join(checked((here/p['path']).read_bytes(),p) for p in m['literal']['parts']);checked(literal,m['literal'])
    data=b''.join((old if kind==0 else literal)[offset:offset+length] for kind,offset,length in m['operations']);checked(data,m['apk'])
    apk=a.out/m['apk']['name']
    with apk.open('wb') as output:
        for offset in range(0,len(data),1024*1024):
            chunk=memoryview(data)[offset:offset+1024*1024]
            while chunk:
                written=output.write(chunk)
                assert written is not None and written>0,'APK write interrupted'
                chunk=chunk[written:]
        output.flush();os.fsync(output.fileno())
    checked(apk.read_bytes(),m['apk'])
    sources=[]
    for item in m['source_files']:
        p=repo/item['path'];checked(p.read_bytes(),item);sources.append(p)
    files=[apk]
    if a.package_source:
        package=a.out/'Horda-Zumbi-v0.10.30-Projeto-Publico.zip'
        with ZipFile(package,'w',ZIP_DEFLATED,compresslevel=6) as z:
            for p in sources:z.write(p,p.relative_to(repo).as_posix())
            z.writestr('LEIA-ME.txt','Horda Zumbi 0.10.30, Godot 4.5.1. Projeto público completo sem credenciais privadas. Abra monster-game/project.godot e importe. Em seguida rode python3 monster-game/tools/refresh_startup_integrity.py antes de executar. O APK distribuído já contém as importações verificadas. Não houve teste em Android físico.\n')
        files.append(package)
    for p in sorted((here/'previews').glob('*.png')):
        dest=a.out/p.name;shutil.copyfile(p,dest);files.append(dest)
    for name in ['VALIDACAO-v0.10.30.json','CORRECAO-v0.10.30.md']:
        dest=a.out/name;shutil.copyfile(repo/'monster-game'/name,dest);files.append(dest)
    (a.out/'SHA256SUMS.txt').write_text(''.join(sha(p.read_bytes())+'  '+p.name+'\n' for p in files))
    print(json.dumps({'apk_sha256':sha(data),'source_files_checked':len(sources),'output':str(a.out),'physical_device_tested':False}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--base',type=Path);p.add_argument('--package-source',action='store_true');main(p.parse_args())
