"""Save a private, offline recovery ZIP. Imported caches are restored from its APK."""
import argparse,hashlib,json,os
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED

RESTORE = '''from pathlib import Path
from zipfile import ZipFile
import hashlib,json
r=Path(__file__).resolve().parent
m=json.loads((r/'manifesto.json').read_text())
apk=r/m['apk']['path']
assert hashlib.file_digest(apk.open('rb'),'sha256').hexdigest()==m['apk']['sha256']
root=r/'projeto/monster-game';count=0
with ZipFile(apk) as z:
 for n in z.namelist():
  if n.startswith('assets/.godot/'):
   dest=root/n[7:];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(n));count+=1
 binary=root/'.godot/v134-project.binary';binary.parent.mkdir(exist_ok=True);binary.write_bytes(z.read('assets/project.binary'))
print('IMPORTACOES_RESTAURADAS',count)
print('Abra projeto/monster-game/project.godot no Godot 4.5.1. Nao copie project.binary para a raiz.')
'''
VERIFY = '''from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parent;m=json.loads((r/'manifesto.json').read_text())
for e in m['files']:
 p=r/e['path']
 assert p.stat().st_size==e['bytes'] and hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==e['sha256'],e['path']
print('BACKUP_OK',m['version'],len(m['files']))
'''

def sha(data):return hashlib.sha256(data).hexdigest()
def main(a):
    source=a.source.resolve();entries=[];a.output.parent.mkdir(parents=True,exist_ok=True)
    with ZipFile(a.output,'w',ZIP_DEFLATED,compresslevel=6) as z:
        def add(name,data):
            z.writestr(name,data);entries.append({'path':name,'bytes':len(data),'sha256':sha(data)})
        for p in sorted(source.rglob('*')):
            if not p.is_file():continue
            rel=p.relative_to(source)
            if any(v in ['.git','.godot','__pycache__','build','validation'] for v in rel.parts):continue
            if p.name in ['project.binary','export_credentials.cfg'] or p.suffix in ['.tmp','.bak','.pyc','.apk','.keystore','.jks']:continue
            add('projeto/monster-game/'+rel.as_posix(),p.read_bytes())
        apk_path='aplicativo/'+a.apk.name;apk_bytes=a.apk.read_bytes();add(apk_path,apk_bytes)
        for name in ['horda-reconstruida.keystore','password.txt']:add('assinatura_privada/'+name,(a.private/name).read_bytes())
        add('assinatura_privada/LEIA-ME.txt','Identidade PRIVADA do aplicativo. Não publicar este ZIP, a chave ou a senha no GitHub.\n'.encode())
        for p in sorted(a.reports.rglob('*')):
            if not p.is_file():continue
            rel=p.relative_to(a.reports)
            if rel.parts[0] not in ['tests','packaged-tests','native-startup','packaged-cabins','regression','visual-final']:continue
            if rel.parts[0]=='visual-final' and p.suffix=='.png' and p.name not in ['01_horda_quatro.png','04_horda_vinte.png','06_horda_oitenta_oito.png','07_onibus_cabine.png','08_caca_cabine.png','24_partida_069.png','24_partida_169.png','24_partida_269.png','25_passagem_nova.png','26_mira_alienigena.png','27_nucleo_exposto.png','28_portal_proximo_setor.png']:continue
            if 'motion' in rel.parts or p.suffix not in ['.log','.json','.png']:continue
            add('validacao/'+rel.as_posix(),p.read_bytes())
        for p in sorted(source.parent.glob('.github/workflows/*')):
            if p.is_file():add('repositorio/'+p.relative_to(source.parent).as_posix(),p.read_bytes())
        readme=source.parent/'README.md'
        if readme.exists():add('repositorio/README.md',readme.read_bytes())
        for name,text in [('restaurar_importacoes.py',RESTORE),('verificar_backup.py',VERIFY)]:add(name,text.encode())
        add('LEIA-ME.txt',('HORDA ZUMBI 0.10.34 — recuperação completa\n\nContém o projeto e artes originais, fontes, testes, APK assinado e identidade privada para continuar atualizando o aplicativo.\n\n1. Extraia todo o ZIP.\n2. Execute python restaurar_importacoes.py para recuperar do APK as importações verificadas, sem depender da internet.\n3. Execute python verificar_backup.py.\n4. Abra projeto/monster-game/project.godot no Godot 4.5.1.\n\nNão copie project.binary antigo para a raiz. A configuração desta versão fica em .godot/v134-project.binary. Após editar/reimportar, rode tools/refresh_startup_integrity.py. O Android usa versão 0.10.34, código 137 e a mesma assinatura da 0.10.33.\n\nA pasta assinatura_privada e este ZIP devem permanecer PRIVADOS. Os fontes públicos e o APK também estão no GitHub. Não houve teste em Android físico nesta sessão.\n').encode())
        z.writestr('manifesto.json',json.dumps({'version':'0.10.34','base_version':'0.10.33','self_contained':True,'physical_device_tested':False,'apk':{'path':apk_path,'sha256':sha(apk_bytes)},'files':entries},ensure_ascii=False,indent=2))
    with ZipFile(a.output) as z:
        assert len(z.namelist())==len(set(z.namelist())) and z.testzip() is None
        for e in entries:assert len(z.read(e['path']))==e['bytes'] and sha(z.read(e['path']))==e['sha256'],e['path']
    result={'path':str(a.output.resolve()),'bytes':a.output.stat().st_size,'sha256':hashlib.file_digest(a.output.open('rb'),'sha256').hexdigest(),'files':len(entries),'self_contained':True}
    a.output.with_suffix('.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['source','private','reports','output','apk']:p.add_argument('--'+name,type=Path,required=True)
    main(p.parse_args())
