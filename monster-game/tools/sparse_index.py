"""Godot 4.5.1 sparse PCK directory (format 3), matching its Android exporter.

Godot's FileAccessPack uses this directory's lengths even when the actual
files live as loose APK assets. Updating only ZIP entries leaves stale lengths.
"""
import hashlib
import struct

MAGIC = 0x43504447
HEADER_SIZE = 104


def read_index(data):
    magic, version, major, minor, patch, flags = struct.unpack_from('<6I', data)
    assert magic == MAGIC and version == 3 and flags == 6
    directory_offset = struct.unpack_from('<Q', data, 32)[0]
    count = struct.unpack_from('<I', data, directory_offset)[0]
    cursor = directory_offset + 4
    result = {}
    for _ in range(count):
        length = struct.unpack_from('<I', data, cursor)[0]
        cursor += 4
        name = data[cursor:cursor + length].rstrip(b'\0').decode('utf-8')
        cursor += length
        offset, size = struct.unpack_from('<QQ', data, cursor)
        md5 = data[cursor + 16:cursor + 32]
        file_flags = struct.unpack_from('<I', data, cursor + 32)[0]
        cursor += 36
        assert name not in result
        result[name] = {'offset': offset, 'size': size, 'md5': md5.hex(), 'flags': file_flags}
    assert not any(data[cursor:]), 'Unexpected nonzero sparse-PCK trailer'
    return result


def build_index(files):
    """files maps resource-relative path to its complete, final bytes."""
    header = struct.pack('<6I2Q16I', MAGIC, 3, 4, 5, 1, 6, 0, HEADER_SIZE, *([0] * 16))
    out = bytearray(header + struct.pack('<I', len(files)))
    for name, data in sorted(files.items()):
        path = name.encode('utf-8')
        path += bytes((-len(path)) % 4)
        out += struct.pack('<I', len(path)) + path
        out += struct.pack('<QQ', 0, len(data)) + hashlib.md5(data).digest() + struct.pack('<I', 0)
    index = bytes(out)
    verify_index(index, files)
    return index


def verify_index(index, files):
    entries = read_index(index)
    assert set(entries) == set(files), 'Sparse directory does not match APK resources'
    for name, data in files.items():
        entry = entries[name]
        assert entry['offset'] == 0 and entry['flags'] == 0
        assert entry['size'] == len(data), 'Stale sparse size: ' + name
        assert entry['md5'] == hashlib.md5(data).hexdigest(), 'Stale sparse hash: ' + name
    return len(entries)
