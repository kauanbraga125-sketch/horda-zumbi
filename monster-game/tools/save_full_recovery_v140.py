"""Private offline project recovery, with imports and signing identity.

The independently saved signed APK is referenced by hash instead of duplicated.
"""
import argparse,hashlib,json,os
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED

VERIFY='''from pathlib import Path
from zipfile import ZipFile
import hashlib,json
r=Path(__file__).resolve().parent;m=json.loads((r/'manifesto.json').read_text())
for item in m['files']:
 p=r/item['path']
 assert p.stat().st_size==item['bytes'] and hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==item['sha256'],item['path']
print('BACKUP_OK',m['version'],len(m['files']))
print('Projeto pronto em projeto/monster-game/project.godot, Godot4.5.1; importacoes incluidas.')
'''
def sha(data):return hashlib.sha256(data).hexdigest()
def main(a):
 source=a.source.resolve();entries=[];a.output.parent.mkdir(parents=True,exist_ok=True)
 apk_hash=hashlib.file_digest(a.apk.open('rb'),'sha256').hexdigest()
 with ZipFile(a.output,'w',ZIP_DEFLATED,compresslevel=9) as z:
  def add(name,data):
   z.writestr(name,data);entries.append({'path':name,'bytes':len(data),'sha256':sha(data)})
  for p in sorted(source.rglob('*')):
   if not p.is_file():continue
   rel=p.relative_to(source)
   if any(v in ['.git','.godot','__pycache__','build','validation'] or v.startswith('.') for v in rel.parts):continue
   if p.name in ['project.binary','export_credentials.cfg'] or p.suffix in ['.tmp','.bak','.pyc','.apk','.keystore','.jks']:continue
   add('projeto/monster-game/'+rel.as_posix(),p.read_bytes())
  imported=0
  with ZipFile(a.apk) as apk:
   for name in apk.namelist():
    if name.startswith('assets/.godot/'):
     add('projeto/monster-game/'+name[7:],apk.read(name));imported+=1
   add('projeto/monster-game/.godot/v140-project.binary',apk.read('assets/project.binary'))
  for name in ['horda-reconstruida.keystore','password.txt']:add('assinatura_privada/'+name,(a.private/name).read_bytes())
  add('assinatura_privada/LEIA-ME.txt','Identidade PRIVADA do aplicativo. Não publicar a chave, a senha ou este ZIP no GitHub.\n'.encode())
  for p in sorted(a.reports.rglob('*')):
   if p.is_file() and p.suffix in ['.log','.json']:add('validacao/'+p.relative_to(a.reports).as_posix(),p.read_bytes())
  for p in sorted(source.parent.glob('.github/workflows/*')):
   if p.is_file():add('repositorio/'+p.relative_to(source.parent).as_posix(),p.read_bytes())
  add('repositorio/README.md',(source.parent/'README.md').read_bytes())
  add('verificar_backup.py',VERIFY.encode())
  add('LEIA-ME.txt',('HORDA ZUMBI 0.10.40 — recuperação privada do projeto\n\nEste ZIP contém o projeto completo, artes originais, fontes, ferramentas, testes, importações verificadas e identidade de assinatura.\n\n1. Extraia todo o ZIP.\n2. Execute python verificar_backup.py.\n3. Abra projeto/monster-game/project.godot no Godot4.5.1. As importações já estão incluídas, permitindo abrir o projeto sem baixar arquivos.\n\nO APK assinado é entregue separadamente e está preservado no GitHub. Nome: '+a.apk.name+'\nSHA256: '+apk_hash+'\nURL: https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.40/'+a.apk.name+'\n\nA configuração binária desta versão fica em .godot/v140-project.binary. Não copie project.binary antigo para a raiz. Após editar/reimportar, rode tools/refresh_startup_integrity.py. O Android usa versão0.10.40, código143 e a mesma assinatura da0.10.39.\n\nEste ZIP, a chave e a senha devem permanecer PRIVADOS. Os fontes públicos e o APK também estão no GitHub. Não houve teste em Android físico nesta sessão.\n').encode())
  z.writestr('manifesto.json',json.dumps({'version':'0.10.40','self_contained_project':True,'apk_embedded':False,'imported_entries':imported,'physical_device_tested':False,'apk':{'name':a.apk.name,'bytes':a.apk.stat().st_size,'sha256':apk_hash,'url':'https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/v0.10.40/'+a.apk.name},'files':entries},ensure_ascii=False,indent=2))
 with ZipFile(a.output) as z:
  assert len(z.namelist())==len(set(z.namelist())) and z.testzip() is None
  for e in entries:
   data=z.read(e['path']);assert len(data)==e['bytes'] and sha(data)==e['sha256'],e['path']
 result={'path':str(a.output.resolve()),'bytes':a.output.stat().st_size,'sha256':hashlib.file_digest(a.output.open('rb'),'sha256').hexdigest(),'files':len(entries),'self_contained_project':True,'apk_embedded':False,'imported_entries':imported}
 a.output.with_suffix('.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ['source','private','reports','output','apk']:p.add_argument('--'+name,type=Path,required=True)
 main(p.parse_args())
