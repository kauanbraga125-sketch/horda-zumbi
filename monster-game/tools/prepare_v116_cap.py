"""Pack the generated cap without redrawing pixels or changing other items.

The imagegen original and prompt are preserved under tools/art_sources/.
Only z_plumber's graphic entry changes. The existing body measurements stay.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import numpy as np
from PIL import Image
from prepare_v113_cosmetics import mesh


def main(a):
    source = a.source.resolve()
    art = source / 'assets/art'
    image = Image.open(a.image).convert('RGBA')
    pixels = np.asarray(image)
    y, x = np.where(pixels[:, :, 3] > 8)
    box = (max(0, int(x.min()) - 12), max(0, int(y.min()) - 12),
           min(image.width, int(x.max()) + 13), min(image.height, int(y.max()) + 13))
    image = image.crop(box)
    image = image.resize((512, round(image.height * 512 / image.width)), Image.Resampling.LANCZOS)
    folder = art / 'cosmetics_v116'
    folder.mkdir(exist_ok=True)
    output = folder / 'plumber.png'
    image.save(output, optimize=True)
    # Contact points are the rear cloth band and front forehead band on the
    # generated master. Runtime maps them to the moving skull, with no shear.
    contacts = [[(px - box[0]) / (box[2] - box[0]), (py - box[1]) / (box[3] - box[1])]
                for px, py in [(330, 870), (1150, 490)]]
    alpha = np.asarray(image)[:, :, 3]
    yy, xx = np.where(alpha > 8)
    graphics_path = art / 'cosmetics_v113/graphics.json'
    graphics = json.loads(graphics_path.read_text())
    before = {k: v for k, v in graphics.items() if k != 'z_plumber'}
    graphics['z_plumber'] = dict(file='cosmetics_v116/plumber.png', closed_band=True, rect=[0, 0, *image.size], contacts=contacts,
                               mesh=mesh(alpha > 8), bounds=[int(xx.min()), int(yy.min()), int(xx.max()-xx.min()+1), int(yy.max()-yy.min()+1)])
    graphics_path.write_text(json.dumps(graphics, separators=(',', ':')))
    assert {k: v for k, v in json.loads(graphics_path.read_text()).items() if k != 'z_plumber'} == before
    # CompressedTexture2D, using the same tested lossless WebP container as the
    # reconstruction. Both APK profiles get identical pixels for this new art.
    data = io.BytesIO()
    image.save(data, format='WEBP', lossless=True, quality=100, method=6, exact=True)
    payload = data.getvalue()
    assert np.array_equal(np.asarray(Image.open(io.BytesIO(payload)).convert('RGBA')), np.asarray(image))
    imported = '.godot/imported/plumber-v116-lossless.ctex'
    target = a.runtime / imported
    target.parent.mkdir(parents=True, exist_ok=True)
    width, height = image.size
    target.write_bytes(struct.pack('<4s8I', b'GST2', 1, width, height, 0, 0xffffffff, 0, 0, 0) +
                       struct.pack('<IHHIII', 2, width, height, 0, 5, len(payload)) + payload)
    config = f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://{imported}"
metadata={{"vram_texture": false}}

[deps]

source_file="res://assets/art/cosmetics_v116/plumber.png"
dest_files=["res://{imported}"]

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
'''
    (output.with_suffix('.png.import')).write_text(config)
    print(json.dumps(dict(asset=str(output), size=image.size, texture_bytes=target.stat().st_size,
                          sha256=hashlib.sha256(output.read_bytes()).hexdigest(), other_graphics_unchanged=len(before), new_texture_lossless=True)))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    for name in ['source', 'image', 'runtime']: p.add_argument('--' + name, type=Path, required=True)
    main(p.parse_args())
