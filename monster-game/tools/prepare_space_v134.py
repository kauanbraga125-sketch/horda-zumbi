"""Split the approved generated source into the four raw in-game sprites."""
from pathlib import Path
from PIL import Image
import json

root = Path(__file__).resolve().parents[1]
destination = root / 'assets/art/space_v134'
layout = json.loads((destination / 'layout.json').read_text())
source = Image.open(root / layout['source']).convert('RGBA')
for name, box in layout['source_boxes'].items():
    sprite = source.crop(box)
    sprite = sprite.crop(sprite.getchannel('A').getbbox())
    sprite.thumbnail((512, 512), Image.Resampling.LANCZOS)
    sprite.save(destination / (name + '.png'))
    Image.open(destination / (name + '.png')).verify()
print('SPACE_V134_ART_READY', len(layout['source_boxes']))
