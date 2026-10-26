"""Fit four existing accessories with native meshes; preserve every PNG.

The eyewear stays rigid, with one similarity transform for its entire frame.
Mask eye apertures and wig source occlusion are geometry, not image edits.
"""
import argparse
import copy
import hashlib
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from shapely.geometry import Polygon
import zstandard
from prepare_v113_cosmetics import mesh

ITEMS = ['z_cyber', 'z_goggles', 'z_hockey', 'z_clown']


def rgba(root, graphic):
    x, y, w, h = map(int, graphic['rect'])
    return np.asarray(Image.open(root / 'assets/art' / graphic['file']).convert('RGBA'))[y:y+h, x:x+w]


def prepare(root):
    folder = root / 'assets/art/cosmetics_v113'
    path = folder / 'graphics.json'
    graphics = json.loads((root / 'tests/v123_before_graphics.json').read_text())
    protected = {k: copy.deepcopy(v) for k, v in graphics.items() if k not in ITEMS}
    for key in ITEMS[:2]:
        g = graphics[key]
        rig = g.pop('eye_rig')
        g['rigid_eyes'] = {'near': rig['near'], 'far': rig['far']}
        pixels = rgba(root, g)
        opaque = pixels[:, :, 3] > 0
        g['mesh'] = mesh(opaque)
        w, h = g['rect'][2:]
        clip = Polygon([(106, 50), (w, 30), (w, h), (106, h)]) if key == 'z_cyber' else Polygon([(116, 0), (w, 0), (w, h), (116, h)])
        g['front_mesh'] = mesh(opaque, clip)

    g = graphics['z_hockey']
    pixels = rgba(root, g)
    opaque = pixels[:, :, 3] > 0
    dark = (pixels[:, :, :3].max(axis=2) < 40) & (pixels[:, :, 3] > 50)
    holes = np.zeros(opaque.shape, dtype=bool)
    centers = []
    for x0, y0, x1, y1 in [(140, 120, 222, 211), (246, 108, 296, 202)]:
        region = np.zeros_like(dark)
        region[y0:y1, x0:x1] = dark[y0:y1, x0:x1]
        labels, count = ndi.label(region)
        assert count > 0
        areas = np.bincount(labels.ravel()); areas[0] = 0
        hole = labels == int(areas.argmax())
        yy, xx = np.where(hole)
        centers.append([round(float(xx.mean()), 3), round(float(yy.mean()), 3)])
        holes |= ndi.binary_dilation(hole, iterations=1)
    g['mesh'] = mesh(opaque & ~holes)
    g['mask_fit'] = {'near': centers[0], 'far': centers[1], 'chin': [230.0, 329.0]}
    g['eye_apertures'] = centers

    g = graphics['z_clown']
    g['hair_fit'] = {'anchor': [273.0, 143.0], 'scale': .0040, 'offset': [.19, -.07], 'angle': -.0878}
    g['source_mesh'] = 'clown_base'
    g['behind_body'] = True
    pixels = rgba(root, g)
    g['front_mesh'] = mesh(pixels[:, :, 3] > 0, Polygon([(0, 0), (401, 0), (401, 139), (0, 139)]))
    packed = (folder / 'fitting.bin').read_bytes()
    frames = json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]))
    overrides = {}
    textures = {}
    removed = 0
    for key, f in frames.items():
        if f['kind'] != 0:
            continue
        if f['file'] not in textures:
            textures[f['file']] = np.asarray(Image.open(root / 'assets/art' / f['file']).convert('RGBA'))
        x, y, w, h = map(int, f['rect'])
        p = textures[f['file']][y:y+h, x:x+w].astype(float)
        r, green, b, alpha = p.transpose(2, 0, 1)
        yy, xx = np.mgrid[:h, :w]
        width = f['head_width']; left, top, right, bottom = f['box']
        head_roi = yy < top + .63 * width
        face = Image.new('L', (w, h))
        draw = ImageDraw.Draw(face)
        data = f['meshes']['face']
        for i in range(0, len(data['indices']), 3):
            draw.polygon([tuple(data['points'][j]) for j in data['indices'][i:i+3]], fill=255)
        # Preserve the measured complete face, including black linework,
        # pupils, mouth, teeth, nostrils and the inside of each ear.
        face_guard = ndi.binary_dilation(np.asarray(face) > 0, iterations=1)
        skin_guard = ndi.binary_dilation((green > r * 1.02) & (green > b * 1.2) & (alpha > 20), iterations=2)
        eye_guard = np.zeros((h, w), dtype=bool)
        for which, radius in [('near', .28), ('far', .19)]:
            ex, ey = f['landmarks'][which]
            eye_guard |= ((xx-ex)**2 + (yy-ey)**2) < (width*radius)**2
        chin = f['landmarks']['chin']
        mouth_guard = (yy > chin[1] - .22 * width) & (yy < chin[1] + .07 * width) & (xx > f['landmarks']['near'][0] - .19 * width) & (xx < right + .07 * width)
        purple = (r > green * 1.45) & (b > green * 1.45) & (b > r * .65) & (alpha > 20) & head_roi
        remove = ndi.binary_dilation(purple, iterations=5) & head_roi & ~face_guard & ~skin_guard & ~eye_guard & ~mouth_guard
        # The neck, shirt, hands and feet always use the complete source UVs.
        remove &= yy < min(top + .63 * width, f['landmarks']['neck'][1] - .13 * width)
        keep = ndi.binary_dilation(alpha > 0, iterations=2) & ~remove
        # Drop detached outlines left outside the face after hiding the hair.
        labels, count = ndi.label(keep & (alpha > 0))
        for label, area in enumerate(np.bincount(labels.ravel())):
            if label == 0 or area >= max(12, .006 * width * width):
                continue
            island = labels == label
            if np.any(island & head_roi) and not np.any(island & (face_guard | skin_guard | eye_guard | mouth_guard)):
                keep &= ~ndi.binary_dilation(island, iterations=2)
        clip = Polygon(f['original_outline']) if 'original_outline' in f else None
        details = np.zeros((h, w), dtype=bool)
        for which, radius in [('near', .235), ('far', .15)]:
            ex, ey = f['landmarks'][which]
            details |= ((xx-ex)**2 + (yy-ey)**2) < (width*radius)**2
        details |= mouth_guard
        details &= ndi.binary_dilation(alpha > 0, iterations=2)
        overrides[key] = {'base': mesh(keep, clip), 'details': mesh(details, clip)}
        removed += int((remove & (alpha > 0)).sum())
    payload = json.dumps(overrides, separators=(',', ':')).encode()
    out = root / 'assets/art/cosmetics_v123'
    out.mkdir(exist_ok=True)
    (out / 'clown_sources.bin').write_bytes(struct.pack('<I', len(payload)) + zstandard.ZstdCompressor(level=19).compress(payload))
    path.write_text(json.dumps(graphics, separators=(',', ':')))
    assert {k: v for k, v in graphics.items() if k not in ITEMS} == protected
    assert hashlib.sha256((folder / 'fitting.bin').read_bytes()).hexdigest() == '5a7fdb5ebdb86a0c92f97813559272b778d3ec65987f458127f9d66d76ee8940'
    print(json.dumps({'items': ITEMS, 'other_graphics_unchanged': len(protected), 'wig_source_frames': len(overrides), 'original_fitting_unchanged': True, 'source_pngs_changed': 0, 'mask_eye_centers': centers, 'native_hair_occlusion_samples': removed}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    prepare(parser.parse_args().source)
