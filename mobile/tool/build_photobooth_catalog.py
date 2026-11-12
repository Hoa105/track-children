"""Build a deterministic manifest from the checked-in PNG sources (no renames)."""
import json
import shutil
import struct
import math
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--mobile-root', type=Path,
                    default=Path(__file__).resolve().parents[1])
mobile = parser.parse_args().mobile_root.resolve()
root = mobile / 'assets' / 'photobooth'


def png_info(path):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise ValueError(f'Invalid PNG: {path}')
    width, height, _, color = struct.unpack('>IIBB', data[16:26])
    return width, height, color in (4, 6)


frames = []
theme_labels = dict(classic='Classic', film='Film', birthday='Birthday',
                    christmas='Christmas', halloween='Halloween')
frame_keys = set()
for path in sorted((root / 'frames').rglob('*.png')):
    width, height, alpha = png_info(path)
    if not alpha:
        raise ValueError(f'Unexpected template: {path}')
    theme = path.parent.name
    metadata = path.with_suffix('.frame.json')
    if metadata.exists():
        info = json.loads(metadata.read_text(encoding='utf-8'))
        slots = info['slots']
    elif theme in theme_labels and (width, height) in ((600, 1800), (1200, 1800)) and path.stem == f'photo-strip-template-{theme}-{"2x6" if width == 600 else "4x6"}':
        info = {}
        slots = [dict(x=48 + col * 600, y=48 + row * 402,
                      width=504, height=382, photo=row)
                 for col in range(width // 600) for row in range(4)]
    else:
        raise ValueError(f'Add measured slot geometry in {metadata}')
    if not slots:
        raise ValueError(f'Empty photo slots: {path}')
    for slot in slots:
        values = [slot[k] for k in ('x', 'y', 'width', 'height')]
        if not all(type(v) in (int, float) and math.isfinite(v) for v in values):
            raise ValueError(f'Invalid slot geometry: {path}')
        x, y, sw, sh = values
        if x < 0 or y < 0 or sw <= 0 or sh <= 0 or x + sw > width or y + sh > height or type(slot['photo']) is not int or slot['photo'] < 0:
            raise ValueError(f'Slot outside image or invalid photo index: {path}')
    photos = {slot['photo'] for slot in slots}
    if photos != set(range(len(photos))):
        raise ValueError(f'Photo indices must be contiguous from zero: {path}')
    key = info.get('key', f'{theme}-{width}')
    if not isinstance(key, str) or not key.strip():
        raise ValueError(f'Frame key must be a non-empty string: {path}')
    if key in frame_keys:
        raise ValueError(f'Duplicate frame key; set a unique key in {metadata}')
    frame_keys.add(key)
    category = info.get('theme', theme)
    for field in ('theme', 'title', 'categoryTitle', 'format'):
        if field in info and (not isinstance(info[field], str) or not info[field].strip()):
            raise ValueError(f'{field} must be a non-empty string: {path}')
    category_title = info.get('categoryTitle', theme_labels.get(category, category.replace('-', ' ').title()))
    frames.append(dict(
        key=key, theme=category,
        title=info.get('title', category_title), categoryTitle=category_title,
        format=info.get('format', '2×6' if (width, height) == (600, 1800) else '4×6' if (width, height) == (1200, 1800) else f'{width} × {height}'),
        asset=path.relative_to(mobile).as_posix(), width=width, height=height,
        slots=slots,
    ))

stickers = []
for path in sorted((root / 'stickers').rglob('*.png')):
    width, height, alpha = png_info(path)
    group = path.relative_to(root / 'stickers').parts[0]
    stickers.append(dict(
        key=f'{group}/{path.stem}', group=group,
        asset=path.relative_to(mobile).as_posix(), width=width, height=height,
        enabled=alpha, note='' if alpha else 'PNG has no alpha channel',
        lowResolution=max(width, height) < 128,
    ))

manifest = dict(version=1, frames=frames, stickers=stickers)
(root / 'catalog.json').write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

licenses = mobile.parent / 'docs' / 'assets-licenses' / 'photobooth'
for path in sorted(root.rglob('*')):
    if path.is_file() and path.name.lower().startswith(('license', 'readme')):
        dest = licenses / path.relative_to(root)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)

pubspec = mobile / 'pubspec.yaml'
text = pubspec.read_text(encoding='utf-8')
begin = '    # BEGIN PHOTOBOOTH ASSETS\n'
end = '    # END PHOTOBOOTH ASSETS\n'
if begin in text:
    start, tail = text.split(begin, 1)
    _, tail = tail.split(end, 1)
    text = start + tail
assets = ['assets/photobooth/catalog.json']
assets += [f['asset'] for f in frames]
assets += [s['asset'] for s in stickers if s['enabled']]
section = begin + ''.join(f'    - {asset}\n' for asset in assets) + end
anchor = '    - assets/images/scenery/icons/ui/\n'
if anchor not in text:
    raise ValueError('Missing pubspec asset anchor')
pubspec.write_text(text.replace(anchor, anchor + section), encoding='utf-8')
print(f'{len(frames)} frames, {len(stickers)} PNG stickers; '
      f'{sum(s["enabled"] for s in stickers)} transparent stickers bundled')
