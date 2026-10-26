"""Import the two new imagegen sprites unchanged and prepare native layers.

Original character PNGs, all existing textures and fitting.bin stay intact.
The hair overlays a complete character; source layers preserve face and body.
"""
import argparse
import copy
import hashlib
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import zstandard
from prepare_v113_cosmetics import mesh


def pack_texture(root, name):
    path = root / 'assets/art/cosmetics_v124' / (name + '.png')
    image = Image.open(path).convert('RGBA')
    pixels = np.asarray(image)
    stream = io.BytesIO()
    image.save(stream, format='WEBP', lossless=True, quality=100, method=6, exact=True)
    payload = stream.getvalue()
    assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')), pixels)
    relative = '.godot/imported/' + name + '-v124-lossless.ctex'
    texture = root / relative
    texture.parent.mkdir(parents=True, exist_ok=True)
    w, h = image.size
    texture.write_bytes(struct.pack('<4s8I', b'GST2', 1, w, h, 0, 0xffffffff, 0, 0, 0) + struct.pack('<IHHIII', 2, w, h, 0, 5, len(payload)) + payload)
    path.with_suffix('.png.import').write_text(f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://{relative}"
metadata={{"vram_texture": false}}

[deps]

source_file="res://assets/art/cosmetics_v124/{name}.png"
dest_files=["res://{relative}"]

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
''')
    yy, xx = np.where(pixels[:, :, 3] > 10)
    graphic = dict(file='cosmetics_v124/' + name + '.png', rect=[0, 0, w, h],
                   bounds=[int(xx.min()), int(yy.min()), int(xx.max()-xx.min()+1), int(yy.max()-yy.min()+1)],
                   mesh=mesh(pixels[:, :, 3] > 0))
    report = dict(name=name, size=[w, h], source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                  rgba_sha256=hashlib.sha256(pixels.tobytes()).hexdigest(), lossless=True, texture_bytes=texture.stat().st_size)
    return pixels, graphic, report


def prepare(root):
    folder = root / 'assets/art/cosmetics_v113'
    graphics = json.loads((root / 'tests/v124_before_graphics.json').read_text())
    protected = {k: copy.deepcopy(v) for k, v in graphics.items() if k not in ['z_hockey', 'z_clown']}
    pixels, mask, mask_report = pack_texture(root, 'hockey')
    opaque = pixels[:, :, 3] > 10
    labels, count = ndi.label(ndi.binary_fill_holes(opaque) & ~opaque)
    holes = []
    for label in range(1, count+1):
        area = int((labels == label).sum())
        if area < 1000:
            continue
        y, x = ndi.center_of_mass(labels == label)
        holes.append((area, [round(float(x), 3), round(float(y), 3)]))
    assert len(holes) >= 2, 'The mask needs two transparent eye apertures'
    near, far = sorted([v[1] for v in sorted(holes, reverse=True)[:2]], key=lambda v: v[0])
    w, h = mask['rect'][2:]
    mask['contacts'] = [[p[0]/w, p[1]/h] for p in [near, far, [940, 990]]]
    mask['mask_surface'] = {'near': near, 'far': far, 'chin': [940, 990], 'chin_offset': .035}
    mask['eye_apertures'] = [near, far]
    mask['reveal_source'] = 'hockey_ears'
    graphics['z_hockey'] = mask

    pixels, hair, hair_report = pack_texture(root, 'clown')
    w, h = hair['rect'][2:]
    x, y, bw, bh = hair['bounds']
    points = [[x+bw*.20, y+bh*.80], [x+bw*.85, y+bh*.57]]
    hair['contacts'] = [[p[0]/w, p[1]/h] for p in points]
    hair['skull_fit'] = [[-.56, .17], [.62, -.07]]
    hair['source_mesh'] = 'clown_base'
    hair['preserve_source'] = False
    hair['reveal_source'] = 'clown_face'
    graphics['z_clown'] = hair

    packed = (folder / 'fitting.bin').read_bytes()
    frames = json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]))
    layers = {};textures = {}
    for key, f in frames.items():
        if f['kind'] != 0:
            continue
        if f['file'] not in textures:
            textures[f['file']] = np.asarray(Image.open(root / 'assets/art' / f['file']).convert('RGBA'))
        x, y, w, h = map(int, f['rect'])
        p = textures[f['file']][y:y+h, x:x+w].astype(float)
        r, g, b, alpha = p.transpose(2, 0, 1)
        yy, xx = np.mgrid[:h, :w]
        width = f['head_width'];left, top, right, bottom = f['box']
        skin = (g > r*1.02) & (g > b*1.2) & (alpha > 10)
        skin = ndi.binary_dilation(ndi.binary_fill_holes(ndi.binary_closing(skin, iterations=1)), iterations=2)
        details = skin.copy()
        eye_guard = np.zeros((h, w), dtype=bool)
        for which, radius in [('near', .235), ('far', .15)]:
            ex, ey = f['landmarks'][which]
            eye_guard |= (xx-ex)**2+(yy-ey)**2 < (width*radius)**2
        details |= eye_guard
        chin = f['landmarks']['chin'];near_eye = f['landmarks']['near']
        details |= (yy > chin[1]-.23*width) & (yy < chin[1]+.08*width) & (xx > near_eye[0]-.20*width) & (xx < right+.08*width)
        # Complete clothes, limbs and feet remain above the rear curls.
        details |= yy > f['landmarks']['neck'][1]-.015*width
        # Keep the old purple fringe out of the restored skin layer.
        purple_hair = (r > g*1.35) & (b > g*1.40) & (b > r*.65) & (yy < f['landmarks']['neck'][1]-.12*width)
        details &= ~purple_hair | eye_guard
        safe_alpha = ndi.binary_dilation(alpha > 0, iterations=2)
        ear = (xx < left+.34*width) & (xx > left-.10*width) & (yy > top+.25*width) & (yy < top+.90*width)
        ear &= skin
        layers[key] = {'clown_face': mesh(details & safe_alpha), 'hockey_ears': mesh(ear & safe_alpha)}
    payload = json.dumps(layers, separators=(',', ':')).encode()
    out = root / 'assets/art/cosmetics_v124'
    (out / 'source_layers.bin').write_bytes(struct.pack('<I', len(payload)) + zstandard.ZstdCompressor(level=19).compress(payload))
    (folder / 'graphics.json').write_text(json.dumps(graphics, separators=(',', ':')))
    assert protected == {k:v for k,v in graphics.items() if k not in ['z_hockey', 'z_clown']}
    report = dict(art=[mask_report, hair_report], original_character_pngs_edited=0,
                  previous_graphics_preserved=len(protected), source_frames=len(layers),
                  mask_eye_centers=[near, far], original_fitting_sha256=hashlib.sha256(packed).hexdigest())
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True)
    prepare(parser.parse_args().source)
