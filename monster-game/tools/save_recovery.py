"""Preserve the full source delta, private signing identity and release evidence.

The resulting recovery archive is private. Never commit it to a public repo.
Restore requires the public base commit or a local copy of that base.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from zipfile import ZipFile, ZIP_DEFLATED

BASE = 'f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720'


def main(a):
    repo = a.repo.resolve()
    def git(*args):
        return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()
    paths = set(git('diff', '--name-only', '--diff-filter=ACMRT', BASE).splitlines())
    paths.update(git('ls-files', '--others', '--exclude-standard').splitlines())
    paths.discard('')
    files = []
    for name in sorted(paths):
        data = (repo / name).read_bytes()
        files.append({'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    deleted = git('diff', '--name-only', '--diff-filter=D', BASE).splitlines()
    manifest = dict(version=a.version, status='complete', base_commit=BASE,
                    source_commit=git('rev-parse', 'HEAD'),
                    source_uncommitted=bool(git('status', '--porcelain')),
                    repository='https://github.com/kauanbraga125-sketch/horda-zumbi',
                    files=files, deleted=deleted,
                    installation_test_on_phone=False,
                    restore_requires_public_base_or_local_base=True)
    custom_restore = repo / 'monster-game/tools/restore_v127.py'
    if a.version == '0.10.27' and custom_restore.exists():
        restore = custom_restore.read_bytes()
    else:
        with ZipFile(a.previous) as previous:
            restore = previous.read('restaurar_projeto.py')
    a.output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(a.output, 'w', compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for item in files: archive.write(repo / item['path'], 'alteracoes/' + item['path'])
        archive.writestr('manifesto.json', json.dumps(manifest, ensure_ascii=False, indent=2))
        archive.writestr('restaurar_projeto.py', restore)
        for name in ['horda-reconstruida.keystore', 'password.txt']:
            archive.write(a.private / name, 'assinatura_privada/' + name)
        archive.writestr('assinatura_privada/LEIA-ME.txt', 'Assinatura privada da versão reconstruída. Guarde esta pasta; não publique no GitHub.\n')
        archive.write(a.runtime, 'compilacao/project.binary')
        for extra in a.extra_runtime:
            archive.write(extra, 'compilacao/' + extra.name)
        archive.writestr('LEIA-ME.txt', f'''HORDA ZUMBI {a.version} — BANCADA DE ITENS

Backup final do código, arte reconstruída, encaixes, testes e assinatura, incluindo todas as alterações anteriores sobre a base pública. Os APKs e backups das versões anteriores continuam separados.

Extraia e execute restaurar_projeto.py com Python 3.9 ou posterior. Ele baixa a base pública no commit exato e aplica as alterações verificadas. Se já tiver a base, use --base-dir PASTA. Este ZIP depende dessa base pública ou de uma cópia local.

Leia alteracoes/monster-game/{a.notes} para detalhes desta revisão. O arquivo compilacao/project.binary é a configuração compilada dos APKs. A assinatura fica em assinatura_privada, fora do projeto. Não publique essa pasta.

A bancada, coleção, movimentação, integridade e inicialização do APK foram verificadas automaticamente. Teste em aparelho físico pendente.
''')
        for path in sorted(a.reports.glob(a.report_prefix + '-*')):
            if path.is_file() and path.suffix in ['.json', '.log'] and 'library' not in path.name:
                archive.write(path, 'validacao/' + path.name)
            elif path.is_dir():
                for item in sorted(path.rglob('*')):
                    if item.is_file(): archive.write(item, 'validacao/' + item.relative_to(a.reports).as_posix())
        for path in sorted(a.output.parent.glob('Horda-Zumbi-v' + a.version + '*.json')):
            archive.write(path, 'validacao/' + path.name)
    with ZipFile(a.output) as archive:
        assert archive.testzip() is None
        for item in files:
            assert hashlib.sha256(archive.read('alteracoes/' + item['path'])).hexdigest() == item['sha256']
    print(json.dumps(dict(output=str(a.output), version=a.version, files=len(files),
                          bytes=a.output.stat().st_size, source_commit=manifest['source_commit'],
                          source_uncommitted=manifest['source_uncommitted'])))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ['repo', 'private', 'runtime', 'previous', 'reports', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--report-prefix', default='v115')
    parser.add_argument('--notes', default='BANCADA-v0.10.15.md')
    parser.add_argument('--extra-runtime', type=Path, action='append', default=[])
    main(parser.parse_args())
