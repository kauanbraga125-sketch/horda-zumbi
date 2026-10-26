"""Build a signed v0.10.27 update directly from either verified v0.10.26 APK.

All previous images, audio, fonts and Android/Godot binaries stay identical.
Nine accessories receive corrected art, attachment fits, atlas bounds and layers. Signing material stays private.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED, ZIP_STORED

from apk_format import patch_manifest, replace_pool_string, string_pool, write_entry, verify_android_layout
from sparse_index import build_index, verify_index

VERSION = '0.10.27'
CODE = 130
INPUTS = {
    '998d0ce67f55d75b24d3c040b793f4e3d5cb00b862e6a7976798bb3c2cdae031',
    'ca9d897f16f62573b9cbf36f3f56910541cf56d2b721fd105e8f26745a174f7e',
}
CHANGED_ITEMS = ['z_scientist','z_vampire','z_scarf','z_chain','s_chaos','s_north','s_wizard','s_striped','s_ice']
CERTIFICATE = 'a641a59f39561af0210f2f1cd246f58c5bfd9ab05462bf5b0635e626d681d15d'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def build(a):
    assert sha(a.input.read_bytes()) in INPUTS, 'Unverified base APK'
    changed = ['project.godot', 'scripts/cosmetics.gd', 'assets/art/cosmetics_v113/graphics.json',
               'assets/art/cosmetics_v127/layers.bin', 'assets/art/cosmetics_v127/skull.json',
               *['assets/art/cosmetics_v127/'+n+'.png.import' for n in ['scientist','cape','scarf','chain','skull']],
               *['.godot/imported/'+n+'-v127-lossless.ctex' for n in ['scientist','cape','scarf','chain','skull']],
               'project.binary', 'startup_integrity.json']
    with ZipFile(a.input) as base:
        verify_android_layout(base)
        original = {n[7:]: base.read(n) for n in base.namelist() if n.startswith('assets/') and n != 'assets/assets.sparsepck'}
        actual = dict(original)
        for name in changed:
            actual[name] = (a.project_binary if name == 'project.binary' else a.source / name).read_bytes()
        old_graphics = json.loads(original['assets/art/cosmetics_v113/graphics.json'])
        new_graphics = json.loads(actual['assets/art/cosmetics_v113/graphics.json'])
        assert old_graphics.keys() == new_graphics.keys()
        assert all(new_graphics[k] == v for k, v in old_graphics.items() if k not in CHANGED_ITEMS)
        assert len(old_graphics) - len(CHANGED_ITEMS) == 26
        assert (a.source / 'assets/art/cosmetics_v113/fitting.bin').read_bytes() == original['assets/art/cosmetics_v113/fitting.bin']
        audit = json.loads(actual['startup_integrity.json'])
        assert audit['version'] == VERSION and audit['class_count'] == 55 and len(audit['files']) == 143
        assert any(x['path'] == 'res://assets/art/cosmetics_v127/scientist.png.import' for x in audit['files'])
        for item in audit['files']:
            data = actual[item['path'][6:]]
            assert len(data) == item['bytes'] and sha(data) == item['sha256'], item['path']
        for name, data in original.items():
            if name.startswith('scripts/'):
                assert (a.source / name).read_bytes() == actual[name], 'Recovery source differs from APK: ' + name
        actual['assets.sparsepck'] = build_index({n: data for n, data in actual.items() if n not in ['_cl_', 'assets.sparsepck']})
        manifest, metadata = patch_manifest(base.read('AndroidManifest.xml'), VERSION, CODE)
        assert metadata['package'] == 'com.kauan.noitedahorda.reconstruida'
        assert metadata['previousVersionCode'] == 129 and metadata['versionCode'] == CODE
        strings, _ = string_pool(manifest, 8)
        manifest = bytes(replace_pool_string(bytearray(manifest), 8, strings.index('Horda Zumbi R26'), 'Horda Zumbi R27'))
        a.output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='horda-v127-') as tmp:
            tmp = Path(tmp)
            unsigned, aligned, signed = [tmp / name for name in ['unsigned.apk', 'aligned.apk', 'signed.apk']]
            with ZipFile(unsigned, 'w', compression=ZIP_DEFLATED, compresslevel=9) as out:
                written = set()
                for info in base.infolist():
                    name = info.filename
                    if name.startswith('META-INF/'):
                        continue
                    data = manifest if name == 'AndroidManifest.xml' else actual[name[7:]] if name.startswith('assets/') else base.read(name)
                    clean = ZipInfo(name, (2026, 10, 24, 0, 0, 0))
                    clean.compress_type = ZIP_STORED if name in ['resources.arsc', 'assets/assets.sparsepck'] else info.compress_type
                    clean._compresslevel = 9
                    write_entry(out, clean, data)
                    written.add(name)
                for name in sorted(actual):
                    if 'assets/' + name in written:
                        continue
                    info = ZipInfo('assets/' + name, (2026, 10, 24, 0, 0, 0))
                    info.compress_type = ZIP_DEFLATED
                    info._compresslevel = 9
                    write_entry(out, info, actual[name])
            subprocess.run([str(a.zipalign), '-f', '4', str(unsigned), str(aligned)], check=True)
            env = os.environ.copy()
            env['HORDA_REBUILD_KEY_PASSWORD'] = (a.key.parent / 'password.txt').read_text().strip()
            classpath = str(a.signer)
            if (a.signer.parent / 'apksig.jar').exists():
                classpath += os.pathsep + str(a.signer.parent / 'apksig.jar')
            signer = ['java', '-cp', classpath, 'com.android.apksigner.ApkSignerTool']
            subprocess.run(signer + ['sign', '--ks', str(a.key), '--ks-key-alias', 'horda-reconstruida', '--ks-pass', 'env:HORDA_REBUILD_KEY_PASSWORD', '--key-pass', 'env:HORDA_REBUILD_KEY_PASSWORD', '--out', str(signed), str(aligned)], env=env, check=True)
            verified = subprocess.run(signer + ['verify', '--verbose', '--print-certs', '--min-sdk-version', '24', str(signed)], check=True, capture_output=True, text=True)
            assert CERTIFICATE in verified.stdout, 'Signing identity changed'
            with ZipFile(signed) as apk:
                assert apk.testzip() is None
                layout = verify_android_layout(apk)
                files = {n[7:]: apk.read(n) for n in apk.namelist() if n.startswith('assets/') and n not in ['assets/assets.sparsepck', 'assets/_cl_']}
                entries = verify_index(apk.read('assets/assets.sparsepck'), files)
                media = [n for n in base.namelist() if n.endswith(('.ctex', '.webp', '.png', '.ogg', '.wav', '.pcm', '.so', '.ttf', '.otf'))]
                assert all(apk.read(n) == base.read(n) for n in media), 'An existing media asset changed'
                assert set(apk.namelist()) - set(base.namelist()) == {'assets/' + name for name in changed if name not in original}
                assert all(files[n] == data for n, data in original.items() if n not in changed and n != '_cl_')
            shutil.copyfile(signed, a.output)
    report = dict(version=VERSION, code=CODE, package=metadata['package'], bytes=a.output.stat().st_size,
                  sha256=sha(a.output.read_bytes()), layout=layout, index_entries=entries,
                  previous_media_entries_preserved=len(media), changed=changed, other_accessories_preserved=26,
                  original_fitting_unchanged=True, original_character_pngs_changed=0, new_accessory_textures=5, signing_certificate_sha256=CERTIFICATE,
                  source_matches_shipped_scripts=True, audit_files=len(audit['files']), physical_device_tested=False)
    a.output.with_suffix('.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ['input', 'source', 'output', 'key', 'signer', 'zipalign', 'project-binary']:
        parser.add_argument('--' + name, type=Path, required=True)
    build(parser.parse_args())
