"""Measure the supplied template packs. Requires Pillow, NumPy and SciPy.

Writes sidecars, never rewrites source PNGs. Review the generated geometry
before running build_photobooth_catalog.py for a new template collection.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PACKS = {
    '008-kids-birthday-photo-booth-template-and-welcome-screen':
        ('birthday', 'kids', 'Sinh nhật bé', 0),
    '023-free-christmas-photo-booth-template-and-welcome-screen':
        ('christmas', 'starlight', 'Ánh sao', 0),
    '326-ugly-sweater-photo-booth-template-and-welcome-screen':
        ('christmas', 'sweater', 'Áo len', 1),
    '330-merry-christmas-photo-booth-template-and-welcome-screen':
        ('christmas', 'merry', 'Giáng sinh vui', 2),
    '405-free-kids-halloween-photo-booth-template-and-welcome-screen':
        ('halloween', 'kids', 'Halloween vui', 0),
}
CATEGORIES = {'birthday': 'Sinh nhật', 'christmas': 'Giáng sinh', 'halloween': 'Halloween'}


def measure(path):
    with Image.open(path) as image:
        alpha = np.asarray(image.convert('RGBA').getchannel('A'))
    # Keep anti-aliased pixels in the hole's connected component so that the
    # photograph also sits behind the translucent boundary, without white seams.
    components, _ = ndimage.label(alpha < 255)
    areas = np.bincount(components.ravel())
    boxes = []
    for label, bounds in enumerate(ndimage.find_objects(components), 1):
        if bounds is None or areas[label] < alpha.size * .012:
            continue
        y, x = bounds
        boxes.append(dict(x=x.start, y=y.start,
                          width=x.stop-x.start, height=y.stop-y.start))
    if not boxes:
        raise ValueError(f'No photo apertures: {path}')
    return alpha.shape[1], alpha.shape[0], boxes


def metadata(path, pack):
    theme, key, title, collection_order = PACKS[pack]
    width, height, boxes = measure(path)
    layout = path.stem.split()[0]
    variant = next((part for part in path.stem.split()[1:] if part.isdigit()), '01')
    single = path.parent.name == 'Single Strip'
    # These print sheets repeat source photos across strips. Mixed portrait
    # sheets have two/three or three/four rows; the shorter strip repeats the
    # first photos of the longer one. Landscape 6x4/03 repeats one row twice.
    if (layout == '2x6' and not single) or (layout == '4x6' and len(boxes) in (5, 7)):
        columns = [sorted((b for b in boxes if b['x'] < width / 2), key=lambda b: b['y']),
                   sorted((b for b in boxes if b['x'] >= width / 2), key=lambda b: b['y'])]
        if not columns[0] or not columns[1]:
            raise ValueError(f'Unbalanced double strip: {path}')
        slots = [dict(**box, photo=index) for column in columns for index, box in enumerate(column)]
        count = max(map(len, columns))
    elif layout == '6x4' and len(boxes) == 6:
        rows = [sorted((b for b in boxes if b['y'] < height / 2), key=lambda b: b['x']),
                sorted((b for b in boxes if b['y'] >= height / 2), key=lambda b: b['x'])]
        if list(map(len, rows)) != [3, 3]:
            raise ValueError(f'Unbalanced landscape strips: {path}')
        slots = [dict(**box, photo=index) for row in rows for index, box in enumerate(row)]
        count = 3
    else:
        # Read portrait layouts down each column; landscape layouts by row.
        if width < height and len(boxes) > 2:
            boxes.sort(key=lambda b: (b['x'] // (width // 2), b['y']))
        else:
            boxes.sort(key=lambda b: (b['y'] // max(1, height // 2), b['x'], b['y']))
        slots = [dict(**box, photo=index) for index, box in enumerate(boxes)]
        count = len(slots)
    shape = 'strip' if layout == '2x6' or single else 'square' if width == height else 'portrait' if width < height else 'landscape'
    format_label = '2×6 đôi' if layout == '2x6' and not single else '6×2' if single and width > height else layout.replace('x', '×')
    info = dict(
        key=f'{theme}-{key}-{layout}-{variant}{"-single" if single else ""}',
        theme=theme, categoryTitle=CATEGORIES[theme],
        title=f'{title} {variant}', format=format_label, shape=shape,
        order=collection_order * 1000 + (0 if single else 100) +
              {'strip': 0, 'portrait': 200, 'landscape': 400, 'square': 600}[shape] + int(variant),
        enabled=True,
        slots=slots,
    )
    return info, count


def prepare_belonkhon(root):
    pack = root / 'belonkhon'
    manifest = pack / 'manifest.json'
    if not manifest.exists():
        return []
    source = json.loads(manifest.read_text(encoding='utf-8'))
    counts = []
    for order, frame in enumerate(source['frames']):
        path = (pack / frame['file']).resolve()
        if not path.is_relative_to(pack.resolve()):
            raise ValueError(f'Frame outside its pack: {path}')
        width, height, boxes = measure(path)
        declared = frame['photo_slots']
        count = frame['photo_count']
        if ((width, height) != (frame['width'], frame['height']) or
                len(boxes) != count or len(declared) != count):
            raise ValueError(f'Manifest does not match measured frame: {path}')
        slots = []
        # Preserve the manifest's photo order even when the right aperture is
        # slightly higher. Include its anti-aliased edge from measured alpha.
        for index, slot in enumerate(declared):
            def overlap(box):
                w = max(0, min(slot['x'] + slot['width'], box['x'] + box['width']) -
                        max(slot['x'], box['x']))
                h = max(0, min(slot['y'] + slot['height'], box['y'] + box['height']) -
                        max(slot['y'], box['y']))
                area = w * h
                return area / (slot['width'] * slot['height'] +
                               box['width'] * box['height'] - area)
            box = max(boxes, key=overlap)
            if overlap(box) < .95:
                raise ValueError(f'Manifest aperture does not match alpha: {path}')
            slots.append(dict(**box, photo=index))
            boxes.remove(box)
        info = dict(key=f'belonkhon-{path.stem.replace("_", "-")}',
                    theme='belonkhon', categoryTitle='Bé Lớn Khôn',
                    title=frame['name_vi'], format=source['aspect_ratio'],
                    shape='landscape', order=order, enabled=True, slots=slots)
        path.with_suffix('.frame.json').write_text(
            json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        counts.append(count)
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mobile-root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.mobile_root / 'assets/photobooth/frames'
    counts = {}
    for path in sorted(root.rglob('*.png')):
        pack = next((part for part in path.parts if part in PACKS), None)
        if pack is None:
            continue
        info, count = metadata(path, pack)
        path.with_suffix('.frame.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        counts[count] = counts.get(count, 0) + 1
    for count in prepare_belonkhon(root):
        counts[count] = counts.get(count, 0) + 1
    print(f'Measured {sum(counts.values())} source templates; logical photo counts: {dict(sorted(counts.items()))}')
    if any(count not in (1, 2, 3, 4) for count in counts):
        raise ValueError('Unexpected logical photo count; review the measured mapping')


if __name__ == '__main__':
    main()
