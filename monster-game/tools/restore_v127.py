"""Restore the verified source delta and optionally the exact packaged runtime."""
from pathlib import Path
import argparse,hashlib,json,shutil,tempfile,urllib.request,zipfile
BASE='f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720'
p=argparse.ArgumentParser();p.add_argument('--base-dir',type=Path);p.add_argument('--apk',type=Path);p.add_argument('--output',type=Path,default=Path('horda-zumbi-recuperado'));a=p.parse_args()
backup=Path(__file__).resolve().parent;out=a.output.resolve();manifest=json.loads((backup/'manifesto.json').read_text())
if out.exists():raise SystemExit('Escolha uma pasta nova com --output.')
for item in manifest['files']:
 if hashlib.sha256((backup/'alteracoes'/item['path']).read_bytes()).hexdigest()!=item['sha256']:raise SystemExit('Arquivo inválido no backup: '+item['path'])
with tempfile.TemporaryDirectory(prefix='horda-restore-') as tmp:
 tmp=Path(tmp)
 if a.base_dir:source=a.base_dir.resolve()
 else:
  print('Baixando a base pública no commit exato...')
  archive=tmp/'base.zip';urllib.request.urlretrieve('https://github.com/kauanbraga125-sketch/horda-zumbi/archive/'+BASE+'.zip',archive);folder=tmp/'base';folder.mkdir()
  with zipfile.ZipFile(archive) as z:
   for n in z.namelist():
    if not (folder/n).resolve().is_relative_to(folder.resolve()):raise SystemExit('Caminho inválido na base.')
   z.extractall(folder)
  source=next(d for d in folder.iterdir() if d.is_dir())
 shutil.copytree(source,out,ignore=shutil.ignore_patterns('.git','.godot','build','__pycache__'))
 if a.apk:
  with zipfile.ZipFile(a.apk) as z:
   for n in z.namelist():
    if not n.startswith('assets/') or n.endswith('/') or n[7:] in ['assets.sparsepck','_cl_']:continue
    target=out/'monster-game'/n[7:]
    if not target.resolve().is_relative_to(out.resolve()):raise SystemExit('Caminho inválido no APK.')
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(n))
 # Source wins over stale source/config files included in older APK templates.
 shutil.copytree(backup/'alteracoes',out,dirs_exist_ok=True)
 for name in manifest.get('deleted',[]):
  target=out/name
  if target.is_file():target.unlink()
 project=out/'monster-game';imported=project/'.godot/imported';imported.mkdir(parents=True,exist_ok=True)
 for extra in (backup/'compilacao').glob('*.ctex'):shutil.copyfile(extra,imported/extra.name)
 cache=backup/'compilacao/global_script_class_cache.cfg'
 if cache.exists():shutil.copyfile(cache,project/'.godot/global_script_class_cache.cfg')
 if a.apk:shutil.copyfile(backup/'compilacao/project.binary',project/'project.binary')
 for item in manifest['files']:
  if hashlib.sha256((out/item['path']).read_bytes()).hexdigest()!=item['sha256']:raise SystemExit('Divergência após restaurar: '+item['path'])
print('Projeto recuperado:',out)
print('Godot 4.5.1. Assinatura privada permanece separada em assinatura_privada.')
print('Sem --apk: importe no editor e execute tools/refresh_startup_integrity.py antes de exportar.')
