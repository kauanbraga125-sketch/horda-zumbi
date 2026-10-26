"""Stage an authenticated-tool-friendly public backup without signing secrets."""
import argparse,hashlib,json,zipfile
from pathlib import Path

def public(p):
    return not any(v in ['.git','.godot','__pycache__','assinatura_privada'] for v in p.parts) and p.suffix not in ['.keystore','.jks','.pyc','.apk','.idsig'] and p.name not in ['password.txt','export_credentials.cfg']

def main(a):
    r=a.source.resolve();stage=a.stage.resolve();work=a.work.resolve();pub=stage/'release-v0.10.29';payload=pub/'payload';payload.mkdir(parents=True,exist_ok=True)
    tree=json.loads(a.base_tree.read_text());known={v['path']:v for v in tree['tree'] if v['type']=='blob'};source_files=[];changed=[]
    for p in sorted(r.rglob('*')):
        if not p.is_file() or not public(p.relative_to(r)):continue
        name='monster-game/'+p.relative_to(r).as_posix();data=p.read_bytes();sha=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        source_files.append({'path':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        if name not in known or sha!=known[name]['sha']:changed.append((name,p))
    archive=work/'source-update.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for name,p in changed:z.write(p,name)
    with zipfile.ZipFile(archive) as z:assert z.testzip() is None and len(z.namelist())==len(changed)
    def pieces(path,stem):
        for old in payload.glob(stem+'-*.bin'):old.unlink()
        data=path.read_bytes();result={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'parts':[]}
        for i,start in enumerate(range(0,len(data),2*1024*1024)):
            part=data[start:start+2*1024*1024];p=payload/f'{stem}-{i:03d}.bin';p.write_bytes(part)
            result['parts'].append({'path':p.relative_to(pub).as_posix(),'bytes':len(part),'sha256':hashlib.sha256(part).hexdigest()})
        return result
    build=json.loads(a.apk.with_suffix('.json').read_text())
    manifest={'version':'0.10.29','code':132,'base_commit':'f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720','signing_certificate_sha256':build['signing_certificate_sha256'],'physical_device_tested':False,'apk':pieces(a.apk,'apk'),'source_delta':pieces(archive,'source'),'source_files':source_files}
    assert manifest['apk']['sha256']==build['sha256']
    (pub/'manifest.json').write_text(json.dumps(manifest,indent=2))
    queue=[]
    for p in sorted(stage.rglob('*')):
        if not p.is_file() or '__pycache__' in p.parts:continue
        data=p.read_bytes();queue.append({'local_path':str(p),'path':p.relative_to(stage).as_posix(),'bytes':len(data),'sha':hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()})
    (work/'github-upload-queue.json').write_text(json.dumps(queue,indent=2))
    print(json.dumps({'changed_source_files':len(changed),'all_source_files':len(source_files),'source_zip_bytes':archive.stat().st_size,'upload_objects':len(queue),'upload_bytes':sum(v['bytes'] for v in queue)}))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ['source','base-tree','apk','stage','work']:p.add_argument('--'+n,type=Path,required=True)
    main(p.parse_args())
