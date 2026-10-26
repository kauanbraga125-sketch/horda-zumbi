"""Hide the old purple fringe with native source meshes, preserving the PNGs.

The v124 circular eye guards included the old fringe and drew it above the
orange wig. These cuts follow the skin and actual eye shapes instead.
"""
import argparse
import copy
import hashlib
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import zstandard
from prepare_v113_cosmetics import mesh


def prepare(root):
    folder = root / 'assets/art/cosmetics_v113'
    graphics = json.loads((root / 'tests/v125_before_graphics.json').read_text())
    protected = {k: copy.deepcopy(v) for k, v in graphics.items() if k != 'z_clown'}
    hair = graphics['z_clown']
    hair['source_mesh'] = 'clown_clean_base'
    hair['reveal_source'] = 'clown_clean_face'
    # Seat the curls on the hairline rather than leaving a purple gap below.
    hair['skull_fit'] = [[-.54, .295], [.64, .055]]
    packed = (folder / 'fitting.bin').read_bytes()
    frames = json.loads(zstandard.ZstdDecompressor().decompress(packed[4:]))
    textures = {}
    layers = {}
    total_removed = 0
    for key, frame in frames.items():
        if frame['kind'] != 0:
            continue
        file = frame['file']
        if file not in textures:
            textures[file] = np.asarray(Image.open(root / 'assets/art' / file).convert('RGBA'))
        x, y, w, h = map(int, frame['rect'])
        r, g, b, alpha = textures[file][y:y+h, x:x+w].astype(float).transpose(2, 0, 1)
        yy, xx = np.mgrid[:h, :w]
        width = float(frame['head_width'])
        neck_y = frame['landmarks']['neck'][1]
        head = yy < neck_y - .12 * width
        purple = (r > g*1.12) & (b > g*1.16) & (b > r*.60) & (alpha > 5) & head
        labels, count = ndi.label(purple)
        hair_color = np.zeros((h, w), dtype=bool)
        for label in range(1, count+1):
            component = labels == label
            cy, cx = np.where(component)
            # Brows and lip linework share the hair's dark purple palette,
            # but only the real hair connects to the crown or back of head.
            crown = cy.min() < frame['box'][1] + .12*width
            rear = cx.min() < frame['box'][0] + .08*width and cy.min() < neck_y-.30*width
            if crown or rear:
                hair_color |= component
        old_hair = ndi.binary_dilation(hair_color, iterations=max(2, round(width*.022))) & head
        eye_features = np.zeros((h, w), dtype=bool)
        for which, rx, ry in [('near', .23, .16), ('far', .14, .12)]:
            ex, ey = frame['landmarks'][which]
            eye_features |= ((xx-ex)/(width*rx))**2+((yy-ey)/(width*ry))**2 < 1
        # The far eyebrow touches the hair in some original frames. Keep
        # the compact eye ellipse, without keeping the upper purple fringe.
        old_hair &= ~eye_features
        skin = (g > r*1.02) & (g > b*1.2) & (alpha > 10)
        # Closing fills the original pupils and mouth, without broad circular
        # eye guards that accidentally preserved the surrounding old hair.
        face = ndi.binary_fill_holes(ndi.binary_closing(skin, iterations=1))
        face = ndi.binary_dilation(face, iterations=2)
        eyes = np.zeros((h, w), dtype=bool)
        for which, radius in [('near', .23), ('far', .145)]:
            ex, ey = frame['landmarks'][which]
            roi = (xx-ex)**2+(yy-ey)**2 < (width*radius)**2
            white = (r > 130) & (g > 90) & (b < g*.87) & (r > g*.98) & roi
            labels, count = ndi.label(white)
            if count:
                areas = np.bincount(labels.ravel());areas[0] = 0
                shape = ndi.binary_fill_holes(labels == int(areas.argmax()))
                # Preserve the complete dark outline and iris inside the eye.
                eyes |= ndi.binary_dilation(shape, iterations=max(2, round(width*.016)))
        near = frame['landmarks']['near']
        chin = frame['landmarks']['chin']
        mouth = (yy > chin[1]-.23*width) & (yy < chin[1]+.08*width) & (xx > near[0]-.20*width) & (xx < frame['box'][2]+.08*width)
        old_hair &= ~mouth
        body = yy > neck_y - .015*width
        safe_alpha = ndi.binary_dilation(alpha > 0, iterations=2)
        keep = safe_alpha & ~old_hair
        # Restore the original measured face and full body above the wig.
        # Exact old-hair removal takes precedence over the circular eye area.
        for which, radius in [('near', .235), ('far', .15)]:
            ex, ey = frame['landmarks'][which]
            eyes |= ((xx-ex)**2+(yy-ey)**2 < (width*radius)**2) & (yy > ey-.17*width)
        # Forehead skin belongs underneath the new fringe. Repainting it
        # above the wig made the old jagged hairline show through in green.
        lower_face = face & (yy > near[1]-.10*width)
        ear = face & (xx < frame['box'][0]+.34*width) & (yy > frame['box'][1]+.25*width)
        details = ((lower_face | ear | eyes | eye_features | mouth) & ~old_hair) | body
        details &= safe_alpha
        # Sample the complete source UVs: legacy polygon outlines predate
        # the current eyes and would clip a few edge pixels in idle frames.
        layers[key] = {'clown_clean_base': mesh(keep), 'clown_clean_face': mesh(details)}
        total_removed += int((old_hair & (alpha > 0)).sum())
    out = root / 'assets/art/cosmetics_v125'
    out.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(layers, separators=(',', ':')).encode()
    (out / 'hair_layers.bin').write_bytes(struct.pack('<I', len(payload)) + zstandard.ZstdCompressor(level=19).compress(payload))
    (folder / 'graphics.json').write_text(json.dumps(graphics, separators=(',', ':')))
    assert protected == {k: v for k, v in graphics.items() if k != 'z_clown'}
    print(json.dumps(dict(frames=len(layers), other_items_preserved=len(protected), original_hair_samples_hidden=total_removed,
                         character_pngs_changed=0, accessory_pngs_changed=0,
                         fitting_sha256=hashlib.sha256(packed).hexdigest())), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    prepare(parser.parse_args().source)
