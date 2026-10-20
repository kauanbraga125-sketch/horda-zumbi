"""Rebuild 0.9.2 with a fresh sparse index, plain scripts and aligned assets.

Native libraries, art, audio, package identity and signing key stay unchanged.
The export ZIP must come from Godot 4.5.1 with script_export_mode=0.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from zipfile import ZipFile, ZipInfo, ZIP_STORED

from apk_format import patch_manifest, replace_pool_string, string_pool, write_entry
from sparse_index import build_index, verify_index


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', required=True, type=Path)
    parser.add_argument('--resources', required=True, type=Path)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--signing-zip', required=True, type=Path)
    parser.add_argument('--signer-jar', required=True, type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    unsigned = args.output.with_name(args.output.stem + '-unsigned.apk')
    overlays = {}
    with ZipFile(args.resources) as exported:
        assert not any(n.endswith('.gdc') for n in exported.namelist()), 'Compressed/binary scripts must not be exported'
        for name in exported.namelist():
            if name.startswith('scripts/') and name.endswith('.gd'):
                data = exported.read(name)
                assert data == (args.source / name).read_bytes(), 'Source was unexpectedly transformed: ' + name
                data.decode('utf-8')
                overlays['assets/' + name] = data
        expected_scripts = {'assets/scripts/' + p.name for p in (args.source / 'scripts').glob('*.gd')}
        assert set(overlays) == expected_scripts, 'The export must include every source script'
        assert 'assets/scripts/boot_audit.gd' in overlays
        script_count = len(overlays)
        for name in ['.godot/global_script_class_cache.cfg', 'project.binary']:
            overlays['assets/' + name] = exported.read(name)
    for name in ['main.tscn', 'boot.tscn']:
        overlays['assets/' + name] = (args.source / name).read_bytes()
    assert overlays['assets/.godot/global_script_class_cache.cfg'] == (args.source / '.godot/global_script_class_cache.cfg').read_bytes()
    # Generate the integrity manifest from the final bytes too. Neither index
    # may be carried forward blindly when a source or asset changes.
    startup_paths = ['assets/.godot/global_script_class_cache.cfg', 'assets/boot.tscn', 'assets/main.tscn']
    startup_paths += sorted(n for n in overlays if n.endswith('.gd'))
    integrity = {'version': '0.9.3',
                 'class_count': len(re.findall(rb'"class":', overlays['assets/.godot/global_script_class_cache.cfg'])),
                 'files': [{'path': 'res://' + n[7:], 'bytes': len(overlays[n]),
                            'sha256': hashlib.sha256(overlays[n]).hexdigest()} for n in startup_paths]}
    overlays['assets/startup_integrity.json'] = json.dumps(integrity, ensure_ascii=False, indent=2).encode('utf-8')
    removed = []
    sparse_files = {}
    with ZipFile(args.base) as base, ZipFile(unsigned, 'w') as out:
        manifest, version = patch_manifest(base.read('AndroidManifest.xml'), '0.9.3', 93)
        strings, _ = string_pool(manifest, 8)
        assert 'Horda Zumbi 0.9.2' in strings
        manifest = bytes(replace_pool_string(bytearray(manifest), 8, strings.index('Horda Zumbi 0.9.2'), 'Horda Zumbi 0.9.3'))
        for info in base.infolist():
            name = info.filename
            if name.startswith('META-INF/') and (name.endswith(('.RSA', '.SF', '.DSA', '.EC')) or name == 'META-INF/MANIFEST.MF'):
                continue
            if name.startswith('assets/') and (name.endswith('.gdc') or name.endswith('.gd.remap') or name == 'assets/main.tscn.remap'):
                removed.append(name)
                continue
            if name in overlays:
                continue
            if name == 'assets/assets.sparsepck':
                continue
            data = manifest if name == 'AndroidManifest.xml' else base.read(info)
            # Keep startup code/configuration easy to map and audit. The root
            # correction is the sparse directory regenerated below; the old
            # directory truncated otherwise-valid ZIP assets and GDScript.
            if name.startswith('assets/') and (name.endswith(('.gd', '.cfg', '.json', '.import', '.binary', '.tscn', '.scn', '.remap')) or name == 'assets/_cl_'):
                info.compress_type = ZIP_STORED
            write_entry(out, info, data)
            if name.startswith('assets/') and name != 'assets/_cl_':
                sparse_files[name[7:]] = data
        for name, data in sorted(overlays.items()):
            info = ZipInfo(name, (2026, 10, 19, 0, 0, 0))
            info.compress_type = ZIP_STORED
            write_entry(out, info, data)
            sparse_files[name[7:]] = data
        index = build_index(sparse_files)
        info = ZipInfo('assets/assets.sparsepck', (2026, 10, 19, 0, 0, 0))
        info.compress_type = ZIP_STORED
        write_entry(out, info, index)
    signing = args.output.parent.parent / 'private-signing'
    signing.mkdir(mode=0o700, exist_ok=True)
    with ZipFile(args.signing_zip) as package:
        package.extractall(signing)
        instructions = package.read('LEIA-ME.txt').decode('utf-8')
    password = re.search(r'^Senha[^:]*:\s*(.+)$', instructions, re.M).group(1).strip()
    alias = re.search(r'^Alias:\s*(.+)$', instructions, re.M).group(1).strip()
    env = os.environ.copy()
    env['HORDA_SIGNING_PASSWORD'] = password
    command = ['java', '-cp', str(args.signer_jar), 'com.android.apksigner.ApkSignerTool']
    subprocess.run(command + ['sign', '--ks', str(signing / 'playtest091.keystore'), '--ks-key-alias', alias,
                             '--ks-pass', 'env:HORDA_SIGNING_PASSWORD', '--key-pass', 'env:HORDA_SIGNING_PASSWORD',
                             '--out', str(args.output), str(unsigned)], env=env, check=True)
    subprocess.run(command + ['verify', '--verbose', str(args.output)], check=True)
    with ZipFile(args.output) as apk:
        assert apk.testzip() is None
        assert not any(n.endswith(('.gdc', '.gd.remap')) for n in apk.namelist())
        assert len(apk.namelist()) == len(set(apk.namelist()))
        actual_files = {n[7:]: apk.read(n) for n in apk.namelist()
                        if n.startswith('assets/') and not n.endswith('/')
                        and n not in ['assets/assets.sparsepck', 'assets/_cl_']}
        index_entries = verify_index(apk.read('assets/assets.sparsepck'), actual_files)
    print(json.dumps({'apk': str(args.output), 'bytes': args.output.stat().st_size,
                      'sha256': hashlib.file_digest(args.output.open('rb'), 'sha256').hexdigest(),
                      'plain_scripts': script_count, 'sparse_index_verified_entries': index_entries,
                      'removed_binary_scripts_and_remaps': len(removed), **version}))


if __name__ == '__main__':
    main()
