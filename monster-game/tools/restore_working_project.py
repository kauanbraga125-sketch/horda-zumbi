"""Recreate the preserved runtime assets plus the corrected editable sources.

Requires the original 0.9.2 APK and this correction bundle. Never overwrites
an existing project directory. Godot 4.5.1 then regenerates editor metadata.
"""
import argparse
from pathlib import Path
from zipfile import ZipFile


def safe_write(root, name, data):
    target = (root / name).resolve()
    assert target.is_relative_to(root.resolve())
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base-apk', type=Path, required=True)
    parser.add_argument('--correction-zip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists() and any(args.output.iterdir()):
        raise ValueError('Output must be a new or empty folder; the original project is preserved')
    args.output.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.base_apk) as base:
        for entry in base.infolist():
            if not entry.filename.startswith('assets/') or entry.is_dir(): continue
            name = entry.filename[7:]
            if name.endswith(('.gdc', '.gd.remap')): continue
            if name in ['assets.sparsepck', 'project.binary', '_cl_', 'main.tscn.remap']: continue
            if name.startswith('.godot/') and not name.startswith('.godot/imported/'): continue
            safe_write(args.output, name, base.read(entry))
    with ZipFile(args.correction_zip) as patch:
        for entry in patch.infolist():
            if entry.filename.startswith('projeto/') and not entry.is_dir():
                safe_write(args.output, entry.filename[8:], patch.read(entry))
    print('Working copy created:', args.output.resolve())


if __name__ == '__main__':
    main()
