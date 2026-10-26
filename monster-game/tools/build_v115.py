"""Add the item workbench to verified v0.10.14 APKs without changing media."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED, ZIP_STORED
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from apk_format import patch_manifest, replace_pool_string, string_pool, write_entry, verify_android_layout
from sparse_index import build_index, verify_index

VERSION = '0.10.15'
CODE = 118
INPUTS = {
    'a2972e1938cd32e89b1cc7abbf1d627d272c70f8cc6ae9c9f9600fad5e24792c',
    '4ec1c48823b313115f57cf62d06760b2452a05cd9e1dfac187f44441e9034f4d',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def build(a):
    assert sha(a.input.read_bytes()) in INPUTS, 'Unverified input APK'
    with ZipFile(a.input) as base:
        verify_android_layout(base)
        original = {n[7:]: base.read(n) for n in base.namelist()
                    if n.startswith('assets/') and n != 'assets/assets.sparsepck'}
        actual = dict(original)
        changed = ['scripts/game.gd', 'scripts/item_lab.gd', 'project.binary', 'startup_integrity.json']
        for name in changed:
            actual[name] = (a.project_binary if name == 'project.binary' else a.source / name).read_bytes()
        audit = json.loads(actual['startup_integrity.json'])
        assert audit['version'] == VERSION and audit['class_count'] == 55
        assert any(x['path'] == 'res://scripts/item_lab.gd' for x in audit['files'])
        for item in audit['files']:
            data = actual[item['path'][6:]]
            assert len(data) == item['bytes'] and sha(data) == item['sha256'], item['path']
        actual['assets.sparsepck'] = build_index({n: b for n, b in actual.items()
                                                if n not in ['_cl_', 'assets.sparsepck']})
        manifest, metadata = patch_manifest(base.read('AndroidManifest.xml'), VERSION, CODE)
        assert metadata['package'] == 'com.kauan.noitedahorda.reconstruida'
        assert metadata['previousVersionCode'] == 117 and metadata['versionCode'] == CODE
        strings, _ = string_pool(manifest, 8)
        assert 'Horda Zumbi R14' in strings
        manifest = bytes(replace_pool_string(bytearray(manifest), 8, strings.index('Horda Zumbi R14'), 'Horda Zumbi R15'))
        a.output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='horda-v115-') as tmp:
            tmp = Path(tmp)
            unsigned, aligned, signed = [tmp / name for name in ('unsigned.apk', 'aligned.apk', 'signed.apk')]
            with ZipFile(unsigned, 'w', compression=ZIP_DEFLATED, compresslevel=9) as out:
                written = set()
                for info in base.infolist():
                    name = info.filename
                    if name.startswith('META-INF/'):
                        continue
                    data = manifest if name == 'AndroidManifest.xml' else actual[name[7:]] if name.startswith('assets/') else base.read(name)
                    clean = ZipInfo(name, (2026, 10, 23, 0, 0, 0))
                    clean.compress_type = ZIP_STORED if name in ['resources.arsc', 'assets/assets.sparsepck'] else info.compress_type
                    clean._compresslevel = 9
                    write_entry(out, clean, data)
                    written.add(name)
                for name in sorted(actual):
                    full = 'assets/' + name
                    if full in written:
                        continue
                    info = ZipInfo(full, (2026, 10, 23, 0, 0, 0))
                    info.compress_type = ZIP_DEFLATED
                    info._compresslevel = 9
                    write_entry(out, info, actual[name])
            subprocess.run([str(a.zipalign), '-f', '4', str(unsigned), str(aligned)], check=True)
            env = os.environ.copy()
            env['HORDA_REBUILD_KEY_PASSWORD'] = (a.key.parent / 'password.txt').read_text().strip()
            cmd = ['java', '-cp', str(a.signer), 'com.android.apksigner.ApkSignerTool']
            subprocess.run(cmd + ['sign', '--ks', str(a.key), '--ks-key-alias', 'horda-reconstruida', '--ks-pass', 'env:HORDA_REBUILD_KEY_PASSWORD', '--key-pass', 'env:HORDA_REBUILD_KEY_PASSWORD', '--out', str(signed), str(aligned)], env=env, check=True)
            verified = subprocess.run(cmd + ['verify', '--verbose', '--print-certs', '--min-sdk-version', '24', str(signed)], check=True, capture_output=True, text=True)
            certificate = 'a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d'
            assert certificate in verified.stdout, 'Signing identity changed'
            with ZipFile(signed) as apk:
                assert apk.testzip() is None
                layout = verify_android_layout(apk)
                files = {n[7:]: apk.read(n) for n in apk.namelist() if n.startswith('assets/') and n not in ['assets/assets.sparsepck', 'assets/_cl_']}
                count = verify_index(apk.read('assets/assets.sparsepck'), files)
                media = [n for n in apk.namelist() if n.endswith(('.ctex', '.webp', '.png', '.ogg', '.wav', '.pcm', '.so'))]
                assert all(apk.read(n) == base.read(n) for n in media)
                assert all(files[n] == data for n, data in original.items() if n not in changed and n != '_cl_')
            shutil.copyfile(signed, a.output)
    report = dict(version=VERSION, code=CODE, bytes=a.output.stat().st_size, sha256=sha(a.output.read_bytes()), layout=layout, index_entries=count, unchanged_media_entries=len(media), changed=changed, added=['scripts/item_lab.gd'], signing_certificate_sha256=certificate, audit_files=len(audit['files']), device_tested=False)
    a.output.with_suffix('.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ['input', 'source', 'output', 'key', 'signer', 'zipalign', 'project-binary']:
        parser.add_argument('--' + name, type=Path, required=True)
    build(parser.parse_args())
