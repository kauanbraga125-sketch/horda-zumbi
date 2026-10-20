"""Refresh the startup audit after importing/editing a complete source checkout.

Run Godot 4.5.1 --headless --path <project> --editor --import first.
This contains no signing credentials and does not modify player saves.
"""
import hashlib
import json
import re
from pathlib import Path


def refresh(root: Path):
    cache = root / '.godot/global_script_class_cache.cfg'
    if not cache.is_file():
        raise SystemExit('Import the project in Godot 4.5.1 before refreshing the audit.')
    paths = [cache, root / 'boot.tscn', root / 'main.tscn']
    paths += sorted(p for p in (root / 'scripts').iterdir() if p.suffix in ('.gd', '.gdshader'))
    for folder in ('soldier_v100', 'polish_v101', 'menu_v102', 'codex_v103'):
        paths += sorted((root / 'assets/art' / folder).glob('*.json'))
    version = re.search(r'config/version="([^"]+)"', (root / 'project.godot').read_text()).group(1)
    manifest = {'version': version,
                'class_count': len(re.findall(rb'"class":', cache.read_bytes())),
                'files': [{'path': 'res://' + p.relative_to(root).as_posix(),
                           'bytes': p.stat().st_size,
                           'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]}
    (root / 'startup_integrity.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Startup audit refreshed: {version}, {len(paths)} files, {manifest["class_count"]} classes')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    refresh(parser.parse_args().project.resolve())
