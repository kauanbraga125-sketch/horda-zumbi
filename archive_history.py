"""Archive the existing public repository; this script never changes its branches."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

REPO = 'kauanbraga125-sketch/horda-zumbi'
TAG = 'history-backup-20261021'
EXPECTED = {
    'refs/heads/main': 'f7bebdd9b8cf8d81cf4e0f28ebfb16dcfccfc720',
    'refs/heads/backup/v0.10.2-recuperada-20261020': '5227bf59805b107ffbd2071ed125c63d4e4cf36d',
    'refs/heads/publish/v0.10.3': 'ad43f764c73744c4072455fcc279727595ef46be',
}


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def output(*args):
    return subprocess.check_output(args, text=True)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b''):
            h.update(chunk)
    return 'sha256:' + h.hexdigest()


def main():
    assert os.environ['GITHUB_REPOSITORY'] == REPO
    assert os.environ['GITHUB_REF'] == 'refs/heads/maintenance/archive-history-20261021'
    existing = subprocess.run(['gh', 'release', 'view', TAG, '--repo', REPO],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if existing.returncode == 0:
        raise SystemExit('Archive already exists; inspect it before creating another copy.')
    root = Path(os.environ['RUNNER_TEMP']) / 'horda-history-archive'
    root.mkdir(exist_ok=False)
    mirror = root / 'snapshot.git'
    run('git', 'clone', '--mirror', 'https://github.com/' + REPO + '.git', str(mirror))
    run('git', '-C', str(mirror), 'fsck', '--full', '--strict')
    refs = {ref: sha for sha, ref in
            (line.split() for line in output('git', '-C', str(mirror), 'show-ref').splitlines())}
    for ref, sha in EXPECTED.items():
        assert refs.get(ref) == sha, 'The audited reference changed: ' + ref
    manifest = root / 'refs-before-cleanup.json'
    manifest.write_text(json.dumps({'repository': REPO, 'refs': refs,
        'commits': int(output('git', '-C', str(mirror), 'rev-list', '--all', '--count'))}, indent=2) + '\n')
    bundle = root / 'Horda-Zumbi-Historico-Completo-20261021.bundle'
    run('git', '-C', str(mirror), 'bundle', 'create', str(bundle), '--all')
    run('git', '-C', str(mirror), 'bundle', 'verify', str(bundle))
    restored = root / 'restore-test.git'
    run('git', 'clone', '--mirror', str(bundle), str(restored))
    run('git', '-C', str(restored), 'fsck', '--full', '--strict')
    assert output('git', '-C', str(restored), 'show-ref') == output('git', '-C', str(mirror), 'show-ref')
    sums = root / 'SHA256SUMS.txt'
    sums.write_text(''.join(digest(p).removeprefix('sha256:') + '  ' + p.name + '\n'
                            for p in [bundle, manifest]))
    files = [bundle, manifest, sums]
    notes = root / 'NOTAS.md'
    notes.write_text('Cópia integral do histórico público antes da limpeza de backups redundantes. '
        'Todos os commits e referências estão no arquivo .bundle, com teste de restauração e SHA-256. '
        'Este arquivo de manutenção não substitui a versão jogável e não altera a main.\n')
    run('gh', 'release', 'create', TAG, *(str(p) for p in files), '--repo', REPO,
        '--target', os.environ['GITHUB_SHA'], '--title', 'Backup do histórico antes da limpeza — 21/10/2026',
        '--notes-file', str(notes), '--prerelease', '--latest=false')
    release = json.loads(output('gh', 'api', 'repos/' + REPO + '/releases/tags/' + TAG))
    assets = {a['name']: a for a in release['assets']}
    for path in files:
        asset = assets[path.name]
        assert asset['size'] == path.stat().st_size
        if asset.get('digest'):
            assert asset['digest'] == digest(path), 'Uploaded digest mismatch: ' + path.name
        else:
            downloaded = root / 'downloaded'
            downloaded.mkdir(exist_ok=True)
            run('gh', 'release', 'download', TAG, '--repo', REPO, '--pattern', path.name,
                '--dir', str(downloaded))
            assert digest(downloaded / path.name) == digest(path)
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as f:
        f.write('Backup integral verificado e preservado em ' + release['html_url'] + '\n\n')
        f.write(str(len(refs)) + ' referências; ' + str(bundle.stat().st_size) + ' bytes.\n')
    print('HORDA_HISTORY_BACKUP_VERIFIED ' + release['html_url'])


if __name__ == '__main__':
    main()
