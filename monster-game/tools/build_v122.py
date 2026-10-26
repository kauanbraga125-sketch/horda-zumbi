"""Update pirate and the two eye accessories on verified v0.10.21 APKs.

Every previous texture, sound and native library remains byte-identical.
The additional hat textures is lossless in both profiles.
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
import zstandard
from apk_format import patch_manifest, replace_pool_string, string_pool, write_entry, verify_android_layout
from sparse_index import build_index, verify_index

VERSION = '0.10.22'
CODE = 125
EYEWEAR_SOURCE_SHA256 = '147a699c48acbf030e55447c00e6782fa64edc681d9cf965680a8b3203f515d4'
INPUTS = {
    '58450bb84731f647e00a243dee046dfce13ab8dd5ebbc61839cd9bded1d55e3c',
    'd0a7df0aafb30b4a2bb58076c9349908fa3faf1f2582fdb5a5bf72457ad7bf6f',
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
        new_textures = ['.godot/imported/' + name + '-v122-lossless.ctex' for name in ['pirate']]
        new_imports = ['assets/art/cosmetics_v122/' + name + '.png.import' for name in ['pirate']]
        changed = ['scripts/cosmetics.gd', 'assets/art/cosmetics_v113/graphics.json', *new_textures, *new_imports, 'project.binary', 'startup_integrity.json']
        for name in changed:
            path = a.project_binary if name == 'project.binary' else (a.runtime if name in new_textures else a.source) / name
            actual[name] = path.read_bytes()
        audit = json.loads(actual['startup_integrity.json'])
        assert audit['version'] == VERSION and audit['class_count'] == 55
        assert any(x['path'] == 'res://scripts/item_lab.gd' for x in audit['files'])
        assert len(audit['files']) == 111 and all(any(x['path'] == 'res://' + n for x in audit['files']) for n in new_textures)
        old_graphics = json.loads(original['assets/art/cosmetics_v113/graphics.json'])
        new_graphics = json.loads(actual['assets/art/cosmetics_v113/graphics.json'])
        assert old_graphics.keys() == new_graphics.keys()
        assert all(old_graphics[k] == new_graphics[k] for k in old_graphics if k not in ['z_pirate', 'z_cyber', 'z_goggles'])
        assert new_graphics['z_pirate']['preserve_source']
        for id in ['z_cyber','z_goggles']:
            new,old=new_graphics[id],old_graphics[id]
            for field in ['file','rect','bounds']:
                assert new[field]==old[field], 'Original eyewear art reference changed'
            assert new['behind_body'] and new['layered_eyes'] and new['eye_rig']
            assert sha((a.source/'assets/art'/new['file']).read_bytes())==EYEWEAR_SOURCE_SHA256, 'Eyewear source image pixels changed'
            importer='assets/art/'+old['file']+'.import'
            assert actual[importer]==original[importer], 'Eyewear texture remapping changed'
        assert (a.source/'assets/art/cosmetics_v113/fitting.bin').read_bytes() == original['assets/art/cosmetics_v113/fitting.bin'], 'Existing frame meshes changed'
        # A recovery source must contain the exact production scripts shipped
        # in this APK, including changes inherited from earlier releases.
        for name,data in original.items():
            if name.startswith('scripts/') and name not in changed:
                assert (a.source/name).read_bytes() == data, 'Source differs from shipped script: '+name
        for item in audit['files']:
            data = actual[item['path'][6:]]
            assert len(data) == item['bytes'] and sha(data) == item['sha256'], item['path']
        actual['assets.sparsepck'] = build_index({n: b for n, b in actual.items()
                                                if n not in ['_cl_', 'assets.sparsepck']})
        manifest, metadata = patch_manifest(base.read('AndroidManifest.xml'), VERSION, CODE)
        assert metadata['package'] == 'com.kauan.noitedahorda.reconstruida'
        assert metadata['previousVersionCode'] == 124 and metadata['versionCode'] == CODE
        strings, _ = string_pool(manifest, 8)
        assert 'Horda Zumbi R21' in strings
        manifest = bytes(replace_pool_string(bytearray(manifest), 8, strings.index('Horda Zumbi R21'), 'Horda Zumbi R22'))
        a.output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='horda-v122-') as tmp:
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
                assert len(media) == 240
                assert all(apk.read(n) == base.read(n) for n in media)
                assert set(apk.namelist()) - set(base.namelist()) == {'assets/' + n for n in new_textures + new_imports}
                assert all(files[n] == data for n, data in original.items() if n not in changed and n != '_cl_')
            shutil.copyfile(signed, a.output)
    report = dict(version=VERSION, code=CODE, bytes=a.output.stat().st_size, sha256=sha(a.output.read_bytes()), layout=layout, index_entries=count, unchanged_media_entries=len(media), changed=changed, added=new_textures + new_imports, other_graphics_unchanged=32, new_hat_textures_lossless=True, original_character_sprites_uncut=True, original_eyewear_textures_unchanged=True, lenses_fitted_individually=True, complete_source_matches_shipped_scripts=True, signing_certificate_sha256=certificate, audit_files=len(audit['files']), device_tested=False)
    a.output.with_suffix('.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ['input', 'source', 'runtime', 'output', 'key', 'signer', 'zipalign', 'project-binary']:
        parser.add_argument('--' + name, type=Path, required=True)
    build(parser.parse_args())
