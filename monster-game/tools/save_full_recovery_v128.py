"""Create a self-contained private project backup, with verified file hashes.

Signing identity is private and is never included in a public source tree.
"""
import argparse,hashlib,json
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED

def main(a):
    source=a.source.resolve();files=[]
    with ZipFile(a.output,'w',compression=ZIP_DEFLATED,compresslevel=6) as z:
        for path in sorted(source.rglob('*')):
            if not path.is_file():continue
            rel=path.relative_to(source)
            if any(p in ['.git','__pycache__','editor','shader_cache'] for p in rel.parts):continue
            if path.suffix in ['.tmp','.bak'] or path.name.startswith('.startle.'):continue
            arc='projeto/monster-game/'+rel.as_posix();data=path.read_bytes()
            z.writestr(arc,data);files.append({'path':arc,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        binary=source/'.godot/v128-project.binary';data=binary.read_bytes();arc='projeto/monster-game/project.binary'
        z.writestr(arc,data);files.append({'path':arc,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        for name in ['horda-reconstruida.keystore','password.txt']:
            z.write(a.private/name,'assinatura_privada/'+name)
        z.writestr('assinatura_privada/LEIA-ME.txt','Assinatura privada do próprio projeto. Guarde esta pasta para continuar instalando atualizações. Não publique essa pasta ou este backup no GitHub.\n')
        z.writestr('LEIA-ME.txt','HORDA ZUMBI 0.10.28\n\nProjeto completo e independente do backup anterior. Extraia este ZIP e importe projeto/monster-game/project.godot no Godot 4.5.1. As artes, fontes, áudio, medições, código, importações verificadas, ferramentas e testes estão incluídos.\n\nA atualização parte da 0.10.27 e corrige os oito acessórios solicitados. Leia projeto/monster-game/CORRECAO-v0.10.28.md. A pasta assinatura_privada deve ser guardada apenas com você.\n\nOs testes em Godot e a verificação do APK estão na pasta validacao. Teste em aparelho Android físico ainda pendente.\n')
        for path in sorted(a.reports.glob('v128-*.log')):
            if path.name in ['v128-first-visual.log','v128-detail-items.log','v128-hat-clearance.log']:continue
            z.write(path,'validacao/'+path.name)
        for name in ['v128-validation/items_validation.json','Horda-Zumbi-v0.10.28-ARM64.json','Horda-Zumbi-v0.10.28-Itens-Revisados.png']:
            p=a.reports/name
            if p.exists():z.write(p,'validacao/'+p.name)
        manifest={'version':'0.10.28','base_version':'0.10.27','self_contained':True,'file_count':len(files),'physical_device_tested':False,'files':files}
        z.writestr('manifesto.json',json.dumps(manifest,ensure_ascii=False,indent=2))
        z.writestr('verificar_backup.py',"from pathlib import Path\nimport hashlib,json\nroot=Path(__file__).resolve().parent\nm=json.loads((root/'manifesto.json').read_text())\nfor entry in m['files']:\n p=root/entry['path']\n assert p.stat().st_size==entry['bytes'] and hashlib.sha256(p.read_bytes()).hexdigest()==entry['sha256'],entry['path']\nprint('BACKUP_OK',m['version'],len(m['files']))\n")
    with ZipFile(a.output) as z:
        assert z.testzip() is None
        for entry in files:
            assert hashlib.sha256(z.read(entry['path'])).hexdigest()==entry['sha256'],entry['path']
    print(json.dumps({'output':str(a.output.resolve()),'bytes':a.output.stat().st_size,'files':len(files),'self_contained':True}))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['source','private','reports','output']:p.add_argument('--'+name,type=Path,required=True)
    main(p.parse_args())
