"""Check the actual Godot sparse-directory lengths and hashes against an APK."""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile
from sparse_index import read_index


def diagnose(path):
    with ZipFile(path) as apk:
        index = read_index(apk.read('assets/assets.sparsepck'))
        files = {n[7:]: apk.read(n) for n in apk.namelist()
                 if n.startswith('assets/') and not n.endswith('/')
                 and n not in ['assets/assets.sparsepck', 'assets/_cl_']}
        missing = sorted(set(index) - set(files))
        unindexed = sorted(set(files) - set(index))
        stale = []
        for name in sorted(set(index) & set(files)):
            entry, data = index[name], files[name]
            if entry['size'] != len(data) or entry['md5'] != hashlib.md5(data).hexdigest():
                stale.append({'path': name, 'indexed_bytes': entry['size'], 'actual_bytes': len(data),
                              'hash_matches': entry['md5'] == hashlib.md5(data).hexdigest()})
        return {'apk': Path(path).name, 'indexed_files': len(index), 'stale': stale,
                'indexed_missing_files': missing, 'unindexed_actual_files': unindexed,
                'passed': not (stale or missing or unindexed)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    result = diagnose(args.apk)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['passed'] else 1)
