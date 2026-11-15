"""Check every supplied pack against its actual alpha pixels and source mapping."""
import json
from collections import Counter
from pathlib import Path
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'assets/photobooth/frames'


class FrameGeometryTests(unittest.TestCase):
    def test_all_new_sources_have_valid_geometry_covering_the_apertures(self):
        counts = Counter()
        metadata = list(ROOT.rglob('*.frame.json'))
        self.assertEqual(len(metadata), 82)
        for path in metadata:
            with self.subTest(frame=path.name, collection=path.parent.parent.name):
                frame = json.loads(path.read_text(encoding='utf-8'))
                with Image.open(path.with_suffix('').with_suffix('.png')) as image:
                    alpha = np.asarray(image.convert('RGBA').getchannel('A'))
                height, width = alpha.shape
                covered = np.zeros(alpha.shape, dtype=bool)
                photos = set()
                for slot in frame['slots']:
                    x, y, w, h = (slot[key] for key in ('x', 'y', 'width', 'height'))
                    self.assertTrue(0 <= x < x+w <= width and 0 <= y < y+h <= height)
                    self.assertGreater(np.count_nonzero(alpha[y:y+h, x:x+w] == 0), w*h*.6)
                    covered[y:y+h, x:x+w] = True
                    photos.add(slot['photo'])
                self.assertEqual(photos, set(range(len(photos))))
                self.assertIn(len(photos), (1, 2, 3, 4))
                transparent = alpha == 0
                self.assertLessEqual(np.count_nonzero(transparent & ~covered), alpha.size * .001)
                counts[len(photos)] += 1
        self.assertEqual(counts, {1: 22, 2: 16, 3: 33, 4: 11})

    def test_belonkhon_slots_follow_manifest_photo_order(self):
        pack = ROOT / 'belonkhon'
        manifest = json.loads((pack / 'manifest.json').read_text(encoding='utf-8'))
        for source in manifest['frames']:
            frame = json.loads((pack / source['file']).with_suffix('.frame.json').read_text(encoding='utf-8'))
            self.assertEqual(frame['format'], '6:4')
            self.assertEqual(len(frame['slots']), source['photo_count'])
            for index, (measured, declared) in enumerate(zip(frame['slots'], source['photo_slots'])):
                self.assertEqual(measured['photo'], index)
                for axis in ('x', 'y', 'width', 'height'):
                    self.assertLessEqual(abs(measured[axis] - declared[axis]), 2)


if __name__ == '__main__':
    unittest.main()
