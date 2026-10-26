"""Preserve the exact working project, current signed APK and private identity."""
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
        add('projeto/monster-game/project.binary',(source/'.godot/v129-project.binary').read_bytes())
        add('aplicativo/'+a.apk.name,a.apk.read_bytes())
        for name in ['horda-reconstruida.keystore','password.txt']:add('assinatura_privada/'+name,(a.private/name).read_bytes())
        z.writestr('assinatura_privada/LEIA-ME.txt','Identidade privada para continuar atualizando o próprio aplicativo. Não publique esta pasta ou este backup privado no GitHub.\n')
        for p in sorted(a.reports.glob('*.log')):
            if p.name in ['build.log','collection.log','currency.log','transform.log','final_checked.log','packaged_boot.log','packaged_lab.log','details_final.log','visual.log']:add('validacao/'+p.name,p.read_bytes())
        for rel in ['final_checked/all_items_validation.json','lab/item_lab_validation.json','packaged_lab/item_lab_validation.json','visual/Sete-Itens-Revisados.png']:
            p=a.reports/rel
            if p.exists():add('validacao/'+rel,p.read_bytes())
        for p in sorted((a.reports/'visual').glob('*.png')):
            if p.name!='Sete-Itens-Revisados.png':add('validacao/animacoes/'+p.name,p.read_bytes())
        for p in sorted((a.reports/'packaged_lab').glob('*.png')):add('validacao/bancada/'+p.name,p.read_bytes())
        if a.apk.with_suffix('.json').exists():add('validacao/'+a.apk.with_suffix('.json').name,a.apk.with_suffix('.json').read_bytes())
        z.writestr('LEIA-ME.txt','HORDA ZUMBI 0.10.29 — recuperação completa\n\nContém o APK assinado, o projeto completo, importações verificadas, PNGs originais, novas artes, áudio, fontes, medições, código, ferramentas, testes e identidade privada de assinatura.\n\nImporte projeto/monster-game/project.godot com Godot 4.5.1. Para usar o projeto com novos imports, rode tools/refresh_startup_integrity.py depois de importar. O preset Android corresponde à 0.10.29 (código 132).\n\nA pasta aplicativo contém a entrega atual e serve como base para a próxima atualização. A pasta assinatura_privada permite preservar a identidade instalada. Este ZIP é privado; o GitHub contém uma cópia pública completa sem a chave.\n\nExecute verificar_backup.py para conferir todos os arquivos. Instalação em Android físico ainda deve ser testada pelo proprietário.\n')
        z.writestr('manifesto.json',json.dumps({'version':'0.10.29','base_version':'0.10.28','self_contained':True,'includes_current_apk':True,'physical_device_tested':False,'files':entries},indent=2))
        z.writestr('verificar_backup.py',"from pathlib import Path\nimport hashlib,json\nr=Path(__file__).resolve().parent\nm=json.loads((r/'manifesto.json').read_text())\nfor e in m['files']:\n p=r/e['path']\n assert p.stat().st_size==e['bytes'] and hashlib.file_digest(p.open('rb'),'sha256').hexdigest()==e['sha256'],e['path']\nprint('BACKUP_OK',m['version'],len(m['files']))\n")
    with ZipFile(a.output) as z:
        assert len(z.namelist())==len(set(z.namelist())) and z.testzip() is None
        for e in entries:assert hashlib.sha256(z.read(e['path'])).hexdigest()==e['sha256'],e['path']
    print(json.dumps({'path':str(a.output.resolve()),'bytes':a.output.stat().st_size,'files':len(entries),'self_contained':True,'includes_current_apk':True}))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['source','private','reports','output','apk']:p.add_argument('--'+name,type=Path,required=True)
    main(p.parse_args())
