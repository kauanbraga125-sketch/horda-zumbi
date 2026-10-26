"""Preserve the exact 0.10.30 working project, signed APK and private identity."""
import argparse,hashlib,json
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED

def main(a):
    source=a.source.resolve();entries=[];a.output.parent.mkdir(parents=True,exist_ok=True)
    with ZipFile(a.output,'w',ZIP_DEFLATED,compresslevel=6) as z:
        def add(name,data):
            z.writestr(name,data);entries.append({'path':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        for p in sorted(source.rglob('*')):
            if not p.is_file():continue
            rel=p.relative_to(source)
            if any(v in ['.git','__pycache__','editor','shader_cache'] for v in rel.parts):continue
            if p.name in ['project.binary','export_credentials.cfg'] or p.suffix in ['.tmp','.bak','.pyc']:continue
            add('projeto/monster-game/'+rel.as_posix(),p.read_bytes())
        add('aplicativo/'+a.apk.name,a.apk.read_bytes())
        for name in ['horda-reconstruida.keystore','password.txt']:add('assinatura_privada/'+name,(a.private/name).read_bytes())
        z.writestr('assinatura_privada/LEIA-ME.txt','Identidade privada para continuar atualizando o próprio aplicativo. Não publique esta pasta ou este backup privado no GitHub.\n')
        for p in sorted(a.reports.rglob('*')):
            if not p.is_file() or p.suffix not in ['.log','.json','.png']:continue
            rel=p.relative_to(a.reports)
            if len(rel.parts)>2 or not (p.name.startswith(('v130-','source-space','ground-v130','ground-v129')) or rel.parts[0] in ['packaged-space','packaged-space-visual','source-space']):continue
            add('validacao/'+rel.as_posix(),p.read_bytes())
        if a.apk.with_suffix('.json').exists():add('validacao/'+a.apk.with_suffix('.json').name,a.apk.with_suffix('.json').read_bytes())
        z.writestr('LEIA-ME.txt','HORDA ZUMBI 0.10.30 — recuperação completa\n\nContém o APK assinado, projeto completo, importações verificadas, artes originais, novos sprites, áudio, código, ferramentas, testes e identidade privada.\n\nAbra projeto/monster-game/project.godot no Godot 4.5.1. A configuração binária atual está em .godot/v130-project.binary. Não copie project.binary antigo para a raiz: ele sobrepõe project.godot. Após editar ou reimportar, execute tools/refresh_startup_integrity.py. O preset Android corresponde à 0.10.30 (código 133).\n\nA pasta aplicativo contém a entrega atual. assinatura_privada preserva a identidade instalada e deve ficar privada. Execute verificar_backup.py para conferir o conteúdo. Não houve teste em Android físico.\n')
        z.writestr('manifesto.json',json.dumps({'version':'0.10.30','base_version':'0.10.29','self_contained':True,'includes_current_apk':True,'physical_device_tested':False,'files':entries},indent=2))
        z.writestr('verificar_backup.py',"from pathlib import Path\nimport hashlib,json\nr=Path(__file__).resolve().parent\nm=json.loads((r/'manifesto.json').read_text())\nfor e in m['files']:\n p=r/e['path']\n assert p.stat().st_size==e['bytes'] and hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==e['sha256'],e['path']\nprint('BACKUP_OK',m['version'],len(m['files']))\n")
    with ZipFile(a.output) as z:
        assert len(z.namelist())==len(set(z.namelist())) and z.testzip() is None
        for e in entries:assert hashlib.sha256(z.read(e['path'])).hexdigest()==e['sha256'],e['path']
    report={'path':str(a.output.resolve()),'bytes':a.output.stat().st_size,'sha256':hashlib.file_digest(a.output.open('rb'),'sha256').hexdigest(),'files':len(entries),'self_contained':True,'includes_current_apk':True}
    a.output.with_suffix('.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['source','private','reports','output','apk']:p.add_argument('--'+name,type=Path,required=True)
    main(p.parse_args())
