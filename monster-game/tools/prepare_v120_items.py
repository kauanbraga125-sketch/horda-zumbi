"""Pack two redrawn hats and preserve the electric hood's complete face.

Character PNGs and existing fitting meshes are never altered. A new body mesh
preserves the complete face and arms; the hood's crown rim uses a front layer.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image, ImageDraw
from scipy.spatial import ConvexHull
from scipy import ndimage as ndi
from shapely.geometry import Polygon
import zstandard
from prepare_v113_cosmetics import mesh

SPECS = {
    'z_nightmare': {'name': 'nightmare', 'contacts': [(360, 686), (1170, 516)],
                    'wear_scale': .86, 'wear_center': [-.10, -.12]},
    'z_sorcerer': {'name': 'sorcerer', 'contacts': [(450, 825), (1060, 740)],
                   'wear_scale': .78, 'wear_center': [-.10, -.16]},
}


def pack_hat(source, runtime, spec, item_id, graphics):
    name = spec['name']
    original = Image.open(source / 'tools/art_sources/v120' / (name + '-generated.png')).convert('RGBA')
    alpha = np.asarray(original)[:, :, 3]
    y, x = np.where(alpha > 8)
    box = (max(0, int(x.min()) - 12), max(0, int(y.min()) - 12),
           min(original.width, int(x.max()) + 13), min(original.height, int(y.max()) + 13))
    image = original.crop(box)
    image = image.resize((512, round(image.height * 512 / image.width)), Image.Resampling.LANCZOS)
    alpha = np.asarray(image)[:, :, 3]
    y, x = np.where(alpha > 8)
    contacts = [[(px-box[0])/(box[2]-box[0]), (py-box[1])/(box[3]-box[1])]
                for px, py in spec['contacts']]
    graphics[item_id] = dict(file='cosmetics_v120/' + name + '.png', worn_brim=True,
                            wear_scale=spec['wear_scale'], wear_center=spec['wear_center'],
                            rect=[0, 0, *image.size], contacts=contacts, mesh=mesh(alpha > 8),
                            bounds=[int(x.min()), int(y.min()), int(x.max()-x.min()+1), int(y.max()-y.min()+1)])
    output = source / 'assets/art/cosmetics_v120' / (name + '.png')
    output.parent.mkdir(exist_ok=True)
    image.save(output, optimize=True)
    data = io.BytesIO()
    image.save(data, format='WEBP', lossless=True, quality=100, method=6, exact=True)
    payload = data.getvalue()
    assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')), np.asarray(image))
    imported = '.godot/imported/' + name + '-v120-lossless.ctex'
    target = runtime / imported
    target.parent.mkdir(parents=True, exist_ok=True)
    width, height = image.size
    target.write_bytes(struct.pack('<4s8I', b'GST2', 1, width, height, 0, 0xffffffff, 0, 0, 0) +
                       struct.pack('<IHHIII', 2, width, height, 0, 5, len(payload)) + payload)
    output.with_suffix('.png.import').write_text(f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://{imported}"
metadata={{"vram_texture": false}}

[deps]

source_file="res://assets/art/cosmetics_v120/{name}.png"
dest_files=["res://{imported}"]

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
''')
    return dict(id=item_id, size=image.size, texture_bytes=target.stat().st_size,
                rgba_sha256=hashlib.sha256(np.asarray(image).tobytes()).hexdigest(), lossless=True)


def preserve_face(source, frames):
    sheets = {}
    outlines = json.loads((source / 'assets/art/zombie-fluid-v73.json').read_text())['frames']
    count = 0
    for key, f in frames.items():
        if f['kind'] != 0:
            continue
        if f['file'] not in sheets:
            sheets[f['file']] = np.asarray(Image.open(source / 'assets/art' / f['file']).convert('RGBA'))
        x, y, width, height = map(int, f['rect'])
        r, g, b, a = sheets[f['file']][y:y+height, x:x+width].astype(float).transpose(2, 0, 1)
        yy, xx = np.mgrid[:height, :width]
        left, top, right, bottom = f['box']
        w = float(f['head_width'])
        skin = (a > 80) & (g > 60) & (g > r*1.02) & (g > b*1.2)
        region = (xx > left-.08*w) & (xx < right+.08*w) & (yy > top-.08*w) & (yy < bottom+.06*w)
        sy, sx = np.where(skin & region)
        points = np.column_stack([sx, sy])
        hull = points[ConvexHull(points).vertices]
        mask = Image.new('1', (width, height))
        ImageDraw.Draw(mask).polygon([tuple(p) for p in hull], fill=1)
        # Padding includes the dark outline and lips just outside the green
        # skin. Filling the hull retains eye whites, teeth and open mouths.
        keep = ndi.binary_dilation(np.asarray(mask), iterations=max(3, round(w*.045)))
        # Preserve the full foreground face as well as its convex skin hull.
        # Mouth corners and the nose outline can extend beyond green pixels.
        keep |= (xx > left+.10*w) & (yy > top+.25*w) & (yy < bottom+.12*w)
        clip = Polygon(outlines[int(key[8:])]['outline']) if key.startswith('z_other_') else None
        # Hide the covered hair, while preserving the entire face and body.
        # In particular, never use a skin-colour mask as the visible face.
        head = (xx > left-.64*w) & (xx < right+.30*w) & (yy < top+.84*w)
        protected_body = yy > f['landmarks']['neck'][1]-.12*w
        body = ~head | keep | protected_body
        # A hair tip intersected by the hidden-hair boundary can become a
        # detached speck. Remove only tiny, non-skin islands above the face.
        labels, count_islands = ndi.label(body & (a > 5))
        for label, component in enumerate(ndi.find_objects(labels), 1):
            if component is None:
                continue
            sy, sx = component
            part = labels == label
            if part.sum() < max(8, .012*w*w) and not np.any(part & skin) and np.all(yy[part] < top+.30*w):
                body[part] = False
        f['meshes'].pop('hood_face', None)
        f['meshes']['hood_base'] = mesh(body, clip)
        f['meshes']['hood_base_cape'] = f['meshes']['hood_base']
        count += 1
    return count


def main(a):
    source = a.source.resolve()
    folder = source / 'assets/art/cosmetics_v113'
    graphics_path = folder / 'graphics.json'
    graphics = json.loads(graphics_path.read_text())
    before = {k: v for k, v in graphics.items() if k not in [*SPECS, 'z_electric']}
    art = [pack_hat(source, a.runtime, spec, item_id, graphics) for item_id, spec in SPECS.items()]
    graphics['z_electric'].pop('preserve_source', None)
    graphics['z_electric'].pop('face_mesh', None)
    graphics['z_electric']['behind_body'] = True
    graphics['z_electric']['source_mesh'] = 'hood_base'
    # Only the yellow crown rim goes in front of the hair. Keep the dark
    # lining and hanging side cloth behind the complete face and arms.
    hood = graphics['z_electric']
    x, y, width, height = hood['rect']
    pixels = np.asarray(Image.open(source / 'assets/art' / hood['file']).convert('RGBA'))[y:y+height, x:x+width]
    r, g, b, a = pixels.astype(float).transpose(2, 0, 1)
    yy, xx = np.mgrid[:height, :width]
    yellow = (r > 130) & (g > 90) & (b < g*.72) & (r > g*.95)
    front = ndi.binary_dilation(yellow, iterations=2) & (a > 8) & (yy < height*.41)
    hood['front_mesh'] = mesh(front)
    graphics_path.write_text(json.dumps(graphics, separators=(',', ':')))
    assert {k: v for k, v in graphics.items() if k not in [*SPECS, 'z_electric']} == before
    packed = (folder / 'fitting.bin').read_bytes()
    frames = json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]))
    count = preserve_face(source, frames)
    payload = json.dumps(frames, separators=(',', ':')).encode()
    (folder / 'fitting.bin').write_bytes(struct.pack('<I', len(payload)) + zstandard.ZstdCompressor(level=19).compress(payload))
    print(json.dumps(dict(art=art, complete_faces=count, other_graphics_unchanged=len(before),
                          original_character_pngs_modified=0)))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--runtime', type=Path, required=True)
    main(p.parse_args())
