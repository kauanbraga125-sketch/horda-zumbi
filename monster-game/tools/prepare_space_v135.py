"""Reproduce the approved orbital mine from its transparent source."""
from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]
layout=json.loads((root/'assets/art/space_v135/layout.json').read_text())
sprite=Image.open(root/layout['source']).convert('RGBA').crop(layout['crop'])
sprite.thumbnail((layout['max_size'],layout['max_size']),Image.Resampling.LANCZOS)
sprite.save(root/'assets/art/space_v135/mine.png')
print('SPACE_V135_MINE_READY')
