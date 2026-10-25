"""Reconstruct the verified APK and apply the complete source update.

Public backup only: no keystore, password or signing credential is included.
"""
import argparse,hashlib,json,shutil,zipfile
from pathlib import Path

def digest(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def assemble(root,entry,out):
    out.parent.mkdir(parents=True,exist_ok=True)
    with out.open('wb') as target:
        for part in entry['parts']:
            source=root/part['path']
            assert source.stat().st_size==part['bytes'] and digest(source)==part['sha256'],part['path']
            with source.open('rb') as stream:shutil.copyfileobj(stream,target)
    assert out.stat().st_size==entry['bytes'] and digest(out)==entry['sha256'],out.name

def public_file(rel):
    return not any(p in ['.git','.godot','__pycache__','assinatura_privada'] or (p.startswith('.') and p not in ['.gitignore','.gdignore']) for p in rel.parts) and rel.suffix not in ['.keystore','.jks','.pyc','.apk','.idsig'] and rel.name not in ['password.txt','export_credentials.cfg']

def main(a):
    root=Path(__file__).resolve().parent;repo=root.parent;manifest=json.loads((root/'manifest.json').read_text());out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    assert manifest['version']=='0.10.29' and manifest['code']==132
    apk=out/'Horda-Zumbi-v0.10.29-ARM64.apk';source_delta=out/'source-update.zip'
    assemble(root,manifest['apk'],apk);assemble(root,manifest['source_delta'],source_delta)
    if a.apply_source:
        with zipfile.ZipFile(source_delta) as z:
            assert z.testzip() is None
            for name in z.namelist():
                rel=Path(name)
                assert not rel.is_absolute() and '..' not in rel.parts and rel.parts[0]=='monster-game' and public_file(rel),name
                p=repo/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(z.read(name))
        for item in manifest['source_files']:
            p=repo/item['path'];assert p.stat().st_size==item['bytes'] and digest(p)==item['sha256'],item['path']
    if a.package_source:
        full=out/'Horda-Zumbi-v0.10.29-Projeto-Publico.zip'
        with zipfile.ZipFile(full,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for p in sorted((repo/'monster-game').rglob('*')):
                rel=p.relative_to(repo)
                if p.is_file() and public_file(rel):z.write(p,rel.as_posix())
            z.writestr('LEIA-ME.txt','Horda Zumbi 0.10.29. Projeto completo para Godot 4.5.1. Importe monster-game/project.godot e atualize o diagnóstico com tools/refresh_startup_integrity.py antes de testar/exportar. A identidade privada de assinatura permanece no backup privado do proprietário. Leia CORRECAO-v0.10.29.md.\n')
    for source in (root/'previews').glob('*.png'):shutil.copyfile(source,out/source.name)
    source_delta.unlink()
    files=sorted(p for p in out.iterdir() if p.is_file() and p.name!='SHA256SUMS.txt')
    (out/'SHA256SUMS.txt').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in files))
    print('RELEASE_RESTORED',manifest['version'],manifest['apk']['sha256'],len(manifest['source_files']),'source files')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=Path('dist'));p.add_argument('--apply-source',action='store_true');p.add_argument('--package-source',action='store_true');main(p.parse_args())
