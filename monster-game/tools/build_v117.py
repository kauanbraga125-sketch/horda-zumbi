"""Update only the straw hat on verified v0.10.16 APKs.

Every previous texture, sound and native library remains byte-identical.
The additional straw texture is lossless in both profiles.
"""
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

VERSION = '0.10.17'
CODE = 120
INPUTS = {
    '57c554b25ba2253266127b4c0514998f6ce6f4d8692a2fe09663ac0979c8a9ec',
    '65b6fc2e055273dcf49de409cb3a17d102794a53549b010aad696b06f3acadfd',
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
        new_texture = '.godot/imported/straw-v117-lossless.ctex'
        new_import = 'assets/art/cosmetics_v117/straw.png.import'
        changed = ['scripts/cosmetics.gd', 'assets/art/cosmetics_v113/graphics.json', new_texture, new_import, 'project.binary', 'startup_integrity.json']
        for name in changed:
            path = a.project_binary if name == 'project.binary' else (a.runtime if name == new_texture else a.source) / name
            actual[name] = path.read_bytes()
        audit = json.loads(actual['startup_integrity.json'])
        assert audit['version'] == VERSION and audit['class_count'] == 55
        assert any(x['path'] == 'res://scripts/item_lab.gd' for x in audit['files'])
        assert len(audit['files']) == 99 and any(x['path'] == 'res://' + new_texture for x in audit['files'])
        old_graphics = json.loads(original['assets/art/cosmetics_v113/graphics.json'])
        new_graphics = json.loads(actual['assets/art/cosmetics_v113/graphics.json'])
        assert old_graphics.keys() == new_graphics.keys()
        assert all(old_graphics[k] == new_graphics[k] for k in old_graphics if k != 'z_straw')
        assert original['assets/art/cosmetics_v113/fitting.bin'] == actual['assets/art/cosmetics_v113/fitting.bin']
        for item in audit['files']:
            data = actual[item['path'][6:]]
            assert len(data) == item['bytes'] and sha(data) == item['sha256'], item['path']
        actual['assets.sparsepck'] = build_index({n: b for n, b in actual.items()
                                                if n not in ['_cl_', 'assets.sparsepck']})
        manifest, metadata = patch_manifest(base.read('AndroidManifest.xml'), VERSION, CODE)
        assert metadata['package'] == 'com.kauan.noitedahorda.reconstruida'
        assert metadata['previousVersionCode'] == 119 and metadata['versionCode'] == CODE
        strings, _ = string_pool(manifest, 8)
        assert 'Horda Zumbi R16' in strings
        manifest = bytes(replace_pool_string(bytearray(manifest), 8, strings.index('Horda Zumbi R16'), 'Horda Zumbi R17'))
        a.output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='horda-v117-') as tmp:
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
                media = [n for n in base.namelist() if n.endswith(('.ctex', '.webp', '.png', '.ogg', '.wav', '.pcm', '.so'))]
                assert all(apk.read(n) == base.read(n) for n in media)
                assert set(apk.namelist()) - set(base.namelist()) == {'assets/' + new_texture, 'assets/' + new_import}
                assert all(files[n] == data for n, data in original.items() if n not in changed and n != '_cl_')
            shutil.copyfile(signed, a.output)
    report = dict(version=VERSION, code=CODE, bytes=a.output.stat().st_size, sha256=sha(a.output.read_bytes()), layout=layout, index_entries=count, unchanged_media_entries=len(media), changed=changed, added=[new_texture, new_import], other_graphics_unchanged=34, new_straw_lossless=True, signing_certificate_sha256=certificate, audit_files=len(audit['files']), device_tested=False)
    a.output.with_suffix('.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ['input', 'source', 'runtime', 'output', 'key', 'signer', 'zipalign', 'project-binary']:
        parser.add_argument('--' + name, type=Path, required=True)
    build(parser.parse_args())
